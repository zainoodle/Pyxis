import SwiftData
import SwiftUI

struct OutfitDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClosetItem.dateAdded, order: .reverse) private var items: [ClosetItem]
    @Bindable var outfit: Outfit
    @State private var refreshID = UUID()
    @State private var saveErrorMessage: String?
    @State private var isConfirmingDeletion = false
    @State private var duplicateConfirmation: String?

    private var selectedItems: [ClosetItem] {
        outfit.itemIDs.compactMap { itemID in
            items.first { $0.id == itemID }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.lg) {
            HStack {
                Text(outfit.name?.uppercased() ?? "FIT DETAIL")
                    .font(PyxisTypography.title)

                Spacer()

                Button("WORN") {
                    markWornToday()
                }
                .buttonStyle(MinimalButtonStyle())

                Button("CLOSE") {
                    saveAndDismiss()
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Close fit detail")
            }

            if let saveErrorMessage {
                InlineErrorMessage(message: saveErrorMessage)
            }

            if let duplicateConfirmation {
                Text(duplicateConfirmation)
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.secondaryText)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: PyxisSpacing.lg) {
                    VStack(spacing: PyxisSpacing.sm) {
                        ForEach(selectedItems) { item in
                            HStack(spacing: PyxisSpacing.md) {
                                SavedFitItemImage(item: item)
                                    .frame(width: 58, height: 84)

                                VStack(alignment: .leading, spacing: PyxisSpacing.xs) {
                                    ItemCodeLabel(code: item.itemCode)
                                    Text(item.displayName?.uppercased() ?? item.subtype.rawValue.uppercased())
                                        .font(PyxisTypography.body)
                                        .foregroundStyle(PyxisColors.secondaryText)
                                        .lineLimit(1)
                                    Text("WORN \(item.wearCount)")
                                        .font(PyxisTypography.label)
                                        .foregroundStyle(PyxisColors.inactiveText)
                                }

                                Spacer()
                            }
                        }
                    }

                    if selectedItems.count < outfit.itemIDs.count {
                        Text("SOME ITEMS IN THIS FIT ARE NO LONGER IN YOUR CLOSET")
                            .font(PyxisTypography.label)
                            .foregroundStyle(PyxisColors.error)
                            .accessibilityLabel("Some items in this fit are no longer in your closet")
                    }

                    TextField("FIT NAME", text: optionalString($outfit.name))
                        .textFieldStyle(.plain)
                        .font(PyxisTypography.body)
                        .padding(PyxisSpacing.md)
                        .background(PyxisColors.field)

                    TextField("NOTES", text: optionalString($outfit.notes), axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(PyxisTypography.body)
                        .padding(PyxisSpacing.md)
                        .background(PyxisColors.field)

                    Toggle("FAVORITE", isOn: $outfit.favorite)
                        .font(PyxisTypography.body)

                    HStack(spacing: PyxisSpacing.md) {
                        Button("MARK WORN TODAY") {
                            markWornToday()
                        }
                        .buttonStyle(MinimalButtonStyle())

                        Text("FIT WORN \(outfit.wearCount)")
                            .font(PyxisTypography.label)
                            .foregroundStyle(PyxisColors.secondaryText)
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: PyxisSpacing.md) { lifecycleActions }
                        VStack(alignment: .leading, spacing: PyxisSpacing.sm) { lifecycleActions }
                    }
                }
            }
        }
        .padding(PyxisSpacing.md)
        .background(PyxisColors.background)
        .id(refreshID)
        .confirmationDialog("Delete this saved fit?", isPresented: $isConfirmingDeletion, titleVisibility: .visible) {
            Button("DELETE FIT", role: .destructive, action: deleteFit)
            Button("CANCEL", role: .cancel) {}
        } message: {
            Text("This permanently removes the fit from this device. Closet items are not deleted.")
        }
    }

    @ViewBuilder
    private var lifecycleActions: some View {
        Button("DUPLICATE FIT", action: duplicateFit)
            .buttonStyle(MinimalButtonStyle())
        ShareLink(item: shareText) {
            Text("SHARE FIT")
        }
        .buttonStyle(MinimalButtonStyle())
        Button("DELETE FIT", role: .destructive) { isConfirmingDeletion = true }
            .buttonStyle(MinimalButtonStyle())
    }

    private var shareText: String {
        let title = outfit.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let itemList = selectedItems.map { $0.displayName ?? $0.itemCode }.joined(separator: ", ")
        return "\((title?.isEmpty == false ? title : nil) ?? "Pyxis fit"): \(itemList)"
    }

    private func markWornToday() {
        OutfitWearService().markWorn(outfit: outfit, items: items)
        do {
            try upsertOutfitMemory()
            try modelContext.save()
            saveErrorMessage = nil
            refreshID = UUID()
        } catch {
            saveErrorMessage = PersistenceErrorMessage.saveFailed(error)
        }
    }

    private func saveAndDismiss() {
        do {
            outfit.touch()
            try upsertOutfitMemory()
            try modelContext.save()
            saveErrorMessage = nil
            dismiss()
        } catch {
            saveErrorMessage = PersistenceErrorMessage.saveFailed(error)
        }
    }

    private func duplicateFit() {
        let copy = Outfit(
            name: outfit.name.map { "\($0) Copy" },
            topItemID: outfit.topItemID,
            bottomItemID: outfit.bottomItemID,
            onePieceItemID: outfit.onePieceItemID,
            footwearItemID: outfit.footwearItemID,
            outerwearItemID: outfit.outerwearItemID,
            accessoryItemIDs: outfit.accessoryItemIDs,
            favorite: outfit.favorite,
            notes: outfit.notes
        )
        modelContext.insert(copy)
        do {
            let payload = OnDeviceMemoryPayloadBuilder.outfitPayload(for: copy, items: selectedItems)
            try OnDeviceMemoryStore(context: modelContext).upsertMemory(
                kind: .outfit,
                subjectID: copy.id,
                summary: payload.summary,
                embedding: payload.embedding,
                metadataTags: payload.metadataTags,
                updatedAt: copy.dateUpdated,
                saveImmediately: false
            )
            try modelContext.save()
            duplicateConfirmation = "FIT DUPLICATED"
            saveErrorMessage = nil
        } catch {
            modelContext.rollback()
            saveErrorMessage = PersistenceErrorMessage.saveFailed(error)
        }
    }

    private func deleteFit() {
        do {
            try OnDeviceMemoryStore(context: modelContext).deleteMemories(subjectID: outfit.id, saveImmediately: false)
            modelContext.delete(outfit)
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = PersistenceErrorMessage.saveFailed(error)
        }
    }

    private func upsertOutfitMemory() throws {
        let payload = OnDeviceMemoryPayloadBuilder.outfitPayload(for: outfit, items: selectedItems)
        try OnDeviceMemoryStore(context: modelContext).upsertMemory(
            kind: .outfit,
            subjectID: outfit.id,
            summary: payload.summary,
            embedding: payload.embedding,
            metadataTags: payload.metadataTags,
            updatedAt: outfit.dateUpdated,
            saveImmediately: false
        )
    }

    private func optionalString(_ value: Binding<String?>) -> Binding<String> {
        Binding<String>(
            get: { value.wrappedValue ?? "" },
            set: { value.wrappedValue = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        )
    }
}
