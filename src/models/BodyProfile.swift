import Foundation
import SwiftData

public enum MeasurementSystem: String, CaseIterable, Codable, Identifiable, Sendable {
    case imperial
    case metric
    public var id: String { rawValue }
}

public enum FitPreference: String, CaseIterable, Codable, Identifiable, Sendable {
    case close
    case regular
    case relaxed
    public var id: String { rawValue }
}

@Model
public final class BodyProfile: Identifiable {
    @Attribute(.unique) public var id: UUID
    public var measurementSystemRawValue: String
    public var fitPreferenceRawValue: String
    public var heightCentimeters: Double?
    public var weightKilograms: Double?
    public var chestCentimeters: Double?
    public var waistCentimeters: Double?
    public var hipCentimeters: Double?
    public var inseamCentimeters: Double?
    public var shoulderCentimeters: Double?
    public var footLengthCentimeters: Double?
    public var dateUpdated: Date

    public init(
        id: UUID = UUID(),
        measurementSystem: MeasurementSystem = .imperial,
        fitPreference: FitPreference = .regular,
        heightCentimeters: Double? = nil,
        weightKilograms: Double? = nil,
        chestCentimeters: Double? = nil,
        waistCentimeters: Double? = nil,
        hipCentimeters: Double? = nil,
        inseamCentimeters: Double? = nil,
        shoulderCentimeters: Double? = nil,
        footLengthCentimeters: Double? = nil,
        dateUpdated: Date = .now
    ) {
        self.id = id
        self.measurementSystemRawValue = measurementSystem.rawValue
        self.fitPreferenceRawValue = fitPreference.rawValue
        self.heightCentimeters = heightCentimeters
        self.weightKilograms = weightKilograms
        self.chestCentimeters = chestCentimeters
        self.waistCentimeters = waistCentimeters
        self.hipCentimeters = hipCentimeters
        self.inseamCentimeters = inseamCentimeters
        self.shoulderCentimeters = shoulderCentimeters
        self.footLengthCentimeters = footLengthCentimeters
        self.dateUpdated = dateUpdated
    }

    public var measurementSystem: MeasurementSystem {
        get { MeasurementSystem(rawValue: measurementSystemRawValue) ?? .imperial }
        set { measurementSystemRawValue = newValue.rawValue }
    }

    public var fitPreference: FitPreference {
        get { FitPreference(rawValue: fitPreferenceRawValue) ?? .regular }
        set { fitPreferenceRawValue = newValue.rawValue }
    }
}
