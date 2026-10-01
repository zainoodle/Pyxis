import SwiftUI

struct ProfileView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("pyxis.appearance") private var appearance = PyxisAppearance.system.rawValue
    @State private var selectedClosetID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PrimaryPageHeader(title: "Profile")

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("WARDROBE")
                        .font(colorScheme == .dark ? PyxisTypography.editorialLabel : PyxisTypography.label)
                        .tracking(colorScheme == .dark ? 1.5 : 0)
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
                                .accessibilityLabel(option.title.capitalized)
                                .editorialGlow(cornerRadius: 8, strength: appearance == option.rawValue ? 1.1 : 0.5)
                                .accessibilityAddTraits(appearance == option.rawValue ? .isSelected : [])
                            }
                        }
                        .accessibilityElement(children: .contain)
                    } else {
                        Picker("APPEARANCE", selection: $appearance) {
                            ForEach(PyxisAppearance.allCases) { option in
                                Text(option.title).tag(option.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityElement(children: .contain)
                    }
                    Text("PYXIS")
                        .font(PyxisTypography.editorialMicro)
                        .tracking(3)
                        .foregroundStyle(PyxisColors.inactiveText)
                        .padding(.top, 40)
                        .accessibilityHidden(true)
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
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .light))
                .accessibilityHidden(true)
                .frame(width: 24)
                .foregroundStyle(PyxisColors.secondaryText)
            Text(title)
                .font(PyxisTypography.body)
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
