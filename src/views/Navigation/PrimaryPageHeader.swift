import SwiftUI

/// One destination title, with related actions aligned on the trailing edge.
struct PrimaryPageHeader<Actions: View>: View {
    private let title: String
    private let actions: Actions

    init(title: String, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.actions = actions()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                heading.fixedSize()
                Spacer(minLength: 0)
                actions
            }
            VStack(alignment: .leading, spacing: 8) {
                heading
                HStack { Spacer(); actions }
            }
        }
        .foregroundStyle(PyxisColors.text)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.top, 8)
    }

    private var heading: some View {
        Text(title)
            .font(PyxisTypography.pageTitle)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityAddTraits(.isHeader)
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
