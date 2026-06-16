#if DEBUG
import SwiftData
import UIKit

@MainActor
enum DebugClosetSeedService {
    struct SeedResult {
        let insertedCount: Int
    }

    private struct SampleItem {
        let code: String
        let name: String
        let category: ClothingCategory
        let subtype: ClothingSubtype
        let color: ClosetColor
        let tags: [String]
    }

    static func seedCloset(in context: ModelContext, existingItems: [ClosetItem]) throws -> SeedResult {
        let existingCodes = Set(existingItems.map(\.itemCode))
        let storage = try ImageStorageService()
        var insertedCount = 0

        for sample in samples where !existingCodes.contains(sample.code) {
            let itemID = UUID()
            let image = renderSampleImage(for: sample)
            guard let imageData = image.pngData() else {
                continue
            }

            let temporaryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("ARCHIVE-seed-\(itemID.uuidString).png")
            try imageData.write(to: temporaryURL, options: .atomic)

            let originalPath = try storage.saveOriginal(from: temporaryURL, itemID: itemID)
            let cutoutPath = try storage.saveCutoutPNG(imageData, itemID: itemID)
            let thumbnailPath = try storage.saveThumbnailPNG(imageData, itemID: itemID)
            try? FileManager.default.removeItem(at: temporaryURL)

            let item = ClosetItem(
                id: itemID,
                itemCode: sample.code,
                displayName: sample.name,
                category: sample.category,
                subtype: sample.subtype,
                primaryColor: sample.color,
                tags: sample.tags,
                notes: "Debug seed item for local outfit-building tests.",
                brand: "ARCHIVE",
                size: "M",
                favorite: sample.tags.contains("favorite"),
                imageOriginalPath: originalPath,
                imageCutoutPath: cutoutPath,
                thumbnailPath: thumbnailPath,
                source: .owned
            )
            context.insert(item)
            insertedCount += 1
        }

        if insertedCount > 0 {
            try context.save()
        }
        return SeedResult(insertedCount: insertedCount)
    }

    private static var samples: [SampleItem] {
        [
            SampleItem(code: "DEMO-TS-001", name: "White tee", category: .tops, subtype: .tShirt, color: .white, tags: ["daily", "favorite"]),
            SampleItem(code: "DEMO-HD-001", name: "Black hoodie", category: .tops, subtype: .hoodie, color: .black, tags: ["winter"]),
            SampleItem(code: "DEMO-SW-001", name: "Gray sweater", category: .tops, subtype: .sweater, color: .gray, tags: ["layer"]),
            SampleItem(code: "DEMO-SH-001", name: "Blue shirt", category: .tops, subtype: .shirt, color: .blue, tags: ["work"]),
            SampleItem(code: "DEMO-JE-001", name: "Blue jeans", category: .bottoms, subtype: .jeans, color: .blue, tags: ["daily", "favorite"]),
            SampleItem(code: "DEMO-PA-001", name: "Black pants", category: .bottoms, subtype: .pants, color: .black, tags: ["clean"]),
            SampleItem(code: "DEMO-SO-001", name: "Tan shorts", category: .bottoms, subtype: .shorts, color: .tan, tags: ["warm"]),
            SampleItem(code: "DEMO-SN-001", name: "White sneakers", category: .footwear, subtype: .sneakers, color: .white, tags: ["daily", "favorite"]),
            SampleItem(code: "DEMO-BT-001", name: "Black boots", category: .footwear, subtype: .boots, color: .black, tags: ["winter"]),
            SampleItem(code: "DEMO-SA-001", name: "Brown sandals", category: .footwear, subtype: .sandals, color: .brown, tags: ["warm"]),
            SampleItem(code: "DEMO-JA-001", name: "Olive jacket", category: .outerwear, subtype: .jacket, color: .olive, tags: ["outerwear"]),
            SampleItem(code: "DEMO-CO-001", name: "Navy coat", category: .outerwear, subtype: .coat, color: .navy, tags: ["outerwear"]),
            SampleItem(code: "DEMO-HA-001", name: "Black cap", category: .accessories, subtype: .hat, color: .black, tags: ["accessory"]),
            SampleItem(code: "DEMO-BA-001", name: "Cream bag", category: .accessories, subtype: .bag, color: .cream, tags: ["accessory"])
        ]
    }

