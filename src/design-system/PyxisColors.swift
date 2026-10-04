import SwiftUI
import UIKit

enum PyxisAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum PyxisColors {
    static let background = adaptive(light: 0xF4F2EE, dark: 0x161618)
    static let surface = adaptive(light: 0xFBF9F5, dark: 0x1E1E20)
    static let text = adaptive(light: 0x242321, dark: 0xEAE7E1)
    static let secondaryText = adaptive(light: 0x66615A, dark: 0xB0ADA8)
    static let inactiveText = adaptive(light: 0x736D65, dark: 0x9B9893)
    static let hairline = adaptive(light: 0xCEC8BE, dark: 0x49494B)
    static let controlBorder = adaptive(light: 0x8A8379, dark: 0x777472)
    static let field = adaptive(light: 0xEBE7E1, dark: 0x242426)
    static let imageCanvas = adaptive(light: 0xE8E4DD, dark: 0x29292B)
    static let stageLight = adaptive(light: 0xFCFAF6, dark: 0x414144)
    static let stageEdge = adaptive(light: 0xD9D3C9, dark: 0x202023)
    static let galleryCanvas = imageCanvas
    static let shadow = adaptive(light: 0x000000, dark: 0x000000).opacity(0.12)
    static let error = adaptive(light: 0x8C1A14, dark: 0xFF9A8F)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}
