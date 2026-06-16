import SwiftData
import SwiftUI

struct AddItemFlow: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var existingItems: [ClosetItem]
    @StateObject private var viewModel = AddItemViewModel()
    private let initialCategory: ClothingCategory?
    private let initialSubtype: ClothingSubtype?
    private let onSave: ((ClosetItem) -> Void)?

    init(
        initialCategory: ClothingCategory? = nil,
        initialSubtype: ClothingSubtype? = nil,
        onSave: ((ClosetItem) -> Void)? = nil
    ) {
        self.initialCategory = initialCategory
        self.initialSubtype = initialSubtype
        self.onSave = onSave
    }

    var body: some View {
        ScrollView {
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
                        applyInitialMetadata()
                        Task {
                            await viewModel.processSelectedImage()
                        }
                    }
                    .frame(minHeight: 360)
                } else {
                    editorContent
                }
            }
            .padding(ArchiveSpacing.md)
        }
        .background(ArchiveColors.background)
    }

    @ViewBuilder
    private var editorContent: some View {
        if viewModel.stage.isProcessing {
            previewAndActions
        } else {
            responsiveEditorContent
        }
    }

    private var responsiveEditorContent: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: ArchiveSpacing.xl) {
                previewAndActions

                MetadataEditorView(viewModel: viewModel)
                    .frame(maxWidth: 320)
            }

            VStack(spacing: ArchiveSpacing.lg) {
                previewAndActions

                MetadataEditorView(viewModel: viewModel)
            }
        }
    }

    private var previewAndActions: some View {
        VStack(spacing: ArchiveSpacing.md) {
            ProcessingRevealImageView(
                url: previewURL,
                isProcessing: viewModel.stage.isProcessing
            )
            .frame(maxWidth: 300)
            .frame(height: 360)

            statusView

            if !viewModel.stage.isProcessing {
                HStack {
                    Button("IMPROVE CUTOUT") {
                        Task { await viewModel.retry() }
                    }
                    .buttonStyle(MinimalButtonStyle())
                    .disabled(viewModel.selectedImageURL == nil)

                    Button(viewModel.stage.isFailed ? "USE AS IS" : "SAVE") {
                        save()
                    }
                    .buttonStyle(MinimalButtonStyle())
                    .disabled(viewModel.result?.originalPath.isEmpty ?? true)
                }
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.stage {
        case .idle, .selected:
            Text("READY")
                .font(ArchiveTypography.label)
                .foregroundStyle(ArchiveColors.secondaryText)
        case .processing:
            Text("PREPARING")
                .font(ArchiveTypography.label)
                .foregroundStyle(ArchiveColors.secondaryText)
        case .processed:
            Text("READY")
                .font(ArchiveTypography.label)
        case .failed:
            Text("ORIGINAL ONLY")
                .font(ArchiveTypography.label)
                .foregroundStyle(ArchiveColors.secondaryText)
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
        onSave?(item)
        dismiss()
    }

    private func applyInitialMetadata() {
        guard let initialCategory else {
            return
        }

        viewModel.updateCategory(initialCategory, preferredSubtype: initialSubtype)
    }
}

private struct ProcessingRevealImageView: View {
    let url: URL?
    let isProcessing: Bool
    @State private var isClosed = false

    var body: some View {
        ZStack {
            LocalImageView(url: isProcessing ? nil : url)
                .opacity(isProcessing ? 0 : 1)
                .animation(.easeOut(duration: 0.24), value: isProcessing)

            if isProcessing {
                ShutterProcessingView(isClosed: isClosed)
                    .transition(.opacity)
            }
        }
        .background(ArchiveColors.field)
        .clipShape(Rectangle())
        .onAppear {
            updateAnimation()
        }
        .onChange(of: isProcessing) { _, _ in
            updateAnimation()
        }
    }

    private func updateAnimation() {
        guard isProcessing else {
            withAnimation(.easeOut(duration: 0.2)) {
                isClosed = false
            }
            return
        }

        withAnimation(.easeInOut(duration: 0.72).repeatForever(autoreverses: true)) {
            isClosed = true
        }
    }
}

private struct ShutterProcessingView: View {
    let isClosed: Bool

    var body: some View {
        GeometryReader { proxy in
            let bladeCount = 7
            let bladeWidth = proxy.size.width / CGFloat(bladeCount)

            ZStack {
                ForEach(0..<bladeCount, id: \.self) { index in
                    shutterBlade(index: index, width: bladeWidth, height: proxy.size.height)
                }

                VStack(spacing: ArchiveSpacing.sm) {
                    Text("ARCHIVE")
                        .font(ArchiveTypography.label)
                        .foregroundStyle(ArchiveColors.secondaryText)

                    Text("CUTOUT")
                        .font(ArchiveTypography.body)
                        .foregroundStyle(ArchiveColors.text)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .accessibilityLabel("Preparing clothing image")
    }

    private func shutterBlade(index: Int, width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(index.isMultiple(of: 2) ? ArchiveColors.surface : ArchiveColors.field)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(ArchiveColors.hairline)
                    .frame(width: 1)
            }
            .frame(width: width + 2, height: height)
            .rotation3DEffect(
                .degrees(isClosed ? 0 : (index.isMultiple(of: 2) ? 68 : -68)),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.7
            )
            .opacity(isClosed ? 0.98 : 0.42)
            .offset(x: (CGFloat(index) * width) - ((width * 3) + width / 2))
    }
}

private extension AddItemViewModel.Stage {
    var isProcessing: Bool {
        if case .processing = self {
            return true
        }
        return false
    }

    var isFailed: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
}
