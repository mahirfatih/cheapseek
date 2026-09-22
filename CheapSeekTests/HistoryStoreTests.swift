import XCTest
@testable import CheapSeek

final class HistoryStoreTests: XCTestCase {

    private func makeDefaults() -> UserDefaults {
        let suite = "HistoryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func date(_ day: Int, _ hour: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar.date(from: DateComponents(year: 2026, month: 1, day: day, hour: hour)) ?? Date()
    }

    func testRecordsOnlyOnStateChange() {
        let store = HistoryStore(defaults: nil)

        XCTAssertTrue(store.record(isPeak: true, at: date(1, 0)))
        XCTAssertFalse(store.record(isPeak: true, at: date(1, 1)))
        XCTAssertTrue(store.record(isPeak: false, at: date(1, 2)))
        XCTAssertEqual(store.samples.count, 2)
        XCTAssertEqual(store.lastState, false)
    }

    func testPersistenceRoundTrip() {
        let defaults = makeDefaults()
        let store = HistoryStore(defaults: defaults)
        store.record(isPeak: true, at: date(1, 0))
        store.record(isPeak: false, at: date(1, 5))

        let reloaded = HistoryStore(defaults: defaults)
        XCTAssertEqual(reloaded.samples, store.samples)
    }

    func testPruneKeepsOneAnchorBeforeCutoff() {
        let defaults = makeDefaults()
        let store = HistoryStore(defaults: defaults)
        for day in 1...11 {
            store.record(isPeak: day % 2 == 1, at: date(day), retentionDays: 100)
        }
        XCTAssertEqual(store.samples.count, 11)

        store.prune(now: date(11), retentionDays: 7)

        // Cutoff is Jan 4; the Jan 3 sample is kept as the anchor.
        XCTAssertEqual(store.samples.first?.timestamp, date(3))
        XCTAssertEqual(store.samples.count, 9)
    }

    func testPruneWithOnlyOldSamplesKeepsLatest() {
        let store = HistoryStore(defaults: nil)
        store.record(isPeak: true, at: date(1))
        store.record(isPeak: false, at: date(2))
        store.record(isPeak: true, at: date(3))

        store.prune(now: date(20), retentionDays: 7)

        XCTAssertEqual(store.samples.count, 1)
        XCTAssertEqual(store.samples.first?.timestamp, date(3))
    }

    func testPruneUsesCalendarDayBoundaryAcrossDST() {
        let newYork = TimeZone(identifier: "America/New_York")!
        let store = HistoryStore(defaults: nil)
        store.record(isPeak: false, at: local(newYork, 2026, 2, 28, 22, 30), retentionDays: 100, timeZone: newYork)
        store.record(isPeak: true, at: local(newYork, 2026, 2, 28, 23, 30), retentionDays: 100, timeZone: newYork)
        store.record(isPeak: false, at: local(newYork, 2026, 3, 1, 12), retentionDays: 100, timeZone: newYork)

        store.prune(now: local(newYork, 2026, 3, 8), retentionDays: 7, timeZone: newYork)

        // The 1 March calendar-day cutoff keeps the 28 February 23:30 sample only
        // as the spanning anchor; the earlier sample is outside the window.
        XCTAssertEqual(store.samples.map(\.timestamp), [
            local(newYork, 2026, 2, 28, 23, 30),
            local(newYork, 2026, 3, 1, 12)
        ])
    }

    func testRemoveAll() {
        let defaults = makeDefaults()
        let store = HistoryStore(defaults: defaults)
        store.record(isPeak: true, at: date(1))
        store.removeAll()

        XCTAssertTrue(store.samples.isEmpty)
        XCTAssertNil(defaults.data(forKey: "history.samples.v1"))
        XCTAssertTrue(HistoryStore(defaults: defaults).samples.isEmpty)
    }

    func testInMemoryStoreDoesNotPersist() {
        let defaults = makeDefaults()
        let ephemeral = HistoryStore(defaults: nil)
        ephemeral.record(isPeak: true, at: date(1))

        let persistent = HistoryStore(defaults: defaults)
        XCTAssertTrue(persistent.samples.isEmpty)
        XCTAssertEqual(ephemeral.samples.count, 1)
    }

