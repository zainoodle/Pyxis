import Foundation

/// A small, interruptible pendulum response. Nothing runs while the rack is at rest.
struct ClosetRackSway {
    static let maximumAngle = Double.pi / 40
    private static let decay = 6.5
    private static let frequency = sqrt(169 - decay * decay)

    private(set) var startedAt = 0.0
    private var angle = 0.0
    private var velocity = 0.0

    func sample(at time: Double) -> (angle: Double, velocity: Double) {
        let elapsed = max(0, time - startedAt)
        let decay = Self.decay
        let frequency = Self.frequency
        let envelope = exp(-decay * elapsed)
        let sine = sin(frequency * elapsed)
        let cosine = cos(frequency * elapsed)
        let b = (velocity + decay * angle) / frequency
        let displacement = angle * cosine + b * sine
        let value = envelope * displacement
        return (
            min(Self.maximumAngle, max(-Self.maximumAngle, value)),
            envelope * (-decay * displacement - angle * frequency * sine + b * frequency * cosine)
        )
    }

    mutating func nudge(velocityChange: Double, at time: Double) {
        guard velocityChange.isFinite, time.isFinite else { return }
        let current = sample(at: time)
        angle = current.angle
        let impulse = min(1_400, max(-1_400, velocityChange)) * 0.001
        velocity = min(1.15, max(-1.15, current.velocity + impulse))
        startedAt = time
    }

    mutating func reset() { self = Self() }
}
