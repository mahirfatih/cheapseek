import Foundation

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
    func record(isPeak: Bool, at date: Date, retentionDays: Int = HistoryStore.defaultRetentionDays) -> Bool {
        prune(now: date, retentionDays: retentionDays)
        guard samples.last?.isPeak != isPeak else { return false }
        samples.append(HistorySample(timestamp: date, isPeak: isPeak))
        persist()
        return true
    }

    /// Drops entries older than the retention window, keeping the most recent
    /// sample before the cutoff as an anchor so the spanning interval still counts.
    func prune(now: Date, retentionDays: Int = HistoryStore.defaultRetentionDays) {
        guard retentionDays > 0 else { return }
        let cutoff = now.addingTimeInterval(-Double(retentionDays) * 86_400)

        guard let firstInWindow = samples.firstIndex(where: { $0.timestamp >= cutoff }) else {
            if samples.count > 1, let last = samples.last {
                samples = [last]
                persist()
            }
            return
        }

        let keepFrom = max(0, firstInWindow - 1)
        if keepFrom > 0 {
            samples.removeFirst(keepFrom)
            persist()
        }
    }

    func removeAll() {
        samples = []
        persist()
    }

    private func persist() {
        guard let defaults else { return }
        if let data = try? JSONEncoder().encode(samples) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
