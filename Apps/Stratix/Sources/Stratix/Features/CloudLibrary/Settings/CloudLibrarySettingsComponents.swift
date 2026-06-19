// CloudLibrarySettingsComponents.swift
// Defines cloud library settings components for the CloudLibrary / Settings surface.
//

import SwiftUI

private struct CloudLibrarySettingsPaneMoveEnvironmentKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: ((MoveCommandDirection) -> Void)? = nil
}

extension EnvironmentValues {
    var cloudLibrarySettingsPaneMoveHandler: ((MoveCommandDirection) -> Void)? {
        get { self[CloudLibrarySettingsPaneMoveEnvironmentKey.self] }
        set { self[CloudLibrarySettingsPaneMoveEnvironmentKey.self] = newValue }
    }
}

private extension View {
    func cloudLibrarySettingsPaneMoveCommand() -> some View {
        modifier(CloudLibrarySettingsPaneMoveCommandModifier())
    }
}

private struct CloudLibrarySettingsPaneMoveCommandModifier: ViewModifier {
    @Environment(\.cloudLibrarySettingsPaneMoveHandler) private var paneMoveHandler

    func body(content: Content) -> some View {
        content.onMoveCommand { direction in
            paneMoveHandler?(direction)
        }
    }
}

private struct CloudLibrarySettingsRowBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: StratixTheme.Radius.md)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.04), Color.white.opacity(0.025)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: StratixTheme.Radius.md)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

private extension View {
    func cloudLibrarySettingsRowBackground() -> some View {
        modifier(CloudLibrarySettingsRowBackground())
    }
}

/// Always-visible value chrome used inside settings controls and menu labels.
private struct CloudLibrarySettingsValueLabel: View {
    let text: String
    let isFocused: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Text(text)
            .font(StratixTypography.rounded(20, weight: .bold, dynamicTypeSize: dynamicTypeSize))
            .foregroundStyle(isFocused ? Color.black.opacity(0.82) : StratixTheme.Colors.textPrimary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                Capsule(style: .continuous)
                    .fill(isFocused ? StratixTheme.Colors.focusTint : Color.white.opacity(0.08))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(isFocused ? 0.18 : 0.12), lineWidth: 1)
            )
            .scaleEffect(isFocused ? 1.04 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isFocused)
            .gamePassDisableSystemFocusEffect()
    }
}

/// Focusable settings control that always shows its value horizontally inside the capsule.
private struct CloudLibrarySettingsValueControl: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            FocusAwareView { isFocused in
                CloudLibrarySettingsValueLabel(text: text, isFocused: isFocused)
            }
        }
        .buttonStyle(CloudLibraryTVButtonStyle())
        .gamePassDisableSystemFocusEffect()
        .cloudLibrarySettingsPaneMoveCommand()
    }
}

struct CloudLibraryPageSectionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        GlassCard(
            cornerRadius: StratixTheme.Radius.xl,
            fill: Color.white.opacity(0.04),
            stroke: Color.white.opacity(0.10),
            shadowOpacity: 0.14
        ) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(StratixTheme.Colors.textPrimary)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(StratixTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                content
            }
            .padding(22)
        }
    }
}

struct CloudLibrarySidebarButton: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            FocusAwareView { isFocused in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconBackground(isFocused: isFocused))
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: systemImage)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(isSelected ? Color.black.opacity(0.82) : StratixTheme.Colors.textSecondary)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(StratixTypography.rounded(19, weight: .bold, dynamicTypeSize: dynamicTypeSize))
                            .foregroundStyle(isSelected ? Color.black : StratixTheme.Colors.textPrimary)
                            .lineLimit(1)

                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(StratixTypography.rounded(15, weight: .medium, dynamicTypeSize: dynamicTypeSize))
                                .foregroundStyle(isSelected ? Color.black.opacity(0.72) : StratixTheme.Colors.textMuted)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 0)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.75))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: subtitle == nil ? 58 : 70, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(backgroundFill(isFocused: isFocused))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(borderColor(isFocused: isFocused), lineWidth: 1)
                )
                .gamePassFocusRing(isFocused: isFocused, cornerRadius: 18)
            }
        }
        .buttonStyle(CloudLibraryTVButtonStyle())
        .gamePassDisableSystemFocusEffect()
        .accessibilityValue(Text(isSelected ? "selected" : "not_selected"))
    }

    private func iconBackground(isFocused: Bool) -> Color {
        if isSelected {
            return Color.black.opacity(0.08)
        }
        return Color.white.opacity(isFocused ? 0.10 : 0.04)
    }

    private func backgroundFill(isFocused: Bool) -> Color {
        if isSelected {
            return StratixTheme.Colors.focusTint
        }
        return isFocused ? Color.white.opacity(0.10) : Color.white.opacity(0.05)
    }

    private func borderColor(isFocused: Bool) -> Color {
        if isSelected {
            return Color.white.opacity(0.08)
        }
        return Color.white.opacity(isFocused ? 0.16 : 0.10)
    }
}

