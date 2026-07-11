# Product Features — Design

**Date:** 2026-07-11
**Source:** `docs/audit-2026-07-11.md` §5, §6, §10
**Decisions made during brainstorming:**
- Scope: meeting-link detection (Join button), multi-calendar tracking, French localization. "Progress line at rest" was **excluded** to preserve the zero-work-at-rest guarantee.
- Join UX: dedicated button in the panel (not a fully clickable panel).
- Language selection: follow the system locale (no in-app toggle); per-app override is already provided by macOS.
- Delivery order (foundation-first): formatting extraction → meeting links → multi-calendar → localization. Localization ships **last** so every new string from the other PRs is translated exactly once.
- This workstream starts after the Robustness workstream (both touch `CalendarManager`).

## Goal

Ship the three highest-value features identified in the audit on top of a cleaned-up snapshot pipeline, without regressing the idle-first performance model.

---

## PR P1 — Extract snapshot building out of `CalendarManager` (refactor)

### Problem
`CalendarManager` mixes EventKit access with presentation formatting (`"Starts in Xm — …"`, `"%02d:%02d:%02d"`). This blocks localization and pushes the file toward the 300-line lint limit.

### Change
- New file `Sources/Calendar/SnapshotBuilder.swift`: an enum/namespace owning `computeSnapshot(events:selectedCalendarID:now:calendar:)`, the per-state builders, `formatDuration`, `formattedTime`, and the `nilIfEmpty` helper.
- `CalendarManager.currentSnapshot` delegates to `SnapshotBuilder`. `CalendarManager` keeps only EventKit access, authorization, polling, and observer wiring.
- **Pure refactor: zero behavior change.** Snapshot strings and states are byte-for-byte identical.

### Tests
- `SnapshotComputationTests` retargets `SnapshotBuilder.computeSnapshot`; assertions unchanged (they are the behavioral safety net for this refactor).

---

## PR P2 — Meeting links: Join button

### Detection
- New pure type `MeetingLinkDetector` (`Sources/Calendar/MeetingLinkDetector.swift`):
  `static func detect(url: URL?, location: String?, notes: String?) -> URL?`
- Priority order: the event's `url` field, then `location`, then `notes`. First match wins.
- Recognized providers (host-based matching, https only): `zoom.us` (any subdomain, `/j/` and `/my/` paths), `meet.google.com`, `teams.microsoft.com` and `teams.live.com`, `*.webex.com`. Bare text without a recognizable meeting URL yields `nil`.

### Data flow
- `CalendarEvent` gains `joinURL: URL?`; `CalendarManager` populates it via the detector when mapping `EKEvent`s.
- `EventProgressSnapshot` gains `joinURL: URL?`; set by the `inProgress` and `startingSoon` builders, `nil` for all other states.

### UI
- A `Join` button (camera SF Symbol + label, tinted with the snapshot tint) rendered in the panel for `inProgress` and `startingSoon` when `joinURL != nil`, placed on the metrics row (per the approved mock).
- `NotchContentView` currently has `.allowsHitTesting(false)`; the Join button is added as an interactive overlay (same pattern as `SettingsOrbButton`) so the no-hit-testing content stays inert.
- Action: `NSWorkspace.shared.open(url)`.

### Tests
- `MeetingLinkDetectorTests`: one case per provider, link found in `location`, link found in `notes`, priority (url beats notes), non-meeting URL → nil, plain text → nil, http (non-https) → nil.
- Snapshot tests: `joinURL` propagated for `inProgress`/`startingSoon`, nil for secondary states.

---

## PR P3 — Multi-calendar tracking

### Preferences
- `selectedCalendarIdentifier: String?` becomes `selectedCalendarIdentifiers: Set<String>` backed by a new defaults key `selectedCalendarIdentifiers` (`[String]`).
- Migration chain (idempotent, in order): legacy array `selectedCalendarIDs` → single `selectedCalendarIdentifier` → new set key. Old keys removed after migration.
- `ensureDefaultSelection` seeds the set with the same single default as today. An empty set is legal.

### Snapshot semantics
- `computeSnapshot` takes `selectedCalendarIDs: Set<String>`; relevant events are those whose `calendarIdentifier` is in the set, merged and sorted by `startDate`.
- Several events in progress at once: show the one with the **earliest start** (consistent with today's single-calendar sort). Tint always comes from the shown event's own calendar color.
- Empty set → `noCalendar` state (message unchanged: "Pick a calendar in Settings").

### Settings UI
- Radio rows become checkbox rows (toggle membership). Zero selected is allowed and shows the `noCalendar` state.

### Fetch
- `refreshEvents` passes all selected calendars to `predicateForEvents`.

### Tests
- Preferences: migration single → set, legacy chain end-to-end, empty-set persistence.
- Snapshot: events merged across two calendars; overlapping events pick earliest start; events outside the set ignored (existing test updated).

---

## PR P4 — French localization

### Mechanics
- `Package.swift`: `defaultLocalization: "en"`; add a `Localizable.xcstrings` String Catalog resource to the target (en + fr).
- All user-facing strings move to `String(localized:bundle:)` lookups against `Bundle.module`: snapshot labels/messages (now centralized in `SnapshotBuilder` — P1 made this possible), Settings UI, menu-bar items.
- Countdown/duration values stay numeric; only surrounding labels are translated. `Date.formatted` is already locale-aware.
- Format strings use `String(localized:)` interpolation so word order can differ in French.
- App bundle: `CFBundleLocalizations` (en, fr) added by the packaging script or Info.plist.

### Language choice
- System locale only. No in-app toggle (macOS per-app language override covers the rest).

### Tests
- Existing snapshot tests pin the **English** strings (run under en locale — assert via explicit `Locale(identifier: "en_US")`-driven formatting where relevant so CI is locale-independent).
- One smoke test: the fr table resolves a known key to a non-English value.

---

## Non-goals

- Progress indicator while collapsed (excluded by decision).
- In-app language switcher.
- Landing page changes beyond what R1 already corrected.
- Global keyboard shortcut for Join (possible v2).

## Performance guardrails

The idle-first model is unchanged: no new timers at rest, detection runs only during event mapping (every 30 s poll / store change), the Join button lives inside the already-conditional expanded panel.
