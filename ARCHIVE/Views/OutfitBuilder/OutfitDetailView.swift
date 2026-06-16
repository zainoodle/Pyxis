import SwiftData
import SwiftUI

struct OutfitDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClosetItem.dateAdded, order: .reverse) private var items: [ClosetItem]
    @Bindable var outfit: Outfit
    @State private var refreshID = UUID()

    private var selectedItems: [ClosetItem] {
        outfit.itemIDs.compactMap { itemID in
            items.first { $0.id == itemID }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ArchiveSpacing.lg) {
            HStack {
                Text(outfit.name?.uppercased() ?? "FIT DETAIL")
                    .font(ArchiveTypography.title)

                Spacer()

                Button("WORN") {
                    markWornToday()
                }
                .buttonStyle(MinimalButtonStyle())

                Button("CLOSE") {
                    try? modelContext.save()
                    dismiss()
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: ArchiveSpacing.lg) {
                    VStack(spacing: ArchiveSpacing.sm) {
                        ForEach(selectedItems) { item in
                            HStack(spacing: ArchiveSpacing.md) {
                                SavedFitItemImage(item: item)
                                    .frame(width: 58, height: 84)

                                VStack(alignment: .leading, spacing: ArchiveSpacing.xs) {
                                    ItemCodeLabel(code: item.itemCode)
                                    Text(item.displayName?.uppercased() ?? item.subtype.rawValue.uppercased())
                                        .font(ArchiveTypography.body)
                                        .foregroundStyle(ArchiveColors.secondaryText)
                                        .lineLimit(1)
                                    Text("WORN \(item.wearCount)")
                                        .font(ArchiveTypography.label)
                                        .foregroundStyle(ArchiveColors.inactiveText)
                                }

                                Spacer()
                            }
                        }
                    }

                    TextField("FIT NAME", text: optionalString($outfit.name))
                        .textFieldStyle(.plain)
                        .font(ArchiveTypography.body)
                        .padding(ArchiveSpacing.md)
                        .background(ArchiveColors.field)

                    TextField("NOTES", text: optionalString($outfit.notes), axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(ArchiveTypography.body)
                        .padding(ArchiveSpacing.md)
                        .background(ArchiveColors.field)

                    Toggle("FAVORITE", isOn: $outfit.favorite)
                        .font(ArchiveTypography.body)

                    HStack(spacing: ArchiveSpacing.md) {
                        Button("MARK WORN TODAY") {
                            markWornToday()
                        }
                        .buttonStyle(MinimalButtonStyle())

                        Text("FIT WORN \(outfit.wearCount)")
                            .font(ArchiveTypography.label)
                            .foregroundStyle(ArchiveColors.secondaryText)
                    }
                }
            }
        }
        .padding(ArchiveSpacing.md)
        .background(ArchiveColors.background)
        .id(refreshID)
    }

    private func markWornToday() {
        OutfitWearService().markWorn(outfit: outfit, items: items)
        try? modelContext.save()
        refreshID = UUID()
    }

    private func optionalString(_ value: Binding<String?>) -> Binding<String> {
        Binding<String>(
            get: { value.wrappedValue ?? "" },
            set: { value.wrappedValue = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        )
    }
}
