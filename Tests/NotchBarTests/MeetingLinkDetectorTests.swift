import XCTest
@testable import NotchBar

final class MeetingLinkDetectorTests: XCTestCase {
    func test_zoomJoinURL_inURLField() {
        let url = URL(string: "https://us02web.zoom.us/j/1234567890")!
        XCTAssertEqual(MeetingLinkDetector.detect(url: url, location: nil, notes: nil), url)
    }

    func test_googleMeet_inLocation() {
        let expected = URL(string: "https://meet.google.com/abc-defg-hij")!
        XCTAssertEqual(
            MeetingLinkDetector.detect(url: nil, location: "https://meet.google.com/abc-defg-hij", notes: nil),
            expected
        )
    }

    func test_teams_inNotes() {
        let notes = "Agenda…\nJoin: https://teams.microsoft.com/l/meetup-join/19%3ameeting_x, see you"
        XCTAssertEqual(
            MeetingLinkDetector.detect(url: nil, location: nil, notes: notes)?.host(),
            "teams.microsoft.com"
        )
    }

    func test_webexSubdomain_isDetected() {
        let url = URL(string: "https://acme.webex.com/meet/jdoe")!
        XCTAssertEqual(MeetingLinkDetector.detect(url: url, location: nil, notes: nil), url)
    }

    func test_urlFieldBeatsNotes() {
        let urlField = URL(string: "https://zoom.us/j/111")!
        let result = MeetingLinkDetector.detect(url: urlField, location: nil, notes: "https://meet.google.com/xyz-aaaa-bbb")
        XCTAssertEqual(result, urlField)
    }

    func test_nonMeetingURL_returnsNil() {
        XCTAssertNil(MeetingLinkDetector.detect(url: URL(string: "https://example.com/agenda")!, location: nil, notes: nil))
    }

    func test_plainText_returnsNil() {
        XCTAssertNil(MeetingLinkDetector.detect(url: nil, location: "Room 4B", notes: "Bring the deck"))
    }

    func test_httpScheme_returnsNil() {
        XCTAssertNil(MeetingLinkDetector.detect(url: URL(string: "http://zoom.us/j/111")!, location: nil, notes: nil))
    }

    func test_zoomWithoutJoinPath_returnsNil() {
        XCTAssertNil(MeetingLinkDetector.detect(url: URL(string: "https://zoom.us/pricing")!, location: nil, notes: nil))
    }
}
