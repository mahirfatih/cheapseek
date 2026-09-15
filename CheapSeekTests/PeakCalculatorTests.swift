import XCTest
@testable import CheapSeek

final class PeakCalculatorTests: XCTestCase {

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

    // MARK: - isPeak

    func testIsPeakInsideFirstWindow() {
        XCTAssertTrue(PeakCalculator.isPeak(at: utcDate(2026, 1, 5, 2, 30))) // Monday
    }

    func testIsPeakInsideSecondWindow() {
        XCTAssertTrue(PeakCalculator.isPeak(at: utcDate(2026, 1, 5, 8, 0))) // Monday
    }

    func testIsPeakStartOfFirstWindowInclusive() {
        XCTAssertTrue(PeakCalculator.isPeak(at: utcDate(2026, 1, 5, 1, 0)))
    }

    func testIsPeakEndOfFirstWindowExclusive() {
        XCTAssertFalse(PeakCalculator.isPeak(at: utcDate(2026, 1, 5, 4, 0)))
    }

    func testIsPeakJustBeforeFirstWindow() {
        XCTAssertFalse(PeakCalculator.isPeak(at: utcDate(2026, 1, 5, 0, 59, 59)))
    }

    func testIsPeakJustBeforeSecondWindow() {
        XCTAssertFalse(PeakCalculator.isPeak(at: utcDate(2026, 1, 5, 5, 59, 59)))
    }

    func testIsPeakStartOfSecondWindowInclusive() {
        XCTAssertTrue(PeakCalculator.isPeak(at: utcDate(2026, 1, 5, 6, 0)))
    }

    func testIsPeakEndOfSecondWindowExclusive() {
        XCTAssertFalse(PeakCalculator.isPeak(at: utcDate(2026, 1, 5, 10, 0)))
    }

    func testIsPeakOffPeakMidday() {
        XCTAssertFalse(PeakCalculator.isPeak(at: utcDate(2026, 1, 5, 12, 0)))
    }

    func testIsPeakSaturdayAlwaysOffPeak() {
        XCTAssertFalse(PeakCalculator.isPeak(at: utcDate(2026, 1, 3, 2, 0))) // Saturday
    }

    func testIsPeakSundayAlwaysOffPeak() {
        XCTAssertFalse(PeakCalculator.isPeak(at: utcDate(2026, 1, 4, 7, 0))) // Sunday
    }

    func testIsPeakMonday0200() {
        XCTAssertTrue(PeakCalculator.isPeak(at: utcDate(2026, 1, 5, 2, 0))) // Monday
    }

    func testIsPeakMonday0500() {
        XCTAssertFalse(PeakCalculator.isPeak(at: utcDate(2026, 1, 5, 5, 0))) // Monday
    }

    func testIsPeakMonday1100() {
        XCTAssertFalse(PeakCalculator.isPeak(at: utcDate(2026, 1, 5, 11, 0))) // Monday
    }

    func testIsPeakFriday2359() {
        XCTAssertFalse(PeakCalculator.isPeak(at: utcDate(2026, 1, 2, 23, 59))) // Friday
    }

    func testIsPeakSunday0800() {
        XCTAssertFalse(PeakCalculator.isPeak(at: utcDate(2026, 1, 4, 8, 0))) // Sunday
    }

    // MARK: - nextTransition

    func testNextTransitionFromFirstPeakWindow() {
        let result = PeakCalculator.nextTransition(from: utcDate(2026, 1, 5, 3, 0))
        XCTAssertEqual(result.0, utcDate(2026, 1, 5, 4, 0))
        XCTAssertFalse(result.1)
    }

    func testNextTransitionFromSecondPeakWindow() {
        let result = PeakCalculator.nextTransition(from: utcDate(2026, 1, 5, 7, 0))
        XCTAssertEqual(result.0, utcDate(2026, 1, 5, 10, 0))
        XCTAssertFalse(result.1)
    }

    func testNextTransitionFromMorningGap() {
        let result = PeakCalculator.nextTransition(from: utcDate(2026, 1, 5, 4, 30))
        XCTAssertEqual(result.0, utcDate(2026, 1, 5, 6, 0))
        XCTAssertTrue(result.1)
    }

    func testNextTransitionBeforeFirstWindow() {
        let result = PeakCalculator.nextTransition(from: utcDate(2026, 1, 5, 0, 15))
        XCTAssertEqual(result.0, utcDate(2026, 1, 5, 1, 0))
        XCTAssertTrue(result.1)
    }

    func testNextTransitionAfterSecondWindowWeekday() {
        let result = PeakCalculator.nextTransition(from: utcDate(2026, 1, 5, 12, 0))
        XCTAssertEqual(result.0, utcDate(2026, 1, 6, 1, 0)) // next day (Tuesday)
        XCTAssertTrue(result.1)
    }

