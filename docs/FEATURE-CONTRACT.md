# Feature contract — the 36-feature vector

**Owned here. Load-bearing.** This file is the single authority for the window,
the per-channel statistics, and their order into the Core ML input. The Swift
feature extractor cites this file. The Python training pipeline cites
`pilot/analysis/lib/features.py` in the thesis repo. Neither cites the other.

Changing anything below is a contract change: edit this file, add a dated line
to [`DECISIONS.md`](DECISIONS.md), then update both sides and re-run the parity
check.

Unlike [`PLATFORM-FACTS.md`](PLATFORM-FACTS.md), this is **not** a snapshot of
the thesis repo. It is the deployment side's own statement of a contract the
thesis repo's code implements independently. The parity check is what keeps the
two honest; nothing else does.

---

## 0. Why this file exists

The Core ML model that ships in D5 is fitted on the output of
`~/Documents/Personal/thesis/pilot/analysis/lib/features.py`. A classifier does
not validate its input. If the Swift extractor computes a different SD
denominator, a different percentile rule, or a different vector order, the model
still returns a confident probability for every window — of a different
question. There is no exception, no log line, and no symptom on the wrist.

Every other phase of this app fails loudly. This one fails silently. That is the
entire reason the contract is a file and the parity check is a test.

---

## 1. Window

| | Value | Source |
|---|---|---|
| Length | **200 samples** | `window_s = 2.0` at `fs = 100` Hz |
| Stride (hop) | **100 samples** | `overlap = 0.5` |

Derived exactly as `lib/run.py` derives them:

```python
win = int(round(window_s * fs))                  # 200
hop = max(1, int(round(win * (1.0 - overlap))))  # 100
```

Both are **sample counts, not durations**. The extractor never looks at a
timestamp. 100 Hz is a ceiling, not a guarantee (`PLATFORM-FACTS.md`), so a
window is 200 consecutive delivered samples however long they took in wall
time — exactly as the training windows are 200 consecutive rows however long
those took.

**No partial windows, no zero-padding.** `lib/windowing.py` yields nothing for a
bout shorter than `win`; on device the equivalent is that `RingBuffer` emits
nothing until 200 real samples exist. A padded window is a different signal.

**2.0 s / 50 % is inherited from the public arm**, not measured on the
collector's own data: `research/pipeline-design-decisions.md` §2.1 chose it from
the NinaPro DB5 sweep, explicitly without sight of the author's data. It is
frozen here so D2 has a number to be exact about. If a sweep on own data moves
it, that is a contract change and the D5 model must be retrained at the new
value — the model and this file are a matched pair.

---

## 2. Channels — 9, in this order

Normative order, from the collector's
[`DATA-CONTRACT.md`](../../WristWatch/docs/DATA-CONTRACT.md) §2.1, which is CSV
file order minus `timestamp`:

| # | Channel | `CMDeviceMotion` source |
|---|---|---|
| 0 | `grav_x` | `gravity.x` |
| 1 | `grav_y` | `gravity.y` |
| 2 | `grav_z` | `gravity.z` |
| 3 | `uacc_x` | `userAcceleration.x` |
| 4 | `uacc_y` | `userAcceleration.y` |
| 5 | `uacc_z` | `userAcceleration.z` |
| 6 | `gyro_x` | `rotationRate.x` |
| 7 | `gyro_y` | `rotationRate.y` |
| 8 | `gyro_z` | `rotationRate.z` |

This order is not alphabetical and is not grouped by axis. It is file order,
because `features.signal_channels()` takes the loader's columns in file order:

```python
return [c for c in signals.columns if c != "timestamp"]
```

`gyro_*` is `rotationRate`, not the raw gyroscope — `isGyroAvailable` is false
on this hardware. The name is a pilot-era artefact kept for compatibility
(`PLATFORM-FACTS.md`). It is a naming fact, not a sensor claim.

---

## 3. Statistics — 4, in this order

`features.DEFAULT_STATS`: `["mean", "std", "p25", "p75"]`.

### 3.1 `mean`

`w.mean(axis=0)` — arithmetic mean, `sum / n`.

### 3.2 `std` — population SD, ddof = 0

`ndarray.std(axis=0)`, whose default is **`ddof = 0`**, computed two-pass:

```
m   = sum(x) / n
var = sum((x - m)^2) / n          <- n, NOT n-1
sd  = sqrt(var)
```

A sample SD (`ddof = 1`) is wrong by a factor of sqrt(200/199) ~ 1.0025. The
`StandardScaler` would absorb the constant scale change on average, so the app
would look fine and the decision boundary would sit in the wrong place. Do not
use `ddof = 1`.

**Two-pass, not one-pass.** `sum(x^2)/n - m^2` is algebraically identical and
numerically not: on the gravity channels — values near +/-1 with a small spread —
it cancels catastrophically and can even return a small negative variance.
numpy is two-pass; the Swift side is two-pass.

