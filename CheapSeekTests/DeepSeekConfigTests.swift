import XCTest
@testable import CheapSeek

final class DeepSeekConfigTests: XCTestCase {

    private func encoded(_ config: DeepSeekConfig) -> Data {
        try! PropertyListEncoder().encode(config)
    }

    func testDecodeNilFallsBack() {
        XCTAssertEqual(DeepSeekConfig.decode(nil), .fallback)
    }

    func testDecodeMalformedDataFallsBack() {
        XCTAssertEqual(DeepSeekConfig.decode(Data("not a plist".utf8)), .fallback)
    }

    func testDecodeValidConfigRoundTrips() {
        XCTAssertEqual(DeepSeekConfig.decode(encoded(.fallback)), .fallback)
    }

    func testDecodeEmptyModelsFallsBack() {
        var config = DeepSeekConfig.fallback
        config = DeepSeekConfig(
            pricingURL: config.pricingURL, docsURL: config.docsURL, usageURL: config.usageURL,
            weekdayOnly: config.weekdayOnly, offPeakFactor: config.offPeakFactor,
            peakWindows: config.peakWindows, models: []
        )
        XCTAssertEqual(DeepSeekConfig.decode(encoded(config)), .fallback)
    }

    func testDecodeInvalidOffPeakFactorFallsBack() {
        let base = DeepSeekConfig.fallback
        let config = DeepSeekConfig(
            pricingURL: base.pricingURL, docsURL: base.docsURL, usageURL: base.usageURL,
            weekdayOnly: base.weekdayOnly, offPeakFactor: 2.0,
            peakWindows: base.peakWindows, models: base.models
        )
        XCTAssertEqual(DeepSeekConfig.decode(encoded(config)), .fallback)
    }

    func testDecodeInvalidWindowFallsBack() {
        let base = DeepSeekConfig.fallback
        let config = DeepSeekConfig(
            pricingURL: base.pricingURL, docsURL: base.docsURL, usageURL: base.usageURL,
            weekdayOnly: base.weekdayOnly, offPeakFactor: base.offPeakFactor,
            peakWindows: [PeakWindow(startHour: 10, endHour: 4)], models: base.models
        )
        XCTAssertEqual(DeepSeekConfig.decode(encoded(config)), .fallback)
    }

    func testDecodeNegativePriceFallsBack() {
        let base = DeepSeekConfig.fallback
        let badModel = ModelPricing(
            id: "m", name: "M",
            inputCacheHit: Price(offPeak: -1, peak: 1),
            inputCacheMiss: Price(offPeak: 1, peak: 1),
            output: Price(offPeak: 1, peak: 1)
        )
        let config = DeepSeekConfig(
            pricingURL: base.pricingURL, docsURL: base.docsURL, usageURL: base.usageURL,
            weekdayOnly: base.weekdayOnly, offPeakFactor: base.offPeakFactor,
            peakWindows: base.peakWindows, models: [badModel]
        )
        XCTAssertEqual(DeepSeekConfig.decode(encoded(config)), .fallback)
    }

    func testLoadFromBundleWithoutPlistFallsBack() {
        // The test bundle does not contain Configuration.plist.
        XCTAssertEqual(DeepSeekConfig.load(from: Bundle(for: type(of: self))), .fallback)
    }

    func testScheduleUsesUTC() {
        XCTAssertEqual(DeepSeekConfig.fallback.schedule.timeZone, .gmt)
    }

    func testFallbackWindowsMatchTheDefaultSchedule() {
        // Single source of truth: the fallback must not redefine the windows.
        XCTAssertEqual(DeepSeekConfig.fallback.schedule.windows, PeakSchedule.deepseekDefault.windows)
        XCTAssertEqual(DeepSeekConfig.fallback.schedule.weekdayOnly, PeakSchedule.deepseekDefault.weekdayOnly)
        XCTAssertEqual(DeepSeekConfig.fallback.schedule.timeZone, PeakSchedule.deepseekDefault.timeZone)
    }
}
