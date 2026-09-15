# Agent rules for this repo

## What this repo is

The **deployment app** for a watchOS/iOS thesis study on wrist-posture
classification. A watch app that samples `CMDeviceMotion` at 100 Hz, computes a
36-feature vector over a sliding window, runs an on-device Core ML binary
classifier (neutral / non-neutral), fires one haptic on non-neutral posture, and
pushes a session summary to an iPhone companion for history. See
[README.md](README.md) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

It is **not** the collector. The collector
(`~/Documents/Personal/WristWatch`) is a separate app in a separate repo that
records raw CSV under a scripted protocol. Read from it; never write to it.

## Hard rules

### Never commit, never push, never touch git history

The student commits. This is absolute — no `git commit`, no `git push`, no
`git rebase`, no `git reset`, no history rewriting, no branch deletion, not
even when asked to "save progress". Stage nothing. Show the diff and stop.

### No participant data in this repo, ever

No CSVs, no sidecars, no session videos, no photographs, no consent forms, no
participant IDs paired with anything identifying.

`.gitignore` blocks `data/`, `*.csv`, `*.mov`, `*.mp4`, `*.jpg`, `*.jpeg`,
`*.heic`, `*.xcappdata/`, `.DS_Store`, `xcuserdata/`, `*.mlmodel` and
`*.mlmodelc` from the first commit. **Do not relax those rules, do not add
negation patterns, do not `git add -f` past them.** If a test needs sample
data, generate it synthetically.

### Do not invent platform facts

If something is not in [docs/PLATFORM-FACTS.md](docs/PLATFORM-FACTS.md) or in
`thesis/research/`, it is **unknown**. Write "unknown" and say what would
settle it. Do not fill the gap with a plausible-sounding API detail, version
number, or plist string.

## The thesis repo is authoritative

The study lives at `~/Documents/Personal/thesis`. This repo is its sibling, not
a submodule. A platform-facts change is made in the thesis repo **first**, then
re-derived here. `docs/PLATFORM-FACTS.md` is a **banner-stamped snapshot**, not
a source. If the two disagree, the thesis repo wins and the snapshot is stale.
Never edit a snapshot to resolve a disagreement.

`docs/FEATURE-CONTRACT.md` is **owned here and load-bearing**: it is the single
authority for the 36-feature vector — the window length, the stride, the
per-channel statistics, and their order into the Core ML input. The Swift
feature extractor cites it; the Python training pipeline cites it; neither
cites the other. Changing it is a contract change: edit it, add a dated line to
`docs/DECISIONS.md`, then update both sides. (Not yet written — D0 has no
feature code. Created when D1 needs it.)

## Settled — do not re-derive

Carried over unchanged from the collector's own settled facts (see
[docs/PLATFORM-FACTS.md](docs/PLATFORM-FACTS.md)):

1. **`CMMotionManager.isGyroAvailable` is false on real hardware.** The nine
   channels come from `CMDeviceMotion` — `gravity`, `userAcceleration`,
   `rotationRate`.
2. **The runtime session is `HKWorkoutSession`** + `WKBackgroundModes =
   workout-processing`, not `WKExtendedRuntimeSession`. The account is paid
   (team `P23A73L3J8`); the `WKExtendedRuntimeSession` / `physical-therapy`
   fallback is dead. Do not reintroduce it as a live option.
3. **100 Hz is a ceiling, not a guarantee.** Every row carries a real
   timestamp; a shortfall is a finding, not a bug to chase.
4. **CPU headroom is the real 100 Hz risk, not the session type.** The hot
   path — the 100 Hz motion callback — runs on a background `OperationQueue`
   and stays O(1) per sample: no allocation, no sorting, no formatting, no
   locks, nothing on the main queue. This applies doubly here: this app also
   runs the feature computation and the Core ML forward pass in that same
   budget.

## One repo, two apps

The original plan put this app in a different repo from the collector; that
changed on 2026-09-13, then changed back — this is its own repo, sibling to the
collector, not a branch of it. See `thesis/research/` for the current account
of why. Bundle IDs are `com.kae.WristWatcher` (iOS) /
`com.kae.WristWatcher.watchkitapp` (watch), distinct from the collector's
`com.kae.WristWatch`, so both can be installed on the same devices
simultaneously — the D0 gate requires exactly that.

## Out of scope (this phase, D0)

D0 is repo and Xcode-project bootstrap only. Do not add:

- Any sensor code, `CMDeviceMotion` handling, or feature extraction
- The Core ML model, model loading, or inference
- Haptic cueing
- `WatchConnectivity` transfer logic
- A settings screen, SwiftData, custom retry backoff, phone remote control

Each later phase (D1–D6) states its own scope when it starts. Do not start a
phase before its predecessor's gate is confirmed passed on physical hardware.

## Working style

- The student is semi-technical: reads code, rarely writes it. Lead with what a
  change does, then the internals.
- Every phase gate is a **physical-device gate**. The Simulator supports
  neither `transferUserInfo` nor `HKWorkoutSession`, so anything touching
  either is unverifiable there.
- The hot path is a 100 Hz motion callback on a background `OperationQueue`.
  Keep it O(1) per sample.
