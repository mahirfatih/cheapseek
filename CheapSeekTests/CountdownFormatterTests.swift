import XCTest
@testable import CheapSeek

final class CountdownFormatterTests: XCTestCase {

    private var hourUnit: String { "unit_hours".localized() }
    private var minuteUnit: String { "unit_minutes".localized() }
    private var secondUnit: String { "unit_seconds".localized() }

    func testHoursAndMinutes() {
        XCTAssertEqual(CountdownFormatter.string(from: 3661), "1\(hourUnit) 1\(minuteUnit)")
    }

    func testMinutesAndSeconds() {
        XCTAssertEqual(CountdownFormatter.string(from: 61), "1\(minuteUnit) 1\(secondUnit)")
    }

    func testSecondsOnly() {
        XCTAssertEqual(CountdownFormatter.string(from: 59), "59\(secondUnit)")
    }

    func testExactHour() {
        XCTAssertEqual(CountdownFormatter.string(from: 3600), "1\(hourUnit) 0\(minuteUnit)")
    }

    func testNegativeClampsToZero() {
        XCTAssertEqual(CountdownFormatter.string(from: -5), "0\(secondUnit)")
    }
}
