# Iteration 3 plan: from posture app to activity-minutes app

Status: plan only, nothing built. Needs the student's go-ahead (new files, 3+ files touched).

## 1. Parity result

Gate run 2026-11-21: 236 windows (4 scripted P1 blocks, one per activity) went through the Python pipeline (`lib/features.py`) and the app's `FeatureExtractor` + `RingBuffer`, compiled unchanged on macOS. Max absolute difference 4.4e-16; max relative difference 1.1e-13. Label disagreements: 0 of 236 for the sklearn pipeline (scikit-learn 1.5.1), 0 of 236 for `logreg.mlmodel` (coremltools predict), and Core ML vs sklearn also 0. **PASS.**

What matches: window 200 samples, step 100, no partial window; channel order grav, uacc, gyro (x, y, z); stat-major layout (all means, then SD, p25, p75); SD is population (ddof 0); percentile is numpy "linear"; units g and rad/s on both sides (CMDeviceMotion natively; Sensor Logger exports the same); input names equal `meta.json` `coreml_input_names`.

**One thing must change, and it is not the extractor:** `SessionEngine.handleEnrollmentResult` subtracts a gravity anchor from `grav_x/y/z` before the window. The model was trained on raw gravity (no anchor anywhere in `session_loader.py`, `run_lopo.py`, `train_final.py`). Left in, the app feeds the model shifted gravity features and still returns confident labels. It goes (section 2). `FEATURE-CONTRACT.md` section 5 (anchor) must be edited and a dated line added to `DECISIONS.md`, as the repo rules require. The extractor needs no fix.

Caveat: window = 200 delivered samples, not 2 s of clock. If the watch delivers under 100 Hz, one window is longer than 1 s and "1 window = 1 s" drifts. Training had the same property. The summary keeps `sampleRateHz` so this can be checked.

## 2. Watch (FR-1 to FR-6)

What the person sees: Idle (Start) -> Running (elapsed time and Stop only; no label, no haptic, no count) -> Summary (per-activity time, percent, transfer state, Done).

| FR | Change |
|---|---|
| FR-1 | Start goes straight to running: no 10 s enrollment hold. State enum becomes idle / running / finished. |
| FR-2 | Stop ends the session. If the system ends the workout session (`WorkoutKeepAlive` already records an unexpected end), the engine now finishes on its own: builds the summary with `endedBySystem = true`, sends it, shows the Summary with a "Ended by system" line. Today it would stay on the Running screen. |
| FR-3 | New `ActivityClassifier` (4 labels via `logreg.mlmodel`, output `label`, input = the 36 named doubles). One window = one label. |
| FR-4 | Engine keeps seconds per label and extends or opens a segment per label. |
| FR-5 | Summary shows each activity's time and percent of classified time, the total and session duration, and the transfer state. |
| FR-6 | `Transfer.send` already uses `transferUserInfo`, which queues and retries across launches while the phone is unreachable. Keep. Delivery confirmation (`didFinish`) sets "Sent". Do not change. |

Delete: `Enrollment.swift`, `EnrollmentView.swift`, `HapticController.swift`, `PostureClassifier.swift`, `CoreMLPostureClassifier.swift`, `ship_logreg_binary.mlmodel`, the anchor and haptic code in `SessionEngine`, the alert badge in `RunningView`, the enrollment message in `IdleView`, and the tests `EnrollmentTests`, `HapticControllerTests`. Keep: `FeatureExtractor`, `RingBuffer`, `MotionSampler` (its `sampleFilter` hook stays unused or is dropped), `WorkoutKeepAlive` (gains an "ended unexpectedly" callback), `LatencyHarness` and its models.

Replace: `ActivityClassifier.swift` (protocol `classify(_ features: [Double]) -> Activity?` plus `ReplayClassifier`), `CoreMLActivityClassifier.swift` (loads `logreg`, reads `label`).

Replay mode (promised in Chapter 3 for black-box tests): `ReplayClassifier` returns a scripted sequence such as `typing*30,mouse*20,rest*10` given by an Xcode scheme launch argument (`-replayScript`), one label per window. No settings screen, no visible toggle. The sensors still run so windows tick. When the script runs out it repeats the last label.

## 3. Data model

New `SessionSummary` (in `SessionSummary.swift`, already shared by both targets, so no project-file edit):
`schemaVersion` (2), `sessionId`, `startedAt`, `endedAt`, `endedBySystem`, `secondsByActivity` ([raw label: Int]), `segments` ([start s, end s, activity], seconds from session start), `sampleRateHz`, `modelIdentifier`, `appVersion`, optional `batteryStart` / `batteryEnd` (section 7). `Activity` enum lives in the same file: raw values equal the model labels (`typing`, `mouse`, `writing`, `rest`); display names Typing, Mouse, Handwriting, Rest.

Old posture summaries: ignored. The iPhone stores under a new key (`receiver.summaries.v2`); the old key is removed on first launch. No migration. Stated trade-off: any posture-era sessions on the phone disappear (there should be none that matter).

Storage note: Chapter 3's figure says SwiftData and Swift Charts; the app uses UserDefaults JSON. Recommendation: keep UserDefaults (six participants, one session each) and change the figure text to "stored on the phone". Swift Charts is built in, so the timeline uses it as written. Your call.

## 4. iPhone (FR-7 to FR-10)

