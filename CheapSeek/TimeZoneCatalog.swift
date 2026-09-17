import Foundation

/// A single selectable timezone row.
struct TimeZoneEntry: Identifiable, Equatable {
    /// IANA identifier, or an empty string for the "System Timezone" entry.
    let id: String
    let city: String
    let offset: String
    let searchText: String
}

/// A named group of timezones (e.g. `Europe`), or the pinned system group when `title` is `nil`.
struct TimeZoneGroup: Identifiable, Equatable {
    let id: String
    let title: String?
    let entries: [TimeZoneEntry]
}

/// Pure, testable builder for the grouped + searchable timezone list.
enum TimeZoneCatalog {
    static let systemGroupID = "system"

    static func entry(for identifier: String, locale: Locale, now: Date = Date()) -> TimeZoneEntry {
        let timeZone = identifier.isEmpty
            ? TimeZone.current
            : (TimeZone(identifier: identifier) ?? .current)
        let city = cityName(for: identifier)
        let generic = timeZone.localizedName(for: .generic, locale: locale) ?? ""
        let searchText = normalize("\(identifier) \(city) \(generic)")

        return TimeZoneEntry(
            id: identifier,
            city: city,
            offset: TimeZoneLabel.offset(for: timeZone, at: now),
            searchText: searchText
        )
    }

    static func groups(
        identifiers: [String],
        locale: Locale,
        now: Date = Date(),
        systemEntry: TimeZoneEntry?
    ) -> [TimeZoneGroup] {
        var result: [TimeZoneGroup] = []

        if let systemEntry {
            result.append(TimeZoneGroup(id: systemGroupID, title: nil, entries: [systemEntry]))
        }

        let grouped = Dictionary(grouping: identifiers, by: region(for:))
        for region in grouped.keys.sorted() {
            let entries = grouped[region, default: []]
                .map { entry(for: $0, locale: locale, now: now) }
                .sorted { $0.city.localizedCaseInsensitiveCompare($1.city) == .orderedAscending }
            result.append(TimeZoneGroup(id: region, title: region, entries: entries))
        }

        return result
    }

    static func filter(_ groups: [TimeZoneGroup], query: String) -> [TimeZoneGroup] {
        let needle = normalize(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !needle.isEmpty else { return groups }

        return groups.compactMap { group in
            let entries = group.entries.filter { $0.searchText.contains(needle) }
            guard !entries.isEmpty else { return nil }
            return TimeZoneGroup(id: group.id, title: group.title, entries: entries)
        }
    }

    private static func region(for identifier: String) -> String {
        identifier.split(separator: "/").first.map(String.init) ?? identifier
    }

    private static func cityName(for identifier: String) -> String {
        guard !identifier.isEmpty else { return "" }
        let leaf = identifier.split(separator: "/").last.map(String.init) ?? identifier
        return leaf.replacingOccurrences(of: "_", with: " ")
    }

    private static func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }
}
