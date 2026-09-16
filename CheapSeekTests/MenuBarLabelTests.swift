import XCTest
import Localize_Swift
@testable import CheapSeek

final class MenuBarLabelTests: XCTestCase {

    private var previousLanguage = ""

    override func setUp() {
        super.setUp()
        previousLanguage = Localize.currentLanguage()
        Localize.setCurrentLanguage("en")
    }

    override func tearDown() {
        Localize.setCurrentLanguage(previousLanguage)
        super.tearDown()
    }

    func testOffPeakReturnsCheapText() {
        XCTAssertEqual(MenuBarLabel.text(for: .offPeak), "cheap")
    }

    func testPeakReturnsPeakText() {
        XCTAssertEqual(MenuBarLabel.text(for: .peak), "peak")
    }

    func testTextIsShort() {
        for status in [PeakStatus.peak, .offPeak] {
            XCTAssertLessThanOrEqual(MenuBarLabel.text(for: status).count, 8, "\(status) menu bar text is too long")
        }
    }

    func testSymbolsAreDistinctAndNonEmpty() {
        let offPeak = MenuBarLabel.symbolName(for: .offPeak)
        let peak = MenuBarLabel.symbolName(for: .peak)
        XCTAssertFalse(offPeak.isEmpty)
        XCTAssertFalse(peak.isEmpty)
        XCTAssertNotEqual(offPeak, peak)
    }

    func testAccessibilityLabelsAreNonEmpty() {
        XCTAssertFalse(PeakStatus(isPeak: false).title.isEmpty)
        XCTAssertFalse(PeakStatus(isPeak: true).title.isEmpty)
    }
}
