import Foundation

public enum ClosetItemImageResolver {
    public static func preferredDisplayPath(for item: ClosetItem) -> String {
        if let cutoutPath = item.imageCutoutPath {
            return cutoutPath
        }
        if let thumbnailPath = item.thumbnailPath {
            return thumbnailPath
        }
        return item.imageOriginalPath
    }

    /// Large garment presentations should never upscale a catalog thumbnail.
    public static func preferredFullSizePath(for item: ClosetItem) -> String {
        item.imageCutoutPath ?? item.imageOriginalPath
    }

    public static func hasCutout(for item: ClosetItem) -> Bool {
        item.imageCutoutPath != nil
    }
}
