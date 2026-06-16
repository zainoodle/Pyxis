import SwiftUI

struct TopNavigationView: View {
    @Binding var filterState: ClosetFilterState
    let closets: [Closet]
    let addAction: () -> Void
    let buildAction: () -> Void
    let fitsAction: () -> Void
    let manageClosetsAction: () -> Void

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
        VStack(spacing: PyxisSpacing.sm) {
            actionRow
            closetRow
            categoryRow

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PyxisSpacing.md) {
                    colorButton(nil, title: "Colors")
                    ForEach([ClosetColor.black, .white, .gray, .brown, .blue, .green, .red], id: \.self) { color in
                        colorButton(color, title: color.rawValue)
                    }
                }
                .padding(.horizontal, PyxisSpacing.xs)
            }
        }
    }

    private var actionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PyxisSpacing.lg) {
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

                Button(action: fitsAction) {
                    UppercaseNavLabel(title: "Fits", isActive: false)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Saved fits")

                Button(action: manageClosetsAction) {
                    UppercaseNavLabel(title: "Closets", isActive: filterState.closetID != nil)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Manage closets")
            }
            .padding(.horizontal, PyxisSpacing.xs)
        }
    }

    @ViewBuilder
    private var closetRow: some View {
        if !closets.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PyxisSpacing.lg) {
                    closetButton(nil, title: "All Closets")
                    ForEach(closets) { closet in
                        closetButton(closet.id, title: closet.displayName)
                    }
                }
                .padding(.horizontal, PyxisSpacing.xs)
            }
        }
    }

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PyxisSpacing.lg) {
                categoryButton(nil, title: "All")
                categoryButton(.tops, title: "Tops")
                categoryButton(.bottoms, title: "Bottoms")
                categoryButton(.outerwear, title: "Outerwear")
                categoryButton(.footwear, title: "Footwear")
                categoryButton(.accessories, title: "Accessories")
            }
            .padding(.horizontal, PyxisSpacing.xs)
        }
    }

    private func closetButton(_ closetID: UUID?, title: String) -> some View {
        Button {
            filterState.closetID = closetID
        } label: {
            UppercaseNavLabel(title: title, isActive: filterState.closetID == closetID)
        }
        .buttonStyle(.plain)
    }

    private func categoryButton(_ category: ClothingCategory?, title: String) -> some View {
        Button {
            filterState.category = category
        } label: {
            UppercaseNavLabel(title: title, isActive: filterState.category == category)
        }
        .buttonStyle(.plain)
    }

    private func colorButton(_ color: ClosetColor?, title: String) -> some View {
        Button {
            filterState.color = color
        } label: {
            UppercaseNavLabel(title: title, isActive: filterState.color == color)
        }
        .buttonStyle(.plain)
    }
}
