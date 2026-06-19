// StreamPresentationFocusCapture.swift
// Keeps tvOS focus on the stream surface so shell navigation does not receive Menu/Back.
//

import SwiftUI

struct StreamPresentationFocusCapture: ViewModifier {
    @FocusState private var capturesFocus: Bool

    func body(content: Content) -> some View {
        content
            .focusable()
            .focused($capturesFocus)
            .onAppear {
                capturesFocus = true
            }
    }
}

extension View {
    func streamPresentationFocusCapture() -> some View {
        modifier(StreamPresentationFocusCapture())
    }
}