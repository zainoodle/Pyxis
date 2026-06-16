import SwiftData
import SwiftUI

struct ClosetGridView: View {
    @Query(sort: \ClosetItem.dateAdded, order: .reverse) private var items: [ClosetItem]
    @StateObject private var viewModel = ClosetGridViewModel()
    @State private var isShowingAddFlow = false
    @State private var selectedItem: ClosetItem?
    @FocusState private var isSearchFocused: Bool

    private let columns = [
        GridItem(.adaptive(minimum: 158, maximum: 210), spacing: ArchiveSpacing.lg)
    ]

    var body: some View {
        VStack(spacing: ArchiveSpacing.lg) {
            TopNavigationView(filterState: $viewModel.filterState) {
                isShowingAddFlow = true
            }
            .padding(.top, ArchiveSpacing.lg)

            SearchAndFilterView(
                filterState: $viewModel.filterState,
                isSearchFocused: $isSearchFocused
            )

            content
        }
        .padding(.horizontal, ArchiveSpacing.xl)
        .padding(.bottom, ArchiveSpacing.xl)
        .frame(minWidth: 820, minHeight: 620)
        .background(ArchiveColors.background)
        .toolbar {
            Button("ADD") {
                isShowingAddFlow = true
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("FIND") {
                isSearchFocused = true
            }
            .keyboardShortcut("f", modifiers: .command)
        }
        .sheet(isPresented: $isShowingAddFlow) {
            AddItemFlow()
                .frame(minWidth: 760, minHeight: 620)
        }
        .sheet(item: $selectedItem) { item in
            ItemDetailView(item: item)
                .frame(minWidth: 760, minHeight: 620)
        }
    }

    @ViewBuilder
    private var content: some View {
        let filteredItems = viewModel.filteredItems(from: items)

        if items.isEmpty {
            Spacer()
            EmptyArchiveState {
                isShowingAddFlow = true
            }
            Spacer()
        } else if filteredItems.isEmpty {
            Spacer()
            Text("NO MATCHES")
                .font(ArchiveTypography.body)
                .foregroundStyle(ArchiveColors.inactiveText)
            Spacer()
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: ArchiveSpacing.xl) {
                    ForEach(filteredItems) { item in
                        ClosetGridItemView(item: item)
                            .onTapGesture {
                                selectedItem = item
                            }
                    }
                }
                .padding(.top, ArchiveSpacing.md)
            }
        }
    }
}
