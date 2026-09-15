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
