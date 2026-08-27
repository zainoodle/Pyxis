import Foundation

public enum ClothingSubtype: String, CaseIterable, Codable, Identifiable, Sendable {
    case tShirt
    case longSleeve
    case shirt
    case hoodie
    case crewneck
    case sweater
    case cardigan
    case jacket
    case coat
    case vest
    case jeans
    case pants
    case leggings
    case joggers
    case shorts
    case skirt
    case dress
    case sneakers
    case boots
    case slides
    case mules
    case sandals
    case hat
    case bag
    case belt
    case jewelry
    case scarf
    case sunglasses
    case watch
    case other

    public var id: String { rawValue }

    public var compatibleCategory: ClothingCategory {
        switch self {
        case .tShirt, .longSleeve, .shirt, .hoodie, .crewneck, .sweater, .cardigan:
            return .tops
        case .jacket, .coat, .vest:
            return .outerwear
        case .jeans, .pants, .leggings, .joggers, .shorts, .skirt:
            return .bottoms
        case .dress:
            return .onePiece
        case .sneakers, .boots, .slides, .mules, .sandals:
            return .footwear
        case .hat, .bag, .belt, .jewelry, .scarf, .sunglasses, .watch:
            return .accessories
        case .other:
            return .other
        }
    }

    public static func compatibleSubtypes(for category: ClothingCategory) -> [ClothingSubtype] {
        switch category {
        case .tops:
            return [.tShirt, .longSleeve, .shirt, .hoodie, .crewneck, .sweater, .cardigan]
        case .bottoms:
            return [.pants, .jeans, .leggings, .joggers, .shorts, .skirt]
        case .outerwear:
            return [.jacket, .coat, .vest]
        case .footwear:
            return [.sneakers, .boots, .slides, .mules, .sandals]
        case .accessories:
            return [.hat, .bag, .belt, .jewelry, .scarf, .sunglasses, .watch]
        case .onePiece:
            return [.dress]
        case .other:
            return [.other]
        }
    }

    public static func defaultSubtype(for category: ClothingCategory) -> ClothingSubtype {
        compatibleSubtypes(for: category).first ?? .other
    }

    public func isCompatible(with category: ClothingCategory) -> Bool {
        compatibleCategory == category
    }
}
