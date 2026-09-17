import XCTest
import SwiftUI
import ViewInspector
@testable import CheapSeek

final class PeakStatusTests: XCTestCase {

    func testInitFromIsPeak() {
        XCTAssertEqual(PeakStatus(isPeak: true), .peak)
        XCTAssertEqual(PeakStatus(isPeak: false), .offPeak)
    }

    func testTitlesAreLocalized() {
        XCTAssertFalse(PeakStatus.peak.title.isEmpty)
        XCTAssertFalse(PeakStatus.offPeak.title.isEmpty)
    }

    func testColors() {
        XCTAssertEqual(PeakStatus.peak.color, Color.red)
        XCTAssertEqual(PeakStatus.offPeak.color, Color.green)
    }

    func testSymbolNames() {
        XCTAssertEqual(PeakStatus.peak.symbolName, "dollarsign.circle.fill")
        XCTAssertEqual(PeakStatus.offPeak.symbolName, "dollarsign.circle")
    }

    func testBadgeBodyRendersForBothStatuses() throws {
        XCTAssertNoThrow(try PeakStatusBadge(status: .peak).inspect())
        XCTAssertNoThrow(try PeakStatusBadge(status: .offPeak, style: .caption, bold: false).inspect())
    }

    func testBadgeExposesAccessibilityLabel() throws {
        let badge = PeakStatusBadge(status: .peak)
        let label = try badge.inspect().find(ViewType.Label.self)
        XCTAssertNoThrow(try label.accessibilityLabel())
    }
}
