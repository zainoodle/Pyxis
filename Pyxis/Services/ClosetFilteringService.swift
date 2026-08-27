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
    public var closetID: UUID?

    public init(
        searchText: String = "",
        category: ClothingCategory? = nil,
        subtype: ClothingSubtype? = nil,
        color: ClosetColor? = nil,
        favoritesOnly: Bool = false,
        sort: ClosetSortOption = .newest,
        closetID: UUID? = nil
    ) {
        self.searchText = searchText
        self.category = category
        self.subtype = subtype
        self.color = color
        self.favoritesOnly = favoritesOnly
        self.sort = sort
        self.closetID = closetID
    }

    public var activeFilterCount: Int {
        var count = 0
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
        if closetID != nil { count += 1 }
        if category != nil { count += 1 }
        if subtype != nil { count += 1 }
        if color != nil { count += 1 }
        if favoritesOnly { count += 1 }
        if sort != .newest { count += 1 }
        return count
    }

    public var hasActiveFilters: Bool {
        activeFilterCount > 0
    }

    public mutating func selectCategory(_ newCategory: ClothingCategory?) {
        category = newCategory
        if let subtype, let newCategory, !subtype.isCompatible(with: newCategory) {
            self.subtype = nil
        }
    }

    public mutating func clearAll() {
        self = ClosetFilterState()
    }
}

public struct ClosetFilteringService: Sendable {
    public init() {}

    public func filteredItems(
        _ items: [ClosetItem],
        state: ClosetFilterState,
        closets: [Closet] = []
    ) -> [ClosetItem] {
        let query = state.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let closetItemIDs: Set<UUID>?
        if let closetID = state.closetID {
            guard let closet = closets.first(where: { $0.id == closetID }) else {
                return []
            }
            closetItemIDs = Set(closet.itemIDs)
        } else {
            closetItemIDs = nil
        }

        let filtered = items.filter { item in
            if item.isDeleted {
                return false
            }
            if let closetItemIDs, !closetItemIDs.contains(item.id) {
                return false
            }
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
