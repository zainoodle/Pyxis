import SwiftData
import SwiftUI

struct ClosetManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Closet.dateUpdated, order: .reverse) private var closets: [Closet]
    @Query(sort: \ClosetItem.dateAdded, order: .reverse) private var items: [ClosetItem]
    @Binding var selectedClosetID: UUID?
    @State private var newClosetName = ""
    @State private var message: String?
    @State private var saveErrorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PyxisSpacing.lg) {
                HStack {
                    Text("CLOSETS")
                        .font(PyxisTypography.title)
                    Spacer()
                    Button("CLOSE") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                }

                createRow

                if let message {
                    Text(message.uppercased())
                        .font(PyxisTypography.label)
                        .foregroundStyle(PyxisColors.secondaryText)
                }

                if let saveErrorMessage {
                    InlineErrorMessage(message: saveErrorMessage)
                }

                if closets.isEmpty {
                    Text("NO CUSTOM CLOSETS")
                        .font(PyxisTypography.body)
                        .foregroundStyle(PyxisColors.inactiveText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, PyxisSpacing.xl)
                } else {
                    VStack(spacing: PyxisSpacing.md) {
                        ForEach(closets) { closet in
                            ClosetEditorRow(
                                closet: closet,
                                items: items,
                                selectedClosetID: $selectedClosetID,
                                saveErrorMessage: $saveErrorMessage
                            ) {
                                delete(closet)
                            }
                        }
                    }
                }
            }
            .padding(PyxisSpacing.md)
        }
        .background(PyxisColors.background)
    }

    private var createRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: PyxisSpacing.md) {
                nameField
                createButton
            }

            VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                nameField
                createButton
            }
        }
    }

    private var nameField: some View {
        TextField("NEW CLOSET NAME", text: $newClosetName)
            .textFieldStyle(.plain)
            .font(PyxisTypography.body)
            .padding(.horizontal, PyxisSpacing.sm)
            .padding(.vertical, PyxisSpacing.sm)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PyxisColors.field)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(PyxisColors.hairline, lineWidth: 1)
            }
    }

    private var createButton: some View {
        Button("CREATE") {
            create()
        }
        .buttonStyle(MinimalButtonStyle())
        .disabled(Closet.cleanedName(newClosetName) == nil)
    }

    private func create() {
        guard let cleanedName = Closet.cleanedName(newClosetName) else {
            return
        }
        if let existing = closets.first(where: { $0.displayName.caseInsensitiveCompare(cleanedName) == .orderedSame }) {
            selectedClosetID = existing.id
            message = "\(existing.displayName) selected"
            newClosetName = ""
            return
        }

        let closet = Closet(name: cleanedName)
        modelContext.insert(closet)
        selectedClosetID = closet.id
        newClosetName = ""
        do {
            try modelContext.save()
            message = "\(closet.displayName) created"
            saveErrorMessage = nil
        } catch {
            selectedClosetID = nil
            modelContext.rollback()
            saveErrorMessage = PersistenceErrorMessage.saveFailed(error)
        }
    }

    private func delete(_ closet: Closet) {
        let previousSelection = selectedClosetID
        let deletedName = closet.displayName
        if selectedClosetID == closet.id {
            selectedClosetID = nil
        }
        modelContext.delete(closet)
        do {
            try modelContext.save()
            message = "\(deletedName) deleted"
            saveErrorMessage = nil
        } catch {
            selectedClosetID = previousSelection
            modelContext.rollback()
            saveErrorMessage = PersistenceErrorMessage.saveFailed(error)
        }
    }
}

private struct ClosetEditorRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var closet: Closet
    let items: [ClosetItem]
    @Binding var selectedClosetID: UUID?
    @Binding var saveErrorMessage: String?
    let deleteAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.md) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: PyxisSpacing.md) {
                    editableName
                    itemCount
                    rowActions
                }

                VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                    HStack {
                        editableName
                        itemCount
                    }
                    rowActions
                }
            }

            if items.isEmpty {
                Text("NO CLOTHING ITEMS")
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.inactiveText)
            } else {
                DisclosureGroup("ITEMS") {
                    VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                        ForEach(items) { item in
                            Toggle(itemTitle(for: item), isOn: membershipBinding(for: item))
                        }
                    }
                    .padding(.top, PyxisSpacing.sm)
                }
                .font(PyxisTypography.body)
            }
        }
        .padding(PyxisSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PyxisColors.field)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PyxisColors.hairline, lineWidth: 1)
        }
    }

    private var editableName: some View {
        TextField("CLOSET NAME", text: nameBinding)
            .textFieldStyle(.plain)
            .font(PyxisTypography.body)
    }

    private var itemCount: some View {
        Text("\(closet.itemCount)")
            .font(PyxisTypography.code)
            .foregroundStyle(PyxisColors.secondaryText)
            .accessibilityLabel("\(closet.itemCount) items")
    }

    private var rowActions: some View {
        HStack(spacing: PyxisSpacing.sm) {
            Button(selectedClosetID == closet.id ? "VIEWING" : "VIEW") {
                selectedClosetID = closet.id
            }
            .buttonStyle(MinimalButtonStyle())

            Button("DELETE") {
                deleteAction()
            }
            .buttonStyle(MinimalButtonStyle())
        }
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { closet.name },
            set: { newName in
                closet.rename(newName)
                saveChanges()
            }
        )
    }

    private func membershipBinding(for item: ClosetItem) -> Binding<Bool> {
        Binding(
            get: { closet.contains(item) },
            set: { isIncluded in
                closet.setContains(isIncluded, item: item)
                saveChanges()
            }
        )
    }

    private func saveChanges() {
        do {
            try modelContext.save()
            saveErrorMessage = nil
        } catch {
            saveErrorMessage = PersistenceErrorMessage.saveFailed(error)
        }
    }

    private func itemTitle(for item: ClosetItem) -> String {
        let name = item.displayName ?? item.subtype.rawValue
        return "\(item.itemCode) \(name)".uppercased()
    }
}
