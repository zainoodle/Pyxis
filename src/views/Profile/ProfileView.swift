import SwiftUI

struct ProfileView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("pyxis.appearance") private var appearance = PyxisAppearance.system.rawValue
    @State private var selectedClosetID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.lg) {
            PrimaryPageHeader(title: "PROFILE")

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("ORGANIZE")
                        .font(PyxisTypography.editorialLabel)
                        .tracking(1.5)
                        .foregroundStyle(PyxisColors.secondaryText)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.bottom, PyxisSpacing.sm)

                    NavigationLink {
                        ClosetManagementView(selectedClosetID: $selectedClosetID)
                    } label: {
                        settingsRow("MANAGE CLOSETS", systemImage: "folder")
                    }

                    Rectangle()
                        .fill(PyxisColors.hairline.opacity(0.35))
                        .frame(height: 1)

                    NavigationLink {
                        SizingProfileView()
                    } label: {
                        settingsRow("FIT PASSPORT", systemImage: "ruler")
                    }

                    Text("APPEARANCE")
                        .font(PyxisTypography.editorialLabel)
                        .tracking(1.5)
                        .foregroundStyle(PyxisColors.secondaryText)
                        .padding(.top, PyxisSpacing.lg)
                        .padding(.bottom, PyxisSpacing.sm)

                    appearanceLayout {
                        ForEach(PyxisAppearance.allCases) { option in
                            Button { appearance = option.rawValue } label: {
                                Text(option.title)
                                    .font(PyxisTypography.editorialLabel)
                                    .tracking(1.5)
                                    .foregroundStyle(appearance == option.rawValue ? PyxisColors.background : PyxisColors.secondaryText)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(appearance == option.rawValue ? PyxisColors.text : PyxisColors.field,
                                                in: RoundedRectangle(cornerRadius: 8))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(PyxisColors.hairline, lineWidth: 1)
                                    }
                                    .animation(.easeOut(duration: 0.18), value: appearance)
                            }
                            .buttonStyle(PyxisPressableStyle())
                            .editorialGlow(cornerRadius: 8, strength: appearance == option.rawValue ? 1.1 : 0.5)
                            .accessibilityAddTraits(appearance == option.rawValue ? .isSelected : [])
                        }
                    }
                    .accessibilityLabel("App appearance")
                }
                .padding(.top, PyxisSpacing.md)
            }
        }
        .padding(.horizontal, 20)
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
            Image(systemName: systemImage)
                .frame(width: 24)
                .foregroundStyle(PyxisColors.secondaryText)
            Text(title)
                .font(PyxisTypography.editorialBody)
                .tracking(1.2)

            Spacer(minLength: PyxisSpacing.sm)

            Image(systemName: "chevron.right")
                .font(PyxisTypography.label)
                .foregroundStyle(PyxisColors.inactiveText)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 60)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }
}
