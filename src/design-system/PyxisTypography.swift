import SwiftUI

enum PyxisTypography {
    static let nav = Font.custom("IBMPlexMono-Medium", size: 12, relativeTo: .caption)
    static let code = Font.custom("IBMPlexMono-Regular", size: 11, relativeTo: .caption2)
    static let body = Font.custom("IBMPlexMono-Regular", size: 15, relativeTo: .body)
    static let label = Font.custom("IBMPlexMono-Regular", size: 12, relativeTo: .caption)
    static let title = Font.custom("IBMPlexMono-Medium", size: 20, relativeTo: .title3)

    static let editorialBrand = Font.custom("IBMPlexMono-Light", size: 28, relativeTo: .title)
    static let pageTitle = Font.system(.largeTitle, design: .default, weight: .light)
    static let closetBrowse = Font.system(.body, design: .default, weight: .regular)
    static let editorialTitle = Font.system(.title3, design: .default, weight: .light)
    static let garmentTitle = Font.system(.title2, design: .default, weight: .light)
    static let control = Font.system(.body, design: .default, weight: .regular)
    static let prose = Font.system(.body)
    static let proseCaption = Font.system(.footnote)
    static let editorialBody = Font.custom("IBMPlexMono-Regular", size: 13, relativeTo: .body)
    static let editorialLabel = Font.custom("IBMPlexMono-Regular", size: 12, relativeTo: .caption)
    static let editorialMicro = Font.custom("IBMPlexMono-Regular", size: 10, relativeTo: .caption2)
    static let editorialNav = Font.custom("IBMPlexMono-Regular", size: 10, relativeTo: .caption)
}
