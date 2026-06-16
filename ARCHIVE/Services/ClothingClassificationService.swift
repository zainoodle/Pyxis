import Foundation

public struct ClothingClassificationResult: Equatable, Sendable {
    public let category: ClothingCategory
    public let subtype: ClothingSubtype
    public let confidence: Double

    public init(
        category: ClothingCategory,
        subtype: ClothingSubtype,
        confidence: Double
    ) {
        self.category = category
        self.subtype = subtype
        self.confidence = confidence
    }
}

public struct ClothingClassificationService: Sendable {
    private let rules: [(tokens: [String], category: ClothingCategory, subtype: ClothingSubtype)]

    public init() {
        rules = [
            (["tshirt", "tee", "t-shirt"], .tops, .tShirt),
            (["longsleeve", "long-sleeve", "long sleeve"], .tops, .longSleeve),
            (["shirt", "buttondown", "button-down"], .tops, .shirt),
            (["hoodie"], .tops, .hoodie),
            (["crewneck", "crew"], .tops, .crewneck),
            (["sweater", "knit"], .tops, .sweater),
            (["jacket", "bomber"], .outerwear, .jacket),
            (["coat", "parka"], .outerwear, .coat),
            (["jeans", "denim"], .bottoms, .jeans),
            (["pants", "trouser"], .bottoms, .pants),
            (["shorts"], .bottoms, .shorts),
            (["skirt"], .bottoms, .skirt),
            (["dress"], .onePiece, .dress),
            (["sneaker", "shoe"], .footwear, .sneakers),
            (["boot"], .footwear, .boots),
            (["slide"], .footwear, .slides),
            (["sandal"], .footwear, .sandals),
            (["hat", "cap", "beanie"], .accessories, .hat),
            (["bag", "tote"], .accessories, .bag),
            (["belt"], .accessories, .belt),
            (["jewelry", "ring", "necklace"], .accessories, .jewelry)
        ]
    }

    public func classify(filename: String?) -> ClothingClassificationResult {
        let normalized = (filename ?? "")
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")

        guard !normalized.isEmpty else {
            return .unknown
        }

        for rule in rules {
            if rule.tokens.contains(where: { normalized.contains($0) }) {
                return ClothingClassificationResult(
                    category: rule.category,
                    subtype: rule.subtype,
                    confidence: 0.55
                )
            }
        }

        return .unknown
    }
}

public extension ClothingClassificationResult {
    static let unknown = ClothingClassificationResult(
        category: .other,
        subtype: .other,
        confidence: 0
    )
}
