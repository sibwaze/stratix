// CloudLibraryLibraryShoulderTabSwitch.swift
// Maps gamepad LB/RB to library header tab cycling.
//

import GameController
import SwiftUI
import UIKit

struct CloudLibraryLibraryShoulderTabSwitch: UIViewRepresentable {
    var isEnabled: Bool
    var onShoulderLeft: () -> Void
    var onShoulderRight: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isHidden = true
        view.isUserInteractionEnabled = false
        context.coordinator.start()
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onShoulderLeft = onShoulderLeft
        context.coordinator.onShoulderRight = onShoulderRight
        if isEnabled {
            context.coordinator.resumePolling()
        } else {
            context.coordinator.pausePolling()
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator: NSObject, @unchecked Sendable {
        var isEnabled = false
        var onShoulderLeft: (() -> Void)?
        var onShoulderRight: (() -> Void)?

        private var observers: [NSObjectProtocol] = []
        private var displayLink: CADisplayLink?
        private var displayLinkTarget: DisplayLinkTarget?
        private var previousLeftPressed = false
        private var previousRightPressed = false
        private var isObserving = false

        func start() {
            guard !isObserving else { return }
            isObserving = true

            observers = [
                NotificationCenter.default.addObserver(
                    forName: .GCControllerDidConnect,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.resumePolling()
                    }
                },
                NotificationCenter.default.addObserver(
                    forName: .GCControllerDidDisconnect,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.resetShoulderEdgeState()
                    }
                },
                NotificationCenter.default.addObserver(
                    forName: .librarySearchRequestKeyboard,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.resumePolling()
                    }
                },
                NotificationCenter.default.addObserver(
                    forName: .librarySearchResignKeyboard,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.syncShoulderEdgeStateToHardware()
                    }
                }
            ]

            resumePolling()
        }

        func stop() {
            guard isObserving else { return }
            isObserving = false
            pausePolling()
            observers.forEach { NotificationCenter.default.removeObserver($0) }
            observers.removeAll()
            resetShoulderEdgeState()
        }

        func resumePolling() {
            guard isEnabled else { return }
            guard displayLink == nil else { return }

            let target = DisplayLinkTarget()
            target.onTick = { [weak self] in
                self?.pollShoulderButtons()
            }
            displayLinkTarget = target

            let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.tick))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        func pausePolling() {
            displayLink?.invalidate()
            displayLink = nil
            displayLinkTarget = nil
        }

        private func pollShoulderButtons() {
            guard isEnabled else { return }

            let gamepad = GCController.controllers()
                .compactMap(\.extendedGamepad)
                .first

            guard let gamepad else {
                resetShoulderEdgeState()
                return
            }

            handleLeftShoulder(gamepad.leftShoulder.isPressed)
            handleRightShoulder(gamepad.rightShoulder.isPressed)
        }

        private func handleLeftShoulder(_ pressed: Bool) {
            guard isEnabled else {
                previousLeftPressed = pressed
                return
            }
            if pressed, !previousLeftPressed {
                invokeShoulderAction(onShoulderLeft)
            }
            previousLeftPressed = pressed
        }

        private func handleRightShoulder(_ pressed: Bool) {
            guard isEnabled else {
                previousRightPressed = pressed
                return
            }
            if pressed, !previousRightPressed {
                invokeShoulderAction(onShoulderRight)
            }
            previousRightPressed = pressed
        }

        private func resetShoulderEdgeState() {
            previousLeftPressed = false
            previousRightPressed = false
        }

        /// Keeps edge detection aligned with the physical buttons so a held shoulder
        /// cannot fire a second tab shift when search resigns mid-press.
        private func syncShoulderEdgeStateToHardware() {
            let gamepad = GCController.controllers()
                .compactMap(\.extendedGamepad)
                .first

            guard let gamepad else {
                resetShoulderEdgeState()
                return
            }

            previousLeftPressed = gamepad.leftShoulder.isPressed
            previousRightPressed = gamepad.rightShoulder.isPressed
        }

        /// CADisplayLink ticks on the main run loop, so shoulder actions can run inline.
        private func invokeShoulderAction(_ action: (() -> Void)?) {
            action?()
        }
    }
}

private final class DisplayLinkTarget: NSObject {
    var onTick: (() -> Void)?

    @objc func tick() {
        onTick?()
    }
}