import XCTest
@testable import CheapSeek

final class AppLanguageTests: XCTestCase {

    func testEveryLanguageExposesMetadata() {
        XCTAssertEqual(AppLanguage.allCases.count, 17)

        for language in AppLanguage.allCases {
            XCTAssertEqual(language.id, language.rawValue)
            XCTAssertFalse(language.displayName.isEmpty, "displayName empty for \(language.rawValue)")
            XCTAssertFalse(language.flag.isEmpty, "flag empty for \(language.rawValue)")
            XCTAssertFalse(language.localeIdentifier.isEmpty, "localeIdentifier empty for \(language.rawValue)")
            // Accessing `.locale` exercises the computed property for every case.
            XCTAssertFalse(language.locale.identifier.isEmpty)
        }
    }

    func testDisplayNamesAndFlagsAreUnique() {
        let names = AppLanguage.allCases.map(\.displayName)
        let flags = AppLanguage.allCases.map(\.flag)
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertEqual(Set(flags).count, flags.count)
    }
}
