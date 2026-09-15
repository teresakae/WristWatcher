# WristWatcher

The **deployment app** for a watchOS thesis on wrist-posture classification.
On a live session it samples `CMDeviceMotion` at 100 Hz, slides a fixed window,
computes a 36-feature vector, runs an on-device Core ML binary classifier
(neutral / non-neutral), fires one haptic when posture goes non-neutral, and
pushes a session summary to an iPhone companion for history.

It is **not** the collector. The collector
(`~/Documents/Personal/WristWatch`) is a separate app in a separate repo that
records raw CSV under a scripted recording protocol for training data. This
app is what a wearer runs day to day; it reads nothing from the collector's
data and writes nothing back to it.

## Hardware

- Apple Watch Series 11 (46 mm) — development device
- A paired iPhone
- A Mac with Xcode

**Every phase gate below is a physical-device gate.** The Simulator supports
neither `transferUserInfo` nor `HKWorkoutSession`, so nothing that depends on
either is verifiable there — sensing continuity, the workout session staying
alive with the wrist down, or the watch↔phone handoff.

## Phases

| Phase | Builds | Gate |
|---|---|---|
| **D0** | Repo, Xcode project, three targets (iOS, watch, watch unit tests), capabilities, no app code | Both targets build and install to the physical watch and iPhone **alongside the already-installed collector**, and launch. `WKBackgroundModes` and the HealthKit entitlement are present in the built binary. The empty test target runs and reports zero tests. |
| **D1** | Continuous `CMDeviceMotion` sampling through a `HKWorkoutSession`, ring buffer emitting fixed-length windows. No features, no model, no haptics. | 10 continuous minutes on hardware, wrist down, screen off. Session stays alive, no invalidations logged, window count matches the expected count from sample count, `measuredHz` is reported. |
| **D2** ⚠️ | The Swift 36-feature extractor, built to reproduce the thesis's Python feature pipeline exactly. A correctness argument, not just an implementation. | `tools/parity.py` passes on a full collector rehearsal CSV, every window, worst-case difference inside tolerance. `docs/FEATURE-CONTRACT.md` lists all 36 feature names in order. |
| **D3** | Haptic controller and firing policy (debounce + cooldown), driven by a stub classifier — no Core ML yet. | On hardware, with the scripted classifier: fires after N consecutive non-neutral windows, does not repeat inside cooldown, fires again after. Unit test covers the N−1 boundary. |
| **D4** | Session summary, its transfer (`transferUserInfo`), and the read-only iPhone history UI. | Start/stop a session on the watch; the summary appears in phone history with a plausible duration, window count and rate — including across a phone-app force-quit and relaunch. |
| **D5** 🔒 | Swap the stub classifier for the real Core ML model. **Blocked** until collection finishes and a model is selected from the Core ML-exportable set. | A recorded session's windows replayed through the Python model and the on-device model match, window for window. Latency measured on hardware. |
| **D6** | The functional-requirement spec and the black-box test that verifies it — the artefact half of RQ3. | Every FR in `REQUIREMENTS.md` has at least one case in `TEST-CASES.md`; cases executed on hardware with the observed column filled in. |

Do not start a phase before its predecessor's gate is confirmed passed on
physical hardware.

## Docs

- [CLAUDE.md](CLAUDE.md) — agent rules for this repo
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — state flow and pipeline
- [docs/PLATFORM-FACTS.md](docs/PLATFORM-FACTS.md) — banner-stamped facts snapshot
- [docs/DECISIONS.md](docs/DECISIONS.md) — dated decision log
