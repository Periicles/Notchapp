import Foundation

/// Compares the running version with the latest GitHub release, only when the
/// user asks: NotchBar never reaches the network on its own.
@MainActor
final class UpdateChecker: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(ReleaseVersion, URL)
        case failed
    }

    /// Returns the URL `…/releases/latest` redirects to.
    typealias LatestReleaseFetcher = @MainActor () async throws -> URL

    @Published private(set) var state: State = .idle

    /// `nil` when the binary carries no version — a `swift run` build has no
    /// Info.plist — in which case there is nothing meaningful to compare.
    let installedVersion: ReleaseVersion?

    private let fetchLatestRelease: LatestReleaseFetcher

    init(
        installedVersion: ReleaseVersion? = UpdateChecker.bundleVersion(),
        fetchLatestRelease: @escaping LatestReleaseFetcher = { try await LatestReleaseLocator.fetch() }
    ) {
        self.installedVersion = installedVersion
        self.fetchLatestRelease = fetchLatestRelease
    }

    var canCheck: Bool {
        installedVersion != nil && state != .checking
    }

    func check() async {
        guard canCheck, let installedVersion else { return }
        state = .checking

        do {
            let location = try await fetchLatestRelease()
            guard let latest = ReleaseVersion(releaseLocation: location) else {
                Log.updates.error("Latest release redirect is not a tag page")
                state = .failed
                return
            }
            state = latest > installedVersion ? .available(latest, location) : .upToDate
            Log.updates.info(
                "Latest release \(latest, privacy: .public), installed \(installedVersion, privacy: .public)"
            )
        } catch {
            Log.updates.error("Update check failed: \(error.localizedDescription, privacy: .public)")
            state = .failed
        }
    }

    nonisolated static func bundleVersion(_ bundle: Bundle = .main) -> ReleaseVersion? {
        (bundle.infoDictionary?["CFBundleShortVersionString"] as? String).flatMap(ReleaseVersion.init)
    }
}

/// Asks GitHub where `releases/latest` points without following the redirect:
/// the tag sits in the `Location` header, so a `HEAD` is enough and nothing
/// but the request line leaves the machine — no API token, no cookies.
enum LatestReleaseLocator {
    enum Failure: Error {
        case unexpectedResponse
    }

    static let latestReleaseURL = URL(string: "https://github.com/Periicles/Notchapp/releases/latest")!
    private static let timeout: TimeInterval = 10

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        return URLSession(configuration: configuration, delegate: RedirectRefusal(), delegateQueue: nil)
    }()

    static func fetch() async throws -> URL {
        var request = URLRequest(url: latestReleaseURL, timeoutInterval: timeout)
        request.httpMethod = "HEAD"

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (300..<400).contains(http.statusCode),
              let header = http.value(forHTTPHeaderField: "Location"),
              let location = URL(string: header, relativeTo: latestReleaseURL)?.absoluteURL else {
            throw Failure.unexpectedResponse
        }
        return location
    }
}

/// Hands the redirect response back as the result instead of following it.
private final class RedirectRefusal: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
