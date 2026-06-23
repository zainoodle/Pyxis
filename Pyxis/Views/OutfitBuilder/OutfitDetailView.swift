import SwiftData
import SwiftUI

struct OutfitDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClosetItem.dateAdded, order: .reverse) private var items: [ClosetItem]
    @Bindable var outfit: Outfit
    @State private var refreshID = UUID()
    @State private var saveErrorMessage: String?

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
                }
            }
        }
        .padding(PyxisSpacing.md)
        .background(PyxisColors.background)
        .id(refreshID)
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
            try upsertOutfitMemory()
            try modelContext.save()
            saveErrorMessage = nil
            dismiss()
        } catch {
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
