import XCTest
@testable import CheapSeek

final class NotificationPlannerTests: XCTestCase {

    private let schedule = PeakSchedule.deepseekDefault

    private func utcDate(_ year: Int, _ month: Int, _ day: Int,
                         _ hour: Int, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }

    private func plan(
        now: Date,
        beforePeakMinutes: Int = 5,
        notifyOffPeak: Bool = true,
        notifyPeakStart: Bool = false,
        quietHours: NotificationPlanner.QuietHours = .disabled
    ) -> [PlannedNotification] {
        NotificationPlanner.plan(
            now: now,
            schedule: schedule,
            timeZone: .gmt,
            beforePeakMinutes: beforePeakMinutes,
            notifyOnOffPeakStart: notifyOffPeak,
            notifyOnPeakStart: notifyPeakStart,
            quietHours: quietHours
        )
    }

    func testOffPeakStartIsScheduledWhenPeakEnds() {
        let now = utcDate(2026, 1, 5, 2) // Monday, inside the 01:00–04:00 peak window
        let plans = plan(now: now)

        let offPeak = plans.first { $0.kind == .offPeakStart }
        XCTAssertEqual(offPeak?.fireDate, utcDate(2026, 1, 5, 4))
        XCTAssertNil(offPeak?.bodyArgument)
    }

    func testPeakWarningFiresFiveMinutesBeforePeak() {
        let now = utcDate(2026, 1, 5, 22) // Monday, before Tuesday's 01:00 peak
        let plans = plan(now: now)

        let warning = plans.first { $0.kind == .peakSoon }
        XCTAssertEqual(warning?.fireDate, utcDate(2026, 1, 6, 0, 55))
        XCTAssertEqual(warning?.bodyArgument, 5)
        XCTAssertEqual(warning?.titleKey, "notification.peak_soon.title")
    }

    func testZeroBeforePeakDisablesWarning() {
        let plans = plan(now: utcDate(2026, 1, 5, 22), beforePeakMinutes: 0)
        XCTAssertTrue(plans.allSatisfy { $0.kind != .peakSoon })
    }

    func testPeakStartOnlyWhenEnabled() {
        let now = utcDate(2026, 1, 5, 22)
        XCTAssertTrue(plan(now: now).allSatisfy { $0.kind != .peakStart })

        let withPeakStart = plan(now: now, notifyPeakStart: true)
        XCTAssertTrue(withPeakStart.contains { $0.kind == .peakStart && $0.fireDate == utcDate(2026, 1, 6, 1) })
    }

    func testAllDisabledProducesNoPlans() {
        let now = utcDate(2026, 1, 5, 22)
        XCTAssertTrue(plan(now: now, beforePeakMinutes: 0, notifyOffPeak: false, notifyPeakStart: false).isEmpty)
    }

    func testPastFireDatesAreDropped() {
        let now = utcDate(2026, 1, 5, 2)
        XCTAssertTrue(plan(now: now).allSatisfy { $0.fireDate > now })
    }

    func testHorizonCoversMultipleTransitions() {
        let plans = plan(now: utcDate(2026, 1, 5, 12))
        let days = Set(plans.map { Calendar(identifier: .gregorian).component(.day, from: $0.fireDate) })
        XCTAssertGreaterThan(days.count, 2)
    }

    func testQuietHoursSuppressEventsInsideWindow() {
        let quiet = NotificationPlanner.QuietHours(enabled: true, startMinutes: 23 * 60, endMinutes: 7 * 60)
        let plans = plan(now: utcDate(2026, 1, 5, 22, 30), quietHours: quiet)

        for planned in plans {
            XCTAssertFalse(
                NotificationPlanner.isQuiet(planned.fireDate, quietHours: quiet, timeZone: .gmt),
                "\(planned.kind) at \(planned.fireDate) should be suppressed"
            )
        }
        // The next peak warning would be at 00:55, inside quiet hours.
        XCTAssertTrue(plans.allSatisfy { $0.kind != .peakSoon })
    }

    func testIsQuietHandlesWrapAroundWindow() {
        let quiet = NotificationPlanner.QuietHours(enabled: true, startMinutes: 23 * 60, endMinutes: 7 * 60)
        XCTAssertTrue(NotificationPlanner.isQuiet(utcDate(2026, 1, 5, 23, 30), quietHours: quiet, timeZone: .gmt))
        XCTAssertTrue(NotificationPlanner.isQuiet(utcDate(2026, 1, 5, 6, 30), quietHours: quiet, timeZone: .gmt))
        XCTAssertFalse(NotificationPlanner.isQuiet(utcDate(2026, 1, 5, 7, 0), quietHours: quiet, timeZone: .gmt))
        XCTAssertFalse(NotificationPlanner.isQuiet(utcDate(2026, 1, 5, 22, 59), quietHours: quiet, timeZone: .gmt))
    }

    func testIsQuietIsFalseWhenDisabledOrZeroLength() {
        XCTAssertFalse(NotificationPlanner.isQuiet(utcDate(2026, 1, 5, 2), quietHours: .disabled, timeZone: .gmt))

        let zeroLength = NotificationPlanner.QuietHours(enabled: true, startMinutes: 0, endMinutes: 0)
        XCTAssertFalse(NotificationPlanner.isQuiet(utcDate(2026, 1, 5, 2), quietHours: zeroLength, timeZone: .gmt))
    }

    func testIsQuietHandlesSameDayWindow() {
        let quiet = NotificationPlanner.QuietHours(enabled: true, startMinutes: 9 * 60, endMinutes: 17 * 60)

        XCTAssertTrue(NotificationPlanner.isQuiet(utcDate(2026, 1, 5, 10), quietHours: quiet, timeZone: .gmt))
        XCTAssertFalse(NotificationPlanner.isQuiet(utcDate(2026, 1, 5, 8, 59), quietHours: quiet, timeZone: .gmt))
        XCTAssertFalse(NotificationPlanner.isQuiet(utcDate(2026, 1, 5, 17, 0), quietHours: quiet, timeZone: .gmt))
    }
}
