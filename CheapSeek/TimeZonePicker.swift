import SwiftUI
import Localize_Swift

/// A searchable, region-grouped timezone selector. Shows the current selection
/// inline and opens a popover with a filter field and a grouped list.
struct TimeZonePicker: View {
    @Binding var selection: String
    let locale: Locale

    @State private var isPresented = false
    @State private var query = ""

    var body: some View {
        Button {
            query = ""
            isPresented = true
        } label: {
            HStack(spacing: Spacing.sm) {
                Text(selectedLabel)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            TimeZonePickerContent(selection: $selection, isPresented: $isPresented, query: $query, locale: locale)
        }
        .accessibilityLabel("timezone".localized())
        .accessibilityValue(selectedLabel)
    }

    var selectedLabel: String {
        if selection.isEmpty {
            return "system_timezone".localized()
        }
        return TimeZoneLabel.string(for: TimeZone(identifier: selection) ?? .current)
    }
}

/// The popover body, extracted so it can be inspected directly in tests.
struct TimeZonePickerContent: View {
    @Binding var selection: String
    @Binding var isPresented: Bool
    @Binding var query: String
    let locale: Locale

    @FocusState private var searchFocused: Bool

    var groups: [TimeZoneGroup] {
        TimeZoneCatalog.groups(
            identifiers: TimeZone.knownTimeZoneIdentifiers,
            locale: locale,
            systemEntry: TimeZoneCatalog.entry(for: "", locale: locale)
        )
    }

    var filteredGroups: [TimeZoneGroup] {
        TimeZoneCatalog.filter(groups, query: query)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()

            if filteredGroups.isEmpty {
                Text("timezone.no_results".localized())
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                list
            }
        }
        .frame(width: 320, height: 380)
        .onAppear { searchFocused = true }
        .onExitCommand { isPresented = false }
    }

    private var searchField: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("timezone.search".localized(), text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit(selectFirstMatch)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("close".localized())
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    private var list: some View {
        List {
            ForEach(filteredGroups) { group in
                Section {
                    ForEach(group.entries) { entry in
                        row(for: entry)
                    }
                } header: {
                    if let title = group.title {
                        Text(title)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private func row(for entry: TimeZoneEntry) -> some View {
        Button {
            selection = entry.id
            isPresented = false
        } label: {
            HStack(spacing: Spacing.sm) {
                Text(displayName(for: entry))
                    .lineLimit(1)
                Spacer(minLength: Spacing.sm)
                Text(entry.offset)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .opacity(entry.id == selection ? 1 : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(displayName(for: entry)) \(entry.offset)")
    }

    func displayName(for entry: TimeZoneEntry) -> String {
        entry.id.isEmpty ? "system_timezone".localized() : entry.city
    }

    func selectFirstMatch() {
        guard let first = filteredGroups.first?.entries.first else { return }
        selection = first.id
        isPresented = false
    }
}
