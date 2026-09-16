import Foundation
import OSLog

private let logger = Logger(subsystem: "com.labrus.CheapSeek", category: "DeepSeekConfig")

struct Price: Codable, Equatable {
    let offPeak: Double
    let peak: Double
}

struct ModelPricing: Codable, Equatable {
    let id: String
    let name: String
    let inputCacheHit: Price
    let inputCacheMiss: Price
    let output: Price
}

struct DeepSeekConfig: Codable, Equatable {
    let pricingURL: String
    let docsURL: String
    let usageURL: String
    let weekdayOnly: Bool
    let offPeakFactor: Double
    let peakWindows: [PeakWindow]
    let models: [ModelPricing]

    var schedule: PeakSchedule {
        PeakSchedule(
            windows: peakWindows,
            weekdayOnly: weekdayOnly,
            timeZone: .gmt
        )
    }

    static func load(from bundle: Bundle = .main) -> DeepSeekConfig {
        guard let url = bundle.url(forResource: "Configuration", withExtension: "plist") else {
            logger.warning("Configuration.plist missing; falling back to built-in defaults.")
            return .fallback
        }
        do {
            let data = try Data(contentsOf: url)
            let config = try PropertyListDecoder().decode(DeepSeekConfig.self, from: data)
            guard config.isValid else {
                logger.error("Configuration.plist failed validation; falling back to built-in defaults.")
                return .fallback
            }
            return config
        } catch {
            logger.error("Configuration.plist unreadable (\(error.localizedDescription)); falling back to built-in defaults.")
            return .fallback
        }
    }

    private var isValid: Bool {
        guard !models.isEmpty else { return false }
        guard (0...1).contains(offPeakFactor) else { return false }
        for window in peakWindows {
            guard (0...24).contains(window.startHour),
                  (0...24).contains(window.endHour),
                  window.startHour < window.endHour else { return false }
        }
        for model in models {
            for price in [model.inputCacheHit, model.inputCacheMiss, model.output] {
                guard price.offPeak >= 0, price.peak >= 0 else { return false }
            }
        }
        return true
    }

    static let fallback = DeepSeekConfig(
        pricingURL: "https://api-docs.deepseek.com/quick_start/pricing/",
        docsURL: "https://api-docs.deepseek.com/",
        usageURL: "https://platform.deepseek.com/usage",
        weekdayOnly: true,
        offPeakFactor: 0.5,
        peakWindows: [PeakWindow(startHour: 1, endHour: 4), PeakWindow(startHour: 6, endHour: 10)],
        models: [
            ModelPricing(
                id: "deepseek-flash",
                name: "DeepSeek-V4.1-Flash",
                inputCacheHit: Price(offPeak: 0.003, peak: 0.006),
                inputCacheMiss: Price(offPeak: 0.15, peak: 0.30),
                output: Price(offPeak: 0.60, peak: 1.20)
            ),
            ModelPricing(
                id: "deepseek-v4-pro",
                name: "DeepSeek-V4-Pro-0813",
                inputCacheHit: Price(offPeak: 0.022, peak: 0.044),
                inputCacheMiss: Price(offPeak: 0.66, peak: 1.32),
                output: Price(offPeak: 1.98, peak: 3.96)
            )
        ]
    )
}
