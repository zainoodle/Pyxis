import SwiftUI

struct ProfileView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("pyxis.appearance") private var appearance = PyxisAppearance.system.rawValue
    @State private var selectedClosetID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PrimaryPageHeader(title: "Profile")

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("WARDROBE")
                        .font(PyxisTypography.editorialLabel)
                        .tracking(1)
                        .foregroundStyle(PyxisColors.secondaryText)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.bottom, PyxisSpacing.sm)

                    NavigationLink {
                        ClosetManagementView(selectedClosetID: $selectedClosetID)
                    } label: {
                        settingsRow("Closets", systemImage: "folder")
                    }

                    Rectangle()
                        .fill(PyxisColors.hairline.opacity(0.35))
                        .frame(height: 1)

                    NavigationLink {
                        SizingProfileView()
                    } label: {
                        settingsRow("Measurements", systemImage: "ruler")
                    }

                    Text("APPEARANCE")
                        .font(PyxisTypography.editorialLabel)
                        .tracking(1)
                        .foregroundStyle(PyxisColors.secondaryText)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, PyxisSpacing.lg)
                        .padding(.bottom, PyxisSpacing.sm)

                    appearanceLayout {
                        ForEach(PyxisAppearance.allCases) { option in
                            Button { appearance = option.rawValue } label: {
                                Text(option.title.capitalized)
                                    .font(PyxisTypography.control)
                                    .foregroundStyle(appearance == option.rawValue ? PyxisColors.background : PyxisColors.text)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(appearance == option.rawValue ? PyxisColors.text : PyxisColors.field,
                                                in: RoundedRectangle(cornerRadius: 8))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(PyxisColors.controlBorder, lineWidth: 0.5)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("profile.appearance.\(option.rawValue)")
                            .accessibilityAddTraits(appearance == option.rawValue ? .isSelected : [])
                        }
                    }
                    .accessibilityElement(children: .contain)
                }
                .padding(.top, 24)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, PyxisSpacing.md)
        .editorialCanvas()
        .navigationBarHidden(true)
    }

    private var appearanceLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: PyxisSpacing.sm))
            : AnyLayout(HStackLayout(spacing: PyxisSpacing.sm))
    }

    private func settingsRow(_ title: String, systemImage: String) -> some View {
        HStack(spacing: PyxisSpacing.md) {
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .light))
                    .accessibilityHidden(true)
                    .frame(width: 24)
                    .foregroundStyle(PyxisColors.secondaryText)
            }
            Text(title)
                .font(PyxisTypography.control)
                .tracking(0)
                .multilineTextAlignment(.leading)

            Spacer(minLength: PyxisSpacing.sm)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(PyxisColors.inactiveText)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 60)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }
}