    // MARK: - Backfill

    private func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        )) ?? Date()
    }

    private func local(_ timeZone: TimeZone, _ year: Int, _ month: Int, _ day: Int,
                       _ hour: Int = 0, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        )) ?? Date()
    }

    func testBackfillInsertsTransitionsAndFinalSample() {
        let store = HistoryStore(defaults: nil)
        let added = store.backfill(from: utc(2026, 1, 5, 0), to: utc(2026, 1, 5, 12), schedule: .deepseekDefault)

        XCTAssertEqual(added, 5)
        XCTAssertEqual(store.samples.map(\.timestamp), [
            utc(2026, 1, 5, 1), utc(2026, 1, 5, 4), utc(2026, 1, 5, 6),
            utc(2026, 1, 5, 10), utc(2026, 1, 5, 12)
        ])
        XCTAssertEqual(store.samples.map(\.isPeak), [true, false, true, false, false])
    }

    func testBackfillSkipsWhenNotBeforeNow() {
        let store = HistoryStore(defaults: nil)
        store.record(isPeak: false, at: utc(2026, 1, 5, 12))

        XCTAssertEqual(store.backfill(from: utc(2026, 1, 5, 12), to: utc(2026, 1, 5, 12), schedule: .deepseekDefault), 0)
        XCTAssertEqual(store.backfill(from: utc(2026, 1, 5, 12), to: utc(2026, 1, 5, 10), schedule: .deepseekDefault), 0)
        XCTAssertEqual(store.samples.count, 1)
    }

    func testBackfillGapInsideOffPeakOnlyAddsNow() {
        let store = HistoryStore(defaults: nil)
        store.backfill(from: utc(2026, 1, 3, 10), to: utc(2026, 1, 3, 12), schedule: .deepseekDefault)

        XCTAssertEqual(store.samples, [HistorySample(timestamp: utc(2026, 1, 3, 12), isPeak: false)])
    }

    func testBackfillPeakOffPeakPeak() {
        let store = HistoryStore(defaults: nil)
        store.backfill(from: utc(2026, 1, 5, 3), to: utc(2026, 1, 5, 7), schedule: .deepseekDefault)

        XCTAssertEqual(store.samples.map(\.timestamp), [
            utc(2026, 1, 5, 4), utc(2026, 1, 5, 6), utc(2026, 1, 5, 7)
        ])
        XCTAssertEqual(store.samples.map(\.isPeak), [false, true, true])
    }

    func testBackfillFullWeekendIsOffPeak() {
        let store = HistoryStore(defaults: nil)
        store.record(isPeak: true, at: utc(2026, 1, 2, 8)) // Friday peak
        store.backfill(from: utc(2026, 1, 2, 8), to: utc(2026, 1, 5, 2), schedule: .deepseekDefault)

        XCTAssertEqual(store.samples, [
            HistorySample(timestamp: utc(2026, 1, 2, 8), isPeak: true),
            HistorySample(timestamp: utc(2026, 1, 2, 10), isPeak: false),
            HistorySample(timestamp: utc(2026, 1, 5, 1), isPeak: true),
            HistorySample(timestamp: utc(2026, 1, 5, 2), isPeak: true)
        ])

        let days = HistoryAggregator.dailyDistribution(samples: store.samples, now: utc(2026, 1, 5, 2), timeZone: .gmt)
        for day in [utc(2026, 1, 3), utc(2026, 1, 4)] {
            let bucket = days.first { $0.date == day }
            XCTAssertEqual(bucket?.peakMinutes, 0, "\(day) should have no peak minutes")
            XCTAssertEqual(bucket?.offPeakMinutes, 1440, "\(day) should be fully off-peak")
        }
    }

    func testBackfillIsIdempotent() {
        let store = HistoryStore(defaults: nil)
        store.backfill(from: utc(2026, 1, 5, 0), to: utc(2026, 1, 5, 12), schedule: .deepseekDefault)
        let first = store.samples

        let added = store.backfill(from: utc(2026, 1, 5, 0), to: utc(2026, 1, 5, 12), schedule: .deepseekDefault)

        XCTAssertEqual(added, 0)
        XCTAssertEqual(store.samples, first)
    }

    func testBackfillWithLaterNowAddsOnlyNewTransitions() {
        let store = HistoryStore(defaults: nil)
        store.backfill(from: utc(2026, 1, 5, 0), to: utc(2026, 1, 5, 12), schedule: .deepseekDefault)
        let first = store.samples

        let added = store.backfill(from: utc(2026, 1, 5, 12), to: utc(2026, 1, 5, 18), schedule: .deepseekDefault)

        XCTAssertGreaterThan(added, 0)
        let timestamps = store.samples.map(\.timestamp)
        XCTAssertEqual(Set(timestamps).count, timestamps.count, "No duplicate timestamps")
        XCTAssertTrue(first.allSatisfy { store.samples.contains($0) }, "Existing samples must be retained")
    }

    func testBackfillCapsVeryLongGap() {
        let store = HistoryStore(defaults: nil)
        let now = utc(2026, 2, 2, 0)
        store.backfill(from: utc(2026, 1, 5, 0), to: now, schedule: .deepseekDefault,
                       retentionDays: 100, maxSamples: 50)

        XCTAssertEqual(store.samples.count, 50)
        XCTAssertEqual(store.samples.last?.timestamp, now)
    }

    func testBackfillDSTSpringForwardDayIsShort() {
        let newYork = TimeZone(identifier: "America/New_York")!
        let now = local(newYork, 2026, 3, 9)
        let store = HistoryStore(defaults: nil)
        store.record(isPeak: false, at: local(newYork, 2026, 3, 7))
        store.backfill(from: local(newYork, 2026, 3, 7), to: now, schedule: .deepseekDefault)

        let days = HistoryAggregator.dailyDistribution(samples: store.samples, now: now, timeZone: newYork)
        let sunday = days.first { $0.date == local(newYork, 2026, 3, 8) }
        XCTAssertEqual(sunday?.totalMinutes, 1380)
    }

    func testBackfillDSTFallBackDayIsLong() {
        let newYork = TimeZone(identifier: "America/New_York")!
        let now = local(newYork, 2026, 11, 2)
        let store = HistoryStore(defaults: nil)
        store.record(isPeak: false, at: local(newYork, 2026, 10, 31))
        store.backfill(from: local(newYork, 2026, 10, 31), to: now, schedule: .deepseekDefault)

        let days = HistoryAggregator.dailyDistribution(samples: store.samples, now: now, timeZone: newYork)
        let sunday = days.first { $0.date == local(newYork, 2026, 11, 1) }
        XCTAssertEqual(sunday?.totalMinutes, 1500)
    }

    func testBackfillNonUTCTimeZoneBoundaries() {
        let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
        let store = HistoryStore(defaults: nil)
        store.backfill(from: local(losAngeles, 2026, 1, 5), to: local(losAngeles, 2026, 1, 6),
                       schedule: .deepseekDefault, retentionDays: 100)

        XCTAssertEqual(store.samples.map(\.timestamp), [
            utc(2026, 1, 5, 10), utc(2026, 1, 6, 1), utc(2026, 1, 6, 4),
            utc(2026, 1, 6, 6), utc(2026, 1, 6, 8)
        ])
    }

    func testBackfillHalfHourOffsetAggregatesWeekend() {
        let kolkata = TimeZone(identifier: "Asia/Kolkata")!
        let now = local(kolkata, 2026, 1, 5)
        let store = HistoryStore(defaults: nil)
        store.record(isPeak: false, at: local(kolkata, 2026, 1, 3))
        store.backfill(from: local(kolkata, 2026, 1, 3), to: now, schedule: .deepseekDefault)

        let days = HistoryAggregator.dailyDistribution(samples: store.samples, now: now, timeZone: kolkata)
        for day in [local(kolkata, 2026, 1, 3), local(kolkata, 2026, 1, 4)] {
            let bucket = days.first { $0.date == day }
            XCTAssertEqual(bucket?.offPeakMinutes, 1440)
            XCTAssertEqual(bucket?.peakMinutes, 0)
        }
    }
}
