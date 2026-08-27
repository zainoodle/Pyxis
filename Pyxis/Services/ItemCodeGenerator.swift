import Foundation

public enum ItemCodeGenerator {
    public static func generate(
        for subtype: ClothingSubtype,
        category: ClothingCategory,
        existingCodes: Set<String>
    ) -> String {
        let prefix = prefix(for: subtype, category: category)
        var index = 1

        while true {
            let code = "\(prefix)-\(String(format: "%03d", index))"
            if !existingCodes.contains(code) {
                return code
            }
            index += 1
        }
    }

    public static func prefix(
        for subtype: ClothingSubtype,
        category: ClothingCategory
    ) -> String {
        switch subtype {
        case .tShirt:
            return "TS"
        case .longSleeve:
            return "LS"
        case .hoodie:
            return "HD"
        case .crewneck:
            return "CN"
        case .sweater:
            return "SW"
        case .cardigan:
            return "CG"
        case .pants:
            return "PT"
        case .jeans:
            return "JE"
        case .leggings:
            return "LG"
        case .joggers:
            return "JG"
        case .sneakers:
            return "SH"
        case .boots:
            return "BT"
        case .slides:
            return "SL"
        case .mules:
            return "ML"
        case .jacket:
            return "JK"
        case .coat:
            return "CT"
        case .vest:
            return "VT"
        case .bag:
            return "BG"
        case .shirt:
            return "SH"
        case .shorts:
            return "PT"
        case .skirt:
            return "PT"
        case .dress:
            return "DR"
        case .sandals:
            return "SH"
        case .scarf:
            return "SC"
        case .sunglasses:
            return "SG"
        case .watch:
            return "WT"
        case .hat, .belt, .jewelry:
            return "AC"
        case .other:
            return fallbackPrefix(for: category)
        }
    }

    private static func fallbackPrefix(for category: ClothingCategory) -> String {
        switch category {
        case .tops:
            return "TP"
        case .bottoms:
            return "PT"
        case .outerwear:
            return "JK"
        case .footwear:
            return "SH"
        case .accessories:
            return "AC"
        case .onePiece:
            return "DR"
        case .other:
            return "OT"
        }
    }
}
