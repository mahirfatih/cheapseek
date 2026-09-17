import Foundation

/// Builds the timezone labels shown in the popup and the settings picker so a
/// user-selected zone keeps its identifier instead of collapsing to an
/// offset-only name like `GMT+3`.
enum TimeZoneLabel {
    static func string(for timeZone: TimeZone, at date: Date = Date()) -> String {
        let identifier = timeZone.identifier
        guard identifier.contains("/") else { return identifier }
        return "\(identifier) · \(offset(for: timeZone, at: date))"
    }

    /// Current UTC offset including daylight saving, e.g. `GMT+3` or `GMT+5:30`.
    static func offset(for timeZone: TimeZone, at date: Date = Date()) -> String {
        let seconds = timeZone.secondsFromGMT(for: date)
        guard seconds != 0 else { return "GMT" }
        let sign = seconds < 0 ? "-" : "+"
        let magnitude = abs(seconds)
        let hours = magnitude / 3600
        let minutes = (magnitude % 3600) / 60
        guard minutes != 0 else { return "GMT\(sign)\(hours)" }
        return String(format: "GMT%@%d:%02d", sign, hours, minutes)
    }
}
