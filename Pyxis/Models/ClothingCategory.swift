import Foundation

public enum ClothingCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case tops
    case bottoms
    case outerwear
    case footwear
    case accessories
    case onePiece
    case other

    public var id: String { rawValue }
}
