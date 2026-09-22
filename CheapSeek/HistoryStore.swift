import Foundation
import OSLog

private let logger = Logger(subsystem: "com.labrus.CheapSeek", category: "HistoryStore")

/// A single observed peak/off-peak state at a point in time.
struct HistorySample: Codable, Equatable {
    let timestamp: Date
    let isPeak: Bool
}

/// Event-based, on-device history of peak/off-peak state changes.
///
/// Samples are appended only when the state changes, so the stored JSON stays
/// tiny (a handful of entries per day). Persistence is a single JSON blob in
/// `UserDefaults`; pass `nil` for an in-memory store used by tests and previews.
final class HistoryStore {

    static let defaultRetentionDays = 7
    static let defaultMaxBackfillSamples = 50
    private static let storageKey = "history.samples.v1"

    private let defaults: UserDefaults?
    private(set) var samples: [HistorySample]

    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
        if let data = defaults?.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([HistorySample].self, from: data) {
            self.samples = decoded
        } else {
            self.samples = []
        }
    }

    static let inMemory = HistoryStore(defaults: nil)

    var lastState: Bool? { samples.last?.isPeak }

    /// Prunes old entries and appends a new sample only when the state changed.
    /// - Returns: `true` when a new sample was recorded.
    @discardableResult
    func record(
        isPeak: Bool,
        at date: Date,
        retentionDays: Int = HistoryStore.defaultRetentionDays,
        timeZone: TimeZone? = nil
    ) -> Bool {
        prune(now: date, retentionDays: retentionDays, timeZone: timeZone, persistChanges: false)
        guard samples.last?.isPeak != isPeak else { return false }
        samples.append(HistorySample(timestamp: date, isPeak: isPeak))
        persist()
        return true
    }

    /// Fills the gap between the last recorded sample and `now` by recomputing the
    /// true peak/off-peak state from the pure schedule, inserting only the transition
    /// boundaries that actually occurred plus a final sample at `now`.
    ///
    /// Idempotent: existing timestamps are never duplicated, so calling it again with
    /// the same inputs leaves the store unchanged.
    /// - Returns: the number of samples appended.
    @discardableResult
    func backfill(
        from lastSample: Date,
        to now: Date,
        schedule: PeakSchedule,
        retentionDays: Int = HistoryStore.defaultRetentionDays,
        maxSamples: Int = HistoryStore.defaultMaxBackfillSamples,
        timeZone: TimeZone? = nil
    ) -> Int {
        guard lastSample < now else { return 0 }

        let boundaries = PeakCalculator.transitions(from: lastSample, to: now, schedule: schedule)
        var additions = boundaries.map {
            HistorySample(timestamp: $0, isPeak: PeakCalculator.isPeak(at: $0, schedule: schedule))
        }
        additions.append(HistorySample(timestamp: now, isPeak: PeakCalculator.isPeak(at: now, schedule: schedule)))

        if additions.count > maxSamples {
            logger.debug("Backfill gap produced \(additions.count) samples; capping to \(maxSamples).")
            additions = Array(additions.suffix(maxSamples))
        }

        let existingTimestamps = Set(samples.map(\.timestamp))
        let newSamples = additions.filter { !existingTimestamps.contains($0.timestamp) }
        guard !newSamples.isEmpty else { return 0 }

        samples.append(contentsOf: newSamples)
        samples.sort { $0.timestamp < $1.timestamp }
        prune(now: now, retentionDays: retentionDays, timeZone: timeZone)
        persist()
        return newSamples.count
    }

    /// Drops entries older than the retention window, keeping the most recent
    /// sample before the cutoff as an anchor so the spanning interval still counts.
    func prune(
        now: Date,
        retentionDays: Int = HistoryStore.defaultRetentionDays,
        timeZone: TimeZone? = nil
    ) {
        prune(now: now, retentionDays: retentionDays, timeZone: timeZone, persistChanges: true)
    }

    private func prune(
        now: Date,
        retentionDays: Int,
        timeZone: TimeZone?,
        persistChanges: Bool
    ) {
        guard retentionDays > 0 else { return }
        let cutoff = Self.cutoff(for: now, retentionDays: retentionDays, timeZone: timeZone)

        guard let firstInWindow = samples.firstIndex(where: { $0.timestamp >= cutoff }) else {
            if samples.count > 1, let last = samples.last {
                samples = [last]
                if persistChanges {
                    persist()
                }
            }
            return
        }

        let keepFrom = max(0, firstInWindow - 1)
        if keepFrom > 0 {
            samples.removeFirst(keepFrom)
            if persistChanges {
                persist()
            }
        }
    }

    private static func cutoff(for now: Date, retentionDays: Int, timeZone: TimeZone?) -> Date {
        guard let timeZone else {
            return now.addingTimeInterval(-Double(retentionDays) * 86_400)
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startOfToday = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -retentionDays, to: startOfToday)
            ?? now.addingTimeInterval(-Double(retentionDays) * 86_400)
    }

    func removeAll() {
        samples = []
        defaults?.removeObject(forKey: Self.storageKey)
    }

    private func persist() {
        guard let defaults else { return }
        if let data = try? JSONEncoder().encode(samples) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
