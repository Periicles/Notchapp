# Robustness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix calendar-permission correctness, widen the event fetch window to 7 days, recover when access is granted after launch, and add `os.Logger` observability — per `docs/superpowers/specs/2026-07-11-robustness-design.md`.

**Architecture:** Four stacked PRs, one per task. All state logic stays in pure, testable static functions; `CalendarManager` keeps EventKit access and wiring. No new dependencies.

**Tech Stack:** Swift 6.1, SPM, AppKit/SwiftUI, EventKit, XCTest, SwiftLint.

## Global Constraints

- macOS 14+ target, SPM-only, **zero external dependencies**.
- Conventional Commits; **never add a `Co-Authored-By` trailer**.
- Every task: `swiftlint` (0 errors), `swift build`, `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` all green before the PR.
- Stacked branches: each task branches off the previous task's branch; `gh pr create --base <previous-branch>` (Task R1 bases on `main`).
- Never log event titles or other personal data.
- Update README whenever behavior changes.

---

### Task R1: Permissions & product coherence

**Branch:** `fix/calendar-permissions` off `main`. PR base: `main`.

**Files:**
- Modify: `Supporting/Info.plist`
- Modify: `Sources/Calendar/CalendarManager.swift`
- Modify: `Sources/Settings/SettingsView.swift`
- Modify: `README.md` (§Uninstall)
- Modify: `docs/main.js` (`feat.2.d` strings)
- Test: `Tests/NotchBarTests/AuthorizationMappingTests.swift` (create)

**Interfaces:**
- Produces: `CalendarManager.AuthorizationState.insufficient` (new case) and `static func mapAuthorizationStatus(_ status: EKAuthorizationStatus) -> AuthorizationState` — Task R3 reuses both.

- [ ] **Step 1: Write the failing tests** — create `Tests/NotchBarTests/AuthorizationMappingTests.swift`:

```swift
import EventKit
import XCTest
@testable import NotchBar

@MainActor
final class AuthorizationMappingTests: XCTestCase {
    func test_fullAccess_mapsToGranted() {
        XCTAssertEqual(CalendarManager.mapAuthorizationStatus(.fullAccess), .granted)
    }

    func test_writeOnly_mapsToInsufficient() {
        XCTAssertEqual(CalendarManager.mapAuthorizationStatus(.writeOnly), .insufficient)
    }

    func test_denied_mapsToDenied() {
        XCTAssertEqual(CalendarManager.mapAuthorizationStatus(.denied), .denied)
    }

    func test_restricted_mapsToDenied() {
        XCTAssertEqual(CalendarManager.mapAuthorizationStatus(.restricted), .denied)
    }

    func test_notDetermined_mapsToUnknown() {
        XCTAssertEqual(CalendarManager.mapAuthorizationStatus(.notDetermined), .unknown)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter AuthorizationMappingTests`
Expected: compile error — `insufficient` and `mapAuthorizationStatus` don't exist.

- [ ] **Step 3: Implement in `CalendarManager.swift`** — add the case, the mapper, and rewrite `requestAccessIfNeeded`:

```swift
enum AuthorizationState: Equatable {
    case unknown
    case granted
    case insufficient   // write-only access: cannot read events
    case denied
}

static func mapAuthorizationStatus(_ status: EKAuthorizationStatus) -> AuthorizationState {
    switch status {
    case .fullAccess:
        return .granted
    case .writeOnly:
        return .insufficient
    case .denied, .restricted:
        return .denied
    case .notDetermined:
        return .unknown
    @unknown default:
        return .denied
    }
}

private func requestAccessIfNeeded() async -> AuthorizationState {
    let status = EKEventStore.authorizationStatus(for: .event)
    guard status == .notDetermined else {
        return Self.mapAuthorizationStatus(status)
    }
    do {
        let granted = try await store.requestFullAccessToEvents()
        return granted ? .granted : .denied
    } catch {
        return .denied
    }
}
```

