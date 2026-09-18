import Foundation

@MainActor
final class ClosetGridViewModel: ObservableObject {
    /// Intentionally session-scoped: a `StateObject` preserves filters while the
    /// Closet tab and its detail destinations remain alive, while a new app
    /// launch starts from the default catalog rather than restoring stale filters.
    @Published var filterState = ClosetFilterState()

    private let filteringService: ClosetFilteringService

    init(filteringService: ClosetFilteringService = ClosetFilteringService()) {
        self.filteringService = filteringService
    }

    func filteredItems(from items: [ClosetItem], closets: [Closet] = []) -> [ClosetItem] {
        filteringService.filteredItems(items, state: filterState, closets: closets)
    }

    func selectCategory(_ category: ClothingCategory?) {
        filterState.category = category
    }

    func selectColor(_ color: ClosetColor?) {
        filterState.color = color
    }
}
