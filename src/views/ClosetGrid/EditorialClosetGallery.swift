import SwiftUI

/// A snapping garment stage with selection shared by gallery, search, and detail.
struct EditorialClosetGallery: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var minimumCaptionHeight: CGFloat = 208
    @State private var measuredCaptionHeight: CGFloat = 0
    let items: [ClosetItem]
    @Binding var selection: UUID?
    let buildAction: (UUID?) -> Void

    private var selectedIndex: Int { items.firstIndex { $0.id == selection } ?? 0 }
    private var captionHeight: CGFloat { max(minimumCaptionHeight, measuredCaptionHeight) }

    var body: some View {
        GeometryReader { geometry in
            let imageHeight = max(220, geometry.size.height - captionHeight)
            if dynamicTypeSize.isAccessibilitySize || geometry.size.height < captionHeight + 220 {
                ScrollView(.vertical) { gallery(width: geometry.size.width, imageHeight: 270) }
            } else {
                gallery(width: geometry.size.width, imageHeight: imageHeight)
            }
        }
        .onChange(of: items.map(\.id), initial: true) { oldIDs, newIDs in
            if let selection, newIDs.contains(selection) { return }
            let index = selection.flatMap { oldIDs.firstIndex(of: $0) } ?? 0
            selection = newIDs.isEmpty ? nil : newIDs[min(index, newIDs.count - 1)]
        }
    }

    private func gallery(width: CGFloat, imageHeight: CGFloat) -> some View {
        let garmentWidth = max(1, width * 0.68)
        let sideMargin = (width - garmentWidth) / 2
        return VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(items) { item in
                            garmentLink(for: item, width: garmentWidth, height: imageHeight)
                                .id(item.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, sideMargin, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .scrollPosition(id: $selection, anchor: .center)
                .frame(height: imageHeight)
                .coordinateSpace(name: ClosetRackGarment.coordinateSpace)
                .background { GarmentStageBackground() }
                .overlay(alignment: .top) {
                    if items.contains(where: { $0.imageCutoutPath != nil && GarmentRackSupport.forCategory($0.category) != nil }) {
                        Rectangle()
                            .fill(PyxisColors.secondaryText.opacity(0.55))
                            .frame(height: 1.5)
                            .padding(.top, GarmentRackGeometry.hookY)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(PyxisColors.hairline.opacity(0.65), lineWidth: 1)
                        .allowsHitTesting(false)
                }
                .onAppear { proxy.scrollTo(selection, anchor: .center) }
                .onChange(of: imageHeight) { _, _ in proxy.scrollTo(selection, anchor: .center) }
                .onChange(of: width) { _, _ in proxy.scrollTo(selection, anchor: .center) }
                .onChange(of: items.map(\.id)) { _, _ in proxy.scrollTo(selection, anchor: .center) }
            }
            if !items.isEmpty {
                caption(for: items[selectedIndex])
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .background {
                        GeometryReader { geometry in
                            Color.clear.preference(key: RackCaptionHeightKey.self, value: geometry.size.height)
                        }
                    }
                    .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 0 : captionHeight, alignment: .bottom)
                    .onPreferenceChange(RackCaptionHeightKey.self) { height in
                        if abs(height - measuredCaptionHeight) > 0.5 { measuredCaptionHeight = height }
                    }
            }
        }
    }

    private func garmentLink(for item: ClosetItem, width: CGFloat, height: CGFloat) -> some View {
        let isSelected = item.id == (selection ?? items.first?.id)
        return NavigationLink {
            detail(for: item)
        } label: {
            ClosetRackGarment(
                url: ImageStorageService.shared?.url(for: ClosetItemImageResolver.preferredFullSizePath(for: item)),
                revision: Int(item.effectiveDateUpdated.timeIntervalSince1970 * 1_000),
                category: item.category, width: width, height: height
            )
            .frame(width: width, height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.itemCode), \(item.displayName ?? item.subtype.rawValue)")
        .accessibilityHint("Opens garment details")
        .accessibilityIdentifier("closet.garment.\(item.itemCode)")
        .accessibilityHidden(!isSelected)
        .accessibilityAction(named: "Next garment") { moveSelection(by: 1) }
        .accessibilityAction(named: "Previous garment") { moveSelection(by: -1) }
    }

    private func caption(for item: ClosetItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.displayName ?? item.subtype.rawValue.capitalized)
                .font(PyxisTypography.garmentTitle)
                .foregroundStyle(PyxisColors.text)
                .fixedSize(horizontal: false, vertical: true)
            ItemCodeLabel(code: item.itemCode)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { position(for: item); Spacer(minLength: 0); detailLink(for: item) }
                VStack(alignment: .leading, spacing: 0) { position(for: item); detailLink(for: item) }
            }
            if OutfitBuilderService().slot(for: item.category) != nil {
                Button("Build with this") { buildAction(item.id) }
                    .buttonStyle(EditorialPrimaryButtonStyle())
                    .accessibilityIdentifier("closet.build")
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 16)
    }

    private func position(for item: ClosetItem) -> some View {
        Text("\(item.category == .onePiece ? "One piece" : item.category.rawValue.capitalized) · \(String(format: "%02d / %02d", selectedIndex + 1, items.count))")
            .font(PyxisTypography.editorialLabel)
            .foregroundStyle(PyxisColors.secondaryText)
            .monospacedDigit()
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("closet.position")
            .accessibilityLabel("\(item.category.rawValue), garment \(selectedIndex + 1) of \(items.count)")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: moveSelection(by: 1)
                case .decrement: moveSelection(by: -1)
                @unknown default: break
                }
            }
    }

    private func detailLink(for item: ClosetItem) -> some View {
        NavigationLink { detail(for: item) } label: {
            Label("View details", systemImage: "arrow.right")
                .labelStyle(.titleAndIcon)
                .font(PyxisTypography.editorialLabel)
                .foregroundStyle(PyxisColors.secondaryText)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("closet.details")
    }

    private func detail(for item: ClosetItem) -> some View {
        ItemDetailView(item: item, showsCloseButton: false) { buildAction($0.id) }
    }

    private func moveSelection(by offset: Int) {
        guard !items.isEmpty else { return }
        let index = min(max(0, selectedIndex + offset), items.count - 1)
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { selection = items[index].id }
    }
}

private struct RackCaptionHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
