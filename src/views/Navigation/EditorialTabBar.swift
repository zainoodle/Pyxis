import SwiftUI

struct EditorialTabBar: View {
    @Binding var selection: AppSection

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
                        Rectangle()
                            .fill(selection == section ? PyxisColors.text : .clear)
                            .frame(width: 28, height: 1)
                    }
                    .foregroundStyle(selection == section ? PyxisColors.text : PyxisColors.inactiveText)
                    .frame(maxWidth: .infinity, minHeight: 66)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.title.capitalized)
                .accessibilityAddTraits(selection == section ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 9)
        .background(PyxisColors.background.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(PyxisColors.hairline).frame(height: 1)
        }
    }

    private func symbol(for section: AppSection) -> String {
        switch section {
        case .closet: "hanger"
        case .build: "plus"
        case .fits: "tshirt"
        case .profile: "person"
        }
    }
}
