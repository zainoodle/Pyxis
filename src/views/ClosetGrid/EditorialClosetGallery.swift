import SwiftUI

/// A snapping garment stage with selection shared by gallery, search, and detail.
struct EditorialClosetGallery: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var minimumCaptionHeight: CGFloat = 96
    @State private var measuredCaptionHeight: CGFloat = 0
    @State private var inspectedItem: ClosetItem?
    @State private var actionItem: ClosetItem?
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
        .navigationDestination(item: $inspectedItem) { detail(for: $0) }
        .confirmationDialog(
            actionItem.map { "\($0.itemCode) · \($0.displayName ?? $0.subtype.rawValue.capitalized)" } ?? "Piece options",
            isPresented: Binding(get: { actionItem != nil }, set: { if !$0 { actionItem = nil } }),
            titleVisibility: .visible,
            presenting: actionItem
        ) { item in
            Button("View details") { inspectedItem = item }
                .accessibilityIdentifier("closet.details")
            if OutfitBuilderService().slot(for: item.category) != nil {
                Button("Build a fit") { buildAction(item.id) }
                    .accessibilityLabel("Build a fit with \(item.itemCode)")
                    .accessibilityIdentifier("closet.build")
            }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: items.map(\.id), initial: true) { oldIDs, newIDs in
            if let selection, newIDs.contains(selection) { return }
            let index = selection.flatMap { oldIDs.firstIndex(of: $0) } ?? 0
            selection = newIDs.isEmpty ? nil : newIDs[min(index, newIDs.count - 1)]
        }
        #if DEBUG
        .task { await runDemoCycle() }
        #endif
    }

    #if DEBUG
    /// QA-only driver: `-pyxis.demoCycle` walks selection so rack sway can be
    /// recorded without a touch injector. Never ships in release builds.
    private func runDemoCycle() async {
        guard ProcessInfo.processInfo.arguments.contains("-pyxis.demoCycle") else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, items.count > 1 else { continue }
            let next = items[(selectedIndex + 1) % items.count]
            await MainActor.run {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { selection = next.id }
            }
        }
    }
    #endif

    private func gallery(width: CGFloat, imageHeight: CGFloat) -> some View {
        let garmentWidth = max(1, width * 0.68)
        let slotWidth = max(1, width * 0.34)
        let sideMargin = (width - slotWidth) / 2
        return VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(items) { item in
                            garmentLink(for: item, width: garmentWidth, slotWidth: slotWidth,
                                        viewportWidth: width, height: imageHeight)
                                .zIndex(item.id == (selection ?? items.first?.id) ? 1 : 0)
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
                .background {
                    ZStack(alignment: .top) {
                        ClosetRunwayBackground()
                        if items.contains(where: { $0.imageCutoutPath != nil && GarmentRackSupport.forCategory($0.category) != nil }) {
                            ClosetRackRail()
                        }
                    }
                }
                .clipped()
                .task(id: [width, imageHeight]) {
                    let selectedID = selection
                    await Task.yield()
                    proxy.scrollTo(selectedID, anchor: .center)
                }
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

    private func garmentLink(for item: ClosetItem, width: CGFloat, slotWidth: CGFloat,
                             viewportWidth: CGFloat, height: CGFloat) -> some View {
        let isSelected = item.id == (selection ?? items.first?.id)
        let removesMotion = reduceMotion
        let coordinateSpace = ClosetRackGarment.coordinateSpace
        let hookAnchor = UnitPoint(x: 0.5, y: GarmentRackGeometry.hookY / height)
        return ClosetRackGarment(
            url: ImageStorageService.shared?.url(for: ClosetItemImageResolver.preferredFullSizePath(for: item)),
            revision: Int(item.effectiveDateUpdated.timeIntervalSince1970 * 1_000),
            category: item.category, width: width, height: height
        )
        .frame(width: width, height: height)
        .visualEffect { content, geometry in
            let distance = abs(geometry.frame(in: .named(coordinateSpace)).midX - viewportWidth / 2)
            let proximity = max(0, 1 - distance / (viewportWidth * 0.56))
            return content
                .scaleEffect(removesMotion ? 1 : 0.82 + 0.18 * proximity, anchor: hookAnchor)
                .opacity(removesMotion ? 1 : 0.58 + 0.42 * proximity)
        }
        .frame(width: slotWidth, height: height)
        .contentShape(Rectangle())
        .background {
            RackTapTarget { showActions(for: item) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { showActions(for: item) }
        .accessibilityLabel("\(item.itemCode), \(item.displayName ?? item.subtype.rawValue)")
        .accessibilityHint("Shows garment options")
        .accessibilityIdentifier("closet.garment.\(item.itemCode)")
        .accessibilityHidden(!isSelected)
        .accessibilityAction(named: "Next garment") { moveSelection(by: 1) }
        .accessibilityAction(named: "Previous garment") { moveSelection(by: -1) }
    }

    private func caption(for item: ClosetItem) -> some View {
        let metadataLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
        return VStack(alignment: .leading, spacing: 16) {
            metadataLayout {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.displayName ?? item.subtype.rawValue.capitalized)
                        .font(PyxisDisplayFace.current.garmentName)
                        .textCase(PyxisDisplayFace.current.textCase)
                        .lineSpacing(2)
                        .foregroundStyle(PyxisColors.text)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        ItemCodeLabel(code: item.itemCode)
                        Text(item.category.rawValue.uppercased())
                            .font(PyxisTypography.editorialMicro)
                            .tracking(1.2)
                            .foregroundStyle(PyxisColors.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                position(for: item)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 16)
    }

    private func position(for item: ClosetItem) -> some View {
        Text(String(format: "%02d / %02d", selectedIndex + 1, items.count))
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

    private func showActions(for item: ClosetItem) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { selection = item.id }
        actionItem = item
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
