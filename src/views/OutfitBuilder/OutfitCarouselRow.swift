import SwiftUI

struct OutfitCarouselRow: View {
    let row: OutfitRow
    let selectedIndex: Int?
    let selectIndex: (Int) -> Void
    let advance: (Int) -> Void
    let openItem: (ClosetItem) -> Void

    private var selected: Int {
        selectedIndex ?? 0
    }

    private var visibleOffsets: [Int] {
        switch row.items.count {
        case 0:
            return []
        case 1:
            return [0]
        case 2:
            return [0, 1]
        case 3:
            return [-1, 0, 1]
        default:
            return [-2, -1, 0, 1, 2]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
            HStack {
                Text(row.slot.title)
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.secondaryText)

                Spacer()

                Button("PREV") {
                    advance(-1)
                }
                .buttonStyle(.plain)
                .font(PyxisTypography.label)
                .accessibilityLabel("Previous \(row.slot.title.lowercased())")

                Button("NEXT") {
                    advance(1)
                }
                .buttonStyle(.plain)
                .font(PyxisTypography.label)
                .accessibilityLabel("Next \(row.slot.title.lowercased())")
            }

            GeometryReader { proxy in
                let rowWidth = proxy.size.width
                let itemSpacing = min(132, max(76, rowWidth * 0.28))
                let selectedWidth = min(190, max(150, rowWidth * 0.48))
                let sideWidth = min(154, max(112, rowWidth * 0.38))

                ZStack {
                    ForEach(visibleOffsets, id: \.self) { offset in
                        let index = displayIndex(for: offset)
                        let item = row.items[index]

                        OutfitCarouselItemView(
                            item: item,
                            isSelected: offset == 0
                        ) {
                            if offset == 0 {
                                openItem(item)
                            } else {
                                selectIndex(index)
                            }
                        }
                        .frame(width: offset == 0 ? selectedWidth : sideWidth, height: 176)
                        .scaleEffect(offset == 0 ? 1 : 0.82)
                        .opacity(opacity(for: offset))
                        .rotation3DEffect(
                            .degrees(Double(offset) * -16),
                            axis: (x: 0, y: 1, z: 0)
                        )
                        .offset(x: CGFloat(offset) * itemSpacing)
                        .zIndex(offset == 0 ? 10 : Double(5 - abs(offset)))
                        .animation(.snappy(duration: 0.28), value: selectedIndex)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 186)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        if value.translation.width < -36 {
                            advance(1)
                        } else if value.translation.width > 36 {
                            advance(-1)
                        }
                    }
            )
            .accessibilityLabel("\(row.slot.title) carousel")
        }
    }

    private func displayIndex(for offset: Int) -> Int {
        (selected + offset + row.items.count) % row.items.count
    }

    private func opacity(for offset: Int) -> Double {
        switch abs(offset) {
        case 0:
            return 1
        case 1:
            return 0.58
        default:
            return 0.24
        }
    }
}
