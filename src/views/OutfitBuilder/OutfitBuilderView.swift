import SwiftData
import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct OutfitBuilderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \ClosetItem.dateAdded, order: .reverse) private var items: [ClosetItem]
    @State private var selections: [OutfitSlot: Int] = [:]
    @State private var notes = ""
    @State private var isShowingAddFlow = false
    @State private var selectedItem: ClosetItem?
    @State private var pendingAddSlot: OutfitSlot?
    @State private var focusedItemID: UUID?
    @State private var savedConfirmationID: UUID?
    @State private var saveErrorMessage: String?
    @State private var isShowingAITryOn = false
    @State private var stagePhotoItem: PhotosPickerItem?
    @State private var stagePhoto: UIImage?
    @State private var stageSlot: OutfitSlot = .top

    private let service = OutfitBuilderService()
    private let initialItemID: UUID?

    init(initialItemID: UUID? = nil) {
        self.initialItemID = initialItemID
        self._focusedItemID = State(initialValue: initialItemID)
    }

    private var rows: [OutfitRow] {
        service.requiredRows(from: items) + service.optionalRows(from: items).filter { !$0.items.isEmpty }
    }

    private var draft: OutfitDraft {
        service.draft(from: rows, selections: selections)
    }

    private var selectedPieces: [(slot: OutfitSlot, item: ClosetItem)] {
        rows.compactMap { row in
            guard let selectedIndex = selections[row.slot], row.items.indices.contains(selectedIndex) else {
                return nil
            }
            return (slot: row.slot, item: row.items[selectedIndex])
        }
    }

    var body: some View {
        VStack(spacing: colorScheme == .dark ? PyxisSpacing.md : PyxisSpacing.lg) {
            PrimaryPageHeader(title: "BUILD")

            if items.isEmpty {
                VStack(spacing: PyxisSpacing.md) {
                    Text("YOUR CLOSET IS EMPTY")
                        .font(PyxisTypography.body)
                        .foregroundStyle(PyxisColors.secondaryText)

                    Button("ADD YOUR FIRST ITEM") {
                        isShowingAddFlow = true
                    }
                    .buttonStyle(MinimalButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, PyxisSpacing.xl)
            } else {
                ScrollView {
                    VStack(spacing: colorScheme == .dark ? PyxisSpacing.md : PyxisSpacing.lg) {
                        ClosetReadinessView(rows: rows, draft: draft)

                        OutfitStageView(
                            rows: rows,
                            selections: selections,
                            selectedPieces: selectedPieces,
                            photo: stagePhoto,
                            photoItem: $stagePhotoItem,
                            activeSlot: $stageSlot,
                            select: select
                        )

                        Button("OUTFIT ON YOU") { isShowingAITryOn = true }
                            .buttonStyle(MinimalButtonStyle())
                            .accessibilityLabel("Try clothing on your photo")

                        ForEach(rows) { row in
                            if row.items.isEmpty {
                                MissingOutfitRow(slot: row.slot) {
                                    pendingAddSlot = row.slot
                                    isShowingAddFlow = true
                                }
                            } else {
                                OutfitCarouselRow(
                                    row: row,
                                    selectedIndex: selections[row.slot],
                                    selectIndex: { select(row.slot, index: $0) },
                                    advance: { offset in advance(row.slot, by: offset) },
                                    openItem: { selectedItem = $0 }
                                )
                            }
                        }

                        if dynamicTypeSize.isAccessibilitySize {
                            notesField
                        }
                    }
                    .padding(.vertical, PyxisSpacing.md)
                }
            }
        }
        .padding(.horizontal, PyxisSpacing.md)
        .padding(.bottom, PyxisSpacing.md)
        .background(PyxisColors.background)
        .safeAreaInset(edge: .bottom) {
            if !items.isEmpty {
                saveRail
                    .padding(.horizontal, PyxisSpacing.md)
                    .padding(.top, PyxisSpacing.md)
                    .padding(.bottom, colorScheme == .dark ? 32 : PyxisSpacing.md)
                    .background(PyxisColors.background)
                    .overlay(alignment: .top) {
                        Rectangle().fill(PyxisColors.hairline).frame(height: 1)
                    }
            }
        }
        .onAppear(perform: reconcileSelections)
        .onChange(of: initialItemID) { _, newValue in
            focusedItemID = newValue
            reconcileSelections()
        }
        .onChange(of: items.map(\.id)) { _, _ in
            reconcileSelections()
        }
        .onChange(of: stagePhotoItem) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                stagePhoto = image
            }
        }
        .sheet(isPresented: $isShowingAddFlow) {
            AddItemFlow(
                initialCategory: pendingAddSlot?.category,
                initialSubtype: pendingAddSlot.map(service.defaultSubtype(for:)),
                onSave: { item in
                    focusedItemID = item.id
                }
            )
        }
        .sheet(item: $selectedItem) { item in
            ItemDetailView(item: item)
        }
        .sheet(isPresented: $isShowingAITryOn) {
            AITryOnView(items: selectedPieces.map(\.item))
        }
    }

    private var saveRail: some View {
        VStack(spacing: PyxisSpacing.sm) {
            if dynamicTypeSize.isAccessibilitySize {
                saveButton
                    .frame(maxWidth: .infinity)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: PyxisSpacing.md) {
                        notesField
                        saveButton
                    }

                    VStack(spacing: PyxisSpacing.sm) {
                        notesField
                        saveButton
                    }
                }
            }

            if savedConfirmationID != nil {
                Text("SAVED")
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.secondaryText)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if let saveErrorMessage {
                InlineErrorMessage(message: saveErrorMessage)
            }

            if let saveRequirement {
                Text(saveRequirement)
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.secondaryText)
                    .accessibilityLabel(saveRequirement.capitalized)
            }
        }
    }

    private var saveRequirement: String? {
        if draft.footwearItemID == nil {
            return "ADD FOOTWEAR"
        }
        if draft.onePieceItemID == nil && (draft.topItemID == nil || draft.bottomItemID == nil) {
            return "SELECT A TOP AND BOTTOM, OR SELECT A ONE-PIECE"
        }
        return nil
    }

    private var notesField: some View {
        TextField("FIT NOTES", text: $notes, axis: .vertical)
            .font(PyxisTypography.body)
            .textFieldStyle(.plain)
            .padding(PyxisSpacing.md)
            .background(PyxisColors.field)
    }

    private var saveButton: some View {
        Button("SAVE FIT") {
            saveFit()
        }
        .buttonStyle(MinimalButtonStyle())
        .disabled(!service.canSave(draft))
        .opacity(service.canSave(draft) ? 1 : 0.35)
        .accessibilityLabel("Save fit")
    }

    private func reconcileSelections() {
        let defaults = service.defaultSelections(for: rows)
        if !rows.contains(where: { $0.slot == stageSlot && !$0.items.isEmpty }),
           let firstAvailable = rows.first(where: { !$0.items.isEmpty }) {
            stageSlot = firstAvailable.slot
        }
        for row in rows {
            guard !row.items.isEmpty else {
                selections[row.slot] = nil
                continue
            }

            if let index = selections[row.slot], row.items.indices.contains(index) {
                continue
            }

            selections[row.slot] = defaults[row.slot]
        }

        if selections[.onePiece] != nil {
            selections[.top] = nil
            selections[.bottom] = nil
        }

        if let focusedItemID,
           let target = service.selectionTarget(for: focusedItemID, in: rows) {
            withAnimation(.easeInOut(duration: 0.24)) {
                select(target.slot, index: target.index)
            }
            self.focusedItemID = nil
        }
    }

    private func advance(_ slot: OutfitSlot, by offset: Int) {
        guard let row = rows.first(where: { $0.slot == slot }) else {
            return
        }
        guard let index = service.advancedIndex(
            from: selections[slot],
            offset: offset,
            itemCount: row.items.count
        ) else { return }
        select(slot, index: index)
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
            UIAccessibility.post(
                notification: .announcement,
                argument: "Selected \(row.items[index].itemCode) for \(slot.title.lowercased())"
            )
        }
        #endif
    }

    private func saveFit() {
        guard service.canSave(draft) else {
            return
        }

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let outfit = service.outfit(
            from: draft,
            name: nil,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
        )
        modelContext.insert(outfit)
        do {
            try upsertMemory(for: outfit)
            try modelContext.save()
            saveErrorMessage = nil
        } catch {
            modelContext.rollback()
            saveErrorMessage = PersistenceErrorMessage.saveFailed(error)
            return
        }
        notes = ""
        withAnimation(.easeOut(duration: 0.24)) {
            savedConfirmationID = outfit.id
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            await MainActor.run {
                guard savedConfirmationID == outfit.id else {
                    return
                }
                withAnimation(.easeOut(duration: 0.2)) {
                    savedConfirmationID = nil
                }
            }
        }
    }

    private func upsertMemory(for outfit: Outfit) throws {
        let payload = OnDeviceMemoryPayloadBuilder.outfitPayload(for: outfit, items: items)
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
}

