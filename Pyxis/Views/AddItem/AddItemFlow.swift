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
    @State private var saveErrorMessage: String?
    @State private var didSave = false
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
                    .keyboardShortcut(.cancelAction)
                    .accessibilityLabel("Close add item")
                }

                if let setupError = viewModel.setupError {
                    InlineErrorMessage(message: setupError)
                }

                if let saveErrorMessage {
                    InlineErrorMessage(message: saveErrorMessage)
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
        .onDisappear {
            if !didSave {
                viewModel.discardDraft()
            }
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
            StudioCutoutProcessingView(
                url: previewURL,
                isProcessing: viewModel.stage.isProcessing,
                subtypeLabel: viewModel.subtype.rawValue,
                candidateItemCode: candidateItemCode,
                imageRevision: viewModel.imageRevision
            )
            .id(viewModel.imageRevision)
            .frame(maxWidth: 300)
            .frame(height: 360)

            statusView

            if let aiError = viewModel.aiEnhancementError {
                InlineErrorMessage(message: aiError)
            }

            if !viewModel.stage.isProcessing {
                rotationControls

                HStack {
                    Button(viewModel.isAIEnhancing ? "GENERATING" : "AI DE-WRINKLE") {
                        Task { await viewModel.makePristineWithAI() }
                    }
                    .buttonStyle(MinimalButtonStyle())
                    .disabled(viewModel.isAIEnhancing || (viewModel.result?.originalPath.isEmpty ?? true))
                    .accessibilityLabel("Generate a pristine AI garment image")

                    Button("IMPROVE CUTOUT") {
                        Task { await viewModel.retry() }
                    }
                    .buttonStyle(MinimalButtonStyle())
                    .disabled(viewModel.selectedImageURL == nil)
                    .accessibilityLabel("Retry background removal")

                    Button(viewModel.stage.isFailed ? "USE AS IS" : "SAVE") {
                        save()
                    }
                    .buttonStyle(MinimalButtonStyle())
                    .disabled(viewModel.result?.originalPath.isEmpty ?? true)
                    .accessibilityLabel(viewModel.stage.isFailed ? "Save item with original image" : "Save item")
                }

                Text("AI DE-WRINKLE SENDS THIS PHOTO TO XAI FOR GENERATION. XAI MAY RETAIN API DATA FOR UP TO 30 DAYS. VERIFY FABRIC, LOGOS, AND CONDITION BEFORE SAVING.")
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.inactiveText)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var rotationControls: some View {
        HStack(spacing: PyxisSpacing.sm) {
            Button {
                rotateImage(.counterclockwise)
            } label: {
                Image(systemName: "rotate.left")
                    .frame(width: 36, height: 32)
            }
            .buttonStyle(MinimalButtonStyle())
            .disabled(viewModel.result?.originalPath.isEmpty ?? true)
            .accessibilityLabel("Rotate image left")

            Button {
                rotateImage(.clockwise)
            } label: {
                Image(systemName: "rotate.right")
                    .frame(width: 36, height: 32)
            }
            .buttonStyle(MinimalButtonStyle())
            .disabled(viewModel.result?.originalPath.isEmpty ?? true)
            .accessibilityLabel("Rotate image right")
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
            Text("SAVING CLEAN ITEM")
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
            if let storage = ImageStorageService.shared {
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

    private var candidateItemCode: String? {
        guard viewModel.selectedImageURL != nil else {
            return nil
        }

        return ItemCodeGenerator.generate(
            for: viewModel.subtype,
            category: viewModel.category,
            existingCodes: Set(existingItems.map(\.itemCode))
        )
    }

    private func save() {
        let existingCodes = Set(existingItems.map(\.itemCode))
        guard let item = viewModel.makeClosetItem(
            existingCodes: existingCodes,
            preferredItemCode: candidateItemCode
        ) else {
            return
        }
        modelContext.insert(item)
        for closet in closets where selectedClosetIDs.contains(closet.id) {
            closet.add(item)
        }
        do {
            try upsertMemory(for: item)
            try modelContext.save()
            saveErrorMessage = nil
            didSave = true
            onSave?(item)
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = PersistenceErrorMessage.saveFailed(error)
        }
    }

    private func rotateImage(_ direction: ImageUtilities.RotationDirection) {
        do {
            try viewModel.rotateProcessedImage(direction)
            saveErrorMessage = nil
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    private func upsertMemory(for item: ClosetItem) throws {
        let payload = OnDeviceMemoryPayloadBuilder.closetItemPayload(for: item)
        try OnDeviceMemoryStore(context: modelContext).upsertMemory(
            kind: .closetItem,
            subjectID: item.id,
            summary: payload.summary,
            embedding: payload.embedding,
            metadataTags: payload.metadataTags,
            updatedAt: item.dateAdded,
            saveImmediately: false
        )
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

private struct StudioCutoutProcessingView: View {
    let url: URL?
    let isProcessing: Bool
    let subtypeLabel: String?
    let candidateItemCode: String?
    let imageRevision: Int
    @Environment(\.accessibilityReduceMotion) private var prefersReducedMotion
    @State private var sweepOffset: CGFloat = -1
    @State private var isLifted = false
    @State private var isFinishVisible = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LocalImageView(url: url, revision: imageRevision)
                    .saturation(isProcessing ? 0.15 : 1)
                    .opacity(isProcessing ? 0.42 : 1)
                    .scaleEffect(isProcessing && isLifted ? 1.025 : 1)
                    .animation(.easeOut(duration: 0.28), value: isProcessing)
                    .animation(.easeOut(duration: 0.34), value: isLifted)

                if isProcessing {
                    PyxisColors.field
                        .opacity(0.56)

                    Ellipse()
                        .fill(PyxisColors.shadow.opacity(prefersReducedMotion ? 0.12 : 0.2))
                        .frame(
                            width: min(proxy.size.width * 0.34, 104),
                            height: prefersReducedMotion ? 8 : 10
                        )
                        .blur(radius: prefersReducedMotion ? 4 : 6)
                        .scaleEffect(x: isLifted ? 1 : 0.64, y: 1)
                        .opacity(isLifted ? 1 : 0)
                        .offset(y: proxy.size.height * 0.23)
                        .animation(.easeOut(duration: 0.28), value: isLifted)

                    if !prefersReducedMotion {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, PyxisColors.surface.opacity(0.88), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: proxy.size.width * 0.62, height: proxy.size.height * 1.6)
                            .rotationEffect(.degrees(-18))
                            .offset(x: sweepOffset * proxy.size.width * 1.35)
                            .blendMode(.screen)
                    }

                    Image(systemName: "sparkle")
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(PyxisColors.secondaryText)
                        .opacity(
                            isFinishVisible
                                ? (prefersReducedMotion ? 0.22 : 0.62)
                                : 0
                        )
                        .padding(PyxisSpacing.md)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .animation(.easeOut(duration: 0.22), value: isFinishVisible)
                        .accessibilityHidden(true)

                    VStack {
                        Spacer()

                        HStack {
                            Text((subtypeLabel ?? "ITEM").uppercased())
                            Spacer()
                            if let candidateItemCode {
                                Text(candidateItemCode.uppercased())
                            }
                        }
                        .font(PyxisTypography.code)
                        .foregroundStyle(PyxisColors.secondaryText)
                        .padding(PyxisSpacing.md)
                    }
                }
            }
            .clipShape(Rectangle())
        }
        .background(PyxisColors.field)
        .onAppear {
            updateAnimation()
        }
        .onChange(of: isProcessing) { _, _ in
            updateAnimation()
        }
        .onChange(of: prefersReducedMotion) { _, _ in
            updateAnimation()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isProcessing ? "Saving clean item" : "Clothing image preview")
    }

    private func updateAnimation() {
        guard isProcessing else {
            sweepOffset = -1
            isFinishVisible = false
            withAnimation(.easeOut(duration: 0.2)) {
                isLifted = false
            }
            return
        }

        guard !prefersReducedMotion else {
            sweepOffset = -1
            isLifted = true
            isFinishVisible = true
            return
        }

        isFinishVisible = false
        withAnimation(.easeOut(duration: 0.34)) {
            isLifted = true
        }
        withAnimation(.easeOut(duration: 0.22).delay(0.65)) {
            isFinishVisible = true
        }
        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
            sweepOffset = 1
        }
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
