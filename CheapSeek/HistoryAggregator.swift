import Foundation

/// Peak and off-peak minutes attributed to one calendar day.
struct DayDistribution: Identifiable, Equatable {
    let date: Date
    let peakMinutes: Double
    let offPeakMinutes: Double

    var totalMinutes: Double { peakMinutes + offPeakMinutes }
    var id: Date { date }
}

/// Pure aggregation of recorded samples into a per-day peak/off-peak distribution.
struct HistoryAggregator {

    static let defaultDays = 7

    /// Builds exactly `days` calendar-day buckets ending with `now`'s day.
    ///
    /// Each pair of consecutive samples forms an interval carrying the earlier
    /// sample's state; the final interval runs to `now`. Intervals are clipped to
    /// the window and split at local day boundaries, so DST-sized days (23/25h)
    /// fall out naturally from the injected calendar/timezone.
    static func dailyDistribution(
        samples: [HistorySample],
        now: Date,
        days: Int = HistoryAggregator.defaultDays,
        timeZone: TimeZone
    ) -> [DayDistribution] {
        guard days > 0 else { return [] }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let today = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
            return []
        }

        var dayStarts: [Date] = []
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: windowStart) else { return [] }
            dayStarts.append(day)
        }

        var peakSeconds = [Double](repeating: 0, count: days)
        var offPeakSeconds = [Double](repeating: 0, count: days)

        for segment in intervals(from: samples, now: now) {
            let start = max(segment.start, windowStart)
            let end = min(segment.end, now)
            guard end > start else { continue }

            for index in 0..<days {
                let dayStart = dayStarts[index]
                let dayEnd = index + 1 < days ? dayStarts[index + 1] : now
                let overlapStart = max(start, dayStart)
                let overlapEnd = min(end, dayEnd)
                guard overlapEnd > overlapStart else { continue }

                let seconds = overlapEnd.timeIntervalSince(overlapStart)
                if segment.isPeak {
                    peakSeconds[index] += seconds
                } else {
                    offPeakSeconds[index] += seconds
                }
            }
        }

        return dayStarts.enumerated().map { index, date in
            DayDistribution(
                date: date,
                peakMinutes: peakSeconds[index] / 60,
                offPeakMinutes: offPeakSeconds[index] / 60
            )
        }
    }

    private struct Segment {
        let start: Date
        let end: Date
        let isPeak: Bool
    }

    private static func intervals(from samples: [HistorySample], now: Date) -> [Segment] {
        let sorted = samples.sorted { $0.timestamp < $1.timestamp }
        guard !sorted.isEmpty else { return [] }

        var segments: [Segment] = []
        for index in sorted.indices {
            let start = sorted[index].timestamp
            let end = index + 1 < sorted.count ? sorted[index + 1].timestamp : now
            guard end > start else { continue }
            segments.append(Segment(start: start, end: end, isPeak: sorted[index].isPeak))
        }
        return segments
    }
}
