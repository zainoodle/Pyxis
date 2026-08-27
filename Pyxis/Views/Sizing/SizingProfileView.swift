import SwiftData
import SwiftUI

struct SizingProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BodyProfile.dateUpdated, order: .reverse) private var profiles: [BodyProfile]

    @State private var system: MeasurementSystem = .imperial
    @State private var fit: FitPreference = .regular
    @State private var values: [MeasurementKey: String] = [:]
    @State private var category: SizeChartCategory = .top
    @State private var chartRows = ["S", "M", "L"].map { ChartRowDraft(label: $0) }
    @State private var recommendation: SizeRecommendation?
    @State private var message: String?
    @State private var isConfirmingDelete = false
    let showsCloseButton: Bool

    init(showsCloseButton: Bool = true) {
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PyxisSpacing.xl) {
                    intro
                    profileFields
                    sizeChecker
                    privacy
                }
                .padding(PyxisSpacing.md)
            }
            .background(PyxisColors.background)
            .navigationTitle("MY SIZE")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if showsCloseButton {
                        Button("CLOSE") { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("SAVE") { saveProfile() }
                }
            }
            .onAppear(perform: loadProfile)
            .onChange(of: system) { oldSystem, newSystem in
                convertDisplayedValues(from: oldSystem, to: newSystem)
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
            Text("FIT PASSPORT")
                .font(PyxisTypography.title)
            Text("SAVE ONLY WHAT YOU KNOW. PYXIS COMPARES YOUR MEASUREMENTS WITH A RETAILER'S OWN SIZE CHART—IT DOES NOT ASSIGN ONE UNIVERSAL SIZE.")
                .font(PyxisTypography.label)
                .foregroundStyle(PyxisColors.secondaryText)
        }
    }

    private var profileFields: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.md) {
            Picker("UNITS", selection: $system) {
                Text("IN / LB").tag(MeasurementSystem.imperial)
                Text("CM / KG").tag(MeasurementSystem.metric)
            }
            .pickerStyle(.segmented)

            Picker("PREFERRED FIT", selection: $fit) {
                ForEach(FitPreference.allCases) { preference in
                    Text(preference.rawValue.uppercased()).tag(preference)
                }
            }

            Text("MEASUREMENTS USED FOR SIZE MATCHING")
                .font(PyxisTypography.label)
                .foregroundStyle(PyxisColors.secondaryText)
            ForEach([MeasurementKey.chest, .waist, .hip, .inseam, .foot]) { key in
                MeasurementInput(key: key, system: system, value: binding(for: key))
            }

            DisclosureGroup("OPTIONAL PROFILE CONTEXT") {
                VStack(spacing: PyxisSpacing.md) {
                    ForEach([MeasurementKey.height, .weight, .shoulder]) { key in
                        MeasurementInput(key: key, system: system, value: binding(for: key))
                    }
                }
                .padding(.top, PyxisSpacing.md)
            }

            Text("Measure close to the body over light clothing. Keep the tape level and comfortably snug.")
                .font(PyxisTypography.label)
                .foregroundStyle(PyxisColors.inactiveText)

            if let message {
                Text(message.uppercased())
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.secondaryText)
            }
        }
        .padding(PyxisSpacing.md)
        .background(PyxisColors.field)
    }

    private var sizeChecker: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.md) {
            Text("RETAILER SIZE CHECK")
                .font(PyxisTypography.title)
            Text("COPY THE MEASUREMENT RANGES FROM THE PRODUCT'S SIZE CHART. LEAVE COLUMNS BLANK WHEN THE RETAILER DOES NOT PROVIDE THEM.")
                .font(PyxisTypography.label)
                .foregroundStyle(PyxisColors.secondaryText)

            Picker("CATEGORY", selection: $category) {
                ForEach(SizeChartCategory.allCases) { value in
                    Text(value.rawValue.uppercased()).tag(value)
                }
            }
            .pickerStyle(.segmented)

            ForEach($chartRows) { $row in
                VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                    TextField("SIZE LABEL", text: $row.label)
                    if category == .footwear {
                        ChartRangeField(title: "FOOT LENGTH", value: $row.foot)
                    } else {
                        HStack {
                            if category != .bottom { ChartRangeField(title: "CHEST", value: $row.chest) }
                            ChartRangeField(title: "WAIST", value: $row.waist)
                        }
                        HStack {
                            if category != .top { ChartRangeField(title: "HIP", value: $row.hip) }
                            if category == .bottom { ChartRangeField(title: "INSEAM", value: $row.inseam) }
                        }
                    }
                    Button("REMOVE SIZE", role: .destructive) { removeChartRow(row.id) }
                        .font(PyxisTypography.label)
                }
                .padding(PyxisSpacing.sm)
                .overlay { Rectangle().stroke(PyxisColors.hairline) }
            }

            Button("ADD SIZE") { chartRows.append(ChartRowDraft(label: "")) }
                .buttonStyle(MinimalButtonStyle())

            Button("FIND MY SIZE") { findSize() }
                .buttonStyle(MinimalButtonStyle())

            if let recommendation {
                VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                    Text("LIKELY SIZE \(recommendation.sizeLabel.uppercased())")
                        .font(PyxisTypography.title)
                    Text("CONFIDENCE \(Int(recommendation.confidence * 100))%")
                        .font(PyxisTypography.label)
                    Text(recommendation.explanation.uppercased())
                        .font(PyxisTypography.label)
                        .foregroundStyle(PyxisColors.secondaryText)
                }
                .padding(PyxisSpacing.md)
                .background(PyxisColors.field)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var privacy: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
            Text("PRIVATE BY DEFAULT")
                .font(PyxisTypography.label)
            Text("Your Fit Passport stays in local app storage and is not included in AI image requests. Measurements are sizing guidance, not a medical assessment or fit guarantee.")
                .font(PyxisTypography.label)
                .foregroundStyle(PyxisColors.secondaryText)
            if !profiles.isEmpty {
                Button("DELETE FIT PASSPORT", role: .destructive) {
                    isConfirmingDelete = true
                }
            }
        }
        .confirmationDialog("Delete your Fit Passport?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("DELETE FIT PASSPORT", role: .destructive, action: deleteProfile)
            Button("CANCEL", role: .cancel) {}
        } message: {
            Text("This permanently removes your saved body measurements from this device.")
        }
    }

    private func binding(for key: MeasurementKey) -> Binding<String> {
        Binding(get: { values[key, default: ""] }, set: { values[key] = $0 })
    }

    private func loadProfile() {
        guard let profile = profiles.first else { return }
        system = profile.measurementSystem
        fit = profile.fitPreference
        values[.height] = display(profile.heightCentimeters, key: .height)
        values[.weight] = display(profile.weightKilograms, key: .weight)
        values[.chest] = display(profile.chestCentimeters, key: .chest)
        values[.waist] = display(profile.waistCentimeters, key: .waist)
        values[.hip] = display(profile.hipCentimeters, key: .hip)
        values[.inseam] = display(profile.inseamCentimeters, key: .inseam)
        values[.shoulder] = display(profile.shoulderCentimeters, key: .shoulder)
        values[.foot] = display(profile.footLengthCentimeters, key: .foot)
    }

    @discardableResult
    private func saveProfile() -> Bool {
        let profile = profiles.first ?? BodyProfile()
        if profiles.isEmpty { modelContext.insert(profile) }
        profile.measurementSystem = system
        profile.fitPreference = fit
        profile.heightCentimeters = canonical(.height)
        profile.weightKilograms = canonical(.weight)
        profile.chestCentimeters = canonical(.chest)
        profile.waistCentimeters = canonical(.waist)
        profile.hipCentimeters = canonical(.hip)
        profile.inseamCentimeters = canonical(.inseam)
        profile.shoulderCentimeters = canonical(.shoulder)
        profile.footLengthCentimeters = canonical(.foot)
        profile.dateUpdated = .now
        do {
            try modelContext.save()
            message = "Fit Passport saved"
            return true
        } catch {
            modelContext.rollback()
            message = PersistenceErrorMessage.saveFailed(error)
            return false
        }
    }

    private func findSize() {
        guard saveProfile() else { return }
        guard let profile = profiles.first ?? (try? modelContext.fetch(FetchDescriptor<BodyProfile>()).first) else { return }
        let options = chartRows.compactMap { $0.option(system: system) }
        recommendation = SizeRecommendationService().recommend(profile: profile, category: category, options: options)
        if recommendation == nil { message = "Add relevant measurements and chart ranges" }
    }

    private func removeChartRow(_ id: UUID) {
        guard chartRows.count > 1 else {
            chartRows[0] = ChartRowDraft(label: "")
            return
        }
        chartRows.removeAll { $0.id == id }
    }

    private func deleteProfile() {
        profiles.forEach(modelContext.delete)
        do {
            try modelContext.save()
            values = [:]
            recommendation = nil
            message = "Fit Passport deleted"
        } catch {
            modelContext.rollback()
            message = PersistenceErrorMessage.saveFailed(error)
        }
    }

    private func canonical(_ key: MeasurementKey) -> Double? {
        guard let number = Double(values[key, default: ""].replacingOccurrences(of: ",", with: ".")), number > 0 else { return nil }
        if system == .metric { return number }
        return key == .weight ? number * 0.45359237 : number * 2.54
    }

    private func display(_ value: Double?, key: MeasurementKey) -> String {
        guard let value else { return "" }
        let converted = system == .metric ? value : (key == .weight ? value / 0.45359237 : value / 2.54)
        return converted.formatted(.number.precision(.fractionLength(0...1)))
    }

    private func convertDisplayedValues(from oldSystem: MeasurementSystem, to newSystem: MeasurementSystem) {
        guard oldSystem != newSystem else { return }
        for key in MeasurementKey.allCases {
            guard let number = Double(values[key, default: ""].replacingOccurrences(of: ",", with: ".")) else { continue }
            let converted: Double
            if key == .weight {
                converted = newSystem == .metric ? number * 0.45359237 : number / 0.45359237
            } else {
                converted = newSystem == .metric ? number * 2.54 : number / 2.54
            }
            values[key] = converted.formatted(.number.precision(.fractionLength(0...1)))
        }
        for index in chartRows.indices {
            chartRows[index].convertRanges(from: oldSystem, to: newSystem)
        }
    }
}

