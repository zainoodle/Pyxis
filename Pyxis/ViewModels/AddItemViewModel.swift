import Foundation

@MainActor
final class AddItemViewModel: ObservableObject {
    enum Stage: Equatable {
        case idle
        case selected
        case processing
        case processed
        case failed(String)
    }

    @Published var stage: Stage = .idle
    @Published var selectedImageURL: URL?
    @Published var result: BackgroundRemovalResult?
    @Published var displayName = ""
    @Published var category: ClothingCategory = .other
    @Published var subtype: ClothingSubtype = .other
    @Published var primaryColor: ClosetColor = .unknown
    @Published var classificationConfidence: Double = 0
    @Published var colorConfidence: Double = 0
    @Published var brand = ""
    @Published var size = ""
    @Published var tags = ""
    @Published var notes = ""
    @Published var favorite = false
    @Published var setupError: String?
    @Published var imageRevision = 0
    @Published var isAIEnhancing = false
    @Published var aiEnhancementError: String?

    private let imageStorage: ImageStorageService?
    private let backgroundRemovalService: (any BackgroundRemovalServiceProtocol)?
    private let colorAnalysisService: ColorAnalysisService
    private let classificationService: any ClothingClassificationProviding
    private let aiStudioService: any AIGarmentStudioProviding
    private var userAdjustedClassification = false
    private var draftItemID = UUID()
    private var processingGeneration: UInt64 = 0

    var isAIStudioAvailable: Bool {
        aiStudioService.isConfigured
    }

    init() {
        do {
            let storage = try ImageStorageService()
            self.imageStorage = storage
            self.backgroundRemovalService = LocalBackgroundRemovalService(imageStorage: storage)
            self.colorAnalysisService = ColorAnalysisService()
            self.classificationService = ClothingClassificationService()
            self.aiStudioService = AIGarmentStudioService()
        } catch {
            self.imageStorage = nil
            self.backgroundRemovalService = nil
            self.colorAnalysisService = ColorAnalysisService()
            self.classificationService = ClothingClassificationService()
            self.aiStudioService = AIGarmentStudioService()
            self.setupError = "Image storage could not be opened."
        }
    }

    init(
        imageStorage: ImageStorageService,
        backgroundRemovalService: BackgroundRemovalServiceProtocol,
        colorAnalysisService: ColorAnalysisService = ColorAnalysisService(),
        classificationService: any ClothingClassificationProviding = ClothingClassificationService(),
        aiStudioService: any AIGarmentStudioProviding = AIGarmentStudioService()
    ) {
        self.imageStorage = imageStorage
        self.backgroundRemovalService = backgroundRemovalService
        self.colorAnalysisService = colorAnalysisService
        self.classificationService = classificationService
        self.aiStudioService = aiStudioService
    }

    func selectImage(_ url: URL) {
        invalidateProcessing()
        discardProcessedImages()
        discardTemporaryImport()
        draftItemID = UUID()
        selectedImageURL = url
        stage = .selected
        userAdjustedClassification = false
        primaryColor = .unknown
        colorConfidence = 0
        let classification = classificationService.classify(filename: url.lastPathComponent)
        applyAutomaticClassification(classification)
        if let colorHint = colorAnalysisService.colorHint(filename: url.lastPathComponent) {
            primaryColor = colorHint.primaryColor
            colorConfidence = colorHint.confidence
        }
    }

    func updateCategory(
        _ newCategory: ClothingCategory,
        preferredSubtype: ClothingSubtype? = nil,
        markUserEdited: Bool = true
    ) {
        if markUserEdited {
            userAdjustedClassification = true
        }
        category = newCategory
        if let preferredSubtype, preferredSubtype.isCompatible(with: newCategory) {
            subtype = preferredSubtype
        } else if !subtype.isCompatible(with: newCategory) {
            subtype = ClothingSubtype.defaultSubtype(for: newCategory)
        }
    }

