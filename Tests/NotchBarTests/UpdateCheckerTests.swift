@preconcurrency import XCTest
@testable import NotchBar

@MainActor
final class UpdateCheckerTests: XCTestCase {
    private let releaseURL = URL(string: "https://github.com/Periicles/Notchapp/releases/tag/v0.4.0")!

    private struct OfflineError: Error {}

    func test_check_reportsNewerRelease() async {
        let url = releaseURL
        let checker = UpdateChecker(installedVersion: ReleaseVersion("0.3.3")) { url }

        await checker.check()

        XCTAssertEqual(checker.state, .available(ReleaseVersion("0.4.0")!, url))
    }

    func test_check_reportsUpToDate_whenSameVersion() async {
        let url = releaseURL
        let checker = UpdateChecker(installedVersion: ReleaseVersion("0.4.0")) { url }

        await checker.check()

        XCTAssertEqual(checker.state, .upToDate)
    }

    func test_check_reportsUpToDate_whenInstalledIsAhead() async {
        let url = releaseURL
        let checker = UpdateChecker(installedVersion: ReleaseVersion("0.5.0")) { url }

        await checker.check()

        XCTAssertEqual(checker.state, .upToDate)
    }

    func test_check_fails_onNetworkError() async {
        let checker = UpdateChecker(installedVersion: ReleaseVersion("0.3.3")) { throw OfflineError() }

        await checker.check()

        XCTAssertEqual(checker.state, .failed)
    }

    func test_check_fails_whenLocationIsNotATag() async {
        let checker = UpdateChecker(installedVersion: ReleaseVersion("0.3.3")) {
            URL(string: "https://github.com/login")!
        }

        await checker.check()

        XCTAssertEqual(checker.state, .failed)
    }

    func test_check_doesNothing_withoutInstalledVersion() async {
        var fetched = false
        let checker = UpdateChecker(installedVersion: nil) {
            fetched = true
            return URL(string: "https://example.com")!
        }

        XCTAssertFalse(checker.canCheck)
        await checker.check()

        XCTAssertFalse(fetched)
        XCTAssertEqual(checker.state, .idle)
    }

    func test_latestReleaseURL_pointsAtTheRepository() {
        XCTAssertEqual(
            LatestReleaseLocator.latestReleaseURL.absoluteString,
            "https://github.com/Periicles/Notchapp/releases/latest"
        )
    }

    func test_bundleVersion_readsShortVersionString() throws {
        let bundle = try makeBundle(info: ["CFBundleShortVersionString": "0.4.0"])
        XCTAssertEqual(UpdateChecker.bundleVersion(bundle), ReleaseVersion("0.4.0"))
    }

    func test_bundleVersion_isNil_withoutUsableVersion() throws {
        XCTAssertNil(UpdateChecker.bundleVersion(try makeBundle(info: [:])))
        XCTAssertNil(UpdateChecker.bundleVersion(try makeBundle(info: ["CFBundleShortVersionString": "dev"])))
    }

    func test_canCheck_isFalseWhileChecking() async {
        let url = releaseURL
        let gate = AsyncStream<Void>.makeStream()
        let checker = UpdateChecker(installedVersion: ReleaseVersion("0.3.3")) {
            for await _ in gate.stream { break }
            return url
        }

        let task = Task { await checker.check() }
        while checker.state != .checking { await Task.yield() }
        XCTAssertFalse(checker.canCheck)

        gate.continuation.yield()
        await task.value
        XCTAssertTrue(checker.canCheck)
    }

    private func makeBundle(info: [String: String]) throws -> Bundle {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("UpdateCheckerTests-\(UUID().uuidString).bundle")
        let contents = url.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }

        var plist: [String: String] = ["CFBundleIdentifier": "com.periicles.NotchBarTests.\(UUID().uuidString)"]
        plist.merge(info) { _, new in new }
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))

        return try XCTUnwrap(Bundle(url: url))
    }
}
