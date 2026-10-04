import SwiftUI

/// The editorial display voice for page titles, garment names, and section heads.
/// Mono stays on archival metadata; system text handles controls and prose.
enum PyxisDisplayFace: String, CaseIterable, Sendable {
    /// Newsreader — a working editorial serif. The catalog voice.
    case serif
    /// Cormorant Garamond — high-contrast didone. The runway voice.
    case didone
    /// Instrument Serif — a single-weight modern editorial italic family.
    case instrument
    /// Antonio — extend the condensed masthead voice to names and titles.
    case condensed

    /// `-pyxis.displayFace <serif|didone|instrument|condensed>` overrides the default for review.
    static var current: PyxisDisplayFace {
        let arguments = ProcessInfo.processInfo.arguments
        if let flag = arguments.firstIndex(of: "-pyxis.displayFace"),
           let raw = arguments.dropFirst(flag + 1).first,
           let face = PyxisDisplayFace(rawValue: raw) {
            return face
        }
        return .serif
    }

    /// Display text renders as stored for serifs; condensed reads in quiet caps.
    var textCase: Text.Case? { self == .condensed ? .uppercase : nil }

    /// Full-bleed page mastheads (CLOSET, FITS, PROFILE) — the Antonio voice, always.
    var pageMasthead: Font { .custom("Antonio-Light", size: 58, relativeTo: .largeTitle) }

    /// The selected garment's name and detail title.
    var garmentName: Font {
        switch self {
        case .serif: .custom("Newsreader16pt16pt-Light", size: 27, relativeTo: .title2)
        case .didone: .custom("CormorantGaramondLight-Medium", size: 31, relativeTo: .title2)
        case .instrument: .custom("InstrumentSerif-Regular", size: 29, relativeTo: .title2)
        case .condensed: .custom("Antonio-Light", size: 32, relativeTo: .title2)
        }
    }

    /// In-page section titles: Suggestions, Continue fit, empty-state heads.
    var sectionTitle: Font {
        switch self {
        case .serif: .custom("Newsreader16pt16pt-Regular", size: 21, relativeTo: .title3)
        case .didone: .custom("CormorantGaramondLight-Medium", size: 24, relativeTo: .title3)
        case .instrument: .custom("InstrumentSerif-Regular", size: 23, relativeTo: .title3)
        case .condensed: .custom("Antonio-Light", size: 24, relativeTo: .title3)
        }
    }

    /// Drill-in feature titles: Your fit, saved-fit names.
    var featureTitle: Font {
        switch self {
        case .serif: .custom("Newsreader16pt16pt-Light", size: 30, relativeTo: .title)
        case .didone: .custom("CormorantGaramondLight-Medium", size: 34, relativeTo: .title)
        case .instrument: .custom("InstrumentSerif-Regular", size: 32, relativeTo: .title)
        case .condensed: .custom("Antonio-Light", size: 34, relativeTo: .title)
        }
    }

    /// Inline navigation and sheet titles.
    var navigationTitle: Font {
        switch self {
        case .serif: .custom("Newsreader16pt16pt-Regular", size: 16, relativeTo: .headline)
        case .didone: .custom("CormorantGaramondLight-Medium", size: 19, relativeTo: .headline)
        case .instrument: .custom("InstrumentSerif-Regular", size: 18, relativeTo: .headline)
        case .condensed: .custom("Antonio-Light", size: 20, relativeTo: .headline)
        }
    }
}

enum PyxisTypography {
    static let nav = Font.custom("IBMPlexMono-Medium", size: 12, relativeTo: .caption)
    static let code = Font.custom("IBMPlexMono-Regular", size: 11, relativeTo: .caption2)
    static let label = Font.system(.footnote, design: .default, weight: .regular)
    static let title = Font.system(.title3, design: .default, weight: .medium)

    /// Controls and reading copy use the system face; mono no longer flattens them.
    static let body = Font.system(.body)
    static let button = Font.system(.callout, design: .default, weight: .medium)
    static let control = Font.system(.body)
    static let prose = Font.system(.body)
    static let proseCaption = Font.system(.footnote)
    static let fieldLabel = Font.system(.footnote, design: .default, weight: .medium)

    static let editorialBrand = Font.custom("IBMPlexMono-Light", size: 28, relativeTo: .title)
    static let closetWordmark = Font.system(.caption, design: .default, weight: .semibold)
    static let closetBrowse = Font.system(.subheadline, design: .default, weight: .semibold)

    /// Archival metadata — codes, counts, tag chips — keeps the mono voice.
    static let editorialLabel = Font.custom("IBMPlexMono-Regular", size: 12, relativeTo: .caption)
    static let editorialMicro = Font.custom("IBMPlexMono-Regular", size: 10, relativeTo: .caption2)
    static let editorialNav = Font.custom("IBMPlexMono-Regular", size: 10, relativeTo: .caption)
}
