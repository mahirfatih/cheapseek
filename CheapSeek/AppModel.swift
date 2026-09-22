import Foundation
import Observation
import Localize_Swift

// History backfill wiring (audit):
// - `backfillHistory()` is the only caller of `HistoryStore.backfill(...)`.
// - It runs on launch (`init`) and on a timezone change
//   (`SettingsView.handleTimeZoneChange` -> `backfillHistory`).
// - Transitions are computed from `config.schedule`, whose timeZone is UTC, so the
//   selected display timezone only affects aggregation (`refreshHistory`), not the
//   transition instants. Backfill and live recording therefore always pass the
//   same `config.schedule` instance.
@Observable
@MainActor
final class AppModel {
    let config: DeepSeekConfig
    let settings: AppSettings
    let notifications: NotificationManager
    let history: HistoryStore

    private let clock: Clock

    private(set) var languageRevision = 0
    private(set) var historyDays: [DayDistribution] = []
    @ObservationIgnored private var languageObserver: NSObjectProtocol?

    init(
        settings: AppSettings,
        config: DeepSeekConfig = .fallback,
        clock: Clock = Clock(),
        notifications: NotificationManager = .disabled,
        history: HistoryStore = .inMemory,
        autoStart: Bool = true
    ) {
        self.settings = settings
        self.config = config
        self.clock = clock
        self.notifications = notifications
        self.history = history
        clock.onTick = { [weak self] date in
            self?.recordHistory(at: date)
        }
        if autoStart {
            clock.start(interval: settings.updateInterval)
        }
        languageObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name(rawValue: LCLLanguageChangeNotification),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.languageRevision &+= 1
            self.refreshNotifications()
        }
        notifications.refreshAuthorizationStatus()
        refreshNotifications()
        backfillHistory()
        recordHistory(at: now)
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

    /// Recomputes and reschedules transition notifications for the current settings.
    func refreshNotifications() {
        notifications.reschedule(now: now, schedule: config.schedule, settings: settings)
    }

    var hasHistory: Bool {
        historyDays.contains { $0.totalMinutes > 0 }
    }

    /// Fills the gap since the last recorded sample with the true peak/off-peak
    /// transitions, then reaggregates. Runs on launch and after a timezone change.
    func backfillHistory() {
        if let lastSample = history.samples.last?.timestamp {
            history.backfill(from: lastSample, to: now, schedule: config.schedule, timeZone: timeZone)
        }
        refreshHistory()
    }

    /// Reaggregates history, e.g. after a timezone change.
    func refreshHistory(now: Date? = nil) {
        let effectiveNow = now ?? self.now
        historyDays = HistoryAggregator.dailyDistribution(
            samples: history.samples,
            now: effectiveNow,
            timeZone: timeZone
        )
    }

    func clearHistory() {
        history.removeAll()
        refreshHistory()
    }

    private func recordHistory(at date: Date) {
        history.record(
            isPeak: PeakCalculator.isPeak(at: date, schedule: config.schedule),
            at: date,
            timeZone: timeZone
        )
        refreshHistory(now: date)
    }
}
