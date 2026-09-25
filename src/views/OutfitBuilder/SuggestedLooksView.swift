import SwiftData
import SwiftUI

struct SuggestedLooksView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let items: [ClosetItem]
    let outfits: [Outfit]
    @State private var selectedID: String?
    @State private var message: String?

    private var suggestions: [SuggestedLook] {
        LocalOutfitSuggestionService().suggestions(from: items, excluding: outfits)
    }

    private var featured: SuggestedLook? {
        suggestions.first(where: { $0.id == selectedID }) ?? suggestions.first
    }

    private var hasEnoughPieces: Bool {
        let owned = items.filter { !$0.isDeleted && $0.source == .owned }
        let categories = Set(owned.map(\.category))
        return categories.contains(.footwear)
            && (categories.contains(.onePiece) || (categories.contains(.tops) && categories.contains(.bottoms)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("PICKED FOR YOU")
                    .font(colorScheme == .dark ? PyxisTypography.editorialTitle : PyxisTypography.title)
                    .tracking(colorScheme == .dark ? 2 : 0)
                    .foregroundStyle(PyxisColors.text)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("YOUR CLOSET / NEW COMBINATIONS")
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.secondaryText)
                    .multilineTextAlignment(.trailing)
            }

            if let featured {
                OutfitFlatLayView(items: featured.items)
                    .frame(height: dynamicTypeSize.isAccessibilitySize ? 220 : 235)
                    .background {
                        if colorScheme == .light {
                            RoundedRectangle(cornerRadius: 12).fill(PyxisColors.galleryCanvas)
                        }
                    }
                    .accessibilityLabel("Suggested look made from \(featured.items.map { $0.displayName ?? $0.itemCode }.joined(separator: ", "))")

                HStack(alignment: .top, spacing: PyxisSpacing.md) {
                    VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                        Text(featured.title)
                            .font(colorScheme == .dark ? PyxisTypography.editorialTitle : .system(.title2, design: .monospaced, weight: .medium))
                            .tracking(colorScheme == .dark ? 1.5 : 0)
                            .foregroundStyle(PyxisColors.text)
                        Text(featured.summary)
                            .font(PyxisTypography.body)
                            .foregroundStyle(PyxisColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PyxisSpacing.sm) {
                        ForEach(featured.tags, id: \.self) { tag in
                            Text(tag)
                                .font(PyxisTypography.label)
                                .foregroundStyle(PyxisColors.secondaryText)
                                .padding(.horizontal, PyxisSpacing.md)
                                .padding(.vertical, PyxisSpacing.sm)
                                .background(PyxisColors.field, in: Capsule())
                        }
                    }
                }

                Button { save(featured) } label: {
                    HStack {
                        Spacer()
                        Text("SAVE THIS LOOK")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(PyxisTypography.body)
                    .foregroundStyle(PyxisColors.background)
                    .padding(PyxisSpacing.md)
                    .frame(minHeight: 52)
                    .background(PyxisColors.text, in: RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Save suggested look \(featured.title)")

                if suggestions.count > 1 {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: PyxisSpacing.md),
                                             count: dynamicTypeSize.isAccessibilitySize ? 1 : 2),
                              spacing: PyxisSpacing.md) {
                        ForEach(suggestions.filter { $0.id != featured.id }) { look in
                            Button { selectedID = look.id } label: {
                                VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                                    OutfitFlatLayView(items: look.items)
                                        .frame(height: 142)
                                        .background {
                                            if colorScheme == .light {
                                                RoundedRectangle(cornerRadius: 9).fill(PyxisColors.galleryCanvas)
                                            }
                                        }
                                    Text(look.title)
                                        .font(PyxisTypography.label)
                                        .foregroundStyle(PyxisColors.text)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Show suggested look \(look.title)")
                        }
                    }
                }
            } else {
                Text(hasEnoughPieces
                     ? "ALL CURRENT COMBINATIONS ARE SAVED. ADD A PIECE TO UNLOCK NEW LOOKS."
                     : "ADD A TOP, BOTTOM, AND SHOES, OR A ONE-PIECE AND SHOES, TO GET LOOKS.")
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            }

            if let message {
                Text(message)
                    .font(PyxisTypography.label)
                    .foregroundStyle(PyxisColors.secondaryText)
            }
        }
        .padding(.bottom, PyxisSpacing.lg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(PyxisColors.hairline.opacity(0.5)).frame(height: 1)
        }
    }

    private func save(_ look: SuggestedLook) {
        let outfit = OutfitBuilderService().outfit(from: look.draft, name: look.title, notes: look.summary)
        modelContext.insert(outfit)
        do {
            let payload = OnDeviceMemoryPayloadBuilder.outfitPayload(for: outfit, items: items)
            try OnDeviceMemoryStore(context: modelContext).upsertMemory(
                kind: .outfit,
                subjectID: outfit.id,
                summary: payload.summary,
                embedding: payload.embedding,
                metadataTags: payload.metadataTags,
                updatedAt: outfit.dateUpdated,
                saveImmediately: false
            )
            try modelContext.save()
            selectedID = nil
            message = "SAVED TO FITS"
        } catch {
            modelContext.rollback()
            message = PersistenceErrorMessage.saveFailed(error)
        }
    }
}
