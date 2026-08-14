@preconcurrency import XCTest
@testable import NotchBar

@MainActor
final class PreferencesTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "NotchBarTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try await super.tearDown()
    }

    // MARK: - pickDefaultIdentifier

    func test_pickDefaultIdentifier_returnsSystemDefault_whenInAvailable() {
        let id = Preferences.pickDefaultIdentifier(
            available: ["a", "b", "c"],
            nonSubscriptionAlphabetical: ["a", "b"],
            systemDefault: "b"
        )

        XCTAssertEqual(id, "b")
    }

    func test_pickDefaultIdentifier_fallsBackToFirstNonSubscription_whenSystemDefaultMissing() {
        let id = Preferences.pickDefaultIdentifier(
            available: ["a", "b", "c"],
            nonSubscriptionAlphabetical: ["b", "a"],
            systemDefault: nil
        )

        XCTAssertEqual(id, "b")
    }

    func test_pickDefaultIdentifier_fallsBackToFirstNonSubscription_whenSystemDefaultNotInAvailable() {
        let id = Preferences.pickDefaultIdentifier(
            available: ["a", "b"],
            nonSubscriptionAlphabetical: ["a"],
            systemDefault: "x"
        )

        XCTAssertEqual(id, "a")
    }

    func test_pickDefaultIdentifier_returnsNil_whenNoCandidates() {
        let id = Preferences.pickDefaultIdentifier(
            available: [],
            nonSubscriptionAlphabetical: [],
            systemDefault: nil
        )

        XCTAssertNil(id)
    }

    func test_pickDefaultIdentifier_returnsNil_whenOnlySubscriptionsAvailable() {
        let id = Preferences.pickDefaultIdentifier(
            available: ["sub-a", "sub-b"],
            nonSubscriptionAlphabetical: [],
            systemDefault: nil
        )

        XCTAssertNil(id)
    }

    // MARK: - Legacy migration

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

    func test_migration_singleWinsOverLegacyArray_whenNewKeyAbsent() {
        defaults.set("single-id", forKey: "selectedCalendarIdentifier")
        defaults.set(["legacy-a", "legacy-b"], forKey: "selectedCalendarIDs")

        let prefs = Preferences(defaults: defaults)

        XCTAssertEqual(prefs.selectedCalendarIdentifiers, ["single-id"])
        XCTAssertNil(defaults.object(forKey: "selectedCalendarIdentifier"))
        XCTAssertNil(defaults.object(forKey: "selectedCalendarIDs"))
    }

    func test_migration_emptyLegacyArray_leavesSelectionUnstored() {
        defaults.set([String](), forKey: "selectedCalendarIDs")

        let prefs = Preferences(defaults: defaults)

        XCTAssertEqual(prefs.selectedCalendarIdentifiers, [])
        XCTAssertFalse(prefs.hasStoredSelection)
        XCTAssertNil(defaults.object(forKey: "selectedCalendarIDs"))
    }

    func test_migration_doesNotOverwriteExistingSelection() {
        defaults.set(["existing-id"], forKey: "selectedCalendarIdentifiers")
        defaults.set("legacy-solo", forKey: "selectedCalendarIdentifier")
        defaults.set(["legacy-a"], forKey: "selectedCalendarIDs")

        let prefs = Preferences(defaults: defaults)

        XCTAssertEqual(prefs.selectedCalendarIdentifiers, ["existing-id"])
        XCTAssertNil(defaults.object(forKey: "selectedCalendarIdentifier"))
        XCTAssertNil(defaults.object(forKey: "selectedCalendarIDs"))
    }

    // MARK: - Init from defaults

    func test_init_loadsExistingSelection() {
        defaults.set(["stored-a", "stored-b"], forKey: "selectedCalendarIdentifiers")

        let prefs = Preferences(defaults: defaults)

        XCTAssertEqual(prefs.selectedCalendarIdentifiers, ["stored-a", "stored-b"])
        XCTAssertTrue(prefs.hasStoredSelection)
    }

    func test_init_noSelectionStored_isEmptyAndNotMarkedStored() {
        let prefs = Preferences(defaults: defaults)

        XCTAssertEqual(prefs.selectedCalendarIdentifiers, [])
        XCTAssertFalse(prefs.hasStoredSelection)
    }

    // MARK: - Persistence

    func test_setSelectedCalendarIdentifiers_persistsToDefaults() {
        let prefs = Preferences(defaults: defaults)

        prefs.selectedCalendarIdentifiers = ["b", "a"]

        XCTAssertEqual(defaults.stringArray(forKey: "selectedCalendarIdentifiers"), ["a", "b"])
    }

    func test_emptySelection_isPersistedAndNotReseeded() {
        let prefs = Preferences(defaults: defaults)
        prefs.selectedCalendarIdentifiers = ["a"]
        prefs.selectedCalendarIdentifiers = []

        let reloaded = Preferences(defaults: defaults)

        XCTAssertEqual(reloaded.selectedCalendarIdentifiers, [])
        XCTAssertTrue(reloaded.hasStoredSelection)
    }

    // MARK: - Menu-bar countdown toggle

    func test_showsMenuBarCountdown_defaultsToTrue_whenNeverSet() {
        let prefs = Preferences(defaults: defaults)

        XCTAssertTrue(prefs.showsMenuBarCountdown)
    }

    func test_showsMenuBarCountdown_loadsStoredFalse() {
        defaults.set(false, forKey: "showsMenuBarCountdown")

        let prefs = Preferences(defaults: defaults)

        XCTAssertFalse(prefs.showsMenuBarCountdown)
    }

    func test_setShowsMenuBarCountdown_persistsToDefaults() {
        let prefs = Preferences(defaults: defaults)

        prefs.showsMenuBarCountdown = false

        XCTAssertEqual(defaults.object(forKey: "showsMenuBarCountdown") as? Bool, false)
        XCTAssertFalse(Preferences(defaults: defaults).showsMenuBarCountdown)
    }

    // MARK: - resolveSelection

    func test_resolveSelection_keepsCurrent_whenStillAvailable() {
        XCTAssertEqual(
            Preferences.resolveSelection(current: ["b"], available: ["a", "b"]),
            ["b"]
        )
    }

    func test_resolveSelection_dropsRemovedIdentifiers() {
        XCTAssertEqual(
            Preferences.resolveSelection(current: ["a", "gone"], available: ["a", "b"]),
            ["a"]
        )
    }

    func test_resolveSelection_returnsEmptySet_whenNoneAvailable() {
        XCTAssertEqual(
            Preferences.resolveSelection(current: ["gone"], available: ["a", "b"]),
            []
        )
    }
}
