import SwiftData
import SwiftUI

struct OutfitBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClosetItem.dateAdded, order: .reverse) private var items: [ClosetItem]
    @Query(sort: \Outfit.dateCreated, order: .reverse) private var outfits: [Outfit]
    @State private var selections: [OutfitSlot: Int] = [:]
    @State private var notes = ""
    @State private var isShowingAddFlow = false
    @State private var selectedItem: ClosetItem?
    @State private var selectedOutfit: Outfit?
    @State private var pendingAddSlot: OutfitSlot?
    @State private var focusedItemID: UUID?
    @State private var savedConfirmationID: UUID?

    private let service = OutfitBuilderService()
    private let initialItemID: UUID?

    init(initialItem: ClosetItem? = nil) {
        self.initialItemID = initialItem?.id
        self._focusedItemID = State(initialValue: initialItem?.id)
    }

    private var rows: [OutfitRow] {
        service.requiredRows(from: items) + service.optionalRows(from: items).filter { !$0.items.isEmpty }
    }

    private var requiredRows: [OutfitRow] {
        service.requiredRows(from: items)
    }

    private var draft: OutfitDraft {
        service.draft(from: rows, selections: selections)
    }

    var body: some View {
        VStack(spacing: ArchiveSpacing.lg) {
            header

            ClosetReadinessView(rows: requiredRows)

            ScrollView {
                VStack(spacing: ArchiveSpacing.lg) {
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
                                selectIndex: { selections[row.slot] = $0 },
                                advance: { offset in advance(row.slot, by: offset) },
                                openItem: { selectedItem = $0 }
                            )
                        }
                    }
                }
                .padding(.vertical, ArchiveSpacing.md)
            }

            SavedFitsStrip(outfits: outfits, items: items, recentOutfitID: savedConfirmationID) { outfit in
                selectedOutfit = outfit
            }

            saveRail
        }
        .padding(ArchiveSpacing.md)
        .background(ArchiveColors.background)
        .onAppear(perform: reconcileSelections)
        .onChange(of: initialItemID) { _, newValue in
            focusedItemID = newValue
            reconcileSelections()
        }
        .onChange(of: items.map(\.id)) { _, _ in
            reconcileSelections()
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
        .sheet(item: $selectedOutfit) { outfit in
            OutfitDetailView(outfit: outfit)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: ArchiveSpacing.xs) {
                Text("BUILD")
                    .font(ArchiveTypography.title)
                    .foregroundStyle(ArchiveColors.text)
                Text("STACK YOUR CLOSET")
                    .font(ArchiveTypography.label)
                    .foregroundStyle(ArchiveColors.secondaryText)
            }

            Spacer()

            Button("CLOSE") {
                dismiss()
            }
            .buttonStyle(.plain)
        }
    }

    private var saveRail: some View {
        VStack(spacing: ArchiveSpacing.sm) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: ArchiveSpacing.md) {
                    notesField
                    saveButton
                }

                VStack(spacing: ArchiveSpacing.sm) {
                    notesField
                    saveButton
                }
            }

            if savedConfirmationID != nil {
                Text("SAVED")
                    .font(ArchiveTypography.label)
                    .foregroundStyle(ArchiveColors.secondaryText)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    private var notesField: some View {
        TextField("FIT NOTES", text: $notes, axis: .vertical)
            .font(ArchiveTypography.body)
            .textFieldStyle(.plain)
            .padding(ArchiveSpacing.md)
            .background(ArchiveColors.field)
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

        if let focusedItemID,
           let target = service.selectionTarget(for: focusedItemID, in: rows) {
            withAnimation(.easeInOut(duration: 0.24)) {
                selections[target.slot] = target.index
            }
            self.focusedItemID = nil
        }
    }

    private func advance(_ slot: OutfitSlot, by offset: Int) {
        guard let row = rows.first(where: { $0.slot == slot }) else {
            return
        }
        selections[slot] = service.advancedIndex(
            from: selections[slot],
            offset: offset,
            itemCount: row.items.count
        )
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
        try? modelContext.save()
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
}

private struct ClosetReadinessView: View {
    let rows: [OutfitRow]

    private var missingSlots: [OutfitSlot] {
        rows.filter(\.items.isEmpty).map(\.slot)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ArchiveSpacing.xs) {
            Text(missingSlots.isEmpty ? "CLOSET READY" : "MISSING \(missingSlots.map(\.title).joined(separator: " / "))")
                .font(ArchiveTypography.label)
                .foregroundStyle(missingSlots.isEmpty ? ArchiveColors.text : ArchiveColors.secondaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ArchiveSpacing.md) {
                    ForEach(rows) { row in
                        Text("\(row.slot.title) \(row.items.count)")
                            .font(ArchiveTypography.label)
                            .foregroundStyle(row.items.isEmpty ? ArchiveColors.inactiveText : ArchiveColors.secondaryText)
                    }
                }
            }
        }
        .padding(.vertical, ArchiveSpacing.sm)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ArchiveColors.hairline)
                .frame(height: 1)
        }
    }
}

private struct MissingOutfitRow: View {
    let slot: OutfitSlot
    let addAction: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: ArchiveSpacing.xs) {
                Text(slot.title)
                    .font(ArchiveTypography.label)
                    .foregroundStyle(ArchiveColors.secondaryText)
                Text("NO \(slot.title)")
                    .font(ArchiveTypography.body)
                    .foregroundStyle(ArchiveColors.inactiveText)
            }

            Spacer()

            Button("ADD \(slot.title)") {
                addAction()
            }
            .buttonStyle(MinimalButtonStyle())
            .accessibilityLabel("Add \(slot.title.lowercased())")
        }
        .frame(height: 132)
        .padding(.horizontal, ArchiveSpacing.md)
        .background(ArchiveColors.field)
    }
}
