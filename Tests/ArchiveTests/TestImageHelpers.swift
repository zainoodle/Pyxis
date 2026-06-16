import UIKit
import XCTest

func makeTestImage(color: UIColor = .white, size: CGSize = CGSize(width: 12, height: 12)) -> UIImage {
    UIGraphicsImageRenderer(size: size).image { context in
        color.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
}

extension UIImage {
    func pngDataForTests() -> Data? {
        pngData()
    }

    func jpegDataForTests() -> Data? {
        jpegData(compressionQuality: 0.9)
    }
}
