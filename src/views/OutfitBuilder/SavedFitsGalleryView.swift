import SwiftData
import SwiftUI

struct SavedFitsGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \ClosetItem.dateAdded, order: .reverse) private var items: [ClosetItem]
    @Query(sort: \Outfit.dateCreated, order: .reverse) private var outfits: [Outfit]
    @State private var query = OutfitGalleryQuery()
    @State private var favoriteError: String?
    @State private var isShowingSearch = false
    @State private var selectedSearchResult: Outfit?
    @AppStorage("pyxis.outfitComposition.v1") private var draftData = Data()
    let buildAction: (() -> Void)?

    init(buildAction: (() -> Void)? = nil) { self.buildAction = buildAction }

    private var visibleOutfits: [Outfit] {
        OutfitGalleryService().filteredOutfits(outfits, items: items, query: query)
    }
    private var savedOutfits: [Outfit] { outfits.filter { !$0.isDeleted } }
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16),
              count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PrimaryPageHeader(title: "Fits") {
                HStack(spacing: 0) {
                    HeaderIconButton(symbol: "magnifyingglass", label: "Search fits", identifier: "fits.openSearch") {
                        isShowingSearch = true
                    }
                    if let buildAction {
                        HeaderIconButton(symbol: "plus", label: "Create fit", identifier: "fits.create", action: buildAction)
                    }
                }
            }

            if !savedOutfits.isEmpty {
                FitsBrowseMenu(query: $query, count: visibleOutfits.count)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let favoriteError { InlineErrorMessage(message: favoriteError) }
                    if !draftData.isEmpty, let buildAction {
                        Button(action: buildAction) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Continue fit").font(PyxisTypography.editorialTitle)
                                }
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                            .foregroundStyle(PyxisColors.text)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("fits.resumeDraft")
                    }

                    if savedOutfits.isEmpty {
                        emptyState("Your first fit", detail: "Bring pieces from your closet together.")
                        if let buildAction {
                            if draftData.isEmpty {
                                Button("Create a fit", action: buildAction)
                                    .buttonStyle(EditorialPrimaryButtonStyle())
                            }
                        }
                    } else if visibleOutfits.isEmpty {
                        emptyState("No matching fits", detail: "Try another search or clear your filters.")
                        Button("Clear all") { query = OutfitGalleryQuery() }
                            .buttonStyle(MinimalButtonStyle())
                    } else {
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(visibleOutfits) { outfit in
                                fitTile(outfit)
                            }
                        }
                    }

                    SuggestedLooksView(items: items, outfits: outfits)
                        .padding(.top, 16)
                }
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 24)
        .editorialCanvas()
        .sheet(isPresented: $isShowingSearch) {
            SavedFitsSearchSheet(query: $query, outfits: outfits, items: items) {
                selectedSearchResult = $0
            }
        }
        .navigationDestination(item: $selectedSearchResult) { outfit in
            OutfitDetailView(outfit: outfit)
        }
    }

    private func fitTile(_ outfit: Outfit) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink {
                OutfitDetailView(outfit: outfit)
            } label: {
                OutfitGalleryTile(outfit: outfit, items: items)
            }
            .buttonStyle(.plain)

            Button { toggleFavorite(outfit) } label: {
                Image(systemName: outfit.favorite ? "heart.fill" : "heart")
                    .font(.system(size: 18, weight: .light))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(PyxisColors.text)
            .accessibilityLabel(outfit.favorite ? "Remove favorite" : "Favorite fit")
        }
    }

    private func toggleFavorite(_ outfit: Outfit) {
        outfit.favorite.toggle()
        do {
            try modelContext.save()
            favoriteError = nil
        } catch {
            modelContext.rollback()
            favoriteError = PersistenceErrorMessage.saveFailed(error)
        }
    }

    private func emptyState(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(PyxisTypography.editorialTitle).foregroundStyle(PyxisColors.text)
            Text(detail).font(PyxisTypography.body).foregroundStyle(PyxisColors.secondaryText)
        }
        .padding(.top, 16)
    }
}

private struct FitsBrowseMenu: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var query: OutfitGalleryQuery
    let count: Int

    private var browseLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
    }

    private var detail: String? {
        var parts: [String] = []
        if !query.searchText.isEmpty { parts.append("“\(query.searchText)”") }
        if let color = query.color { parts.append(color.rawValue.capitalized) }
        if let season = query.season { parts.append(season.rawValue.capitalized) }
        if query.sort == .mostWorn { parts.append("Most worn") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        browseLayout {
            Menu {
                Button("All fits") { query = OutfitGalleryQuery() }
                Toggle("Favorites only", isOn: $query.favoritesOnly)
                Section("Sort") {
                    Picker("Sort", selection: $query.sort) {
                        Text("Recent").tag(OutfitGallerySort.recent)
                        Text("Most worn").tag(OutfitGallerySort.mostWorn)
                    }
                }
                Menu("Color") {
                    Button("All colors") { query.color = nil }
                    ForEach(ClosetColor.allCases.filter { $0 != .unknown }) { color in
                        Button(color.rawValue.capitalized) { query.color = color }
                    }
                }
                Menu("Season") {
                    Button("All seasons") { query.season = nil }
                    ForEach(Season.allCases) { season in
                        Button(season.rawValue.capitalized) { query.season = season }
                    }
                }
                Button("Clear all") { query = OutfitGalleryQuery() }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(query.favoritesOnly ? "Favorites" : "All fits")
                            .font(PyxisTypography.closetBrowse)
                        if let detail {
                            Text(detail).font(PyxisTypography.editorialMicro)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .light))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Browse fits")
            .accessibilityValue(([query.favoritesOnly ? "Favorites" : "All fits", detail].compactMap { $0 }).joined(separator: ", "))
            .accessibilityIdentifier("fits.browse")
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Text("\(count) shown")
                .font(PyxisTypography.editorialMicro)
                .frame(minHeight: 44)
        }
        .foregroundStyle(PyxisColors.secondaryText)
    }
}

