import SwiftData
import SwiftUI

struct ClosetGridView: View {
    @Query(sort: \ClosetItem.dateAdded, order: .reverse) private var items: [ClosetItem]
    @StateObject private var viewModel = ClosetGridViewModel()
    @State private var isShowingAddFlow = false
    @State private var isShowingBuilder = false
    @State private var isShowingSavedFits = false
    @State private var selectedItem: ClosetItem?
    @State private var builderFocusItem: ClosetItem?
    @State private var savedItemPrompt: ClosetItem?
    @State private var seedMessage: String?
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isSearchFocused: Bool

    private let columns = [
        GridItem(.adaptive(minimum: 158, maximum: 210), spacing: ArchiveSpacing.lg)
    ]

    var body: some View {
        VStack(spacing: ArchiveSpacing.lg) {
            TopNavigationView(
                filterState: $viewModel.filterState,
                addAction: { isShowingAddFlow = true },
                buildAction: {
                    builderFocusItem = nil
                    isShowingBuilder = true
                },
                fitsAction: { isShowingSavedFits = true }
            )
            .padding(.top, ArchiveSpacing.lg)

            if let savedItemPrompt {
                SavedItemBuildPrompt(item: savedItemPrompt) {
                    builderFocusItem = savedItemPrompt
                    self.savedItemPrompt = nil
                    isShowingBuilder = true
                } dismissAction: {
                    self.savedItemPrompt = nil
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            SearchAndFilterView(
                filterState: $viewModel.filterState,
                isSearchFocused: $isSearchFocused
            )

            content
        }
        .padding(.horizontal, ArchiveSpacing.md)
        .padding(.bottom, ArchiveSpacing.xl)
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
            AddItemFlow { item in
                withAnimation(.easeOut(duration: 0.2)) {
                    savedItemPrompt = item
                }
            }
        }
        .sheet(isPresented: $isShowingBuilder) {
            OutfitBuilderView(initialItem: builderFocusItem)
        }
        .sheet(isPresented: $isShowingSavedFits) {
            SavedFitsGalleryView()
        }
        .sheet(item: $selectedItem) { item in
            ItemDetailView(item: item) { buildItem in
                builderFocusItem = buildItem
                selectedItem = nil
                Task {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    await MainActor.run {
                        isShowingBuilder = true
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        let filteredItems = viewModel.filteredItems(from: items)

        if items.isEmpty {
            Spacer()
            VStack(spacing: ArchiveSpacing.md) {
                EmptyArchiveState {
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
                        .font(ArchiveTypography.label)
                        .foregroundStyle(ArchiveColors.secondaryText)
                }
                #endif
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
                        ClosetGridItemView(item: item) {
                            selectedItem = item
                        }
                    }
                }
                .padding(.top, ArchiveSpacing.md)
            }
        }
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
        HStack(spacing: ArchiveSpacing.md) {
            VStack(alignment: .leading, spacing: ArchiveSpacing.xs) {
                Text("SAVED \(item.itemCode)")
                    .font(ArchiveTypography.label)
                    .foregroundStyle(ArchiveColors.secondaryText)

                Text(item.displayName?.uppercased() ?? item.subtype.rawValue.uppercased())
                    .font(ArchiveTypography.body)
                    .foregroundStyle(ArchiveColors.text)
                    .lineLimit(1)
            }

            Spacer()

            if OutfitBuilderService().slot(for: item.category) != nil {
                Button("BUILD WITH THIS", action: buildAction)
                    .buttonStyle(MinimalButtonStyle())
            }

            Button("READY", action: dismissAction)
                .buttonStyle(.plain)
                .font(ArchiveTypography.label)
                .foregroundStyle(ArchiveColors.secondaryText)
        }
        .padding(ArchiveSpacing.md)
        .background(ArchiveColors.field)
    }
}
