import SwiftUI
import UIKit

extension View {
    func dismissKeyboardOnBackgroundTap() -> some View {
        background(KeyboardDismissGestureInstaller())
    }
}

private struct KeyboardDismissGestureInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = KeyboardDismissGestureView()
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            !touch.viewContainsTextInput
        }
    }
}

private final class KeyboardDismissGestureView: UIView {
    weak var delegate: UIGestureRecognizerDelegate?
    private weak var installedWindow: UIWindow?
    private weak var tapGesture: UITapGestureRecognizer?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        installGestureIfNeeded()
    }

    private func installGestureIfNeeded() {
        guard let window else { return }
        guard installedWindow !== window else { return }

        if let tapGesture, let installedWindow {
            installedWindow.removeGestureRecognizer(tapGesture)
        }

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = delegate
        window.addGestureRecognizer(tapGesture)

        installedWindow = window
        self.tapGesture = tapGesture
    }

    @objc private func dismissKeyboard() {
        window?.endEditing(true)
    }
}

private extension UITouch {
    var viewContainsTextInput: Bool {
        var currentView = view
        while let candidate = currentView {
            if candidate is UITextField || candidate is UITextView {
                return true
            }
            currentView = candidate.superview
        }
        return false
    }
}
