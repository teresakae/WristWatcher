> ⚠️ SNAPSHOT — not the source of truth.
> Derived from `thesis/research/FACTS.md` and the collector's own
> `docs/PLATFORM-FACTS.md` as of 2026-09-15.
> The thesis repo is authoritative. If the two disagree, the thesis repo wins
> and this file is stale. Re-derive before a session with the deployment app.

# Platform facts

App-relevant rows only, carried over from the collector where they are shared,
plus the rows specific to this app (Core ML path). Anything not on this page
and not in `thesis/research/` is **unknown** — write "unknown", don't guess.

---

## Sensing

| Fact | Value |
|---|---|
| **Sensor channels** | `CMMotionManager.isGyroAvailable` is **false on real hardware**. The feature vector is built from `CMDeviceMotion` — `gravity` / `userAcceleration` / `rotationRate` — giving **9 channels** → 36 windowed features on the Watch arm. |
| **Sample rate** | 100 Hz requested. A ceiling, not a guarantee; the achieved rate is measured per session from the timestamps and reported. |
| **Runtime session** | `HKWorkoutSession` + `WKBackgroundModes = workout-processing`. **Not** `WKExtendedRuntimeSession` — the `self-care` type was tested on hardware and invalidated at ~10 min, shorter than a session; the fallback is dead. |

These are settled. Do not re-derive them, and do not "fix" the `gyro_*`
naming convention this app inherits from the collector's frozen contract —
the data behind it is `rotationRate`.

## Core ML path

| Fact | Value |
|---|---|
| **Training stack** | scikit-learn 1.5.1 + `coremltools`. |
| **Model selection** | Restricted to the set of scikit-learn estimators `coremltools` can export — this bounds which classifiers are eligible before any accuracy comparison happens. |
| **Task** | Binary: neutral vs. non-neutral. The collector's three cued classes (neutral / extension / ulnar) collapse to two at inference time; the collection-time labels stay three-way. |

## Account and signing

| Fact | Value |
|---|---|
| **HealthKit gating** | HealthKit is gated behind the **paid** Apple Developer Program; Background Modes and App Groups are not. `HKWorkoutSession` needs HealthKit. **Account tier is confirmed paid** (team `P23A73L3J8`). |
| **Provisioning** | Paid-account provisioning lasts a year; the 7-day free-provisioning expiry does not apply. |
| **Bundle IDs** | `com.kae.WristWatcher` (iOS companion) / `com.kae.WristWatcher.watchkitapp` (watch), distinct from the collector's `com.kae.WristWatch` — both apps install side by side on the same devices. |

## Now known, moved out of "unknown"

- **`WKBackgroundModes` plist string** — confirmed as the literal
  `workout-processing`, written into the built binary's Info.plist for the
  watch target (D0).
- **Watch hardware** — the development device is an Apple Watch Series 11
  (46 mm).

## Not in this file — treat as unknown

Anything not on this page and not in `thesis/research/` is unknown. In
particular: the exact classifier family the exported Core ML model uses (not
chosen yet — D0 ships no model), the achieved on-device inference latency, and
the haptic debounce/cooldown timing constants (decided at plan time, see
[DECISIONS.md](DECISIONS.md), but not yet implemented or measured).
