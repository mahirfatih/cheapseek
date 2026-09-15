import XCTest
@testable import CheapSeek

final class AppModelTests: XCTestCase {

    private func utcDate(_ year: Int, _ month: Int, _ day: Int,
                         _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return calendar.date(from: components)!
    }

    private func makeSettings() -> AppSettings {
        let suite = "AppModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppSettings(defaults: defaults)
    }

    func testIsPeakComputedFromInjectedDate() {
        let utc = TimeZone(identifier: "UTC")!
        let peakModel = AppModel(settings: makeSettings(), date: utcDate(2026, 1, 5, 2, 0), timeZone: utc, autoRefresh: false)
        XCTAssertTrue(peakModel.isPeak)

        let offPeakModel = AppModel(settings: makeSettings(), date: utcDate(2026, 1, 5, 12, 0), timeZone: utc, autoRefresh: false)
        XCTAssertFalse(offPeakModel.isPeak)
    }

    func testScheduleUsesInjectedTimeZone() {
        let utc = TimeZone(identifier: "UTC")!
        let model = AppModel(settings: makeSettings(), date: utcDate(2026, 1, 5, 12, 0), timeZone: utc, autoRefresh: false)

        XCTAssertEqual(model.timeZone, utc)
        XCTAssertEqual(model.schedule.count, 5)
        XCTAssertEqual(model.schedule[1].isPeak, true)
        XCTAssertEqual(model.schedule[2].isPeak, false)
    }

    func testRefreshRecomputesState() {
        let utc = TimeZone(identifier: "UTC")!
        let model = AppModel(settings: makeSettings(), date: utcDate(2026, 1, 5, 12, 0), timeZone: utc, autoRefresh: false)
        XCTAssertFalse(model.isPeak)

        model.refresh(now: utcDate(2026, 1, 5, 2, 0))
        XCTAssertTrue(model.isPeak)
        XCTAssertEqual(model.schedule.count, 5)
    }
}