private struct OutfitStageView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let rows: [OutfitRow]
    let selections: [OutfitSlot: Int]
    let selectedPieces: [(slot: OutfitSlot, item: ClosetItem)]
    let photo: UIImage?
    @Binding var photoItem: PhotosPickerItem?
    @Binding var activeSlot: OutfitSlot
    let select: (OutfitSlot, Int) -> Void

    private var activeRow: OutfitRow? { rows.first { $0.slot == activeSlot && !$0.items.isEmpty } }
    private var activeIndex: Int { selections[activeSlot] ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.md) {
            HStack {
                Text("THE STAGE")
                    .font(colorScheme == .dark ? PyxisTypography.editorialLabel : PyxisTypography.label)
                    .tracking(colorScheme == .dark ? 1.6 : 0)
                    .foregroundStyle(PyxisColors.text)

                Spacer()

                Text("\(selectedPieces.count) PIECES")
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.inactiveText)
            }

            GeometryReader { geometry in
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(colorScheme == .dark ? PyxisColors.surface : PyxisColors.field)
                        .overlay {
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(PyxisColors.hairline.opacity(colorScheme == .dark ? 0.8 : 0), lineWidth: 1)
                        }
                    Circle()
                        .stroke(PyxisColors.hairline.opacity(0.28), lineWidth: 1)
                        .frame(width: 280, height: 280)
                        .offset(y: -4)
                    Circle()
                        .stroke(PyxisColors.hairline.opacity(0.18), lineWidth: 1)
                        .frame(width: 210, height: 210)
                        .offset(y: -4)

                    if let row = activeRow {
                        ForEach(Array(row.items.enumerated()), id: \.element.id) { index, item in
                            let distance = wrappedDistance(index, from: activeIndex, count: row.items.count)
                            if abs(distance) <= 2 {
                                Button {
                                    withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8)) {
                                        select(row.slot, index)
                                    }
                                } label: {
                                    LocalImageView(url: imageURL(for: item), revision: imageRevision(for: item))
                                        .frame(width: 80, height: 96)
                                        .padding(7)
                                        .brightness(colorScheme == .dark ? 0.10 : 0)
                                        .background(colorScheme == .dark ? PyxisColors.field : Color(red: 0.94, green: 0.93, blue: 0.90), in: RoundedRectangle(cornerRadius: 14))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(index == activeIndex ? PyxisColors.text : PyxisColors.hairline.opacity(0.5), lineWidth: 1)
                                        }
                                        .shadow(color: colorScheme == .dark ? .white.opacity(0.08) : PyxisColors.shadow, radius: 12, y: 7)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Select \(item.itemCode) for \(row.slot.title.lowercased())")
                                .offset(x: CGFloat(distance) * geometry.size.width * 0.28,
                                        y: CGFloat(abs(distance)) * 30 - 45)
                                .scaleEffect(distance == 0 ? 1.12 : 0.82)
                                .rotation3DEffect(.degrees(Double(distance) * -24), axis: (x: 0, y: 1, z: 0))
                                .zIndex(distance == 0 ? 2 : 0)
                            }
                        }
                    }

                    Ellipse()
                        .fill(PyxisColors.text.opacity(0.08))
                        .frame(width: 230, height: 38)
                        .offset(y: 127)
                    Ellipse()
                        .stroke(PyxisColors.hairline.opacity(0.65), lineWidth: 1)
                        .frame(width: 240, height: 44)
                        .offset(y: 129)

                    if let photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 146, height: 238)
                            .clipShape(RoundedRectangle(cornerRadius: 76))
                            .overlay {
                                RoundedRectangle(cornerRadius: 76)
                                    .stroke(PyxisColors.background.opacity(0.8), lineWidth: 4)
                            }
                            .offset(y: 5)
                            .zIndex(3)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 112, weight: .ultraLight))
                            .foregroundStyle(PyxisColors.secondaryText)
                            .frame(width: 146, height: 222)
                            .background(PyxisColors.background.opacity(0.82), in: RoundedRectangle(cornerRadius: 76))
                            .offset(y: 5)
                            .zIndex(3)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 30).onEnded { value in
                    guard let row = activeRow, !row.items.isEmpty else { return }
                    let step = value.translation.width < 0 ? 1 : -1
                    let next = (activeIndex + step + row.items.count) % row.items.count
                    withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8)) {
                        select(row.slot, next)
                    }
                })
            }
            .frame(height: 310)

            HStack(spacing: PyxisSpacing.sm) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(photo == nil ? "ADD YOUR PHOTO" : "CHANGE PHOTO", systemImage: "person.crop.square")
                        .font(PyxisTypography.label)
                }
                .buttonStyle(MinimalButtonStyle())
                Spacer()
                Text("SWIPE TO SPIN")
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.secondaryText)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PyxisSpacing.sm) {
                    ForEach(rows.filter { !$0.items.isEmpty }) { row in
                        Button(row.slot.title) { activeSlot = row.slot }
                            .font(PyxisTypography.label)
                            .foregroundStyle(activeSlot == row.slot ? PyxisColors.background : PyxisColors.text)
                            .padding(.horizontal, PyxisSpacing.md)
                            .frame(minHeight: 40)
                            .background {
                                if colorScheme == .dark {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(activeSlot == row.slot ? PyxisColors.text : PyxisColors.field)
                                } else {
                                    Capsule().fill(activeSlot == row.slot ? PyxisColors.text : PyxisColors.field)
                                }
                            }
                    }
                }
            }
            Text("PHOTO STAYS ON THIS DEVICE. USE OUTFIT ON YOU FOR A TRY-ON PREVIEW.")
                .font(PyxisTypography.label)
                .foregroundStyle(PyxisColors.secondaryText)
        }
        .animation(.snappy(duration: 0.28), value: selectedPieces.map { $0.item.id })
    }

    private func wrappedDistance(_ index: Int, from selected: Int, count: Int) -> Int {
        let forward = (index - selected + count) % count
        return forward <= count / 2 ? forward : forward - count
    }

    private func imageURL(for item: ClosetItem) -> URL? {
        guard let storage = ImageStorageService.shared else {
            return nil
        }
        return storage.url(for: ClosetItemImageResolver.preferredDisplayPath(for: item))
    }

    private func imageRevision(for item: ClosetItem) -> Int {
        Int(item.effectiveDateUpdated.timeIntervalSince1970 * 1_000)
    }
}

