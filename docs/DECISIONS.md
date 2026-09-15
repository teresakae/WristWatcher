# Decisions

Dated log of decisions that change this app's behavior or contracts. Newest
first within a date. A platform-facts change belongs in the thesis repo first,
then here as a re-derivation, not as the original decision.

---

## 2026-09-15 — D0 bootstrap

**Summary-only transfer to the iPhone companion.** The watch pushes a session
summary (class counts, non-neutral duration, timestamps) rather than raw
feature vectors or CSV. The companion is history, not a second data store —
raw channels never leave the watch's local storage for this app, unlike the
collector, which exists specifically to export raw CSV. Keeps the companion
thin and keeps participant-adjacent volume data off a second device.

**Debounce + cooldown haptic policy.** A single haptic firing on non-neutral
posture needs both a debounce (require N consecutive non-neutral window
classifications before firing, so one noisy window doesn't buzz the wrist) and
a cooldown (suppress re-firing for a fixed interval after a haptic, so a
sustained non-neutral posture doesn't buzz continuously). Exact constants for
both are not decided — D0 ships no haptic code.

**Read-only companion.** The iPhone app only displays session history; it
never sends commands back to the watch. Mirrors the collector's watch-only
control decision — the phone is not a remote.

**Model-independent-first sequencing.** The phases (see [README.md](README.md))
build the pipeline scaffold — sensing, windowing, feature vector, transfer —
before the Core ML model is wired in, so pipeline bugs aren't confused with
model bugs. The model is trained offline against the collector's data and
dropped in once the vector shape is proven.

**`transferFile` → `transferUserInfo` divergence from `b3-bab3.tex`'s alignment
matrix.** The thesis's architecture-alignment matrix (`b3-bab3.tex`) lists
`transferFile` for the watch→phone summary push, matching the collector's raw
CSV transfer. This app instead uses `transferUserInfo`, because the payload is
a small dictionary (counts and timestamps), not a file — `transferFile` exists
for exactly the case this app doesn't have. `b3-bab3.tex` needs a dated
correction; not made here, since this repo doesn't own that file.

**Unit-test target added at D0, not later.** The collector's own P4 discovered
that adding an XCTest target after other work is underway means hand-editing
`project.pbxproj` by hand. D0 adds the (empty) target now, while the project is
otherwise empty and a mistake costs nothing.

---

## 2026-09-15 — D2 feature contract

**[`FEATURE-CONTRACT.md`](FEATURE-CONTRACT.md) created, and it is the authority
for the 36-feature vector.** D0 deferred it because D0 shipped no feature code;
D1 shipped `RingBuffer` with no real length or stride for the same reason. D2
needs it, so it exists now: 9 channels in the collector CSV's column order, the
4 statistics of `features.DEFAULT_STATS`, stat-major / channel-minor layout,
population SD with `ddof = 0`, and numpy's `method="linear"` percentile.

**Window frozen at 200 samples / 100 stride (2.0 s, 50% overlap at 100 Hz).**
Carried over from `research/pipeline-design-decisions.md` §2.1, which chose 2.0 s
from the NinaPro DB5 sweep explicitly without sight of the author's own data. It
is frozen rather than left configurable because D2 is an exactness argument and
an unfrozen window has nothing to be exact about. A later sweep on own data may
move it; that is a contract change, and the D5 model must be retrained at the
new value. The model and the contract are a matched pair.

**The parity check runs the thesis code, it does not reimplement it.**
`tools/parity_fixture.py` imports `features.py` and `windowing.py` from the
thesis repo by path and executes them, then writes the expected vectors as a
fixture that `FeatureParityTests` replays through `RingBuffer` and
`FeatureExtractor`. A Python reimplementation living in this repo would be a
third thing to keep in sync, and agreement between two copies of the same
misunderstanding is not evidence.

**Parity is asserted to ~1e-12 relative, not bit-for-bit.** numpy sums pairwise,
Swift sums sequentially; the measured worst-case disagreement is 5.8e-15
relative. Every mistake the contract guards against is 1e-3 or larger, so the
bound separates them by orders of magnitude. See `FEATURE-CONTRACT.md` §7.1.

**No scaling on device.** The converted Core ML object is the whole sklearn
`Pipeline(StandardScaler -> estimator)`, so the fitted scaler constants ship
inside the model. The Swift extractor emits raw features; normalizing on device
would scale twice.

**A non-finite window is dropped, never imputed.** Mirrors the trust boundary at
`features.py` line 75. Zero-filling or carrying the last good vector forward
would fabricate an observation, and the haptic would fire on it.
