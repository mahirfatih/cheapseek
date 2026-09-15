import Foundation

struct PeakWindow: Codable, Equatable {
    let startHour: Int
    let endHour: Int
}

struct PeakSchedule: Equatable {
    let windows: [PeakWindow]
    let weekdayOnly: Bool
    let timeZone: TimeZone

    static let deepseekDefault = PeakSchedule(
        windows: [PeakWindow(startHour: 1, endHour: 4), PeakWindow(startHour: 6, endHour: 10)],
        weekdayOnly: true,
        timeZone: .gmt
    )

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    var sortedWindows: [PeakWindow] {
        windows.sorted { $0.startHour < $1.startHour }
    }
}

struct PeakCalculator {

    static func isPeak(at date: Date, schedule: PeakSchedule = .deepseekDefault) -> Bool {
        let calendar = schedule.calendar
        let weekday = calendar.component(.weekday, from: date)
        if schedule.weekdayOnly && !(2...6).contains(weekday) { return false }

        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        let secondsOfDay = hour * 3600 + minute * 60 + second

        return schedule.sortedWindows.contains { window in
            secondsOfDay >= window.startHour * 3600 && secondsOfDay < window.endHour * 3600
        }
    }

    static func nextTransition(from date: Date, schedule: PeakSchedule = .deepseekDefault) -> (Date, Bool) {
        let calendar = schedule.calendar
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        let secondsOfDay = hour * 3600 + minute * 60 + second
        let weekday = calendar.component(.weekday, from: date)

        if isPeak(at: date, schedule: schedule) {
            for window in schedule.sortedWindows
            where secondsOfDay >= window.startHour * 3600 && secondsOfDay < window.endHour * 3600 {
                return (atHour(window.endHour, on: date, schedule: schedule), false)
            }
        }

        let isWeekendDay = schedule.weekdayOnly && !(2...6).contains(weekday)
        if isWeekendDay {
            return (nextWindowStart(after: date, schedule: schedule), true)
        }

        for window in schedule.sortedWindows where window.startHour * 3600 > secondsOfDay {
            return (atHour(window.startHour, on: date, schedule: schedule), true)
        }

        return (nextWindowStart(after: date, schedule: schedule), true)
    }

    static func todaySchedules(for timeZone: TimeZone, schedule: PeakSchedule = .deepseekDefault) -> [(Date, Date, Bool)] {
        schedules(for: timeZone, referenceDate: Date(), schedule: schedule)
    }

    static func schedules(for timeZone: TimeZone, referenceDate: Date, schedule: PeakSchedule = .deepseekDefault) -> [(Date, Date, Bool)] {
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = timeZone

        let dayStart = localCalendar.startOfDay(for: referenceDate)
        let dayEnd = localCalendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)

        var segments: [(Date, Date, Bool)] = []
        var cursor = dayStart
        var state = isPeak(at: dayStart, schedule: schedule)

        while cursor < dayEnd {
            let (transition, _) = nextTransition(from: cursor, schedule: schedule)
            let segmentEnd = min(transition, dayEnd)
            segments.append((cursor, segmentEnd, state))
            cursor = segmentEnd
            state = isPeak(at: cursor, schedule: schedule)
        }

        return segments
    }

    private static func atHour(_ hour: Int, on date: Date, schedule: PeakSchedule) -> Date {
        let calendar = schedule.calendar
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = 0
        components.second = 0
        components.nanosecond = 0
        return calendar.date(from: components) ?? date
    }

    private static func nextWindowStart(after date: Date, schedule: PeakSchedule) -> Date {
        let calendar = schedule.calendar
        let firstStart = schedule.sortedWindows.map(\.startHour).min() ?? 0
        var day = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date.addingTimeInterval(86_400)

        if schedule.weekdayOnly {
            while true {
                let weekday = calendar.component(.weekday, from: day)
                if (2...6).contains(weekday) { break }
                day = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
            }
        }

        return atHour(firstStart, on: day, schedule: schedule)
    }
}
