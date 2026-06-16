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
        .background(PyxisColors.background)
    }

    private var imagePanel: some View {
        VStack(spacing: PyxisSpacing.md) {
            LocalImageView(url: viewModel.displayURL(for: item))
                .frame(maxWidth: 330)
                .frame(height: 420)

            ItemCodeLabel(code: item.itemCode)

            Text(ClosetItemImageResolver.hasCutout(for: item) ? "READY" : "ORIGINAL ONLY")
                .font(PyxisTypography.label)
                .foregroundStyle(PyxisColors.secondaryText)

            Toggle("USE ORIGINAL", isOn: $viewModel.showOriginal)
                .font(PyxisTypography.label)

            Button(viewModel.isRetryingBackgroundRemoval ? "IMPROVING" : "IMPROVE CUTOUT") {
                Task {
                    await viewModel.retryBackgroundRemoval(for: item)
                    try? modelContext.save()
                }
            }
            .buttonStyle(MinimalButtonStyle())

            if let retryMessage = viewModel.retryMessage {
                Text(retryMessage.uppercased())
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.secondaryText)
            }
        }
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.md) {
            HStack {
                Text("DETAIL")
                    .font(PyxisTypography.title)
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
                VStack(alignment: .leading, spacing: PyxisSpacing.md) {
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
                        ForEach(ClothingSubtype.compatibleSubtypes(for: item.category)) { subtype in
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

            if !closets.isEmpty {
                DisclosureGroup("CLOSETS") {
                    VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                        ForEach(closets) { closet in
                            Toggle(closet.displayName.uppercased(), isOn: closetBinding(for: closet))
                        }
                    }
                    .padding(.top, PyxisSpacing.sm)
                }
            }

            Button("DELETE ITEM") {
                viewModel.deleteImages(for: item)
                closets.forEach { $0.remove(item) }
                modelContext.delete(item)
                try? modelContext.save()
                dismiss()
            }
            .buttonStyle(MinimalButtonStyle())
        }
        .font(PyxisTypography.body)
        .textFieldStyle(.plain)
    }

    private var utilityBlock: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
            Text("USED IN \(fitUsageCount) FIT\(fitUsageCount == 1 ? "" : "S")")
            Text("WORN \(item.wearCount) TIME\(item.wearCount == 1 ? "" : "S")")
            Text(lastWornText)
        }
        .font(PyxisTypography.body)
        .foregroundStyle(PyxisColors.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, PyxisSpacing.sm)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PyxisColors.hairline)
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
                try? modelContext.save()
            }
        )
    }

    private func optionalString(_ value: Binding<String?>) -> Binding<String> {
        Binding<String>(
            get: { value.wrappedValue ?? "" },
            set: { value.wrappedValue = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        )
    }
}