struct CloudLibrarySettingsActionButton: View {
    let title: String
    let systemImage: String
    var destructive = false
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            FocusAwareView { isFocused in
                Label(title, systemImage: systemImage)
                    .font(StratixTypography.rounded(19, weight: .bold, dynamicTypeSize: dynamicTypeSize))
                    .foregroundStyle(foreground(isFocused: isFocused))
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .padding(.horizontal, 16)
                    .background(Capsule().fill(backgroundFill(isFocused: isFocused)))
                    .overlay(Capsule().stroke(borderColor(isFocused: isFocused), lineWidth: 1))
                    .gamePassFocusRing(isFocused: isFocused, cornerRadius: 24)
            }
        }
        .buttonStyle(CloudLibraryTVButtonStyle())
        .gamePassDisableSystemFocusEffect()
        .cloudLibrarySettingsPaneMoveCommand()
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }

    private func foreground(isFocused: Bool) -> Color {
        if isFocused {
            return .black
        }
        return destructive ? Color.red.opacity(0.92) : StratixTheme.Colors.textPrimary
    }

    private func backgroundFill(isFocused: Bool) -> Color {
        isFocused ? StratixTheme.Colors.focusTint : Color.white.opacity(0.06)
    }

    private func borderColor(isFocused: Bool) -> Color {
        Color.white.opacity(isFocused ? 0.16 : 0.10)
    }
}

struct CloudLibraryStatPill: View {
    let icon: String
    let text: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Label(text, systemImage: icon)
            .font(StratixTypography.rounded(16, weight: .bold, dynamicTypeSize: dynamicTypeSize))
            .foregroundStyle(StratixTheme.Colors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.white.opacity(0.05)))
            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

struct CloudLibraryStatLine: View {
    let icon: String
    let text: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(StratixTheme.Colors.focusTint)
                .frame(width: 20)

            Text(text)
                .font(StratixTypography.rounded(18, weight: .medium, dynamicTypeSize: dynamicTypeSize))
                .foregroundStyle(StratixTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct CloudLibraryToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(StratixTypography.rounded(19, weight: .bold, dynamicTypeSize: dynamicTypeSize))
                    .foregroundStyle(StratixTheme.Colors.textPrimary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(StratixTypography.rounded(16, weight: .medium, dynamicTypeSize: dynamicTypeSize))
                        .foregroundStyle(StratixTheme.Colors.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            CloudLibrarySettingsValueControl(text: isOn ? "On" : "Off") {
                isOn.toggle()
            }
            .accessibilityValue(Text(isOn ? "On" : "Off"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: 76)
        .cloudLibrarySettingsRowBackground()
        .cloudLibrarySettingsPaneMoveCommand()
    }
}

struct CloudLibrarySliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let formatter: (Double) -> String
    var step: Double? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var resolvedStep: Double {
        let fallback = (range.upperBound - range.lowerBound) / 20
        return max(step ?? fallback, 0.01)
    }

    private var normalized: Double {
        guard range.upperBound > range.lowerBound else { return 1 }
        return (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(StratixTypography.rounded(19, weight: .bold, dynamicTypeSize: dynamicTypeSize))
                    .foregroundStyle(StratixTheme.Colors.textPrimary)

                Spacer()

                Text(formatter(value))
                    .font(StratixTypography.rounded(15, weight: .bold, dynamicTypeSize: dynamicTypeSize))
                    .foregroundStyle(StratixTheme.Colors.focusTint)
                    .monospacedDigit()
            }

            HStack(spacing: 10) {
                CloudLibraryNudgeButton(systemImage: "minus") {
                    value = max(range.lowerBound, value - resolvedStep)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.10))
                        Capsule(style: .continuous)
                            .fill(StratixTheme.Colors.accent.opacity(0.85))
                            .frame(width: max(8, proxy.size.width * max(0, min(1, normalized))))
                    }
                }
                .frame(height: 8)
                .frame(maxWidth: .infinity)

                CloudLibraryNudgeButton(systemImage: "plus") {
                    value = min(range.upperBound, value + resolvedStep)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: 88)
        .cloudLibrarySettingsRowBackground()
        .cloudLibrarySettingsPaneMoveCommand()
    }
}

struct CloudLibraryPickerRow: View {
    let title: String
    @Binding var selection: String
    let options: [String]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(StratixTypography.rounded(19, weight: .bold, dynamicTypeSize: dynamicTypeSize))
                .foregroundStyle(StratixTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            CloudLibrarySettingsValueControl(text: selection, action: cycleSelection)
                .accessibilityValue(Text(selection))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: 76)
        .cloudLibrarySettingsRowBackground()
        .cloudLibrarySettingsPaneMoveCommand()
    }

    private func cycleSelection() {
        guard !options.isEmpty else { return }
        guard let currentIndex = options.firstIndex(of: selection) else {
            selection = options[0]
            return
        }
        selection = options[(currentIndex + 1) % options.count]
    }
}

struct CloudLibrarySettingTag: View {
    let text: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Text(text)
            .font(StratixTypography.rounded(13, weight: .bold, dynamicTypeSize: dynamicTypeSize))
            .foregroundStyle(StratixTheme.Colors.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.06)))
            .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
    }
}

private struct CloudLibraryNudgeButton: View {
    let systemImage: String
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            FocusAwareView { isFocused in
                Image(systemName: systemImage)
                    .font(StratixTypography.system(18, weight: .heavy, dynamicTypeSize: dynamicTypeSize))
                    .foregroundStyle(StratixTheme.Colors.textPrimary)
                    .frame(width: 52, height: 44)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(isFocused ? 0.16 : 0.11), lineWidth: 1))
                    .gamePassFocusRing(isFocused: isFocused, cornerRadius: 12)
            }
        }
        .buttonStyle(CloudLibraryTVButtonStyle())
        .gamePassDisableSystemFocusEffect()
        .cloudLibrarySettingsPaneMoveCommand()
    }
}