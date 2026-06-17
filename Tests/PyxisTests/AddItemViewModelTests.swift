import XCTest
@testable import PyxisCore

@MainActor
final class AddItemViewModelTests: XCTestCase {
    func testPersistsClassificationAndColorConfidenceOnCreatedItem() async throws {
        let root = try makeTemporaryRoot()
        let source = try makeImageFile(named: "navy-cargo-pants.jpg", root: root)
        let storage = try ImageStorageService(rootURL: root)
        let backgroundRemoval = FailingBackgroundRemovalService(imageStorage: storage)
        let viewModel = AddItemViewModel(
            imageStorage: storage,
            backgroundRemovalService: backgroundRemoval
        )

        viewModel.selectImage(source)
        let itemID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000042"))
        await viewModel.processSelectedImage(itemID: itemID)
        let item = try XCTUnwrap(viewModel.makeClosetItem(existingCodes: []))

        XCTAssertEqual(item.category, .bottoms)
        XCTAssertEqual(item.subtype, .pants)
        XCTAssertGreaterThan(item.classificationConfidence ?? 0, 0)
        XCTAssertNotNil(item.colorConfidence)
    }

    func testUsesFilenameColorWhenImageAnalysisHasNoVisiblePixels() async throws {
        let root = try makeTemporaryRoot()
        let source = try makeImageFile(
            named: "black-hoodie.png",
            root: root,
            color: PyxisColor(red: 1, green: 1, blue: 1, alpha: 0),
            format: .png
        )
        let storage = try ImageStorageService(rootURL: root)
        let backgroundRemoval = FailingBackgroundRemovalService(imageStorage: storage)
        let viewModel = AddItemViewModel(
            imageStorage: storage,
            backgroundRemovalService: backgroundRemoval
        )

        viewModel.selectImage(source)
        await viewModel.processSelectedImage(itemID: UUID())
        let item = try XCTUnwrap(viewModel.makeClosetItem(existingCodes: []))

        XCTAssertEqual(item.primaryColor, .black)
        XCTAssertGreaterThan(item.colorConfidence ?? 0, 0)
    }

    func testSelectingNewImageWithoutColorHintClearsPreviousColorMetadata() throws {
        let root = try makeTemporaryRoot()
        let firstSource = try makeImageFile(named: "black-hoodie.png", root: root)
        let secondSource = try makeImageFile(named: "pyxis-import.png", root: root)
        let storage = try ImageStorageService(rootURL: root)
        let viewModel = AddItemViewModel(
            imageStorage: storage,
            backgroundRemovalService: FailingBackgroundRemovalService(imageStorage: storage)
        )

        viewModel.selectImage(firstSource)
        XCTAssertEqual(viewModel.primaryColor, .black)

        viewModel.selectImage(secondSource)

        XCTAssertEqual(viewModel.primaryColor, .unknown)
        XCTAssertEqual(viewModel.colorConfidence, 0)
    }

    func testKeepsConfidentImageColorOverFilenameColorHint() async throws {
        let root = try makeTemporaryRoot()
        let source = try makeImageFile(
            named: "black-shirt.jpg",
            root: root,
            color: .red,
            format: .jpeg
        )
        let storage = try ImageStorageService(rootURL: root)
        let backgroundRemoval = FailingBackgroundRemovalService(imageStorage: storage)
        let viewModel = AddItemViewModel(
            imageStorage: storage,
            backgroundRemovalService: backgroundRemoval
        )

        viewModel.selectImage(source)
        await viewModel.processSelectedImage(itemID: UUID())
        let item = try XCTUnwrap(viewModel.makeClosetItem(existingCodes: []))

        XCTAssertEqual(item.primaryColor, .red)
        XCTAssertGreaterThan(item.colorConfidence ?? 0, 0.9)
    }

