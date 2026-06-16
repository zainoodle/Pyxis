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
            (["overshirt", "shacket"], .outerwear, .jacket),
            (["hoodie", "hoody"], .tops, .hoodie),
            (["crewneck", "crew"], .tops, .crewneck),
            (["cardigan"], .tops, .cardigan),
            (["sweater", "knit"], .tops, .sweater),
            (["vest", "gilet"], .outerwear, .vest),
            (["jacket", "bomber", "blazer", "puffer"], .outerwear, .jacket),
            (["coat", "parka", "overcoat", "trench", "raincoat"], .outerwear, .coat),
            (["shirt", "buttondown", "button-down", "button up", "button-up", "tank", "top"], .tops, .shirt),
            (["jeans", "denim"], .bottoms, .jeans),
            (["leggings"], .bottoms, .leggings),
            (["jogger", "joggers"], .bottoms, .joggers),
            (["pants", "pant", "trouser", "trousers", "cargo", "chino", "chinos", "sweatpants"], .bottoms, .pants),
            (["shorts"], .bottoms, .shorts),
            (["skirt"], .bottoms, .skirt),
            (["dress"], .onePiece, .dress),
            (["sneaker", "sneakers", "shoe", "shoes", "loafer", "loafers", "trainer", "trainers"], .footwear, .sneakers),
            (["boot", "boots"], .footwear, .boots),
            (["mule", "mules", "clog", "clogs"], .footwear, .mules),
            (["slide", "slides"], .footwear, .slides),
            (["sandal", "sandals"], .footwear, .sandals),
            (["hat", "cap", "beanie"], .accessories, .hat),
            (["bag", "tote", "backpack"], .accessories, .bag),
            (["belt"], .accessories, .belt),
            (["watch"], .accessories, .watch),
            (["jewelry", "jewellery", "ring", "necklace", "bracelet", "earring", "earrings"], .accessories, .jewelry),
            (["scarf"], .accessories, .scarf),
            (["sunglasses", "glasses"], .accessories, .sunglasses)
        ]
    }

    public func classify(filename: String?) -> ClothingClassificationResult {
        let tokens = normalizedTokens(from: filename)

        guard !tokens.isEmpty else {
            return .unknown
        }

        for rule in rules {
            if rule.tokens.contains(where: { matches($0, in: tokens) }) {
                return ClothingClassificationResult(
                    category: rule.category,
                    subtype: rule.subtype,
                    confidence: 0.55
                )
            }
        }

        return .unknown
    }

    private func normalizedTokens(from filename: String?) -> [String] {
        let stem = URL(fileURLWithPath: filename ?? "").deletingPathExtension().lastPathComponent
        let normalized = stem
            .lowercased()
            .map { character in
                character.isLetter || character.isNumber ? character : " "
            }

        return String(normalized)
            .split(separator: " ")
            .map(String.init)
    }

    private func matches(_ tokenPattern: String, in tokens: [String]) -> Bool {
        let patternTokens = normalizedTokens(from: tokenPattern)

        guard !patternTokens.isEmpty else {
            return false
        }

        if patternTokens.count == 1 {
            return tokens.contains(patternTokens[0])
        }

        guard tokens.count >= patternTokens.count else {
            return false
        }

        for startIndex in 0...(tokens.count - patternTokens.count) {
            let endIndex = startIndex + patternTokens.count
            if Array(tokens[startIndex..<endIndex]) == patternTokens {
                return true
            }
        }

        return false
    }
}

public extension ClothingClassificationResult {
    static let unknown = ClothingClassificationResult(
        category: .other,
        subtype: .other,
        confidence: 0
    )
}
