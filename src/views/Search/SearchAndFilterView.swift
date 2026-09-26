import SwiftUI

struct SearchAndFilterView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var filterState: ClosetFilterState
    let closets: [Closet]
    let isSearchFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: colorScheme == .dark ? 14 : PyxisSpacing.sm) {
            searchField

            if colorScheme == .dark {
                categoryStrip
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                    sortPicker
                    favoritesToggle
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: PyxisSpacing.md) {
                        sortPicker
                        favoritesToggle
                    }
                    .fixedSize(horizontal: true, vertical: false)

                    VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                        sortPicker
                        favoritesToggle
                    }
                }
            }

            if showsActiveFilters {
                activeFilters
            }
        }
        .foregroundStyle(PyxisColors.text)
    }

    private var showsActiveFilters: Bool {
        // The selected category is already visible in the dark category strip.
        let visibleCategoryCount = colorScheme == .dark && filterState.category != nil ? 1 : 0
        return filterState.activeFilterCount > visibleCategoryCount
    }

    private var searchField: some View {
        HStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: colorScheme == .dark ? 19 : 12, weight: .light))
                .foregroundStyle(PyxisColors.text)
                .accessibilityHidden(true)

            TextField(
                "Search closet",
                text: $filterState.searchText,
                prompt: Text(colorScheme == .dark ? "SEARCH YOUR CLOSET" : "SEARCH")
                    .foregroundColor(PyxisColors.secondaryText)
            )
                .textFieldStyle(.plain)
                .font(colorScheme == .dark ? PyxisTypography.editorialBody : PyxisTypography.body)
                .tracking(colorScheme == .dark ? 1.2 : 0)
                .autocorrectionDisabled()
                .focused(isSearchFocused)
        }
        .padding(.horizontal, colorScheme == .dark ? 16 : PyxisSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: colorScheme == .dark ? 54 : 44)
        .background(PyxisColors.field, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(PyxisColors.hairline, lineWidth: 1)
        }
        .editorialGlow()
        .accessibilityLabel("Search closet")
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                categoryButton("ALL", category: nil)
                ForEach(ClothingCategory.allCases) { category in
                    categoryButton(category == .onePiece ? "ONE PIECE" : category.rawValue.uppercased(), category: category)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 2)
        }
        .scrollClipDisabled()
        .padding(.vertical, -8)
    }

    private func categoryButton(_ title: String, category: ClothingCategory?) -> some View {
        let selected = filterState.category == category
        return Button {
            filterState.selectCategory(category)
            if category == nil { filterState.subtype = nil }
        } label: {
            Text(title)
                .font(PyxisTypography.editorialLabel)
                .tracking(1.2)
                .foregroundStyle(selected ? PyxisColors.background : PyxisColors.text)
                .padding(.horizontal, 17)
                .frame(minHeight: 44)
                .background(selected ? PyxisColors.text : PyxisColors.field, in: RoundedRectangle(cornerRadius: 9))
                .overlay {
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(PyxisColors.hairline, lineWidth: 1)
                }
                .editorialGlow(cornerRadius: 9, strength: selected ? 1.25 : 0.55)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var sortPicker: some View {
        if colorScheme == .dark {
            Menu {
                sortOptions
            } label: {
                HStack(spacing: 8) {
                    Text(filterState.sort == .mostWorn ? "MOST WORN" : filterState.sort.rawValue.uppercased())
                        .font(PyxisTypography.editorialLabel)
                        .tracking(1.1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .light))
                }
                .foregroundStyle(PyxisColors.text)
                .frame(minWidth: 128, minHeight: 44, alignment: .leading)
            }
            .accessibilityLabel("Sort closet")
            .accessibilityValue(filterState.sort.rawValue)
        } else {
            sortOptions
                .labelsHidden()
                .tint(PyxisColors.text)
                .frame(minWidth: dynamicTypeSize.isAccessibilitySize ? nil : 128, alignment: .leading)
                .frame(minHeight: 44)
        }
    }

    private var sortOptions: some View {
        Picker("Sort", selection: $filterState.sort) {
            ForEach(ClosetSortOption.allCases) { option in
                Text(option == .mostWorn ? "MOST WORN" : option.rawValue.uppercased()).tag(option)
            }
        }
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
                    .lineLimit(2)
            }
            .foregroundStyle(filterState.favoritesOnly ? PyxisColors.surface : PyxisColors.secondaryText)
            .padding(.horizontal, PyxisSpacing.sm)
            .padding(.vertical, PyxisSpacing.sm)
            .frame(minHeight: 44)
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
            .editorialGlow(cornerRadius: 8, strength: filterState.favoritesOnly ? 1.1 : 0.4)
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
                if colorScheme != .dark, let category = filterState.category {
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
            .frame(minHeight: 44)
            .background(PyxisColors.field)
            .overlay { Capsule().stroke(PyxisColors.hairline, lineWidth: 1) }
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove \(title) filter")
    }
}
