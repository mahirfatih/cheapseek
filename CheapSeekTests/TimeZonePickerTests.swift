import XCTest
import SwiftUI
import ViewInspector
import Localize_Swift
@testable import CheapSeek

private final class ValueBox {
    var value = ""
}

final class TimeZonePickerTests: XCTestCase {

    private func binding(_ box: ValueBox) -> Binding<String> {
        Binding(get: { box.value }, set: { box.value = $0 })
    }

    func testSelectedLabelSystemAndZone() {
        XCTAssertEqual(
            TimeZonePicker(selection: .constant(""), locale: Locale(identifier: "en_US")).selectedLabel,
            "system_timezone".localized()
        )
        XCTAssertTrue(
            TimeZonePicker(selection: .constant("Europe/Istanbul"), locale: Locale(identifier: "en_US"))
                .selectedLabel.contains("Europe/Istanbul")
        )
    }

    func testPickerButtonRenders() {
        let picker = TimeZonePicker(selection: .constant(""), locale: Locale(identifier: "en_US"))
        _ = picker.body
        _ = try? picker.inspect()
    }

    func testContentWithDefaultQueryRendersGroups() {
        let content = TimeZonePickerContent(
            selection: .constant(""), isPresented: .constant(true),
            query: .constant(""), locale: Locale(identifier: "en_US")
        )
        XCTAssertFalse(content.filteredGroups.isEmpty)
        _ = content.body
        _ = try? content.inspect()

        let entry = content.filteredGroups[0].entries[0]
        XCTAssertEqual(content.displayName(for: entry), entry.city.isEmpty ? "system_timezone".localized() : entry.city)
    }

    func testContentWithEmptyResultShowsNoResults() {
        let content = TimeZonePickerContent(
            selection: .constant(""), isPresented: .constant(true),
            query: .constant("zzzzzzzz"), locale: Locale(identifier: "en_US")
        )
        XCTAssertTrue(content.filteredGroups.isEmpty)
        _ = content.body
        _ = try? content.inspect()
    }

    func testSelectFirstMatchSetsSelectionAndCloses() {
        let box = ValueBox()
        let closed = ValueBox()
        let content = TimeZonePickerContent(
            selection: binding(box),
            isPresented: Binding(get: { closed.value == "open" }, set: { closed.value = $0 ? "open" : "closed" }),
            query: .constant("tokyo"),
            locale: Locale(identifier: "en_US")
        )

        content.selectFirstMatch()

        XCTAssertEqual(box.value, "Asia/Tokyo")
        XCTAssertEqual(closed.value, "closed")
    }

    func testSystemEntryDisplayName() {
        let content = TimeZonePickerContent(
            selection: .constant(""), isPresented: .constant(true),
            query: .constant(""), locale: Locale(identifier: "en_US")
        )
        let systemEntry = TimeZoneEntry(id: "", city: "", offset: "GMT", searchText: "")
        XCTAssertEqual(content.displayName(for: systemEntry), "system_timezone".localized())
    }
}
