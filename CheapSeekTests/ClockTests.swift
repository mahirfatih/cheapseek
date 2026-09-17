import XCTest
@testable import CheapSeek

final class ClockTests: XCTestCase {

    func testStartTicksAndStopStops() {
        let clock = Clock(now: Date(timeIntervalSince1970: 0))
        let ticked = expectation(description: "clock ticks")
        ticked.assertForOverFulfill = false
        clock.onTick = { _ in ticked.fulfill() }

        clock.start(interval: 0.05)
        wait(for: [ticked], timeout: 3)
        clock.stop()

        XCTAssertGreaterThan(clock.now.timeIntervalSince1970, 0)
    }

    func testStartTwiceReplacesTheRunningTask() {
        let clock = Clock(now: Date(timeIntervalSince1970: 0))
        let ticked = expectation(description: "clock ticks")
        ticked.assertForOverFulfill = false
        clock.onTick = { _ in ticked.fulfill() }

        clock.start(interval: 5)
        clock.start(interval: 0.05) // cancels the first task
        wait(for: [ticked], timeout: 3)
        clock.stop()
    }

    func testStopWithoutStartIsSafe() {
        let clock = Clock()
        clock.stop()
        clock.stop()
    }
}
