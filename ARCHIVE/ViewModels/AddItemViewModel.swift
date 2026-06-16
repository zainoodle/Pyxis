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

    private let imageStorage: ImageStorageService
    private let backgroundRemovalService: BackgroundRemovalServiceProtocol
    private let colorAnalysisService: ColorAnalysisService
    private let classificationService: ClothingClassificationService

    init() {
        do {
            let storage = try ImageStorageService()
            self.imageStorage = storage
            self.backgroundRemovalService = LocalBackgroundRemovalService(imageStorage: storage)
            self.colorAnalysisService = ColorAnalysisService()
            self.classificationService = ClothingClassificationService()
        } catch {
            fatalError("Failed to create image services: \(error)")
        }
    }

    init(
        imageStorage: ImageStorageService,
        backgroundRemovalService: BackgroundRemovalServiceProtocol,
        colorAnalysisService: ColorAnalysisService = ColorAnalysisService(),
        classificationService: ClothingClassificationService = ClothingClassificationService()
    ) {
        self.imageStorage = imageStorage
        self.backgroundRemovalService = backgroundRemovalService
        self.colorAnalysisService = colorAnalysisService
        self.classificationService = classificationService
    }

    func selectImage(_ url: URL) {
        selectedImageURL = url
        stage = .selected
        let classification = classificationService.classify(filename: url.lastPathComponent)
        updateCategory(classification.category, preferredSubtype: classification.subtype)
        classificationConfidence = classification.confidence
        if let colorHint = colorAnalysisService.colorHint(filename: url.lastPathComponent) {
            primaryColor = colorHint.primaryColor
            colorConfidence = colorHint.confidence
        }
    }

    func updateCategory(_ newCategory: ClothingCategory, preferredSubtype: ClothingSubtype? = nil) {
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

    func makeClosetItem(existingCodes: Set<String>) -> ClosetItem? {
        guard let result, !result.originalPath.isEmpty else {
            return nil
        }

        let code = ItemCodeGenerator.generate(
            for: subtype,
            category: category,
            existingCodes: existingCodes
        )

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

    private func analysisURL(from result: BackgroundRemovalResult) -> URL? {
        if let cutoutPath = result.cutoutPath {
            return imageStorage.url(for: cutoutPath)
        }
        guard !result.originalPath.isEmpty else {
            return nil
        }
        return imageStorage.url(for: result.originalPath)
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
