import SwiftData
import SwiftUI

struct SavedFitsGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \ClosetItem.dateAdded, order: .reverse) private var items: [ClosetItem]
    @Query(sort: \Outfit.dateCreated, order: .reverse) private var outfits: [Outfit]
    @State private var query = OutfitGalleryQuery()
    @State private var favoriteError: String?
    let buildAction: (() -> Void)?

    private var visibleOutfits: [Outfit] {
        OutfitGalleryService().filteredOutfits(outfits, items: items, query: query)
    }

    private var savedOutfits: [Outfit] { outfits.filter { !$0.isDeleted } }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: PyxisSpacing.md),
              count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }

    init(buildAction: (() -> Void)? = nil) {
        self.buildAction = buildAction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
            PrimaryPageHeader(title: "FITS")

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    searchField
                    filters
                    sortBar

                    if let favoriteError {
                        InlineErrorMessage(message: favoriteError)
                    }

                    if savedOutfits.isEmpty {
                        emptyState("NO SAVED FITS")
                    } else if visibleOutfits.isEmpty {
                        emptyState("NO MATCHING FITS")
                        Button("CLEAR FILTERS") { query = OutfitGalleryQuery() }
                            .buttonStyle(MinimalButtonStyle())
                    } else {
                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(visibleOutfits) { outfit in
                                fitTile(outfit)
                            }
                        }
                    }

                    SuggestedLooksView(items: items, outfits: outfits)
                        .padding(.top, PyxisSpacing.lg)
                }
                .padding(.top, 12)
                .padding(.horizontal, 8)
                .padding(.bottom, PyxisSpacing.md)
            }
            .padding(.horizontal, -8)
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 20)
        .editorialCanvas()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let buildAction {
                Button(action: buildAction) {
                    HStack {
                        Spacer()
                        Text("CREATE OUTFIT")
                            .font(PyxisTypography.editorialBody)
                            .tracking(2.5)
                        Spacer()
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .ultraLight))
                    }
                    .foregroundStyle(PyxisColors.background)
                    .padding(.horizontal, 18)
                    .frame(height: 50)
                    .background(PyxisColors.text, in: RoundedRectangle(cornerRadius: 9))
                    .editorialGlow(cornerRadius: 9, strength: 1.4)
                }
                .buttonStyle(PyxisPressableStyle())
                .padding(.horizontal, 28)
                .padding(.top, 10)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)
                .background(PyxisColors.background)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .ultraLight))
                .accessibilityHidden(true)
            TextField("SEARCH FITS", text: $query.searchText,
                      prompt: Text("SEARCH FITS").foregroundStyle(PyxisColors.secondaryText))
                .font(PyxisTypography.editorialBody)
                .tracking(1.8)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
        }
        .foregroundStyle(PyxisColors.text)
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .frame(height: 54)
        .background(PyxisColors.field, in: RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11).stroke(PyxisColors.hairline, lineWidth: 1)
        }
        .editorialGlow(cornerRadius: 11)
    }

    private var filters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                filterChip("ALL", active: !query.favoritesOnly && query.color == nil && query.season == nil) {
                    query.favoritesOnly = false
                    query.color = nil
                    query.season = nil
                }
                filterChip("FAVORITES", active: query.favoritesOnly) { query.favoritesOnly.toggle() }
                Menu {
                    Button("ALL COLORS") { query.color = nil }
                    ForEach(ClosetColor.allCases.filter { $0 != .unknown }) { color in
                        Button(color.rawValue.uppercased()) { query.color = color }
                    }
                } label: {
                    chipLabel(query.color?.rawValue.uppercased() ?? "COLOR", active: query.color != nil)
                }
                Menu {
                    Button("ALL SEASONS") { query.season = nil }
                    ForEach(Season.allCases) { season in
                        Button(season.rawValue.uppercased()) { query.season = season }
                    }
                } label: {
                    chipLabel(query.season?.rawValue.uppercased() ?? "SEASON", active: query.season != nil)
                }
            }
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .padding(.vertical, -8)
    }

    private var sortBar: some View {
        HStack(spacing: 22) {
            sortButton("RECENT", sort: .recent)
            sortButton("MOST WORN", sort: .mostWorn)
            Spacer(minLength: 0)
            Text("\(visibleOutfits.count) FITS")
                .font(PyxisTypography.editorialMicro)
                .tracking(1)
                .foregroundStyle(PyxisColors.secondaryText)
        }
        .frame(height: 42)
        .overlay(alignment: .bottom) {
            Rectangle().fill(PyxisColors.hairline).frame(height: 1)
        }
    }

    private func filterChip(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { chipLabel(title, active: active) }
            .buttonStyle(PyxisPressableStyle())
    }

    private func chipLabel(_ title: String, active: Bool) -> some View {
        Text(title)
            .font(PyxisTypography.editorialLabel)
            .tracking(1.5)
            .foregroundStyle(active ? PyxisColors.background : PyxisColors.secondaryText)
            .padding(.horizontal, 15)
            .frame(minHeight: 40)
            .background(active ? PyxisColors.text : PyxisColors.field, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8).stroke(PyxisColors.hairline, lineWidth: 1)
            }
            .editorialGlow(cornerRadius: 8, strength: active ? 1.1 : 0.5)
    }

    private func sortButton(_ title: String, sort: OutfitGallerySort) -> some View {
        Button { query.sort = sort } label: {
            Text(title)
                .font(PyxisTypography.editorialLabel)
                .tracking(1)
                .foregroundStyle(query.sort == sort ? PyxisColors.text : PyxisColors.inactiveText)
                .frame(height: 42)
                .overlay(alignment: .bottom) {
                    if query.sort == sort {
                        Rectangle().fill(PyxisColors.text).frame(height: 1)
                    }
                }
        }
        .buttonStyle(PyxisPressableStyle())
    }

    private func fitTile(_ outfit: Outfit) -> some View {
        ZStack(alignment: .bottomTrailing) {
            NavigationLink {
                OutfitDetailView(outfit: outfit)
            } label: {
                OutfitGalleryTile(outfit: outfit, items: items)
            }
            .buttonStyle(PyxisPressableStyle())

            Button { toggleFavorite(outfit) } label: {
                Image(systemName: outfit.favorite ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .ultraLight))
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(PyxisColors.text)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PyxisPressableStyle())
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

    private func emptyState(_ title: String) -> some View {
        Text(title)
            .font(PyxisTypography.editorialLabel)
            .tracking(1.5)
            .foregroundStyle(PyxisColors.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
    }
}

private struct OutfitGalleryTile: View {
    let outfit: Outfit
    let items: [ClosetItem]

    private var pieces: [ClosetItem] {
        outfit.itemIDs.compactMap { id in items.first { $0.id == id && !$0.isDeleted } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
            OutfitFlatLayView(items: pieces)
                .frame(height: 180)
                .background {
                    RoundedRectangle(cornerRadius: 9).fill(PyxisColors.galleryCanvas)
                }

            HStack(alignment: .top, spacing: PyxisSpacing.xs) {
                VStack(alignment: .leading, spacing: PyxisSpacing.xs) {
                    Text(outfit.name?.uppercased() ?? outfit.dateCreated.formatted(date: .numeric, time: .omitted))
                        .font(PyxisTypography.editorialLabel)
                        .tracking(1.1)
                        .foregroundStyle(PyxisColors.text)
                        .lineLimit(2)
                    Text("\(pieces.count) PIECES · WORN \(outfit.wearCount)×")
                        .font(PyxisTypography.editorialMicro)
                        .tracking(0.7)
                        .foregroundStyle(PyxisColors.secondaryText)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Open \(outfit.name ?? "saved fit"), \(pieces.count) pieces, worn \(outfit.wearCount) times")
    }
}

struct OutfitFlatLayView: View {
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
