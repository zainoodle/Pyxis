import SwiftUI

struct TopNavigationView: View {
    @Binding var filterState: ClosetFilterState
    let addAction: () -> Void
    let buildAction: () -> Void
    let fitsAction: () -> Void

    init(
        filterState: Binding<ClosetFilterState>,
        addAction: @escaping () -> Void,
        buildAction: @escaping () -> Void = {},
        fitsAction: @escaping () -> Void = {}
    ) {
        self._filterState = filterState
        self.addAction = addAction
        self.buildAction = buildAction
        self.fitsAction = fitsAction
    }

    var body: some View {
        VStack(spacing: ArchiveSpacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ArchiveSpacing.lg) {
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

                    categoryButton(nil, title: "All")
                    categoryButton(.tops, title: "Tops")
                    categoryButton(.bottoms, title: "Bottoms")
                    categoryButton(.outerwear, title: "Outerwear")
                    categoryButton(.footwear, title: "Footwear")
                    categoryButton(.accessories, title: "Accessories")
                }
                .padding(.horizontal, ArchiveSpacing.xs)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ArchiveSpacing.md) {
                    colorButton(nil, title: "Colors")
                    ForEach([ClosetColor.black, .white, .gray, .brown, .blue, .green, .red], id: \.self) { color in
                        colorButton(color, title: color.rawValue)
                    }
                }
                .padding(.horizontal, ArchiveSpacing.xs)
            }
        }
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
