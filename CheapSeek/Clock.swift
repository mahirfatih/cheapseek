import Foundation
import Observation

/// A ticking source of `now` used to refresh peak status at a configurable interval.
@Observable
final class Clock {
    private(set) var now: Date

    @ObservationIgnored private var task: Task<Void, Never>?

    init(now: Date = Date()) {
        self.now = now
    }

    func start(interval: TimeInterval) {
        task?.cancel()
        let seconds = max(1, interval)
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(seconds))
                if Task.isCancelled { return }
                guard let self else { return }
                await MainActor.run { self.now = Date() }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
