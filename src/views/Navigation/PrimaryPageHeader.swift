import SwiftUI

/// A stable anchor for each top-level tab. The tab bar identifies the current
/// destination, while this header keeps the brand and page actions in one place.
struct PrimaryPageHeader<Actions: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let actions: Actions

    init(@ViewBuilder actions: () -> Actions) {
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
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.top, PyxisSpacing.lg)
    }

    private var brand: some View {
        Text("PYXIS")
            .font(PyxisTypography.title)
            .foregroundStyle(PyxisColors.text)
            .lineLimit(1)
            .accessibilityAddTraits(.isHeader)
    }
}

extension PrimaryPageHeader where Actions == EmptyView {
    init() {
        self.init { EmptyView() }
    }
}
