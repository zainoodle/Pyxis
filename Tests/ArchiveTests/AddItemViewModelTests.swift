import XCTest
@testable import ArchiveCore

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
        await viewModel.processSelectedImage(itemID: UUID(uuidString: "00000000-0000-0000-0000-000000000042")!)
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
            color: ArchiveColor(red: 1, green: 1, blue: 1, alpha: 0),
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
            .appendingPathComponent("ARCHIVE-\(UUID().uuidString)", isDirectory: true)
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
        color: ArchiveColor = ArchiveColor(red: 0.02, green: 0.05, blue: 0.22, alpha: 1),
        format: TestImageFormat = .jpeg
    ) throws -> URL {
        let url = root.appendingPathComponent(name)
        let image = makeTestImage(color: color)
        let data = try XCTUnwrap(format == .jpeg ? image.jpegDataForTests() : image.pngDataForTests())
        try data.write(to: url)
        return url
    }
}
