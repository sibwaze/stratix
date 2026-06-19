// CloudLibrarySearchFieldLeadingAlignment.swift
// Opens the tvOS searchable letter keyboard when library search is active.
//

import SwiftUI
import UIKit

extension Notification.Name {
    static let librarySearchRequestKeyboard = Notification.Name("CloudLibraryLibrarySearchRequestKeyboard")
    static let librarySearchResignKeyboard = Notification.Name("CloudLibraryLibrarySearchResignKeyboard")
}

struct CloudLibrarySearchFieldLeadingAlignment: UIViewRepresentable {
    var activatesKeyboard: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SearchFocusHostView {
        let view = SearchFocusHostView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.onWindowChange = { [weak coordinator = context.coordinator] window in
            guard let coordinator, let window else { return }
            Task { @MainActor in
                coordinator.handleWindowChange(window)
            }
        }
        return view
    }

    func updateUIView(_ uiView: SearchFocusHostView, context: Context) {
        context.coordinator.activatesKeyboard = activatesKeyboard
        if let window = uiView.window {
            context.coordinator.handleWindowChange(window)
        }
    }

    static func dismantleUIView(_ uiView: SearchFocusHostView, coordinator: Coordinator) {
        uiView.onWindowChange = nil
        coordinator.stop()
    }

    @MainActor
    final class Coordinator {
        var activatesKeyboard = false
        private var keyboardSuppressed = false
        private weak var focusedSearchBar: UISearchBar?
        private var focusTask: Task<Void, Never>?
        private var keyboardObservers: [NSObjectProtocol] = []

        init() {
            keyboardObservers = [
                NotificationCenter.default.addObserver(
                    forName: .librarySearchRequestKeyboard,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor in
                        self?.keyboardSuppressed = false
                        self?.requestKeyboardFocus()
                    }
                },
                NotificationCenter.default.addObserver(
                    forName: .librarySearchResignKeyboard,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor in
                        self?.keyboardSuppressed = true
                        self?.resignKeyboardFocus()
                    }
                }
            ]
        }

        func handleWindowChange(_ window: UIWindow) {
            if activatesKeyboard, !keyboardSuppressed {
                requestKeyboardFocus(in: window)
            } else if !activatesKeyboard {
                keyboardSuppressed = false
                resignKeyboardFocus()
            }
        }

        func stop() {
            focusTask?.cancel()
            focusTask = nil
            keyboardSuppressed = false
            resignKeyboardFocus()
            keyboardObservers.forEach { NotificationCenter.default.removeObserver($0) }
            keyboardObservers.removeAll()
        }

        func requestKeyboardFocus() {
            guard let window = focusedSearchBar?.window ?? keyWindow() else { return }
            requestKeyboardFocus(in: window)
        }

        private func requestKeyboardFocus(in window: UIWindow) {
            focusTask?.cancel()
            focusTask = Task { @MainActor in
                for _ in 0..<24 {
                    try? await Task.sleep(for: .milliseconds(50))
                    guard !Task.isCancelled, activatesKeyboard else { return }
                    guard let rootView = window.rootViewController?.view else { continue }
                    let searchBars = Self.findSearchBars(in: rootView)
                    guard let searchBar = Self.primarySearchBar(in: searchBars, window: window) else { continue }

                    Self.hideDuplicateSearchBars(searchBars, in: window, keeping: searchBar)
                    focusedSearchBar = searchBar
                    if searchBar.becomeFirstResponder() {
                        return
                    }
                }
            }
        }

        private func resignKeyboardFocus() {
            focusTask?.cancel()
            focusTask = nil
            focusedSearchBar?.resignFirstResponder()
            focusedSearchBar = nil
        }

        private func keyWindow() -> UIWindow? {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)
        }

        private static func primarySearchBar(in searchBars: [UISearchBar], window: UIWindow) -> UISearchBar? {
            searchBars.min {
                $0.convert($0.bounds, to: window).minX < $1.convert($1.bounds, to: window).minX
            } ?? searchBars.first
        }

        private static func hideDuplicateSearchBars(
            _ searchBars: [UISearchBar],
            in window: UIWindow,
            keeping primary: UISearchBar
        ) {
            guard searchBars.count > 1 else { return }

            for duplicate in searchBars where duplicate !== primary {
                let primaryMinX = primary.convert(primary.bounds, to: window).minX
                let duplicateMinX = duplicate.convert(duplicate.bounds, to: window).minX
                guard duplicateMinX > primaryMinX + 0.5 else { continue }
                duplicate.isHidden = true
                duplicate.alpha = 0
                duplicate.superview?.isHidden = true
            }
        }

        private static func findSearchBars(in view: UIView) -> [UISearchBar] {
            var bars: [UISearchBar] = []
            if let searchBar = view as? UISearchBar {
                bars.append(searchBar)
            }
            for subview in view.subviews {
                bars.append(contentsOf: findSearchBars(in: subview))
            }
            return bars
        }
    }
}

final class SearchFocusHostView: UIView {
    var onWindowChange: ((UIWindow?) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        onWindowChange?(window)
    }
}