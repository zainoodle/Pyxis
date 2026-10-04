import SwiftData
import SwiftUI

struct SuggestedLooksView: View {
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
            VStack(alignment: .leading, spacing: 6) {
                Text("Suggestions")
                    .font(PyxisTypography.editorialTitle)
                    .foregroundStyle(PyxisColors.text)
                    .accessibilityAddTraits(.isHeader)
            }

            if let featured {
                OutfitFlatLayView(items: featured.items)
                    .frame(height: dynamicTypeSize.isAccessibilitySize ? 220 : 235)
                    .garmentSurface()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Suggested look made from \(featured.items.map { $0.displayName ?? $0.itemCode }.joined(separator: ", "))")

                HStack(alignment: .top, spacing: PyxisSpacing.md) {
                    VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                        Text(featured.title)
                            .font(PyxisTypography.editorialTitle)
                            .tracking(0)
                            .foregroundStyle(PyxisColors.text)
                        Text("\(featured.items.count) pieces")
                            .font(PyxisTypography.editorialLabel)
                            .foregroundStyle(PyxisColors.secondaryText)
                    }
                    Spacer(minLength: 0)
                }

                Button("Save fit") { save(featured) }
                    .buttonStyle(EditorialPrimaryButtonStyle())
                    .accessibilityLabel("Save suggested fit \(featured.title)")

                if suggestions.count > 1 {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: PyxisSpacing.md),
                                             count: dynamicTypeSize.isAccessibilitySize ? 1 : 2),
                              spacing: PyxisSpacing.md) {
                        ForEach(suggestions.filter { $0.id != featured.id }) { look in
                            Button { selectedID = look.id } label: {
                                VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                                    OutfitFlatLayView(items: look.items)
                                        .frame(height: 142)
                                        .garmentSurface()
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
                     ? "No new combinations yet."
                     : "Add a complete outfit to see suggestions.")
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
        let outfit = OutfitBuilderService().outfit(from: look.draft, name: look.title)
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
            message = "Fit saved"
        } catch {
            modelContext.rollback()
            message = PersistenceErrorMessage.saveFailed(error)
        }
    }
}
