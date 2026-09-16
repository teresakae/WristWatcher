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
`tools/parity.py` imports `features.py` and `windowing.py` from the
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

**D2 closes on real watch data, but not on a collector rehearsal CSV.** The gate
in [README.md](../README.md) asks for parity on a full collector rehearsal CSV.
No such file exists on this machine: `WristWatch/data/` is absent, and the three
`com.kae.WristWatch` app containers pulled on 2026-09-15 disappeared from
`~/Documents/Personal/WristWatch/` the same afternoon, before they could be read.

What D2 did run on is the August pilot-recorder corpus — 5 recordings, 1,166
windows, every one matching. That is real watch motion at the same nine channels
in the same order: real gravity near −0.998, real 100 Hz jitter, real `Double`
bit patterns. Its header is 12 columns, not the collector's 16, so `parity.py`
validates only the first ten (`timestamp` plus the nine channels) and ignores the
rest, none of which reaches a feature.

Remaining for a full gate: one collector-format rehearsal CSV through the same
command. Not a code change — a file that does not exist yet.

**The parity suite's window-grid check is single-bout only.** `windowing.py`
restarts its grid at each bout and refuses straddling windows; `RingBuffer` is
stride-aligned from the first sample and has no bout concept, correctly, because
a live wrist has no bouts. On the 7-posture August file that is 425 windows
against 433, with starts that do not align. Feature parity is therefore asserted
over Python's own window starts, and the grids are compared only where there is
one bout. See `FEATURE-CONTRACT.md` §7.2.

---

## 2026-09-15 — D3 haptic controller, closed on hardware

**Debounce + cooldown constants set:** `consecutiveWindowsToFire = 5`
(~5 s at the D2 contract's 200/100 windows), `cooldownSeconds = 30`,
`probabilityThreshold = 0.5`. `HapticPolicy` carries these; not yet exposed
as user-facing settings (out of D0's scope list, unchanged since).

**One preset, no graded cueing, is a platform limit, not a D3 simplification.**
watchOS has no Core Haptics — no custom waveforms — so there is no mechanism
to grade the cue by deviation size or duration even if wanted. This also
converges with `tuken2025`'s finding that multi-level cueing is
contraindicated, which is part of why the classifier output is binary in the
first place. Both belong in the thesis's Batasan Masalah.

**`ScriptedClassifier` stands in for the D5 Core ML model.** It ignores the
feature vector and returns a probability set directly — by a debug toggle in
`ContentView` for the hardware gate, by tests otherwise. `HapticController`
only ever sees a probability; D5 replaces the classifier type, not the
controller.

**D3 gate passed on hardware 2026-09-15.** Apple Watch Series 11 (46 mm):
scripted toggle held non-neutral, haptic fired on the 5th consecutive window;
re-toggling inside 30 s did not refire; past 30 s it fired again. Unit tests
(`HapticControllerTests`) cover the N−1 boundary, the same reset case, and
the cooldown/refire timing.

---

## 2026-09-15 — D4 session summary + transfer, closed on hardware

**`modelIdentifier = "scripted-v0"`** for every summary until D5 wires in the
real Core ML model's identifier. Distinguishes pre-model sessions from
post-model ones in phone history, since the thesis compares across model
versions.

**`Transfer.swift` reduced from the collector's**, not copied whole. The
collector's version (P2/P3) exists to move a file safely: queued/sent/acked
states, SHA-256 + byte-count metadata, one retry then fail. None of that
applies here — this app's own ARCHITECTURE.md §6 already calls for
`transferUserInfo`, not `transferFile`, because the payload is a small
dictionary, and `transferUserInfo` already queues and retries on its own. No
ACK: read-only companion, no file whose deletion depends on confirmed
receipt.

**D4 gate passed on hardware 2026-09-15.** Stopping a watch session produced
a row in the iPhone history list with model id, alert count, and
non-neutral/total window ratio.

---

## 2026-09-16 — UI pass, slotted between D4 and D5

**Ran between D4 and D5, against `thesis/research/watcher-ui-design.md` and
the new `docs/UI-SPEC.md` it's derived from.** No new capability: no Core ML,
no sensing change, no `HapticPolicy` arithmetic change. Both `ContentView`s
went from debug readouts to the real view hierarchy — `RootView` /
`IdleView` / `RunningView` / `SummaryView` on the watch,
`HistoryListView` / `SessionDetailView` on iOS.

**The D1 prompt's "wrist down and screen off" was wrong.** `HKWorkoutSession`
keeps the app frontmost in Always-On Display — the screen dims, it doesn't
turn off, for the whole session. See `watcher-ui-design.md` §1.1 and
`UI-SPEC.md` §1. `RunningView` now branches on `\.isLuminanceReduced` and
drives elapsed time off `TimelineView` (`.periodic` bright, `.everyMinute`
dimmed) instead of a `Timer`, dropping to minutes-only when dimmed.

**`SessionEngine.isRunning: Bool` replaced with a 3-case `SessionState`
(`idle` / `running` / `finished`).** `SummaryView` needed a real finished
state — inferring it from "not running" is also true before the first
session ever runs. `SessionEngine` also now retains `lastSummary` (was built
and dropped in `stop()`) and exposes `startedAt` and a `blockedReason`
computed property (motion unavailable / HealthKit denied / no companion) for
`IdleView`'s blocked state.

**`Transfer` gained a `queued`/`sent`/`failed` state**, set from the now-
implemented `session(_:didFinish:error:)` delegate call. `SummaryView`'s
transfer row reads it directly rather than implying the record has arrived
the instant `stop()` returns — `transferUserInfo` is eventual.

**The D3 debug toggle moved behind `#if DEBUG`,** off the primary flow, into
`IdleView`. It's still the only way to drive `ScriptedClassifier` before D5
has a real model, so D5's hardware gate must run a **Debug** build — that's
how it would be launched from Xcode anyway, not a new constraint in
practice.

**Haptic bookend cues (session-started / session-ended) are not wired.** The
design's §2.5 names three cues; only the middle one (`HapticController`'s
`.notification`) exists in code. Adding the bookends wasn't in this pass's
prerequisite list, so it's left as a documented gap (`UI-SPEC.md` §2.1)
rather than built quietly.
