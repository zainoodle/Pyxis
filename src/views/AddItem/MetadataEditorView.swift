import SwiftUI

struct MetadataEditorView: View {
    @ObservedObject var viewModel: AddItemViewModel
    let closets: [Closet]
    @Binding var selectedClosetIDs: Set<UUID>

    var body: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.lg) {
            labeledField("Name", text: $viewModel.displayName)

            VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                EditorialMenuPicker(title: "Category", value: viewModel.category.rawValue.capitalized, selection: categoryBinding) {
                    ForEach(ClothingCategory.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                EditorialMenuPicker(title: "Type", value: viewModel.subtype.rawValue.capitalized, selection: $viewModel.subtype) {
                    ForEach(ClothingSubtype.compatibleSubtypes(for: viewModel.category)) { Text($0.rawValue.capitalized).tag($0) }
                }
                EditorialMenuPicker(title: "Color", value: viewModel.primaryColor.rawValue.capitalized, selection: $viewModel.primaryColor) {
                    ForEach(ClosetColor.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                if viewModel.classificationConfidence > 0 || viewModel.colorConfidence > 0 {
                    Text("Suggested from photo")
                        .font(PyxisTypography.proseCaption)
                        .foregroundStyle(PyxisColors.secondaryText)
                }
            }

            DisclosureGroup("More details") {
                VStack(alignment: .leading, spacing: PyxisSpacing.md) {
                    labeledField("Brand", text: $viewModel.brand)
                    labeledField("Size", text: $viewModel.size)
                    TagEntryField(text: $viewModel.tags)
                    labeledField("Notes", text: $viewModel.notes, axis: .vertical)
                    Toggle("Favorite", isOn: $viewModel.favorite)
                    if !closets.isEmpty {
                        DisclosureGroup("Closets") {
                            ForEach(closets) { closet in
                                Toggle(closet.displayName, isOn: closetBinding(closet))
                            }
                            .padding(.top, PyxisSpacing.sm)
                        }
                    }
                }
                .padding(.top, PyxisSpacing.md)
            }
            .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(PyxisTypography.control)
        .textFieldStyle(.plain)
        .tint(PyxisColors.text)
        .disclosureGroupStyle(EditorialDisclosureGroupStyle())
    }

    private func labeledField(_ title: String, text: Binding<String>, axis: Axis = .horizontal) -> some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.xs) {
            Text(title).font(PyxisTypography.label).foregroundStyle(PyxisColors.secondaryText)
            EditorialTextField(title, text: text, axis: axis)
                .frame(minHeight: 44)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(PyxisColors.hairline).frame(height: 1)
                }
                .accessibilityLabel(title)
        }
    }

    private var categoryBinding: Binding<ClothingCategory> {
        Binding(get: { viewModel.category }, set: { viewModel.updateCategory($0) })
    }

    private func closetBinding(_ closet: Closet) -> Binding<Bool> {
        Binding(get: { selectedClosetIDs.contains(closet.id) }, set: { selected in
            if selected { selectedClosetIDs.insert(closet.id) }
            else { selectedClosetIDs.remove(closet.id) }
        })
    }
}
