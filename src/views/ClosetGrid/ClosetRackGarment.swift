import SwiftUI

enum GarmentRackSupport {
    case shoulder
    case clips

    static func forCategory(_ category: ClothingCategory) -> Self? {
        switch category {
        case .tops, .outerwear, .onePiece: .shoulder
        case .bottoms: .clips
        case .footwear, .accessories, .other: nil
        }
    }
}

/// The support stays behind the photo; it never paints over fabric or generates a new pose.
struct GarmentRackHanger: Shape {
    let support: GarmentRackSupport

    func path(in rect: CGRect) -> Path {
        let center = rect.midX
        var path = Path()
        path.move(to: CGPoint(x: center - 7, y: 9))
        path.addCurve(to: CGPoint(x: center + 8, y: 9),
                      control1: CGPoint(x: center - 7, y: -2),
                      control2: CGPoint(x: center + 8, y: -2))
        path.addCurve(to: CGPoint(x: center, y: 29),
                      control1: CGPoint(x: center + 10, y: 21),
                      control2: CGPoint(x: center - 2, y: 22))
        path.addLine(to: CGPoint(x: center, y: 34))
        if support == .shoulder {
            path.addLine(to: CGPoint(x: rect.minX + 4, y: 59))
            path.addQuadCurve(to: CGPoint(x: rect.minX + 9, y: 64),
                              control: CGPoint(x: rect.minX - 1, y: 64))
            path.addLine(to: CGPoint(x: rect.maxX - 9, y: 64))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - 4, y: 59),
                              control: CGPoint(x: rect.maxX + 1, y: 64))
            path.addLine(to: CGPoint(x: center, y: 34))
        } else {
            path.addLine(to: CGPoint(x: rect.minX + 8, y: 43))
            path.addLine(to: CGPoint(x: rect.maxX - 8, y: 43))
            path.addLine(to: CGPoint(x: center, y: 34))
            for x in [rect.minX + 14, rect.maxX - 14] {
                path.move(to: CGPoint(x: x, y: 43))
                path.addLine(to: CGPoint(x: x, y: 57))
            }
        }
        return path
    }
}

struct ClosetRackGarment: View {
    static let coordinateSpace = "closet.rack.viewport"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    let url: URL?
    let revision: Int
    let category: ClothingCategory
    let width: CGFloat
    let height: CGFloat
    @State private var sway = ClosetRackSway()
    @State private var isAnimating = false
    @State private var previousPosition: CGFloat?
    @State private var previousTime = 0.0
    @State private var previousVelocity = 0.0

    private var support: GarmentRackSupport? {
        guard url?.deletingLastPathComponent().lastPathComponent == "Cutouts" else { return nil }
        return GarmentRackSupport.forCategory(category)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: !isAnimating || reduceMotion)) { _ in
            LocalImageView(url: url, revision: revision, balancedFraming: true,
                           castsShadow: true, rackSupport: support)
                .padding(support == nil ? 20 : 0)
                .frame(width: width, height: height)
                .rotationEffect(.radians(reduceMotion || support == nil ? 0 : sway.sample(at: now).angle),
                                anchor: UnitPoint(x: 0.5, y: GarmentRackGeometry.hookY / height))
        }
        .background {
            GeometryReader { geometry in
                Color.clear.preference(key: RackPositionKey.self,
                                       value: geometry.frame(in: .named(Self.coordinateSpace)).midX)
            }
        }
        .onPreferenceChange(RackPositionKey.self) { observe(position: $0) }
        .task(id: sway.startedAt) {
            guard isAnimating else { return }
            do { try await Task.sleep(for: .milliseconds(900)) } catch { return }
            isAnimating = false
            sway.reset()
            previousVelocity = 0
        }
        .onChange(of: reduceMotion) { _, _ in stopMotion() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { stopMotion() } }
        .onDisappear { stopMotion() }
    }

    private var now: Double { ProcessInfo.processInfo.systemUptime }

    private func observe(position: CGFloat) {
        let time = now
        defer { previousPosition = position; previousTime = time }
        guard let previousPosition, !reduceMotion, support != nil, scenePhase == .active else { return }
        let elapsed = time - previousTime
        guard elapsed > 0.002, elapsed < 0.18 else { previousVelocity = 0; return }
        let velocity = min(1_600, max(-1_600, Double(position - previousPosition) / elapsed))
        guard abs(position - previousPosition) > 0.15 else { return }
        sway.nudge(velocityChange: velocity - previousVelocity, at: time)
        previousVelocity = velocity
        isAnimating = true
    }

    private func stopMotion() {
        isAnimating = false
        sway.reset()
        previousPosition = nil
        previousVelocity = 0
    }
}

private struct RackPositionKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
