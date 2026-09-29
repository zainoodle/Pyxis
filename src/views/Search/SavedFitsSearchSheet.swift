import SwiftUI

struct SavedFitsSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @Binding var query: OutfitGalleryQuery
    let outfits: [Outfit]
    let items: [ClosetItem]
    let selectFit: (Outfit) -> Void

    private var results: [Outfit] {
        OutfitGalleryService().filteredOutfits(outfits, items: items, query: query)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").accessibilityHidden(true)
                    TextField("Search your fits", text: $query.searchText)
                        .font(PyxisTypography.body)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isFocused)
                        .submitLabel(.search)
                        .onSubmit { isFocused = false }
                        .accessibilityIdentifier("fits.search")
                    if !query.searchText.isEmpty {
                        HeaderIconButton(symbol: "xmark.circle.fill", label: "Clear search") { query.searchText = "" }
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .background(PyxisColors.field, in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 24)

                if results.isEmpty {
                    ContentUnavailableView.search(text: query.searchText)
                } else {
                    List(results) { outfit in
                        Button {
                            dismiss()
                            selectFit(outfit)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(outfit.name ?? "Untitled fit").font(PyxisTypography.body)
                                Text("\(outfit.itemIDs.count) pieces")
                                    .font(PyxisTypography.label)
                                    .foregroundStyle(PyxisColors.secondaryText)
                            }
                            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
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
            .editorialNavigationTitle("Search fits")
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
