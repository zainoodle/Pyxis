import SwiftData
import SwiftUI

struct ItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: ClosetItem
    @StateObject private var viewModel = ItemDetailViewModel()

    var body: some View {
        HStack(alignment: .top, spacing: ArchiveSpacing.xl) {
            VStack(spacing: ArchiveSpacing.md) {
                LocalImageView(url: viewModel.displayURL(for: item))
                    .frame(width: 330, height: 420)

                ItemCodeLabel(code: item.itemCode)

                Toggle("ORIGINAL", isOn: $viewModel.showOriginal)
                    .font(ArchiveTypography.label)

                Button(viewModel.isRetryingBackgroundRemoval ? "RETRYING" : "RETRY BACKGROUND") {
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
            .frame(width: 330)
        }
        .padding(ArchiveSpacing.xl)
        .background(ArchiveColors.background)
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
