import SwiftData
import SwiftUI

/// Garment cards standing on a shallow concave ring that curls around the viewer,
/// after Scrolltide's "Media Gallery" component. The middle slot is farthest
/// (smallest); cards toward the edges grow larger and lean inward.
///
/// Positions are solved in projected space — card centers are spaced by the
/// integral of their neighbors' scaled half-widths — so the gaps between card
/// edges stay even after the perspective transforms.
struct EditorialClosetGallery: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.modelContext) private var modelContext

    let items: [ClosetItem]
    let galleryHeight: CGFloat
    let buildAction: (UUID?) -> Void

    /// Continuous gallery offset in item units; `0` centers `items[0]`.
    @State private var offset: CGFloat = 0
    @State private var selectedID: UUID?
    @State private var saveError: String?
    @State private var dragOrigin: CGFloat?
    @State private var probe = GalleryOffsetProbe()

    private var selectedItem: ClosetItem? {
        items.first { $0.id == selectedID } ?? items.first
    }

    private func geometry(for width: CGFloat) -> GalleryGeometry {
        let cardWidth = min(width * 0.21, 96)
        return GalleryGeometry(
            cardWidth: cardWidth,
            cardHeight: cardWidth / 0.62
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let geom = self.geometry(for: geometry.size.width)
                let centerX = geometry.size.width / 2
                let cardCenterY = geometry.size.height * 0.52

                ZStack {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        let t = CGFloat(index) - offset
                        if abs(t) < 4.4 {
                            galleryCard(item: item, index: index, geom: geom)
                                .scaleEffect(geom.scale(t))
                                .rotation3DEffect(
                                    .degrees(geom.lean(t)),
                                    axis: (x: 0, y: 1, z: 0),
                                    perspective: 0.55
                                )
                                .position(
                                    x: centerX + geom.projectedX(t),
                                    y: cardCenterY + geom.lift(t)
                                )
                                .zIndex(abs(t))
                        }
                    }

                    // Overlays live outside the perspective transform so the
                    // item code and favorite control keep a constant, legible,
                    // tappable size at every arc position. The heart only lands
                    // on cards large enough to host a comfortable target.
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        let t = CGFloat(index) - offset
                        if abs(t) < 3.4 {
                            cardOverlay(
                                item: item,
                                geom: geom,
                                t: t,
                                centerX: centerX,
                                cardCenterY: cardCenterY,
                                showsFavorite: abs(t) < 1.6
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .gesture(drag(in: geom))
                .modifier(GalleryOffsetReporter(value: offset, probe: probe))
                .accessibilityAdjustableAction { direction in
                    let step: CGFloat = direction == .increment ? 1 : -1
                    settle(to: (offset + step).rounded(), in: geom)
                }
            }
            .frame(height: galleryHeight)

            if let saveError {
                Text(saveError)
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.text)
                    .padding(.top, 12)
                    .accessibilityAddTraits(.updatesFrequently)
            }

            if let selectedItem {
                NavigationLink {
                    ItemDetailView(item: selectedItem, showsCloseButton: false) { buildItem in
                        buildAction(buildItem.id)
                    }
                } label: {
                    Text("VIEW ITEM")
                        .font(PyxisTypography.editorialBody)
                        .tracking(2)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(PyxisColors.text)
                        .overlay { RoundedRectangle(cornerRadius: 8).stroke(PyxisColors.text.opacity(0.8), lineWidth: 0.8) }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View \(selectedItem.displayName ?? selectedItem.itemCode)")
                .padding(.top, 24)
            }
        }
        .onAppear {
            if !items.isEmpty, selectedID == nil {
                let middle = CGFloat(items.count - 1) / 2
                offset = middle
                probe.current = middle
                selectedID = items[Int(middle.rounded())].id
            }
        }
        .onChange(of: items.map(\.id)) { _, ids in
            let count = CGFloat(ids.count)
            if offset > max(0, count - 1) {
                offset = max(0, count - 1)
            }
            if let selectedID, !ids.contains(selectedID) {
                self.selectedID = nil
            }
            if !ids.isEmpty, selectedID == nil, ids.indices.contains(Int(offset.rounded())) {
                selectedID = ids[Int(offset.rounded())]
            }
        }
        .sensoryFeedback(.selection, trigger: selectedID)
        .background {
            #if DEBUG
            galleryDemoDriver
            #endif
        }
    }

    #if DEBUG
    /// Drives the gallery offset for headless motion capture when launched with
    /// `-pyxisGalleryDemo`. Never ships in release builds.
    @ViewBuilder
    private var galleryDemoDriver: some View {
        if ProcessInfo.processInfo.arguments.contains("-pyxisGalleryDemo") {
            TimelineView(.animation) { context in
                Color.clear
                    .onChange(of: context.date, initial: true) { _, date in
                        let elapsed = date.timeIntervalSinceReferenceDate
                        let middle = CGFloat(max(0, items.count - 1)) / 2
                        offset = middle + middle * sin(elapsed * 0.55)
                    }
            }
        }
    }
    #endif

    // MARK: - Cards

    private func galleryCard(item: ClosetItem, index: Int, geom: GalleryGeometry) -> some View {
        let isSelected = item.id == selectedItem?.id
        return Button {
            select(index)
        } label: {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(PyxisColors.field.opacity(colorScheme == .dark ? 0.55 : 0.7))

                LocalImageView(
                    url: imageURL(for: item),
                    revision: Int(item.effectiveDateUpdated.timeIntervalSince1970 * 1_000)
                )
                .padding(16)

                if isSelected, contrast != .increased {
                    Ellipse()
                        .fill(glowColor.opacity(0.32))
                        .frame(height: 52)
                        .blur(radius: 18)
                        .offset(y: 14)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(GalleryCardButtonStyle())
        .frame(width: geom.cardWidth, height: geom.cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(PyxisColors.hairline, lineWidth: contrast == .increased ? 1.5 : 0.75)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            if isSelected, contrast != .increased {
                Capsule()
                    .fill(glowColor.opacity(0.85))
                    .frame(width: geom.cardWidth * 0.6, height: 1)
                    .blur(radius: 1.2)
                    .padding(.bottom, 5)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel("\(item.itemCode), \(item.displayName ?? item.subtype.rawValue), item \(index + 1) of \(items.count)")
        .accessibilityHint("Activates to focus this garment in the gallery")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var glowColor: Color {
        colorScheme == .dark ? .white : PyxisColors.hairline
    }

    @ViewBuilder
    private func cardOverlay(
        item: ClosetItem,
        geom: GalleryGeometry,
        t: CGFloat,
        centerX: CGFloat,
        cardCenterY: CGFloat,
        showsFavorite: Bool
    ) -> some View {
        let scale = geom.scale(t)
        let leanRadians = CGFloat(geom.lean(t)) * .pi / 180
        let halfWidth = geom.cardWidth * scale * 0.5 * cos(leanRadians)
        let halfHeight = geom.cardHeight * scale * 0.5
        let cardX = centerX + geom.projectedX(t)
        let cardTop = cardCenterY + geom.lift(t) - halfHeight

        Color.clear
            .frame(width: halfWidth * 2 - 8, height: 1)
            .overlay(alignment: .topLeading) {
                Text(item.itemCode)
                    .font(.custom("IBMPlexMono-Regular", size: 10.5))
                    .tracking(0.8)
                    .foregroundStyle(PyxisColors.text.opacity(0.9))
                    .lineLimit(1)
                    .frame(maxWidth: halfWidth * 2 - (showsFavorite ? 44 : 10), alignment: .leading)
                    .padding(6)
            }
            .position(x: cardX, y: cardTop + 4)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

        if showsFavorite {
            Button {
                toggleFavorite(item)
            } label: {
                Image(systemName: item.favorite ? "heart.fill" : "heart")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(PyxisColors.text)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: cardX + halfWidth - 20, y: cardTop + 24)
            .accessibilityLabel(item.favorite ? "Remove \(item.itemCode) from favorites" : "Favorite \(item.itemCode)")
        }
    }

    // MARK: - Drag

    private func drag(in geom: GalleryGeometry) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onChanged { value in
                let base = dragOrigin ?? probe.current
                dragOrigin = base
                let raw = base - value.translation.width / geom.pointsPerItem
                offset = rubberBanded(raw)
            }
            .onEnded { value in
                dragOrigin = nil
                let projected = (value.predictedEndTranslation.width - value.translation.width)
                    / geom.pointsPerItem
                settle(to: (offset - projected).rounded(), in: geom)
            }
    }

    private func settle(to target: CGFloat, in geom: GalleryGeometry) {
        guard !items.isEmpty else { return }
        let clamped = max(0, min(CGFloat(items.count - 1), target))
        let animation: Animation = reduceMotion
            ? .easeOut(duration: 0.2)
            : .spring(response: 0.5, dampingFraction: 0.84)
        withAnimation(animation) {
            offset = clamped
        }
        let index = Int(clamped)
        if items.indices.contains(index) {
            selectedID = items[index].id
        }
    }

    private func select(_ index: Int) {
        guard items.indices.contains(index) else { return }
        selectedID = items[index].id
        settle(to: CGFloat(index), in: geometry(for: probe.width))
    }

    private func rubberBanded(_ t: CGFloat) -> CGFloat {
        let upper = CGFloat(max(0, items.count - 1))
        if t < 0 { return -rubberAmount(-t) }
        if t > upper { return upper + rubberAmount(t - upper) }
        return t
    }

    private func rubberAmount(_ overshoot: CGFloat) -> CGFloat {
        (overshoot * 0.55) / (1 + 0.55 * overshoot)
    }

    private func imageURL(for item: ClosetItem) -> URL? {
        ImageStorageService.shared?.url(for: ClosetItemImageResolver.preferredDisplayPath(for: item))
    }

    private func toggleFavorite(_ item: ClosetItem) {
        let previousFavorite = item.favorite
        let previousDate = item.dateUpdated
        item.favorite.toggle()
        item.touch()
        do {
            try modelContext.save()
            saveError = nil
        } catch {
            item.favorite = previousFavorite
            item.dateUpdated = previousDate
            saveError = PersistenceErrorMessage.saveFailed(error)
        }
    }
}

// MARK: - Geometry

/// Maps a continuous gallery offset (in item units) to projected position,
/// scale, lean, and lift for one card.
private struct GalleryGeometry {
    var cardWidth: CGFloat
    var cardHeight: CGFloat
    /// Visual gap maintained between adjacent projected card edges.
    var gap: CGFloat = 12

    var sMin: CGFloat = 1.0
    var sMax: CGFloat = 1.34
    var halfRange: CGFloat = 3.2
    var exponent: CGFloat = 1.45
    var leanDegrees: CGFloat = 38
    var liftFraction: CGFloat = 0.13

    /// Perspective scale of a card at offset `t`. The middle slot is the
    /// farthest point on the ring, so it renders smallest.
    func scale(_ t: CGFloat) -> CGFloat {
        let u = min(abs(t) / halfRange, 1)
        return sMin + (sMax - sMin) * pow(u, exponent)
    }

    /// Projected x for a card at offset `t`, integrating the scaled half-width
    /// of every slot on the way so adjacent card edges keep an even gap after
    /// perspective scaling.
    func projectedX(_ t: CGFloat) -> CGFloat {
        let u = abs(t)
        let delta = sMax - sMin
        let envelope = u <= halfRange
            ? pow(u, exponent + 1) / ((exponent + 1) * pow(halfRange, exponent))
            : halfRange / (exponent + 1) + (u - halfRange)
        let x = (cardWidth * sMin + gap) * u + cardWidth * delta * envelope
        return t < 0 ? -x : x
    }

    /// Cards lean inward around the ring; magnitude grows with distance from
    /// the middle and caps just past the visible range.
    func lean(_ t: CGFloat) -> Double {
        Double(max(-1.25, min(1.25, t / halfRange))) * Double(leanDegrees)
    }

    /// The ring's far wall sits slightly higher, lifting middle cards.
    func lift(_ t: CGFloat) -> CGFloat {
        -cardHeight * liftFraction * max(0, 1 - abs(t) / (halfRange + 0.6))
    }

    /// Points of horizontal drag travel per item slot near mid-arc.
    var pointsPerItem: CGFloat { scale(1) * cardWidth + gap }
}

// MARK: - Interruptible offset reporting

/// Receives the gallery's live (presentation-layer) offset during animations so
/// a new drag can pick up exactly where the cards are on screen.
private final class GalleryOffsetProbe {
    var current: CGFloat = 0
    var width: CGFloat = 320
}

private struct GalleryOffsetReporter: AnimatableModifier {
    var value: CGFloat
    let probe: GalleryOffsetProbe

    var animatableData: CGFloat {
        get { value }
        set { value = newValue }
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: value, initial: true) { _, new in probe.current = new }
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { probe.width = proxy.size.width }
                        .onChange(of: proxy.size.width) { _, w in probe.width = w }
                }
            )
    }
}

private struct GalleryCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
