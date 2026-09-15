import Foundation

struct PeakCalculator {

    private static let utcTimeZone = TimeZone(identifier: "UTC")!

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utcTimeZone
        return calendar
    }

    static func isPeak(at date: Date) -> Bool {
        let calendar = utcCalendar
        let weekday = calendar.component(.weekday, from: date)
        guard (2...6).contains(weekday) else { return false }

        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        let secondsOfDay = hour * 3600 + minute * 60 + second

        let firstWindow = 1 * 3600..<4 * 3600
        let secondWindow = 6 * 3600..<10 * 3600
        return firstWindow.contains(secondsOfDay) || secondWindow.contains(secondsOfDay)
    }

    static func nextTransition(from date: Date) -> (Date, Bool) {
        let calendar = utcCalendar
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        let weekday = calendar.component(.weekday, from: date)
        let secondsOfDay = hour * 3600 + minute * 60 + second

        if isPeak(at: date) {
            let endHour = secondsOfDay < 4 * 3600 ? 4 : 10
            return (atHour(endHour, on: date), false)
        }

        let isWeekend = weekday == 1 || weekday == 7
        if !isWeekend {
            if secondsOfDay < 1 * 3600 {
                return (atHour(1, on: date), true)
            } else if secondsOfDay < 6 * 3600 {
                return (atHour(6, on: date), true)
            } else {
                return (nextWeekdayPeakStart(from: date, weekday: weekday), true)
            }
        }

        return (nextMondayPeakStart(from: date), true)
    }

    static func todaySchedules(for timeZone: TimeZone) -> [(Date, Date, Bool)] {
        schedules(for: timeZone, referenceDate: Date())
    }

    static func schedules(for timeZone: TimeZone, referenceDate: Date) -> [(Date, Date, Bool)] {
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = timeZone

        let dayStart = localCalendar.startOfDay(for: referenceDate)
        let dayEnd = localCalendar.date(byAdding: .day, value: 1, to: dayStart)!

        var segments: [(Date, Date, Bool)] = []
        var cursor = dayStart
        var state = isPeak(at: dayStart)

        while cursor < dayEnd {
            let (transition, _) = nextTransition(from: cursor)
            let segmentEnd = min(transition, dayEnd)
            segments.append((cursor, segmentEnd, state))
            cursor = segmentEnd
            state = isPeak(at: cursor)
        }

        return segments
    }

    private static func atHour(_ hour: Int, on date: Date) -> Date {
        let calendar = utcCalendar
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = 0
        components.second = 0
        components.nanosecond = 0
        return calendar.date(from: components)!
    }

    private static func nextWeekdayPeakStart(from date: Date, weekday: Int) -> Date {
        let calendar = utcCalendar
        let startOfDay = calendar.startOfDay(for: date)
        let daysToAdd = weekday <= 5 ? 1 : 3
        let nextDay = calendar.date(byAdding: .day, value: daysToAdd, to: startOfDay)!
        return atHour(1, on: nextDay)
    }

    private static func nextMondayPeakStart(from date: Date) -> Date {
        let calendar = utcCalendar
        let weekday = calendar.component(.weekday, from: date)
        let daysToAdd = (9 - weekday) % 7
        let startOfDay = calendar.startOfDay(for: date)
        let monday = calendar.date(byAdding: .day, value: daysToAdd, to: startOfDay)!
        return atHour(1, on: monday)
    }
}
