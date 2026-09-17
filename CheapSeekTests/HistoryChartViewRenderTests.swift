import XCTest
import SwiftUI
@testable import CheapSeek

/// Offscreen render spike: `ImageRenderer` actually builds the SwiftUI tree, so
/// the `Chart`/`AxisMarks` builders execute even though ViewInspector does not
/// materialize them.
final class HistoryChartViewRenderTests: XCTestCase {

    private func days(_ peak: Double, _ offPeak: Double) -> [DayDistribution] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return (1...7).map { day in
            let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: day)) ?? Date()
            return DayDistribution(date: date, peakMinutes: peak, offPeakMinutes: offPeak)
        }
    }

    @MainActor
    func testRendersChartOffscreen() {
        let view = HistoryChartView(days: days(30, 90), timeZone: .gmt)
            .frame(width: 300, height: 160)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1

        XCTAssertNotNil(renderer.nsImage)
    }

    @MainActor
    func testRendersEmptyStateOffscreen() {
        let view = HistoryChartView(days: [], timeZone: .gmt)
            .frame(width: 300, height: 160)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1

        XCTAssertNotNil(renderer.nsImage)
    }
}
