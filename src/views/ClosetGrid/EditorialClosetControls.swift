import SwiftUI

struct EditorialClosetControls: View {
    @Binding var filterState: ClosetFilterState
    let closets: [Closet]
    var isSearchFocused: FocusState<Bool>.Binding
    @State private var showsFilters = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20, weight: .light))
                    TextField("Search your closet", text: $filterState.searchText, prompt: Text("SEARCH YOUR CLOSET").foregroundStyle(PyxisColors.secondaryText))
                        .font(PyxisTypography.editorialLabel)
                        .tracking(1.2)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused(isSearchFocused)
                        .submitLabel(.search)
                        .accessibilityLabel("Search your closet")
                    if !filterState.searchText.isEmpty {
                        Button { filterState.searchText = "" } label: {
                            Image(systemName: "xmark").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.leading, 16)
                .frame(minHeight: 52)
                .background(PyxisColors.field.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(PyxisColors.hairline, lineWidth: 0.75) }

                Button { showsFilters = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 23, weight: .ultraLight))
                        .frame(width: 52, height: 52)
                        .background(PyxisColors.field.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
                        .overlay { RoundedRectangle(cornerRadius: 10).stroke(PyxisColors.hairline, lineWidth: 0.75) }
                        .overlay(alignment: .topTrailing) {
                            if filterState.hasActiveFilters {
                                Circle().fill(PyxisColors.text).frame(width: 6, height: 6).padding(7)
                            }
                        }
                }
                .accessibilityLabel("Open closet filters")
                .accessibilityValue("\(filterState.activeFilterCount) active filters")
            }
            ViewThatFits(in: .horizontal) {
                HStack { categoryMenu; Spacer(minLength: 12); sortMenu }
                VStack(alignment: .leading) { categoryMenu; sortMenu }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(PyxisColors.text)
        .sheet(isPresented: $showsFilters) {
            ClosetFilterSheet(filterState: $filterState, closets: closets)
                .presentationDetents([.medium, .large])
        }
    }

    private var categoryMenu: some View {
        Menu {
            Button("All items") {
                filterState.selectCategory(nil)
                filterState.subtype = nil
                filterState.favoritesOnly = false
            }
            ForEach(ClothingCategory.allCases) { category in
                Button(category.rawValue.capitalized) { filterState.selectCategory(category) }
            }
            Divider()
            Toggle("Favorites only", isOn: $filterState.favoritesOnly)
        } label: {
            menuLabel(filterState.category?.rawValue ?? (filterState.favoritesOnly ? "FAVORITES" : "ALL ITEMS"))
        }
        .accessibilityLabel("Category: \(filterState.category?.rawValue ?? "All items")")
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $filterState.sort) {
                ForEach(ClosetSortOption.allCases) { option in
                    Text(sortTitle(option)).tag(option)
                }
            }
        } label: { menuLabel(sortTitle(filterState.sort)) }
        .accessibilityLabel("Sort: \(sortTitle(filterState.sort))")
    }

    private func sortTitle(_ option: ClosetSortOption) -> String {
        option == .mostWorn ? "MOST WORN" : option.rawValue.uppercased()
    }

    private func menuLabel(_ title: String) -> some View {
        HStack(spacing: 10) {
            Text(title.uppercased()).font(PyxisTypography.editorialLabel).tracking(1.5)
            Image(systemName: "chevron.down").font(.system(size: 11, weight: .light))
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}
