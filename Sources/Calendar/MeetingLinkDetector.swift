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
