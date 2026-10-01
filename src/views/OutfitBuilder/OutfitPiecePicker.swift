import SwiftUI

struct OutfitPiecePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let items: [ClosetItem]
    let composition: OutfitComposition
    let select: (ClosetItem) -> Bool
    @State private var slot: OutfitSlot
    @State private var isShowingImport = false
    @State private var selectionError: String?

    init(items: [ClosetItem], composition: OutfitComposition, slot: OutfitSlot? = nil,
         select: @escaping (ClosetItem) -> Bool) {
        self.items = items
        self.composition = composition
        self.select = select
        self._slot = State(initialValue: slot ?? .top)
    }

    private var candidates: [ClosetItem] {
        items.filter { !$0.isDeleted && $0.category == slot.category }.sorted { $0.itemCode < $1.itemCode }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(OutfitSlot.allCases) { candidate in
                            Button { slot = candidate; selectionError = nil } label: {
                                Text(title(candidate))
                                    .font(PyxisTypography.control)
                                    .foregroundStyle(slot == candidate ? PyxisColors.text : PyxisColors.inactiveText)
                                    .padding(.vertical, 12)
                                    .frame(minHeight: 44)
                                    .contentShape(Rectangle())
                                    .overlay(alignment: .bottom) {
                                        if slot == candidate { Rectangle().fill(PyxisColors.text).frame(height: 1) }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(slot == candidate ? .isSelected : [])
                        }
                    }
                }
                if let selectionError { InlineErrorMessage(message: selectionError) }
                if composition.keptSlots.contains(slot) {
                    Text("Unlock this piece in your fit before swapping it.")
                        .font(PyxisTypography.control)
                        .foregroundStyle(PyxisColors.secondaryText)
                }
                if candidates.isEmpty {
                    ContentUnavailableView("No \(title(slot).lowercased()) yet", systemImage: "hanger",
                                           description: Text("Add a piece to your closet to use it here."))
                } else {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16),
                                                 count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 20) {
                            ForEach(candidates) { item in
                                Button { choose(item) } label: {
                                    ClosetGridItemView(item: item)
                                        .overlay(alignment: .topTrailing) {
                                            if composition.selections[slot] == item.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(PyxisColors.text)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                                .disabled(composition.keptSlots.contains(slot) && composition.selections[slot] != item.id)
                                .accessibilityLabel("Use \(item.displayName ?? item.subtype.rawValue), \(item.itemCode)")
                                .accessibilityIdentifier("fit.choose.\(item.itemCode)")
                            }
                        }
                    }
                }
                Button { isShowingImport = true } label: { Label("Add a new piece", systemImage: "plus") }
                    .buttonStyle(EditorialPrimaryButtonStyle())
            }
            .padding(24)
            .editorialCanvas()
            .navigationTitle("Choose a piece")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $isShowingImport) {
                AddItemFlow(initialCategory: slot.category) { item in choose(item) }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func choose(_ item: ClosetItem) {
        if select(item) { dismiss() }
        else { selectionError = "Unlock the kept piece before replacing it." }
    }

    private func title(_ slot: OutfitSlot) -> String {
        switch slot {
        case .top: "Tops"
        case .bottom: "Bottoms"
        case .onePiece: "One piece"
        case .footwear: "Shoes"
        case .outerwear: "Outerwear"
        case .accessory: "Accessories"
        }
    }
}