### 3.3 `p25` / `p75` — numpy `method="linear"`

`np.percentile(w, q, axis=0)` with its default `method="linear"`. For sorted
`s[0..n-1]`:

```
h    = (n - 1) * q / 100
lo   = floor(h)
t    = h - lo
value = s[lo]                       if lo == n - 1
        s[lo] + (s[lo+1] - s[lo]) * t        if t <  0.5
        s[lo+1] - (s[lo+1] - s[lo]) * (1-t)  if t >= 0.5
```

The two-branch form is numpy's own `_lerp`, kept for the last ulp rather than
because the split is meaningful.

At n = 200 both percentiles genuinely interpolate — p25 lands at h = 49.75 and
p75 at h = 149.25 — so a nearest-rank or an "exclusive" percentile differs on
essentially every window, not just on ties.

---

## 4. Vector layout — stat-major, channel-minor

36 = 9 channels x 4 statistics, ordered by `features.feature_names`:

```python
[f"{c}_{s}" for s in stats for c in channels]
```

The **statistic is the outer loop**:

```
[ 0.. 8]  grav_x_mean grav_y_mean grav_z_mean uacc_x_mean uacc_y_mean uacc_z_mean gyro_x_mean gyro_y_mean gyro_z_mean
[ 9..17]  grav_x_std  grav_y_std  grav_z_std  uacc_x_std  uacc_y_std  uacc_z_std  gyro_x_std  gyro_y_std  gyro_z_std
[18..26]  grav_x_p25  ...                                                                                 gyro_z_p25
[27..35]  grav_x_p75  ...                                                                                 gyro_z_p75
```

It is **not** channel-blocked (`grav_x_mean, grav_x_std, grav_x_p25, ...`).
Channel-blocked is the intuitive layout and the wrong one; a model fed it runs
and is wrong.

### 4.1 The 36 feature names, in order — normative

Emitted by `features.feature_names(channels, DEFAULT_STATS)`. This table is the
list the D2 gate asks for; index is the position in the Core ML input vector.

| # | Feature |
|---|---|
| 0 | `grav_x_mean` |
| 1 | `grav_y_mean` |
| 2 | `grav_z_mean` |
| 3 | `uacc_x_mean` |
| 4 | `uacc_y_mean` |
| 5 | `uacc_z_mean` |
| 6 | `gyro_x_mean` |
| 7 | `gyro_y_mean` |
| 8 | `gyro_z_mean` |
| 9 | `grav_x_std` |
| 10 | `grav_y_std` |
| 11 | `grav_z_std` |
| 12 | `uacc_x_std` |
| 13 | `uacc_y_std` |
| 14 | `uacc_z_std` |
| 15 | `gyro_x_std` |
| 16 | `gyro_y_std` |
| 17 | `gyro_z_std` |
| 18 | `grav_x_p25` |
| 19 | `grav_y_p25` |
| 20 | `grav_z_p25` |
| 21 | `uacc_x_p25` |
| 22 | `uacc_y_p25` |
| 23 | `uacc_z_p25` |
| 24 | `gyro_x_p25` |
| 25 | `gyro_y_p25` |
| 26 | `gyro_z_p25` |
| 27 | `grav_x_p75` |
| 28 | `grav_y_p75` |
| 29 | `grav_z_p75` |
| 30 | `uacc_x_p75` |
| 31 | `uacc_y_p75` |
| 32 | `uacc_z_p75` |
| 33 | `gyro_x_p75` |
| 34 | `gyro_y_p75` |
| 35 | `gyro_z_p75` |

`FeatureExtractor.featureNames` is asserted equal to this list, element for
element, in `FeatureParityTests.testVectorLayoutMatchesPython` — against the
fixture's copy of Python's own output, not against a transcription of this
table.

---

## 5. No scaling on device

The Swift extractor emits **raw, unscaled** feature values.

Every arm in the thesis slate is an sklearn `Pipeline(StandardScaler ->
estimator)`, and the converted model is the **Pipeline**, not the bare
estimator (`lib/models.py` header): the fitted scaler's means and scales ship
*inside* the `.mlmodel`, which is why the deployed object and the evaluated
object are the same object. The model scales its own input.

Normalizing on device would scale twice. Do not add a normalization step, a
gravity-magnitude correction, a unit conversion, or a filter between the
extractor and the model input.

---

## 6. Non-finite refusal

`features.extract` ends at a trust boundary, not a debug assert:

```python
if not np.isfinite(X).all():
    raise ValueError(f"non-finite feature values in columns: {bad.tolist()}")
```

A NaN or inf reaching an estimator makes some raise and some quietly produce
garbage, so it is refused at the source. The Swift extractor refuses the same
way: a window with any non-finite feature yields `nil` and is **dropped, not
substituted**. No zero-fill, no last-good-value carry-forward — an imputed
window is a fabricated observation and the haptic would fire on it.