private enum MeasurementKey: String, Identifiable, CaseIterable {
    case height, weight, chest, waist, hip, inseam, shoulder, foot
    var id: String { rawValue }
    var title: String { self == .foot ? "FOOT LENGTH" : rawValue.uppercased() }
    var accessibilityLabel: String { self == .foot ? "Foot length" : rawValue.capitalized }
}

private struct MeasurementInput: View {
    let key: MeasurementKey
    let system: MeasurementSystem
    @Binding var value: String
    var body: some View {
        HStack {
            Text(key.title).font(PyxisTypography.label)
            Spacer()
            TextField("OPTIONAL", text: $value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 110)
                .accessibilityLabel(key.accessibilityLabel)
            Text(key == .weight ? (system == .metric ? "KG" : "LB") : (system == .metric ? "CM" : "IN"))
                .font(PyxisTypography.label)
                .foregroundStyle(PyxisColors.inactiveText)
        }
    }
}

private struct ChartRowDraft: Identifiable {
    let id = UUID()
    var label: String
    var chest = ""
    var waist = ""
    var hip = ""
    var inseam = ""
    var foot = ""

    func option(system: MeasurementSystem) -> RetailerSizeOption? {
        guard !label.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return RetailerSizeOption(
            label: label,
            chestCentimeters: range(chest, system: system),
            waistCentimeters: range(waist, system: system),
            hipCentimeters: range(hip, system: system),
            inseamCentimeters: range(inseam, system: system),
            footLengthCentimeters: range(foot, system: system)
        )
    }

