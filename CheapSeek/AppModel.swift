import Foundation
import Observation
import Localize_Swift

@Observable
final class AppModel {
    let config: DeepSeekConfig
    let settings: AppSettings

    private let clock: Clock

    private(set) var languageRevision = 0
    @ObservationIgnored private var languageObserver: NSObjectProtocol?

    init(settings: AppSettings, config: DeepSeekConfig = .fallback, clock: Clock = Clock(), autoStart: Bool = true) {
        self.settings = settings
        self.config = config
        self.clock = clock
        if autoStart {
            clock.start(interval: settings.updateInterval)
        }
        languageObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name(rawValue: LCLLanguageChangeNotification),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.languageRevision &+= 1
        }
    }

    deinit {
        clock.stop()
        if let languageObserver {
            NotificationCenter.default.removeObserver(languageObserver)
        }
    }

    var now: Date { clock.now }
    var timeZone: TimeZone { settings.timeZone }
    var isPeak: Bool { PeakCalculator.isPeak(at: now, schedule: config.schedule) }

    var schedule: [(start: Date, end: Date, isPeak: Bool)] {
        PeakCalculator.schedules(for: timeZone, referenceDate: now, schedule: config.schedule)
    }

    func setUpdateInterval(_ interval: Double) {
        let range = AppSettings.updateIntervalRange
        clock.start(interval: min(max(interval, range.lowerBound), range.upperBound))
    }
}