private struct OutfitGalleryTile: View {
    @Environment(\.colorScheme) private var colorScheme
    let outfit: Outfit
    let items: [ClosetItem]

    private var pieces: [ClosetItem] {
        outfit.itemIDs.compactMap { id in items.first { $0.id == id && !$0.isDeleted } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
            OutfitFlatLayView(items: pieces)
                .frame(height: colorScheme == .dark ? 180 : 208)
                .background {
                    if colorScheme == .light {
                        RoundedRectangle(cornerRadius: 9).fill(PyxisColors.galleryCanvas)
                    }
                }

            HStack(alignment: .top, spacing: PyxisSpacing.xs) {
                VStack(alignment: .leading, spacing: PyxisSpacing.xs) {
                    Text(outfit.name?.uppercased() ?? outfit.dateCreated.formatted(date: .numeric, time: .omitted))
                        .font(colorScheme == .dark ? PyxisTypography.editorialLabel : PyxisTypography.label)
                        .tracking(colorScheme == .dark ? 1.1 : 0)
                        .foregroundStyle(PyxisColors.text)
                        .lineLimit(2)
                    Text("\(pieces.count) PIECES" + (outfit.wearCount > 0 ? " · WORN \(outfit.wearCount)×" : ""))
                        .font(colorScheme == .dark ? PyxisTypography.editorialMicro : PyxisTypography.code)
                        .tracking(colorScheme == .dark ? 0.7 : 0)
                        .foregroundStyle(PyxisColors.secondaryText)
                }
                Spacer(minLength: 0)
                if outfit.favorite && colorScheme == .light {
                    Image(systemName: "heart.fill")
                        .font(PyxisTypography.label)
                        .foregroundStyle(PyxisColors.text)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Open \(outfit.name ?? "saved fit"), \(pieces.count) pieces" + (outfit.wearCount > 0 ? ", worn \(outfit.wearCount) times" : ""))
    }
}

struct OutfitFlatLayView: View {
    let items: [ClosetItem]

    var body: some View {
        GeometryReader { geometry in
            if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "hanger").font(.system(size: 36, weight: .ultraLight))
                    Text("Add a piece to start your fit")
                        .font(PyxisTypography.control)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(PyxisColors.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ZStack {
                    ForEach(Array(items.prefix(6))) { item in
                        let placement = placement(for: item)
                        LocalImageView(
                            url: ImageStorageService.shared?.url(for: ClosetItemImageResolver.preferredFullSizePath(for: item)),
                            revision: Int(item.effectiveDateUpdated.timeIntervalSince1970 * 1_000)
                        )
                        .frame(width: geometry.size.width * placement.width,
                               height: geometry.size.height * placement.height)
                        .rotationEffect(.degrees(placement.rotation))
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 6)
                        .position(x: geometry.size.width * placement.x, y: geometry.size.height * placement.y)
                        .accessibilityLabel(item.displayName ?? item.itemCode)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func placement(for item: ClosetItem) -> (width: CGFloat, height: CGFloat, x: CGFloat, y: CGFloat, rotation: Double) {
        let hasLayer = items.contains { $0.category == .outerwear }
        let hasOnePiece = items.contains { $0.category == .onePiece }
        switch item.category {
        case .outerwear: return (0.60, 0.57, 0.29, 0.29, 0)
        case .tops: return hasLayer ? (0.49, 0.43, 0.75, 0.27, 0) : (0.60, 0.56, 0.30, 0.29, 0)
        case .bottoms: return hasLayer ? (0.54, 0.62, 0.44, 0.68, 5) : (0.52, 0.75, 0.72, 0.51, 3)
        case .onePiece: return (0.62, 0.92, 0.35, 0.49, 0)
        case .footwear:
            return hasLayer || hasOnePiece ? (0.35, 0.28, 0.81, 0.79, -10) : (0.43, 0.28, 0.30, 0.84, -8)
        case .accessories: return (0.27, 0.25, 0.82, 0.52, 0)
        case .other: return (0.3, 0.3, 0.5, 0.5, 0)
        }
    }
}