    private func range(_ text: String, system: MeasurementSystem) -> ClosedRange<Double>? {
        let numbers = text.replacingOccurrences(of: "–", with: "-").split(separator: "-").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard numbers.count == 2, numbers[0] <= numbers[1] else { return nil }
        let factor = system == .metric ? 1.0 : 2.54
        return (numbers[0] * factor)...(numbers[1] * factor)
    }

    mutating func convertRanges(from oldSystem: MeasurementSystem, to newSystem: MeasurementSystem) {
        guard oldSystem != newSystem else { return }
        chest = convertedRange(chest, to: newSystem)
        waist = convertedRange(waist, to: newSystem)
        hip = convertedRange(hip, to: newSystem)
        inseam = convertedRange(inseam, to: newSystem)
        foot = convertedRange(foot, to: newSystem)
    }

    private func convertedRange(_ text: String, to newSystem: MeasurementSystem) -> String {
        let numbers = text.replacingOccurrences(of: "–", with: "-").split(separator: "-").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard numbers.count == 2 else { return text }
        let factor = newSystem == .metric ? 2.54 : 1 / 2.54
        return numbers.map { ($0 * factor).formatted(.number.precision(.fractionLength(0...1))) }.joined(separator: "-")
    }
}

private struct ChartRangeField: View {
    let title: String
    @Binding var value: String
    var body: some View {
        TextField("\(title) MIN-MAX", text: $value)
            .keyboardType(.numbersAndPunctuation)
            .font(PyxisTypography.label)
            .padding(PyxisSpacing.sm)
            .background(PyxisColors.field)
    }
}
