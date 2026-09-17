import XCTest
@testable import NotchBar

final class ReleaseVersionTests: XCTestCase {
    // MARK: - Parsing

    func test_init_parsesPlainVersion() {
        XCTAssertEqual(ReleaseVersion("0.3.3")?.description, "0.3.3")
    }

    func test_init_stripsLeadingV() {
        XCTAssertEqual(ReleaseVersion("v1.2.3")?.description, "1.2.3")
    }

    func test_init_padsMissingComponents() {
        XCTAssertEqual(ReleaseVersion("1")?.description, "1.0.0")
        XCTAssertEqual(ReleaseVersion("v1.2")?.description, "1.2.0")
    }

    func test_init_rejectsMalformedInput() {
        for input in ["", "v", "latest", "1.2.3.4", "1..2", "1.2.x", "-1.0.0", "1.2.3-beta", " 1.2.3"] {
            XCTAssertNil(ReleaseVersion(input), "\(input) should not parse")
        }
    }

    // MARK: - Ordering

    func test_ordering_comparesNumericallyNotLexically() {
        XCTAssertLessThan(ReleaseVersion("0.3.9")!, ReleaseVersion("0.3.10")!)
        XCTAssertLessThan(ReleaseVersion("0.9.0")!, ReleaseVersion("0.10.0")!)
        XCTAssertLessThan(ReleaseVersion("0.99.99")!, ReleaseVersion("1.0.0")!)
    }

    func test_equality_ignoresPaddingAndPrefix() {
        XCTAssertEqual(ReleaseVersion("v1.2"), ReleaseVersion("1.2.0"))
    }

    // MARK: - Release page location

    func test_fromReleaseLocation_readsTag() {
        let url = URL(string: "https://github.com/Periicles/Notchapp/releases/tag/v0.4.0")!
        XCTAssertEqual(ReleaseVersion(releaseLocation: url), ReleaseVersion("0.4.0"))
    }

    func test_fromReleaseLocation_rejectsNonTagPaths() {
        let urls = [
            "https://github.com/Periicles/Notchapp/releases",
            "https://github.com/Periicles/Notchapp/releases/latest",
            "https://github.com/Periicles/Notchapp/releases/tag/nightly",
            "https://github.com/Periicles/Notchapp/tree/v0.4.0",
        ]
        for string in urls {
            XCTAssertNil(ReleaseVersion(releaseLocation: URL(string: string)!), string)
        }
    }
}
