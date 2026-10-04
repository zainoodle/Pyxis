import CoreImage
import XCTest
@testable import PyxisCore

final class GarmentPhotoRefinementTests: XCTestCase {
    private let context = CIContext(options: [.useSoftwareRenderer: true])

    func testSmoothingReducesFineVariationWithoutChangingPartialAlpha() throws {
        let size = 100
        var bytes = [UInt8](repeating: 0, count: size * size * 4)
        for y in 0..<size {
            for x in 0..<size {
                let offset = (y * size + x) * 4
                let value: UInt8 = (x + y).isMultiple(of: 2) ? 150 : 154
                bytes[offset] = value
                bytes[offset + 1] = value
                bytes[offset + 2] = value
                bytes[offset + 3] = x < 10 ? 128 : 255
            }
        }
        let source = CIImage(bitmapData: Data(bytes), bytesPerRow: size * 4,
                             size: CGSize(width: size, height: size), format: .RGBA8,
                             colorSpace: CGColorSpaceCreateDeviceRGB())
        let data = try XCTUnwrap(context.pngRepresentation(of: source, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()))
        let decoded = try XCTUnwrap(CIImage(data: data))
        let output = try XCTUnwrap(CIImage(data: GarmentPhotoRefinementService.softenedCreasesPNG(from: data, using: context)))
        let before = pixels(decoded), after = pixels(output)
        var originalVariation = 0, softenedVariation = 0
        for y in 20..<80 {
            for x in 20..<80 {
                let offset = (y * size + x) * 4
                originalVariation += abs(Int(before[offset]) - Int(before[offset + 4]))
                softenedVariation += abs(Int(after[offset]) - Int(after[offset + 4]))
            }
        }
        XCTAssertLessThan(softenedVariation, originalVariation)
        for index in stride(from: 3, to: before.count, by: 4) {
            XCTAssertEqual(before[index], after[index])
        }
    }

    func testSmoothingPreservesAlphaAndStrongDetails() throws {
        let extent = CGRect(x: 0, y: 0, width: 100, height: 100)
        let fabric = CIImage(color: CIColor(red: 0.6, green: 0.4, blue: 0.3))
            .cropped(to: CGRect(x: 20, y: 10, width: 60, height: 80))
        let seam = CIImage(color: .black).cropped(to: CGRect(x: 48, y: 20, width: 4, height: 60))
        let source = seam.composited(over: fabric)
            .composited(over: CIImage(color: .clear).cropped(to: extent))
        let data = try XCTUnwrap(context.pngRepresentation(of: source, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()))
        let result = try GarmentPhotoRefinementService.softenedCreasesPNG(from: data, using: context)
        let output = try XCTUnwrap(CIImage(data: result))
        XCTAssertEqual(output.extent, extent)
        let before = pixels(source), after = pixels(output)
        for index in stride(from: 3, to: before.count, by: 4) {
            XCTAssertEqual(before[index], after[index], "Alpha must stay unchanged")
        }
        XCTAssertLessThan(after[(50 * 100 + 50) * 4], 12, "Keep the contrasting seam")
        XCTAssertEqual(Int(after[(50 * 100 + 30) * 4]), Int(before[(50 * 100 + 30) * 4]), accuracy: 3)
    }

    func testMatteCleanupKeepsOpeningsAndThinDetailsOnBothBackgrounds() {
        let extent = CGRect(x: 0, y: 0, width: 100, height: 100)
        let body = CIImage(color: .white).cropped(to: CGRect(x: 20, y: 10, width: 60, height: 80))
        let gap = CIImage(color: .black).cropped(to: CGRect(x: 45, y: 35, width: 10, height: 30))
        let strap = CIImage(color: .white).cropped(to: CGRect(x: 78, y: 20, width: 4, height: 30))
        let mask = strap.composited(over: gap.composited(over: body))
            .composited(over: CIImage(color: .black).cropped(to: extent))
        let refined = GarmentPhotoRefinementService.refinedMask(mask, extent: extent)
        let values = pixels(refined)
        XCTAssertGreaterThan(values[(65 * 100 + 80) * 4], 240)
        XCTAssertLessThan(values[(50 * 100 + 50) * 4], 5)
        XCTAssertLessThan(values[(5 * 100 + 5) * 4], 5)
        for background in [CIColor.white, CIColor.black] {
            let cutout = CIImage(color: CIColor(red: 0.6, green: 0.4, blue: 0.3)).cropped(to: extent)
                .applyingFilter("CIBlendWithMask", parameters: [
                    kCIInputMaskImageKey: refined,
                    kCIInputBackgroundImageKey: CIImage(color: background).cropped(to: extent)
                ])
            let sample = pixels(cutout)
            XCTAssertEqual(sample[(5 * 100 + 5) * 4], background == .white ? 255 : 0)
        }
    }

    func testTransparentImportKeepsTwoPiecesWithoutRequiringModelInference() async throws {
        let extent = CGRect(x: 0, y: 0, width: 100, height: 100)
        let left = CIImage(color: .white).cropped(to: CGRect(x: 10, y: 20, width: 25, height: 60))
        let right = CIImage(color: .white).cropped(to: CGRect(x: 65, y: 20, width: 25, height: 60))
        let source = left.composited(over: right).composited(over: CIImage(color: .clear).cropped(to: extent))
        let data = try XCTUnwrap(context.pngRepresentation(of: source, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        defer { try? FileManager.default.removeItem(at: url) }
        try data.write(to: url)
        let result = try await LocalBackgroundRemovalService.makeTransparentCutoutPNG(from: url, ciContext: context)
        let output = try XCTUnwrap(CIImage(data: result))
        let analysis = try XCTUnwrap(GarmentImageFraming.analyze(output, using: context))
        XCTAssertGreaterThan(analysis.visibleRect.width, 75)
        XCTAssertEqual(analysis.visibleRect.height, 60, accuracy: 2)
        XCTAssertLessThan(analysis.fillFraction, 0.7)
    }

    private func pixels(_ image: CIImage) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: Int(image.extent.width * image.extent.height) * 4)
        context.render(image, toBitmap: &bytes, rowBytes: Int(image.extent.width) * 4,
                       bounds: image.extent, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return bytes
    }
}
