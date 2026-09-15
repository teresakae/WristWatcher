#!/usr/bin/env python3
"""Generate the Swift/Python feature-parity fixture.

    python3 tools/parity_fixture.py            # synthetic, rewrites the fixture
    python3 tools/parity_fixture.py <file.csv> # a real collector CSV, off-repo

This imports the thesis repo's `features.py` and `windowing.py` BY PATH and
runs them. It does not reimplement them, and it must never start to: a
reimplementation is a third thing to keep in sync, which is the exact failure
mode docs/FEATURE-CONTRACT.md exists to prevent. If the import fails, the fixture
is not regenerated -- there is no fallback path, deliberately.

Output (see FEATURE-CONTRACT.md section 7): a synthetic sample stream, the window
starts `windowing.window_indices` produced for it, and the 36-vector
`features.extract` produced for each. `FeatureParityTests` replays the same
stream through `RingBuffer` + `FeatureExtractor` and must reproduce all of it.

The committed fixture is synthetic and seeded. No participant CSV enters this
repo (CLAUDE.md), which is why the <file.csv> form writes its output next to the
CSV and never here.
"""

import json
import os
import sys
import tempfile
from pathlib import Path

import numpy as np
import pandas as pd

THESIS_LIB = Path(
    os.environ.get("THESIS_LIB", Path.home() / "Documents/Personal/thesis/pilot/analysis/lib")
).expanduser()

if not (THESIS_LIB / "features.py").exists():
    sys.exit(f"thesis lib not found at {THESIS_LIB}. Set THESIS_LIB to override.")
sys.path.insert(0, str(THESIS_LIB))

import features  # noqa: E402
import windowing  # noqa: E402

REPO = Path(__file__).resolve().parent.parent
FIXTURE = REPO / "WristWatcher/WristWatcher Watch AppTests/parity_fixture.json"

# FEATURE-CONTRACT.md sections 1 and 2. Named here rather than imported so that a
# drift between this script and the contract shows up as a failing parity run,
# not as a silently-agreeing pair.
WIN, HOP = 200, 100
CHANNELS = ["grav_x", "grav_y", "grav_z",
            "uacc_x", "uacc_y", "uacc_z",
            "gyro_x", "gyro_y", "gyro_z"]
CSV_COLUMNS = ["timestamp"] + CHANNELS + [
    "axis", "angle_deg", "transition", "corrupt", "segment_id", "segment_kind",
]

N = 850  # -> 7 windows at 200/100: starts 0, 100, ... 600


def synthetic_csv(path, seed=20260915):
    """A 16-column CSV per DATA-CONTRACT.md section 2.1, chosen to be hostile.

    Every channel targets a way the two implementations could disagree:

      grav_x  constant                 -- SD exactly 0, percentiles on ties
      grav_y  rounded to 3 dp          -- heavy ties, so s[lo] == s[lo+1] often
      grav_z  -1.0 +/- 1e-8            -- one-pass SD cancels catastrophically
                                          here and two-pass does not
      uacc_x  ordinary noise           -- the boring case
      uacc_y  1.3 Hz sinusoid          -- smooth, no ties, percentiles fully
                                          interpolated
      uacc_z  ~1e-8 magnitudes         -- denormal-adjacent, absolute
                                          tolerances would pass on anything
      gyro_x  wide-scale noise         -- large summands, ordering visible
      gyro_y  Laplace                  -- heavy tails, outliers far outside p25/p75
      gyro_z  10-sample plateaus       -- interpolation between equal neighbours
    """
    rng = np.random.default_rng(seed)
    t = 1789456320.0 + np.arange(N) / 100.0
    elapsed = t - t[0]
    df = pd.DataFrame({
        "timestamp": t,
        "grav_x": np.full(N, 0.2),
        "grav_y": np.round(rng.normal(0, 0.3, N), 3),
        "grav_z": -1.0 + rng.normal(0, 1e-8, N),
        "uacc_x": rng.normal(0, 0.05, N),
        "uacc_y": 0.4 * np.sin(2 * np.pi * 1.3 * elapsed),
        "uacc_z": rng.normal(0, 0.05, N) * 1e-7,
        "gyro_x": rng.normal(0, 2.0, N),
        "gyro_y": rng.laplace(0, 1.0, N),
        "gyro_z": np.repeat(rng.normal(0, 1.0, N // 10 + 1), 10)[:N],
        "axis": "neutral",
        "angle_deg": 0.0,
        "transition": 1,
        "corrupt": 0,
        "segment_id": 0,
        "segment_kind": "bout",
    })
    df[CSV_COLUMNS].to_csv(path, index=False)
    return path


def run(csv_path):
    """Read a 16-column CSV, window it, extract. Returns (samples, starts, X)."""
    df = pd.read_csv(csv_path)
    if list(df.columns) != CSV_COLUMNS:
        sys.exit(f"{csv_path}: header is not DATA-CONTRACT.md section 2.1 order.")

    signals = df[["timestamp"] + CHANNELS]
    meta = df[["segment_id"]].rename(columns={"segment_id": "bout"})

    channels = features.signal_channels(signals)
    assert channels == CHANNELS, f"channel order drifted: {channels}"

    wins = windowing.window_indices(meta, win=WIN, hop=HOP)
    X, _, names = features.extract(signals, meta, wins, channels)
    assert names == features.feature_names(CHANNELS, features.DEFAULT_STATS)
    assert X.shape[1] == 36, X.shape

    samples = signals.to_numpy().tolist()
    return samples, [i for i, _ in wins], X, names


def main():
    if len(sys.argv) > 1:
        csv_path = Path(sys.argv[1]).expanduser()
        out = csv_path.with_suffix(".parity.json")
        note = "real CSV -- written beside the CSV, never into this repo"
    else:
        tmp = Path(tempfile.mkdtemp()) / "synthetic.csv"
        csv_path = synthetic_csv(tmp)
        out = FIXTURE
        note = "synthetic, seeded"

    samples, starts, X, names = run(csv_path)

    out.write_text(json.dumps({
        "_generated_by": "tools/parity_fixture.py",
        "_contract": "docs/FEATURE-CONTRACT.md",
        "_source": note,
        "window_length": WIN,
        "stride": HOP,
        "feature_names": names,
        "columns": ["timestamp"] + CHANNELS,
        "samples": samples,
        "window_starts": starts,
        "expected": X.tolist(),
    }, indent=1))

    print(f"{out}")
    print(f"  {len(samples)} samples -> {len(starts)} windows x {X.shape[1]} features")
    print(f"  starts: {starts}")
    print(f"  layout: {names[0]} {names[1]} ... {names[8]} | {names[9]} ... ({len(names)})")


if __name__ == "__main__":
    main()
