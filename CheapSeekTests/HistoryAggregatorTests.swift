import XCTest
@testable import CheapSeek

final class HistoryAggregatorTests: XCTestCase {

    private let utc = TimeZone(identifier: "UTC")!

    private func date(_ year: Int, _ month: Int, _ day: Int,
                      _ hour: Int = 0, _ minute: Int = 0,
                      timeZone: TimeZone = TimeZone(identifier: "UTC")!) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        )) ?? Date()
    }

    private func bucket(for date: Date, in days: [DayDistribution], timeZone: TimeZone) -> DayDistribution? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let target = calendar.startOfDay(for: date)
        return days.first { $0.date == target }
    }

    func testEmptyDataYieldsSevenZeroBuckets() {
        let days = HistoryAggregator.dailyDistribution(
            samples: [], now: date(2026, 1, 10, 12), timeZone: utc
        )

        XCTAssertEqual(days.count, 7)
        XCTAssertTrue(days.allSatisfy { $0.totalMinutes == 0 })
    }

    func testSingleDayPeakAndOffPeak() {
        let samples = [
            HistorySample(timestamp: date(2026, 1, 10, 10), isPeak: true),
            HistorySample(timestamp: date(2026, 1, 10, 11), isPeak: false)
        ]
        let days = HistoryAggregator.dailyDistribution(
            samples: samples, now: date(2026, 1, 10, 11, 30), timeZone: utc
        )

        let today = bucket(for: date(2026, 1, 10), in: days, timeZone: utc)
        XCTAssertEqual(today?.peakMinutes, 60)
        XCTAssertEqual(today?.offPeakMinutes, 30)
    }

    func testFullSevenDays() {
        var samples: [HistorySample] = []
        for offset in 0...7 {
            samples.append(HistorySample(
                timestamp: date(2026, 1, 1 + offset),
                isPeak: offset % 2 == 0
            ))
        }

        let days = HistoryAggregator.dailyDistribution(
            samples: samples, now: date(2026, 1, 8, 12), timeZone: utc
        )

        XCTAssertEqual(days.count, 7)
        // Jan 2 … Jan 7 are complete 24-hour days; Jan 8 is partial.
        let fullDays = days.filter { abs($0.totalMinutes - 1440) < 0.001 }
        XCTAssertEqual(fullDays.count, 6)

        let jan2 = bucket(for: date(2026, 1, 2), in: days, timeZone: utc)
        XCTAssertEqual(jan2?.peakMinutes, 0)
        XCTAssertEqual(jan2?.offPeakMinutes, 1440)
    }

    func testTimezoneChangeReassignsDays() {
        let instant = date(2026, 1, 5, 23, 30)
        let samples = [HistorySample(timestamp: instant.addingTimeInterval(-3600), isPeak: false)]

        let utcDays = HistoryAggregator.dailyDistribution(samples: samples, now: instant, timeZone: utc)
        let tokyoDays = HistoryAggregator.dailyDistribution(
            samples: samples, now: instant, timeZone: TimeZone(identifier: "Asia/Tokyo")!
        )

        XCTAssertNotEqual(utcDays.last?.date, tokyoDays.last?.date)
    }

    func testDSTSpringForwardDayHas1380Minutes() {
        let newYork = TimeZone(identifier: "America/New_York")!
        let march8 = date(2026, 3, 8, 0, 0, timeZone: newYork)
        let samples = [HistorySample(timestamp: march8, isPeak: false)]
        let days = HistoryAggregator.dailyDistribution(
            samples: samples, now: date(2026, 3, 9, 0, 0, timeZone: newYork), timeZone: newYork
        )

        let day = bucket(for: march8, in: days, timeZone: newYork)
        XCTAssertEqual(day?.offPeakMinutes, 1380)
    }

    func testDSTFallBackDayHas1500Minutes() {
        let newYork = TimeZone(identifier: "America/New_York")!
        let november1 = date(2026, 11, 1, 0, 0, timeZone: newYork)
        let samples = [HistorySample(timestamp: november1, isPeak: false)]
        let days = HistoryAggregator.dailyDistribution(
            samples: samples, now: date(2026, 11, 2, 0, 0, timeZone: newYork), timeZone: newYork
        )

        let day = bucket(for: november1, in: days, timeZone: newYork)
        XCTAssertEqual(day?.offPeakMinutes, 1500)
    }

    func testWindowClipsOlderSamples() {
        let now = date(2026, 1, 10, 12)
        let samples = [HistorySample(timestamp: date(2025, 12, 1), isPeak: true)]
        let days = HistoryAggregator.dailyDistribution(samples: samples, now: now, timeZone: utc)

        let windowStart = date(2026, 1, 4)
        let expectedMinutes = now.timeIntervalSince(windowStart) / 60
        XCTAssertEqual(days.reduce(0) { $0 + $1.totalMinutes }, expectedMinutes, accuracy: 0.001)
        XCTAssertTrue(days.allSatisfy { $0.totalMinutes <= 1440 })
    }

    func testFinalIntervalUsesLastSampleState() {
        let now = date(2026, 1, 10, 12)
        let samples = [HistorySample(timestamp: date(2026, 1, 10, 11), isPeak: true)]
        let days = HistoryAggregator.dailyDistribution(samples: samples, now: now, timeZone: utc)

        let today = bucket(for: date(2026, 1, 10), in: days, timeZone: utc)
        XCTAssertEqual(today?.peakMinutes, 60)
        XCTAssertEqual(today?.offPeakMinutes, 0)
    }
}
