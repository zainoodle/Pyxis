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
        let itemID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))

        let path = try storage.saveOriginal(from: source, itemID: itemID)

        XCTAssertEqual(path, "Images/Originals/\(itemID.uuidString).jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.url(for: path).path))
    }

    func testResavingStoredOriginalDoesNotDeleteSource() throws {
        let root = try makeTemporaryRoot()
        let source = try makeImageFile(named: "source.jpg", root: root)
        let storage = try ImageStorageService(rootURL: root)
        let itemID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000009"))
        let path = try storage.saveOriginal(from: source, itemID: itemID)
        let storedURL = storage.url(for: path)
        let originalData = try Data(contentsOf: storedURL)

        let resavedPath = try storage.saveOriginal(from: storedURL, itemID: itemID)

        XCTAssertEqual(resavedPath, path)
        XCTAssertEqual(try Data(contentsOf: storedURL), originalData)
    }

    func testSavesCutoutAndThumbnailPNGs() throws {
        let root = try makeTemporaryRoot()
        let storage = try ImageStorageService(rootURL: root)
        let itemID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
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
        let cutoutPath = try XCTUnwrap(imageSet.cutoutPath)
        let thumbnailPath = try XCTUnwrap(imageSet.thumbnailPath)
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.url(for: cutoutPath).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.url(for: thumbnailPath).path))
    }

    func testURLForRelativePathCannotEscapeStorageRoot() throws {
        let root = try makeTemporaryRoot()
        let storage = try ImageStorageService(rootURL: root)

        let escaped = storage.url(for: "../outside.txt").standardizedFileURL
        let rootPath = root.standardizedFileURL.path

        XCTAssertTrue(escaped.path == rootPath || escaped.path.hasPrefix(rootPath + "/"))
    }

    func testDeleteImagesIgnoresPathsOutsideStorageRoot() throws {
        let root = try makeTemporaryRoot()
        let storage = try ImageStorageService(rootURL: root)
        let outsideURL = root.deletingLastPathComponent()
            .appendingPathComponent("pyxis-outside-\(UUID().uuidString).txt")
        try "keep".write(to: outsideURL, atomically: true, encoding: .utf8)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: outsideURL)
        }

        storage.deleteImages(StoredImageSet(originalPath: "../\(outsideURL.lastPathComponent)"))

        XCTAssertTrue(FileManager.default.fileExists(atPath: outsideURL.path))
    }

    func testRelativePathDoesNotTreatSiblingDirectoryAsNested() throws {
        let root = try makeTemporaryRoot()
        let storage = try ImageStorageService(rootURL: root)
        let siblingRoot = root.deletingLastPathComponent()
            .appendingPathComponent(root.lastPathComponent + "-sibling", isDirectory: true)
        let siblingFile = siblingRoot.appendingPathComponent("item.jpg")

        XCTAssertEqual(storage.relativePath(for: siblingFile), "item.jpg")
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
