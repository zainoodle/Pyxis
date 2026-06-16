import SwiftUI

struct SearchAndFilterView: View {
    @Binding var filterState: ClosetFilterState
    let isSearchFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: ArchiveSpacing.md) {
            TextField("SEARCH", text: $filterState.searchText)
                .textFieldStyle(.plain)
                .font(ArchiveTypography.body)
                .focused(isSearchFocused)
                .padding(.horizontal, ArchiveSpacing.sm)
                .padding(.vertical, ArchiveSpacing.sm)
                .background(ArchiveColors.field)
                .frame(width: 260)
                .accessibilityLabel("Search closet")

            Picker("Sort", selection: $filterState.sort) {
                ForEach(ClosetSortOption.allCases) { option in
                    Text(option.rawValue.uppercased()).tag(option)
                }
            }
            .labelsHidden()
            .frame(width: 150)

            Toggle("FAVORITES", isOn: $filterState.favoritesOnly)
                .font(ArchiveTypography.label)
        }
        .foregroundStyle(ArchiveColors.text)
    }
}
