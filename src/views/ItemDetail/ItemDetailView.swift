import SwiftData
import SwiftUI

struct ItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Outfit.dateCreated, order: .reverse) private var outfits: [Outfit]
    @Query(sort: \Closet.dateUpdated, order: .reverse) private var closets: [Closet]
    @Bindable var item: ClosetItem
    @StateObject private var viewModel = ItemDetailViewModel()
    @State private var isEditingDetails = false
    @State private var saveErrorMessage: String?
    @State private var isConfirmingDeletion = false
    let buildAction: ((ClosetItem) -> Void)?
    let showsCloseButton: Bool

    init(
        item: ClosetItem,
        showsCloseButton: Bool = true,
        buildAction: ((ClosetItem) -> Void)? = nil
    ) {
        self.item = item
        self.showsCloseButton = showsCloseButton
        self.buildAction = buildAction
    }

    private var fitUsageCount: Int {
        OutfitBuilderService().fitUsageCounts(from: outfits)[item.id, default: 0]
    }

    private var canBuildWithItem: Bool {
        OutfitBuilderService().slot(for: item.category) != nil
    }

    var body: some View {
        ScrollView {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: PyxisSpacing.xl) {
                    imagePanel
                    detailPanel
                        .frame(maxWidth: 330)
                }

                VStack(spacing: PyxisSpacing.lg) {
                    imagePanel
                    detailPanel
                }
            }
            .padding(PyxisSpacing.md)
        }
        .editorialCanvas()
        .disclosureGroupStyle(EditorialDisclosureGroupStyle())
        .editorialNavigationTitle(item.displayName ?? item.subtype.rawValue.capitalized)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Delete piece", systemImage: "trash", role: .destructive) { isConfirmingDeletion = true }
                } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                .accessibilityLabel("Piece options")
            }
            if showsCloseButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: saveAndDismiss).keyboardShortcut(.cancelAction)
                        .accessibilityLabel("Close item detail")
                }
            }
        }
        .onChange(of: isEditingDetails) { _, expanded in if !expanded { saveChanges() } }
        .confirmationDialog(
            "DELETE \(item.itemCode)?",
            isPresented: $isConfirmingDeletion,
            titleVisibility: .visible
        ) {
            Button("DELETE ITEM", role: .destructive, action: deleteItem)
            Button("CANCEL", role: .cancel) {}
        } message: {
            Text("This removes the item and its stored images from this device. This cannot be undone.")
        }
    }

    private var imagePanel: some View {
        VStack(spacing: PyxisSpacing.sm) {
            GarmentStage(url: viewModel.displayURL(for: item), revision: viewModel.imageRevision)
                .frame(maxWidth: 330)
                .frame(height: 300)
            ItemCodeLabel(code: item.itemCode)
        }
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.md) {
            if let saveErrorMessage { InlineErrorMessage(message: saveErrorMessage) }

            if canBuildWithItem, let buildAction {
                Button("Build with this") { buildAction(item) }
                    .buttonStyle(EditorialPrimaryButtonStyle())
            }
            Button("Wear today") {
                OutfitWearService().markWorn(item: item)
                saveChanges()
            }
            .buttonStyle(MinimalButtonStyle())
            .accessibilityLabel("Mark item worn today")

            if fitUsageCount > 0 || item.wearCount > 0 {
                VStack(alignment: .leading, spacing: PyxisSpacing.xs) {
                    if fitUsageCount > 0 { Text("Used in \(fitUsageCount) fit\(fitUsageCount == 1 ? "" : "s")") }
                    if item.wearCount > 0 {
                        Text("Worn \(item.wearCount) time\(item.wearCount == 1 ? "" : "s")")
                        if let date = item.lastWornDate {
                            Text("Last worn \(date.formatted(date: .abbreviated, time: .omitted))")
                        }
                    }
                }
                .font(PyxisTypography.proseCaption)
                .foregroundStyle(PyxisColors.secondaryText)
            }

            DisclosureGroup("Edit details", isExpanded: $isEditingDetails) {
                VStack(alignment: .leading, spacing: PyxisSpacing.md) {
                    detailField("Name", text: optionalString($item.displayName))
                    detailField("Brand", text: optionalString($item.brand))
                    detailField("Size", text: optionalString($item.size))
                    detailField("Notes", text: optionalString($item.notes), axis: .vertical)
                    EditorialMenuPicker(title: "Category", value: item.category.rawValue.capitalized, selection: categoryBinding) {
                        ForEach(ClothingCategory.allCases) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    EditorialMenuPicker(title: "Type", value: item.subtype.rawValue.capitalized, selection: subtypeBinding) {
                        ForEach(ClothingSubtype.compatibleSubtypes(for: item.category)) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    EditorialMenuPicker(title: "Color", value: item.primaryColor.rawValue.capitalized, selection: colorBinding) {
                        ForEach(ClosetColor.allCases) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    Toggle("Favorite", isOn: $item.favorite)
                    Stepper("Wear count \(item.wearCount)", value: $item.wearCount, in: 0...999)
                }
                .padding(.top, PyxisSpacing.md)
            }
            .frame(minHeight: 44)

            DisclosureGroup("Edit photo") {
                VStack(alignment: .leading, spacing: PyxisSpacing.md) {
                    if ClosetItemImageResolver.hasCutout(for: item) {
                        Toggle("Use original", isOn: $viewModel.showOriginal)
                    }
                    Button(viewModel.isRetryingBackgroundRemoval ? "Removing background…" : "Improve cutout") {
                        Task {
                            await viewModel.retryBackgroundRemoval(for: item)
                            saveChanges()
                        }
                    }
                    .buttonStyle(MinimalButtonStyle())
                    .disabled(viewModel.isRetryingBackgroundRemoval)
                    .accessibilityLabel("Retry background removal")
                    if let retryMessage = viewModel.retryMessage {
                        Text(retryMessage).font(PyxisTypography.proseCaption)
                            .foregroundStyle(PyxisColors.secondaryText)
                    }
                }
                .padding(.top, PyxisSpacing.md)
            }
            .frame(minHeight: 44)

            if !closets.isEmpty {
                DisclosureGroup("Closets") {
                    ForEach(closets) { closet in
                        Toggle(closet.displayName, isOn: closetBinding(for: closet))
                    }
                    .padding(.top, PyxisSpacing.sm)
                }
                .frame(minHeight: 44)
            }
        }
        .font(PyxisTypography.control)
        .textFieldStyle(.plain)
        .tint(PyxisColors.text)
    }

    private func detailField(_ title: String, text: Binding<String>, axis: Axis = .horizontal) -> some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.xs) {
            Text(title).font(PyxisTypography.label).foregroundStyle(PyxisColors.secondaryText)
            EditorialTextField(title, text: text, axis: axis).frame(minHeight: 44).accessibilityLabel(title)
                .padding(.horizontal, PyxisSpacing.sm).background(PyxisColors.field)
        }
    }

    private var categoryBinding: Binding<ClothingCategory> {
        Binding(
            get: { item.category },
            set: { newCategory in
                item.category = newCategory
                if !item.subtype.isCompatible(with: newCategory) {
                    item.subtype = ClothingSubtype.defaultSubtype(for: newCategory)
                }
            }
        )
    }

    private var subtypeBinding: Binding<ClothingSubtype> {
        Binding(
            get: { item.subtype },
            set: { item.subtype = $0 }
        )
    }

    private var colorBinding: Binding<ClosetColor> {
        Binding(
            get: { item.primaryColor },
            set: { item.primaryColor = $0 }
        )
    }

    private func closetBinding(for closet: Closet) -> Binding<Bool> {
        Binding(
            get: { closet.contains(item) },
            set: { isIncluded in
                closet.setContains(isIncluded, item: item)
                saveChanges()
            }
        )
    }

    private func saveChanges() {
        do {
            item.touch()
            try upsertItemMemory()
            try modelContext.save()
            saveErrorMessage = nil
        } catch {
            saveErrorMessage = PersistenceErrorMessage.saveFailed(error)
        }
    }

    private func deleteItem() {
        let imageSet = viewModel.storedImageSet(for: item)
        do {
            try OnDeviceMemoryStore(context: modelContext).deleteMemories(
                subjectID: item.id,
                saveImmediately: false
            )
            closets.forEach { $0.remove(item) }
            modelContext.delete(item)
            try modelContext.save()
            viewModel.deleteImages(imageSet)
            saveErrorMessage = nil
            dismiss()
        } catch {
            saveErrorMessage = PersistenceErrorMessage.saveFailed(error)
            modelContext.rollback()
        }
    }

    private func saveAndDismiss() {
        do {
            item.touch()
            try upsertItemMemory()
            try modelContext.save()
            saveErrorMessage = nil
            dismiss()
        } catch {
            saveErrorMessage = PersistenceErrorMessage.saveFailed(error)
        }
    }

    private func upsertItemMemory() throws {
        let payload = OnDeviceMemoryPayloadBuilder.closetItemPayload(for: item)
        try OnDeviceMemoryStore(context: modelContext).upsertMemory(
            kind: .closetItem,
            subjectID: item.id,
            summary: payload.summary,
            embedding: payload.embedding,
            metadataTags: payload.metadataTags,
            updatedAt: item.effectiveDateUpdated,
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
