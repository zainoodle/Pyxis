import SwiftData
import SwiftUI

struct AddItemFlow: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var existingItems: [ClosetItem]
    @Query(sort: \Closet.dateUpdated, order: .reverse) private var closets: [Closet]
    @StateObject private var viewModel = AddItemViewModel()
    @State private var selectedClosetIDs: Set<UUID> = []
    @State private var didApplyInitialCloset = false
    private let initialCategory: ClothingCategory?
    private let initialSubtype: ClothingSubtype?
    private let initialClosetID: UUID?
    private let onSave: ((ClosetItem) -> Void)?

    init(
        initialCategory: ClothingCategory? = nil,
        initialSubtype: ClothingSubtype? = nil,
        initialClosetID: UUID? = nil,
        onSave: ((ClosetItem) -> Void)? = nil
    ) {
        self.initialCategory = initialCategory
        self.initialSubtype = initialSubtype
        self.initialClosetID = initialClosetID
        self.onSave = onSave
    }

    var body: some View {
        ScrollView {
            VStack(spacing: PyxisSpacing.lg) {
                HStack {
                    Text("ADD ITEM")
                        .font(PyxisTypography.title)
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
            .padding(PyxisSpacing.md)
        }
        .background(PyxisColors.background)
        .onAppear(perform: applyInitialCloset)
        .onChange(of: closets.map(\.id)) { _, _ in
            applyInitialCloset()
        }
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
            HStack(alignment: .top, spacing: PyxisSpacing.xl) {
                previewAndActions

                MetadataEditorView(
                    viewModel: viewModel,
                    closets: closets,
                    selectedClosetIDs: $selectedClosetIDs
                )
                    .frame(maxWidth: 320)
            }

            VStack(spacing: PyxisSpacing.lg) {
                previewAndActions

                MetadataEditorView(
                    viewModel: viewModel,
                    closets: closets,
                    selectedClosetIDs: $selectedClosetIDs
                )
            }
        }
    }

    private var previewAndActions: some View {
        VStack(spacing: PyxisSpacing.md) {
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
                .font(PyxisTypography.label)
                .foregroundStyle(PyxisColors.secondaryText)
        case .processing:
            Text("PREPARING")
                .font(PyxisTypography.label)
                .foregroundStyle(PyxisColors.secondaryText)
        case .processed:
            Text("READY")
                .font(PyxisTypography.label)
        case .failed:
            Text("ORIGINAL ONLY")
                .font(PyxisTypography.label)
                .foregroundStyle(PyxisColors.secondaryText)
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
        for closet in closets where selectedClosetIDs.contains(closet.id) {
            closet.add(item)
        }
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

    private func applyInitialCloset() {
        guard !didApplyInitialCloset, let initialClosetID else {
            return
        }
        guard closets.contains(where: { $0.id == initialClosetID }) else {
            return
        }
        selectedClosetIDs.insert(initialClosetID)
        didApplyInitialCloset = true
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
        .background(PyxisColors.field)
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

                VStack(spacing: PyxisSpacing.sm) {
                    Text("Pyxis")
                        .font(PyxisTypography.label)
                        .foregroundStyle(PyxisColors.secondaryText)

                    Text("CUTOUT")
                        .font(PyxisTypography.body)
                        .foregroundStyle(PyxisColors.text)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .accessibilityLabel("Preparing clothing image")
    }

    private func shutterBlade(index: Int, width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(index.isMultiple(of: 2) ? PyxisColors.surface : PyxisColors.field)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(PyxisColors.hairline)
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