    func testVisualClassificationRefinesFilenameMetadataAfterProcessing() async throws {
        let root = try makeTemporaryRoot()
        let source = try makeImageFile(named: "black-shirt.jpg", root: root)
        let storage = try ImageStorageService(rootURL: root)
        let viewModel = AddItemViewModel(
            imageStorage: storage,
            backgroundRemovalService: FailingBackgroundRemovalService(imageStorage: storage),
            classificationService: StubClassificationService(
                filenameResult: ClothingClassificationResult(
                    category: .tops,
                    subtype: .shirt,
                    confidence: 0.55
                ),
                imageResult: ClothingClassificationResult(
                    category: .bottoms,
                    subtype: .jeans,
                    confidence: 0.9
                )
            )
        )

        viewModel.selectImage(source)
        await viewModel.processSelectedImage(itemID: UUID())
        let item = try XCTUnwrap(viewModel.makeClosetItem(existingCodes: []))

        XCTAssertEqual(item.category, .bottoms)
        XCTAssertEqual(item.subtype, .jeans)
        XCTAssertEqual(item.classificationConfidence, 0.9)
    }

    func testManualClassificationEditPreventsVisualClassificationOverride() async throws {
        let root = try makeTemporaryRoot()
        let source = try makeImageFile(named: "black-shirt.jpg", root: root)
        let storage = try ImageStorageService(rootURL: root)
        let viewModel = AddItemViewModel(
            imageStorage: storage,
            backgroundRemovalService: FailingBackgroundRemovalService(imageStorage: storage),
            classificationService: StubClassificationService(
                filenameResult: ClothingClassificationResult(
                    category: .tops,
                    subtype: .shirt,
                    confidence: 0.55
                ),
                imageResult: ClothingClassificationResult(
                    category: .bottoms,
                    subtype: .jeans,
                    confidence: 0.9
                )
            )
        )

        viewModel.selectImage(source)
        viewModel.updateCategory(.accessories, preferredSubtype: .watch)
        await viewModel.processSelectedImage(itemID: UUID())
        let item = try XCTUnwrap(viewModel.makeClosetItem(existingCodes: []))

        XCTAssertEqual(item.category, .accessories)
        XCTAssertEqual(item.subtype, .watch)
        XCTAssertEqual(item.classificationConfidence, 0.55)
    }

    func testChangingCategoryResetsIncompatibleSubtype() throws {
        let root = try makeTemporaryRoot()
        let storage = try ImageStorageService(rootURL: root)
        let viewModel = AddItemViewModel(
            imageStorage: storage,
            backgroundRemovalService: FailingBackgroundRemovalService(imageStorage: storage)
        )
        viewModel.category = .accessories
        viewModel.subtype = .sunglasses

        viewModel.updateCategory(.bottoms)

        XCTAssertEqual(viewModel.category, .bottoms)
        XCTAssertEqual(viewModel.subtype, .pants)
    }

    private func makeTemporaryRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Pyxis-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private enum TestImageFormat {
        case jpeg
        case png
    }

    private func makeImageFile(
        named name: String,
        root: URL,
        color: PyxisColor = PyxisColor(red: 0.02, green: 0.05, blue: 0.22, alpha: 1),
        format: TestImageFormat = .jpeg
    ) throws -> URL {
        let url = root.appendingPathComponent(name)
        let image = makeTestImage(color: color)
        let data = try XCTUnwrap(format == .jpeg ? image.jpegDataForTests() : image.pngDataForTests())
        try data.write(to: url)
        return url
    }
}

private struct StubClassificationService: ClothingClassificationProviding {
    let filenameResult: ClothingClassificationResult
    let imageResult: ClothingClassificationResult

    func classify(filename: String?) -> ClothingClassificationResult {
        filenameResult
    }

    func classify(
        filename: String?,
        visualObservations: [ClothingVisualObservation]
    ) -> ClothingClassificationResult {
        imageResult
    }

    func classify(imageURL: URL, filename: String?) -> ClothingClassificationResult {
        imageResult
    }
}
