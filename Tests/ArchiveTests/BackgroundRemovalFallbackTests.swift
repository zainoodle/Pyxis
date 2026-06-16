import XCTest
@testable import ArchiveCore

final class BackgroundRemovalFallbackTests: XCTestCase {
    func testFailurePreservesOriginalAndAllowsSaveWithoutCutout() async throws {
        let root = try makeTemporaryRoot()
        let source = try makeImageFile(named: "source.jpg", root: root)
        let storage = try ImageStorageService(rootURL: root)
        let service = FailingBackgroundRemovalService(imageStorage: storage)

        let result = await service.processImage(at: source, itemID: UUID())

        XCTAssertEqual(result.status, .failed)
        XCTAssertFalse(result.originalPath.isEmpty)
        XCTAssertNil(result.cutoutPath)
        XCTAssertEqual(result.errorMessage, "Background removal failed — retry")
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.url(for: result.originalPath).path))
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

    private func makeImageFile(named name: String, root: URL) throws -> URL {
        let url = root.appendingPathComponent(name)
        let data = try XCTUnwrap(makeTestImage().jpegDataForTests())
        try data.write(to: url)
        return url
    }
}
