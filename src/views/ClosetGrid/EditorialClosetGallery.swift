import SwiftUI

/// A native snapping gallery. Selection is owned by the closet so it survives
/// detail navigation, tab changes, and search-sheet dismissal.
struct EditorialClosetGallery: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var captionHeight: CGFloat = 112
    let items: [ClosetItem]
    @Binding var selection: UUID?
    let buildAction: (UUID?) -> Void

    private var selectedIndex: Int {
        items.firstIndex { $0.id == selection } ?? 0
    }

    var body: some View {
        GeometryReader { geometry in
            let imageHeight = max(200, geometry.size.height - captionHeight)
            if geometry.size.height < captionHeight + 200 {
                ScrollView(.vertical) {
                    gallery(width: geometry.size.width, imageHeight: 240)
                }
            } else {
                gallery(width: geometry.size.width, imageHeight: imageHeight)
            }
        }
        .onChange(of: items.map(\.id), initial: true) { oldIDs, newIDs in
            if let selection, newIDs.contains(selection) { return }
            let previousIndex = selection.flatMap { oldIDs.firstIndex(of: $0) } ?? 0
            selection = newIDs.isEmpty ? nil : newIDs[min(previousIndex, newIDs.count - 1)]
        }
    }

    private func gallery(width: CGFloat, imageHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(items) { item in
                            garmentLink(for: item, width: max(1, width - 36), height: imageHeight)
                                .id(item.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, 18, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .scrollPosition(id: $selection, anchor: .center)
                .frame(height: imageHeight)
                .onAppear { proxy.scrollTo(selection, anchor: .center) }
                .onChange(of: imageHeight) { _, _ in
                    proxy.scrollTo(selection, anchor: .center)
                }
                .onChange(of: width) { _, _ in
                    proxy.scrollTo(selection, anchor: .center)
                }
                .onChange(of: items.map(\.id)) { _, _ in
                    proxy.scrollTo(selection, anchor: .center)
                }
            }

            if !items.isEmpty {
                caption(for: items[selectedIndex])
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: captionHeight, alignment: .center)
            }
        }
    }

    private func garmentLink(for item: ClosetItem, width: CGFloat, height: CGFloat) -> some View {
        let path = ClosetItemImageResolver.preferredFullSizePath(for: item)
        let url = ImageStorageService.shared?.url(for: path)
        let revision = Int(item.effectiveDateUpdated.timeIntervalSince1970 * 1_000)
        let itemIndex = items.firstIndex { $0.id == item.id } ?? 0
        let isSelected = item.id == (selection ?? items.first?.id)

        return NavigationLink {
            ItemDetailView(item: item, showsCloseButton: false) { buildItem in
                buildAction(buildItem.id)
            }
        } label: {
            LocalImageView(url: url, revision: revision)
                .padding(.vertical, 8)
                .frame(width: width, height: height)
                .shadow(color: .black.opacity(0.25), radius: 16, y: 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.itemCode), \(item.displayName ?? item.subtype.rawValue.capitalized)")
        .accessibilityValue("\(item.category.rawValue.capitalized), \(itemIndex + 1) of \(items.count)")
        .accessibilityHint("Opens garment details")
        .accessibilityIdentifier("closet.garment.\(item.itemCode)")
        .accessibilityHidden(!isSelected)
        .accessibilityAction(named: "Next garment") { moveSelection(by: 1) }
        .accessibilityAction(named: "Previous garment") { moveSelection(by: -1) }
    }

    private func caption(for item: ClosetItem) -> some View {
        VStack(spacing: 8) {
            Text((item.displayName ?? item.subtype.rawValue).uppercased())
                .font(PyxisTypography.editorialBody)
                .tracking(0.8)
                .foregroundStyle(PyxisColors.text)
                .fixedSize(horizontal: false, vertical: true)
            ItemCodeLabel(code: item.itemCode)
            Text("\(item.category == .onePiece ? "One piece" : item.category.rawValue.capitalized) · \(String(format: "%02d / %02d", selectedIndex + 1, items.count))")
                .font(PyxisTypography.editorialLabel)
                .monospacedDigit()
                .tracking(1.1)
                .foregroundStyle(PyxisColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("closet.position")
        .accessibilityLabel("\(item.itemCode), \(item.displayName ?? item.subtype.rawValue), \(item.category.rawValue)")
        .accessibilityValue("Garment \(selectedIndex + 1) of \(items.count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: moveSelection(by: 1)
            case .decrement: moveSelection(by: -1)
            @unknown default: break
            }
        }
    }

    private func moveSelection(by offset: Int) {
        guard !items.isEmpty else { return }
        let index = min(max(0, selectedIndex + offset), items.count - 1)
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
            selection = items[index].id
        }
    }
}
