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
| `IdleView` | "Ready" status. Full-width `.borderedProminent` Start, `.handGestureShortcut(.primaryAction)` — Start only, never Stop. Blocked state (motion unavailable / HealthKit denied / no companion): disabled control + one sentence naming the cause, from `SessionEngine.blockedReason`. Optional relative last-session date. `#if DEBUG` gate-driver toggle, de-emphasized, below Start — scaffolding, not a settings screen. |
| `RunningView`, bright | Elapsed, largest element, `.monospacedDigit()`. Alert count, secondary, with an SF Symbol. Stop, `.bordered` + `.tint(.red)` — not prominent, since the app doesn't want the session stopped. |
| `RunningView`, dimmed | Minutes only. Stop hidden. Alert count stays. |
| `SummaryView` | Duration, windows classified, non-neutral fraction, alerts fired, transfer state (`Waiting to send` / `Sent to iPhone` / `Couldn't send` — never implies arrival before it's confirmed). Measured Hz moved here as a de-emphasized recording-detail row — it's a gate readout, not product UI. Done returns to idle via `SessionEngine.dismissSummary()`. |

Not present, each already settled in the design (§2.2): live posture class,
chart, sparkline, progress ring.

### 2.1 Haptic vocabulary — partially implemented

The design's §2.5 names three cues: session-started, posture alert,
session-ended. Only the middle one exists in code (`HapticController`'s
`.notification`, per `HapticPolicy`'s debounce + cooldown). The start/stop
bookend cues are documented intent, not wired — they weren't in this pass's
scope (view rendering + the four `SessionEngine`/`Transfer` prerequisites),
so they're noted here as a gap rather than added quietly.

## 3. iOS — screen inventory

`NavigationStack` → `HistoryListView` (in `ContentView.swift`) → pushes
`SessionDetailView`. Read-only throughout — no control reaches the watch.

| Screen | Content |
|---|---|
| List | One row per summary: date + duration leading, non-neutral fraction (the one number a row scanned at arm's length supports) trailing. `ContentUnavailableView` when empty — native empty-state layout, one sentence that sessions appear after finishing on the watch. No pull-to-refresh; delivery is push-based. Title "Sessions", large. |
| Detail | `List`, `.insetGrouped`, four sections, every row `LabeledContent`. Session (started/ended/duration). Posture (windows classified, non-neutral count + fraction, alerts fired, windows refused). Recording (measured Hz, model identifier, app version). Diagnostics — present only when `invalidationReason` is non-nil. Title inline, the session's date/time. |

`Receiver.summaries` is newest-first by construction (`add()` inserts at
index 0) — checked, not assumed.

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
watch · a delete affordance · pull-to-refresh · custom materials or
hand-built glass · a launch screen animation.
