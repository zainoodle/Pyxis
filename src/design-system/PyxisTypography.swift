import SwiftUI

enum PyxisTypography {
    static let nav = Font.system(.caption, design: .monospaced, weight: .medium)
    static let code = Font.system(.caption2, design: .monospaced)
    static let body = Font.system(.body, design: .monospaced)
    static let label = Font.system(.caption, design: .monospaced)
    static let title = Font.system(.title3, design: .monospaced, weight: .medium)

    static let editorialBrand = Font.system(size: 23, weight: .light, design: .monospaced)
    static let editorialTitle = Font.system(size: 21, weight: .regular, design: .monospaced)
    static let editorialBody = Font.system(size: 13, weight: .regular, design: .monospaced)
    static let editorialLabel = Font.system(size: 11, weight: .regular, design: .monospaced)
    static let editorialMicro = Font.system(size: 9, weight: .regular, design: .monospaced)
    static let editorialNav = Font.system(size: 10, weight: .regular, design: .monospaced)
}
