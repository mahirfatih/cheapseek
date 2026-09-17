import XCTest
@testable import CheapSeek

final class TimeZoneCatalogTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_705_320_000)
    private let locale = Locale(identifier: "en_US")

    func testGroupsIncludeSystemEntryWithoutTitle() {
        let system = TimeZoneCatalog.entry(for: "", locale: locale, now: now)
        let groups = TimeZoneCatalog.groups(
            identifiers: ["Europe/Istanbul"],
            locale: locale,
            now: now,
            systemEntry: system
        )

        XCTAssertEqual(groups.first?.id, TimeZoneCatalog.systemGroupID)
        XCTAssertNil(groups.first?.title)
        XCTAssertEqual(groups.first?.entries.first?.id, "")
    }

    func testGroupingByRegionAndCityExtraction() {
        let groups = TimeZoneCatalog.groups(
            identifiers: ["Europe/Istanbul", "America/Argentina/Buenos_Aires", "Asia/Tokyo"],
            locale: locale,
            now: now,
            systemEntry: nil
        )

        XCTAssertEqual(groups.map(\.title), ["America", "Asia", "Europe"])

        let buenosAires = groups.first { $0.title == "America" }?.entries.first
        XCTAssertEqual(buenosAires?.city, "Buenos Aires")
        XCTAssertEqual(buenosAires?.offset, "GMT-3")

        let tokyo = groups.first { $0.title == "Asia" }?.entries.first
        XCTAssertEqual(tokyo?.city, "Tokyo")
        XCTAssertEqual(tokyo?.offset, "GMT+9")
    }

    func testFilterIsCaseAndDiacriticInsensitive() {
        let groups = TimeZoneCatalog.groups(
            identifiers: ["Europe/Istanbul"],
            locale: locale,
            now: now,
            systemEntry: nil
        )

        XCTAssertEqual(TimeZoneCatalog.filter(groups, query: "ISTANBUL").count, 1)
        XCTAssertEqual(TimeZoneCatalog.filter(groups, query: "İstanbul").count, 1)
        XCTAssertEqual(TimeZoneCatalog.filter(groups, query: "istanbul").count, 1)
    }

    func testFilterMatchesLocalizedGenericName() {
        let turkish = Locale(identifier: "tr_TR")
        let groups = TimeZoneCatalog.groups(
            identifiers: ["Europe/Istanbul"],
            locale: turkish,
            now: now,
            systemEntry: nil
        )

        XCTAssertEqual(TimeZoneCatalog.filter(groups, query: "türkiye").count, 1)
        XCTAssertEqual(TimeZoneCatalog.filter(groups, query: "turkiye").count, 1)
    }

    func testFilterReturnsEverythingForEmptyQuery() {
        let groups = TimeZoneCatalog.groups(
            identifiers: ["Europe/Istanbul", "Asia/Tokyo"],
            locale: locale,
            now: now,
            systemEntry: nil
        )

        XCTAssertEqual(TimeZoneCatalog.filter(groups, query: ""), groups)
        XCTAssertEqual(TimeZoneCatalog.filter(groups, query: "   "), groups)
    }

    func testFilterDropsNonMatchingGroups() {
        let groups = TimeZoneCatalog.groups(
            identifiers: ["Europe/Istanbul", "Asia/Tokyo"],
            locale: locale,
            now: now,
            systemEntry: nil
        )

        let filtered = TimeZoneCatalog.filter(groups, query: "tokyo")
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.title, "Asia")

        XCTAssertTrue(TimeZoneCatalog.filter(groups, query: "atlantis").isEmpty)
    }
}
