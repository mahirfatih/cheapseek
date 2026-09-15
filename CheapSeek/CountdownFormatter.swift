import Foundation
import Localize_Swift

enum CountdownFormatter {
    static func string(from interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded(.down)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        let hourUnit = "unit_hours".localized()
        let minuteUnit = "unit_minutes".localized()
        let secondUnit = "unit_seconds".localized()

        if hours > 0 {
            return "\(hours)\(hourUnit) \(minutes)\(minuteUnit)"
        } else if minutes > 0 {
            return "\(minutes)\(minuteUnit) \(secs)\(secondUnit)"
        } else {
            return "\(secs)\(secondUnit)"
        }
    }
}