(`bootstrap` and `refreshEvents` already guard on `== .granted`, so `.insufficient` correctly does no fetching/polling.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
Expected: PASS (all suites).

- [ ] **Step 5: Settings message for `.insufficient`** — in `SettingsView.body`, replace the `if calendarManager.authorizationState == .denied` branch with:

```swift
if calendarManager.authorizationState == .denied {
    Text("Calendar access is disabled. Enable it in System Settings > Privacy & Security > Calendars.")
        .font(.footnote)
        .foregroundStyle(.secondary)
} else if calendarManager.authorizationState == .insufficient {
    Text("NotchBar has write-only calendar access and cannot read your events. Switch it to Full Access in System Settings > Privacy & Security > Calendars.")
        .font(.footnote)
        .foregroundStyle(.secondary)
} else {
```

- [ ] **Step 6: Info.plist keys** — in `Supporting/Info.plist`, after the `NSCalendarsUsageDescription` entry add:

```xml
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>NotchBar shows your meeting progress.</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
```

- [ ] **Step 7: Fix docs claims** — README §Uninstall step 2 becomes:

```markdown
2. Quit NotchBar: click the NotchBar icon in the menu bar → **Quit**, or hover the notch → open settings → **Quit NotchBar**.
```

In `docs/main.js`, replace `feat.2.d`:

```js
"feat.2.d":    { en: "The notch stays black until you hover. No clutter — just a discreet menu-bar icon.",
                 fr: "Le notch reste noir tant que tu ne survoles pas. Zéro encombrement — juste une icône discrète dans la barre de menus." },
```

- [ ] **Step 8: Verify everything**

Run: `swiftlint && swift build && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
Expected: 0 lint errors, build OK, all tests PASS.

- [ ] **Step 9: Commit and open PR**

```bash
git checkout -b fix/calendar-permissions main
git add Supporting/Info.plist Sources/Calendar/CalendarManager.swift Sources/Settings/SettingsView.swift README.md docs/main.js Tests/NotchBarTests/AuthorizationMappingTests.swift
git commit -m "fix(calendar): require full access, handle write-only, add macOS 14 usage key"
git push -u origin fix/calendar-permissions
gh pr create --base main --title "fix(calendar): correct permission handling and docs coherence" --body "..."
```

PR body: summarize spec §PR R1 (why: silent failure on macOS 14+ key, write-only reads nothing, menu-bar icon claim was false).

---

### Task R2: 7-day fetch window

**Branch:** `feat/seven-day-window` off `fix/calendar-permissions`. PR base: `fix/calendar-permissions`.

**Files:**
- Modify: `Sources/Calendar/CalendarManager.swift` (`refreshEvents`, `computeSnapshot`, builder)
- Modify: `Sources/Calendar/EventProgressModel.swift` (state enum)
- Modify: `README.md` (states table)
- Test: `Tests/NotchBarTests/SnapshotComputationTests.swift`

**Interfaces:**
- Produces: `EventProgressSnapshot.State.upcomingLater` (renames `.upcomingTomorrow`); `statusLabel` `"Upcoming"` for that state. Product plan P1 moves the renamed builder as-is.

- [ ] **Step 1: Update tests first.** In `SnapshotComputationTests.swift`, replace the wall-clock-dependent helper `noonToday()` with a deterministic one and retarget the tomorrow tests:

```swift
/// Noon of a fixed reference day — never depends on when the test runs.
private func fixedNoon() -> Date {
    let reference = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let startOfDay = calendar.startOfDay(for: reference)
    return calendar.date(byAdding: DateComponents(hour: 12), to: startOfDay)!
}
```

Replace every `noonToday()` call with `fixedNoon()` and delete `noonToday()`. Then rename/retarget the two tomorrow tests and add three:

```swift
func test_state_isUpcomingLater_whenNextEventIsTomorrow() {
    let now = fixedNoon()
    let snapshot = CalendarManager.computeSnapshot(
        events: [makeEvent(title: "Tomorrow", startOffset: 86_400, durationSeconds: 3600, relativeTo: now)],
        selectedCalendarID: calendarID,
        now: now,
        calendar: calendar
    )
    XCTAssertEqual(snapshot.state, .upcomingLater)
    XCTAssertEqual(snapshot.statusLabel, "Upcoming")
}

func test_state_isUpcomingLater_whenNextEventInThreeDays() {
    let now = fixedNoon()
    let snapshot = CalendarManager.computeSnapshot(
        events: [makeEvent(title: "Conf", startOffset: 3 * 86_400, durationSeconds: 3600, relativeTo: now)],
        selectedCalendarID: calendarID,
        now: now,
        calendar: calendar
    )
    XCTAssertEqual(snapshot.state, .upcomingLater)
    XCTAssertEqual(snapshot.secondaryMessage, "Next event in: 03:00:00:00")
}

func test_boundary_eventBeforeMidnight_isUpcomingToday() {
    let now = calendar.date(byAdding: DateComponents(hour: 23, minute: 30),
                            to: calendar.startOfDay(for: fixedNoon()))!
    let snapshot = CalendarManager.computeSnapshot(
        events: [makeEvent(title: "Late", startOffset: 20 * 60, durationSeconds: 1800, relativeTo: now)],
        selectedCalendarID: calendarID,
        now: now,
        calendar: calendar
    )
    XCTAssertEqual(snapshot.state, .upcomingToday)
}

func test_boundary_eventAfterMidnight_isUpcomingLater() {
    let now = calendar.date(byAdding: DateComponents(hour: 23, minute: 30),
                            to: calendar.startOfDay(for: fixedNoon()))!
    let snapshot = CalendarManager.computeSnapshot(
        events: [makeEvent(title: "Early", startOffset: 40 * 60, durationSeconds: 1800, relativeTo: now)],
        selectedCalendarID: calendarID,
        now: now,
        calendar: calendar
    )
    XCTAssertEqual(snapshot.state, .upcomingLater)
    XCTAssertEqual(snapshot.secondaryMessage, "Next event in: 00:00:40:00")
}
```

Update `test_upcomingTomorrow_countdownFormat` → rename to `test_upcomingLater_countdownFormat`, assert `.upcomingLater` (message assertion unchanged). Update `test_state_isUpcomingToday_whenEventLaterTodayBeyondFiveMinutes` and `test_upcomingToday_minutesOnly_whenUnderOneHour` to use `fixedNoon()`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter SnapshotComputationTests`
Expected: compile error — `.upcomingLater` doesn't exist.

- [ ] **Step 3: Implement.** In `EventProgressModel.swift` rename the enum case `upcomingTomorrow` → `upcomingLater`. In `CalendarManager.swift`:
  - `refreshEvents`: replace the window line with `let endOfWindow = now.addingTimeInterval(7 * 86400)`.
  - Rename `upcomingTomorrowSnapshot` → `upcomingLaterSnapshot`; inside it set `statusLabel: "Upcoming"` and `state: .upcomingLater`.
  - In `computeSnapshot`, the final return becomes `return upcomingLaterSnapshot(for: next, now: now)`.
  - `NotchPanelView.swift`: update the `switch` case list (`.upcomingTomorrow` → `.upcomingLater`).

- [ ] **Step 4: Run the full suite**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
Expected: PASS.

- [ ] **Step 5: README states table** — the `Upcoming tomorrow` row becomes:

```markdown
| **Upcoming** | Next event is beyond today (up to 7 days out) | `Next event in: DD:HH:MM:SS` (live countdown) |
```

- [ ] **Step 6: Verify, commit, PR**

```bash
swiftlint && swift build && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
git checkout -b feat/seven-day-window fix/calendar-permissions
git add -A && git commit -m "feat(calendar): widen fetch window to 7 days, rename upcoming state"
git push -u origin feat/seven-day-window
gh pr create --base fix/calendar-permissions --title "feat(calendar): 7-day fetch window" --body "..."
```

---

### Task R3: Authorization recovery & calendar list freshness

**Branch:** `feat/authorization-recovery` off `feat/seven-day-window`. PR base: `feat/seven-day-window`.

**Files:**
- Modify: `Sources/Calendar/CalendarManager.swift`
- Modify: `Sources/Calendar/EventProgressModel.swift`
- Modify: `Sources/Settings/Preferences.swift`
- Test: `Tests/NotchBarTests/PreferencesTests.swift`

**Interfaces:**
- Consumes: `mapAuthorizationStatus` (R1).
- Produces: `CalendarManager.reevaluateAuthorizationIfNeeded(using:) async`; `static Preferences.resolveSelection(current: String?, available: [String]) -> String?`.

- [ ] **Step 1: Failing tests** — add to `PreferencesTests.swift`:

```swift
// MARK: - resolveSelection

func test_resolveSelection_keepsCurrent_whenStillAvailable() {
    XCTAssertEqual(Preferences.resolveSelection(current: "b", available: ["a", "b"]), "b")
}

func test_resolveSelection_returnsNil_whenCurrentRemoved() {
    XCTAssertNil(Preferences.resolveSelection(current: "gone", available: ["a", "b"]))
}

func test_resolveSelection_returnsNil_whenCurrentNil() {
    XCTAssertNil(Preferences.resolveSelection(current: nil, available: ["a"]))
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --filter PreferencesTests` (with `DEVELOPER_DIR`). Expected: compile error.

- [ ] **Step 3: Implement `resolveSelection`** in `Preferences.swift`:

```swift
static func resolveSelection(current: String?, available: [String]) -> String? {
    guard let current, available.contains(current) else { return nil }
    return current
}
```

- [ ] **Step 4: Recovery in `CalendarManager.swift`.** Move `installStoreObserver` to the top of `bootstrap` (before the auth guard), add:

```swift
func reevaluateAuthorizationIfNeeded(using preferences: Preferences) async {
    guard authorizationState != .granted else { return }
    let latest = Self.mapAuthorizationStatus(EKEventStore.authorizationStatus(for: .event))
    guard latest != authorizationState else { return }
    authorizationState = latest
    guard latest == .granted else { return }
    availableCalendars = store.calendars(for: .event)
    preferences.ensureDefaultSelection(using: availableCalendars, store: store)
    await refreshEvents(using: preferences)
    startPolling(preferences: preferences)
}

private func handleStoreChanged(using preferences: Preferences) async {
    await reevaluateAuthorizationIfNeeded(using: preferences)
    guard authorizationState == .granted else { return }
    availableCalendars = store.calendars(for: .event)
    let availableIDs = availableCalendars.map(\.calendarIdentifier)
    if Preferences.resolveSelection(current: preferences.selectedCalendarIdentifier, available: availableIDs) == nil {
        preferences.selectedCalendarIdentifier = nil
        preferences.ensureDefaultSelection(using: availableCalendars, store: store)
    }
    await refreshEvents(using: preferences)
}
```

and point the observer at it:

```swift
private func installStoreObserver(preferences: Preferences) {
    NotificationCenter.default.addObserver(
        forName: .EKEventStoreChanged,
        object: store,
        queue: .main
    ) { [weak self] _ in
        Task { await self?.handleStoreChanged(using: preferences) }
    }
}
```

- [ ] **Step 5: Panel-open recovery hook** in `EventProgressModel.setHoverVisible` (`visible == true` branch, before `refreshSnapshot()`):

```swift
if visible {
    recoverAuthorizationIfNeeded()
    refreshSnapshot()
    startTicking()
}
```

```swift
/// Cheap: exits immediately unless access is currently not granted.
private func recoverAuthorizationIfNeeded() {
    guard let calendarManager, let preferences,
          calendarManager.authorizationState != .granted else { return }
    Task { [weak self] in
        await calendarManager.reevaluateAuthorizationIfNeeded(using: preferences)
        self?.refreshSnapshot()
    }
}
```

- [ ] **Step 6: Full verification** — `swiftlint && swift build && DEVELOPER_DIR=... swift test`. Expected: green. (Note: `CalendarManager.swift` may cross the 300-line SwiftLint *warning* — acceptable; product Task P1 shrinks it. Zero *errors* remains mandatory.)

- [ ] **Step 7: Commit & PR**

```bash
git checkout -b feat/authorization-recovery feat/seven-day-window
git add -A && git commit -m "feat(calendar): recover authorization after launch, refresh calendar list"
git push -u origin feat/authorization-recovery
gh pr create --base feat/seven-day-window --title "feat(calendar): authorization recovery" --body "..."
```

---

### Task R4: Observability (os.Logger)

**Branch:** `feat/os-logger` off `feat/authorization-recovery`. PR base: `feat/authorization-recovery`.

**Files:**
- Create: `Sources/Utilities/Log.swift`
- Modify: `Sources/Calendar/CalendarManager.swift`, `Sources/Calendar/EventProgressModel.swift`, `Sources/Settings/Preferences.swift`, `Sources/Settings/SettingsView.swift`

**Interfaces:**
- Produces: `Log.calendar`, `Log.panel`, `Log.preferences` (`os.Logger` instances) — available to all later work.

- [ ] **Step 1: Create `Sources/Utilities/Log.swift`**

```swift
import os

enum Log {
    private static let subsystem = "com.periicles.NotchBar"

    static let calendar = Logger(subsystem: subsystem, category: "calendar")
    static let panel = Logger(subsystem: subsystem, category: "panel")
    static let preferences = Logger(subsystem: subsystem, category: "preferences")
}
```

- [ ] **Step 2: Insert log calls.** Never log event titles. Exact insertions:
  - `CalendarManager.bootstrap` after auth assignment: `Log.calendar.info("Bootstrap authorization: \(String(describing: self.authorizationState), privacy: .public)")`
  - `reevaluateAuthorizationIfNeeded` after `authorizationState = latest`: `Log.calendar.info("Authorization changed: \(String(describing: latest), privacy: .public)")`
  - `refreshEvents` before returns and at end: `Log.calendar.debug("Refresh: current=\(self.currentEvent != nil), next=\(self.nextEvent != nil)")`
  - `requestAccessIfNeeded` catch: `Log.calendar.error("Full-access request failed: \(error.localizedDescription, privacy: .public)")`
  - `startPolling`: `Log.calendar.info("Polling started")`
  - `EventProgressModel.setHoverVisible` after the guard: `Log.panel.debug("Panel \(visible ? "opened" : "closed", privacy: .public)")`
  - `Preferences.selectedCalendarIdentifier.didSet`: `Log.preferences.debug("Selected calendar changed")`
  - `Preferences.migrateLegacyMultiSelectIfNeeded` on migration: `Log.preferences.info("Migrated legacy multi-select preference")` (make the method non-static or log from `init` after the call — logging from `init` is simpler: `if defaults.string(forKey: Keys.selectedCalendarIdentifier) != nil { … }` is noise; just log unconditionally after migration call is acceptable at `debug` level).
  - `SettingsView.setLaunchAtLogin` catch: `Log.preferences.error("Launch-at-login toggle failed: \(error.localizedDescription, privacy: .public)")`

- [ ] **Step 3: Verify** — `swiftlint && swift build && DEVELOPER_DIR=... swift test`. Expected: green (no behavior change; suite untouched).

- [ ] **Step 4: Manual smoke check** — `swift run` then `log stream --predicate 'subsystem == "com.periicles.NotchBar"' --level debug` in another terminal; hover the notch; expect `panel` open/close lines. Skip if no interactive session.

- [ ] **Step 5: Commit & PR**

```bash
git checkout -b feat/os-logger feat/authorization-recovery
git add -A && git commit -m "feat(logging): add os.Logger observability, surface swallowed errors"
git push -u origin feat/os-logger
gh pr create --base feat/authorization-recovery --title "feat(logging): os.Logger observability" --body "..."
```
