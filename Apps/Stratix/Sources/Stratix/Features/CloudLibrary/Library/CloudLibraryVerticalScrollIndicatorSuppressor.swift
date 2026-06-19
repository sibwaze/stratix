// CloudLibraryVerticalScrollIndicatorSuppressor.swift
// Hides the system vertical scroll indicator so a custom index can occupy that edge.
//

import SwiftUI
import UIKit

struct CloudLibraryVerticalScrollIndicatorSuppressor: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> IndicatorHostView {
        let view = IndicatorHostView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.onHierarchyChange = { [weak coordinator = context.coordinator, weak view] in
            guard let view, let coordinator else { return }
            Task { @MainActor in
                coordinator.refresh(from: view)
            }
        }
        return view
    }

    func updateUIView(_ uiView: IndicatorHostView, context: Context) {
        context.coordinator.refresh(from: uiView)
    }

    static func dismantleUIView(_ uiView: IndicatorHostView, coordinator: Coordinator) {
        uiView.onHierarchyChange = nil
        coordinator.stop()
    }

    @MainActor
    final class Coordinator {
        private weak var scrollView: UIScrollView?
        private var displayLink: CADisplayLink?
        private var displayLinkTarget: ScrollIndicatorDisplayLinkTarget?

        func refresh(from view: UIView) {
            guard let scrollView = findScrollView(startingFrom: view) else { return }
            guard scrollView !== self.scrollView else {
                suppressIndicators(in: scrollView)
                return
            }
            stop()
            self.scrollView = scrollView
            suppressIndicators(in: scrollView)
            startDisplayLink()
        }

        func stop() {
            displayLink?.invalidate()
            displayLink = nil
            displayLinkTarget = nil
            scrollView = nil
        }

        private func startDisplayLink() {
            let target = ScrollIndicatorDisplayLinkTarget()
            target.onTick = { [weak self] in
                self?.handleDisplayLinkTick()
            }
            displayLinkTarget = target
            let link = CADisplayLink(target: target, selector: #selector(ScrollIndicatorDisplayLinkTarget.tick))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        private func handleDisplayLinkTick() {
            guard let scrollView else {
                stop()
                return
            }
            suppressIndicators(in: scrollView)
        }

        private func findScrollView(startingFrom view: UIView) -> UIScrollView? {
            var ancestor: UIView? = view
            while let current = ancestor {
                if let scrollView = current as? UIScrollView {
                    return scrollView
                }
                ancestor = current.superview
            }
            return nil
        }

        private func suppressIndicators(in scrollView: UIScrollView) {
            scrollView.showsVerticalScrollIndicator = false
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.indicatorStyle = .default
            if #available(tvOS 13.0, *) {
                scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }

            hideIndicatorViews(in: scrollView)
            for subview in scrollView.subviews {
                hideIndicatorViews(in: subview)
            }
        }

        private func hideIndicatorViews(in view: UIView) {
            let typeName = String(describing: type(of: view))
            let isIndicatorType =
                typeName.localizedCaseInsensitiveContains("indicator")
                || typeName.localizedCaseInsensitiveContains("scrollBar")
                || typeName.localizedCaseInsensitiveContains("scrollIndicator")

            if isIndicatorType {
                view.isHidden = true
                view.alpha = 0
                view.isUserInteractionEnabled = false
            }

            for subview in view.subviews {
                hideIndicatorViews(in: subview)
            }
        }
    }
}

private final class ScrollIndicatorDisplayLinkTarget: NSObject {
    var onTick: (() -> Void)?

    @objc func tick() {
        onTick?()
    }
}

final class IndicatorHostView: UIView {
    var onHierarchyChange: (() -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        onHierarchyChange?()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onHierarchyChange?()
    }
}