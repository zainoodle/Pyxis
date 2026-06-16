import Foundation

@MainActor
final class ClosetGridViewModel: ObservableObject {
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
