import Foundation

/// A `major.minor.patch` version as NotchBar tags its releases (`v0.3.3`).
/// Missing trailing components count as zero, so `v1.2` equals `1.2.0`.
/// Anything else — pre-release suffixes included — is rejected rather than
/// guessed at: NotchBar only publishes plain numeric tags.
struct ReleaseVersion: Comparable, CustomStringConvertible, Sendable {
    private static let componentCount = 3

    private let components: [Int]

    init?(_ string: String) {
        let trimmed = string.hasPrefix("v") ? string.dropFirst() : Substring(string)
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...Self.componentCount).contains(parts.count) else { return nil }

        var components: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy(\.isASCIIDigit), let value = Int(part) else { return nil }
            components.append(value)
        }
        components += Array(repeating: 0, count: Self.componentCount - components.count)
        self.components = components
    }

    /// Reads the version out of a release page URL
    /// (`…/releases/tag/v0.4.0`), which is where GitHub redirects
    /// `…/releases/latest`.
    init?(releaseLocation url: URL) {
        let path = url.pathComponents
        guard path.count >= 3,
              path[path.count - 3] == "releases",
              path[path.count - 2] == "tag" else { return nil }
        self.init(path[path.count - 1])
    }

    var description: String {
        components.map(String.init).joined(separator: ".")
    }

    static func < (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        lhs.components.lexicographicallyPrecedes(rhs.components)
    }
}

private extension Character {
    var isASCIIDigit: Bool {
        isASCII && isNumber
    }
}
