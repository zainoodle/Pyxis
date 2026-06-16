import XCTest
@testable import PyxisCore

final class ImageStorageTests: XCTestCase {
    func testCreatesImageDirectories() throws {
        let root = try makeTemporaryRoot()
        let storage = try ImageStorageService(rootURL: root)

        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.originalsURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.cutoutsURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.thumbnailsURL.path))
    }

    func testSavesOriginalWithRelativePath() throws {
        let root = try makeTemporaryRoot()
        let source = try makeImageFile(named: "source.jpg", root: root)
        let storage = try ImageStorageService(rootURL: root)
        let itemID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        let path = try storage.saveOriginal(from: source, itemID: itemID)

        XCTAssertEqual(path, "Images/Originals/\(itemID.uuidString).jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.url(for: path).path))
    }

    func testSavesCutoutAndThumbnailPNGs() throws {
        let root = try makeTemporaryRoot()
        let storage = try ImageStorageService(rootURL: root)
        let itemID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let data = try XCTUnwrap(makeTestImage().pngDataForTests())

        let cutout = try storage.saveCutoutPNG(data, itemID: itemID)
        let thumbnail = try storage.saveThumbnailPNG(data, itemID: itemID)

        XCTAssertEqual(cutout, "Images/Cutouts/\(itemID.uuidString).png")
        XCTAssertEqual(thumbnail, "Images/Thumbnails/\(itemID.uuidString).png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.url(for: cutout).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.url(for: thumbnail).path))
    }

    func testDeletesRelatedImageFiles() throws {
        let root = try makeTemporaryRoot()
        let storage = try ImageStorageService(rootURL: root)
        let itemID = UUID()
        let data = try XCTUnwrap(makeTestImage().pngDataForTests())
        let originalSource = try makeImageFile(named: "source.jpg", root: root)
        let imageSet = StoredImageSet(
            originalPath: try storage.saveOriginal(from: originalSource, itemID: itemID),
            cutoutPath: try storage.saveCutoutPNG(data, itemID: itemID),
            thumbnailPath: try storage.saveThumbnailPNG(data, itemID: itemID)
        )

        storage.deleteImages(imageSet)

        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.url(for: imageSet.originalPath).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.url(for: imageSet.cutoutPath!).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.url(for: imageSet.thumbnailPath!).path))
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

    private func makeImageFile(named name: String, root: URL) throws -> URL {
        let url = root.appendingPathComponent(name)
        let data = try XCTUnwrap(makeTestImage().jpegDataForTests())
        try data.write(to: url)
        return url
    }
}
