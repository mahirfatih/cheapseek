import Foundation
import Combine
import Localize_Swift

final class AppModel: ObservableObject {
    @Published private(set) var isPeak: Bool
    @Published private(set) var schedule: [(start: Date, end: Date, isPeak: Bool)]
    @Published private(set) var timeZone: TimeZone

    private let settings: AppSettings
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var languageObserver: NSObjectProtocol?
    private var systemTimeZoneObserver: NSObjectProtocol?

    init(settings: AppSettings, date: Date = Date(), timeZone: TimeZone? = nil, autoRefresh: Bool = true) {
        self.settings = settings
        let tz = timeZone ?? settings.timeZone
        self.timeZone = tz
        isPeak = PeakCalculator.isPeak(at: date)
        schedule = PeakCalculator.schedules(for: tz, referenceDate: date)

        if autoRefresh {
            startTimer()

            settings.$timeZoneIdentifier
                .dropFirst()
                .sink { [weak self] _ in
                    guard let self else { return }
                    self.timeZone = self.settings.timeZone
                    self.refresh()
                }
                .store(in: &cancellables)

            settings.$updateInterval
                .dropFirst()
                .sink { [weak self] _ in
                    self?.startTimer()
                }
                .store(in: &cancellables)
        }

        languageObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name(LCLLanguageChangeNotification),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.objectWillChange.send()
        }

        systemTimeZoneObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.NSSystemTimeZoneDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.timeZone = self.settings.timeZone
            self.refresh()
        }
    }

    deinit {
        timer?.invalidate()
        if let languageObserver {
            NotificationCenter.default.removeObserver(languageObserver)
        }
        if let systemTimeZoneObserver {
            NotificationCenter.default.removeObserver(systemTimeZoneObserver)
        }
    }

    func refresh(now: Date = Date()) {
        isPeak = PeakCalculator.isPeak(at: now)
        schedule = PeakCalculator.schedules(for: timeZone, referenceDate: now)
    }

    private func startTimer() {
        timer?.invalidate()
        let interval = settings.updateInterval.clamped(to: 30...300)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
