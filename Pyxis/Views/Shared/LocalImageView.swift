import SwiftUI
import UIKit

struct LocalImageView: View {
    let url: URL?
    var contentMode: ContentMode = .fit

    var body: some View {
        Group {
            if let url, let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .overlay {
                        Text("NO IMAGE")
                            .font(PyxisTypography.label)
                            .foregroundStyle(PyxisColors.inactiveText)
                    }
            }
        }
        .accessibilityLabel("Clothing image")
    }
}
