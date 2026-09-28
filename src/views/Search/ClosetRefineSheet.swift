import SwiftUI

struct ClosetRefineSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filterState: ClosetFilterState
    let closets: [Closet]

    var body: some View {
        NavigationStack {
            Form {
                Picker("Sort", selection: $filterState.sort) {
                    ForEach(ClosetSortOption.allCases) { option in
                        Text(option == .mostWorn ? "Most Worn" : option.rawValue.capitalized).tag(option)
                    }
                }
                .pickerStyle(.navigationLink)

                if !closets.isEmpty {
                    Picker("Closet", selection: $filterState.closetID) {
                        Text("All closets").tag(Optional<UUID>.none)
                        ForEach(closets) { closet in
                            Text(closet.displayName).tag(Optional(closet.id))
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                if let category = filterState.category {
                    Picker("Type", selection: $filterState.subtype) {
                        Text("All \(categoryTitle(category))").tag(Optional<ClothingSubtype>.none)
                        ForEach(ClothingSubtype.compatibleSubtypes(for: category)) { subtype in
                            Text(subtype.rawValue.capitalized).tag(Optional(subtype))
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Picker("Color", selection: $filterState.color) {
                    Text("All colors").tag(Optional<ClosetColor>.none)
                    ForEach(ClosetColor.allCases.filter { $0 != .unknown }) { color in
                        Text(color.rawValue.capitalized).tag(Optional(color))
                    }
                }
                .pickerStyle(.navigationLink)
            }
            .scrollContentBackground(.hidden)
            .background(PyxisColors.background)
            .foregroundStyle(PyxisColors.text)
            .navigationTitle("SORT & FILTER")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PyxisColors.text)
                }
            }
        }
    }

    private func categoryTitle(_ category: ClothingCategory) -> String {
        category == .onePiece ? "One Piece" : category.rawValue.capitalized
    }
}