private struct ClosetReadinessView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let rows: [OutfitRow]
    let draft: OutfitDraft

    private var missingSlots: [OutfitSlot] {
        var missing: [OutfitSlot] = []
        if draft.onePieceItemID == nil && (draft.topItemID == nil || draft.bottomItemID == nil) {
            missing.append(draft.topItemID == nil ? .top : .bottom)
        }
        if draft.footwearItemID == nil { missing.append(.footwear) }
        return missing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.xs) {
            Text(missingSlots.isEmpty ? "CLOSET READY" : "MISSING \(missingSlots.map(\.title).joined(separator: " / "))")
                .font(PyxisTypography.label)
                .foregroundStyle(missingSlots.isEmpty ? PyxisColors.text : PyxisColors.secondaryText)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: PyxisSpacing.sm) {
                    ForEach(rows) { row in
                        HStack(alignment: .firstTextBaseline) {
                            Text(row.slot.title)
                            Spacer(minLength: PyxisSpacing.sm)
                            Text("\(row.items.count)")
                        }
                        .font(PyxisTypography.label)
                        .foregroundStyle(row.items.isEmpty ? PyxisColors.inactiveText : PyxisColors.secondaryText)
                    }
                }
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 110, maximum: 180), alignment: .leading)],
                    alignment: .leading,
                    spacing: PyxisSpacing.xs
                ) {
                    ForEach(rows) { row in
                        Text("\(row.slot.title) \(row.items.count)")
                            .font(PyxisTypography.label)
                            .foregroundStyle(row.items.isEmpty ? PyxisColors.inactiveText : PyxisColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.vertical, PyxisSpacing.sm)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PyxisColors.hairline)
                .frame(height: 1)
        }
    }
}

private struct MissingOutfitRow: View {
    let slot: OutfitSlot
    let addAction: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: PyxisSpacing.xs) {
                Text(slot.title)
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.secondaryText)
                Text("NO \(slot.title)")
                    .font(PyxisTypography.body)
                    .foregroundStyle(PyxisColors.inactiveText)
            }

            Spacer()

            Button("ADD \(slot.title)") {
                addAction()
            }
            .buttonStyle(MinimalButtonStyle())
            .accessibilityLabel("Add \(slot.title.lowercased())")
        }
        .frame(height: 132)
        .padding(.horizontal, PyxisSpacing.md)
        .background(PyxisColors.field)
    }
}
