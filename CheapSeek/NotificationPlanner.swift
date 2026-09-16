import Foundation

/// The kind of peak/off-peak transition notification.
enum NotificationKind: String, CaseIterable {
    case peakSoon
    case offPeakStart
    case peakStart

    var key: String {
        switch self {
        case .peakSoon: return "peak_soon"
        case .offPeakStart: return "offpeak_start"
        case .peakStart: return "peak_start"
        }
    }

    var titleKey: String { "notification.\(key).title" }
    var bodyKey: String { "notification.\(key).body" }
}

/// A fully resolved notification to be handed to the system scheduler.
struct PlannedNotification: Equatable {
    let id: String
    let kind: NotificationKind
    let fireDate: Date
    let titleKey: String
    let bodyKey: String
    let bodyArgument: Int?
}

/// Pure, side-effect-free planning of transition notifications.
///
/// Enumerates the peak transitions in a rolling horizon and turns them into
/// concrete delivery dates, dropping anything in the past or inside quiet hours.
struct NotificationPlanner {

    static let horizon: TimeInterval = 7 * 24 * 60 * 60
    static let maximumTransitions = 60

    struct QuietHours: Equatable {
        let enabled: Bool
        let startMinutes: Int
        let endMinutes: Int

        static let disabled = QuietHours(enabled: false, startMinutes: 23 * 60, endMinutes: 7 * 60)
    }

    static func plan(
        now: Date,
        schedule: PeakSchedule,
        timeZone: TimeZone,
        beforePeakMinutes: Int,
        notifyOnOffPeakStart: Bool,
        notifyOnPeakStart: Bool,
        quietHours: QuietHours
    ) -> [PlannedNotification] {
        guard beforePeakMinutes > 0 || notifyOnOffPeakStart || notifyOnPeakStart else { return [] }

        let horizonEnd = now.addingTimeInterval(horizon)
        var plans: [PlannedNotification] = []
        var cursor = now

        while plans.count < maximumTransitions * 3 {
            let (transition, isPeak) = PeakCalculator.nextTransition(from: cursor, schedule: schedule)
            guard transition > cursor, transition <= horizonEnd else { break }

            if isPeak, beforePeakMinutes > 0 {
                append(
                    .peakSoon,
                    fireDate: transition.addingTimeInterval(-Double(beforePeakMinutes) * 60),
                    bodyArgument: beforePeakMinutes,
                    now: now,
                    quietHours: quietHours,
                    timeZone: timeZone,
                    into: &plans
                )
            }
            if isPeak, notifyOnPeakStart {
                append(.peakStart, fireDate: transition, bodyArgument: nil,
                       now: now, quietHours: quietHours, timeZone: timeZone, into: &plans)
            }
            if !isPeak, notifyOnOffPeakStart {
                append(.offPeakStart, fireDate: transition, bodyArgument: nil,
                       now: now, quietHours: quietHours, timeZone: timeZone, into: &plans)
            }

            cursor = transition
        }

        return plans.sorted { $0.fireDate < $1.fireDate }
    }

    /// Whether `date` falls inside the quiet-hours window. A window whose start
    /// is after its end spans midnight. A zero-length window disables quiet hours.
    static func isQuiet(_ date: Date, quietHours: QuietHours, timeZone: TimeZone) -> Bool {
        guard quietHours.enabled else { return false }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        let start = normalizedMinutes(quietHours.startMinutes)
        let end = normalizedMinutes(quietHours.endMinutes)
        guard start != end else { return false }

        if start < end {
            return minutes >= start && minutes < end
        }
        return minutes >= start || minutes < end
    }

    private static func append(
        _ kind: NotificationKind,
        fireDate: Date,
        bodyArgument: Int?,
        now: Date,
        quietHours: QuietHours,
        timeZone: TimeZone,
        into plans: inout [PlannedNotification]
    ) {
        guard fireDate > now else { return }
        guard !isQuiet(fireDate, quietHours: quietHours, timeZone: timeZone) else { return }

        plans.append(
            PlannedNotification(
                id: "\(kind.rawValue)-\(Int(fireDate.timeIntervalSince1970))",
                kind: kind,
                fireDate: fireDate,
                titleKey: kind.titleKey,
                bodyKey: kind.bodyKey,
                bodyArgument: bodyArgument
            )
        )
    }

    private static func normalizedMinutes(_ minutes: Int) -> Int {
        ((minutes % 1440) + 1440) % 1440
    }
}
