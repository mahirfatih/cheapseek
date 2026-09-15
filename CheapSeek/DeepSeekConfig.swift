import Foundation

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
    let baseURL: String
    let weekdayOnly: Bool
    let offPeakFactor: Double
    let peakWindows: [PeakWindow]
    let models: [ModelPricing]

    var schedule: PeakSchedule {
        PeakSchedule(
            windows: peakWindows,
            weekdayOnly: weekdayOnly,
            timeZone: TimeZone(identifier: "UTC")!
        )
    }

    static func load(from bundle: Bundle = .main) -> DeepSeekConfig {
        guard let url = bundle.url(forResource: "Configuration", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let config = try? PropertyListDecoder().decode(DeepSeekConfig.self, from: data) else {
            return .fallback
        }
        return config
    }

    static let fallback = DeepSeekConfig(
        pricingURL: "https://api-docs.deepseek.com/quick_start/pricing/",
        docsURL: "https://api-docs.deepseek.com/",
        baseURL: "https://api.deepseek.com",
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
