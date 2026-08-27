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
    @State private var processingTask: Task<Void, Never>?
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

                AddItemStepIndicator(stage: viewModel.stage)

                if let setupError = viewModel.setupError {
                    InlineErrorMessage(message: setupError)
                }

                if let saveErrorMessage {
                    InlineErrorMessage(message: saveErrorMessage)
                }

                if viewModel.selectedImageURL == nil {
                    ImageImportView { url in
                        processingTask?.cancel()
                        viewModel.selectImage(url)
                        applyInitialMetadata()
                        processingTask = Task {
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
        .safeAreaInset(edge: .bottom) {
            if viewModel.selectedImageURL != nil, !viewModel.stage.isProcessing {
                Button(viewModel.stage.isFailed ? "SAVE ORIGINAL" : "SAVE ITEM") {
                    save()
                }
                .buttonStyle(MinimalButtonStyle())
                .disabled(viewModel.result?.originalPath.isEmpty ?? true)
                .accessibilityLabel(viewModel.stage.isFailed ? "Save item with original image" : "Save item")
                .padding(PyxisSpacing.md)
                .frame(maxWidth: .infinity)
                .background(PyxisColors.background)
                .overlay(alignment: .top) {
                    Rectangle().fill(PyxisColors.hairline).frame(height: 1)
                }
            }
        }
        .onAppear(perform: applyInitialCloset)
        .onChange(of: closets.map(\.id)) { _, _ in
            applyInitialCloset()
        }
        .onDisappear {
            processingTask?.cancel()
            if !didSave {
                viewModel.discardDraft()
            }
        }
    }

    @ViewBuilder
    private var editorContent: some View {
        responsiveEditorContent
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
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: PyxisSpacing.sm) {
                        secondaryProcessingActions
                    }
                    VStack(spacing: PyxisSpacing.sm) {
                        secondaryProcessingActions
                    }
                }

                if viewModel.isAIStudioAvailable {
                    Button(viewModel.isAIEnhancing ? "GENERATING" : "AI DE-WRINKLE") {
                        Task { await viewModel.makePristineWithAI() }
                    }
                    .buttonStyle(MinimalButtonStyle())
                    .disabled(viewModel.isAIEnhancing || (viewModel.result?.originalPath.isEmpty ?? true))
                    .accessibilityLabel("Generate a pristine AI garment image")

                    Text("AI DE-WRINKLE SENDS THIS PHOTO TO XAI FOR GENERATION. XAI MAY RETAIN API DATA FOR UP TO 30 DAYS. VERIFY FABRIC, LOGOS, AND CONDITION BEFORE SAVING.")
                        .font(PyxisTypography.body)
                        .foregroundStyle(PyxisColors.inactiveText)
                        .multilineTextAlignment(.center)
                } else {
                    Text("AI STUDIO IS UNAVAILABLE IN THIS BUILD. LOCAL CUTOUTS AND SAVING STILL WORK OFFLINE.")
                        .font(PyxisTypography.body)
                        .foregroundStyle(PyxisColors.inactiveText)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    @ViewBuilder
    private var secondaryProcessingActions: some View {
        rotationControls

        Button("IMPROVE CUTOUT") {
            retryProcessing()
        }
        .buttonStyle(MinimalButtonStyle())
        .disabled(viewModel.selectedImageURL == nil)
        .accessibilityLabel("Retry background removal")
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
        case .failed(let message):
            VStack(spacing: PyxisSpacing.xs) {
                Text("ORIGINAL ONLY")
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.secondaryText)
                Text("\(message) THE ORIGINAL PHOTO WILL BE SAVED IF YOU CONTINUE.")
                    .font(PyxisTypography.body)
                    .foregroundStyle(PyxisColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
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

    private func retryProcessing() {
        processingTask?.cancel()
        processingTask = Task {
            await viewModel.retry()
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

private struct AddItemStepIndicator: View {
    let stage: AddItemViewModel.Stage

    private var currentStep: Int {
        switch stage {
        case .idle: 0
        case .selected, .processing: 1
        case .processed, .failed: 2
        }
    }

    var body: some View {
        HStack(spacing: PyxisSpacing.sm) {
            step(0, title: "ADD PHOTO")
            connector(after: 0)
            step(1, title: "CLEAN IMAGE")
            connector(after: 1)
            step(2, title: "REVIEW DETAILS")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentStep + 1) of 3, \(stepTitle)")
    }

    private func step(_ index: Int, title: String) -> some View {
        VStack(spacing: PyxisSpacing.xs) {
            Text("\(index + 1)")
                .font(PyxisTypography.code)
                .frame(width: 28, height: 28)
                .foregroundStyle(index <= currentStep ? PyxisColors.surface : PyxisColors.secondaryText)
                .background(index <= currentStep ? PyxisColors.text : PyxisColors.field)
                .clipShape(Circle())
            Text(title)
                .font(PyxisTypography.label)
                .foregroundStyle(index == currentStep ? PyxisColors.text : PyxisColors.inactiveText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func connector(after index: Int) -> some View {
        Rectangle()
            .fill(index < currentStep ? PyxisColors.text : PyxisColors.hairline)
            .frame(maxWidth: 36, maxHeight: 1)
    }

    private var stepTitle: String {
        switch currentStep {
        case 0: "Add photo"
        case 1: "Clean image"
        default: "Review details"
        }
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
