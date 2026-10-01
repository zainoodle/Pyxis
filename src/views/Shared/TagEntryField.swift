import SwiftUI

struct TagEntryField: View {
    @Binding private var text: String
    @State private var draft: TagEntryDraft

    init(text: Binding<String>) {
        _text = text
        _draft = State(initialValue: TagEntryDraft(text: text.wrappedValue))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
            Text("Tags").font(PyxisTypography.label).foregroundStyle(PyxisColors.secondaryText)
            if !draft.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PyxisSpacing.sm) {
                        ForEach(Array(draft.tags.enumerated()), id: \.offset) { index, tag in
                            Button {
                                draft.remove(at: index)
                                text = draft.text
                            } label: {
                                HStack(spacing: 8) {
                                    Text(tag)
                                    Image(systemName: "xmark").font(.caption)
                                }
                                .font(PyxisTypography.control)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 44)
                                .background(PyxisColors.field, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove tag \(tag)")
                        }
                    }
                }
            }
            HStack(spacing: PyxisSpacing.sm) {
                EditorialTextField("New tag", placeholder: "Add tag", text: Binding(
                    get: { draft.input },
                    set: { value in draft.updateInput(value); text = draft.text }
                ))
                .font(PyxisTypography.control)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { commitInput() }
                .accessibilityIdentifier("piece.tags")
                Button(action: commitInput) {
                    Image(systemName: "plus").frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(draft.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Add tags")
                .accessibilityIdentifier("piece.addTags")
            }
        }
    }

    private func commitInput() { draft.commitInput(); text = draft.text }
}
