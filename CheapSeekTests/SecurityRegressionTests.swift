import XCTest
@testable import CheapSeek

final class SecurityRegressionTests: XCTestCase {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // CheapSeekTests
            .deletingLastPathComponent() // repo root
    }

    private var projectYML: String {
        try! String(contentsOf: repoRoot.appendingPathComponent("project.yml"), encoding: .utf8)
    }

    /// The `CheapSeek:` application target block only — test targets may use remote
    /// packages (e.g. ViewInspector), the shipped app must stay dependency-free.
    private var appTargetYML: String {
        let marker = "\n  CheapSeek:\n"
        guard let start = projectYML.range(of: marker)?.upperBound else { return "" }
        let remainder = projectYML[start...]
        let end = remainder.range(of: "\n  CheapSeekTests:")?.lowerBound ?? remainder.endIndex
        return String(remainder[..<end])
    }

    private var appSources: String {
        let dir = repoRoot.appendingPathComponent("CheapSeek")
        let files = try! FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        return files.map { try! String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
    }

    func testA05_noATSArbitraryLoads() {
        XCTAssertFalse(projectYML.contains("NSAllowsArbitraryLoads"))
    }

    func testA05_noEntitlementsDeclared() {
        XCTAssertFalse(projectYML.contains("CODE_SIGN_ENTITLEMENTS"))
        XCTAssertFalse(projectYML.contains("entitlements"))
    }

    func testMenuBarAgent_isLSUIElement() {
        XCTAssertTrue(projectYML.contains("INFOPLIST_KEY_LSUIElement: true"))
    }

    func test_noNetworkingAPIs() {
        let source = appSources
        XCTAssertFalse(source.contains("URLSession"))
        XCTAssertFalse(source.contains("URLRequest"))
        XCTAssertFalse(source.contains("import Network"))
    }

    func test_noAnalyticsOrTelemetrySDKs() {
        let source = appSources
        for banned in ["Firebase", "Sentry", "Mixpanel", "Analytics", "Telemetry", "Amplitude"] {
            XCTAssertFalse(source.contains(banned), "Found banned dependency: \(banned)")
        }
    }

    func test_noKeychainOrSecretStorage() {
        let source = appSources
        XCTAssertFalse(source.contains("Keychain"))
        XCTAssertFalse(source.contains("SecItem"))
    }

    func testA06_noRemotePackageDependencies() {
        // The app target must not pull remote SPM packages; only the vendored
        // local Localize-Swift is allowed. Test targets may use remote packages.
        let appTarget = appTargetYML
        XCTAssertFalse(appTarget.isEmpty, "Could not locate the CheapSeek app target in project.yml")
        XCTAssertFalse(appTarget.contains("url:"))
        XCTAssertFalse(appTarget.contains("from: "))
        XCTAssertFalse(appTarget.contains("ViewInspector"))
    }

    func testLocalizations_allLanguagesPresent() {
        let resources = repoRoot.appendingPathComponent("CheapSeek")
        for language in AppLanguage.allCases {
            let lproj = resources.appendingPathComponent("\(language.rawValue).lproj")
            XCTAssertTrue(FileManager.default.fileExists(atPath: lproj.path), "Missing \(language.rawValue).lproj")
        }
    }
}
