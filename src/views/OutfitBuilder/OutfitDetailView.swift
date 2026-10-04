import SwiftData
import SwiftUI

struct OutfitDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClosetItem.dateAdded, order: .reverse) private var items: [ClosetItem]
    @Bindable var outfit: Outfit
    @State private var refreshID = UUID()
    @State private var saveErrorMessage: String?
    @State private var tryOnSheet: TryOnEntry?
    @StateObject private var tryOnEntry = TryOnEntryViewModel()
    @State private var isConfirmingDeletion = false
    @State private var duplicateConfirmation: String?

    private var selectedItems: [ClosetItem] {
        outfit.itemIDs.compactMap { itemID in
            items.first { $0.id == itemID }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PyxisSpacing.lg) {
                if let saveErrorMessage { InlineErrorMessage(message: saveErrorMessage) }
                if let duplicateConfirmation {
                    Text(duplicateConfirmation).font(PyxisTypography.proseCaption)
                        .foregroundStyle(PyxisColors.secondaryText)
                }
                OutfitFlatLayView(items: selectedItems)
                    .frame(height: 265)
                    .garmentSurface()
                    .accessibilityHidden(true)

                Button("Wear today", action: markWornToday)
                    .buttonStyle(EditorialPrimaryButtonStyle())
                    .accessibilityLabel("Mark fit worn today")

                Text("\(selectedItems.count) pieces" + (outfit.wearCount > 0 ? " · Worn \(outfit.wearCount)×" : ""))
                    .font(PyxisTypography.editorialLabel)
                    .foregroundStyle(PyxisColors.secondaryText)

                VStack(spacing: PyxisSpacing.sm) {
                    ForEach(selectedItems) { item in
                        NavigationLink {
                            ItemDetailView(item: item, showsCloseButton: false)
                        } label: {
                            HStack(spacing: PyxisSpacing.md) {
                                SavedFitItemImage(item: item).frame(width: 58, height: 84).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: PyxisSpacing.xs) {
                                    Text(item.displayName ?? item.subtype.rawValue.capitalized)
                                        .font(PyxisTypography.control)
                                        .fixedSize(horizontal: false, vertical: true)
                                    ItemCodeLabel(code: item.itemCode)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).accessibilityHidden(true)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Open \(item.displayName ?? item.subtype.rawValue), \(item.itemCode)")
                    }
                }

                if selectedItems.count < outfit.itemIDs.count {
                    Text("Some pieces are no longer in your closet.")
                        .font(PyxisTypography.proseCaption).foregroundStyle(PyxisColors.error)
                }
                if let destination = tryOnEntry.destination {
                    Button(destination.title) { tryOnSheet = destination }.buttonStyle(MinimalButtonStyle())
                }
                DisclosureGroup("Edit fit") {
                    VStack(alignment: .leading, spacing: PyxisSpacing.md) {
                        fitField("Name", text: optionalString($outfit.name))
                        fitField("Notes", text: optionalString($outfit.notes), axis: .vertical)
                        Toggle("Favorite", isOn: $outfit.favorite)
                    }
                    .padding(.top, PyxisSpacing.md)
                }
                .font(PyxisTypography.control)
                .frame(minHeight: 44)
            }
            .padding(24)
        }
        .editorialCanvas()
        .disclosureGroupStyle(EditorialDisclosureGroupStyle())
        .editorialNavigationTitle(outfit.name ?? outfit.dateCreated.formatted(date: .abbreviated, time: .omitted))
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back", action: saveAndDismiss).accessibilityLabel("Save fit and go back")
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Share fit")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Duplicate fit", systemImage: "plus.square.on.square", action: duplicateFit)
                    Button("Delete fit", systemImage: "trash", role: .destructive) { isConfirmingDeletion = true }
                } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                .accessibilityLabel("Saved fit options")
            }
        }
        .id(refreshID)
        .task { await tryOnEntry.load() }
        .sheet(item: $tryOnSheet) { destination in
            switch destination {
            case .generate: AITryOnView(items: selectedItems)
            case .savedPreviews: SavedTryOnEntryView()
            }
        }
        .confirmationDialog("Delete this saved fit?", isPresented: $isConfirmingDeletion, titleVisibility: .visible) {
            Button("Delete fit", role: .destructive, action: deleteFit)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the fit from this device. Closet items are not deleted.")
        }
    }

    private func fitField(_ title: String, text: Binding<String>, axis: Axis = .horizontal) -> some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.xs) {
            Text(title).font(PyxisTypography.label).foregroundStyle(PyxisColors.secondaryText)
            EditorialTextField(title, text: text, axis: axis).font(PyxisTypography.control)
                .frame(minHeight: 44).padding(.horizontal, PyxisSpacing.sm)
                .background(PyxisColors.field).accessibilityLabel(title)
        }
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
            duplicateConfirmation = "Fit duplicated"
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
