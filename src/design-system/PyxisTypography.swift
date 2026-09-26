import SwiftUI

enum PyxisTypography {
    static let nav = Font.custom("IBMPlexMono-Medium", size: 12, relativeTo: .caption)
    static let code = Font.custom("IBMPlexMono-Regular", size: 11, relativeTo: .caption2)
    static let body = Font.custom("IBMPlexMono-Regular", size: 15, relativeTo: .body)
    static let label = Font.custom("IBMPlexMono-Regular", size: 12, relativeTo: .caption)
    static let title = Font.custom("IBMPlexMono-Medium", size: 20, relativeTo: .title3)

    static let editorialBrand = Font.custom("IBMPlexMono-Light", size: 28, relativeTo: .title)
    static let editorialTitle = Font.custom("IBMPlexMono-Light", size: 21, relativeTo: .title3)
    static let editorialBody = Font.custom("IBMPlexMono-Regular", size: 13, relativeTo: .body)
    static let editorialLabel = Font.custom("IBMPlexMono-Regular", size: 12, relativeTo: .caption)
    static let editorialMicro = Font.custom("IBMPlexMono-Regular", size: 10, relativeTo: .caption2)
    static let editorialNav = Font.custom("IBMPlexMono-Regular", size: 10, relativeTo: .caption)
}
