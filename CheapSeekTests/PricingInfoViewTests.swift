import XCTest
import SwiftUI
import ViewInspector
@testable import CheapSeek

final class PricingInfoViewTests: XCTestCase {

    func testPricingInfoRendersScrollableAndFlat() throws {
        let scrollable = PricingInfoView(config: .fallback, timeZone: .gmt)
        XCTAssertNoThrow(try scrollable.inspect())

        let flat = PricingInfoView(config: .fallback, timeZone: .gmt, scrollable: false)
        XCTAssertNoThrow(try flat.inspect())
    }

    func testPricingInfoRendersEveryModel() throws {
        let view = PricingInfoView(config: .fallback, timeZone: .gmt, scrollable: false)
        let inspected = try view.inspect()
        for model in DeepSeekConfig.fallback.models {
            XCTAssertNoThrow(try inspected.find(text: model.name))
        }
    }

    func testPricingInfoShowsLinks() throws {
        let view = PricingInfoView(config: .fallback, timeZone: .gmt, scrollable: false)
        let inspected = try view.inspect()
        XCTAssertNoThrow(try inspected.find(ViewType.Link.self))
    }
}
