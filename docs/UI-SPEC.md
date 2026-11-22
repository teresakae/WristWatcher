# UI spec

Owned here, load-bearing — the views cite this, not the other way around.
Derived from `thesis/research/watcher-ui-design.md`, which is the argument;
this is the single place the screen inventory lives. It carries the design's
decisions and its exclusions, not its reasoning — see the design doc for why.

---

## 1. The Always-On correction

`HKWorkoutSession` keeps the watch app frontmost in Always-On Display. The
screen is not off during a session — it's dimmed, showing this app's UI, for
the whole session. Consequences, all implemented in `RunningView`:

- `@Environment(\.isLuminanceReduced)` drives layout.
- Elapsed time comes from `TimelineView`, never a hand-rolled `Timer`:
  `.periodic(from: startedAt, by: 1)` when bright, `.everyMinute` when dimmed.
- Dimmed shows minutes only — no seconds field, not a hidden or stale one.
- Stop is hidden when dimmed. A tap wakes the display first, so the control
  is one interaction away regardless.

## 2. watchOS — screen inventory

`RootView` switches on `SessionEngine.SessionState` (`idle` / `running` /
`finished`). No `NavigationStack`, no `TabView`.

| Screen | Content |
|---|---|
| `IdleView` | "Ready" status. Full-width `.borderedProminent` Start, `.handGestureShortcut(.primaryAction)` — Start only, never Stop. Blocked state (motion unavailable / HealthKit denied / no companion): disabled control + one sentence naming the cause, from `SessionEngine.blockedReason`. Optional fixed last-session time (`Last: 14:05`). Two small links below: Latency test and Test mode. Test mode is a test-only setting for black-box cases: it picks a scripted replay classifier from a fixed preset list (persisted as `testPreset`, default Real model) and shows an orange `Test: <name>` line under Start while active. |
| `RunningView`, bright | Elapsed, largest element, `.monospacedDigit()`. `#if DEBUG` raw sample count, tertiary. No label, no counts. Stop, `.bordered` + `.tint(.red)` — not prominent, since the app doesn't want the session stopped. |
| `RunningView`, dimmed | Minutes only. Stop hidden. |
| `SummaryView` | "Ended by system" line when flagged, duration, time and percent of classified time per activity ("No data" when nothing was classified), transfer state (`Waiting to send` / `Sent to iPhone` / `Couldn't send` — never implies arrival before it's confirmed; on failure it shows the error and a Send again button, and retries when the app becomes active). Measured Hz moved here as a de-emphasized recording-detail row — it's a gate readout, not product UI. Done returns to idle via `SessionEngine.dismissSummary()`. |

Not present, each already settled in the design (§2.2): live activity label,
chart, sparkline, progress ring.

### 2.1 Haptics

None. The posture-era alert cue and its `HapticController` were removed
2026-11-21 (DECISIONS.md). Times read "59 s" below a minute, "1 min 0 s" from 60 s.

## 3. iOS — screen inventory

`NavigationStack` → `HistoryListView` (in `ContentView.swift`) → pushes
`SessionDetailView`. Read-only throughout — no control reaches the watch.

| Screen | Content |
|---|---|
| List | One row per stored session (SwiftData, newest first): date + duration leading, with an "Ended by system" tag when flagged; dominant activity ("No data" if none) trailing. `ContentUnavailableView` when empty — native empty-state layout, one sentence that sessions appear after finishing on the watch. No pull-to-refresh; delivery is push-based. Title "Sessions", large. |
| Detail | `List`, `.insetGrouped`, every row `LabeledContent`. Session (started/ended/duration, ended by system). Activity (time and percent per activity). Timeline (Swift Charts, one `BarMark` per segment, coloured by activity; only when segments exist). Recording (measured Hz, model identifier, app version). Diagnostics — present only when `invalidationReason` is non-nil. Title inline, the session's date/time. |

The list is a SwiftData `@Query` sorted by `startedAt`, newest first. A session
re-delivered with the same `sessionId` replaces its row (`StoredSession.upsert`).

## 4. Accessibility

- Elapsed time: explicit `.accessibilityLabel("N minutes M seconds")` (or
  minutes-only when dimmed) — VoiceOver reads `12:30` as a time of day
  otherwise.
- Watch label/value rows: `.accessibilityElement(children: .combine)`, one
  utterance per row. iOS gets this free from `LabeledContent`.
- Dynamic Type: no fixed heights on text rows; each watch screen is wrapped
  in a `ScrollView` so the Digital Crown works at AX sizes.
- Semantic colors only, everywhere. No hardcoded hex, no hand-rolled
  materials — watchOS 26's Liquid Glass arrives free on system controls.

## 5. Explicitly not in the UI

Charts or plots on the watch · a settings screen on either target · a
progress ring · live posture class · any phone control that affects the
watch · pull-to-refresh · custom materials or
hand-built glass · a launch screen animation.
