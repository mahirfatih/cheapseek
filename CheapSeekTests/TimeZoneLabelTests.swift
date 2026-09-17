import XCTest
@testable import CheapSeek

final class TimeZoneLabelTests: XCTestCase {

    func testIstanbulKeepsIdentifierAlongsideOffset() {
        let timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let label = TimeZoneLabel.string(for: timeZone)

        XCTAssertTrue(label.contains("Europe/Istanbul"), "Label should show the selected identifier, got \(label)")
        XCTAssertTrue(label.contains("GMT+3"), "Label should show the offset, got \(label)")
    }

    func testOffsetOnlyZoneDoesNotDuplicateIdentifier() {
        let timeZone = TimeZone(secondsFromGMT: 3 * 3600)!
        let label = TimeZoneLabel.string(for: timeZone)

        XCTAssertEqual(label, timeZone.identifier)
    }

    func testOffsetFormatting() {
        // 2024-01-15 12:00 UTC — a fixed winter instant for deterministic offsets.
        let date = Date(timeIntervalSince1970: 1_705_320_000)
        XCTAssertEqual(TimeZoneLabel.offset(for: TimeZone(identifier: "Europe/Istanbul")!, at: date), "GMT+3")
        XCTAssertEqual(TimeZoneLabel.offset(for: TimeZone(identifier: "Asia/Kolkata")!, at: date), "GMT+5:30")
        XCTAssertEqual(TimeZoneLabel.offset(for: TimeZone(identifier: "America/Los_Angeles")!, at: date), "GMT-8")
        XCTAssertEqual(TimeZoneLabel.offset(for: TimeZone(identifier: "UTC")!, at: date), "GMT")
    }

    func testOffsetReflectsDaylightSaving() {
        let winter = Date(timeIntervalSince1970: 1_705_320_000)
        let summer = Date(timeIntervalSince1970: 1_720_000_000)
        let london = TimeZone(identifier: "Europe/London")!

        XCTAssertEqual(TimeZoneLabel.offset(for: london, at: winter), "GMT")
        XCTAssertEqual(TimeZoneLabel.offset(for: london, at: summer), "GMT+1")
    }
}
