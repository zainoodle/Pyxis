import SwiftData
import SwiftUI

struct ClosetGridView: View {
    @Query(sort: \ClosetItem.dateAdded, order: .reverse) private var items: [ClosetItem]
    @Query(sort: \Closet.dateUpdated, order: .reverse) private var closets: [Closet]
    @StateObject private var viewModel = ClosetGridViewModel()
    @State private var isShowingAddFlow = false
    @State private var savedItemPrompt: ClosetItem?
    @State private var seedMessage: String?
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isSearchFocused: Bool
    private let buildAction: (UUID?) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 158, maximum: 210), spacing: PyxisSpacing.lg)
    ]

    init(buildAction: @escaping (UUID?) -> Void = { _ in }) {
        self.buildAction = buildAction
    }

    var body: some View {
        VStack(spacing: PyxisSpacing.lg) {
            TopNavigationView(
                filterState: $viewModel.filterState,
                closets: closets,
                addAction: { isShowingAddFlow = true }
            )
            .padding(.top, PyxisSpacing.lg)

            if let savedItemPrompt {
                SavedItemBuildPrompt(item: savedItemPrompt) {
                    let itemID = savedItemPrompt.id
                    self.savedItemPrompt = nil
                    buildAction(itemID)
                } dismissAction: {
                    self.savedItemPrompt = nil
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            SearchAndFilterView(
                filterState: $viewModel.filterState,
                closets: closets,
                isSearchFocused: $isSearchFocused
            )

            content
        }
        .padding(.horizontal, PyxisSpacing.md)
        .padding(.bottom, PyxisSpacing.xl)
        .background(PyxisColors.background)
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
            AddItemFlow(initialClosetID: viewModel.filterState.closetID) { item in
                withAnimation(.easeOut(duration: 0.2)) {
                    savedItemPrompt = item
                }
            }
        }
        .onChange(of: closets.map(\.id)) { _, closetIDs in
            if let closetID = viewModel.filterState.closetID, !closetIDs.contains(closetID) {
                viewModel.filterState.closetID = nil
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        let filteredItems = viewModel.filteredItems(from: items, closets: closets)

        if items.isEmpty {
            Spacer()
            VStack(spacing: PyxisSpacing.md) {
                EmptyPyxisState {
                    isShowingAddFlow = true
                }

                #if DEBUG
                Button("SEED CLOSET") {
                    seedDebugCloset()
                }
                .buttonStyle(MinimalButtonStyle())
                .accessibilityLabel("Seed closet with sample clothing")

                if let seedMessage {
                    Text(seedMessage.uppercased())
                        .font(PyxisTypography.label)
                        .foregroundStyle(PyxisColors.secondaryText)
                }
                #endif
            }
            Spacer()
        } else if filteredItems.isEmpty {
            Spacer()
            VStack(spacing: PyxisSpacing.md) {
                Text(emptyFilteredTitle)
                    .font(PyxisTypography.body)
                    .foregroundStyle(PyxisColors.inactiveText)

                if viewModel.filterState.hasActiveFilters {
                    Button("CLEAR ALL") {
                        viewModel.filterState.clearAll()
                    }
                    .buttonStyle(MinimalButtonStyle())
                    .accessibilityLabel("Clear search and all filters")
                }
            }
            Spacer()
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: PyxisSpacing.xl) {
                    ForEach(filteredItems) { item in
                        NavigationLink {
                            ItemDetailView(item: item, showsCloseButton: false) { buildItem in
                                buildAction(buildItem.id)
                            }
                        } label: {
                            ClosetGridItemView(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, PyxisSpacing.md)
            }
        }
    }

    private var selectedCloset: Closet? {
        guard let closetID = viewModel.filterState.closetID else {
            return nil
        }
        return closets.first { $0.id == closetID }
    }

    private var emptyFilteredTitle: String {
        if selectedCloset?.itemCount == 0 {
            return "THIS CLOSET IS EMPTY"
        }
        if !viewModel.filterState.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "NO ITEMS MATCH THIS SEARCH"
        }
        return "NO ITEMS MATCH THESE FILTERS"
    }

    #if DEBUG
    private func seedDebugCloset() {
        do {
            let result = try DebugClosetSeedService.seedCloset(in: modelContext, existingItems: items)
            seedMessage = result.insertedCount == 0
                ? "Sample closet already seeded"
                : "Seeded \(result.insertedCount) items"
        } catch {
            seedMessage = "Seed failed"
        }
    }
    #endif
}

private struct SavedItemBuildPrompt: View {
    let item: ClosetItem
    let buildAction: () -> Void
    let dismissAction: () -> Void

    var body: some View {
        HStack(spacing: PyxisSpacing.md) {
            VStack(alignment: .leading, spacing: PyxisSpacing.xs) {
                Text("SAVED \(item.itemCode)")
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.secondaryText)

                Text(item.displayName?.uppercased() ?? item.subtype.rawValue.uppercased())
                    .font(PyxisTypography.body)
                    .foregroundStyle(PyxisColors.text)
                    .lineLimit(1)
            }

            Spacer()

            if OutfitBuilderService().slot(for: item.category) != nil {
                Button("BUILD WITH THIS", action: buildAction)
                    .buttonStyle(MinimalButtonStyle())
            }

            Button("READY", action: dismissAction)
                .buttonStyle(.plain)
                .font(PyxisTypography.label)
                .foregroundStyle(PyxisColors.secondaryText)
        }
        .padding(PyxisSpacing.md)
        .background(PyxisColors.field)
    }
}