    func testNextTransitionFridayEveningSkipsWeekend() {
        let result = PeakCalculator.nextTransition(from: utcDate(2026, 1, 2, 12, 0)) // Friday
        XCTAssertEqual(result.0, utcDate(2026, 1, 5, 1, 0)) // Monday
        XCTAssertTrue(result.1)
    }

    func testNextTransitionSaturdaySkipsToMonday() {
        let result = PeakCalculator.nextTransition(from: utcDate(2026, 1, 3, 10, 0)) // Saturday
        XCTAssertEqual(result.0, utcDate(2026, 1, 5, 1, 0)) // Monday
        XCTAssertTrue(result.1)
    }

    func testNextTransitionSundaySkipsToMonday() {
        let result = PeakCalculator.nextTransition(from: utcDate(2026, 1, 4, 23, 0)) // Sunday
        XCTAssertEqual(result.0, utcDate(2026, 1, 5, 1, 0)) // Monday
        XCTAssertTrue(result.1)
    }

    // MARK: - schedules

    func testSchedulesForUTCDay() {
        let utc = TimeZone(identifier: "UTC")!
        let segments = PeakCalculator.schedules(for: utc, referenceDate: utcDate(2026, 1, 5, 12, 0))

        XCTAssertEqual(segments.count, 5)
        XCTAssertEqual(segments[0].0, utcDate(2026, 1, 5, 0, 0))
        XCTAssertEqual(segments[0].1, utcDate(2026, 1, 5, 1, 0))
        XCTAssertFalse(segments[0].2)

        XCTAssertEqual(segments[1].0, utcDate(2026, 1, 5, 1, 0))
        XCTAssertEqual(segments[1].1, utcDate(2026, 1, 5, 4, 0))
        XCTAssertTrue(segments[1].2)

        XCTAssertEqual(segments[2].0, utcDate(2026, 1, 5, 4, 0))
        XCTAssertEqual(segments[2].1, utcDate(2026, 1, 5, 6, 0))
        XCTAssertFalse(segments[2].2)

        XCTAssertEqual(segments[3].0, utcDate(2026, 1, 5, 6, 0))
        XCTAssertEqual(segments[3].1, utcDate(2026, 1, 5, 10, 0))
        XCTAssertTrue(segments[3].2)

        XCTAssertEqual(segments[4].0, utcDate(2026, 1, 5, 10, 0))
        XCTAssertEqual(segments[4].1, utcDate(2026, 1, 6, 0, 0))
        XCTAssertFalse(segments[4].2)
    }

    func testSchedulesForWeekendDaySingleOffPeakSegment() {
        let utc = TimeZone(identifier: "UTC")!
        let segments = PeakCalculator.schedules(for: utc, referenceDate: utcDate(2026, 1, 3, 12, 0))

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].0, utcDate(2026, 1, 3, 0, 0))
        XCTAssertEqual(segments[0].1, utcDate(2026, 1, 4, 0, 0))
        XCTAssertFalse(segments[0].2)
    }

    func testSchedulesForLocalTimeZone() {
        let istanbul = TimeZone(identifier: "Asia/Istanbul")!
        let segments = PeakCalculator.schedules(for: istanbul, referenceDate: utcDate(2026, 1, 5, 12, 0))

        XCTAssertEqual(segments.count, 5)
        XCTAssertEqual(segments[0].0, utcDate(2026, 1, 4, 21, 0))
        XCTAssertEqual(segments[0].1, utcDate(2026, 1, 5, 1, 0))
        XCTAssertFalse(segments[0].2)

        XCTAssertEqual(segments[1].0, utcDate(2026, 1, 5, 1, 0))
        XCTAssertEqual(segments[1].1, utcDate(2026, 1, 5, 4, 0))
        XCTAssertTrue(segments[1].2)

        XCTAssertEqual(segments[2].0, utcDate(2026, 1, 5, 4, 0))
        XCTAssertEqual(segments[2].1, utcDate(2026, 1, 5, 6, 0))
        XCTAssertFalse(segments[2].2)

        XCTAssertEqual(segments[3].0, utcDate(2026, 1, 5, 6, 0))
        XCTAssertEqual(segments[3].1, utcDate(2026, 1, 5, 10, 0))
        XCTAssertTrue(segments[3].2)

        XCTAssertEqual(segments[4].0, utcDate(2026, 1, 5, 10, 0))
        XCTAssertEqual(segments[4].1, utcDate(2026, 1, 5, 21, 0))
        XCTAssertFalse(segments[4].2)
    }
}
