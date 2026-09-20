import XCTest
@testable import NotchBar

final class LocalizationTests: XCTestCase {
    func test_resources_carryBothLocalizations() {
        // Guards the bundle name and the lookup: if `Localized.resources` ever
        // resolves to something without the .lproj folders, every string in the
        // app silently falls back to its key.
        XCTAssertNotNil(Localized.resources.path(forResource: "en", ofType: "lproj"))
        XCTAssertNotNil(Localized.resources.path(forResource: "fr", ofType: "lproj"))
    }

    func test_frenchTranslation_resolves() {
        let value = Localized.string("No event today", locale: Locale(identifier: "fr"))
        XCTAssertEqual(value, "Aucun événement aujourd'hui")
    }

    func test_frenchFormatString_resolves() {
        let value = Localized.string("All day: \("Férié")", locale: Locale(identifier: "fr"))
        XCTAssertEqual(value, "Toute la journée : Férié")
    }

    func test_frenchAccessRevoked_resolves() {
        let value = Localized.string("Calendar access is off — re-enable in Settings", locale: Locale(identifier: "fr"))
        XCTAssertEqual(value, "Accès au calendrier désactivé — réactivez-le dans les Réglages")
    }

    func test_frenchThenPrefix_resolves() {
        XCTAssertEqual(Localized.string("Then:", locale: Locale(identifier: "fr")), "Ensuite :")
    }

    func test_frenchBlockedNotifications_resolves() {
        let value = Localized.string(
            "Notifications are blocked for NotchBar in System Settings.",
            locale: Locale(identifier: "fr")
        )
        XCTAssertEqual(value, "Les notifications de NotchBar sont bloquées dans les Réglages Système.")
    }
}
