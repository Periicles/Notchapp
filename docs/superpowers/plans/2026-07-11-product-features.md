# Product Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract snapshot building, add a Join button for meeting links, support multiple tracked calendars, and localize the app in French — per `docs/superpowers/specs/2026-07-11-product-features-design.md`.

**Architecture:** Four stacked PRs continuing the robustness stack (P1 bases on `feat/os-logger`). Foundation-first order: the P1 refactor cleans the surface P2/P3 modify; localization lands last so every string is translated once.

**Tech Stack:** Swift 6.1, SPM, AppKit/SwiftUI, EventKit, String Catalog (`.xcstrings`), XCTest, SwiftLint.

## Global Constraints

- macOS 14+ target, SPM-only, **zero external dependencies**.
- Conventional Commits; **never add a `Co-Authored-By` trailer**.
- Every task: `swiftlint` (0 errors), `swift build`, `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` all green before the PR.
- Stacked branches: P1 ← `feat/os-logger`, P2 ← P1's branch, etc. `gh pr create --base <previous-branch>`.
- Idle-first guarantee unchanged: no new timers at rest.
- This plan assumes the Robustness plan is applied (state `.upcomingLater`, `mapAuthorizationStatus`, `Log`).
- Update README whenever behavior changes.

---

### Task P1: Extract `SnapshotBuilder` (pure refactor)

**Branch:** `refactor/snapshot-builder` off `feat/os-logger`. PR base: `feat/os-logger`.

**Files:**
- Create: `Sources/Calendar/SnapshotBuilder.swift`
- Modify: `Sources/Calendar/CalendarManager.swift`
- Test: `Tests/NotchBarTests/SnapshotComputationTests.swift` (retarget only)

**Interfaces:**
- Produces: `enum SnapshotBuilder` with `static func computeSnapshot(events: [CalendarEvent], selectedCalendarID: String?, now: Date, calendar: Calendar) -> EventProgressSnapshot`. P2/P3/P4 modify this type.

- [ ] **Step 1: Move code.** Create `Sources/Calendar/SnapshotBuilder.swift` and move from `CalendarManager.swift`, unchanged: `computeSnapshot`, `upcomingLaterSnapshot`, `inProgressSnapshot`, `startingSoonSnapshot`, `upcomingTodaySnapshot`, `formatDuration`, `formattedTime`, and the `private extension String { var nilIfEmpty }`. Wrap the functions in `enum SnapshotBuilder { … }` (all `static`, drop the `private` on `computeSnapshot` only). `CalendarManager.currentSnapshot` delegates:

```swift
func currentSnapshot(selectedCalendarID: String?, now: Date = .now) -> EventProgressSnapshot {
    let inputs = ([currentEvent, nextEvent].compactMap { $0 }).map { event -> CalendarEvent in
        CalendarEvent(
            title: event.title ?? "",
            startDate: event.startDate,
            endDate: event.endDate,
            calendarIdentifier: event.calendar.calendarIdentifier,
            color: Color(nsColor: NSColor(cgColor: event.calendar.cgColor) ?? .controlAccentColor)
        )
    }

    return SnapshotBuilder.computeSnapshot(
        events: inputs,
        selectedCalendarID: selectedCalendarID,
        now: now,
        calendar: .current
    )
}
```

