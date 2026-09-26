import SwiftUI

struct ProfileView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("pyxis.appearance") private var appearance = PyxisAppearance.system.rawValue
    @State private var selectedClosetID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: PyxisSpacing.lg) {
            PrimaryPageHeader(title: "PROFILE")

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("ORGANIZE")
                        .font(colorScheme == .dark ? PyxisTypography.editorialLabel : PyxisTypography.label)
                        .tracking(colorScheme == .dark ? 1.5 : 0)
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
                        .font(colorScheme == .dark ? PyxisTypography.editorialLabel : PyxisTypography.label)
                        .tracking(colorScheme == .dark ? 1.5 : 0)
                        .foregroundStyle(PyxisColors.secondaryText)
                        .padding(.top, PyxisSpacing.lg)
                        .padding(.bottom, PyxisSpacing.sm)

                    if colorScheme == .dark {
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
                                }
                                .buttonStyle(.plain)
                                .editorialGlow(cornerRadius: 8, strength: appearance == option.rawValue ? 1.1 : 0.5)
                                .accessibilityAddTraits(appearance == option.rawValue ? .isSelected : [])
                            }
                        }
                        .accessibilityLabel("App appearance")
                    } else {
                        Picker("APPEARANCE", selection: $appearance) {
                            ForEach(PyxisAppearance.allCases) { option in
                                Text(option.title).tag(option.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("App appearance")
                    }
                }
                .padding(.top, PyxisSpacing.md)
            }
        }
        .padding(.horizontal, colorScheme == .dark ? 20 : PyxisSpacing.md)
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
                .font(colorScheme == .dark ? PyxisTypography.editorialBody : PyxisTypography.body)
                .tracking(colorScheme == .dark ? 1.2 : 0)

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
