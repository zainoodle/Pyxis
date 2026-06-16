import SwiftData
import SwiftUI

struct ItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Outfit.dateCreated, order: .reverse) private var outfits: [Outfit]
    @Bindable var item: ClosetItem
    @StateObject private var viewModel = ItemDetailViewModel()
    @State private var isEditingDetails = false
    let buildAction: ((ClosetItem) -> Void)?

    init(item: ClosetItem, buildAction: ((ClosetItem) -> Void)? = nil) {
        self.item = item
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
                HStack(alignment: .top, spacing: ArchiveSpacing.xl) {
                    imagePanel
                    detailPanel
                        .frame(maxWidth: 330)
                }

                VStack(spacing: ArchiveSpacing.lg) {
                    imagePanel
                    detailPanel
                }
            }
            .padding(ArchiveSpacing.md)
        }
        .background(ArchiveColors.background)
    }

    private var imagePanel: some View {
        VStack(spacing: ArchiveSpacing.md) {
            LocalImageView(url: viewModel.displayURL(for: item))
                .frame(maxWidth: 330)
                .frame(height: 420)

            ItemCodeLabel(code: item.itemCode)

            Text(ClosetItemImageResolver.hasCutout(for: item) ? "READY" : "ORIGINAL ONLY")
                .font(ArchiveTypography.label)
                .foregroundStyle(ArchiveColors.secondaryText)

            Toggle("USE ORIGINAL", isOn: $viewModel.showOriginal)
                .font(ArchiveTypography.label)

            Button(viewModel.isRetryingBackgroundRemoval ? "IMPROVING" : "IMPROVE CUTOUT") {
                Task {
                    await viewModel.retryBackgroundRemoval(for: item)
                    try? modelContext.save()
                }
            }
            .buttonStyle(MinimalButtonStyle())

            if let retryMessage = viewModel.retryMessage {
                Text(retryMessage.uppercased())
                    .font(ArchiveTypography.label)
                    .foregroundStyle(ArchiveColors.secondaryText)
            }
        }
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: ArchiveSpacing.md) {
            HStack {
                Text("DETAIL")
                    .font(ArchiveTypography.title)
                Spacer()
                Button("CLOSE") {
                    dismiss()
                }
                .buttonStyle(.plain)
            }

            utilityBlock

            if canBuildWithItem, let buildAction {
                Button("BUILD WITH THIS") {
                    buildAction(item)
                    dismiss()
                }
                .buttonStyle(MinimalButtonStyle())
            }

            DisclosureGroup("EDIT DETAILS", isExpanded: $isEditingDetails) {
                VStack(alignment: .leading, spacing: ArchiveSpacing.md) {
                    TextField("DISPLAY NAME", text: optionalString($item.displayName))
                    TextField("BRAND", text: optionalString($item.brand))
                    TextField("SIZE", text: optionalString($item.size))
                    TextField("NOTES", text: optionalString($item.notes), axis: .vertical)

                    Picker("CATEGORY", selection: categoryBinding) {
                        ForEach(ClothingCategory.allCases) { category in
                            Text(category.rawValue.uppercased()).tag(category)
                        }
                    }

                    Picker("SUBTYPE", selection: subtypeBinding) {
                        ForEach(ClothingSubtype.allCases) { subtype in
                            Text(subtype.rawValue.uppercased()).tag(subtype)
                        }
                    }

                    Picker("COLOR", selection: colorBinding) {
                        ForEach(ClosetColor.allCases) { color in
                            Text(color.rawValue.uppercased()).tag(color)
                        }
                    }

                    Toggle("FAVORITE", isOn: $item.favorite)

                    Stepper("WEAR COUNT \(item.wearCount)", value: $item.wearCount, in: 0...999)
                }
            }

            Button("DELETE ITEM") {
                viewModel.deleteImages(for: item)
                modelContext.delete(item)
                try? modelContext.save()
                dismiss()
            }
            .buttonStyle(MinimalButtonStyle())
        }
        .font(ArchiveTypography.body)
        .textFieldStyle(.plain)
    }

    private var utilityBlock: some View {
        VStack(alignment: .leading, spacing: ArchiveSpacing.sm) {
            Text("USED IN \(fitUsageCount) FIT\(fitUsageCount == 1 ? "" : "S")")
            Text("WORN \(item.wearCount) TIME\(item.wearCount == 1 ? "" : "S")")
            Text(lastWornText)
        }
        .font(ArchiveTypography.body)
        .foregroundStyle(ArchiveColors.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, ArchiveSpacing.sm)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ArchiveColors.hairline)
                .frame(height: 1)
        }
    }

    private var lastWornText: String {
        guard let lastWornDate = item.lastWornDate else {
            return "LAST WORN NEVER"
        }

        return "LAST WORN \(lastWornDate.formatted(date: .abbreviated, time: .omitted).uppercased())"
    }

    private var categoryBinding: Binding<ClothingCategory> {
        Binding(
            get: { item.category },
            set: { item.category = $0 }
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

    private func optionalString(_ value: Binding<String?>) -> Binding<String> {
        Binding<String>(
            get: { value.wrappedValue ?? "" },
            set: { value.wrappedValue = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        )
    }
}
