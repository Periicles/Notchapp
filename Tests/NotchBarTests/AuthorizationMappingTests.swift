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
