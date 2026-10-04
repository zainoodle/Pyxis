import CoreGraphics
import Foundation

/// Positions the accepted bitmap with one uniform scale, reserving its full sway envelope.
enum GarmentRackGeometry {
    static let hookY: CGFloat = 31
    static let supportDrop: CGFloat = 53
    static let clipSupportDrop: CGFloat = 44
    /// Pieces that cannot honestly hang rest on an implied shelf at this depth.
    static let shelfFraction: CGFloat = 0.82

    static func imageFrame(displaySize: CGSize, attachment: CGPoint, in container: CGSize,
                           drop: CGFloat = supportDrop) -> CGRect {
        guard displaySize.width > 0, displaySize.height > 0,
              container.width > 0, container.height > hookY + drop + 18 else { return .zero }
        let radians = CGFloat(ClosetRackSway.maximumAngle)
        let sine = sin(radians), cosine = cos(radians)
        let midX = min(1, max(0, attachment.x))
        let topY = min(1, max(0, attachment.y))
        let halfWidth = displaySize.width * max(midX, 1 - midX)
        let lowerHeight = displaySize.height * (1 - topY)
        let horizontalFit = (container.width / 2 - 10 - drop * sine)
            / (halfWidth * cosine + lowerHeight * sine)
        let verticalFit = (container.height - 18 - hookY - drop * cosine)
            / (lowerHeight * cosine + halfWidth * sine)
        let upperHeight = displaySize.height * topY
        let upperFit = (hookY + drop * cosine) / max(1, upperHeight * cosine + halfWidth * sine)
        let scale = max(0, min(1, horizontalFit, verticalFit, upperFit))
        let size = CGSize(width: displaySize.width * scale, height: displaySize.height * scale)
        return CGRect(x: container.width / 2 - midX * size.width,
                      y: hookY + drop - topY * size.height,
                      width: size.width, height: size.height)
    }
}
