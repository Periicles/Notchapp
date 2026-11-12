@testable import NotchBar
import SwiftUI
import XCTest

/// Renders the real views and checks the pixels. These guard what the user
/// actually sees: nothing under the notch, nothing drawn at rest unless asked.
@MainActor
final class PanelRenderingE2ETests: XCTestCase {
    private var owned: [AnyObject] = []

    private func makeModel(
        events: [CalendarEvent],
        restingLine: Bool = false,
        state: CalendarManager.AuthorizationState = .granted
    ) -> EventProgressModel {
        let manager = Fixtures.calendarManager(state: state, events: events)
        let preferences = Fixtures.preferences(restingLine: restingLine)
        owned.append(manager)
        owned.append(preferences)

        let model = EventProgressModel()
        model.bind(to: manager, preferences: preferences)
        owned.append(model)
        return model
    }

    private var running: [CalendarEvent] {
        [Fixtures.event(title: "A rather long design review title", start: -900, duration: 1800)]
    }

    private let panelSize = CGSize(width: ScreenHelper.panelWidth, height: ScreenHelper.panelHeight)

    // MARK: - Open panel

    // The bug that started this: content used to begin above the lower edge of
    // the notch, which displays nothing, and lost the top of the title.
    func test_openPanel_drawsNothingBelowTheNotchBeforeItsContentInset() throws {
        let model = makeModel(events: running)
        let topInset = ScreenHelper.contentTopInset

        let image = try XCTUnwrap(RenderedImage(
            NotchContentView(
                progressModel: model,
                shimmerEnabled: false,
                topInset: topInset,
                height: ScreenHelper.panelHeight
            ),
            size: panelSize
        ))

        XCTAssertFalse(image.hasInk(inRows: 0..<Int(topInset)), "content leaks into the notch area")
        XCTAssertTrue(image.hasInk(inRows: Int(topInset)..<image.height), "no content was drawn")
    }

    func test_openPanel_drawsTheTitleAndTheBarForARunningEvent() throws {
        let model = makeModel(events: running)

        let image = try XCTUnwrap(RenderedImage(
            NotchContentView(
                progressModel: model,
                shimmerEnabled: false,
                topInset: ScreenHelper.contentTopInset,
                height: ScreenHelper.panelHeight
            ),
            size: panelSize
        ))

        XCTAssertGreaterThan(try XCTUnwrap(image.lastInkRow), Int(ScreenHelper.contentTopInset) + 40)
    }

    func test_openPanel_showsAMessage_whenNothingIsRunning() throws {
        for state in [CalendarManager.AuthorizationState.granted, .denied] {
            let model = makeModel(events: [], state: state)

            let image = try XCTUnwrap(RenderedImage(
                NotchContentView(
                    progressModel: model,
                    shimmerEnabled: false,
                    topInset: ScreenHelper.contentTopInset,
                    height: ScreenHelper.panelHeight
                ),
                size: panelSize
            ))

            XCTAssertTrue(image.hasInk(inRows: 0..<image.height), "\(state)")
        }
    }

    func test_openPanel_showsTheNextEventAndTheConcurrentCount() throws {
        let events = [
            Fixtures.event(title: "Now", start: -600, duration: 1800),
            Fixtures.event(title: "Also now", start: -300, duration: 1800),
            Fixtures.event(title: "Later", start: 3600, duration: 1800),
        ]
        let model = makeModel(events: events)

        let image = try XCTUnwrap(RenderedImage(
            NotchContentView(
                progressModel: model,
                shimmerEnabled: true,
                topInset: ScreenHelper.contentTopInset,
                height: ScreenHelper.panelHeight
            ),
            size: panelSize
        ))

        XCTAssertGreaterThan(model.snapshot.concurrentEventCount, 0)
        XCTAssertNotNil(model.snapshot.nextEvent)
        XCTAssertTrue(image.hasInk(inRows: 0..<image.height))
    }

    func test_openPanel_rendersWholeWhenHovered() throws {
        let model = makeModel(events: running)
        model.setHoverVisible(true)
        defer { model.setHoverVisible(false) }

        let image = try XCTUnwrap(RenderedImage(NotchPanelView(progressModel: model, onSettingsTapped: {}), size: panelSize))

        XCTAssertTrue(image.hasInk(inRows: 0..<image.height))
    }

    func test_openPanel_offersTheJoinButton_whenTheEventHasAMeetingLink() throws {
        let link = try XCTUnwrap(URL(string: "https://meet.example.com/abc"))
        let model = makeModel(events: [Fixtures.event(start: -300, duration: 1800, joinURL: link)])
        model.setHoverVisible(true)
        defer { model.setHoverVisible(false) }

        let image = try XCTUnwrap(RenderedImage(NotchPanelView(progressModel: model, onSettingsTapped: {}), size: panelSize))

        XCTAssertEqual(model.snapshot.joinURL, link)
        XCTAssertTrue(image.hasInk(inRows: Int(panelSize.height) - 40..<Int(panelSize.height)))
    }

    // MARK: - Closed panel

    // Anything drawn at rest slides with the desktop during a Space switch, so
    // by default the closed panel has to be completely empty.
    func test_closedPanel_drawsNothing_byDefault() throws {
        let model = makeModel(events: running, restingLine: false)

        let image = try XCTUnwrap(RenderedImage(NotchPanelView(progressModel: model, onSettingsTapped: {}), size: panelSize))

        XCTAssertTrue(image.isBlank)
    }

    func test_closedPanel_drawsOnlyAThinBandAroundTheNotch_whenTheLineIsOn() throws {
        let model = makeModel(events: running, restingLine: true)

        let image = try XCTUnwrap(RenderedImage(NotchPanelView(progressModel: model, onSettingsTapped: {}), size: panelSize))

        let notchBottom = Int(ScreenHelper.panelTopBleed + ScreenHelper.closedHeight())
        let glowReach = Int(RestingProgressLine.height + RestingProgressLine.glowRadius * 2)
        let lastRow = try XCTUnwrap(image.lastInkRow)
        XCTAssertGreaterThan(lastRow, notchBottom - 2, "the line should reach below the notch")
        XCTAssertLessThanOrEqual(lastRow, notchBottom + glowReach)
    }

    func test_closedPanel_drawsNothing_whenNoEventIsRunning() throws {
        let model = makeModel(events: [], restingLine: true)

        let image = try XCTUnwrap(RenderedImage(NotchPanelView(progressModel: model, onSettingsTapped: {}), size: panelSize))

        XCTAssertTrue(image.isBlank)
    }
}
