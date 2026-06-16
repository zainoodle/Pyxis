import SwiftUI

struct MetadataEditorView: View {
    @ObservedObject var viewModel: AddItemViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ArchiveSpacing.md) {
            TextField("DISPLAY NAME", text: $viewModel.displayName)
            TextField("BRAND", text: $viewModel.brand)
            TextField("SIZE", text: $viewModel.size)
            TextField("TAGS", text: $viewModel.tags)
            TextField("NOTES", text: $viewModel.notes, axis: .vertical)

            Picker("CATEGORY", selection: categoryBinding) {
                ForEach(ClothingCategory.allCases) { category in
                    Text(category.rawValue.uppercased()).tag(category)
                }
            }

            Picker("SUBTYPE", selection: $viewModel.subtype) {
                ForEach(ClothingSubtype.compatibleSubtypes(for: viewModel.category)) { subtype in
                    Text(subtype.rawValue.uppercased()).tag(subtype)
                }
            }

            Picker("COLOR", selection: $viewModel.primaryColor) {
                ForEach(ClosetColor.allCases) { color in
                    Text(color.rawValue.uppercased()).tag(color)
                }
            }

            Toggle("FAVORITE", isOn: $viewModel.favorite)
        }
        .font(ArchiveTypography.body)
        .textFieldStyle(.plain)
    }

    private var categoryBinding: Binding<ClothingCategory> {
        Binding(
            get: { viewModel.category },
            set: { viewModel.updateCategory($0) }
        )
    }
}
