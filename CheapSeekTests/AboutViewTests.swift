import XCTest
import SwiftUI
import ViewInspector
@testable import CheapSeek

@MainActor
final class AboutViewTests: XCTestCase {

    func testRenders() {
        let view = AboutView(onClose: {})
        _ = view.body
        _ = try? view.inspect()
    }

    func testVersionIsNonEmptyAndReadable() {
        let version = AboutView.version
        XCTAssertFalse(version.isEmpty)
        XCTAssertTrue(version.contains("("), "Version should include the build number: \(version)")
    }

    func testLinksPointToLabrus() {
        XCTAssertEqual(AboutView.websiteURL.scheme, "https")
        XCTAssertEqual(AboutView.websiteURL.host, "labrus.com")
        XCTAssertEqual(AboutView.contactURL.scheme, "mailto")
        XCTAssertEqual(AboutView.contactURL.absoluteString, "mailto:info@labrus.com")
    }

    func testAppName() {
        XCTAssertEqual(AboutView.appName, "CheapSeek")
    }
}
