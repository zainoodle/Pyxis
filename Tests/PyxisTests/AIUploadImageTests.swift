import ImageIO
import XCTest
@testable import PyxisCore

final class AIUploadImageTests: XCTestCase {
    func testUploadImageIsBoundedJPEGWithoutSourceMetadata() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("Pyxis-AI-upload-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }

        let sourceURL = root.appendingPathComponent("source.jpg")
        let image = try XCTUnwrap(makeTestImage(size: CGSize(width: 2400, height: 1200)).cgImageForTests)
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithURL(sourceURL as CFURL, "public.jpeg" as CFString, 1, nil)
        )
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "private metadata"]] as CFDictionary
        )
        XCTAssertTrue(CGImageDestinationFinalize(destination))

        let data = try ImageUtilities.aiUploadJPEGData(from: sourceURL, maxPixelSize: 600)
        let output = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(output, 0, nil) as? [CFString: Any])
        let width = try XCTUnwrap(properties[kCGImagePropertyPixelWidth] as? NSNumber)
        let height = try XCTUnwrap(properties[kCGImagePropertyPixelHeight] as? NSNumber)
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]

        XCTAssertLessThanOrEqual(max(width.intValue, height.intValue), 600)
        XCTAssertNil(exif?[kCGImagePropertyExifUserComment])
        XCTAssertEqual(data.prefix(3), Data([0xff, 0xd8, 0xff]))
    }
}
