// StreamReconnectStatusBanner.swift
// Auto-reconnect status chip aligned with the stream launch Cancel row.
//

import SwiftUI

enum StreamStatusChipStyle {
    static let fill = Color.white.opacity(0.07)
    static let stroke = Color.white.opacity(0.12)
    static let strokeWidth: CGFloat = 1
    static let readableFill = Color.white.opacity(0.09)
    static let readableStroke = Color.white.opacity(0.14)
    static let emphasizedScrim = Color.black.opacity(0.62)
    static let emphasizedFill = Color.white.opacity(0.22)
    static let emphasizedStroke = Color.white.opacity(0.24)
}

extension View {
    func streamStatusCapsuleBackground() -> some View {
        background(
            Capsule(style: .continuous)
                .fill(StreamStatusChipStyle.fill)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(StreamStatusChipStyle.stroke, lineWidth: StreamStatusChipStyle.strokeWidth)
        )
    }

    func streamStatusPanelBackground(cornerRadius: CGFloat) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(StreamStatusChipStyle.fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(StreamStatusChipStyle.stroke, lineWidth: StreamStatusChipStyle.strokeWidth)
        )
    }

    func streamStatusReadablePanelBackground(cornerRadius: CGFloat) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(StreamStatusChipStyle.readableFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(StreamStatusChipStyle.readableStroke, lineWidth: StreamStatusChipStyle.strokeWidth)
        )
    }

    func streamStatusEmphasizedPanelBackground(cornerRadius: CGFloat) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.thinMaterial)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(StreamStatusChipStyle.emphasizedScrim)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(StreamStatusChipStyle.emphasizedFill)
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(StreamStatusChipStyle.emphasizedStroke, lineWidth: StreamStatusChipStyle.strokeWidth)
        )
    }
}

struct StreamReconnectStatusBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(StratixTheme.Colors.textPrimary)
            Text("Reconnecting…")
                .font(.callout.bold())
                .foregroundStyle(StratixTheme.Colors.textPrimary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .streamStatusCapsuleBackground()
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .accessibilityIdentifier("stream_reconnect_status_banner")
        .accessibilityLabel("Reconnecting")
    }
}