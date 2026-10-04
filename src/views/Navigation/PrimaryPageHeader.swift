import SwiftUI

/// Every page opens like a spread in the same archive: the Pyxis wordmark,
/// related actions on the trailing edge, then the page name in the masthead face.
struct PrimaryPageHeader<Actions: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let title: String
    private let actions: Actions

    init(title: String, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.actions = actions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("PYXIS")
                    .font(PyxisTypography.closetWordmark)
                    .tracking(4)
                    .foregroundStyle(PyxisColors.text)
                    .accessibilityHidden(true)
                Spacer(minLength: 12)
                actions
            }
            .frame(minHeight: 44)
            heading
        }
        .foregroundStyle(PyxisColors.text)
    }

    private var heading: some View {
        Text(dynamicTypeSize.isAccessibilitySize ? title.capitalized : title.uppercased())
            .font(dynamicTypeSize.isAccessibilitySize
                  ? PyxisDisplayFace.current.featureTitle
                  : PyxisDisplayFace.current.pageMasthead)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(title)
    }
}

extension PrimaryPageHeader where Actions == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

struct HeaderIconButton: View {
    let symbol: String
    let label: String
    var identifier = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .light))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}
