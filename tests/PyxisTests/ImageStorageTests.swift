import XCTest
import CoreImage
import ImageIO
@testable import PyxisCore

final class ImageStorageTests: XCTestCase {
    func testRotationHonorsEXIFOrientationAndPreservesJPEGEncoding() throws {
        let width = 40, height = 60
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                pixels[i + (x < width / 2 && y < height / 2 ? 0 : 2)] = 255
                pixels[i + 3] = 255
            }
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        for orientation in [6, 8, 2] {
            let bytes = NSMutableData()
            let destination = CGImageDestinationCreateWithData(bytes, "public.jpeg" as CFString, 1, nil)!
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
            XCTAssertTrue(CGImageDestinationFinalize(destination))
            let rotated = try ImageUtilities.rotatedImageData(from: bytes as Data, direction: .clockwise, jpegEncoding: true)
            let source = try XCTUnwrap(CGImageSourceCreateWithData(rotated as CFData, nil))
            XCTAssertEqual(CGImageSourceGetType(source) as String?, "public.jpeg")
            let result = try XCTUnwrap(CIImage(data: rotated, options: [.applyOrientationProperty: true]))
            XCTAssertEqual(result.extent.width, CGFloat(orientation == 2 ? height : width))
            XCTAssertEqual(result.extent.height, CGFloat(orientation == 2 ? width : height))
            var rgba = [UInt8](repeating: 0, count: Int(result.extent.width * result.extent.height) * 4)
            CIContext().render(result, toBitmap: &rgba, rowBytes: Int(result.extent.width) * 4,
                               bounds: result.extent, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
            let x = Int(result.extent.width) * (orientation == 8 ? 1 : 3) / 4
            let y = Int(result.extent.height) * (orientation == 8 ? 1 : 3) / 4
            let offset = (y * Int(result.extent.width) + x) * 4
            XCTAssertGreaterThan(rgba[offset], 180, "Red corner lost for EXIF \(orientation)")
            XCTAssertLessThan(rgba[offset + 2], 70)
        }
    }

    func testRotationFailurePreservesAcceptedOriginalAndThumbnail() throws {
        let root = try makeTemporaryRoot()
        let storage = try ImageStorageService(rootURL: root)
        let id = UUID()
        let source = try makeImageFile(named: "original.png", root: root)
        let original = try storage.saveOriginal(from: source, itemID: id)
        let thumbnail = try storage.makeThumbnail(from: source, itemID: id)
        let before = try Data(contentsOf: storage.url(for: original))
        let thumbBefore = try Data(contentsOf: storage.url(for: thumbnail))
        let set = StoredImageSet(itemID: id, originalPath: original,
                                 cutoutPath: "Images/Cutouts/missing.png", thumbnailPath: thumbnail)
        XCTAssertThrowsError(try storage.rotateImages(set, direction: .clockwise))
        XCTAssertEqual(try Data(contentsOf: storage.url(for: original)), before)
        XCTAssertEqual(try Data(contentsOf: storage.url(for: thumbnail)), thumbBefore)
    }

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
            itemID: itemID,
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

        storage.deleteImages(
            StoredImageSet(itemID: UUID(), originalPath: "../\(outsideURL.lastPathComponent)")
        )

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
