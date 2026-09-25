import SwiftData
import SwiftUI

struct SavedFitsGalleryView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \ClosetItem.dateAdded, order: .reverse) private var items: [ClosetItem]
    @Query(sort: \Outfit.dateCreated, order: .reverse) private var outfits: [Outfit]
    @State private var query = OutfitGalleryQuery()
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
        VStack(alignment: .leading, spacing: PyxisSpacing.lg) {
            PrimaryPageHeader {
                if let buildAction {
                    Button("BUILD FIT", action: buildAction)
                        .buttonStyle(MinimalButtonStyle())
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: PyxisSpacing.lg) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: PyxisSpacing.xs) {
                            Text("FITS")
                                .font(.system(.largeTitle, design: .monospaced, weight: .medium))
                                .foregroundStyle(PyxisColors.text)
                                .accessibilityAddTraits(.isHeader)
                            Text("YOUR LOCAL LOOKBOOK")
                                .font(PyxisTypography.label)
                                .foregroundStyle(PyxisColors.secondaryText)
                        }
                        Spacer()
                        Text("\(savedOutfits.count) FITS")
                            .font(PyxisTypography.label)
                            .foregroundStyle(PyxisColors.secondaryText)
                    }

                    if !savedOutfits.isEmpty {
                        searchField
                        filters
                        sortBar
                    }

                    if savedOutfits.isEmpty {
                        emptyState("NO SAVED FITS", detail: "BUILD A FIT FROM YOUR CLOSET TO START YOUR LOOKBOOK")
                    } else if visibleOutfits.isEmpty {
                        emptyState("NO MATCHING FITS", detail: "TRY ANOTHER SEARCH OR CLEAR YOUR FILTERS")
                        Button("CLEAR FILTERS") { query = OutfitGalleryQuery() }
                            .buttonStyle(MinimalButtonStyle())
                    } else {
                        LazyVGrid(columns: columns, spacing: PyxisSpacing.lg) {
                            ForEach(visibleOutfits) { outfit in
                                NavigationLink {
                                    OutfitDetailView(outfit: outfit)
                                } label: {
                                    OutfitGalleryTile(outfit: outfit, items: items)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.vertical, PyxisSpacing.md)
            }
        }
        .padding(.horizontal, PyxisSpacing.md)
        .padding(.bottom, PyxisSpacing.md)
        .background(PyxisColors.background)
    }

    private var searchField: some View {
        HStack(spacing: PyxisSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .accessibilityHidden(true)
            TextField("SEARCH FITS, CLOTHES, NOTES", text: $query.searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
        }
        .font(PyxisTypography.body)
        .foregroundStyle(PyxisColors.text)
        .padding(PyxisSpacing.md)
        .frame(minHeight: 52)
        .background(PyxisColors.field, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel("Search saved fits")
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PyxisSpacing.sm) {
                filterChip("ALL", active: !query.favoritesOnly && query.color == nil && query.season == nil) {
                    query.favoritesOnly = false
                    query.color = nil
                    query.season = nil
                }
                filterChip("FAVORITES", active: query.favoritesOnly) {
                    query.favoritesOnly.toggle()
                }
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
        }
    }

    private var sortBar: some View {
        HStack(spacing: PyxisSpacing.lg) {
            sortButton("RECENT", value: .recent)
            sortButton("MOST WORN", value: .mostWorn)
            Spacer(minLength: 0)
            Text("\(visibleOutfits.count) SHOWN")
                .font(PyxisTypography.label)
                .foregroundStyle(PyxisColors.inactiveText)
        }
        .padding(.bottom, PyxisSpacing.sm)
        .overlay(alignment: .bottom) {
            Rectangle().fill(PyxisColors.hairline.opacity(0.45)).frame(height: 1)
        }
    }

    private func filterChip(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { chipLabel(title, active: active) }
            .buttonStyle(.plain)
    }

    private func chipLabel(_ title: String, active: Bool) -> some View {
        Text(title)
            .font(PyxisTypography.label)
            .foregroundStyle(active ? PyxisColors.background : PyxisColors.text)
            .padding(.horizontal, PyxisSpacing.md)
            .frame(minHeight: 44)
            .background(active ? PyxisColors.text : PyxisColors.field, in: Capsule())
    }

    private func sortButton(_ title: String, value: OutfitGallerySort) -> some View {
        Button {
            query.sort = value
        } label: {
            Text(title)
                .font(PyxisTypography.label)
                .foregroundStyle(query.sort == value ? PyxisColors.text : PyxisColors.secondaryText)
                .frame(minHeight: 44)
                .overlay(alignment: .bottom) {
                    if query.sort == value {
                        Rectangle().fill(PyxisColors.text).frame(height: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func emptyState(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
            Text(title).font(PyxisTypography.title).foregroundStyle(PyxisColors.text)
            Text(detail).font(PyxisTypography.label).foregroundStyle(PyxisColors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
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
                .frame(height: 208)
                .background(PyxisColors.galleryCanvas, in: RoundedRectangle(cornerRadius: 9))

            HStack(alignment: .top, spacing: PyxisSpacing.xs) {
                VStack(alignment: .leading, spacing: PyxisSpacing.xs) {
                    Text(outfit.name?.uppercased() ?? outfit.dateCreated.formatted(date: .numeric, time: .omitted))
                        .font(PyxisTypography.label)
                        .foregroundStyle(PyxisColors.text)
                        .lineLimit(2)
                    Text("\(pieces.count) PIECES · WORN \(outfit.wearCount)×")
                        .font(PyxisTypography.code)
                        .foregroundStyle(PyxisColors.secondaryText)
                }
                Spacer(minLength: 0)
                if outfit.favorite {
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