- FR-7: `Receiver.add` already removes any summary with the same `sessionId` before inserting, so a re-delivered session replaces itself (confirmed in code). Add a test.
- FR-8: history row = date, duration, dominant activity name (most seconds; ties follow typing, mouse, writing, rest; no data shows "No data"). A "Ended by system" tag when flagged.
- FR-9: detail = per-activity minutes and percent, plus a segment timeline (one horizontal bar, Swift Charts `BarMark` per segment, coloured by activity), plus the session facts and diagnostics.
- FR-10 (optional): **out for Iteration 3.** No RQ and no Table-3.1 test case depends on it, and it is about 50 lines that can still be added last. Marked "not implemented" in Chapter 4 if left out.

## 5. Labeling choices to confirm

1. First label arrives about 2 s after Start (first full window). Recommended: window i counts as 1 s for the second it ends in, so the first second is unclassified. Total classified seconds = duration minus 1 s; percent = share of classified seconds. A 1 s session has no data.
2. One window = one second, matching the MAE method in Chapter 3 (each window counted as 1 s).
3. Segments are consecutive runs of the same label, built from window counts, not from timestamps.
4. Percent is rounded to whole numbers and may add to 99 or 101.
5. Time format: under 60 s shown as "59 s", from 60 s as "1 min 0 s". The 59/60/61 test cases refer to classified seconds of one activity. Confirm.
6. Display names Typing, Mouse, Handwriting, Rest (model label "writing" displayed as Handwriting).

## 6. Black-box checklist (all via replay mode unless noted)

| FR | Steps | Expected |
|---|---|---|
| FR-1 | Tap Start | Running screen within 1 s; no enrollment screen; motion updates running (sample count rising in a debug build) |
| FR-2a | Start, tap Stop | Summary appears, endedBySystem false |
| FR-2b | Start, force the workout session to end (turn Health permission off mid-run, or end the workout from the system) | Summary appears with "Ended by system"; the session reaches the phone flagged |
| FR-3 | Script 10 x typing | 9 classified seconds (first second unclassified) or as decided in section 5, all typing |
| FR-4 | Script typing*20, mouse*10, typing*5 | seconds 25 / 10; three segments in order |
| FR-5 | Boundaries: 0, 1, 59, 60, 61 classified seconds; one activity; mixed order | No data / seconds below 60, minutes from 60; percents match; transfer state visible |
| FR-6 | Phone off or Bluetooth off, finish session, switch phone back on | Summary says waiting; after the phone is reachable it arrives and the watch says Sent |
| FR-7 | Deliver the same session twice (re-send) | One row on the phone |
| FR-8 | Three sessions with different dominant activities | Rows show the right activity, newest first |
| FR-9 | Open the mixed session | Minutes and percent per activity; timeline segments match the script |
| FR-10 | Optional, not implemented | - |
| Size | Script alternating typing,mouse every second for 600 s | Session still arrives on the phone (checks the transfer payload size) |

## 7. Battery test

Procedure from Chapter 3: three 60-minute sessions, each from a full charge, report percent per hour. App support: an optional `batteryStart` and `batteryEnd` in the summary (`WKInterfaceDevice` battery level, already read the same way in `LatencyHarness`), shown on the phone detail only. It is a measurement, not live feedback. Resolution of the watch battery level is unknown until read on the device; if it is coarse, the manual reading from the watch battery screen at start and end is the fallback. Do the test on a Release build, watch screen off, one activity typed or mixed at the desk, same watch.

## 8. Build order (each step ends in a build that compiles)

| # | Step | Files | Diff |
|---|---|---|---|
| 1 | New `Activity`, `Segment`, `SessionSummary` v2; update the two iOS views and `Receiver` key so both targets build | SessionSummary, Receiver, ContentView (iOS), SessionDetailView (iOS), SessionSummaryTests | ~150 lines |
| 2 | 4-class classifier + replay classifier; drop binary model | ActivityClassifier, CoreMLActivityClassifier (new); PostureClassifier, CoreMLPostureClassifier, ship_logreg_binary deleted | ~120 |
| 3 | Engine: remove enrollment, anchor, haptics; accumulate seconds and segments; system-end handling | SessionEngine, WorkoutKeepAlive, ContentView (watch); delete Enrollment*, HapticController and their tests; update SessionEngineTests | ~250, mostly deletions |
| 4 | Watch screens: Running without alerts, Summary with per-activity rows | RunningView, SummaryView, IdleView | ~120 |
| 5 | iPhone history row and detail with timeline | ContentView (iOS), SessionDetailView | ~150 |
| 6 | Battery fields (if you want them) | SessionEngine, SessionSummary, SessionDetailView | ~25 |
| 7 | Docs: FEATURE-CONTRACT section 5 edit, DECISIONS line, ARCHITECTURE/UI-SPEC/CLAUDE.md wording (haptics, posture) | docs | text |
| 8 | Run the section 6 checklist; battery runs | none | - |

Risks: the `.mlmodel` files are git-ignored, so the shipped `logreg.mlmodel` must be backed up with `meta.json` (its hash goes in `DECISIONS.md`); SessionEngineTests drive enrollment today and need a rewrite; `transferUserInfo` payload size limit is unknown (hence the 600-segment test); the unexpected-end callback runs off the main queue and the engine must finalize once only (stop and system end can race).