The `CalendarEvent` struct moves to `SnapshotBuilder.swift` too (it is the builder's input type).

- [ ] **Step 2: Retarget tests.** In `SnapshotComputationTests.swift`, replace every `CalendarManager.computeSnapshot(` with `SnapshotBuilder.computeSnapshot(`. **No assertion changes** — the existing suite is the proof this refactor changes nothing.

- [ ] **Step 3: Verify** — `swiftlint && swift build && DEVELOPER_DIR=... swift test`. Expected: green, and `CalendarManager.swift` is back under the 300-line lint warning.

- [ ] **Step 4: Commit & PR**

```bash
git checkout -b refactor/snapshot-builder feat/os-logger
git add -A && git commit -m "refactor(calendar): extract SnapshotBuilder from CalendarManager"
git push -u origin refactor/snapshot-builder
gh pr create --base feat/os-logger --title "refactor(calendar): extract SnapshotBuilder" --body "..."
```

---

### Task P2: Meeting links — Join button

**Branch:** `feat/join-button` off `refactor/snapshot-builder`. PR base: `refactor/snapshot-builder`.

**Files:**
- Create: `Sources/Calendar/MeetingLinkDetector.swift`
- Modify: `Sources/Calendar/SnapshotBuilder.swift` (`CalendarEvent.joinURL`, snapshot plumbing)
- Modify: `Sources/Calendar/EventProgressModel.swift` (`EventProgressSnapshot.joinURL`)
- Modify: `Sources/Calendar/CalendarManager.swift` (populate `joinURL`)
- Modify: `Sources/NotchPanel/NotchPanelView.swift` (Join button overlay)
- Modify: `README.md` (feature mention in states table rows for In progress / Starting soon)
- Test: `Tests/NotchBarTests/MeetingLinkDetectorTests.swift` (create), `SnapshotComputationTests.swift` (propagation)

**Interfaces:**
- Produces: `enum MeetingLinkDetector { static func detect(url: URL?, location: String?, notes: String?) -> URL? }`; `CalendarEvent.joinURL: URL?` (memberwise default `nil`); `EventProgressSnapshot.joinURL: URL?` (default `nil`).

- [ ] **Step 1: Failing detector tests** — create `Tests/NotchBarTests/MeetingLinkDetectorTests.swift`:

```swift
import XCTest
@testable import NotchBar

final class MeetingLinkDetectorTests: XCTestCase {
    func test_zoomJoinURL_inURLField() {
        let url = URL(string: "https://us02web.zoom.us/j/1234567890")!
        XCTAssertEqual(MeetingLinkDetector.detect(url: url, location: nil, notes: nil), url)
    }

    func test_googleMeet_inLocation() {
        let expected = URL(string: "https://meet.google.com/abc-defg-hij")!
        XCTAssertEqual(
            MeetingLinkDetector.detect(url: nil, location: "https://meet.google.com/abc-defg-hij", notes: nil),
            expected
        )
    }

    func test_teams_inNotes() {
        let notes = "Agenda…\nJoin: https://teams.microsoft.com/l/meetup-join/19%3ameeting_x, see you"
        XCTAssertEqual(
            MeetingLinkDetector.detect(url: nil, location: nil, notes: notes)?.host(),
            "teams.microsoft.com"
        )
    }

    func test_webexSubdomain_isDetected() {
        let url = URL(string: "https://acme.webex.com/meet/jdoe")!
        XCTAssertEqual(MeetingLinkDetector.detect(url: url, location: nil, notes: nil), url)
    }

    func test_urlFieldBeatsNotes() {
        let urlField = URL(string: "https://zoom.us/j/111")!
        let result = MeetingLinkDetector.detect(url: urlField, location: nil, notes: "https://meet.google.com/xyz-aaaa-bbb")
        XCTAssertEqual(result, urlField)
    }

    func test_nonMeetingURL_returnsNil() {
        XCTAssertNil(MeetingLinkDetector.detect(url: URL(string: "https://example.com/agenda")!, location: nil, notes: nil))
    }

    func test_plainText_returnsNil() {
        XCTAssertNil(MeetingLinkDetector.detect(url: nil, location: "Room 4B", notes: "Bring the deck"))
    }

    func test_httpScheme_returnsNil() {
        XCTAssertNil(MeetingLinkDetector.detect(url: URL(string: "http://zoom.us/j/111")!, location: nil, notes: nil))
    }

    func test_zoomWithoutJoinPath_returnsNil() {
        XCTAssertNil(MeetingLinkDetector.detect(url: URL(string: "https://zoom.us/pricing")!, location: nil, notes: nil))
    }
}
```

- [ ] **Step 2: Run to verify failure** — compile error, `MeetingLinkDetector` missing.

- [ ] **Step 3: Implement `Sources/Calendar/MeetingLinkDetector.swift`**

```swift
import Foundation

enum MeetingLinkDetector {
    static func detect(url: URL?, location: String?, notes: String?) -> URL? {
        if let url, isMeetingURL(url) { return url }
        if let fromLocation = firstMeetingURL(in: location) { return fromLocation }
        return firstMeetingURL(in: notes)
    }

    private static func firstMeetingURL(in text: String?) -> URL? {
        guard let text, !text.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range)
            .compactMap(\.url)
            .first(where: isMeetingURL)
    }

    private static func isMeetingURL(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host()?.lowercased() else { return false }
        if host == "zoom.us" || host.hasSuffix(".zoom.us") {
            return url.path.hasPrefix("/j/") || url.path.hasPrefix("/my/")
        }
        if host == "meet.google.com" { return true }
        if host == "teams.microsoft.com" || host == "teams.live.com" { return true }
        if host.hasSuffix(".webex.com") { return true }
        return false
    }
}
```

- [ ] **Step 4: Run detector tests** — expected PASS.

- [ ] **Step 5: Plumb `joinURL`.**
  - `CalendarEvent` (in `SnapshotBuilder.swift`): add `var joinURL: URL? = nil` as the last property (memberwise default keeps existing call sites compiling).
  - `EventProgressSnapshot` (in `EventProgressModel.swift`): add `var joinURL: URL? = nil` as the last property.
  - `SnapshotBuilder.inProgressSnapshot` and `startingSoonSnapshot`: pass `joinURL: event.joinURL` in the returned snapshot. Other builders leave the default `nil`.
  - `CalendarManager.currentSnapshot` mapping gains:

```swift
joinURL: MeetingLinkDetector.detect(url: event.url, location: event.location, notes: event.notes)
```

  - Snapshot propagation tests in `SnapshotComputationTests.swift`:

```swift
func test_joinURL_propagatedForInProgress() {
    let now = fixedNoon()
    let join = URL(string: "https://meet.google.com/abc-defg-hij")!
    var event = makeEvent(title: "Standup", startOffset: -300, durationSeconds: 1800, relativeTo: now)
    event.joinURL = join
    let snapshot = SnapshotBuilder.computeSnapshot(
        events: [event], selectedCalendarID: calendarID, now: now, calendar: calendar
    )
    XCTAssertEqual(snapshot.joinURL, join)
}

func test_joinURL_nilForEmptyToday() {
    let now = fixedNoon()
    let snapshot = SnapshotBuilder.computeSnapshot(
        events: [], selectedCalendarID: calendarID, now: now, calendar: calendar
    )
    XCTAssertNil(snapshot.joinURL)
}
```

  (`makeEvent`'s `CalendarEvent` must be a `var` for this — change `CalendarEvent` properties used here accordingly: `joinURL` is already `var`.)

- [ ] **Step 6: UI.** In `NotchPanelView.swift` add `import AppKit`, a `JoinButton` view, and an overlay (sibling of the settings-orb overlay on the root `ZStack`):

```swift
.overlay(alignment: .bottom) {
    if let joinURL = progressModel.snapshot.joinURL {
        JoinButton(tint: progressModel.snapshot.tint) {
            NSWorkspace.shared.open(joinURL)
        }
        .padding(.bottom, 16)
        .opacity(isExpanded ? 1 : 0)
        .scaleEffect(isExpanded ? 1 : 0.85, anchor: .bottom)
        .allowsHitTesting(isExpanded)
        .animation(.easeOut(duration: 0.16).delay(isExpanded ? 0.08 : 0), value: isExpanded)
    }
}
```

```swift
private struct JoinButton: View {
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "video.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("Join")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(tint.opacity(0.35)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.55), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
```

The bottom-center position lands between the Elapsed (left) and Remaining (right) metrics, per the approved mock. `NotchContentView` keeps `.allowsHitTesting(false)`.

- [ ] **Step 7: Verify** — `swiftlint && swift build && DEVELOPER_DIR=... swift test`. Manual: `swift run` with a test event containing a Meet link; hover; click Join; browser opens.

- [ ] **Step 8: README** — In progress / Starting soon rows: append "+ **Join** button when a meeting link is detected (Zoom, Meet, Teams, Webex)".

- [ ] **Step 9: Commit & PR**

```bash
git checkout -b feat/join-button refactor/snapshot-builder
git add -A && git commit -m "feat(panel): detect meeting links and add Join button"
git push -u origin feat/join-button
gh pr create --base refactor/snapshot-builder --title "feat(panel): Join button for meeting links" --body "..."
```

---

### Task P3: Multi-calendar tracking

**Branch:** `feat/multi-calendar` off `feat/join-button`. PR base: `feat/join-button`.

**Files:**
- Modify: `Sources/Settings/Preferences.swift` (Set-based selection + migration)
- Modify: `Sources/Calendar/SnapshotBuilder.swift` (`computeSnapshot` takes a Set)
- Modify: `Sources/Calendar/CalendarManager.swift` (multi-calendar fetch)
- Modify: `Sources/Calendar/EventProgressModel.swift` (pass the Set)
- Modify: `Sources/Settings/SettingsView.swift` (checkboxes)
- Modify: `README.md` (single-calendar wording)
- Test: `PreferencesTests.swift`, `SnapshotComputationTests.swift`

**Interfaces:**
- Produces: `Preferences.selectedCalendarIdentifiers: Set<String>` (replaces `selectedCalendarIdentifier`); `SnapshotBuilder.computeSnapshot(events:selectedCalendarIDs: Set<String>, now:calendar:)`; `CalendarManager.currentSnapshot(selectedCalendarIDs:now:)`; `Preferences.resolveSelection(current: Set<String>, available: [String]) -> Set<String>` (replaces the R3 single-value version).

- [ ] **Step 1: Failing preference tests** — in `PreferencesTests.swift`, replace the single-selection tests with Set equivalents:

```swift
func test_migration_singleIdentifierBecomesSet() {
    defaults.set("solo-id", forKey: "selectedCalendarIdentifier")
    let prefs = Preferences(defaults: defaults)
    XCTAssertEqual(prefs.selectedCalendarIdentifiers, ["solo-id"])
    XCTAssertNil(defaults.object(forKey: "selectedCalendarIdentifier"))
}

func test_migration_legacyArrayBecomesFullSet() {
    defaults.set(["legacy-a", "legacy-b"], forKey: "selectedCalendarIDs")
    let prefs = Preferences(defaults: defaults)
    XCTAssertEqual(prefs.selectedCalendarIdentifiers, ["legacy-a", "legacy-b"])
    XCTAssertNil(defaults.object(forKey: "selectedCalendarIDs"))
}

func test_emptySelection_isPersistedAndNotReseeded() {
    let prefs = Preferences(defaults: defaults)
    prefs.selectedCalendarIdentifiers = ["a"]
    prefs.selectedCalendarIdentifiers = []
    let reloaded = Preferences(defaults: defaults)
    XCTAssertEqual(reloaded.selectedCalendarIdentifiers, [])
    XCTAssertTrue(reloaded.hasStoredSelection)
}

func test_resolveSelection_dropsRemovedIdentifiers() {
    XCTAssertEqual(
        Preferences.resolveSelection(current: ["a", "gone"], available: ["a", "b"]),
        ["a"]
    )
}
```

- [ ] **Step 2: Implement `Preferences`** (replacing the single-value property, keeping `pickDefaultIdentifier`):

```swift
private enum Keys {
    static let selectedCalendarIdentifiers = "selectedCalendarIdentifiers"
    static let legacySingleIdentifier = "selectedCalendarIdentifier"
    static let legacySelectedCalendarIDs = "selectedCalendarIDs"
    static let legacyShowsNoMeetingState = "showsNoMeetingState"
}

@Published var selectedCalendarIdentifiers: Set<String> {
    didSet {
        defaults.set(Array(selectedCalendarIdentifiers).sorted(), forKey: Keys.selectedCalendarIdentifiers)
        Log.preferences.debug("Selected calendars changed (\(self.selectedCalendarIdentifiers.count))")
    }
}

var hasStoredSelection: Bool {
    defaults.object(forKey: Keys.selectedCalendarIdentifiers) != nil
}

init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    Self.migrateIfNeeded(in: defaults)
    self.selectedCalendarIdentifiers = Set(defaults.stringArray(forKey: Keys.selectedCalendarIdentifiers) ?? [])
}

static func migrateIfNeeded(in defaults: UserDefaults) {
    if defaults.object(forKey: Keys.selectedCalendarIdentifiers) == nil {
        if let single = defaults.string(forKey: Keys.legacySingleIdentifier) {
            defaults.set([single], forKey: Keys.selectedCalendarIdentifiers)
        } else if let legacyArray = defaults.stringArray(forKey: Keys.legacySelectedCalendarIDs), !legacyArray.isEmpty {
            defaults.set(legacyArray, forKey: Keys.selectedCalendarIdentifiers)
        }
    }
    defaults.removeObject(forKey: Keys.legacySingleIdentifier)
    defaults.removeObject(forKey: Keys.legacySelectedCalendarIDs)
    defaults.removeObject(forKey: Keys.legacyShowsNoMeetingState)
}

func ensureDefaultSelection(using calendars: [EKCalendar], store: EKEventStore) {
    guard !hasStoredSelection else { return }
    let availableIDs = calendars.map(\.calendarIdentifier)
    let nonSubscriptionSorted = calendars
        .filter { $0.type != .subscription }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        .map(\.calendarIdentifier)
    if let id = Self.pickDefaultIdentifier(
        available: availableIDs,
        nonSubscriptionAlphabetical: nonSubscriptionSorted,
        systemDefault: store.defaultCalendarForNewEvents?.calendarIdentifier
    ) {
        selectedCalendarIdentifiers = [id]
    }
}

static func resolveSelection(current: Set<String>, available: [String]) -> Set<String> {
    current.intersection(available)
}
```

Delete the old `migrateLegacyMultiSelectIfNeeded` and the single-value `resolveSelection`; update the R3 `resolveSelection` tests to the Set version; delete obsolete single-selection tests (`test_setSelectedCalendarIdentifier_persistsToDefaults`, etc.) and `test_migration_picksFirstFromLegacyArray` / `test_migration_emptyLegacyArrayClearsKey` / `test_migration_doesNotOverwriteExistingSelection` (replaced by the new migration tests above; keep an equivalent of the do-not-overwrite case asserting the new key wins over legacy keys).

- [ ] **Step 3: `SnapshotBuilder`** — signature change:

```swift
static func computeSnapshot(
    events: [CalendarEvent],
    selectedCalendarIDs: Set<String>,
    now: Date,
    calendar: Calendar
) -> EventProgressSnapshot {
    guard !selectedCalendarIDs.isEmpty else { return .noCalendar }
    let relevant = events
        .filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
        .sorted { $0.startDate < $1.startDate }
    // … rest unchanged (earliest-start overlap wins by construction)
}
```

- [ ] **Step 4: `CalendarManager`** — `selectedCalendars(using:) -> [EKCalendar]` filters `availableCalendars` by membership; `refreshEvents` guards `!calendars.isEmpty` and passes the array to `predicateForEvents`; `currentSnapshot(selectedCalendarIDs: Set<String>, now:)`. `handleStoreChanged` uses the Set `resolveSelection`:

```swift
let resolved = Preferences.resolveSelection(
    current: preferences.selectedCalendarIdentifiers,
    available: availableCalendars.map(\.calendarIdentifier)
)
if resolved != preferences.selectedCalendarIdentifiers {
    preferences.selectedCalendarIdentifiers = resolved
}
```

`EventProgressModel.refreshSnapshot` passes `preferences?.selectedCalendarIdentifiers ?? []`.

- [ ] **Step 5: `SettingsView`** — checkbox rows ("Tracked Calendar" header becomes "Tracked Calendars"):

```swift
Image(systemName: isSelected ? "checkmark.square.fill" : "square")
```

with toggle action `preferences.selectedCalendarIdentifiers.formSymmetricDifference([calendar.calendarIdentifier])`, and `onChange(of: preferences.selectedCalendarIdentifiers)`.

- [ ] **Step 6: Snapshot tests** — update the calendar-filter test names/params to the Set signature (every existing `selectedCalendarID: calendarID` becomes `selectedCalendarIDs: [calendarID]`), plus:

```swift
func test_eventsMergedAcrossSelectedCalendars() {
    let now = fixedNoon()
    let snapshot = SnapshotBuilder.computeSnapshot(
        events: [
            makeEvent(title: "Cal B event", startOffset: 3600, durationSeconds: 1800,
                      calendarID: otherCalendarID, relativeTo: now),
            makeEvent(title: "Cal A event", startOffset: 7200, durationSeconds: 1800, relativeTo: now),
        ],
        selectedCalendarIDs: [calendarID, otherCalendarID],
        now: now,
        calendar: calendar
    )
    XCTAssertEqual(snapshot.state, .upcomingToday)
    XCTAssertEqual(snapshot.secondaryMessage, "Next: Cal B event in 1h 0min")
}

func test_overlappingEvents_showEarliestStart() {
    let now = fixedNoon()
    let snapshot = SnapshotBuilder.computeSnapshot(
        events: [
            makeEvent(title: "Started second", startOffset: -600, durationSeconds: 3600,
                      calendarID: otherCalendarID, relativeTo: now),
            makeEvent(title: "Started first", startOffset: -1200, durationSeconds: 3600, relativeTo: now),
        ],
        selectedCalendarIDs: [calendarID, otherCalendarID],
        now: now,
        calendar: calendar
    )
    XCTAssertEqual(snapshot.title, "Started first")
}

func test_emptySelection_isNoCalendar() {
    let now = fixedNoon()
    let snapshot = SnapshotBuilder.computeSnapshot(
        events: [makeEvent(startOffset: -60, durationSeconds: 1800, relativeTo: now)],
        selectedCalendarIDs: [],
        now: now,
        calendar: calendar
    )
    XCTAssertEqual(snapshot.state, .noCalendar)
}
```

- [ ] **Step 7: README** — "Picks one calendar" bullet becomes "Pick one or more calendars (checkboxes in Settings)"; states table intro adjusted.

- [ ] **Step 8: Verify, commit & PR**

```bash
swiftlint && swift build && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
git checkout -b feat/multi-calendar feat/join-button
git add -A && git commit -m "feat(calendar): track multiple calendars"
git push -u origin feat/multi-calendar
gh pr create --base feat/join-button --title "feat(calendar): multi-calendar tracking" --body "..."
```

---

### Task P4: French localization

**Branch:** `feat/french-localization` off `feat/multi-calendar`. PR base: `feat/multi-calendar`.

**Files:**
- Create: `Sources/Resources/Localizable.xcstrings`
- Modify: `Package.swift` (`defaultLocalization`, resources)
- Modify: `Sources/Calendar/SnapshotBuilder.swift`, `Sources/Calendar/EventProgressModel.swift`, `Sources/NotchPanel/NotchPanelView.swift`, `Sources/Settings/SettingsView.swift`, `Sources/NotchBarApp.swift`
- Modify: `Supporting/Info.plist` (`CFBundleDevelopmentRegion`, `CFBundleLocalizations`), `scripts/package.sh` (copy resource bundle)
- Test: `Tests/NotchBarTests/LocalizationTests.swift` (create), locale pinning in `SnapshotComputationTests.swift`

**Interfaces:**
- Produces: `SnapshotBuilder.computeSnapshot(events:selectedCalendarIDs:now:calendar:locale: Locale = .current)`; `EventProgressSnapshot.noCalendar(locale:)` / `.emptyToday(locale:)` (static funcs replacing the static lets).

- [ ] **Step 1: Package plumbing.** `Package.swift`:

```swift
let package = Package(
    name: "NotchBar",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    …
    .executableTarget(
        name: "NotchBar",
        path: "Sources",
        resources: [.process("Resources")]
    ),
```

- [ ] **Step 2: String Catalog.** Create `Sources/Resources/Localizable.xcstrings` (JSON). Keys and French values (English = key itself, no en entry needed):

| Key | fr |
|---|---|
| `Pick a calendar in Settings` | `Choisissez un calendrier dans les Réglages` |
| `No event today` | `Aucun événement aujourd'hui` |
| `In progress` | `En cours` |
| `Starts soon` | `Commence bientôt` |
| `Upcoming today` | `À venir aujourd'hui` |
| `Upcoming` | `À venir` |
| `Current Meeting` | `Réunion en cours` |
| `Upcoming Meeting` | `Réunion à venir` |
| `Starts now — %@` | `Commence maintenant — %@` |
| `Starts in %lldm — %@` | `Commence dans %lld min — %@` |
| `Next: %@ in %@` | `Prochain : %@ dans %@` |
| `Next event in: %@` | `Prochain événement dans : %@` |
| `%lldmin` | `%lld min` |
| `%lldh %lldmin` | `%lld h %lld min` |
| `Elapsed` | `Écoulé` |
| `Remaining` | `Restant` |
| `Join` | `Rejoindre` |
| `Tracked Calendars` | `Calendriers suivis` |
| `Launch at login` | `Ouvrir à la connexion` |
| `Quit NotchBar` | `Quitter NotchBar` |
| `Refresh Events` | `Actualiser les événements` |
| `Quit` | `Quitter` |
| `Calendar access is disabled. Enable it in System Settings > Privacy & Security > Calendars.` | `L'accès au calendrier est désactivé. Activez-le dans Réglages Système > Confidentialité et sécurité > Calendriers.` |
| `NotchBar has write-only calendar access and cannot read your events. Switch it to Full Access in System Settings > Privacy & Security > Calendars.` | `NotchBar a un accès en écriture seule et ne peut pas lire vos événements. Passez à l'accès complet dans Réglages Système > Confidentialité et sécurité > Calendriers.` |

Catalog JSON shape (repeat per key):

```json
{
  "sourceLanguage": "en",
  "version": "1.0",
  "strings": {
    "No event today": {
      "localizations": {
        "fr": { "stringUnit": { "state": "translated", "value": "Aucun événement aujourd'hui" } }
      }
    }
  }
}
```

- [ ] **Step 3: Code adoption.**
  - `SnapshotBuilder.computeSnapshot` gains `locale: Locale = .current`, threads it to every builder; labels use e.g. `String(localized: "In progress", bundle: .module, locale: locale)` and format strings via `String(localized: "Starts in \(minutes)m — \(title)", bundle: .module, locale: locale)` (interpolation keys must match the catalog exactly). Countdown digits (`%02d…`) stay unlocalized.
  - `EventProgressSnapshot.noCalendar` / `.emptyToday` become `static func noCalendar(locale: Locale = .current)` / `static func emptyToday(locale: Locale = .current)`; call sites (`EventProgressModel`, `SnapshotBuilder`) updated to `.noCalendar()` / `.emptyToday()` or pass the locale through.
  - Views: `Text("Elapsed", bundle: .module)` pattern for `MetricLabel` titles, `Join`, Settings strings, menu-bar items.
- [ ] **Step 4: Pin tests to English.** Every assertion on user-facing strings in `SnapshotComputationTests` passes `locale: Locale(identifier: "en")` to `computeSnapshot` so the suite is green on French machines and CI alike. Add `Tests/NotchBarTests/LocalizationTests.swift`:

```swift
import XCTest
@testable import NotchBar

final class LocalizationTests: XCTestCase {
    func test_frenchTranslation_resolves() {
        let value = String(localized: "No event today", bundle: .module, locale: Locale(identifier: "fr"))
        XCTAssertEqual(value, "Aucun événement aujourd'hui")
    }

    func test_frenchFormatString_resolves() {
        let value = String(localized: "Next event in: \("01:02:03:04")", bundle: .module, locale: Locale(identifier: "fr"))
        XCTAssertEqual(value, "Prochain événement dans : 01:02:03:04")
    }
}
```

- [ ] **Step 5: Bundle packaging.** `Supporting/Info.plist`:

```xml
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>fr</string>
    </array>
```

`scripts/package.sh`, after the binary copy line:

```bash
cp -R "$BIN_DIR/${APP_NAME}_${APP_NAME}.bundle" "$CONTENTS/Resources/"
```

- [ ] **Step 6: Verify** — `swiftlint && swift build && DEVELOPER_DIR=... swift test`; then `bash scripts/package.sh` and confirm `dist/NotchBar.app/Contents/Resources/NotchBar_NotchBar.bundle` exists. Manual: `swift run` on a French system (or per-app language set to French) shows French labels.

- [ ] **Step 7: README** — add a "Localization" line under What it does: "English and French, following the system language."

- [ ] **Step 8: Commit & PR**

```bash
git checkout -b feat/french-localization feat/multi-calendar
git add -A && git commit -m "feat(l10n): French localization via String Catalog"
git push -u origin feat/french-localization
gh pr create --base feat/multi-calendar --title "feat(l10n): French localization" --body "..."
```
