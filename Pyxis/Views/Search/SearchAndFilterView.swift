import SwiftUI

struct SearchAndFilterView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var filterState: ClosetFilterState
    let closets: [Closet]
    let isSearchFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                    searchField
                    sortPicker
                    favoritesToggle
                }
            } else {
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
            }

            if filterState.hasActiveFilters {
                activeFilters
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
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 180)
            .frame(minHeight: 44)
            .accessibilityLabel("Search closet")
    }

    private var sortPicker: some View {
        Picker("Sort", selection: $filterState.sort) {
            ForEach(ClosetSortOption.allCases) { option in
                Text(option.rawValue.uppercased()).tag(option)
            }
        }
        .labelsHidden()
        .tint(PyxisColors.text)
        .frame(
            minWidth: dynamicTypeSize.isAccessibilitySize ? nil : 128,
            maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 128,
            alignment: .leading
        )
        .frame(minHeight: 44)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
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
            .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: false)
            .accessibilityLabel("Show favorites only")
            .accessibilityValue(filterState.favoritesOnly ? "On" : "Off")
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, alignment: .leading)
            .frame(minHeight: 44)
    }

    private var activeFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PyxisSpacing.sm) {
                if !filterState.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ActiveFilterChip(title: "SEARCH: \(filterState.searchText)") {
                        filterState.searchText = ""
                    }
                }
                if let closetID = filterState.closetID {
                    ActiveFilterChip(
                        title: closets.first(where: { $0.id == closetID })?.displayName ?? "CLOSET"
                    ) {
                        filterState.closetID = nil
                    }
                }
                if let category = filterState.category {
                    ActiveFilterChip(title: category.rawValue) {
                        filterState.selectCategory(nil)
                        filterState.subtype = nil
                    }
                }
                if let subtype = filterState.subtype {
                    ActiveFilterChip(title: subtype.rawValue) {
                        filterState.subtype = nil
                    }
                }
                if let color = filterState.color {
                    ActiveFilterChip(title: color.rawValue) {
                        filterState.color = nil
                    }
                }
                if filterState.favoritesOnly {
                    ActiveFilterChip(title: "FAVORITES") {
                        filterState.favoritesOnly = false
                    }
                }
                if filterState.sort != .newest {
                    ActiveFilterChip(title: "SORT: \(filterState.sort.rawValue)") {
                        filterState.sort = .newest
                    }
                }

                Button("CLEAR ALL") {
                    filterState.clearAll()
                }
                .font(PyxisTypography.label)
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityLabel("Clear all search and filters")
            }
        }
    }
}

private struct ActiveFilterChip: View {
    let title: String
    let removeAction: () -> Void

    var body: some View {
        Button(action: removeAction) {
            HStack(spacing: PyxisSpacing.xs) {
                Text(title.uppercased())
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .font(PyxisTypography.label)
            .foregroundStyle(PyxisColors.secondaryText)
            .padding(.horizontal, PyxisSpacing.sm)
            .frame(minHeight: 36)
            .background(PyxisColors.field)
            .overlay { Capsule().stroke(PyxisColors.hairline, lineWidth: 1) }
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove \(title) filter")
    }
}
