import CoreGraphics
import CoreImage
import Foundation

enum GarmentRackSupport: Sendable, Equatable {
    case shoulder
    case clips

    static func forCategory(_ category: ClothingCategory) -> Self? {
        switch category {
        case .tops, .outerwear, .onePiece: .shoulder
        case .bottoms: .clips
        case .footwear, .accessories, .other: nil
        }
    }
}

/// A conservative presentation hint, never anatomical metadata or a change to the photo.
/// Ambiguous silhouettes deliberately use the flat stage instead of an invented attachment.
struct GarmentRackAttachment: Sendable {
    let support: GarmentRackSupport
    let anchor: CGPoint
    let span: CGFloat

    static func analyze(_ image: CGImage, support: GarmentRackSupport, context: CIContext) -> Self? {
        let scale = min(1, 192 / CGFloat(max(image.width, image.height)))
        let width = max(1, Int(CGFloat(image.width) * scale))
        let height = max(1, Int(CGFloat(image.height) * scale))
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        context.render(CIImage(cgImage: image).transformed(by: CGAffineTransform(scaleX: scale, y: scale)),
                       toBitmap: &rgba, rowBytes: width * 4,
                       bounds: CGRect(x: 0, y: 0, width: width, height: height),
                       format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        // Bitmap rows follow CGImage order (top first), matching SwiftUI image coordinates.
        let alpha = (0..<height).flatMap { y in
            (0..<width).map { x in rgba[(y * width + x) * 4 + 3] }
        }
        return analyze(alpha: alpha, width: width, height: height, support: support)
    }

    static func analyze(alpha: [UInt8], width: Int, height: Int, support: GarmentRackSupport) -> Self? {
        guard width >= 16, height >= 16, alpha.count == width * height else { return nil }
        var left = width, right = -1, top = height, bottom = -1
        var visible = 0, solid = 0
        for y in 0..<height {
            for x in 0..<width where alpha[y * width + x] > 32 {
                left = min(left, x); right = max(right, x)
                top = min(top, y); bottom = max(bottom, y)
                visible += 1
                if alpha[y * width + x] >= 230 { solid += 1 }
            }
        }
        guard visible > 0, Double(solid) / Double(visible) > 0.94,
              left > 0, right < width - 1, top > 0, bottom < height - 1 else { return nil }
        let w = right - left + 1, h = bottom - top + 1
        guard w > 14, h > 20 else { return nil }
        func x(_ fraction: Double) -> Int { left + Int(Double(w - 1) * fraction) }
        func firstSolid(_ column: Int) -> Int? {
            (top...bottom).first { alpha[$0 * width + column] >= 230 }
        }
        func opaquePatch(x: Int, y: Int) -> Bool {
            let radius = max(1, w / 45), depth = max(3, h / 12)
            let start = max(2, radius)
            guard depth >= start, x - radius >= 0, x + radius < width, y + depth < height else { return false }
            return (y + start...y + depth).allSatisfy { row in
                (x - radius...x + radius).allSatisfy { alpha[row * width + $0] >= 230 }
            }
        }
        // Require two broad, nearly level supports, a centered silhouette, and opaque cloth.
        // This rejects diagonal/one-shoulder poses, straps, holes, and translucent fabric.
        let lx = x(support == .shoulder ? 0.26 : 0.22)
        let rx = x(support == .shoulder ? 0.74 : 0.78)
        guard let ly = firstSolid(lx), let ry = firstSolid(rx),
              abs(ly - ry) <= max(2, h / 40),
              max(ly, ry) - top < max(4, h / 8),
              opaquePatch(x: lx, y: ly), opaquePatch(x: rx, y: ry) else { return nil }
        let contactY = (ly + ry) / 2
        if support == .shoulder {
            guard let neckY = firstSolid(x(0.5)),
                  let leftNeck = firstSolid(x(0.4)), let rightNeck = firstSolid(x(0.6)),
                  abs(leftNeck - rightNeck) <= max(2, h / 40),
                  neckY - max(leftNeck, rightNeck) >= max(2, h / 100),
                  neckY - min(leftNeck, rightNeck) <= h / 5 else { return nil }
            // A broad shoulder line must persist on either side of the neckline.
            for column in [x(0.22), x(0.34), x(0.66), x(0.78)] {
                guard let y = firstSolid(column), abs(y - contactY) < max(4, h / 10),
                      opaquePatch(x: column, y: y) else { return nil }
            }
        } else {
            let waistY = max(ly, ry) + max(2, h / 40)
            guard waistY < height,
                  (lx...rx).allSatisfy({ alpha[waistY * width + $0] >= 230 }) else { return nil }
        }
        return Self(support: support,
                    anchor: CGPoint(x: CGFloat(lx + rx) / 2 / CGFloat(width),
                                    y: CGFloat(contactY) / CGFloat(height)),
                    span: CGFloat(rx - lx) / CGFloat(width))
    }
}
