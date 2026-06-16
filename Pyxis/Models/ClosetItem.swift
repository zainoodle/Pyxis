import Foundation
import SwiftData

@Model
public final class ClosetItem: Identifiable {
    @Attribute(.unique) public var id: UUID
    @Attribute(.unique) public var itemCode: String
    public var displayName: String?
    public var categoryRawValue: String
    public var subtypeRawValue: String
    public var primaryColorRawValue: String
    public var secondaryColorRawValues: [String]
    public var tags: [String]
    public var notes: String?
    public var brand: String?
    public var size: String?
    public var seasonRawValues: [String]
    public var dateAdded: Date
    public var lastWornDate: Date?
    public var wearCount: Int
    public var favorite: Bool
    public var imageOriginalPath: String
    public var imageCutoutPath: String?
    public var thumbnailPath: String?
    public var classificationConfidence: Double?
    public var colorConfidence: Double?
    public var sourceRawValue: String

    public init(
        id: UUID = UUID(),
        itemCode: String,
        displayName: String? = nil,
        category: ClothingCategory,
        subtype: ClothingSubtype,
        primaryColor: ClosetColor,
        secondaryColors: [ClosetColor] = [],
        tags: [String] = [],
        notes: String? = nil,
        brand: String? = nil,
        size: String? = nil,
        season: [Season] = [],
        dateAdded: Date = .now,
        lastWornDate: Date? = nil,
        wearCount: Int = 0,
        favorite: Bool = false,
        imageOriginalPath: String,
        imageCutoutPath: String? = nil,
        thumbnailPath: String? = nil,
        classificationConfidence: Double? = nil,
        colorConfidence: Double? = nil,
        source: ItemSource = .owned
    ) {
        self.id = id
        self.itemCode = itemCode
        self.displayName = displayName
        self.categoryRawValue = category.rawValue
        self.subtypeRawValue = subtype.rawValue
        self.primaryColorRawValue = primaryColor.rawValue
        self.secondaryColorRawValues = secondaryColors.map(\.rawValue)
        self.tags = tags
        self.notes = notes
        self.brand = brand
        self.size = size
        self.seasonRawValues = season.map(\.rawValue)
        self.dateAdded = dateAdded
        self.lastWornDate = lastWornDate
        self.wearCount = wearCount
        self.favorite = favorite
        self.imageOriginalPath = imageOriginalPath
        self.imageCutoutPath = imageCutoutPath
        self.thumbnailPath = thumbnailPath
        self.classificationConfidence = classificationConfidence
        self.colorConfidence = colorConfidence
        self.sourceRawValue = source.rawValue
    }

    public var category: ClothingCategory {
        get { ClothingCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    public var subtype: ClothingSubtype {
        get { ClothingSubtype(rawValue: subtypeRawValue) ?? .other }
        set { subtypeRawValue = newValue.rawValue }
    }

    public var primaryColor: ClosetColor {
        get { ClosetColor(rawValue: primaryColorRawValue) ?? .unknown }
        set { primaryColorRawValue = newValue.rawValue }
    }

    public var secondaryColors: [ClosetColor] {
        get { secondaryColorRawValues.compactMap(ClosetColor.init(rawValue:)) }
        set { secondaryColorRawValues = newValue.map(\.rawValue) }
    }

    public var season: [Season] {
        get { seasonRawValues.compactMap(Season.init(rawValue:)) }
        set { seasonRawValues = newValue.map(\.rawValue) }
    }

    public var source: ItemSource {
        get { ItemSource(rawValue: sourceRawValue) ?? .owned }
        set { sourceRawValue = newValue.rawValue }
    }
}
