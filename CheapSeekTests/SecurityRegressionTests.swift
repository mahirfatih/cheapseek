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
    /// packages (e.g. ViewInspector), the shipped app must have no remote runtime dependencies.
    private var appTargetYML: String {
        let marker = "\n  CheapSeek:\n"
        guard let start = projectYML.range(of: marker)?.upperBound else { return "" }
        let remainder = projectYML[start...]
        let end = remainder.range(of: "\n  CheapSeekTests:")?.lowerBound ?? remainder.endIndex
        return String(remainder[..<end])
    }

    private var appSwiftFiles: [URL] {
        let dir = repoRoot.appendingPathComponent("CheapSeek")
        return try! FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
    }

    /// App sources with comments removed, so banned-word scans do not trip on
    /// prose in doc comments.
    private var appSources: String {
        appSwiftFiles
            .map { stripComments(try! String(contentsOf: $0, encoding: .utf8)) }
            .joined(separator: "\n")
    }

    private func stripComments(_ source: String) -> String {
        let withoutBlocks = source.replacingOccurrences(
            of: "/\\*[\\s\\S]*?\\*/", with: " ", options: .regularExpression
        )
        return withoutBlocks
            .components(separatedBy: .newlines)
            .map { line -> String in
                if let range = line.range(of: "//") { return String(line[..<range.lowerBound]) }
                return line
            }
            .joined(separator: "\n")
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
        XCTAssertFalse(source.contains("import CFNetwork"))
    }

    func testA05_noEntitlementsFilePresent() {
        var found: [String] = []
        for directory in [repoRoot, repoRoot.appendingPathComponent("CheapSeek")] {
            let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            found += files.filter { $0.pathExtension == "entitlements" }.map(\.lastPathComponent)
        }
        XCTAssertTrue(found.isEmpty, "Found entitlements file(s): \(found)")
    }

    func testPrivacyManifestDeclaresRequiredReasonAPI() {
        let manifest = repoRoot.appendingPathComponent("CheapSeek/PrivacyInfo.xcprivacy")
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifest.path))
        let contents = try! String(contentsOf: manifest, encoding: .utf8)
        XCTAssertTrue(contents.contains("CA92.1"), "UserDefaults required-reason code CA92.1 missing")
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

    func testA06_appTargetHasNoRemotePackageDependencies() {
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
