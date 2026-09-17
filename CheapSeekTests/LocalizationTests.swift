import XCTest
@testable import CheapSeek

final class LocalizationTests: XCTestCase {

    private let languages = AppLanguage.allCases.map(\.rawValue)

    private let expectedKeys: Set<String> = [
        "app_title", "status_peak", "status_offpeak", "now_label", "timezone_label",
        "today_schedule", "next_change", "in_label", "to_peak", "to_offpeak",
        "settings", "quit", "language", "timezone", "notifications", "launch_at_login",
        "update_interval", "unit_hours", "unit_minutes", "unit_seconds",
        "system_timezone", "update_interval_value", "login_item_error",
        "pricing", "info", "peak_label", "off_peak_label", "peak_window",
        "off_peak_window", "full_price", "half_price", "your_time",
        "input_cache_hit", "input_cache_miss", "output_tokens", "per_million_tokens",
        "pricing_page", "api_docs", "api_usage", "close",
        "menu_bar.status.cheap", "menu_bar.status.peak",
        "settings.notifications.enable", "settings.notifications.permission_hint",
        "settings.notifications.open_settings", "settings.notifications.offpeak_start",
        "settings.notifications.peak_start", "settings.notifications.before_peak",
        "settings.notifications.before_peak_value", "settings.notifications.before_peak_off",
        "settings.notifications.quiet_hours", "settings.notifications.quiet_start",
        "settings.notifications.quiet_end",
        "notification.peak_soon.title", "notification.peak_soon.body",
        "notification.offpeak_start.title", "notification.offpeak_start.body",
        "notification.peak_start.title", "notification.peak_start.body",
        "history.title", "history.last7days", "history.peak", "history.offpeak", "history.empty",
        "timezone.search", "timezone.no_results"
    ]

    private var cheapSeekDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // CheapSeekTests
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("CheapSeek")
    }

    func testAllLanguagesHaveIdenticalKeySets() {
        var keysByLanguage: [String: Set<String>] = [:]

        for lang in languages {
            let file = cheapSeekDir
                .appendingPathComponent("\(lang).lproj")
                .appendingPathComponent("Localizable.strings")
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), "Missing \(lang).lproj/Localizable.strings")
            keysByLanguage[lang] = keys(in: file)
        }

        let reference = keysByLanguage["en"]!
        for lang in languages {
            XCTAssertEqual(keysByLanguage[lang], reference, "\(lang) key set differs from en")
        }
    }

    func testEveryExpectedKeyExistsInEveryLanguage() {
        for lang in languages {
            let file = cheapSeekDir
                .appendingPathComponent("\(lang).lproj")
                .appendingPathComponent("Localizable.strings")
            let found = keys(in: file)
            let missing = expectedKeys.subtracting(found)
            XCTAssertTrue(missing.isEmpty, "\(lang) missing keys: \(missing.sorted())")
        }
    }

    func testEveryLanguageResolvesToAValidLocale() {
        for language in AppLanguage.allCases {
            let locale = language.locale
            XCTAssertEqual(locale.language.languageCode?.identifier, language.rawValue.prefix(2).description,
                           "\(language.rawValue) locale resolves to \(locale.identifier)")
        }
        XCTAssertEqual(AppLanguage.zhHans.locale.language.script?.identifier, "Hans")
        XCTAssertEqual(AppLanguage.hi.locale.language.languageCode?.identifier, "hi")
    }

    private func keys(in file: URL) -> Set<String> {
        let content = try! String(contentsOf: file, encoding: .utf8)
        var result = Set<String>()
        for rawLine in content.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("\"") else { continue }
            let rest = line.dropFirst()
            if let closingQuote = rest.firstIndex(of: "\"") {
                result.insert(String(rest[..<closingQuote]))
            }
        }
        return result
    }
}
