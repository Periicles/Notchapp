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

    func test_migration_picksFirstFromLegacyArray() {
        defaults.set(["legacy-a", "legacy-b", "legacy-c"], forKey: "selectedCalendarIDs")

        let prefs = Preferences(defaults: defaults)

        XCTAssertEqual(prefs.selectedCalendarIdentifier, "legacy-a")
        XCTAssertNil(defaults.object(forKey: "selectedCalendarIDs"))
    }

    func test_migration_emptyLegacyArrayClearsKey() {
        defaults.set([String](), forKey: "selectedCalendarIDs")

        let prefs = Preferences(defaults: defaults)

        XCTAssertNil(prefs.selectedCalendarIdentifier)
        XCTAssertNil(defaults.object(forKey: "selectedCalendarIDs"))
    }

    func test_migration_doesNotOverwriteExistingSelection() {
        defaults.set("existing-id", forKey: "selectedCalendarIdentifier")
        defaults.set(["legacy-a"], forKey: "selectedCalendarIDs")

        let prefs = Preferences(defaults: defaults)

        XCTAssertEqual(prefs.selectedCalendarIdentifier, "existing-id")
        XCTAssertEqual(defaults.stringArray(forKey: "selectedCalendarIDs"), ["legacy-a"])
    }

    // MARK: - Init from defaults

    func test_init_loadsExistingSelection() {
        defaults.set("stored-id", forKey: "selectedCalendarIdentifier")

        let prefs = Preferences(defaults: defaults)

        XCTAssertEqual(prefs.selectedCalendarIdentifier, "stored-id")
    }

    func test_init_noSelectionStored_leavesIdentifierNil() {
        let prefs = Preferences(defaults: defaults)

        XCTAssertNil(prefs.selectedCalendarIdentifier)
    }

    // MARK: - Persistence

    func test_setSelectedCalendarIdentifier_persistsToDefaults() {
        let prefs = Preferences(defaults: defaults)

        prefs.selectedCalendarIdentifier = "new-id"

        XCTAssertEqual(defaults.string(forKey: "selectedCalendarIdentifier"), "new-id")
    }

    func test_clearingSelectedCalendarIdentifier_removesFromDefaults() {
        defaults.set("initial-id", forKey: "selectedCalendarIdentifier")
        let prefs = Preferences(defaults: defaults)

        prefs.selectedCalendarIdentifier = nil

        XCTAssertNil(defaults.object(forKey: "selectedCalendarIdentifier"))
    }
}
