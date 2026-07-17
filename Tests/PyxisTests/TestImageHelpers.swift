import XCTest
@testable import PyxisCore

func makeTestImage(color: PyxisColor = .white, size: CGSize = CGSize(width: 12, height: 12)) -> PyxisImage {
    #if canImport(UIKit)
    UIGraphicsImageRenderer(size: size).image { context in
        color.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
    #elseif canImport(AppKit)
    let image = NSImage(size: size)
    image.lockFocus()
    color.setFill()
    CGRect(origin: .zero, size: size).fill()
    image.unlockFocus()
    return image
    #endif
}

extension PyxisImage {
    var cgImageForTests: CGImage? {
        #if canImport(UIKit)
        cgImage
        #elseif canImport(AppKit)
        var proposedRect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &proposedRect, context: nil, hints: nil)
        #endif
    }

    func pngDataForTests() -> Data? {
        ImageUtilities.pngData(from: self)
    }

    func jpegDataForTests() -> Data? {
        ImageUtilities.jpegData(from: self)
    }
}