    private static func renderSampleImage(for sample: SampleItem) -> UIImage {
        let size = CGSize(width: 640, height: 820)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cgContext = context.cgContext
            let garmentColor = uiColor(for: sample.color)
            let shadowColor = UIColor.black.withAlphaComponent(0.08)

            cgContext.setShadow(offset: CGSize(width: 0, height: 12), blur: 22, color: shadowColor.cgColor)
            garmentColor.setFill()
            drawGarment(for: sample.category, in: CGRect(x: 120, y: 120, width: 400, height: 520))
            cgContext.setShadow(offset: .zero, blur: 0, color: nil)

            UIColor.black.withAlphaComponent(0.62).setFill()
            let label = sample.name.uppercased() as NSString
            label.draw(
                in: CGRect(x: 90, y: 690, width: 460, height: 32),
                withAttributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 24, weight: .medium),
                    .foregroundColor: UIColor.black.withAlphaComponent(0.62),
                    .paragraphStyle: centeredParagraphStyle()
                ]
            )

            let code = sample.code as NSString
            code.draw(
                in: CGRect(x: 90, y: 728, width: 460, height: 28),
                withAttributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 18, weight: .regular),
                    .foregroundColor: UIColor.black.withAlphaComponent(0.32),
                    .paragraphStyle: centeredParagraphStyle()
                ]
            )
        }
    }

    private static func drawGarment(for category: ClothingCategory, in rect: CGRect) {
        switch category {
        case .tops, .outerwear:
            drawTop(in: rect, isOuterwear: category == .outerwear)
        case .bottoms:
            drawBottom(in: rect)
        case .footwear:
            drawShoe(in: rect)
        case .accessories:
            drawAccessory(in: rect)
        case .onePiece, .other:
            drawTop(in: rect, isOuterwear: false)
        }
    }

    private static func drawTop(in rect: CGRect, isOuterwear: Bool) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.midX - 88, y: rect.minY + 36))
        path.addLine(to: CGPoint(x: rect.midX - 182, y: rect.minY + 122))
        path.addLine(to: CGPoint(x: rect.midX - 138, y: rect.minY + 206))
        path.addLine(to: CGPoint(x: rect.midX - 96, y: rect.minY + 176))
        path.addLine(to: CGPoint(x: rect.midX - 112, y: rect.maxY - 38))
        path.addLine(to: CGPoint(x: rect.midX + 112, y: rect.maxY - 38))
        path.addLine(to: CGPoint(x: rect.midX + 96, y: rect.minY + 176))
        path.addLine(to: CGPoint(x: rect.midX + 138, y: rect.minY + 206))
        path.addLine(to: CGPoint(x: rect.midX + 182, y: rect.minY + 122))
        path.addLine(to: CGPoint(x: rect.midX + 88, y: rect.minY + 36))
        path.addQuadCurve(to: CGPoint(x: rect.midX - 88, y: rect.minY + 36), controlPoint: CGPoint(x: rect.midX, y: rect.minY + 112))
        path.close()
        path.fill()

        if isOuterwear {
            UIColor.white.withAlphaComponent(0.28).setStroke()
            let seam = UIBezierPath()
            seam.move(to: CGPoint(x: rect.midX, y: rect.minY + 116))
            seam.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 44))
            seam.lineWidth = 8
            seam.stroke()
        }
    }

    private static func drawBottom(in rect: CGRect) {
        let leftLeg = UIBezierPath(roundedRect: CGRect(x: rect.midX - 112, y: rect.minY + 32, width: 96, height: 430), cornerRadius: 26)
        let rightLeg = UIBezierPath(roundedRect: CGRect(x: rect.midX + 16, y: rect.minY + 32, width: 96, height: 430), cornerRadius: 26)
        let waist = UIBezierPath(roundedRect: CGRect(x: rect.midX - 126, y: rect.minY + 20, width: 252, height: 72), cornerRadius: 22)
        waist.fill()
        leftLeg.fill()
        rightLeg.fill()
    }

    private static func drawShoe(in rect: CGRect) {
        let left = UIBezierPath(roundedRect: CGRect(x: rect.midX - 172, y: rect.midY - 44, width: 210, height: 84), cornerRadius: 42)
        let right = UIBezierPath(roundedRect: CGRect(x: rect.midX - 38, y: rect.midY + 58, width: 210, height: 84), cornerRadius: 42)
        left.fill()
        right.fill()
        UIColor.white.withAlphaComponent(0.32).setFill()
        UIBezierPath(roundedRect: CGRect(x: rect.midX - 118, y: rect.midY - 16, width: 86, height: 12), cornerRadius: 6).fill()
        UIBezierPath(roundedRect: CGRect(x: rect.midX + 16, y: rect.midY + 86, width: 86, height: 12), cornerRadius: 6).fill()
    }

    private static func drawAccessory(in rect: CGRect) {
        let accessory = UIBezierPath(roundedRect: CGRect(x: rect.midX - 124, y: rect.minY + 126, width: 248, height: 248), cornerRadius: 58)
        accessory.fill()
        UIColor.white.withAlphaComponent(0.32).setStroke()
        let handle = UIBezierPath(arcCenter: CGPoint(x: rect.midX, y: rect.minY + 130), radius: 76, startAngle: .pi, endAngle: 0, clockwise: true)
        handle.lineWidth = 20
        handle.stroke()
    }

    private static func uiColor(for color: ClosetColor) -> UIColor {
        switch color {
        case .black:
            return UIColor(white: 0.08, alpha: 1)
        case .white:
            return UIColor(white: 0.93, alpha: 1)
        case .gray:
            return UIColor(white: 0.48, alpha: 1)
        case .cream:
            return UIColor(red: 0.86, green: 0.80, blue: 0.68, alpha: 1)
        case .brown:
            return UIColor(red: 0.42, green: 0.28, blue: 0.17, alpha: 1)
        case .tan:
            return UIColor(red: 0.68, green: 0.54, blue: 0.36, alpha: 1)
        case .navy:
            return UIColor(red: 0.08, green: 0.14, blue: 0.30, alpha: 1)
        case .blue:
            return UIColor(red: 0.16, green: 0.36, blue: 0.72, alpha: 1)
        case .green:
            return UIColor(red: 0.12, green: 0.46, blue: 0.28, alpha: 1)
        case .olive:
            return UIColor(red: 0.30, green: 0.36, blue: 0.20, alpha: 1)
        case .red:
            return UIColor(red: 0.70, green: 0.10, blue: 0.12, alpha: 1)
        case .burgundy:
            return UIColor(red: 0.38, green: 0.04, blue: 0.12, alpha: 1)
        case .pink:
            return UIColor(red: 0.86, green: 0.42, blue: 0.58, alpha: 1)
        case .purple:
            return UIColor(red: 0.44, green: 0.24, blue: 0.62, alpha: 1)
        case .yellow:
            return UIColor(red: 0.92, green: 0.75, blue: 0.18, alpha: 1)
        case .orange:
            return UIColor(red: 0.82, green: 0.34, blue: 0.12, alpha: 1)
        case .multicolor:
            return UIColor(red: 0.32, green: 0.40, blue: 0.68, alpha: 1)
        case .unknown:
            return UIColor(white: 0.34, alpha: 1)
        }
    }

    private static func centeredParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        return style
    }
}
#endif
