import Foundation

public enum SizeChartCategory: String, CaseIterable, Identifiable, Sendable {
    case top
    case bottom
    case onePiece
    case footwear
    public var id: String { rawValue }
}

public struct RetailerSizeOption: Equatable, Sendable {
    public let label: String
    public let chestCentimeters: ClosedRange<Double>?
    public let waistCentimeters: ClosedRange<Double>?
    public let hipCentimeters: ClosedRange<Double>?
    public let inseamCentimeters: ClosedRange<Double>?
    public let footLengthCentimeters: ClosedRange<Double>?

    public init(
        label: String,
        chestCentimeters: ClosedRange<Double>? = nil,
        waistCentimeters: ClosedRange<Double>? = nil,
        hipCentimeters: ClosedRange<Double>? = nil,
        inseamCentimeters: ClosedRange<Double>? = nil,
        footLengthCentimeters: ClosedRange<Double>? = nil
    ) {
        self.label = label
        self.chestCentimeters = chestCentimeters
        self.waistCentimeters = waistCentimeters
        self.hipCentimeters = hipCentimeters
        self.inseamCentimeters = inseamCentimeters
        self.footLengthCentimeters = footLengthCentimeters
    }
}

public struct SizeRecommendation: Equatable, Sendable {
    public let sizeLabel: String
    public let confidence: Double
    public let explanation: String
}

public struct SizeRecommendationService {
    public init() {}

    public func recommend(
        profile: BodyProfile,
        category: SizeChartCategory,
        options: [RetailerSizeOption]
    ) -> SizeRecommendation? {
        let measurements = relevantMeasurements(profile: profile, category: category)
        guard !measurements.isEmpty else { return nil }

        let scored = options.compactMap { option -> (RetailerSizeOption, Double, Int)? in
            let ranges = relevantRanges(option: option, category: category)
            let comparable = measurements.compactMap { key, value -> Double? in
                guard let range = ranges[key] else { return nil }
                guard range.contains(value) else { return nil }
                return rangeScore(value: value, range: range, preference: profile.fitPreference)
            }
            let expectedComparisons = measurements.keys.filter { ranges[$0] != nil }.count
            guard expectedComparisons > 0, comparable.count == expectedComparisons else { return nil }
            return (option, comparable.reduce(0, +) / Double(comparable.count), comparable.count)
        }
        guard let best = scored.max(by: { $0.1 < $1.1 }) else { return nil }
        let confidence = min(0.95, 0.45 + Double(best.2) * 0.15 + max(0, best.1) * 0.2)
        let names = relevantMeasurements(profile: profile, category: category).keys.sorted().joined(separator: ", ")
        return SizeRecommendation(
            sizeLabel: best.0.label,
            confidence: confidence,
            explanation: "Based on your \(names) measurements and \(profile.fitPreference.rawValue) fit preference. Check product reviews and fabric stretch before ordering."
        )
    }

    private func relevantMeasurements(profile: BodyProfile, category: SizeChartCategory) -> [String: Double] {
        var values: [String: Double] = [:]
        if [.top, .onePiece].contains(category), let chest = profile.chestCentimeters { values["chest"] = chest }
        if category != .footwear, let waist = profile.waistCentimeters { values["waist"] = waist }
        if [.bottom, .onePiece].contains(category), let hip = profile.hipCentimeters { values["hip"] = hip }
        if category == .bottom, let inseam = profile.inseamCentimeters { values["inseam"] = inseam }
        if category == .footwear, let foot = profile.footLengthCentimeters { values["foot length"] = foot }
        return values
    }

    private func relevantRanges(option: RetailerSizeOption, category: SizeChartCategory) -> [String: ClosedRange<Double>] {
        var ranges: [String: ClosedRange<Double>] = [:]
        if [.top, .onePiece].contains(category), let chest = option.chestCentimeters { ranges["chest"] = chest }
        if category != .footwear, let waist = option.waistCentimeters { ranges["waist"] = waist }
        if [.bottom, .onePiece].contains(category), let hip = option.hipCentimeters { ranges["hip"] = hip }
        if category == .bottom, let inseam = option.inseamCentimeters { ranges["inseam"] = inseam }
        if category == .footwear, let foot = option.footLengthCentimeters { ranges["foot length"] = foot }
        return ranges
    }

    private func rangeScore(value: Double, range: ClosedRange<Double>, preference: FitPreference) -> Double {
        let target: Double
        switch preference {
        case .close: target = range.lowerBound + (range.upperBound - range.lowerBound) * 0.25
        case .regular: target = (range.lowerBound + range.upperBound) / 2
        case .relaxed: target = range.lowerBound + (range.upperBound - range.lowerBound) * 0.75
        }
        let distance = abs(value - target)
        return range.contains(value) ? 1 - distance / max(range.upperBound - range.lowerBound, 1) : -distance / 10
    }
}
