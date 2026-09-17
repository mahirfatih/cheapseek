import XCTest
import SwiftUI
import ViewInspector
import Localize_Swift
@testable import CheapSeek

final class HistoryChartViewTests: XCTestCase {

    private func day(_ day: Int, peak: Double, offPeak: Double) -> DayDistribution {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: day)) ?? Date()
        return DayDistribution(date: date, peakMinutes: peak, offPeakMinutes: offPeak)
    }

    func testEmptyStateRendersLocalizedMessage() throws {
        let view = HistoryChartView(days: [], timeZone: .gmt)
        XCTAssertFalse(view.hasData)
        _ = view.body
        XCTAssertNoThrow(try view.inspect())
    }

    func testChartPropertiesWithData() {
        let days = (1...7).map { day($0, peak: 60, offPeak: 60) }
        let view = HistoryChartView(days: days, timeZone: .gmt)

        XCTAssertTrue(view.hasData)
        XCTAssertEqual(view.offPeakLabel, "history.offpeak".localized())
        XCTAssertEqual(view.peakLabel, "history.peak".localized())
        XCTAssertEqual(view.calendar.timeZone, TimeZone(identifier: "UTC"))
        XCTAssertEqual(view.locale, AppLanguage(rawValue: Localize.currentLanguage())?.locale ?? .current)
        XCTAssertNotNil(view.weekdayFormat)
    }

    func testChartWithDataRenders() {
        let days = (1...7).map { day($0, peak: 30, offPeak: 90) }
        let view = HistoryChartView(days: days, timeZone: .gmt)
        _ = view.body
        _ = try? view.inspect()
    }

    func testSingleDayRenders() {
        let view = HistoryChartView(days: [day(1, peak: 120, offPeak: 0)], timeZone: .gmt)
        _ = try? view.inspect()
    }
}
