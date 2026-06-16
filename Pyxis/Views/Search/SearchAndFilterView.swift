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
        HStack(spacing: PyxisSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PyxisColors.inactiveText)

            TextField("SEARCH", text: $filterState.searchText)
                .textFieldStyle(.plain)
                .font(PyxisTypography.body)
                .focused(isSearchFocused)
        }
            .padding(.horizontal, PyxisSpacing.sm)
            .padding(.vertical, PyxisSpacing.sm)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PyxisColors.field)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(PyxisColors.hairline, lineWidth: 1)
            }
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
        Button {
            filterState.favoritesOnly.toggle()
        } label: {
            HStack(spacing: PyxisSpacing.xs) {
                Image(systemName: filterState.favoritesOnly ? "heart.fill" : "heart")
                    .font(.system(size: 11, weight: .semibold))

                Text("FAVORITES")
                    .font(PyxisTypography.label)
            }
            .foregroundStyle(filterState.favoritesOnly ? PyxisColors.surface : PyxisColors.secondaryText)
            .padding(.horizontal, PyxisSpacing.sm)
            .padding(.vertical, PyxisSpacing.sm)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(filterState.favoritesOnly ? PyxisColors.text : PyxisColors.field)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(filterState.favoritesOnly ? PyxisColors.text : PyxisColors.hairline, lineWidth: 1)
            }
        }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("Show favorites only")
            .accessibilityValue(filterState.favoritesOnly ? "On" : "Off")
    }
}
