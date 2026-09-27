import SwiftUI

struct EditorialTabBar: View {
    @Binding var selection: AppSection
    @Namespace private var underline

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppSection.allCases) { section in
                Button {
                    selection = section
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: symbol(for: section))
                            .font(.system(size: 22, weight: .ultraLight))
                            .frame(height: 26)
                        Text(section.title)
                            .font(PyxisTypography.editorialNav)
                            .tracking(1.6)
                            .lineLimit(1)
                        if selection == section {
                            Rectangle()
                                .fill(PyxisColors.text)
                                .frame(width: 28, height: 1)
                                .matchedGeometryEffect(id: "underline", in: underline)
                        } else {
                            Rectangle()
                                .fill(.clear)
                                .frame(width: 28, height: 1)
                        }
                    }
                    .foregroundStyle(selection == section ? PyxisColors.text : PyxisColors.inactiveText)
                    .shadow(color: selection == section ? .white.opacity(0.2) : .clear, radius: 9)
                    .frame(maxWidth: .infinity, minHeight: 66)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PyxisPressableStyle())
                .accessibilityLabel(section.title.capitalized)
                .accessibilityAddTraits(selection == section ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 9)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: selection)
        .background(PyxisColors.background.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(PyxisColors.hairline).frame(height: 1)
        }
    }

    private func symbol(for section: AppSection) -> String {
        switch section {
        case .closet: "hanger"
        case .fits: "tshirt"
        case .profile: "person"
        }
    }
}
