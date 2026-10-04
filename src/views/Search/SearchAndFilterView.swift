import SwiftUI

struct SearchAndFilterView: View {
    @Binding var filterState: ClosetFilterState
    let closets: [Closet]
    @State private var isShowingMoreFilters = false

    var body: some View {
        HStack {
            browseMenu
            Spacer(minLength: 0)
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

    private var browseMenu: some View {
        HStack {
            Menu {
                Toggle(isOn: $filterState.favoritesOnly) {
                    Label("Favorites only", systemImage: "heart")
                }

                Section("Category") {
                    categoryOption("All pieces", category: nil)
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
                        Text(browseTitle.uppercased())
                            .font(PyxisTypography.closetBrowse)
                            .tracking(1.4)
                            .multilineTextAlignment(.leading)

                        if let browseDetail {
                            Text(browseDetail)
                                .font(PyxisTypography.editorialMicro)
                                .foregroundStyle(PyxisColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(PyxisColors.text)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Browse closet")
            .accessibilityIdentifier("closet.browse")
            .accessibilityValue(browseDetail.map { "\(browseTitle), \($0)" } ?? browseTitle)
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
            return categoryTitle(category)
        }
        return filterState.favoritesOnly ? "Favorites" : "All pieces"
    }

    private var browseDetail: String? {
        var parts: [String] = []
        if !filterState.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("“\(filterState.searchText)”")
        }
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
