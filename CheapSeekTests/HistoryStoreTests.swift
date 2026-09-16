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

    func testRemoveAll() {
        let store = HistoryStore(defaults: makeDefaults())
        store.record(isPeak: true, at: date(1))
        store.removeAll()
        XCTAssertTrue(store.samples.isEmpty)
    }

    func testInMemoryStoreDoesNotPersist() {
        let defaults = makeDefaults()
        let ephemeral = HistoryStore(defaults: nil)
        ephemeral.record(isPeak: true, at: date(1))

        let persistent = HistoryStore(defaults: defaults)
        XCTAssertTrue(persistent.samples.isEmpty)
        XCTAssertEqual(ephemeral.samples.count, 1)
    }
}
