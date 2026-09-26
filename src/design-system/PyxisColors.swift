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
    static let background = adaptive(light: 0xFFFFFF, dark: 0x232325)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x29292B)
    static let text = adaptive(light: 0x141311, dark: 0xF5F3EF)
    static let secondaryText = adaptive(light: 0x5C574D, dark: 0xB7B4B0)
    static let inactiveText = adaptive(light: 0x706B5E, dark: 0xA5A29D)
    static let hairline = adaptive(light: 0x948C7D, dark: 0x59595B)
    static let field = adaptive(light: 0xF7F6F0, dark: 0x2F2F31)
    static let imageCanvas = adaptive(light: 0xDAD7D0, dark: 0x2A2A2C)
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
