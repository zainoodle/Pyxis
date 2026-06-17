import SwiftData
import SwiftUI

@main
struct PyxisApp: App {
    private enum StartupState {
        case ready(ModelContainer)
        case failed
    }

    private let startupState: StartupState

    init() {
        do {
            startupState = .ready(try SwiftDataContainer.makeAppContainer())
        } catch {
            startupState = .failed
        }
    }

    var body: some Scene {
        WindowGroup {
            switch startupState {
            case .ready(let modelContainer):
                ClosetGridView()
                    .modelContainer(modelContainer)
                    .preferredColorScheme(.light)
            case .failed:
                StartupFailureView()
                    .preferredColorScheme(.light)
            }
        }
    }
}

private struct StartupFailureView: View {
    var body: some View {
        VStack(spacing: PyxisSpacing.md) {
            Text("PYXIS COULD NOT START")
                .font(PyxisTypography.title)
                .foregroundStyle(PyxisColors.text)

            Text("LOCAL CLOSET STORAGE COULD NOT BE OPENED")
                .font(PyxisTypography.body)
                .foregroundStyle(PyxisColors.secondaryText)
                .multilineTextAlignment(.center)

            Text("PLEASE RESTART THE APP AND TRY AGAIN")
                .font(PyxisTypography.label)
                .foregroundStyle(PyxisColors.inactiveText)
                .multilineTextAlignment(.center)
                .padding(.top, PyxisSpacing.sm)
        }
        .padding(PyxisSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PyxisColors.background)
    }
}
