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

/// A satin metal hook and a solid shoulder support, drawn behind the accepted cutout.
struct GarmentRackHanger: View {
    let support: GarmentRackSupport
    @Environment(\.colorScheme) private var colorScheme

    private var metal: LinearGradient {
        LinearGradient(colors: [PyxisColors.secondaryText, PyxisColors.text.opacity(0.85),
                                PyxisColors.secondaryText], startPoint: .leading, endPoint: .trailing)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .top) {
                Path { path in
                    let center = width / 2
                    path.move(to: CGPoint(x: center - 7, y: 9))
                    path.addCurve(to: CGPoint(x: center + 8, y: 9),
                                  control1: CGPoint(x: center - 7, y: -3),
                                  control2: CGPoint(x: center + 8, y: -3))
                    path.addCurve(to: CGPoint(x: center, y: 27),
                                  control1: CGPoint(x: center + 9, y: 20),
                                  control2: CGPoint(x: center, y: 20))
                    path.addLine(to: CGPoint(x: center, y: 39))
                }
                .stroke(metal, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

                if support == .shoulder {
                    Path { path in
                        path.move(to: CGPoint(x: width / 2, y: 34))
                        path.addCurve(to: CGPoint(x: 4, y: 62),
                                      control1: CGPoint(x: width * 0.35, y: 37),
                                      control2: CGPoint(x: width * 0.1, y: 51))
                        path.addQuadCurve(to: CGPoint(x: 7, y: 69), control: CGPoint(x: 0, y: 68))
                        path.addQuadCurve(to: CGPoint(x: width / 2, y: 45),
                                          control: CGPoint(x: width * 0.3, y: 53))
                        path.addQuadCurve(to: CGPoint(x: width - 7, y: 69),
                                          control: CGPoint(x: width * 0.7, y: 53))
                        path.addQuadCurve(to: CGPoint(x: width - 4, y: 62), control: CGPoint(x: width, y: 68))
                        path.addCurve(to: CGPoint(x: width / 2, y: 34),
                                      control1: CGPoint(x: width * 0.9, y: 51),
                                      control2: CGPoint(x: width * 0.65, y: 37))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [Color(red: 0.48, green: 0.39, blue: 0.29),
                                                   Color(red: 0.25, green: 0.20, blue: 0.15)],
                                         startPoint: .top, endPoint: .bottom))
                } else {
                    Capsule().fill(metal).frame(height: 3).offset(y: 41)
                    HStack {
                        RoundedRectangle(cornerRadius: 2).fill(metal).frame(width: 9, height: 18)
                        Spacer()
                        RoundedRectangle(cornerRadius: 2).fill(metal).frame(width: 9, height: 18)
                    }
                    .padding(.horizontal, 9).offset(y: 43)
                }
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.14), radius: 2, y: 2)
        }
        .accessibilityHidden(true)
    }
}

struct ClosetRackRail: View {
    var body: some View {
        Capsule()
            .fill(LinearGradient(colors: [PyxisColors.secondaryText.opacity(0.5),
                                         PyxisColors.text.opacity(0.65),
                                         PyxisColors.secondaryText.opacity(0.4)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(height: 4)
            .shadow(color: .black.opacity(0.16), radius: 3, y: 4)
            .padding(.top, GarmentRackGeometry.hookY + 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
            do { try await Task.sleep(for: .milliseconds(1_300)) } catch { return }
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
