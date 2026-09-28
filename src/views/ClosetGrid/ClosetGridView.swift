import SwiftData
import SwiftUI

struct ClosetGridView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \ClosetItem.dateAdded, order: .reverse) private var items: [ClosetItem]
    @Query(sort: \Closet.dateUpdated, order: .reverse) private var closets: [Closet]
    @StateObject private var viewModel = ClosetGridViewModel()
    @State private var isShowingAddFlow = false
    @State private var savedItemPrompt: ClosetItem?
    @State private var seedMessage: String?
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isSearchFocused: Bool
    private let buildAction: (UUID?) -> Void

    init(buildAction: @escaping (UUID?) -> Void = { _ in }) {
        self.buildAction = buildAction
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
            VStack(spacing: 20) {
                PrimaryPageHeader(title: "CLOSET") {
                    Button { isShowingAddFlow = true } label: {
                        Label("ADD", systemImage: "plus")
                            .font(PyxisTypography.editorialBody)
                            .tracking(1.5)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .foregroundStyle(PyxisColors.background)
                            .background(PyxisColors.text, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add new item")
                }
    
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
    
                if !items.isEmpty {
                    EditorialClosetControls(
                        filterState: $viewModel.filterState,
                        closets: closets,
                        isSearchFocused: $isSearchFocused
                    )
                }
    
                content(cardHeight: max(290, min(460, geometry.size.height * 0.44)))
            }
            .frame(minHeight: geometry.size.height, alignment: .top)
            .padding(.horizontal, colorScheme == .dark ? 20 : PyxisSpacing.md)
            .padding(.bottom, colorScheme == .dark ? PyxisSpacing.md : PyxisSpacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
        .background { ClosetWashedBackground().ignoresSafeArea() }
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
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-pyxisSeedCloset") {
                seedDebugCloset()
            }
            #endif
        }
    }

    @ViewBuilder
    private func content(cardHeight: CGFloat) -> some View {
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
            EditorialClosetGallery(items: filteredItems, galleryHeight: cardHeight, buildAction: buildAction)
                .padding(.horizontal, colorScheme == .dark ? -20 : -PyxisSpacing.md)

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