    func processSelectedImage(itemID: UUID? = nil) async {
        guard let selectedImageURL else {
            return
        }
        guard let backgroundRemovalService else {
            stage = .failed(setupError ?? "Image storage could not be opened.")
            return
        }

        processingGeneration &+= 1
        let generation = processingGeneration
        let priorResult = result
        let processingItemID: UUID
        if let itemID {
            processingItemID = itemID
        } else if stage == .selected, result == nil {
            processingItemID = draftItemID
        } else {
            processingItemID = UUID()
        }

        stage = .processing
        let processed = await backgroundRemovalService.processImage(
            at: selectedImageURL,
            itemID: processingItemID
        )

        guard !Task.isCancelled,
              generation == processingGeneration,
              self.selectedImageURL == selectedImageURL else {
            deleteProcessedImages(processed, itemID: processingItemID)
            discardTemporaryImport(at: selectedImageURL)
            return
        }

        let analysisURL = analysisURL(from: processed)
        let colorAnalysisService = self.colorAnalysisService
        let classificationService = self.classificationService
        let filename = selectedImageURL.lastPathComponent
        let suggestions = await Task.detached(priority: .userInitiated) {
            let color = analysisURL.flatMap { try? colorAnalysisService.analyze(imageURL: $0) }
            let classification = analysisURL.map {
                classificationService.classify(
                    imageURL: $0,
                    filename: filename
                )
            }
            return (color, classification)
        }.value

        guard !Task.isCancelled,
              generation == processingGeneration,
              self.selectedImageURL == selectedImageURL else {
            deleteProcessedImages(processed, itemID: processingItemID)
            return
        }

        if let analysis = suggestions.0,
           analysis.primaryColor != .unknown,
           analysis.confidence > 0 {
            primaryColor = analysis.primaryColor
            colorConfidence = analysis.confidence
        }

        if let classification = suggestions.1, !userAdjustedClassification {
            if classification.confidence > classificationConfidence {
                applyAutomaticClassification(classification)
            }
        }

        if let priorResult, priorResult != processed {
            deleteProcessedImages(priorResult, itemID: draftItemID)
        }
        draftItemID = processingItemID
        result = processed

        switch processed.status {
        case .succeeded:
            stage = .processed
        case .failed:
            stage = .failed(processed.errorMessage ?? "Background removal failed — retry")
        }
    }

    func makeClosetItem(
        existingCodes: Set<String>,
        preferredItemCode: String? = nil
    ) -> ClosetItem? {
        guard let result, !result.originalPath.isEmpty else {
            return nil
        }

        let expectedPrefix = ItemCodeGenerator.prefix(for: subtype, category: category)
        let code: String
        if let preferredItemCode,
           preferredItemCode.hasPrefix("\(expectedPrefix)-"),
           !existingCodes.contains(preferredItemCode) {
            code = preferredItemCode
        } else {
            code = ItemCodeGenerator.generate(
                for: subtype,
                category: category,
                existingCodes: existingCodes
            )
        }

        return ClosetItem(
            id: draftItemID,
            itemCode: code,
            displayName: displayName.nilIfBlank,
            category: category,
            subtype: subtype,
            primaryColor: primaryColor,
            tags: tags.tagList,
            notes: notes.nilIfBlank,
            brand: brand.nilIfBlank,
            size: size.nilIfBlank,
            favorite: favorite,
            imageOriginalPath: result.originalPath,
            imageCutoutPath: result.cutoutPath,
            thumbnailPath: result.thumbnailPath,
            classificationConfidence: classificationConfidence,
            colorConfidence: colorConfidence,
            source: .owned
        )
    }

    func retry() async {
        await processSelectedImage()
    }

    func discardDraft() {
        invalidateProcessing()
        discardProcessedImages()
        discardTemporaryImport()
        result = nil
        selectedImageURL = nil
    }

