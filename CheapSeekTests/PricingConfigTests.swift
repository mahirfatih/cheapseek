import XCTest
@testable import CheapSeek

final class PricingConfigTests: XCTestCase {

    func testBundledConfigurationIsPresent() {
        let url = Bundle(for: AppModel.self).url(forResource: "Configuration", withExtension: "plist")
        XCTAssertNotNil(url, "Configuration.plist should be bundled as a resource")
    }

    func testLoadParsesModels() {
        let config = DeepSeekConfig.load(from: Bundle(for: AppModel.self))
        XCTAssertEqual(config.models.count, 2)
        XCTAssertEqual(config.models.first?.id, "deepseek-flash")
        XCTAssertEqual(config.models.first?.name, "DeepSeek-V4.1-Flash")
        XCTAssertEqual(config.models.last?.id, "deepseek-v4-pro")
    }

    func testConfigExposesUsageURL() {
        let config = DeepSeekConfig.load(from: Bundle(for: AppModel.self))
        XCTAssertEqual(config.usageURL, "https://platform.deepseek.com/usage")
        XCTAssertEqual(DeepSeekConfig.fallback.usageURL, "https://platform.deepseek.com/usage")
    }

    func testFallbackScheduleMatchesDeepSeekDefaults() {
        let schedule = DeepSeekConfig.fallback.schedule
        XCTAssertEqual(schedule.windows, [
            PeakWindow(startHour: 1, endHour: 4),
            PeakWindow(startHour: 6, endHour: 10)
        ])
        XCTAssertTrue(schedule.weekdayOnly)
    }

    func testCustomSchedulePeakCalculation() {
        let schedule = PeakSchedule(
            windows: [PeakWindow(startHour: 12, endHour: 13)],
            weekdayOnly: false,
            timeZone: TimeZone(identifier: "UTC")!
        )

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        var weekday = DateComponents()
        weekday.year = 2026; weekday.month = 1; weekday.day = 5; weekday.hour = 12; weekday.minute = 30
        XCTAssertTrue(PeakCalculator.isPeak(at: calendar.date(from: weekday)!, schedule: schedule))

        var weekend = DateComponents()
        weekend.year = 2026; weekend.month = 1; weekend.day = 3; weekend.hour = 12; weekend.minute = 30
        XCTAssertTrue(PeakCalculator.isPeak(at: calendar.date(from: weekend)!, schedule: schedule))

        var before = DateComponents()
        before.year = 2026; before.month = 1; before.day = 5; before.hour = 11; before.minute = 30
        XCTAssertFalse(PeakCalculator.isPeak(at: calendar.date(from: before)!, schedule: schedule))
    }

    func testFallbackLoadWhenBundleMissing() {
        let config = DeepSeekConfig.load(from: Bundle(path: "/tmp/definitely-not-a-bundle") ?? .main)
        XCTAssertEqual(config, .fallback)
    }
}
