import CoreImage
import Foundation

enum GarmentPhotoRefinementService {
    /// Tighten the matte by less than a source pixel, then feather it at output resolution.
    /// This removes the weak background rim without flattening fabric or filling openings.
    static func refinedMask(_ mask: CIImage, extent: CGRect) -> CIImage {
        let radius = min(1, max(0.35, max(extent.width, extent.height) / 2_400))
        return mask.clampedToExtent()
            .applyingFilter("CIMorphologyMinimum", parameters: ["inputRadius": radius])
            .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": radius * 0.55])
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1.04, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 1.04, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 1.04, w: 0),
                "inputBiasVector": CIVector(x: -0.04, y: -0.04, z: -0.04, w: 0)
            ])
            .applyingFilter("CIColorClamp")
            .cropped(to: extent)
    }

    /// Local, conservative smoothing of small luminance variations. It cannot reconstruct
    /// a heavily folded garment. Always derive from the natural cutout, never a prior pass.
    static func softenedCreasesPNG(from data: Data, using context: CIContext = CIContext()) throws -> Data {
        guard let source = CIImage(data: data, options: [.applyOrientationProperty: true]),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw BackgroundRemovalError.couldNotLoadImage
        }
        let matte = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: source.extent)
        let opaque = source.composited(over: matte)
        let softened = opaque.clampedToExtent()
            .applyingFilter("CINoiseReduction", parameters: ["inputNoiseLevel": 0.045, "inputSharpness": 0.3])
            .cropped(to: source.extent)
        // Large changes signal a seam, print, button, or edge. Keep those source pixels.
        let detailMask = opaque.applyingFilter("CIDifferenceBlendMode", parameters: [kCIInputBackgroundImageKey: softened])
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 17, y: 57, z: 6, w: 0),
                "inputGVector": CIVector(x: 17, y: 57, z: 6, w: 0),
                "inputBVector": CIVector(x: 17, y: 57, z: 6, w: 0)
            ])
            .applyingFilter("CIColorClamp")
        let protected = opaque.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputMaskImageKey: detailMask, kCIInputBackgroundImageKey: softened
        ])
        // Reapply the exact source alpha; smoothing must not reintroduce a matte or halo.
        let output = protected.applyingFilter("CIBlendWithAlphaMask", parameters: [
            kCIInputMaskImageKey: source,
            kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: source.extent)
        ])
        guard let png = context.pngRepresentation(of: output, format: .RGBA8, colorSpace: colorSpace) else {
            throw BackgroundRemovalError.couldNotEncodeCutout
        }
        return png
    }
}
