import XCTest
@testable import NotchBar

final class LocalizationTests: XCTestCase {
    func test_frenchTranslation_resolves() {
        let value = Localized.string("No event today", locale: Locale(identifier: "fr"))
        XCTAssertEqual(value, "Aucun événement aujourd'hui")
    }

    func test_frenchFormatString_resolves() {
        let value = Localized.string("Next event in: \("01:02:03:04")", locale: Locale(identifier: "fr"))
        XCTAssertEqual(value, "Prochain événement dans : 01:02:03:04")
    }
}
