import SwiftUI

/// A stable anchor for each top-level tab. The tab bar identifies the current
/// destination, while this header keeps the brand and page actions in one place.
struct PrimaryPageHeader<Actions: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    private let title: String?
    private let actions: Actions

    init(title: String? = nil, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.actions = actions()
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                    brand
                    actions
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: PyxisSpacing.md) {
                        brand
                        Spacer(minLength: PyxisSpacing.sm)
                        actions
                    }

                    VStack(alignment: .leading, spacing: PyxisSpacing.sm) {
                        brand
                        actions
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: colorScheme == .dark ? 56 : 44, alignment: .leading)
        .padding(.top, colorScheme == .dark ? PyxisSpacing.sm : PyxisSpacing.lg)
    }

    private var brand: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("PYXIS")
                .font(colorScheme == .dark ? PyxisTypography.editorialBrand : PyxisTypography.title)
                .tracking(colorScheme == .dark ? 4 : 0)
                .foregroundStyle(PyxisColors.text)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            if colorScheme == .dark, let title {
                Text(title)
                    .font(PyxisTypography.editorialLabel)
                    .tracking(3)
                    .foregroundStyle(PyxisColors.secondaryText)
            }
        }
    }
}

extension PrimaryPageHeader where Actions == EmptyView {
    init(title: String? = nil) {
        self.init(title: title) { EmptyView() }
    }
}
