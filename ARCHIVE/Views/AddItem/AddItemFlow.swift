import SwiftData
import SwiftUI

struct AddItemFlow: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var existingItems: [ClosetItem]
    @StateObject private var viewModel = AddItemViewModel()

    var body: some View {
        VStack(spacing: ArchiveSpacing.lg) {
            HStack {
                Text("ADD ITEM")
                    .font(ArchiveTypography.title)
                Spacer()
                Button("CLOSE") {
                    dismiss()
                }
                .buttonStyle(.plain)
            }

            if viewModel.selectedImageURL == nil {
                ImageImportView { url in
                    viewModel.selectImage(url)
                    Task {
                        await viewModel.processSelectedImage()
                    }
                }
            } else {
                HStack(alignment: .top, spacing: ArchiveSpacing.xl) {
                    VStack(spacing: ArchiveSpacing.md) {
                        LocalImageView(url: previewURL)
                            .frame(width: 300, height: 360)

                        statusView

                        HStack {
                            Button("RETRY") {
                                Task { await viewModel.retry() }
                            }
                            .buttonStyle(MinimalButtonStyle())
                            .disabled(viewModel.selectedImageURL == nil)

                            Button("SAVE") {
                                save()
                            }
                            .buttonStyle(MinimalButtonStyle())
                            .disabled(viewModel.result?.originalPath.isEmpty ?? true)
                        }
                    }

                    MetadataEditorView(viewModel: viewModel)
                        .frame(width: 320)
                }
            }
        }
        .padding(ArchiveSpacing.xl)
        .background(ArchiveColors.background)
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.stage {
        case .idle, .selected:
            Text("READY")
                .font(ArchiveTypography.label)
                .foregroundStyle(ArchiveColors.secondaryText)
        case .processing:
            ProgressView()
                .controlSize(.small)
        case .processed:
            Text("CUTOUT READY")
                .font(ArchiveTypography.label)
        case .failed:
            Text("BACKGROUND REMOVAL FAILED — RETRY")
                .font(ArchiveTypography.label)
                .foregroundStyle(ArchiveColors.error)
        }
    }

    private var previewURL: URL? {
        if let result = viewModel.result {
            if let storage = try? ImageStorageService() {
                if let cutoutPath = result.cutoutPath {
                    return storage.url(for: cutoutPath)
                }
                if !result.originalPath.isEmpty {
                    return storage.url(for: result.originalPath)
                }
            }
        }
        return viewModel.selectedImageURL
    }

    private func save() {
        let existingCodes = Set(existingItems.map(\.itemCode))
        guard let item = viewModel.makeClosetItem(existingCodes: existingCodes) else {
            return
        }
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }
}
