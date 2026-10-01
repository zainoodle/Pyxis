import PhotosUI
import SwiftData
import SwiftUI

struct AITryOnView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ClosetItem.dateAdded, order: .reverse) private var closet: [ClosetItem]
    @StateObject private var model: TryOnViewModel
    @StateObject private var purchase = TryOnPurchaseService()
    @State private var personSelection: PhotosPickerItem?
    @State private var garmentSelection: PhotosPickerItem?
    @State private var sheet: TryOnSheet?
    @State private var confirmsAnother = false
    @State private var didCheckAvailability = false

    init(items: [ClosetItem] = []) {
        let garments = items.compactMap { item -> TryOnGarment? in
            guard let storage = ImageStorageService.shared else { return nil }
            return TryOnGarment(id: item.id, imageURL: storage.url(for: item.imageCutoutPath ?? item.imageOriginalPath),
                category: item.category, name: item.displayName ?? item.subtype.rawValue)
        }
        _model = StateObject(wrappedValue: TryOnViewModel(garments: garments))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PyxisSpacing.lg) {
                    if !didCheckAvailability {
                        ProgressView("Checking availability…").font(PyxisTypography.prose)
                            .frame(maxWidth: .infinity, minHeight: 180)
                    } else if model.available {
                        accessSection
                        referenceSection
                        clothingSection
                        Text(TryOnPrivacy.fitDisclaimer)
                            .font(PyxisTypography.proseCaption).foregroundStyle(PyxisColors.secondaryText)
                    } else {
                        ContentUnavailableView("Try-on unavailable", systemImage: "person.crop.rectangle")
                    }
                    if let error = model.errorMessage { InlineErrorMessage(message: error) }
                    if !model.previews.isEmpty {
                        Button("Saved previews · \(model.previews.count)") { sheet = .saved }
                            .buttonStyle(MinimalButtonStyle()).disabled(model.isGenerating)
                    }
                }
                .padding(PyxisSpacing.md)
            }
            .background(PyxisColors.background)
            .editorialNavigationTitle("Try on")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { sheet = .privacy } label: { Image(systemName: "hand.raised").frame(width: 44, height: 44).contentShape(Rectangle()) }
                        .accessibilityLabel("Try-on privacy").disabled(model.isGenerating)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }.disabled(model.isGenerating || model.isImporting)
                }
            }
            .safeAreaInset(edge: .bottom) { if model.available { generationRail } }
            .interactiveDismissDisabled(model.isGenerating || model.isImporting)
            .task {
                await model.load()
                didCheckAvailability = true
                guard model.available else { return }
                do { try await purchase.refresh(productID: model.configuration?.productID) }
                catch { model.errorMessage = "Purchase options could not load. Try again shortly." }
                await model.refreshAllowance(authorization: purchase.authorization)
            }
            .task(id: purchase.authorization) { await model.refreshAllowance(authorization: purchase.authorization) }
            .task(id: personSelection) { await loadSelection(personSelection, forPerson: true) }
            .task(id: garmentSelection) { await loadSelection(garmentSelection, forPerson: false) }
            .onChange(of: model.garments) { _, _ in model.selectionChanged() }
            .sheet(item: $sheet) { destination in
                switch destination {
                case .consent, .privacy:
                    TryOnPrivacyView(disclosure: model.disclosure, hasConsent: model.hasConsent, requestsConsent: destination == .consent,
                        agree: {
                            model.acceptConsent(); sheet = nil
                            Task { await model.generate(authorization: purchase.authorization) }
                        }, revoke: model.revokeConsent)
                case .closet:
                    TryOnClosetPicker(items: closet, selectedIDs: Set(model.garments.map(\.id))) { item in
                        guard model.garments.count < 6, let storage = ImageStorageService.shared else { return }
                        model.garments.append(TryOnGarment(id: item.id,
                            imageURL: storage.url(for: item.imageCutoutPath ?? item.imageOriginalPath),
                            category: item.category, name: item.displayName ?? item.subtype.rawValue))
                        sheet = nil
                    }
                case .saved:
                    TryOnSavedPreviewsView(model: model)
                }
            }
            .confirmationDialog("Generate another preview?", isPresented: $confirmsAnother, titleVisibility: .visible) {
                Button(model.isPrivatePC ? "Generate preview" : "Generate · 1 try-on") { startGeneration() }
                Button("Cancel", role: .cancel) {}
            } message: { Text(model.isPrivatePC ? "Save this preview first if you want to keep it." : "This uses one more try-on. Save this preview first if you want to keep it.") }
        }
        .tint(PyxisColors.text)
        .disclosureGroupStyle(EditorialDisclosureGroupStyle())
    }

    private var hasReference: Bool { model.personURL != nil }

    private var referenceSection: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.md) {
            Text("Your photo").font(PyxisTypography.editorialTitle)
            if let url = model.showsOriginal ? model.personURL : (model.generatedURL ?? model.personURL) {
                LocalImageView(url: url)
                    .frame(maxWidth: .infinity).frame(height: model.generatedURL == nil ? 340 : 420)
                    .background(PyxisColors.field)
                    .accessibilityLabel(model.generatedURL == nil || model.showsOriginal ? "Your reference photo" : "Generated outfit preview")
                if model.generatedURL != nil {
                    Picker("Compare", selection: $model.showsOriginal) {
                        Text("Preview").tag(false)
                        Text("Original").tag(true)
                    }.pickerStyle(.segmented)
                    Button(model.resultSaved ? "Saved" : "Save preview") { model.saveResult() }
                        .buttonStyle(MinimalButtonStyle()).disabled(model.resultSaved || model.isGenerating)
                }
            } else {
                Image(systemName: "figure.stand")
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundStyle(PyxisColors.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .background(PyxisColors.field)
                    .accessibilityHidden(true)
            }
            HStack {
                PhotosPicker(selection: $personSelection, matching: .images) {
                    Text(hasReference ? "Change photo" : "Choose photo")
                }.buttonStyle(MinimalButtonStyle())
                Spacer()
                if hasReference {
                    Button(role: .destructive) { model.removeReference(); personSelection = nil } label: {
                        Image(systemName: "trash").frame(width: 44, height: 44).contentShape(Rectangle())
                    }.accessibilityLabel("Remove reference photo")
                }
            }.disabled(model.isGenerating || model.isImporting)
            DisclosureGroup("Photo tips") {
                Text("Use a full-body photo. Face forward in even lighting, with your arms slightly away from your body.")
                    .font(PyxisTypography.prose).foregroundStyle(PyxisColors.secondaryText)
                    .padding(.top, PyxisSpacing.sm)
            }
            .font(PyxisTypography.control).frame(minHeight: 44)
            if model.personURL != nil {
                Toggle("Remember my photo on this device", isOn: Binding(get: { model.rememberPhoto }, set: model.setRememberPhoto))
                    .font(PyxisTypography.control).disabled(model.isGenerating || model.isImporting)
            }
        }
    }

    private var clothingSection: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.md) {
            HStack {
                Text("Pieces").font(PyxisTypography.editorialTitle)
                Spacer()
                Text("\(model.garments.count)/6").font(PyxisTypography.label).foregroundStyle(PyxisColors.secondaryText)
            }
            ForEach($model.garments) { $garment in
                HStack(spacing: PyxisSpacing.md) {
                    LocalImageView(url: garment.imageURL).frame(width: 64, height: 78).background(PyxisColors.field)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(garment.name).font(PyxisTypography.control).lineLimit(2)
                        Picker("Garment type", selection: $garment.category) {
                            ForEach(ClothingCategory.allCases) { category in
                                Text(category.tryOnTitle).tag(category)
                            }
                        }.pickerStyle(.menu).labelsHidden().accessibilityLabel("Garment type for \(garment.name)")
                    }
                    Spacer()
                    Button { model.garments.removeAll { $0.id == garment.id } } label: { Image(systemName: "xmark").frame(width: 44, height: 44).contentShape(Rectangle()) }.accessibilityLabel("Remove \(garment.name)")
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack { addClothingButtons }
                VStack(alignment: .leading) { addClothingButtons }
            }
            if model.isImporting { ProgressView("Preparing your photo…").font(PyxisTypography.label) }
        }.disabled(model.isGenerating || model.isImporting)
    }

    @ViewBuilder private var addClothingButtons: some View {
        Button("From closet") { sheet = .closet }.buttonStyle(MinimalButtonStyle())
            .disabled(model.garments.count >= 6)
        PhotosPicker(selection: $garmentSelection, matching: .images) { Text("Add photo") }
            .buttonStyle(MinimalButtonStyle()).disabled(model.garments.count >= 6)
    }

    @ViewBuilder private var accessSection: some View {
        if model.isLoading {
            ProgressView("Checking availability…").font(PyxisTypography.label)
        } else if model.isPrivatePC {
            VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                Text("Your PC").font(PyxisTypography.editorialTitle)
                Text("Keep your PC online during generation. No subscription required.")
                    .font(PyxisTypography.prose).foregroundStyle(PyxisColors.secondaryText)
                if let counts = model.configuration?.supportedGarmentCounts, !counts.contains(model.garments.count) {
                    Text("Choose \(counts.map(String.init).joined(separator: " or ")) piece\(counts == [1] ? "" : "s") for this preview.")
                        .font(PyxisTypography.proseCaption)
                }
                if purchase.authorization == nil {
                    Text("Connect your PC to enable try-on.").font(PyxisTypography.proseCaption)
                }
            }
        } else if let allowance = model.allowance {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(allowance.remaining) of \(allowance.limit) try-ons left").font(PyxisTypography.control)
                Text("Renews \(allowance.renewalDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(PyxisTypography.proseCaption).foregroundStyle(PyxisColors.secondaryText)
                Link("Manage subscription", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    .font(PyxisTypography.control).padding(.vertical, PyxisSpacing.sm)
            }
        } else if purchase.authorization == nil {
            VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                Text("Try-on subscription").font(PyxisTypography.editorialTitle)
                Text("\(model.configuration?.limit ?? 20) previews per month. Failed generations don’t count.")
                    .font(PyxisTypography.prose)
                if let product = purchase.product {
                    Button("Subscribe · \(product.displayPrice)/month") {
                        Task {
                            do { try await purchase.purchase() }
                            catch { model.errorMessage = error.localizedDescription }
                        }
                    }.buttonStyle(MinimalButtonStyle())
                    Text("Renews automatically until canceled. Monthly try-ons do not roll over. Manage or cancel in App Store subscriptions.")
                        .font(PyxisTypography.proseCaption).foregroundStyle(PyxisColors.secondaryText)
                } else {
                    Text("Subscriptions are unavailable right now.").font(PyxisTypography.proseCaption)
                }
                Button {
                    Task {
                        do { try await purchase.restore() }
                        catch { model.errorMessage = error.localizedDescription }
                    }
                } label: {
                    Text("Restore purchases").font(PyxisTypography.control).frame(minHeight: 44)
                }
                HStack {
                    Button { sheet = .privacy } label: { Text("Privacy").frame(minHeight: 44) }
                    Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                        Text("Terms").frame(minHeight: 44)
                    }
                }.font(PyxisTypography.control)
            }.padding(PyxisSpacing.md).background(PyxisColors.field).disabled(purchase.isPurchasing)
        } else {
            Button("Refresh allowance") { Task { await model.refreshAllowance(authorization: purchase.authorization) } }
                .buttonStyle(MinimalButtonStyle())
        }
    }

    private var generationRail: some View {
        VStack(spacing: PyxisSpacing.sm) {
            if model.isGenerating {
                ProgressView("Creating your preview…").font(PyxisTypography.prose)
                Text("Keep Pyxis open. Outfits with several pieces take longer.")
                    .font(PyxisTypography.proseCaption).foregroundStyle(PyxisColors.secondaryText)
            } else {
                Button(model.generatedURL == nil ? "Generate preview" : "Generate another") {
                    if model.generatedURL != nil { confirmsAnother = true } else { startGeneration() }
                }.buttonStyle(EditorialPrimaryButtonStyle()).disabled(!model.canGenerate || purchase.authorization == nil)
                    .accessibilityIdentifier("try-on-generate")
                if !model.isPrivatePC {
                    Text("Uses 1 try-on").font(PyxisTypography.proseCaption).foregroundStyle(PyxisColors.secondaryText)
                }
            }
        }.frame(maxWidth: .infinity).padding(PyxisSpacing.md).background(PyxisColors.background)
            .overlay(alignment: .top) { Rectangle().fill(PyxisColors.hairline).frame(height: 1) }
    }

    private func startGeneration() {
        if !model.hasConsent { sheet = .consent; return }
        Task { await model.generate(authorization: purchase.authorization) }
    }
    private func loadSelection(_ selection: PhotosPickerItem?, forPerson: Bool) async {
        guard let selection else { return }
        do {
            guard let data = try await selection.loadTransferable(type: Data.self), !Task.isCancelled else { return }
            await model.importPhoto(data, forPerson: forPerson)
        } catch { if !Task.isCancelled { model.errorMessage = "Your photo could not be opened." } }
    }
}

private enum TryOnSheet: String, Identifiable {
    case consent, privacy, closet, saved
    var id: String { rawValue }
}

extension ClothingCategory {
    var tryOnTitle: String {
        switch self {
        case .tops: return "Top"
        case .bottoms: return "Bottoms"
        case .footwear: return "Shoes"
        case .outerwear: return "Outerwear"
        case .onePiece: return "One piece"
        case .accessories: return "Accessory"
        case .other: return "Other"
        }
    }
}
