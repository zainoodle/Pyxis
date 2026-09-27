import CoreImage
import CoreML
import CoreVideo
import Foundation

/// Runs the bundled SAM 2 models locally. The actor serializes inference and reuses loaded models.
actor SAMGarmentSegmenter {
    static let shared = SAMGarmentSegmenter()
    private let modelDirectory: URL?
    private var models: Models?
    private let context = CIContext()

    init(modelDirectory: URL? = nil) {
        self.modelDirectory = modelDirectory
    }

    func mask(for image: CIImage, foregroundHint: CIImage?) throws -> CIImage {
        let models = try loadedModels()
        let points = try automaticPoints(for: image, hint: foregroundHint)
        guard points.count >= 3 else { throw BackgroundRemovalError.noForegroundMask }
        let inputImage = try imageBuffer(image)
        let features = try models.image.prediction(from: MLDictionaryFeatureProvider(
            dictionary: ["image": MLFeatureValue(pixelBuffer: inputImage)]
        ))
        let coordinates = try MLMultiArray(shape: [1, NSNumber(value: points.count), 2], dataType: .float16)
        let labels = try MLMultiArray(shape: [1, NSNumber(value: points.count)], dataType: .float16)
        for (index, point) in points.enumerated() {
            coordinates[index * 2] = NSNumber(value: Double(point.x) * 1024)
            coordinates[index * 2 + 1] = NSNumber(value: Double(point.y) * 1024)
            labels[index] = 1
        }
        let prompts = try models.prompt.prediction(from: MLDictionaryFeatureProvider(
            dictionary: ["points": coordinates, "labels": labels]
        ))
        var inputs = [String: MLFeatureValue]()
        for name in ["image_embedding", "feats_s0", "feats_s1"] {
            guard let value = features.featureValue(for: name) else { throw BackgroundRemovalError.noForegroundMask }
            inputs[name] = value
        }
        guard let sparse = prompts.featureValue(for: "sparse_embeddings"),
              let dense = prompts.featureValue(for: "dense_embeddings") else {
            throw BackgroundRemovalError.noForegroundMask
        }
        inputs["sparse_embedding"] = sparse
        inputs["dense_embedding"] = dense
        let output = try models.decoder.prediction(from: MLDictionaryFeatureProvider(dictionary: inputs))
        guard let scores = output.featureValue(for: "scores")?.multiArrayValue,
              let masks = output.featureValue(for: "low_res_masks")?.multiArrayValue,
              masks.shape.count == 4, masks.shape[1].intValue == scores.count else {
            throw BackgroundRemovalError.noForegroundMask
        }
        let width = masks.shape[3].intValue, height = masks.shape[2].intValue
        // Predicted mask quality chooses among whole-object and part masks. Reject weak results.
        let ranked = (0..<scores.count).sorted { scores[$0].doubleValue > scores[$1].doubleValue }
        for candidate in ranked where scores[candidate].doubleValue >= 0.75 {
            var logits = [Float](repeating: 0, count: width * height)
            for y in 0..<height {
                for x in 0..<width {
                    let offset = candidate * masks.strides[1].intValue
                        + y * masks.strides[2].intValue + x * masks.strides[3].intValue
                    logits[y * width + x] = masks[offset].floatValue
                }
            }
            guard let cleaned = GarmentMaskRefinement.cleanedLogits(logits, width: width, height: height),
                  containsPrompts(cleaned, width: width, height: height, points: points) else { continue }
            let mask = try maskImage(cleaned, width: width, height: height, size: image.extent.size)
            guard let stats = BackgroundMaskInstanceStats(instance: candidate, maskImage: mask, ciContext: context),
                  BackgroundMaskCandidateSelector.preferredCandidateIndex(from: [stats]) != nil else { continue }
            return mask
        }
        throw BackgroundRemovalError.noForegroundMask
    }

    private func containsPrompts(_ logits: [Float], width: Int, height: Int, points: [CGPoint]) -> Bool {
        points.allSatisfy {
            let x = min(width - 1, max(0, Int($0.x * CGFloat(width))))
            let y = min(height - 1, max(0, Int($0.y * CGFloat(height))))
            return logits[y * width + x] > 0
        }
    }

    private func automaticPoints(for image: CIImage, hint: CIImage?) throws -> [CGPoint] {
        guard let hint else {
            return [CGPoint(x: 0.4, y: 0.5), CGPoint(x: 0.6, y: 0.5), CGPoint(x: 0.5, y: 0.7)]
        }
        let side = 256
        let resized = hint.transformed(by: CGAffineTransform(
            scaleX: CGFloat(side) / image.extent.width, y: CGFloat(side) / image.extent.height
        ))
        guard let cgImage = context.createCGImage(resized, from: CGRect(x: 0, y: 0, width: side, height: side)) else {
            throw BackgroundRemovalError.noForegroundMask
        }
        var bytes = [UInt8](repeating: 0, count: side * side)
        let rendered = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let bitmap = CGContext(data: buffer.baseAddress, width: side, height: side,
                                         bitsPerComponent: 8, bytesPerRow: side,
                                         space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0) else { return false }
            bitmap.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard rendered else { throw BackgroundRemovalError.noForegroundMask }
        return GarmentMaskRefinement.promptPoints(mask: bytes, width: side, height: side)
    }

    private func imageBuffer(_ image: CIImage) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let result = CVPixelBufferCreate(kCFAllocatorDefault, 1024, 1024, kCVPixelFormatType_32BGRA,
                                        [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer)
        guard result == kCVReturnSuccess, let buffer else { throw BackgroundRemovalError.couldNotLoadImage }
        let resized = image.transformed(by: CGAffineTransform(scaleX: 1024 / image.extent.width,
                                                              y: 1024 / image.extent.height))
        context.render(resized, to: buffer, bounds: CGRect(x: 0, y: 0, width: 1024, height: 1024),
                       colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        return buffer
    }

    private func maskImage(_ logits: [Float], width: Int, height: Int, size: CGSize) throws -> CIImage {
        // Interpolate logits before thresholding; thresholding at 256px makes full-size edges blocky.
        let bytes = logits.map { UInt8((max(0, min(1, ($0 + 16) / 32)) * 255).rounded()) }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let cgImage = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8,
                                    bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: [],
                                    provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else {
            throw BackgroundRemovalError.noForegroundMask
        }
        let scaled = CIImage(cgImage: cgImage, options: [.colorSpace: NSNull()])
            .transformed(by: CGAffineTransform(scaleX: size.width / CGFloat(width), y: size.height / CGFloat(height)))
        return scaled.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 32, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 32, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 32, w: 0),
            "inputBiasVector": CIVector(x: -15.5, y: -15.5, z: -15.5, w: 0)
        ]).applyingFilter("CIColorClamp", parameters: [
            "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
        ])
    }

    private func loadedModels() throws -> Models {
        if let models { return models }
        func load(_ kind: String) throws -> MLModel {
            let name = "SAM2Tiny\(kind)FLOAT16"
            guard let url = modelDirectory?.appendingPathComponent(name + ".mlmodelc")
                ?? Bundle.main.url(forResource: name, withExtension: "mlmodelc") else {
                throw BackgroundRemovalError.modelUnavailable
            }
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .cpuAndGPU
            return try MLModel(contentsOf: url, configuration: configuration)
        }
        let loaded = try Models(image: load("ImageEncoder"), prompt: load("PromptEncoder"), decoder: load("MaskDecoder"))
        models = loaded
        return loaded
    }

    private struct Models {
        let image: MLModel
        let prompt: MLModel
        let decoder: MLModel
    }
}
