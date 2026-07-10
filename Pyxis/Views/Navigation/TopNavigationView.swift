import SwiftUI

struct TopNavigationView: View {
    @Binding var filterState: ClosetFilterState
    let closets: [Closet]
    let addAction: () -> Void
    let buildAction: () -> Void
    let fitsAction: () -> Void
    let manageClosetsAction: () -> Void
    @State private var isShowingFilters = false

    init(
        filterState: Binding<ClosetFilterState>,
        closets: [Closet] = [],
        addAction: @escaping () -> Void,
        buildAction: @escaping () -> Void = {},
        fitsAction: @escaping () -> Void = {},
        manageClosetsAction: @escaping () -> Void = {}
    ) {
        self._filterState = filterState
        self.closets = closets
        self.addAction = addAction
        self.buildAction = buildAction
        self.fitsAction = fitsAction
        self.manageClosetsAction = manageClosetsAction
    }

    var body: some View {
        HStack(spacing: PyxisSpacing.md) {
            Text("PYXIS")
                .font(PyxisTypography.title)
                .foregroundStyle(PyxisColors.text)

            Spacer(minLength: PyxisSpacing.sm)

            Button(action: addAction) {
                UppercaseNavLabel(title: "New", isActive: false)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: .command)
            .accessibilityLabel("Add new item")

            Button(action: buildAction) {
                UppercaseNavLabel(title: "Build", isActive: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Build outfit")

            Button {
                isShowingFilters = true
            } label: {
                UppercaseNavLabel(title: "Filters", isActive: hasActiveCollectionFilter)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open closet filters")
            .accessibilityValue(hasActiveCollectionFilter ? "Filters selected" : "No filters selected")

            Menu {
                Button("SAVED FITS", action: fitsAction)
                Button("MANAGE CLOSETS", action: manageClosetsAction)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(PyxisColors.text)
            }
            .accessibilityLabel("More closet actions")
        }
        .sheet(isPresented: $isShowingFilters) {
            ClosetFilterSheet(filterState: $filterState, closets: closets)
                .presentationDetents([.medium, .large])
        }
    }

    private var hasActiveCollectionFilter: Bool {
        filterState.closetID != nil || filterState.category != nil || filterState.color != nil
    }
}

private struct ClosetFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filterState: ClosetFilterState
    let closets: [Closet]

    private let columns = [
        GridItem(.flexible(), spacing: PyxisSpacing.sm),
        GridItem(.flexible(), spacing: PyxisSpacing.sm)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PyxisSpacing.xl) {
                HStack {
                    VStack(alignment: .leading, spacing: PyxisSpacing.xs) {
                        Text("FILTERS")
                            .font(PyxisTypography.title)
                        Text("REFINE YOUR COLLECTION")
                            .font(PyxisTypography.label)
                            .foregroundStyle(PyxisColors.secondaryText)
                    }

                    Spacer()

                    Button("DONE") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .font(PyxisTypography.label)
                    .accessibilityLabel("Close filters")
                }

                filterSection("CLOSET") {
                    FilterOptionButton(title: "ALL CLOSETS", isSelected: filterState.closetID == nil) {
                        filterState.closetID = nil
                    }

                    ForEach(closets) { closet in
                        FilterOptionButton(
                            title: closet.displayName,
                            isSelected: filterState.closetID == closet.id
                        ) {
                            filterState.closetID = closet.id
                        }
                    }
                }

                filterSection("CATEGORY") {
                    FilterOptionButton(title: "ALL ITEMS", isSelected: filterState.category == nil) {
                        filterState.category = nil
                    }

                    ForEach(ClothingCategory.allCases) { category in
                        FilterOptionButton(
                            title: category.rawValue,
                            isSelected: filterState.category == category
                        ) {
                            filterState.category = category
                        }
                    }
                }

                filterSection("COLOR") {
                    FilterOptionButton(title: "ALL COLORS", isSelected: filterState.color == nil) {
                        filterState.color = nil
                    }

                    ForEach(ClosetColor.allCases.filter { $0 != .unknown }) { color in
                        FilterOptionButton(
                            title: color.rawValue,
                            isSelected: filterState.color == color
                        ) {
                            filterState.color = color
                        }
                    }
                }

                if hasActiveCollectionFilter {
                    Button("CLEAR FILTERS") {
                        filterState.closetID = nil
                        filterState.category = nil
                        filterState.color = nil
                    }
                    .buttonStyle(MinimalButtonStyle())
                    .accessibilityLabel("Clear closet, category, and color filters")
                }
            }
            .padding(PyxisSpacing.md)
        }
        .background(PyxisColors.background)
    }

    private func filterSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
            Text(title)
                .font(PyxisTypography.label)
                .foregroundStyle(PyxisColors.secondaryText)

            LazyVGrid(columns: columns, spacing: PyxisSpacing.sm) {
                content()
            }
        }
    }

    private var hasActiveCollectionFilter: Bool {
        filterState.closetID != nil || filterState.category != nil || filterState.color != nil
    }
}

private struct FilterOptionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(PyxisTypography.label)
                .foregroundStyle(isSelected ? PyxisColors.surface : PyxisColors.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                .padding(.horizontal, PyxisSpacing.sm)
                .background(isSelected ? PyxisColors.text : PyxisColors.field)
                .overlay {
                    Rectangle()
                        .stroke(isSelected ? PyxisColors.text : PyxisColors.hairline, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}
