import SwiftUI

struct MetadataEditorView: View {
    @ObservedObject var viewModel: AddItemViewModel
    let closets: [Closet]
    @Binding var selectedClosetIDs: Set<UUID>

    var body: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.md) {
            editorSection("IDENTITY") {
                labeledField("DISPLAY NAME", text: $viewModel.displayName)
                labeledField("BRAND", text: $viewModel.brand)
                labeledField("SIZE", text: $viewModel.size)
            }

            editorSection("CLASSIFICATION") {
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

                if viewModel.classificationConfidence > 0 || viewModel.colorConfidence > 0 {
                    Text("AUTO-SUGGESTED · REVIEW BEFORE SAVING")
                        .font(PyxisTypography.label)
                        .foregroundStyle(PyxisColors.secondaryText)
                }
            }

            editorSection("ORGANIZATION") {
                labeledField("TAGS · COMMA SEPARATED", text: $viewModel.tags)
                Toggle("FAVORITE", isOn: $viewModel.favorite)

                if !closets.isEmpty {
                    DisclosureGroup("CLOSETS") {
                        VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                            ForEach(closets) { closet in
                                Toggle(closet.displayName.uppercased(), isOn: closetBinding(closet))
                            }
                        }
                        .padding(.top, PyxisSpacing.sm)
                    }
                }
            }

            editorSection("NOTES") {
                labeledField("NOTES", text: $viewModel.notes, axis: .vertical)
            }
        }
        .font(PyxisTypography.body)
        .textFieldStyle(.plain)
    }

    private func editorSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
            Text(title)
                .font(PyxisTypography.label)
                .foregroundStyle(PyxisColors.secondaryText)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PyxisSpacing.md)
        .background(PyxisColors.field)
    }

    private func labeledField(
        _ title: String,
        text: Binding<String>,
        axis: Axis = .horizontal
    ) -> some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.xs) {
            Text(title)
                .font(PyxisTypography.label)
                .foregroundStyle(PyxisColors.secondaryText)
            TextField("", text: text, axis: axis)
                .padding(.vertical, PyxisSpacing.xs)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(PyxisColors.hairline).frame(height: 1)
                }
                .accessibilityLabel(title.capitalized)
        }
    }

    private var categoryBinding: Binding<ClothingCategory> {
        Binding(
            get: { viewModel.category },
            set: { viewModel.updateCategory($0) }
        )
    }

    private func closetBinding(_ closet: Closet) -> Binding<Bool> {
        Binding(
            get: { selectedClosetIDs.contains(closet.id) },
            set: { isSelected in
                if isSelected {
                    selectedClosetIDs.insert(closet.id)
                } else {
                    selectedClosetIDs.remove(closet.id)
                }
            }
        )
    }
}
