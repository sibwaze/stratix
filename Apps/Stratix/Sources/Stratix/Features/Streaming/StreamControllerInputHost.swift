// StreamControllerInputHost.swift
// Defines stream controller input host for the Features / Streaming surface.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(GameController)
import GameController
#endif

#if os(tvOS) && canImport(UIKit) && canImport(GameController)
/// Stream input host for tvOS.
/// Uses GCEventViewController to intercept controller menu/back presses before shell navigation sees them.
struct StreamControllerInputHost<Content: View>: UIViewControllerRepresentable {
    let content: Content
    let onOverlayToggle: (() -> Void)?

    init(onOverlayToggle: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.onOverlayToggle = onOverlayToggle
        self.content = content()
    }

    func makeUIViewController(context: Context) -> StreamControllerInputViewController<Content> {
        StreamControllerInputViewController(rootView: content, onOverlayToggle: onOverlayToggle)
    }

    func updateUIViewController(_ uiViewController: StreamControllerInputViewController<Content>, context: Context) {
        uiViewController.hostingController.rootView = content
        uiViewController.onOverlayToggle = onOverlayToggle
    }
}

final class StreamControllerInputViewController<Content: View>: GCEventViewController {
    let hostingController: UIHostingController<Content>
    var onOverlayToggle: (() -> Void)?

    init(rootView: Content, onOverlayToggle: (() -> Void)? = nil) {
        self.hostingController = UIHostingController(rootView: rootView)
        self.onOverlayToggle = onOverlayToggle
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.insetsLayoutMarginsFromSafeArea = false
        controllerUserInteractionEnabled = true

        hostingController.view.backgroundColor = .clear
        hostingController.view.insetsLayoutMarginsFromSafeArea = false

        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        _ = becomeFirstResponder()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        _ = becomeFirstResponder()
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        [hostingController]
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if shouldHandleOverlayPress(presses) { return }
        if shouldSwallowBackPress(presses) { return }
        super.pressesBegan(presses, with: event)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if shouldHandleOverlayPress(presses) {
            onOverlayToggle?()
            return
        }
        if shouldSwallowBackPress(presses) { return }
        super.pressesEnded(presses, with: event)
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if shouldHandleOverlayPress(presses) { return }
        if shouldSwallowBackPress(presses) { return }
        super.pressesCancelled(presses, with: event)
    }

    private func shouldSwallowBackPress(_ presses: Set<UIPress>) -> Bool {
        presses.contains { $0.type == .menu }
    }

    private func shouldHandleOverlayPress(_ presses: Set<UIPress>) -> Bool {
        presses.contains { $0.type == .playPause }
    }
}
#else
struct StreamControllerInputHost<Content: View>: View {
    let content: Content

    init(onOverlayToggle: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        _ = onOverlayToggle
        self.content = content()
    }

    var body: some View { content }
}
#endif
