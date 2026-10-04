import SwiftUI
import UIKit

/// Native failure ordering makes a completed pan ineligible to also open a garment.
/// A touch that stops deceleration only stops the rack; a fresh tap can open immediately.
struct RackTapTarget: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> TargetView {
        let view = TargetView()
        view.isUserInteractionEnabled = false
        view.action = action
        return view
    }

    func updateUIView(_ view: TargetView, context: Context) {
        view.action = action
        view.installIfNeeded()
    }

    static func dismantleUIView(_ view: TargetView, coordinator: ()) { view.uninstall() }

    final class TargetView: UIView, UIGestureRecognizerDelegate {
        var action: (() -> Void)?
        private weak var scrollView: UIScrollView?
        private var tap: UITapGestureRecognizer?

        override func didMoveToWindow() { super.didMoveToWindow(); installIfNeeded() }
        override func layoutSubviews() { super.layoutSubviews(); installIfNeeded() }

        func installIfNeeded() {
            guard window != nil else { return }
            var ancestor = superview
            while let view = ancestor {
                if let scroll = view as? UIScrollView {
                    guard scroll !== scrollView else { return }
                    uninstall()
                    let tap = StationaryTapRecognizer(target: self, action: #selector(activate))
                    tap.delegate = self
                    tap.cancelsTouchesInView = false
                    tap.require(toFail: scroll.panGestureRecognizer)
                    scroll.addGestureRecognizer(tap)
                    self.tap = tap
                    scrollView = scroll
                    return
                }
                ancestor = view.superview
            }
        }

        func uninstall() {
            if let tap { scrollView?.removeGestureRecognizer(tap) }
            tap = nil
            scrollView = nil
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let scrollView, !scrollView.isDragging, !scrollView.isDecelerating else { return false }
            return bounds.contains(touch.location(in: self))
        }

        @objc private func activate(_ recognizer: UITapGestureRecognizer) {
            if recognizer.state == .ended { action?() }
        }
    }
}

/// Check the final location too: short input sequences can coalesce intermediate moves.
private final class StationaryTapRecognizer: UITapGestureRecognizer {
    private var origin: CGPoint?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        origin = touches.first?.location(in: view?.window)
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard staysWithinTap(touches) else { state = .failed; return }
        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard staysWithinTap(touches) else { state = .failed; return }
        super.touchesEnded(touches, with: event)
    }

    override func reset() { super.reset(); origin = nil }

    private func staysWithinTap(_ touches: Set<UITouch>) -> Bool {
        guard let origin, let point = touches.first?.location(in: view?.window) else { return false }
        return hypot(point.x - origin.x, point.y - origin.y) < 10
    }
}
