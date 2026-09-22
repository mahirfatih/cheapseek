import XCTest
import SwiftUI
import ViewInspector
@testable import CheapSeek

@MainActor
final class PopupViewTests: XCTestCase {

    private func utcDate(_ day: Int, _ hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar.date(from: DateComponents(year: 2026, month: 1, day: day, hour: hour)) ?? Date()
    }

    private func makeModel(now: Date) -> AppModel {
        let suite = "PopupViewTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = AppSettings(defaults: defaults)
        settings.timeZoneIdentifier = "UTC"
        return AppModel(
            settings: settings,
            config: .fallback,
            clock: Clock(now: now),
            autoStart: false
        )
    }

    func testPopupViewRenders() {
        let view = PopupView(model: makeModel(now: utcDate(5, 2)))
        _ = view.body
        XCTAssertNoThrow(try view.inspect())

        // The menu-bar label renders the live status text for a fixed instant.
        XCTAssertNoThrow(try MenuBarLabel(model: makeModel(now: utcDate(5, 2))).inspect()
            .find(text: MenuBarLabel.text(for: .peak)))
        XCTAssertNoThrow(try MenuBarLabel(model: makeModel(now: utcDate(5, 12))).inspect()
            .find(text: MenuBarLabel.text(for: .offPeak)))
    }

    func testStatusBodyRendersPeakAndOffPeak() {
        let body = PopupStatusBody(model: makeModel(now: utcDate(5, 2)), now: utcDate(5, 2))
        _ = body.body
        XCTAssertNoThrow(try body.inspect())
        _ = try? PopupStatusBody(model: makeModel(now: utcDate(5, 12)), now: utcDate(5, 12)).inspect()

        // 2026-01-05 02:00 UTC is inside the Mon–Fri 01:00–04:00 peak window;
        // 12:00 UTC on the same day is outside both peak windows.
        XCTAssertEqual(body.currentStatus, .peak)
        XCTAssertEqual(PopupStatusBody(model: makeModel(now: utcDate(5, 12)), now: utcDate(5, 12)).currentStatus, .offPeak)
    }

    func testStatusBodyHelpers() {
        let body = PopupStatusBody(model: makeModel(now: utcDate(5, 2)), now: utcDate(5, 2))
        XCTAssertFalse(body.locale.identifier.isEmpty)
        XCTAssertEqual(body.timeFormat.timeZone, TimeZone(identifier: "UTC"))
        XCTAssertEqual(body.timeShortFormat.timeZone, TimeZone(identifier: "UTC"))
        XCTAssertFalse(body.timeZoneName.isEmpty)

        let row = body.scheduleRow((start: utcDate(5, 1), end: utcDate(5, 4), isPeak: true))
        _ = try? row.inspect()
    }

    func testInfoContentRenders() {
        let view = PopupInfoContent(config: .fallback, timeZone: .gmt, onClose: {})
        _ = view.body
        _ = try? view.inspect()
    }

    func testHistorySectionRenders() {
        let view = PopupHistorySection(model: makeModel(now: utcDate(5, 2)), isExpanded: .constant(true))
        _ = view.body
        _ = try? view.inspect()
    }

    func testActionButtonsRender() {
        var settingsTapped = false
        var pricingTapped = false
        var aboutTapped = false
        let view = PopupActionButtons(
            onSettings: { settingsTapped = true },
            onPricing: { pricingTapped = true },
            onAbout: { aboutTapped = true },
            onQuit: {}
        )
        _ = view.body
        _ = try? view.inspect()
        XCTAssertFalse(settingsTapped)
        XCTAssertFalse(pricingTapped)
        XCTAssertFalse(aboutTapped)
    }
}
