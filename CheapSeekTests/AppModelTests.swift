import XCTest
import Localize_Swift
@testable import CheapSeek

final class AppModelTests: XCTestCase {

    private func utcDate(_ year: Int, _ month: Int, _ day: Int,
                         _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return calendar.date(from: components) ?? Date()
    }

    private func makeSettings(timeZoneIdentifier: String = "UTC") -> AppSettings {
        let suite = "AppModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = AppSettings(defaults: defaults)
        settings.timeZoneIdentifier = timeZoneIdentifier
        return settings
    }

    private func makeModel(hour: Int) -> AppModel {
        AppModel(
            settings: makeSettings(),
            config: .fallback,
            clock: Clock(now: utcDate(2026, 1, 5, hour, 0)),
            autoStart: false
        )
    }

    func testIsPeakComputedFromInjectedClock() {
        XCTAssertTrue(makeModel(hour: 2).isPeak)
        XCTAssertFalse(makeModel(hour: 12).isPeak)
    }

    func testScheduleUsesSettingsTimeZone() {
        let model = makeModel(hour: 12)

        XCTAssertEqual(model.timeZone, TimeZone(identifier: "UTC"))
        XCTAssertEqual(model.schedule.count, 5)
        XCTAssertEqual(model.schedule[1].isPeak, true)
        XCTAssertEqual(model.schedule[2].isPeak, false)
    }

    func testSetUpdateIntervalClampsToRange() {
        let model = makeModel(hour: 12)
        // Should not crash; the clock is simply restarted with a clamped interval.
        model.setUpdateInterval(1)
        model.setUpdateInterval(1000)
    }

    func testLanguageChangeNotificationIncrementsRevision() {
        let model = makeModel(hour: 12)
        let before = model.languageRevision
        let exp = expectation(description: "language revision increments")

        NotificationCenter.default.post(
            name: Notification.Name(rawValue: LCLLanguageChangeNotification),
            object: nil
        )
        DispatchQueue.main.async { exp.fulfill() }

        wait(for: [exp], timeout: 1)
        XCTAssertGreaterThan(model.languageRevision, before)
    }
}
