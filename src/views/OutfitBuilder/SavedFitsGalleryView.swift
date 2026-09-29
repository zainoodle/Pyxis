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

                    if savedOutfits.isEmpty {
                        emptyState("Your first fit", detail: "Bring pieces from your closet together.")
                        if let buildAction {
                            Button("Create a fit", action: buildAction)
                                .buttonStyle(MinimalButtonStyle())
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
                    Text("\(pieces.count) PIECES · WORN \(outfit.wearCount)×")
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
        .accessibilityLabel("Open \(outfit.name ?? "saved fit"), \(pieces.count) pieces, worn \(outfit.wearCount) times")
    }
}

struct OutfitFlatLayView: View {
    @Environment(\.colorScheme) private var colorScheme
    let items: [ClosetItem]

    var body: some View {
        GeometryReader { geometry in
            if items.isEmpty {
                Text("NO CLOSET IMAGES")
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.inactiveText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(Array(items.prefix(5).enumerated()), id: \.element.id) { index, item in
                    LocalImageView(url: imageURL(for: item), revision: Int(item.effectiveDateUpdated.timeIntervalSince1970 * 1_000))
                        .frame(width: geometry.size.width * width(for: index),
                               height: geometry.size.height * height(for: index))
                        .position(x: geometry.size.width * x(for: index),
                                  y: geometry.size.height * y(for: index))
                }
            }
        }
        .clipped()
    }

    private func imageURL(for item: ClosetItem) -> URL? {
        ImageStorageService.shared?.url(for: ClosetItemImageResolver.preferredDisplayPath(for: item))
    }

    private func width(for index: Int) -> CGFloat { [0.59, 0.53, 0.51, 0.38, 0.34][index] }
    private func height(for index: Int) -> CGFloat { [0.59, 0.66, 0.36, 0.45, 0.30][index] }
    private func x(for index: Int) -> CGFloat { [0.35, 0.68, 0.33, 0.77, 0.57][index] }
    private func y(for index: Int) -> CGFloat { [0.34, 0.56, 0.83, 0.28, 0.83][index] }
}
