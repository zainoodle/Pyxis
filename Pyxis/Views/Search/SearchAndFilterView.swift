import SwiftUI

struct SearchAndFilterView: View {
    @Binding var filterState: ClosetFilterState
    let isSearchFocused: FocusState<Bool>.Binding

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: PyxisSpacing.md) {
                searchField
                sortPicker
                favoritesToggle
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                HStack(spacing: PyxisSpacing.md) {
                    searchField
                    sortPicker
                }

                favoritesToggle
            }
        }
        .foregroundStyle(PyxisColors.text)
    }

    private var searchField: some View {
        TextField("SEARCH", text: $filterState.searchText)
            .textFieldStyle(.plain)
            .font(PyxisTypography.body)
            .focused(isSearchFocused)
            .padding(.horizontal, PyxisSpacing.sm)
            .padding(.vertical, PyxisSpacing.sm)
            .background(PyxisColors.field)
            .frame(maxWidth: 180)
            .accessibilityLabel("Search closet")
    }

    private var sortPicker: some View {
        Picker("Sort", selection: $filterState.sort) {
            ForEach(ClosetSortOption.allCases) { option in
                Text(option.rawValue.uppercased()).tag(option)
            }
        }
        .labelsHidden()
        .frame(width: 128)
    }

    private var favoritesToggle: some View {
        Toggle("FAV", isOn: $filterState.favoritesOnly)
            .font(PyxisTypography.label)
            .fixedSize(horizontal: true, vertical: false)
    }
}