---

## 7. Parity check

`tools/parity.py` imports the thesis repo's `features.py` and `windowing.py`
**by path** and runs them. It never reimplements them -- a reimplementation would
be a third thing to keep in sync, and the failure mode this whole file exists to
prevent.

It writes a fixture -- a sample stream, the window starts
`windowing.window_indices` produced for it, and the 36-vector `features.extract`
produced for each. `FeatureParityTests` replays that stream through
`RingBuffer` and `FeatureExtractor` and compares.

```bash
# synthetic, seeded; rewrites the committed fixture
python3 tools/parity.py

# a real recording; writes a scratch fixture and prints the command below
python3 tools/parity.py <file.csv>

# run the Swift side against that scratch fixture
TEST_RUNNER_PARITY_FIXTURE="<printed path>" xcodebuild test \
  -project WristWatcher/WristWatcher.xcodeproj \
  -scheme "WristWatcher Watch App" \
  -only-testing:'WristWatcher Watch AppTests/FeatureParityTests'
```

**The `TEST_RUNNER_` prefix is not optional.** xcodebuild does not forward its
own environment to the simulator test process; it forwards only variables with
that prefix, stripped. A bare `PARITY_FIXTURE=` is silently ignored, the suite
falls back to the committed fixture, and the run passes without having read the
file you named. Confirm which fixture ran from the `parity: N windows` line --
the committed one is 7 windows, a real recording is hundreds.

Only the committed fixture is synthetic and seeded. A fixture built from a real
recording is written to a scratch directory and committed nowhere: it is derived
from participant-adjacent data (`CLAUDE.md`), and the collector and thesis repos
are read-only from here.

### 7.1 Which CSVs it accepts

The first ten columns must be `timestamp` plus the nine channels of section 2,
in that order. Everything after them is ignored, because no feature is computed
from any of it. This accepts both the collector's 16-column
`DATA-CONTRACT.md` section 2.1 file and the older 12-column pilot-recorder file
(`timestamp`, 9 channels, `axis`, `angle_deg`).

What is *not* relaxed is the order of those ten. A reordered writer produces a
file that loads cleanly and means something else.

### 7.2 Two different window grids, and why only one is compared

`windowing.py` restarts its window grid at each bout and refuses any window that
would straddle two of them. `RingBuffer` is stride-aligned from the first sample
and runs forever, because a live wrist has no bout boundaries to straddle.

On a multi-posture recording the two therefore disagree, and neither is wrong:
the August pilot file `posture-neutral-20260807-004108.csv` has 7 posture runs,
from which Python extracts 425 windows and the ring emits 433 -- the 8 extra are
exactly the ones straddling a posture change. Their *starts* do not even align
(Python: 3645, 3745, ...; ring: 3600, 3700, ...).

So the grids are compared only where there is one bout -- the committed fixture,
and what the device itself produces. Feature parity is asserted over Python's own
window starts, sliced directly out of the stream, because which windows exist is
the bout rule's business and this contract is about what the 36 numbers are once
a window exists.

### 7.3 Tolerance, and why it is not zero

Each feature is compared against the Python value with

```
tolerance = 1e-12 * max(|expected|, channel_scale)
```

where `channel_scale` is the largest absolute sample of that feature's own
channel within the window. Two cases force that shape rather than a plain
relative tolerance:

- **A statistic that is exactly `0.0` in Python.** A constant channel has an SD
  of exactly zero under numpy's summation and about 1.4e-16 under sequential
  summation. A relative tolerance is zero there, so a correct implementation
  would fail.
- **A channel that lives far from 1.0.** `uacc_z` in the fixture sits around
  1e-8. A fixed absolute tolerance would pass on any value at all for it.

Agreement is **not** bit-for-bit. numpy sums with pairwise summation; the Swift
extractor sums sequentially. Over 200 elements the orders disagree in the last
ulp or two, and matching that would mean reimplementing numpy's block summation
on the watch — more code, more to get wrong, for a difference far below what any
sensor channel resolves.

The measured worst case on the committed fixture is **5.8e-15 relative**, on the
mean of a channel whose own mean sits near zero. The bound is ~1e-12, so the
check passes with roughly three orders of magnitude of headroom while still
failing every error class this file exists to catch:

| Mistake | Relative error it produces |
|---|---|
| `ddof = 1` instead of `0` | ~2.5e-3 |
| Nearest-rank instead of linear percentile | ~1e-2 and up |
| One-pass SD on the gravity channels | catastrophic, sometimes `NaN` |
| Channel-blocked instead of stat-major layout | order 1 |

**A parity failure is never a rounding question.** If this test fails, the two
implementations disagree about the contract. Do not widen the tolerance.
