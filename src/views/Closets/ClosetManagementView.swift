import SwiftData
import SwiftUI
import UIKit

struct ClosetManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Closet.dateUpdated, order: .reverse) private var closets: [Closet]
    @Query(sort: \ClosetItem.dateAdded, order: .reverse) private var items: [ClosetItem]
    @State private var newClosetName = ""
    @State private var message: String?
    @State private var saveErrorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PyxisSpacing.lg) {
                createRow

                if let message {
                    Text(message)
                        .font(PyxisTypography.label)
                        .foregroundStyle(PyxisColors.secondaryText)
                }

                if let saveErrorMessage {
                    InlineErrorMessage(message: saveErrorMessage)
                }

                if closets.isEmpty {
                    Text("Create a closet to group your pieces.")
                        .font(PyxisTypography.body)
                        .foregroundStyle(PyxisColors.inactiveText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, PyxisSpacing.xl)
                } else {
                    VStack(spacing: PyxisSpacing.md) {
                        ForEach(closets) { closet in
                            ClosetEditorRow(
                                closet: closet,
                                items: items.filter { !$0.isDeleted },
                                saveErrorMessage: $saveErrorMessage
                            ) {
                                delete(closet)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .editorialCanvas()
        .editorialNavigationTitle("Closets")
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .keyboard) { Button("Done", action: dismissKeyboard) }
        }
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
        EditorialTextField("Closet name", placeholder: "Closet name", text: $newClosetName)
            .accessibilityLabel("Closet name")
            .textFieldStyle(.plain)
            .font(PyxisTypography.body)
            .padding(.horizontal, PyxisSpacing.sm)
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
        Button("Create") {
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
            message = "A closet named \(existing.displayName) already exists."
            dismissKeyboard()
            return
        }

        let closet = Closet(name: cleanedName)
        modelContext.insert(closet)
        do {
            try modelContext.save()
            newClosetName = ""
            dismissKeyboard()
            message = "\(closet.displayName) created"
            saveErrorMessage = nil
        } catch {
            modelContext.rollback()
            saveErrorMessage = PersistenceErrorMessage.saveFailed(error)
        }
    }

    private func delete(_ closet: Closet) {
        let deletedName = closet.displayName
        modelContext.delete(closet)
        do {
            try modelContext.save()
            message = "\(deletedName) deleted"
            saveErrorMessage = nil
        } catch {
            modelContext.rollback()
            saveErrorMessage = PersistenceErrorMessage.saveFailed(error)
        }
    }
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private struct ClosetEditorRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @Bindable var closet: Closet
    let items: [ClosetItem]
    @Binding var saveErrorMessage: String?
    let deleteAction: () -> Void
    @State private var isConfirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.md) {
            if dynamicTypeSize.isAccessibilitySize {
                editableName
                itemCount
                rowActions
            } else {
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
            }

            if items.isEmpty {
                Text("Add pieces to your wardrobe to organize them here.")
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.inactiveText)
            } else {
                DisclosureGroup("Pieces") {
                    VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                        ForEach(items) { item in
                            Toggle(itemTitle(for: item), isOn: membershipBinding(for: item))
                                .frame(minHeight: 44)
                        }
                    }
                    .padding(.top, PyxisSpacing.sm)
                }
                .font(PyxisTypography.body)
                .frame(minHeight: 44)
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
        EditorialTextField("Closet name", text: nameBinding, axis: .vertical)
            .accessibilityLabel("Rename \(closet.displayName)")
            .textFieldStyle(.plain)
            .font(PyxisTypography.body)
    }

    private var itemCount: some View {
        Text("\(closet.itemCount)")
            .font(PyxisTypography.code)
            .foregroundStyle(PyxisColors.secondaryText)
            .accessibilityLabel("\(closet.itemCount) \(closet.itemCount == 1 ? "item" : "items")")
    }

    private var rowActions: some View {
        HStack(spacing: PyxisSpacing.sm) {
            Button("Delete", role: .destructive) {
                isConfirmingDelete = true
            }
            .buttonStyle(MinimalButtonStyle())
            .accessibilityLabel("Delete closet \(closet.displayName)")
        }
        .confirmationDialog("Delete \(closet.displayName)?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete closet", role: .destructive, action: deleteAction)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The group will be removed. Your pieces stay in your wardrobe.")
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
            modelContext.rollback()
            saveErrorMessage = PersistenceErrorMessage.saveFailed(error)
        }
    }

    private func itemTitle(for item: ClosetItem) -> String {
        let name = item.displayName ?? item.subtype.rawValue
        return "\(item.itemCode) \(name)"
    }
}
