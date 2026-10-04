import SwiftData
import SwiftUI

/// Shows one garment at a time without exposing neighboring images.
struct ClosetSpotlightView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var selectedItemID: UUID?
    @State private var favoriteError: String?

    let items: [ClosetItem]
    let buildAction: (UUID?) -> Void

    private var currentIndex: Int {
        items.firstIndex { $0.id == selectedItemID } ?? 0
    }

    private var currentItem: ClosetItem {
        items[currentIndex]
    }

    private var selection: Binding<UUID> {
        Binding(
            get: { currentItem.id },
            set: { selectedItemID = $0 }
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = min(geometry.size.width - 32, 350)
            let cardHeight = min(max(geometry.size.width * 0.88, 290), 370)

            ScrollView {
                VStack(alignment: .leading, spacing: PyxisSpacing.md) {
                    TabView(selection: selection) {
                        ForEach(items) { item in
                            garmentCard(item, width: cardWidth, height: cardHeight)
                                .frame(maxWidth: .infinity)
                                .tag(item.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: cardHeight + 12)
                    .clipped()

                    if items.count > 1 {
                        pageControls
                    }

                    itemHeading

                    if let favoriteError {
                        InlineErrorMessage(message: favoriteError)
                    }

                    NavigationLink {
                        ItemDetailView(item: currentItem, showsCloseButton: false) { buildItem in
                            buildAction(buildItem.id)
                        }
                    } label: {
                        Text("VIEW ITEM")
                            .font(PyxisTypography.editorialLabel)
                            .tracking(1.5)
                            .foregroundStyle(PyxisColors.text)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(PyxisColors.field, in: RoundedRectangle(cornerRadius: 10))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(PyxisColors.hairline, lineWidth: 1)
                            }
                            .editorialGlow()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View \(itemName(currentItem))")
                }
                .padding(.top, PyxisSpacing.sm)
                .padding(.bottom, PyxisSpacing.md)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .onChange(of: items.map(\.id)) { _, ids in
            if let selectedItemID, ids.contains(selectedItemID) {
                return
            }
            selectedItemID = ids.first
        }
    }

    private func garmentCard(_ item: ClosetItem, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(PyxisColors.field)

            if colorScheme == .dark {
                RadialGradient(
                    colors: [.white.opacity(0.07), .clear],
                    center: .center,
                    startRadius: 8,
                    endRadius: height * 0.7
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            LocalImageView(url: imageURL(for: item), revision: imageRevision(for: item))
                .padding(22)
        }
        .frame(width: width, height: height)
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PyxisColors.hairline, lineWidth: 1)
        }
        .shadow(color: PyxisColors.shadow, radius: 14, x: 0, y: 8)
        .editorialGlow(cornerRadius: 20, strength: 0.6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(itemName(item)), item \((items.firstIndex { $0.id == item.id } ?? 0) + 1) of \(items.count)")
    }

    private var pageControls: some View {
        HStack(spacing: PyxisSpacing.sm) {
            Button {
                moveSelection(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .light))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(currentIndex == 0)
            .accessibilityLabel("Previous item")

            Spacer()

            if items.count <= 7 {
                HStack(spacing: 10) {
                    ForEach(items.indices, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? PyxisColors.text : PyxisColors.hairline)
                            .frame(width: 7, height: 7)
                    }
                }
                .accessibilityHidden(true)
            } else {
                Text("\(currentIndex + 1) / \(items.count)")
                    .font(PyxisTypography.editorialLabel)
                    .foregroundStyle(PyxisColors.secondaryText)
                    .accessibilityHidden(true)
            }

            Spacer()

            Button {
                moveSelection(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .light))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(currentIndex == items.count - 1)
            .accessibilityLabel("Next item")
        }
        .foregroundStyle(PyxisColors.text)
        .accessibilityValue("Item \(currentIndex + 1) of \(items.count)")
    }

    private var itemHeading: some View {
        HStack(alignment: .top, spacing: PyxisSpacing.md) {
            VStack(alignment: .leading, spacing: PyxisSpacing.xs) {
                Text(itemName(currentItem).uppercased())
                    .font(colorScheme == .dark ? PyxisTypography.editorialTitle : PyxisTypography.title)
                    .tracking(colorScheme == .dark ? 1.2 : 0)
                    .foregroundStyle(PyxisColors.text)
                    .lineLimit(2)

                Text(currentItem.itemCode.uppercased())
                    .font(PyxisTypography.editorialLabel)
                    .tracking(1)
                    .foregroundStyle(PyxisColors.secondaryText)
            }

            Spacer(minLength: 0)

            Button {
                toggleFavorite(currentItem)
            } label: {
                Image(systemName: currentItem.favorite ? "heart.fill" : "heart")
                    .font(.system(size: 24, weight: .ultraLight))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(PyxisColors.text)
            .accessibilityLabel(currentItem.favorite ? "Remove favorite" : "Favorite item")
        }
    }

    private func moveSelection(by offset: Int) {
        let nextIndex = min(max(currentIndex + offset, 0), items.count - 1)
        selectedItemID = items[nextIndex].id
    }

    private func toggleFavorite(_ item: ClosetItem) {
        item.favorite.toggle()
        do {
            try modelContext.save()
            favoriteError = nil
        } catch {
            modelContext.rollback()
            favoriteError = PersistenceErrorMessage.saveFailed(error)
        }
    }

    private func itemName(_ item: ClosetItem) -> String {
        let name = item.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.flatMap { $0.isEmpty ? nil : $0 } ?? item.subtype.rawValue
    }

    private func imageURL(for item: ClosetItem) -> URL? {
        guard let storage = ImageStorageService.shared else {
            return nil
        }
        return storage.url(for: ClosetItemImageResolver.preferredDisplayPath(for: item))
    }

    private func imageRevision(for item: ClosetItem) -> Int {
        Int(item.effectiveDateUpdated.timeIntervalSince1970 * 1_000)
    }
}
