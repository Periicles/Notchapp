# Robustness — Design

**Date:** 2026-07-11
**Source:** `docs/audit-2026-07-11.md` §3, §4
**Decisions made during brainstorming:**
- P1 audit fixes are part of this workstream (not separate quick wins).
- Fetch window widens to 7 days; the "upcoming tomorrow" state becomes a general "next event" state.
- The menu-bar icon (MenuBarExtra) **stays**; documentation is corrected to match.
- Delivery: 4 independent PRs, in the order below. Each PR passes `swiftlint`, `swift build`, `swift test`, and updates the README when behavior changes.

## Goal

Fix the correctness and trust issues found in the audit: calendar permission handling that can fail silently, a fetch window that contradicts the documented states, no recovery when access is granted after launch, and zero observability.

---

## PR R1 — Permissions & product coherence

### Info.plist
- Add `NSCalendarsFullAccessUsageDescription` (required by `requestFullAccessToEvents()` on macOS 14+). Keep the legacy `NSCalendarsUsageDescription` key.
- Add `LSMinimumSystemVersion` = `14.0` (prevents launch-and-crash on macOS 13).

### `.writeOnly` handling
`CalendarManager.requestAccessIfNeeded()` currently maps `.writeOnly` to `.granted`, but write-only access cannot **read** events — the app would show "No event today" forever with no explanation.

- `AuthorizationState` gains a case: `.insufficient` (write-only granted, full access needed).
- Extract the status mapping into a pure, testable function:
  `static func mapAuthorizationStatus(_ status: EKAuthorizationStatus) -> AuthorizationState`
  (`.fullAccess` → granted; `.writeOnly` → insufficient; `.denied`/`.restricted` → denied; `.notDetermined` handled by the async request path as today).
- `SettingsView` shows a dedicated message for `.insufficient`: switch NotchBar to **Full Access** in System Settings → Privacy & Security → Calendars.
- `bootstrap` treats `.insufficient` like `.denied` (no fetch, no polling).

### Documentation coherence (menu-bar icon)
- README §Uninstall: remove the claim "It has no Dock or menu-bar icon"; describe quitting via the menu-bar icon.
- Landing page (`docs/main.js`, EN + FR strings for `feat.2.d`): replace "no menu-bar icon" with wording that allows the discreet menu-bar icon.

### Tests
- `mapAuthorizationStatus` covers all `EKAuthorizationStatus` cases.

---

## PR R2 — 7-day fetch window

### Behavior
- `refreshEvents` window becomes `now - 8h` → `now + 7 days` (was: end of tomorrow).
- State `upcomingTomorrow` is renamed **`upcomingLater`**: "next event is beyond today". `statusLabel` becomes `"Upcoming"`; the live countdown `DD:HH:MM:SS` is now reachable and correct.
- Beyond 7 days with no event, `emptyToday` still applies; its message stays "No event today" (honest again, since the horizon is now real).

### README
- Update the six-state table (`Upcoming tomorrow` → `Upcoming`, trigger "Next event is beyond today (up to 7 days)").

### Tests
- Replace `noonToday()`-based dates with deterministic dates built from `calendar.startOfDay(for:)` offsets so results cannot depend on the wall-clock time of the CI run.
- Add: next event in 3 days → `upcomingLater` with day-field countdown (this scenario was previously untestable in production).
- Add: boundary just before/after midnight between `upcomingToday` and `upcomingLater`.

---

## PR R3 — Authorization recovery & calendar list freshness

### Problem
Access denied at first launch is permanent until app restart; `availableCalendars` is loaded once at bootstrap and never refreshed.

### Behavior
- On every `EKEventStoreChanged` notification **and** on panel open (`setHoverVisible(true)`), if the current state is `.denied`/`.insufficient`/`.unknown`, re-read `EKEventStore.authorizationStatus` (no prompt). If it is now full access, run the remainder of the bootstrap path: load calendars, `ensureDefaultSelection`, refresh events, start polling.
- On every `EKEventStoreChanged`, refresh `availableCalendars` (new/removed calendars appear in Settings without restart). If the selected calendar disappeared, fall back through `ensureDefaultSelection`.

### Constraints
- No re-prompting: `requestFullAccessToEvents()` is still only called from the `.notDetermined` path at bootstrap.
- The panel-open check is a cheap synchronous status read; it must not add async work to the hover path.

### Tests
- Recovery decision logic extracted pure (given current state + new status → action) and unit-tested.
- Fallback-when-selected-calendar-removed covered via `ensureDefaultSelection` tests.

---

## PR R4 — Observability

### Logging
- `os.Logger`, subsystem `com.periicles.NotchBar`, categories: `calendar`, `panel`, `preferences`.
- Log: authorization transitions, refresh outcomes (event **counts**, never titles — event titles are personal data), polling start/stop, panel show/hide, preference changes, migration runs.

### Swallowed errors surfaced
- `SettingsView.setLaunchAtLogin`: keep the UI rollback, add an error log with the thrown error.
- `requestFullAccessToEvents` catch path: log the error before returning `.denied`.

### Tests
- No dedicated tests (thin wrapper over `os.Logger`); existing suite must stay green.

---

## Error handling summary

| Failure | Behavior |
|---|---|
| Full access refused | Settings explains how to enable; no polling |
| Write-only access | Settings explains how to upgrade; no polling |
| Access granted after launch | Recovered on next store change or panel open |
| Selected calendar deleted | Falls back to default selection |
| Launch-at-login toggle fails | UI rolls back + error logged |

## Out of scope

Virtual notch on external displays (audit §3.5), pausing the 30 s poll while the screen is locked, events longer than 8 h. These stay in the audit backlog.
