import Foundation

public enum ClosetSortOption: String, CaseIterable, Identifiable, Sendable {
    case newest
    case category
    case color
    case mostWorn

    public var id: String { rawValue }
}

public struct ClosetFilterState: Equatable, Sendable {
    public var searchText: String
    public var category: ClothingCategory?
    public var subtype: ClothingSubtype?
    public var color: ClosetColor?
    public var favoritesOnly: Bool
    public var sort: ClosetSortOption

    public init(
        searchText: String = "",
        category: ClothingCategory? = nil,
        subtype: ClothingSubtype? = nil,
        color: ClosetColor? = nil,
        favoritesOnly: Bool = false,
        sort: ClosetSortOption = .newest
    ) {
        self.searchText = searchText
        self.category = category
        self.subtype = subtype
        self.color = color
        self.favoritesOnly = favoritesOnly
        self.sort = sort
    }
}

public struct ClosetFilteringService: Sendable {
    public init() {}

    public func filteredItems(
        _ items: [ClosetItem],
        state: ClosetFilterState
    ) -> [ClosetItem] {
        let query = state.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filtered = items.filter { item in
            if let category = state.category, item.category != category {
                return false
            }
            if let subtype = state.subtype, item.subtype != subtype {
                return false
            }
            if let color = state.color, item.primaryColor != color {
                return false
            }
            if state.favoritesOnly && !item.favorite {
                return false
            }
            if !query.isEmpty && !searchableText(for: item).contains(query) {
                return false
            }
            return true
        }

        return sorted(filtered, by: state.sort)
    }

    private func searchableText(for item: ClosetItem) -> String {
        [
            item.itemCode,
            item.displayName,
            item.brand,
            item.notes,
            item.category.rawValue,
            item.subtype.rawValue,
            item.primaryColor.rawValue,
            item.tags.joined(separator: " ")
        ]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
    }

    private func sorted(
        _ items: [ClosetItem],
        by option: ClosetSortOption
    ) -> [ClosetItem] {
        switch option {
        case .newest:
            return items.sorted { $0.dateAdded > $1.dateAdded }
        case .category:
            return items.sorted { lhs, rhs in
                if lhs.category.rawValue != rhs.category.rawValue {
                    return lhs.category.rawValue < rhs.category.rawValue
                }
                if lhs.subtype.rawValue != rhs.subtype.rawValue {
                    return lhs.subtype.rawValue < rhs.subtype.rawValue
                }
                return lhs.itemCode < rhs.itemCode
            }
        case .color:
            return items.sorted { lhs, rhs in
                if lhs.primaryColor.rawValue != rhs.primaryColor.rawValue {
                    return lhs.primaryColor.rawValue < rhs.primaryColor.rawValue
                }
                return lhs.itemCode < rhs.itemCode
            }
        case .mostWorn:
            return items.sorted { lhs, rhs in
                if lhs.wearCount != rhs.wearCount {
                    return lhs.wearCount > rhs.wearCount
                }
                return lhs.dateAdded > rhs.dateAdded
            }
        }
    }
}
