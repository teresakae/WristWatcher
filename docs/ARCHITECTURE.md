# Architecture

The map, not the schema — no code exists yet (D0). This is what D1 onward
builds toward.

---

## 1. What the app is

A watch app that classifies wrist posture in near-real-time and tells the
wearer when it's wrong. Start a session, and the pipeline runs continuously
until it's stopped:

```
CMDeviceMotion @ 100 Hz ──> sliding window ──> 36-feature vector
        ──> Core ML binary classifier (neutral / non-neutral)
        ──> debounce + cooldown ──> haptic on non-neutral
```

At session end, a summary (not raw data) transfers to the iPhone companion for
history.

## 2. State flow

Simpler than the collector's — there is no protocol to sequence, no operator
audit gate, no bout order. One session type, start to stop.

```
IDLE ──> RUNNING ──> STOPPED ──> transfer summary ──> IDLE
```

`RUNNING` is where the pipeline above executes continuously. `STOPPED` ends
the `HKWorkoutSession`, finalizes any session-local state, and hands off to
transfer.

## 3. The hot path

**The 100 Hz `CMDeviceMotion` callback, on a background `OperationQueue`,
never the main queue.** This app's hot path does more than the collector's: it
still accumulates raw samples, but it also maintains the sliding window,
computes the 36-feature vector at each window slide, and runs the Core ML
forward pass — all inside the same CPU budget that the collector spends only
on file writes and an audit accumulator. Sustained high CPU is a documented
cause of runtime-session cancellation (see
[HKWorkoutSession constraints](#5-hkworkoutsession) below), so this budget is
the central engineering constraint of the whole app, more so than for the
collector.

Exact windowing (length, stride, per-channel statistics) is owned by
`docs/FEATURE-CONTRACT.md`, not written yet — D0 ships no feature code.

## 4. Haptic policy

Debounce + cooldown, per [DECISIONS.md](DECISIONS.md) 2026-09-15. Constants not
yet chosen. No haptic code in D0.

## 5. HKWorkoutSession

Unchanged from the collector — see the collector's
`docs/ARCHITECTURE.md` §6 for the full constraint list (CPU headroom, 100 Hz as
a ceiling, Low Power Mode, the `HKWorkoutActivityType.other` / finish-without-
saving ethics detail). The account is paid (team `P23A73L3J8`); the
`WKExtendedRuntimeSession` fallback is dead for this app for the same reason it
is dead for the collector.

## 6. WatchConnectivity handoff

`transferUserInfo`, not `transferFile` — see
[DECISIONS.md](DECISIONS.md) 2026-09-15 for why this diverges from the
thesis's alignment matrix. The payload is a session summary: class counts,
total non-neutral duration, start/end timestamps, `measured_hz`. No raw
channels, no feature vectors — this app does not export data the way the
collector does.

**Read-only companion.** The phone displays history; it never commands the
watch. No ACK protocol is needed the way the collector's is, because there is
no file whose safe deletion depends on confirmed receipt — the summary is
small enough to just resend if a transfer is lost, and `transferUserInfo`
already queues and retries.

> ⚠️ **The Simulator supports neither `HKWorkoutSession` nor
> `transferUserInfo`.** Every phase gate for this app is a physical-device
> gate, same as the collector.

## 7. File inventory (target, not yet built)

| File | Target | Holds |
|---|---|---|
| `WristWatcherApp.swift` | watch | app entry |
| `SessionEngine.swift` | watch | start/stop state, `HKWorkoutSession` |
| `MotionPipeline.swift` | watch | `CMDeviceMotion` @ 100 Hz, sliding window, feature vector |
| `Classifier.swift` | watch | Core ML model load + forward pass |
| `HapticPolicy.swift` | watch | debounce + cooldown |
| `Transfer.swift` | watch | `WCSession`, summary push |
| `ContentView.swift` | watch | session UI |
| `PhoneApp.swift` | iOS | entry + session history list |
| `Receiver.swift` | iOS | `WCSessionDelegate`, summary persistence |

D0 ships stock template files only; this table is the D1+ target, not current
state.

## 8. Phases

See [README.md](README.md) for the D0–D6 phase table and gates.
