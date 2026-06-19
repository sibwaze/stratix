// StreamOverlayHUDStats.swift
// Defines stream overlay hud stats for the Streaming / Overlay surface.
//

import SwiftUI

extension StreamOverlayDetailsPanel {
    /// Renders the compact connection-stats card shown inside the details panel.
    var statsCard: some View {
        infoCard(title: "Connection", systemImage: "waveform.path.ecg") {
            VStack(alignment: .leading, spacing: 12) {
                statMetricsRow(
                    ("Frame Rate", overlayFormattedFrameRate),
                    ("Bitrate", overlayFormattedBitrate),
                    ("RTT", overlayFormattedRTT),
                    ("Packet Loss", overlayFormattedPacketLoss)
                )
                statMetricsRow(
                    ("Input", overlayInputResolutionText),
                    ("Output", overlayOutputResolutionText),
                    ("Upscaler", surfaceModel.activeRendererMode),
                    ("Render Delay", overlayFormattedRenderDelay)
                )
                if !overlayRendererDiagnostics.isEmpty {
                    statDynamicRow(overlayRendererDiagnostics)
                }
                if let rungSummary = surfaceModel.rendererRungSummaryText {
                    Text(rungSummary)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(StratixTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let lastError = surfaceModel.lastError {
                    Text("Last renderer error: \(lastError)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(StratixTheme.Colors.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// Renders a single metric tile inside the stats card.
    func statTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(StratixTheme.Colors.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(StratixTheme.Colors.textMuted)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    /// Renders one fixed row of stats tiles without per-render array allocation.
    func statMetricsRow(
        _ first: (String, String),
        _ second: (String, String),
        _ third: (String, String),
        _ fourth: (String, String)
    ) -> some View {
        HStack(spacing: 12) {
            statTile(label: first.0, value: first.1)
            statTile(label: second.0, value: second.1)
            statTile(label: third.0, value: third.1)
            statTile(label: fourth.0, value: fourth.1)
        }
    }

    /// Renders a variable-length stats row keyed by stable metric labels.
    func statDynamicRow(_ items: [(String, String)]) -> some View {
        HStack(spacing: 12) {
            ForEach(items, id: \.0) { item in
                statTile(label: item.0, value: item.1)
            }
        }
    }

    var overlayFormattedFrameRate: String {
        session.stats.framesPerSecond.map { String(format: "%.0f fps", $0) } ?? "—"
    }

    var overlayFormattedBitrate: String {
        session.stats.bitrateKbps.map { "\($0 / 1000) Mbps" } ?? "—"
    }

    var overlayFormattedRTT: String {
        session.stats.roundTripTimeMs.map { String(format: "%.0f ms", $0) } ?? "—"
    }

    var overlayFormattedPacketLoss: String {
        session.stats.packetsLost.map(String.init) ?? "—"
    }

    var overlayFormattedRenderDelay: String {
        surfaceModel.renderLatencyMs.map { String(format: "%.1f ms", $0) } ?? "—"
    }

    /// Formats the stream input resolution for the overlay stats card.
    var overlayInputResolutionText: String {
        if let width = surfaceModel.processingInputWidth,
           let height = surfaceModel.processingInputHeight {
            return "\(width)x\(height)"
        }
        if let width = session.stats.negotiatedWidth,
           let height = session.stats.negotiatedHeight {
            return "\(width)x\(height)"
        }
        if let width = session.stats.controlPreferredWidth,
           let height = session.stats.controlPreferredHeight {
            return "\(width)x\(height)"
        }
        return "—"
    }

    /// Formats the stream output resolution for the overlay stats card.
    var overlayOutputResolutionText: String {
        if let width = surfaceModel.processingOutputWidth,
           let height = surfaceModel.processingOutputHeight {
            return "\(width)x\(height)"
        }
        if let width = session.stats.messagePreferredWidth,
           let height = session.stats.messagePreferredHeight {
            return "\(width)x\(height)"
        }
        return overlayInputResolutionText
    }

    /// Collects extra renderer diagnostics when the runtime exposes them.
    var overlayRendererDiagnostics: [(String, String)] {
        var items: [(String, String)] = []
        if let status = surfaceModel.processingStatus {
            items.append(("Status", status))
        }
        if let inputRate = session.stats.inputFlushHz {
            items.append(("Input Rate", String(format: "%.0f Hz", inputRate)))
        }
        if let dropped = surfaceModel.framesDroppedByCoalescing {
            items.append(("Video Drops", "\(dropped)"))
        }
        if let failed = surfaceModel.framesFailed {
            items.append(("Failures", "\(failed)"))
        }
        if let framesLost = session.stats.framesLost {
            items.append(("Frame Loss", "\(framesLost)"))
        }
        return items
    }
}
