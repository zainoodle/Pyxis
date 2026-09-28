import SwiftUI

struct SearchAndFilterView: View {
    @Binding var filterState: ClosetFilterState
    let closets: [Closet]
    let isSearchFocused: FocusState<Bool>.Binding
    @State private var isShowingMoreFilters = false

    var body: some View {
        VStack(spacing: 14) {
            searchField
            browseMenu
        }
        .foregroundStyle(PyxisColors.text)
        .sheet(isPresented: $isShowingMoreFilters) {
            ClosetRefineSheet(filterState: $filterState, closets: closets)
                .presentationDetents([.height(320), .large])
                .presentationContentInteraction(.resizes)
                .presentationDragIndicator(.visible)
                .presentationBackground(PyxisColors.background)
        }
    }

    private var searchField: some View {
        HStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 19, weight: .light))
                .foregroundStyle(PyxisColors.text)
                .accessibilityHidden(true)

            TextField(
                "Search closet",
                text: $filterState.searchText,
                prompt: Text("SEARCH YOUR CLOSET")
                    .foregroundColor(PyxisColors.secondaryText)
            )
            .textFieldStyle(.plain)
            .font(PyxisTypography.editorialBody)
            .tracking(1.2)
            .autocorrectionDisabled()
            .focused(isSearchFocused)

            if !filterState.searchText.isEmpty {
                Button {
                    filterState.searchText = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(PyxisColors.field, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(PyxisColors.hairline, lineWidth: 1)
        }
        .editorialGlow()
        .accessibilityLabel("Search closet")
    }

    private var browseMenu: some View {
        HStack {
            Spacer(minLength: 0)
            Menu {
                Toggle(isOn: $filterState.favoritesOnly) {
                    Label("Favorites only", systemImage: "heart")
                }

                Section("Category") {
                    categoryOption("All items", category: nil)
                    ForEach(ClothingCategory.allCases) { category in
                        categoryOption(categoryTitle(category), category: category)
                    }
                }

                Button {
                    isShowingMoreFilters = true
                } label: {
                    Label("Sort & filter", systemImage: "slider.horizontal.3")
                }

                if filterState.hasActiveFilters {
                    Button("Clear all") {
                        filterState.clearAll()
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(browseTitle)
                            .font(PyxisTypography.editorialLabel)

                        if let browseDetail {
                            Text(browseDetail)
                                .font(PyxisTypography.editorialMicro)
                                .foregroundStyle(PyxisColors.secondaryText)
                                .lineLimit(1)
                        }
                    }

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .accessibilityHidden(true)
                }
                .tracking(1.1)
                .foregroundStyle(PyxisColors.text)
                .padding(.horizontal, PyxisSpacing.md)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Browse closet")
            .accessibilityValue(browseDetail.map { "\(browseTitle), \($0)" } ?? browseTitle)
            Spacer(minLength: 0)
        }
    }

    private func categoryOption(_ title: String, category: ClothingCategory?) -> some View {
        Button {
            filterState.selectCategory(category)
            if category == nil { filterState.subtype = nil }
        } label: {
            if filterState.category == category {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
        .accessibilityAddTraits(filterState.category == category ? .isSelected : [])
    }

    private func categoryTitle(_ category: ClothingCategory) -> String {
        category == .onePiece ? "One Piece" : category.rawValue.capitalized
    }

    private func sortTitle(_ option: ClosetSortOption) -> String {
        option == .mostWorn ? "Most Worn" : option.rawValue.capitalized
    }

    private var browseTitle: String {
        if let category = filterState.category {
            return categoryTitle(category).uppercased()
        }
        return filterState.favoritesOnly ? "FAVORITES" : "ALL ITEMS"
    }

    private var browseDetail: String? {
        var parts: [String] = []
        if filterState.category != nil && filterState.favoritesOnly {
            parts.append("FAVORITES")
        }
        if filterState.sort != .newest {
            parts.append(sortTitle(filterState.sort).uppercased())
        }
        let moreCount = [
            filterState.closetID != nil,
            filterState.subtype != nil,
            filterState.color != nil
        ].filter { $0 }.count
        if moreCount > 0 {
            parts.append("\(moreCount) FILTER\(moreCount == 1 ? "" : "S")")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
