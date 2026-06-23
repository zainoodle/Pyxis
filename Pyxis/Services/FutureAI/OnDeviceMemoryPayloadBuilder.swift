import Foundation

public struct OnDeviceMemoryPayload: Equatable {
    public let summary: String
    public let embedding: [Double]
    public let metadataTags: [String]
}

public enum OnDeviceMemoryPayloadBuilder {
    public static let embeddingDimensions = 32

    public static func closetItemPayload(for item: ClosetItem) -> OnDeviceMemoryPayload {
        var summaryParts = [
            "\(itemLabel(for: item)) (\(item.itemCode))",
            itemTraits(for: item).joined(separator: " ")
        ]

        if let brand = item.brand.trimmedNonEmpty {
            summaryParts.append("Brand: \(brand)")
        }
        if let size = item.size.trimmedNonEmpty {
            summaryParts.append("Size: \(size)")
        }
        if !item.tags.isEmpty {
            summaryParts.append("Tags: \(item.tags.joined(separator: ", "))")
        }
        if let notes = item.notes.trimmedNonEmpty {
            summaryParts.append("Notes: \(notes)")
        }
        if item.favorite {
            summaryParts.append("Favorite item")
        }

        let tags = [
            "closet item",
            item.category.rawValue,
            item.subtype.rawValue,
            item.primaryColor == .unknown ? nil : item.primaryColor.rawValue,
            item.brand.trimmedNonEmpty,
            item.favorite ? "favorite" : nil
        ].compactMap { $0 } + item.tags

        return payload(summaryParts: summaryParts, tags: tags)
    }

    public static func outfitPayload(for outfit: Outfit, items: [ClosetItem]) -> OnDeviceMemoryPayload {
        let itemNames = orderedItems(for: outfit, from: items).map { itemLabel(for: $0) }
        let outfitName = outfit.name.trimmedNonEmpty ?? "Saved fit"
        var summaryParts = [outfitName]

        if !itemNames.isEmpty {
            summaryParts.append("Includes \(itemNames.joined(separator: ", "))")
        }
        if let notes = outfit.notes.trimmedNonEmpty {
            summaryParts.append("Notes: \(notes)")
        }
        if outfit.favorite {
            summaryParts.append("Favorite fit")
        }
        if outfit.wearCount > 0 {
            summaryParts.append("Worn \(outfit.wearCount) time\(outfit.wearCount == 1 ? "" : "s")")
        }

        let itemTags = orderedItems(for: outfit, from: items).flatMap { item in
            [
                item.category.rawValue,
                item.subtype.rawValue,
                item.primaryColor == .unknown ? nil : item.primaryColor.rawValue
            ].compactMap { $0 } + item.tags
        }
        let tags = ["outfit", outfit.favorite ? "favorite" : nil].compactMap { $0 } + itemTags

        return payload(summaryParts: summaryParts, tags: tags)
    }

    private static func payload(summaryParts: [String], tags: [String]) -> OnDeviceMemoryPayload {
        let summary = summaryParts
            .compactMap(\.trimmedNonEmpty)
            .joined(separator: ". ")
        let fallbackSummary = summary.isEmpty ? "Pyxis local memory" : summary
        let metadataTags = sanitizedTags(tags)
        let embeddingText = ([fallbackSummary] + metadataTags).joined(separator: " ")

        return OnDeviceMemoryPayload(
            summary: fallbackSummary,
            embedding: embedding(for: embeddingText),
            metadataTags: metadataTags
        )
    }

    private static func orderedItems(for outfit: Outfit, from items: [ClosetItem]) -> [ClosetItem] {
        outfit.itemIDs.compactMap { itemID in
            items.first { $0.id == itemID }
        }
    }

    private static func itemTraits(for item: ClosetItem) -> [String] {
        var traits: [String] = []
        if item.primaryColor != .unknown {
            traits.append(memoryLabel(item.primaryColor.rawValue))
        }
        traits.append(memoryLabel(item.subtype.rawValue))
        traits.append("in \(memoryLabel(item.category.rawValue))")
        return traits
    }

    private static func itemLabel(for item: ClosetItem) -> String {
        item.displayName.trimmedNonEmpty ?? fallbackItemLabel(for: item)
    }

    private static func fallbackItemLabel(for item: ClosetItem) -> String {
        let traits = itemTraits(for: item).filter { !$0.hasPrefix("in ") }
        guard !traits.isEmpty else {
            return item.itemCode
        }
        return traits.joined(separator: " ")
    }

    private static func sanitizedTags(_ tags: [String]) -> [String] {
        var seenTags = Set<String>()
        var sanitizedTags: [String] = []

        for tag in tags {
            guard let trimmedTag = tag.trimmedNonEmpty else {
                continue
            }
            let normalizedTag = trimmedTag.lowercased()
            guard !seenTags.contains(normalizedTag) else {
                continue
            }

            sanitizedTags.append(normalizedTag)
            seenTags.insert(normalizedTag)
        }

        return sanitizedTags
    }

    private static func embedding(for text: String) -> [Double] {
        var vector = Array(repeating: 0.0, count: embeddingDimensions)
        let parsedTokens = tokenized(text)
        let tokens = parsedTokens.isEmpty ? ["pyxis", "memory"] : parsedTokens

        for token in tokens {
            let hash = stableHash(token)
            let index = Int(hash % UInt64(embeddingDimensions))
            let weight = 1.0 + (Double(token.count) / 10.0)
            vector[index] += weight
        }

        let magnitude = sqrt(vector.reduce(0.0) { $0 + ($1 * $1) })
        guard magnitude > 0 else {
            return vector
        }

        return vector.map { $0 / magnitude }
    }

    private static func tokenized(_ text: String) -> [String] {
        text.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    private static func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }

    private static func memoryLabel(_ value: String) -> String {
        value.reduce(into: "") { result, character in
            if character.isUppercase, !result.isEmpty {
                result.append(" ")
            }
            result.append(character.lowercased())
        }
    }
}

private extension Optional where Wrapped == String {
    var trimmedNonEmpty: String? {
        switch self {
        case .none:
            return nil
        case let .some(value):
            return value.trimmedNonEmpty
        }
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
