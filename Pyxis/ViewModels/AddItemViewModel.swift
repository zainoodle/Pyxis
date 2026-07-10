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

    private let imageStorage: ImageStorageService?
    private let backgroundRemovalService: (any BackgroundRemovalServiceProtocol)?
    private let colorAnalysisService: ColorAnalysisService
    private let classificationService: any ClothingClassificationProviding
    private var userAdjustedClassification = false

    init() {
        do {
            let storage = try ImageStorageService()
            self.imageStorage = storage
            self.backgroundRemovalService = LocalBackgroundRemovalService(imageStorage: storage)
            self.colorAnalysisService = ColorAnalysisService()
            self.classificationService = ClothingClassificationService()
        } catch {
            self.imageStorage = nil
            self.backgroundRemovalService = nil
            self.colorAnalysisService = ColorAnalysisService()
            self.classificationService = ClothingClassificationService()
            self.setupError = "Image storage could not be opened."
        }
    }

    init(
        imageStorage: ImageStorageService,
        backgroundRemovalService: BackgroundRemovalServiceProtocol,
        colorAnalysisService: ColorAnalysisService = ColorAnalysisService(),
        classificationService: any ClothingClassificationProviding = ClothingClassificationService()
    ) {
        self.imageStorage = imageStorage
        self.backgroundRemovalService = backgroundRemovalService
        self.colorAnalysisService = colorAnalysisService
        self.classificationService = classificationService
    }

    func selectImage(_ url: URL) {
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

    func processSelectedImage(itemID: UUID = UUID()) async {
        guard let selectedImageURL else {
            return
        }
        guard let backgroundRemovalService else {
            stage = .failed(setupError ?? "Image storage could not be opened.")
            return
        }

        stage = .processing
        let processingStartedAt = Date()
        let processed = await backgroundRemovalService.processImage(
            at: selectedImageURL,
            itemID: itemID
        )
        result = processed

        if let analysisURL = analysisURL(from: processed),
           let analysis = try? colorAnalysisService.analyze(imageURL: analysisURL),
           analysis.primaryColor != .unknown,
           analysis.confidence > 0 {
            primaryColor = analysis.primaryColor
            colorConfidence = analysis.confidence
        }

        if let analysisURL = analysisURL(from: processed), !userAdjustedClassification {
            let classification = classificationService.classify(
                imageURL: analysisURL,
                filename: selectedImageURL.lastPathComponent
            )
            if classification.confidence > classificationConfidence {
                applyAutomaticClassification(classification)
            }
        }

        let elapsed = Date().timeIntervalSince(processingStartedAt)
        let minimumRevealDuration: TimeInterval = 1.15
        if elapsed < minimumRevealDuration {
            try? await Task.sleep(nanoseconds: UInt64((minimumRevealDuration - elapsed) * 1_000_000_000))
        }

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

    func rotateProcessedImage(_ direction: ImageUtilities.RotationDirection) throws {
        guard let imageStorage else {
            throw AddItemImageEditingError.storageUnavailable
        }
        guard let result, !result.originalPath.isEmpty else {
            throw AddItemImageEditingError.noProcessedImage
        }

        let rotatedImageSet = try imageStorage.rotateImages(
            StoredImageSet(
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
