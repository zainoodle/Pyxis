import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct OutfitBuilderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClosetItem.dateAdded, order: .reverse) private var items: [ClosetItem]

    @State private var selections: [OutfitSlot: Int] = [:]
    @State private var focusedItemID: UUID?
    @State private var isShowingAddFlow = false
    @State private var isShowingTryOn = false
    @State private var saveErrorMessage: String?

    private let service = OutfitBuilderService()
    private let initialItemID: UUID?

    init(initialItemID: UUID? = nil) {
        self.initialItemID = initialItemID
        self._focusedItemID = State(initialValue: initialItemID)
    }

    private var activeItems: [ClosetItem] { items.filter { !$0.isDeleted } }

    private var rows: [OutfitRow] {
        service.requiredRows(from: activeItems) + service.optionalRows(from: activeItems).filter { !$0.items.isEmpty }
    }

    private var draft: OutfitDraft { service.draft(from: rows, selections: selections) }

    private var selectedPieces: [(slot: OutfitSlot, item: ClosetItem)] {
        rows.compactMap { row in
            guard let index = selections[row.slot], row.items.indices.contains(index) else { return nil }
            return (slot: row.slot, item: row.items[index])
        }
    }

    private var availableItems: [ClosetItem] {
        let selectedIDs = Set(selectedPieces.map { $0.item.id })
        let order: [OutfitSlot] = [.accessory, .outerwear, .top, .bottom, .footwear, .onePiece]
        return order.flatMap { slot in
            rows.first { $0.slot == slot }?.items.filter { !selectedIDs.contains($0.id) } ?? []
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(selectedPieces.count) pieces")
                        .font(PyxisTypography.label)
                        .foregroundStyle(PyxisColors.secondaryText)
                        .padding(.top, 8)

                    composition
                        .frame(height: dynamicTypeSize.isAccessibilitySize ? 310 : 360)
                        .padding(.top, 4)

                    Rectangle()
                        .fill(PyxisColors.hairline)
                        .frame(height: 1)
                        .padding(.bottom, 18)

                    closetTray
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
        }
        .editorialCanvas()
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom, spacing: 0) { actionRail }
        .onAppear(perform: reconcileSelections)
        .onChange(of: items.map(\.id)) { _, _ in reconcileSelections() }
        .onChange(of: focusedItemID) { _, _ in reconcileSelections() }
        .sheet(isPresented: $isShowingAddFlow) {
            AddItemFlow { item in focusedItemID = item.id }
        }
        .sheet(isPresented: $isShowingTryOn) {
            AITryOnView(items: selectedPieces.map(\.item))
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .ultraLight))
                    .frame(width: 44, height: 48, alignment: .leading)
            }
            .accessibilityLabel("Back to fits")

            Spacer(minLength: 0)
            Text("Create fit")
                .font(PyxisTypography.body)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Color.clear.frame(width: 44, height: 48)
        }
        .foregroundStyle(PyxisColors.text)
        .padding(.horizontal, 24)
        .padding(.top, 4)
    }

    private var composition: some View {
        GeometryReader { geometry in
            if selectedPieces.isEmpty {
                Text("TAP A CLOSET ITEM TO START")
                    .font(PyxisTypography.editorialLabel)
                    .tracking(1.2)
                    .foregroundStyle(PyxisColors.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ZStack {
                    ForEach(selectedPieces, id: \.slot) { piece in
                        let layout = pieceLayout(for: piece.slot, in: geometry.size)
                        Button {
                            selections[piece.slot] = nil
                        } label: {
                            LocalImageView(url: imageURL(for: piece.item), revision: imageRevision(for: piece.item))
                                .frame(width: layout.width, height: layout.height)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .position(x: layout.x, y: layout.y)
                        .accessibilityLabel("Remove \(piece.item.displayName ?? piece.item.subtype.rawValue) from fit")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func pieceLayout(for slot: OutfitSlot, in size: CGSize) -> (width: CGFloat, height: CGFloat, x: CGFloat, y: CGFloat) {
        let values: (CGFloat, CGFloat, CGFloat, CGFloat)
        switch slot {
        case .top: values = (0.57, 0.59, 0.29, 0.34)
        case .bottom: values = (0.53, 0.82, 0.74, 0.53)
        case .footwear: values = (0.44, 0.28, 0.27, 0.84)
        case .onePiece: values = (0.57, 0.84, 0.53, 0.48)
        case .outerwear: values = (0.55, 0.62, 0.27, 0.33)
        case .accessory: values = (0.32, 0.32, 0.67, 0.84)
        }
        return (size.width * values.0, size.height * values.1,
                size.width * values.2, size.height * values.3)
    }

    private var closetTray: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("From your closet")
                    .font(PyxisTypography.editorialLabel)
                    .tracking(1.6)
                    .foregroundStyle(PyxisColors.text)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Text("Tap to add")
                    .font(PyxisTypography.editorialMicro)
                    .tracking(0.6)
                    .foregroundStyle(PyxisColors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            if availableItems.isEmpty {
                Button(activeItems.isEmpty ? "ADD YOUR FIRST ITEM" : "ADD ANOTHER ITEM") {
                    isShowingAddFlow = true
                }
                .buttonStyle(MinimalButtonStyle())
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(availableItems) { item in
                            Button { select(item) } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    LocalImageView(url: imageURL(for: item), revision: imageRevision(for: item))
                                        .frame(width: 120, height: 112)
                                    Text(item.displayName?.uppercased() ?? item.subtype.rawValue.uppercased())
                                        .font(PyxisTypography.editorialMicro)
                                        .tracking(0.8)
                                        .foregroundStyle(PyxisColors.secondaryText)
                                        .lineLimit(1)
                                }
                                .frame(width: 120, height: 145)
                                .padding(8)
                                .background(PyxisColors.surface, in: RoundedRectangle(cornerRadius: 8))
                                .overlay { RoundedRectangle(cornerRadius: 8).stroke(PyxisColors.hairline, lineWidth: 1) }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add \(item.displayName ?? item.subtype.rawValue) to fit")
                        }
                        Button { isShowingAddFlow = true } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 26, weight: .ultraLight))
                                Text("ADD ITEM")
                                    .font(PyxisTypography.editorialMicro)
                            }
                            .foregroundStyle(PyxisColors.secondaryText)
                            .frame(width: 120, height: 145)
                            .padding(8)
                            .background(PyxisColors.surface, in: RoundedRectangle(cornerRadius: 8))
                            .overlay { RoundedRectangle(cornerRadius: 8).stroke(PyxisColors.hairline, lineWidth: 1) }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add a new closet item")
                    }
                    .padding(.vertical, 2)
                }
                .scrollClipDisabled()
            }
        }
    }

    private var actionRail: some View {
        VStack(spacing: 8) {
            if let saveErrorMessage { InlineErrorMessage(message: saveErrorMessage) }
            if let saveRequirement {
                Text(saveRequirement)
                    .font(PyxisTypography.editorialMicro)
                    .foregroundStyle(PyxisColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    tryOnButton
                    saveFitButton
                }
            } else {
                HStack(spacing: 10) {
                    tryOnButton
                    saveFitButton
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(PyxisColors.background)
        .overlay(alignment: .top) { Rectangle().fill(PyxisColors.hairline).frame(height: 1) }
    }

    private var tryOnButton: some View {
        Button { isShowingTryOn = true } label: {
            HStack(spacing: 7) {
                Text("TRY ON")
                Text("PRO")
                    .font(PyxisTypography.editorialMicro)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .overlay { RoundedRectangle(cornerRadius: 5).stroke(PyxisColors.hairline, lineWidth: 1) }
            }
            .font(PyxisTypography.editorialLabel)
            .tracking(1.2)
            .foregroundStyle(PyxisColors.text)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(PyxisColors.field, in: RoundedRectangle(cornerRadius: 9))
            .overlay { RoundedRectangle(cornerRadius: 9).stroke(PyxisColors.hairline, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .disabled(selectedPieces.isEmpty)
        .accessibilityLabel("Try on selected fit, premium")
    }

    private var saveFitButton: some View {
        Button(action: saveFit) {
            Text("SAVE FIT")
                .font(PyxisTypography.editorialLabel)
                .tracking(1.5)
                .foregroundStyle(PyxisColors.background)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(PyxisColors.text, in: RoundedRectangle(cornerRadius: 9))
                .editorialGlow(cornerRadius: 9, strength: 1.3)
        }
        .buttonStyle(.plain)
        .disabled(!service.canSave(draft))
        .opacity(service.canSave(draft) ? 1 : 0.45)
        .accessibilityLabel("Save fit")
    }

    private var saveRequirement: String? {
        if draft.footwearItemID == nil { return "ADD SHOES TO SAVE THIS FIT" }
        if draft.onePieceItemID == nil && (draft.topItemID == nil || draft.bottomItemID == nil) {
            return "ADD A TOP AND BOTTOM, OR ONE PIECE"
        }
        return nil
    }

    private func imageURL(for item: ClosetItem) -> URL? {
        ImageStorageService.shared?.url(for: ClosetItemImageResolver.preferredDisplayPath(for: item))
    }

    private func imageRevision(for item: ClosetItem) -> Int {
        Int(item.effectiveDateUpdated.timeIntervalSince1970 * 1_000)
    }

    private func reconcileSelections() {
        let defaults = service.defaultSelections(for: rows)
        for row in rows {
            if let index = selections[row.slot], row.items.indices.contains(index) { continue }
            selections[row.slot] = defaults[row.slot]
        }
        if selections[.onePiece] != nil {
            selections[.top] = nil
            selections[.bottom] = nil
        }
        if let focusedItemID,
           let target = service.selectionTarget(for: focusedItemID, in: rows) {
            select(target.slot, index: target.index)
            self.focusedItemID = nil
        }
    }

    private func select(_ item: ClosetItem) {
        guard let target = service.selectionTarget(for: item.id, in: rows) else { return }
        select(target.slot, index: target.index)
    }

    private func select(_ slot: OutfitSlot, index: Int) {
        selections[slot] = index
        if slot == .onePiece {
            selections[.top] = nil
            selections[.bottom] = nil
        } else if slot == .top || slot == .bottom {
            selections[.onePiece] = nil
        }
        #if canImport(UIKit)
        if let row = rows.first(where: { $0.slot == slot }), row.items.indices.contains(index) {
            UIAccessibility.post(notification: .announcement,
                                 argument: "Selected \(row.items[index].itemCode) for \(slot.title.lowercased())")
        }
        #endif
    }

    private func saveFit() {
        guard service.canSave(draft) else { return }
        let outfit = service.outfit(from: draft)
        modelContext.insert(outfit)
        do {
            let payload = OnDeviceMemoryPayloadBuilder.outfitPayload(for: outfit, items: activeItems)
            try OnDeviceMemoryStore(context: modelContext).upsertMemory(
                kind: .outfit, subjectID: outfit.id, summary: payload.summary,
                embedding: payload.embedding, metadataTags: payload.metadataTags,
                updatedAt: outfit.dateUpdated, saveImmediately: false
            )
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = PersistenceErrorMessage.saveFailed(error)
        }
    }
}
