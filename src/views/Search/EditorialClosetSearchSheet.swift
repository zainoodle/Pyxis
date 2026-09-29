import SwiftUI

struct EditorialClosetSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @Binding var filterState: ClosetFilterState
    let items: [ClosetItem]
    let closets: [Closet]
    let selectItem: (UUID) -> Void

    private var results: [ClosetItem] {
        ClosetFilteringService().filteredItems(items, state: filterState, closets: closets)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .accessibilityHidden(true)
                    TextField("Search your closet", text: $filterState.searchText)
                        .font(PyxisTypography.body)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isFocused)
                        .submitLabel(.search)
                        .onSubmit { isFocused = false }
                        .accessibilityIdentifier("closet.search")
                    if !filterState.searchText.isEmpty {
                        Button {
                            filterState.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .background(PyxisColors.field, in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 24)

                if results.isEmpty {
                    ContentUnavailableView.search(text: filterState.searchText)
                } else {
                    List(results) { item in
                        Button {
                            selectItem(item.id)
                            dismiss()
                        } label: {
                            HStack(spacing: 16) {
                                LocalImageView(url: ImageStorageService.shared?.url(for: ClosetItemImageResolver.preferredDisplayPath(for: item)))
                                    .frame(width: 56, height: 68)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.displayName ?? item.subtype.rawValue.capitalized)
                                        .font(PyxisTypography.body)
                                    ItemCodeLabel(code: item.itemCode)
                                    Text(item.category.rawValue.capitalized)
                                        .font(PyxisTypography.label)
                                        .foregroundStyle(PyxisColors.secondaryText)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .foregroundStyle(PyxisColors.text)
            .editorialCanvas()
            .editorialNavigationTitle("Search closet")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { isFocused = true }
        }
        .tint(PyxisColors.text)
    }
}
