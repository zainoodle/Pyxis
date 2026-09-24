import SwiftUI

struct TopNavigationView: View {
    @Binding var filterState: ClosetFilterState
    let closets: [Closet]
    let showsFilters: Bool
    let addAction: () -> Void
    @State private var isShowingFilters = false

    init(
        filterState: Binding<ClosetFilterState>,
        closets: [Closet] = [],
        showsFilters: Bool = true,
        addAction: @escaping () -> Void
    ) {
        self._filterState = filterState
        self.closets = closets
        self.showsFilters = showsFilters
        self.addAction = addAction
    }

    var body: some View {
        PrimaryPageHeader {
            navigationActions
        }
        .sheet(isPresented: $isShowingFilters) {
            ClosetFilterSheet(filterState: $filterState, closets: closets)
                .presentationDetents([.medium, .large])
        }
    }

    private var navigationActions: some View {
        HStack(spacing: PyxisSpacing.md) {
            Button(action: addAction) {
                UppercaseNavLabel(title: "New", isActive: false)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: .command)
            .accessibilityLabel("Add new item")

            if showsFilters {
                Button {
                    isShowingFilters = true
                } label: {
                    UppercaseNavLabel(
                        title: filterState.activeFilterCount == 0
                            ? "Filters"
                            : "Filters \(filterState.activeFilterCount)",
                        isActive: filterState.hasActiveFilters
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open closet filters")
                .accessibilityValue(
                    filterState.activeFilterCount == 0
                        ? "No active filters"
                        : "\(filterState.activeFilterCount) active filters"
                )
            }
        }
    }
}

private struct ClosetFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var filterState: ClosetFilterState
    let closets: [Closet]

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: PyxisSpacing.sm),
            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PyxisSpacing.xl) {
                ViewThatFits(in: .horizontal) {
                    HStack {
                        filterHeading
                        Spacer()
                        doneButton
                    }

                    VStack(alignment: .leading, spacing: PyxisSpacing.md) {
                        filterHeading
                        doneButton
                    }
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
                        filterState.selectCategory(nil)
                    }

                    ForEach(ClothingCategory.allCases) { category in
                        FilterOptionButton(
                            title: category.rawValue,
                            isSelected: filterState.category == category
                        ) {
                            filterState.selectCategory(category)
                        }
                    }
                }

                if let category = filterState.category {
                    filterSection("SUBTYPE") {
                        FilterOptionButton(title: "ALL \(category.rawValue)", isSelected: filterState.subtype == nil) {
                            filterState.subtype = nil
                        }

                        ForEach(ClothingSubtype.compatibleSubtypes(for: category)) { subtype in
                            FilterOptionButton(
                                title: subtype.rawValue,
                                isSelected: filterState.subtype == subtype
                            ) {
                                filterState.subtype = subtype
                            }
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

                if filterState.hasActiveFilters {
                    Button("CLEAR ALL") {
                        filterState.clearAll()
                    }
                    .buttonStyle(MinimalButtonStyle())
                    .accessibilityLabel("Clear search, closet, category, subtype, color, favorites, and sort")
                }
            }
            .padding(PyxisSpacing.md)
        }
        .background(PyxisColors.background)
    }

    private var filterHeading: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.xs) {
            Text("FILTERS")
                .font(PyxisTypography.title)
            Text("REFINE YOUR COLLECTION")
                .font(PyxisTypography.label)
                .foregroundStyle(PyxisColors.secondaryText)
        }
    }

    private var doneButton: some View {
        Button {
            dismiss()
        } label: {
            Text("DONE")
                .font(PyxisTypography.label)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close filters")
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
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
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
