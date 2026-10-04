import SwiftData
import SwiftUI
import UIKit

struct SizingProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \BodyProfile.dateUpdated, order: .reverse) private var profiles: [BodyProfile]

    @State private var draft = BodyMeasurementDraft()
    @State private var fit: FitPreference = .regular
    @State private var category: SizeChartCategory = .top
    @State private var chartRows = [ChartRowDraft(label: "")]
    @State private var recommendation: SizeRecommendation?
    @State private var message: String?
    @State private var comparisonMessage: String?
    @State private var isComparing = false
    @State private var isConfirmingDelete = false

    private var system: MeasurementSystem { draft.system }

    private var unitSelection: Binding<MeasurementSystem> {
        Binding(get: { draft.system }, set: { newSystem in
            let oldSystem = draft.system
            draft.changeUnits(to: newSystem)
            for index in chartRows.indices { chartRows[index].convertRanges(from: oldSystem, to: newSystem) }
            clearComparison()
        })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PyxisSpacing.xl) {
                profileFields
                Button {
                    dismissKeyboard()
                    if saveProfile() { isComparing = true }
                } label: {
                    HStack {
                        Text("Compare a size chart")
                        Spacer()
                        Image(systemName: "chevron.right").accessibilityHidden(true)
                    }
                    .font(PyxisTypography.control)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("measurements.compare")
                privacy
            }
            .padding(24)
        }
        .editorialCanvas()
        .disclosureGroupStyle(EditorialDisclosureGroupStyle())
        .editorialNavigationTitle("Measurements")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { dismissKeyboard(); saveProfile() }
            }
            ToolbarItem(placement: .keyboard) {
                Button("Done", action: dismissKeyboard)
            }
        }
        .navigationDestination(isPresented: $isComparing) {
            ScrollView { sizeChecker.padding(24) }
                .editorialCanvas()
                .editorialNavigationTitle("Size chart")
                .toolbar {
                    ToolbarItem(placement: .keyboard) { Button("Done", action: dismissKeyboard) }
                }
        }
        .onAppear(perform: loadProfile)
    }

    private var profileFields: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
            Text("All fields optional")
                .font(PyxisTypography.proseCaption)
                .foregroundStyle(PyxisColors.secondaryText)
            Picker("Units", selection: unitSelection) {
                Text("IN / LB").tag(MeasurementSystem.imperial)
                Text("CM / KG").tag(MeasurementSystem.metric)
            }
            .pickerStyle(.segmented)

            EditorialMenuPicker(title: "Fit preference", value: fit.rawValue.capitalized, selection: $fit) {
                ForEach(FitPreference.allCases) { preference in
                    Text(preference.rawValue.capitalized).tag(preference)
                }
            }
            .frame(minHeight: 44)

            ForEach([MeasurementKey.chest, .waist, .hip, .inseam, .foot]) { key in
                MeasurementInput(key: key, system: system, value: binding(for: key))
            }

            DisclosureGroup("More measurements") {
                VStack(spacing: PyxisSpacing.md) {
                    ForEach([MeasurementKey.height, .weight, .shoulder]) { key in
                        MeasurementInput(key: key, system: system, value: binding(for: key))
                    }
                }
                .padding(.top, PyxisSpacing.md)
            }

            DisclosureGroup("How to measure") {
                Text("Measure over light clothing. Keep the tape level and comfortably snug.")
                    .font(PyxisTypography.prose)
                    .foregroundStyle(PyxisColors.secondaryText)
                    .padding(.top, PyxisSpacing.sm)
            }
            .frame(minHeight: 44)

            if let message {
                Text(message)
                    .font(PyxisTypography.proseCaption)
                    .foregroundStyle(PyxisColors.secondaryText)
            }
        }
        .padding(PyxisSpacing.md)
        .background(PyxisColors.field, in: RoundedRectangle(cornerRadius: 8))
    }

    private var sizeChecker: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.md) {
            Text("Use the retailer’s ranges in \(system == .metric ? "centimeters" : "inches").")
                .font(PyxisTypography.proseCaption)
                .foregroundStyle(PyxisColors.secondaryText)

            EditorialMenuPicker(title: "Category", value: category == .onePiece ? "One piece" : category.rawValue.capitalized, selection: $category) {
                ForEach(SizeChartCategory.allCases) { value in
                    Text(value == .onePiece ? "One piece" : value.rawValue.capitalized).tag(value)
                }
            }
            .frame(minHeight: 44)
            .onChange(of: category) { _, _ in clearComparison() }

            ForEach($chartRows) { $row in
                VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                    HStack {
                        EditorialTextField("Size label", placeholder: "Size, e.g. M", text: $row.label)
                            .font(PyxisTypography.control)
                            .accessibilityLabel("Size label")
                            .frame(minHeight: 44)
                        Button(role: .destructive) { removeChartRow(row.id); clearComparison() } label: {
                            Image(systemName: "trash").frame(width: 44, height: 44).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(row.label.isEmpty ? "Remove size" : "Remove size \(row.label)")
                    }
                    if category == .footwear {
                        ChartRangeField(title: "Foot length", value: $row.foot)
                    } else {
                        rangeLayout {
                            if category != .bottom { ChartRangeField(title: "Chest", value: $row.chest) }
                            ChartRangeField(title: "Waist", value: $row.waist)
                        }
                        rangeLayout {
                            if category != .top { ChartRangeField(title: "Hip", value: $row.hip) }
                            if category == .bottom { ChartRangeField(title: "Inseam", value: $row.inseam) }
                        }
                    }
                }
                .padding(PyxisSpacing.sm)
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(PyxisColors.hairline) }
            }

            Button("Add size", systemImage: "plus") { chartRows.append(ChartRowDraft(label: "")); clearComparison() }
                .buttonStyle(MinimalButtonStyle())

            Button("Compare sizes") { dismissKeyboard(); findSize() }
                .buttonStyle(EditorialPrimaryButtonStyle())
                .accessibilityIdentifier("measurements.compareSizes")

            if let recommendation {
                VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                    Text("Size \(recommendation.sizeLabel)")
                        .font(PyxisTypography.garmentTitle)
                    Text(recommendation.explanation)
                        .font(PyxisTypography.prose)
                        .foregroundStyle(PyxisColors.secondaryText)
                    Text("Sizing varies by brand and fabric.")
                        .font(PyxisTypography.proseCaption)
                        .foregroundStyle(PyxisColors.secondaryText)
                }
                .padding(PyxisSpacing.md)
                .background(PyxisColors.field, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityElement(children: .combine)
            }
            if let comparisonMessage {
                Text(comparisonMessage).font(PyxisTypography.prose)
                    .foregroundStyle(PyxisColors.secondaryText)
            }
        }
        .onChange(of: chartRows) { _, _ in clearComparison() }
    }

    private var rangeLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: PyxisSpacing.sm))
            : AnyLayout(HStackLayout(spacing: PyxisSpacing.sm))
    }

    private func clearComparison() { recommendation = nil; comparisonMessage = nil }

    private var privacy: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
            Text("Saved on this device. Not sent with AI photos.")
                .font(PyxisTypography.proseCaption)
                .foregroundStyle(PyxisColors.secondaryText)
            if !profiles.isEmpty {
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Text("Delete measurements").font(PyxisTypography.control).frame(minHeight: 44)
                }
            }
        }
        .confirmationDialog("Delete your measurements?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete measurements", role: .destructive, action: deleteProfile)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your saved body measurements from this device.")
        }
    }

    private func binding(for key: MeasurementKey) -> Binding<String> {
        Binding(get: { draft.values[key, default: ""] }, set: { draft.values[key] = $0 })
    }

    private func loadProfile() {
        guard let profile = profiles.first else { return }
        draft = BodyMeasurementDraft(profile: profile)
        fit = profile.fitPreference
    }

    @discardableResult
    private func saveProfile() -> Bool {
        let profile = profiles.first ?? BodyProfile()
        if profiles.isEmpty { modelContext.insert(profile) }
        profile.measurementSystem = system
        profile.fitPreference = fit
        profile.heightCentimeters = draft.canonical(.height)
        profile.weightKilograms = draft.canonical(.weight)
        profile.chestCentimeters = draft.canonical(.chest)
        profile.waistCentimeters = draft.canonical(.waist)
        profile.hipCentimeters = draft.canonical(.hip)
        profile.inseamCentimeters = draft.canonical(.inseam)
        profile.shoulderCentimeters = draft.canonical(.shoulder)
        profile.footLengthCentimeters = draft.canonical(.foot)
        profile.dateUpdated = .now
        do {
            try modelContext.save()
            message = "Measurements saved"
            return true
        } catch {
            modelContext.rollback()
            message = PersistenceErrorMessage.saveFailed(error)
            return false
        }
    }

    private func findSize() {
        guard saveProfile() else { comparisonMessage = message; return }
        guard let profile = profiles.first ?? (try? modelContext.fetch(FetchDescriptor<BodyProfile>()).first) else { return }
        let options = chartRows.compactMap { $0.option(system: system) }
        recommendation = SizeRecommendationService().recommend(profile: profile, category: category, options: options)
        comparisonMessage = recommendation == nil ? "No matching size. Check your measurements and chart ranges." : nil
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
            draft.values = [:]
            recommendation = nil
            message = "Measurements deleted"
        } catch {
            modelContext.rollback()
            message = PersistenceErrorMessage.saveFailed(error)
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private struct MeasurementInput: View {
    let key: MeasurementKey
    let system: MeasurementSystem
    @Binding var value: String
    var body: some View {
        HStack {
            Text(key.title).font(PyxisTypography.label)
            Spacer()
            EditorialTextField(key.accessibilityLabel, placeholder: "—", text: $value,
                               keyboardType: .decimalPad, alignment: .trailing)
                .frame(minWidth: 60, maxWidth: 110)
            Text(key == .weight ? (system == .metric ? "KG" : "LB") : (system == .metric ? "CM" : "IN"))
                .font(PyxisTypography.label)
                .foregroundStyle(PyxisColors.secondaryText)
        }
        .font(PyxisTypography.control)
        .frame(minHeight: 44)
    }
}

private struct ChartRowDraft: Identifiable, Equatable {
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
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(PyxisTypography.label).foregroundStyle(PyxisColors.secondaryText)
            EditorialTextField("\(title) range", placeholder: "Min–max", text: $value, keyboardType: .numbersAndPunctuation)
                .font(PyxisTypography.control)
                .frame(minHeight: 44)
                .accessibilityLabel("\(title) range")
        }
        .padding(PyxisSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PyxisColors.field, in: RoundedRectangle(cornerRadius: 8))
    }
}