    func makePristineWithAI() async {
        guard let imageStorage, let result, !result.originalPath.isEmpty else { return }
        isAIEnhancing = true
        aiEnhancementError = nil
        defer { isAIEnhancing = false }
        do {
            let data = try await aiStudioService.makePristineGarment(
                from: imageStorage.url(for: result.originalPath)
            )
            let cutoutPath = try imageStorage.saveCutoutPNG(data, itemID: draftItemID)
            let thumbnailPath = try? imageStorage.makeThumbnail(
                from: imageStorage.url(for: cutoutPath), itemID: draftItemID
            )
            self.result = BackgroundRemovalResult(
                originalPath: result.originalPath,
                cutoutPath: cutoutPath,
                thumbnailPath: thumbnailPath ?? result.thumbnailPath,
                status: .succeeded
            )
            imageRevision += 1
        } catch {
            aiEnhancementError = error.localizedDescription
        }
    }

    func rotateProcessedImage(_ direction: ImageUtilities.RotationDirection) throws {
        guard let imageStorage else {
            throw AddItemImageEditingError.storageUnavailable
        }
        guard let result, !result.originalPath.isEmpty else {
            throw AddItemImageEditingError.noProcessedImage
        }

        let rotatedImageSet = try imageStorage.rotateImages(
            StoredImageSet(
                itemID: draftItemID,
                originalPath: result.originalPath,
                cutoutPath: result.cutoutPath,
                thumbnailPath: result.thumbnailPath
            ),
            direction: direction
        )

        self.result = BackgroundRemovalResult(
            originalPath: rotatedImageSet.originalPath,
            cutoutPath: rotatedImageSet.cutoutPath,
            thumbnailPath: rotatedImageSet.thumbnailPath,
            status: result.status,
            errorMessage: result.errorMessage
        )
        selectedImageURL = imageStorage.url(for: rotatedImageSet.originalPath)
        imageRevision += 1
    }

    private func analysisURL(from result: BackgroundRemovalResult) -> URL? {
        guard let imageStorage else {
            return nil
        }
        if let cutoutPath = result.cutoutPath {
            return imageStorage.url(for: cutoutPath)
        }
        guard !result.originalPath.isEmpty else {
            return nil
        }
        return imageStorage.url(for: result.originalPath)
    }

    private func applyAutomaticClassification(_ classification: ClothingClassificationResult) {
        updateCategory(
            classification.category,
            preferredSubtype: classification.subtype,
            markUserEdited: false
        )
        classificationConfidence = classification.confidence
    }

    private func discardProcessedImages() {
        guard let imageStorage, let result, !result.originalPath.isEmpty else { return }
        imageStorage.deleteImages(
            StoredImageSet(
                itemID: draftItemID,
                originalPath: result.originalPath,
                cutoutPath: result.cutoutPath,
                thumbnailPath: result.thumbnailPath
            )
        )
        self.result = nil
    }

    private func discardTemporaryImport() {
        guard let selectedImageURL else { return }
        discardTemporaryImport(at: selectedImageURL)
    }

    private func discardTemporaryImport(at selectedImageURL: URL) {
        let temporaryRoot = FileManager.default.temporaryDirectory.standardizedFileURL.path
        let candidate = selectedImageURL.standardizedFileURL
        var prefixes = ["Pyxis-photo-", "Pyxis-camera-", "Pyxis-drop-"]
        #if DEBUG
        prefixes.append("Pyxis-black-shirt-demo-")
        #endif
        guard candidate.path.hasPrefix(temporaryRoot + "/"),
              prefixes.contains(where: { candidate.lastPathComponent.hasPrefix($0) }) else { return }
        try? FileManager.default.removeItem(at: candidate)
    }

    private func invalidateProcessing() {
        processingGeneration &+= 1
    }

    private func deleteProcessedImages(_ result: BackgroundRemovalResult, itemID: UUID) {
        guard let imageStorage, !result.originalPath.isEmpty else { return }
        imageStorage.deleteImages(
            StoredImageSet(
                itemID: itemID,
                originalPath: result.originalPath,
                cutoutPath: result.cutoutPath,
                thumbnailPath: result.thumbnailPath
            )
        )
    }
}

private enum AddItemImageEditingError: LocalizedError {
    case storageUnavailable
    case noProcessedImage

    var errorDescription: String? {
        switch self {
        case .storageUnavailable:
            return "Image storage could not be opened."
        case .noProcessedImage:
            return "Rotate after the image finishes importing."
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var tagList: [String] {
        split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
