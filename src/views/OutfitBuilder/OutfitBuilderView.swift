import SwiftData
import SwiftUI

struct OutfitBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClosetItem.dateAdded, order: .reverse) private var items: [ClosetItem]
    @State private var composition = OutfitComposition()
    @State private var didInitialize = false
    @State private var didSave = false
    @State private var isDraftSaved = false
    @State private var sheet: BuilderSheet?
    @State private var saveErrorMessage: String?
    @State private var isShowingDiscardConfirmation = false
    @StateObject private var tryOnEntry = TryOnEntryViewModel()
    private let initialItemID: UUID?
    private let service = OutfitBuilderService()
    private let draftStore = OutfitDraftStore()

    init(initialItemID: UUID? = nil) { self.initialItemID = initialItemID }

    private var activeItems: [ClosetItem] { items.filter { !$0.isDeleted } }
    private var selectedPieces: [ClosetItem] {
        let order: [OutfitSlot] = [.outerwear, .bottom, .top, .onePiece, .footwear, .accessory]
        return order.compactMap { slot in
            composition.selections[slot].flatMap { id in activeItems.first { $0.id == id } }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    OutfitFlatLayView(items: selectedPieces)
                        .frame(height: dynamicTypeSize.isAccessibilitySize ? 220 : 320)
                        .padding(.vertical, 10)
                        .accessibilityLabel("Your fit, \(selectedPieces.count) pieces")
                    ForEach(selectedPieces) { item in pieceRow(item) }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
        .editorialCanvas()
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom, spacing: 0) { actionRail }
        .onAppear(perform: initializeDraft)
        .task { await tryOnEntry.load() }
        .onChange(of: items.map { "\($0.id)|\($0.categoryRawValue)|\($0.isDeleted)" }) { _, _ in
            composition.reconcile(with: activeItems)
        }
        .onChange(of: composition) { _, _ in persistDraft() }
        .sheet(item: $sheet) { destination in
            switch destination {
            case .pieces(let slot):
                OutfitPiecePicker(items: activeItems, composition: composition, slot: slot, select: select)
            case .tryOn:
                AITryOnView(items: selectedPieces)
            case .savedPreviews:
                SavedTryOnEntryView()
            }
        }
        .confirmationDialog("Discard this draft?", isPresented: $isShowingDiscardConfirmation, titleVisibility: .visible) {
            Button("Discard draft", role: .destructive) {
                didSave = true
                draftStore.clear()
                dismiss()
            }
        } message: { Text("Your saved fits and closet pieces will stay in your wardrobe.") }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button { dismiss() } label: {
                    Label("Fits", systemImage: "chevron.left")
                        .font(PyxisTypography.editorialLabel)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to fits, keeping draft")
                Spacer()
                Menu {
                    if let destination = tryOnEntry.destination {
                        Button(destination.title, systemImage: "person.crop.rectangle") {
                            sheet = destination == .generate ? .tryOn : .savedPreviews
                        }
                        .disabled(destination == .generate && selectedPieces.isEmpty)
                    }
                    Button("Discard draft", systemImage: "trash", role: .destructive) {
                        isShowingDiscardConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Fit options")
            }
            Text("Your fit")
                .font(PyxisTypography.pageTitle)
                .accessibilityAddTraits(.isHeader)
            Text("\(selectedPieces.count) pieces · \(isDraftSaved ? "Draft saved" : "Working draft")")
                .font(PyxisTypography.editorialLabel)
                .foregroundStyle(PyxisColors.secondaryText)
                .accessibilityIdentifier("fit.draftStatus")
        }
        .foregroundStyle(PyxisColors.text)
        .padding(.horizontal, 24)
        .padding(.bottom, 6)
    }

    private func pieceRow(_ item: ClosetItem) -> some View {
        let slot = service.slot(for: item.category) ?? .accessory
        let isKept = composition.keptSlots.contains(slot)
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 14))
        return VStack(spacing: 0) {
            Rectangle().fill(PyxisColors.hairline.opacity(0.65)).frame(height: 0.5)
            layout {
                HStack(spacing: 14) {
                    LocalImageView(
                        url: ImageStorageService.shared?.url(for: ClosetItemImageResolver.preferredDisplayPath(for: item)),
                        revision: Int(item.effectiveDateUpdated.timeIntervalSince1970 * 1_000)
                    )
                    .frame(width: 46, height: 44)
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.displayName ?? item.subtype.rawValue.capitalized)
                            .font(PyxisTypography.editorialBody)
                            .fixedSize(horizontal: false, vertical: true)
                        ItemCodeLabel(code: item.itemCode)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    if isKept { composition.toggleKeep(slot) }
                    else { sheet = .pieces(slot) }
                } label: {
                    Label(isKept ? "Keep" : "Swap", systemImage: isKept ? "lock" : "arrow.left.arrow.right")
                        .font(PyxisTypography.editorialLabel)
                        .foregroundStyle(PyxisColors.secondaryText)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isKept ? "Unlock \(item.itemCode)" : "Swap \(item.itemCode)")
                .accessibilityIdentifier("fit.\(isKept ? "unlock" : "swap").\(item.itemCode)")
            }
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 10 : 5)
            .foregroundStyle(PyxisColors.text)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button(isKept ? "Unlock piece" : "Keep piece", systemImage: isKept ? "lock.open" : "lock") {
                composition.toggleKeep(slot)
            }
            Button("Remove from fit", systemImage: "minus", role: .destructive) { composition.remove(slot) }
                .disabled(isKept)
        }
        .accessibilityAction(named: isKept ? "Unlock piece" : "Keep piece") { composition.toggleKeep(slot) }
        .accessibilityAction(named: "Remove from fit") { composition.remove(slot) }
    }

    private var actionRail: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let saveErrorMessage { InlineErrorMessage(message: saveErrorMessage) }
            if let requirement {
                Text(requirement)
                    .font(PyxisTypography.editorialLabel)
                    .foregroundStyle(PyxisColors.secondaryText)
            }
            Button { sheet = .pieces(nil) } label: {
                Label("Add a piece", systemImage: "plus")
                    .font(PyxisTypography.control)
                    .foregroundStyle(PyxisColors.secondaryText)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("fit.addPiece")
            Button("Save fit", action: saveFit)
                .buttonStyle(EditorialPrimaryButtonStyle())
                .disabled(!service.canSave(composition.draft))
                .accessibilityIdentifier("fit.save")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(PyxisColors.background)
    }

    private var requirement: String? {
        let draft = composition.draft
        if draft.footwearItemID == nil { return "Add shoes to complete this fit." }
        if draft.onePieceItemID == nil && (draft.topItemID == nil || draft.bottomItemID == nil) {
            return "Add a top and bottom, or one piece." }
        return nil
    }

    private func initializeDraft() {
        guard !didInitialize else { return }
        do {
            if let saved = try draftStore.load() { composition = saved }
            else {
                let rows = service.requiredRows(from: activeItems) + service.optionalRows(from: activeItems)
                let draft = service.draft(from: rows, selections: service.defaultSelections(for: rows))
                composition = OutfitComposition(selections: Dictionary(uniqueKeysWithValues: [
                    (OutfitSlot.top, draft.topItemID), (.bottom, draft.bottomItemID),
                    (.onePiece, draft.onePieceItemID), (.footwear, draft.footwearItemID)
                ].compactMap { slot, id in id.map { (slot, $0) } }))
            }
        } catch { saveErrorMessage = "The previous draft could not be opened. You can build a new fit." }
        composition.reconcile(with: activeItems)
        if let initialItemID, let item = activeItems.first(where: { $0.id == initialItemID }),
           let slot = service.slot(for: item.category) {
            composition.begin(with: item.id, for: slot)
        }
        didInitialize = true
        persistDraft()
    }

    private func select(_ item: ClosetItem) -> Bool {
        guard let slot = service.slot(for: item.category), composition.select(item.id, for: slot) else { return false }
        return true
    }

    private func persistDraft() {
        guard didInitialize, !didSave else { return }
        do { try draftStore.save(composition); isDraftSaved = true }
        catch { isDraftSaved = false; saveErrorMessage = "This draft could not be saved. Keep this screen open and try again." }
    }

    private func saveFit() {
        guard service.canSave(composition.draft) else { return }
        let outfit = service.outfit(from: composition.draft)
        modelContext.insert(outfit)
        do {
            let payload = OnDeviceMemoryPayloadBuilder.outfitPayload(for: outfit, items: activeItems)
            try OnDeviceMemoryStore(context: modelContext).upsertMemory(
                kind: .outfit, subjectID: outfit.id, summary: payload.summary,
                embedding: payload.embedding, metadataTags: payload.metadataTags,
                updatedAt: outfit.dateUpdated, saveImmediately: false
            )
            try modelContext.save()
            didSave = true
            draftStore.clear()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = PersistenceErrorMessage.saveFailed(error)
        }
    }
}

private enum BuilderSheet: Identifiable {
    case pieces(OutfitSlot?), tryOn, savedPreviews
    var id: String {
        switch self {
        case .pieces(let slot): "pieces.\(slot?.rawValue ?? "all")"
        case .tryOn: "tryOn"
        case .savedPreviews: "savedPreviews"
        }
    }
}
