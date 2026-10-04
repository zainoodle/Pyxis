import Foundation

enum MeasurementKey: String, Identifiable, CaseIterable {
    case height, weight, chest, waist, hip, inseam, shoulder, foot
    var id: String { rawValue }
    var title: String { accessibilityLabel }
    var accessibilityLabel: String { self == .foot ? "Foot length" : rawValue.capitalized }
}

struct BodyMeasurementDraft {
    private(set) var system: MeasurementSystem
    var values: [MeasurementKey: String]

    init(system: MeasurementSystem = .imperial, values: [MeasurementKey: String] = [:]) {
        self.system = system
        self.values = values
    }

    init(profile: BodyProfile) {
        system = profile.measurementSystem
        values = [:]
        let saved: [MeasurementKey: Double?] = [
            .height: profile.heightCentimeters, .weight: profile.weightKilograms,
            .chest: profile.chestCentimeters, .waist: profile.waistCentimeters,
            .hip: profile.hipCentimeters, .inseam: profile.inseamCentimeters,
            .shoulder: profile.shoulderCentimeters, .foot: profile.footLengthCentimeters
        ]
        for (key, value) in saved {
            guard let value else { continue }
            let displayed = system == .metric ? value : value / factor(for: key)
            values[key] = displayed.formatted(.number.precision(.fractionLength(0...1)))
        }
    }

    mutating func changeUnits(to newSystem: MeasurementSystem) {
        guard system != newSystem else { return }
        for key in MeasurementKey.allCases {
            guard let number = number(for: key) else { continue }
            let converted = newSystem == .metric ? number * factor(for: key) : number / factor(for: key)
            values[key] = converted.formatted(.number.precision(.fractionLength(0...1)))
        }
        system = newSystem
    }

    /// Empty optional fields are valid. Nonempty invalid input must not erase saved values.
    var invalidKeys: [MeasurementKey] {
        MeasurementKey.allCases.filter { key in
            !values[key, default: ""].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && canonical(key) == nil
        }
    }

    func canonical(_ key: MeasurementKey) -> Double? {
        guard let number = number(for: key), number.isFinite, number > 0 else { return nil }
        return system == .metric ? number : number * factor(for: key)
    }

    private func number(for key: MeasurementKey) -> Double? {
        Double(values[key, default: ""].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."))
    }

    private func factor(for key: MeasurementKey) -> Double { key == .weight ? 0.45359237 : 2.54 }
}
