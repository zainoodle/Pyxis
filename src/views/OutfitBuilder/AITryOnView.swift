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
                    Text("YOUR CLOTHES. YOUR PERSPECTIVE.")
                        .font(PyxisTypography.label).foregroundStyle(PyxisColors.secondaryText)
                    referenceSection
                    clothingSection
                    if let error = model.errorMessage { InlineErrorMessage(message: error) }
                    accessSection
                    Text(TryOnPrivacy.fitDisclaimer)
                        .font(PyxisTypography.label).foregroundStyle(PyxisColors.secondaryText)
                    Button("SAVED PREVIEWS · \(model.previews.count)") { sheet = .saved }
                        .buttonStyle(MinimalButtonStyle()).disabled(model.isGenerating)
                }
                .padding(PyxisSpacing.md)
            }
            .background(PyxisColors.background)
            .navigationTitle("OUTFIT ON YOU")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { sheet = .privacy } label: { Image(systemName: "hand.raised") }
                        .accessibilityLabel("Try-on privacy").disabled(model.isGenerating)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("CLOSE") { dismiss() }.disabled(model.isGenerating || model.isImporting)
                }
            }
            .safeAreaInset(edge: .bottom) { generationRail }
            .interactiveDismissDisabled(model.isGenerating || model.isImporting)
            .task {
                await model.load()
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
                    TryOnPrivacyView(hasConsent: model.hasConsent, requestsConsent: destination == .consent,
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
                Button("GENERATE · 1 TRY-ON") { startGeneration() }
                Button("CANCEL", role: .cancel) {}
            } message: { Text("This uses one more try-on. Save this preview first if you want to keep it.") }
        }
        .tint(PyxisColors.text)
    }

    private var hasReference: Bool { model.personURL != nil }

    private var referenceSection: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.md) {
            if let url = model.showsOriginal ? model.personURL : (model.generatedURL ?? model.personURL) {
                LocalImageView(url: url)
                    .frame(maxWidth: .infinity).frame(height: model.generatedURL == nil ? 340 : 420)
                    .background(PyxisColors.field)
                    .accessibilityLabel(model.generatedURL == nil || model.showsOriginal ? "Your reference photo" : "Generated outfit preview")
                if model.generatedURL != nil {
                    Picker("Compare", selection: $model.showsOriginal) {
                        Text("TRY-ON").tag(false)
                        Text("ORIGINAL").tag(true)
                    }.pickerStyle(.segmented)
                    Button(model.resultSaved ? "SAVED ON THIS DEVICE" : "SAVE PREVIEW") { model.saveResult() }
                        .buttonStyle(MinimalButtonStyle()).disabled(model.resultSaved || model.isGenerating)
                }
            } else {
                VStack(spacing: PyxisSpacing.md) {
                    Image(systemName: "figure.stand").font(.system(size: 76, weight: .ultraLight))
                    Text("START WITH YOU").font(PyxisTypography.title)
                    Text("Choose a full-body photo. Face forward, use even lighting, and keep your arms slightly away from your body.")
                        .font(PyxisTypography.body).foregroundStyle(PyxisColors.secondaryText).multilineTextAlignment(.center)
                }.padding(PyxisSpacing.lg).frame(maxWidth: .infinity).frame(minHeight: 290).background(PyxisColors.field)
            }
            HStack {
                PhotosPicker(selection: $personSelection, matching: .images) {
                    Text(hasReference ? "CHANGE PHOTO" : "CHOOSE YOUR PHOTO")
                }.buttonStyle(MinimalButtonStyle())
                Spacer()
                if hasReference {
                    Button(role: .destructive) { model.removeReference(); personSelection = nil } label: {
                        Image(systemName: "trash")
                    }.accessibilityLabel("Remove reference photo")
                }
            }.disabled(model.isGenerating || model.isImporting)
            if model.personURL != nil {
                Toggle("Remember my photo on this device", isOn: Binding(get: { model.rememberPhoto }, set: model.setRememberPhoto))
                    .font(PyxisTypography.label).disabled(model.isGenerating || model.isImporting)
            }
        }
    }

    private var clothingSection: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.md) {
            HStack {
                Text("WHAT WOULD YOU LIKE TO TRY?").font(PyxisTypography.label)
                Spacer()
                Text("\(model.garments.count)/6").font(PyxisTypography.label).foregroundStyle(PyxisColors.secondaryText)
            }
            ForEach($model.garments) { $garment in
                HStack(spacing: PyxisSpacing.md) {
                    LocalImageView(url: garment.imageURL).frame(width: 64, height: 78).background(PyxisColors.field)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(garment.name).font(PyxisTypography.label).lineLimit(2)
                        Picker("Garment type", selection: $garment.category) {
                            ForEach(ClothingCategory.allCases) { category in
                                Text(category.tryOnTitle).tag(category)
                            }
                        }.pickerStyle(.menu).labelsHidden().accessibilityLabel("Garment type for \(garment.name)")
                    }
                    Spacer()
                    Button { model.garments.removeAll { $0.id == garment.id } } label: { Image(systemName: "xmark") }
                        .frame(minWidth: 44, minHeight: 44).accessibilityLabel("Remove \(garment.name)")
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
        Button("FROM CLOSET") { sheet = .closet }.buttonStyle(MinimalButtonStyle())
            .disabled(model.garments.count >= 6)
        PhotosPicker(selection: $garmentSelection, matching: .images) { Text("ADD A PHOTO") }
            .buttonStyle(MinimalButtonStyle()).disabled(model.garments.count >= 6)
    }

    @ViewBuilder private var accessSection: some View {
        if model.isLoading {
            ProgressView("Checking availability…").font(PyxisTypography.label)
        } else if !model.available {
            Text("Try-on is coming soon. You can prepare your photos and view any saved previews.")
                .font(PyxisTypography.body).foregroundStyle(PyxisColors.secondaryText)
        } else if let allowance = model.allowance {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(allowance.remaining) OF \(allowance.limit) TRY-ONS REMAINING").font(PyxisTypography.label)
                Text("Renews \(allowance.renewalDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(PyxisTypography.label).foregroundStyle(PyxisColors.secondaryText)
                Link("MANAGE SUBSCRIPTION", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    .font(PyxisTypography.label).padding(.top, PyxisSpacing.sm)
            }
        } else if purchase.authorization == nil {
            VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                Text("MAKE IT YOURS").font(PyxisTypography.title)
                Text("\(model.configuration?.limit ?? 20) try-ons each month. One finished preview uses one try-on. Failed generations do not count.")
                    .font(PyxisTypography.body)
                if let product = purchase.product {
                    Button("SUBSCRIBE · \(product.displayPrice)/MONTH") {
                        Task {
                            do { try await purchase.purchase() }
                            catch { model.errorMessage = error.localizedDescription }
                        }
                    }.buttonStyle(MinimalButtonStyle())
                    Text("Renews automatically until canceled. Monthly try-ons do not roll over. Manage or cancel in App Store subscriptions.")
                        .font(PyxisTypography.label).foregroundStyle(PyxisColors.secondaryText)
                } else {
                    Text("Subscriptions are not available yet.").font(PyxisTypography.label)
                }
                Button("RESTORE PURCHASE") {
                    Task {
                        do { try await purchase.restore() }
                        catch { model.errorMessage = error.localizedDescription }
                    }
                }.font(PyxisTypography.label)
                HStack {
                    Button("Privacy") { sheet = .privacy }
                    Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                }.font(PyxisTypography.label)
            }.padding(PyxisSpacing.md).background(PyxisColors.field).disabled(purchase.isPurchasing)
        } else {
            Button("REFRESH ALLOWANCE") { Task { await model.refreshAllowance(authorization: purchase.authorization) } }
                .buttonStyle(MinimalButtonStyle())
        }
    }

    private var generationRail: some View {
        VStack(spacing: PyxisSpacing.sm) {
            if model.isGenerating {
                ProgressView("Creating your preview…").font(PyxisTypography.body)
                Text("Keep Pyxis open. Outfits with several pieces take longer.")
                    .font(PyxisTypography.label).foregroundStyle(PyxisColors.secondaryText)
            } else {
                Button(model.generatedURL == nil ? "TRY ON · 1 TRY-ON" : "GENERATE ANOTHER · 1 TRY-ON") {
                    if model.generatedURL != nil { confirmsAnother = true } else { startGeneration() }
                }.buttonStyle(MinimalButtonStyle()).disabled(!model.canGenerate || purchase.authorization == nil)
                    .accessibilityIdentifier("try-on-generate")
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
        case .bottoms: return "Pants / skirt"
        case .footwear: return "Shoes"
        case .outerwear: return "Jacket / coat"
        case .onePiece: return "Dress / one-piece"
        case .accessories: return "Accessory"
        case .other: return "Identify automatically"
        }
    }
}
