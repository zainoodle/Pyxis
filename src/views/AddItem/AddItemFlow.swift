import SwiftData
import SwiftUI

struct AddItemFlow: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Query private var existingItems: [ClosetItem]
    @Query(sort: \Closet.dateUpdated, order: .reverse) private var closets: [Closet]
    @StateObject private var viewModel = AddItemViewModel()
    @State private var selectedClosetIDs: Set<UUID> = []
    @State private var didApplyInitialCloset = false
    @State private var saveErrorMessage: String?
    @State private var didSave = false
    @State private var processingTask: Task<Void, Never>?
    @State private var previewAppearance = PyxisAppearance.system
    @State private var requestsSoftening = false
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
                PrimaryPageHeader(title: "Add piece") {
                    HeaderIconButton(symbol: "xmark", label: "Close add item") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }

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
                    .frame(minHeight: 220)
                } else {
                    editorContent
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .editorialCanvas()
        .safeAreaInset(edge: .bottom) {
            if viewModel.selectedImageURL != nil, !viewModel.stage.isProcessing {
                Button("Save piece") {
                    save()
                }
                .buttonStyle(EditorialPrimaryButtonStyle())
                .disabled(viewModel.isEditingPhoto || (viewModel.result?.originalPath.isEmpty ?? true))
                .accessibilityLabel(viewModel.stage.isFailed ? "Save piece with original photo" : "Save piece")
                .accessibilityIdentifier("piece.save")
                .padding(PyxisSpacing.md)
                .frame(maxWidth: .infinity)
                .background(PyxisColors.background)
                .overlay(alignment: .top) {
                    Rectangle().fill(PyxisColors.hairline).frame(height: 1)
                }
            }
        }
        .onAppear(perform: applyInitialCloset)
        #if DEBUG
        .task {
            let arguments = ProcessInfo.processInfo.arguments
            guard viewModel.selectedImageURL == nil,
                  let flag = arguments.firstIndex(of: "-pyxis.importFixture"),
                  arguments.indices.contains(flag + 1) else { return }
            let url = URL(fileURLWithPath: arguments[flag + 1])
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            viewModel.selectImage(url)
            applyInitialMetadata()
            processingTask = Task { await viewModel.processSelectedImage() }
        }
        #endif
        .onChange(of: closets.map(\.id)) { _, _ in
            applyInitialCloset()
        }
        .onChange(of: requestsSoftening) { _, enabled in
            processingTask = Task {
                await viewModel.setSoftensCreases(enabled)
                requestsSoftening = viewModel.softensCreases
            }
        }
        .onChange(of: viewModel.imageRevision) { _, _ in
            requestsSoftening = viewModel.softensCreases
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

    @ViewBuilder
    private var responsiveEditorContent: some View {
        if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
            HStack(alignment: .top, spacing: PyxisSpacing.xl) {
                previewAndActions

                MetadataEditorView(
                    viewModel: viewModel,
                    closets: closets,
                    selectedClosetIDs: $selectedClosetIDs
                )
                    .frame(width: 320)
            }
        } else {
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
                imageRevision: viewModel.imageRevision
            )
            .frame(maxWidth: 300)
            .frame(height: 300)
            .environment(\.colorScheme, previewAppearance.colorScheme ?? colorScheme)

            if viewModel.result?.cutoutPath != nil {
                Picker("Preview background", selection: $previewAppearance) {
                    Text("Current").tag(PyxisAppearance.system)
                    Text("Light").tag(PyxisAppearance.light)
                    Text("Dark").tag(PyxisAppearance.dark)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)
                .accessibilityIdentifier("piece.previewAppearance")
            }

            if let candidateItemCode { ItemCodeLabel(code: candidateItemCode) }

            statusView

            if let aiError = viewModel.aiEnhancementError {
                InlineErrorMessage(message: aiError)
            }
            if let refinementError = viewModel.photoRefinementError {
                InlineErrorMessage(message: refinementError)
            }

            if !viewModel.stage.isProcessing {
                if viewModel.result?.cutoutPath != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Button(requestsSoftening ? "Restore natural texture" : "Soften small creases") {
                            requestsSoftening.toggle()
                        }
                        .buttonStyle(MinimalButtonStyle())
                        .disabled(viewModel.isEditingPhoto)
                        .accessibilityIdentifier("piece.softenCreases")
                        .accessibilityValue(viewModel.softensCreases ? "Softened" : "Natural")
                        Text(viewModel.isRefiningPhoto ? "Refining photo…" : "On this device. Reduces fine creases; keeps the original photo.")
                            .font(PyxisTypography.proseCaption)
                            .foregroundStyle(PyxisColors.secondaryText)
                    }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: PyxisSpacing.sm) {
                        secondaryProcessingActions
                    }
                    VStack(spacing: PyxisSpacing.sm) {
                        secondaryProcessingActions
                    }
                }
                .disabled(viewModel.isEditingPhoto)

                if viewModel.isAIStudioAvailable {
                    Button(viewModel.isAIEnhancing ? "Generating…" : "AI de-wrinkle") {
                        Task { await viewModel.makePristineWithAI() }
                    }
                    .buttonStyle(MinimalButtonStyle())
                    .disabled(viewModel.isEditingPhoto || (viewModel.result?.originalPath.isEmpty ?? true))
                    .accessibilityLabel("Generate a pristine AI garment image")

                    Text("Sends this photo to xAI, which may retain API data for up to 30 days. Check fabric, logos, and condition before saving.")
                        .font(PyxisTypography.proseCaption)
                        .foregroundStyle(PyxisColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    @ViewBuilder
    private var secondaryProcessingActions: some View {
        rotationControls

        Button(viewModel.stage.isFailed ? "Retry cutout" : "Improve cutout") {
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
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.result?.originalPath.isEmpty ?? true)
            .accessibilityLabel("Rotate image left")

            Button {
                rotateImage(.clockwise)
            } label: {
                Image(systemName: "rotate.right")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.result?.originalPath.isEmpty ?? true)
            .accessibilityLabel("Rotate image right")
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.stage {
        case .processing:
            ProgressView("Removing background…")
                .font(PyxisTypography.proseCaption)
        case .failed(let message):
            Text(viewModel.processingMessage ?? ((viewModel.result?.originalPath.isEmpty == false)
                 ? "Couldn’t remove the background. You can save the original."
                 : message))
                .font(PyxisTypography.proseCaption)
                .foregroundStyle(PyxisColors.secondaryText)
                .multilineTextAlignment(.center)
        case .idle, .selected, .processed:
            if let message = viewModel.processingMessage {
                Text(message).font(PyxisTypography.proseCaption)
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

private struct StudioCutoutProcessingView: View {
    let url: URL?
    let isProcessing: Bool
    let imageRevision: Int
    @Environment(\.accessibilityReduceMotion) private var prefersReducedMotion
    @State private var sweepOffset: CGFloat = -1
    @State private var isLifted = false
    @State private var isFinishVisible = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LocalImageView(url: url, revision: imageRevision, balancedFraming: true, castsShadow: true)
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

                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .background { GarmentStageBackground() }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(PyxisColors.hairline.opacity(0.7), lineWidth: 1)
                .allowsHitTesting(false)
        }
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
        .accessibilityLabel(isProcessing ? "Removing image background" : "Clothing image preview")
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
