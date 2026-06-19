// CloudLibraryLibraryScreenControls.swift
// Defines cloud library library screen controls for the CloudLibrary / Library surface.
//

import SwiftUI

struct LibraryFilterChipButton: View {
    let chip: ChipViewState
    let onSelect: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: onSelect) {
            FocusAwareView { isFocused in
                HStack(spacing: 8) {
                    if let image = chip.systemImage {
                        Image(systemName: image)
                    }
                    Text(chip.label)
                        .lineLimit(1)
                }
                .font(StratixTypography.rounded(22, weight: .bold, dynamicTypeSize: dynamicTypeSize))
                .foregroundStyle(chip.isSelected || chip.style == .accent ? Color.black : StratixTheme.Colors.textPrimary)
                .padding(.horizontal, StratixTheme.Library.chipHorizontalPadding + 8)
                .padding(.vertical, StratixTheme.Library.chipVerticalPadding + 4)
                .background(
                    Capsule(style: .continuous).fill(
                        chip.isSelected || chip.style == .accent
                        ? StratixTheme.Colors.focusTint
                        : Color.white.opacity(isFocused ? 0.14 : 0.07)
                    )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            chip.isSelected || chip.style == .accent
                                ? Color.clear
                                : Color.white.opacity(isFocused ? 0.55 : 0.12),
                            lineWidth: isFocused ? 2 : 1
                        )
                )
            }
        }
        .buttonStyle(CloudLibraryTVButtonStyle())
        .gamePassDisableSystemFocusEffect()
    }
}

struct LibraryTabButton: View {
    let title: String
    var systemImage: String? = nil
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: onSelect) {
            FocusAwareView { isFocused in
                HStack(spacing: 10) {
                    Text(title)
                    if let systemImage {
                        Image(systemName: systemImage)
                    }
                }
                .font(
                    StratixTypography.rounded(
                        50,
                        weight: isSelected || isFocused ? .bold : .medium,
                        dynamicTypeSize: dynamicTypeSize
                    )
                )
                .foregroundStyle(
                    isSelected
                        ? StratixTheme.Colors.focusTint.opacity(0.9)
                        : Color.white.opacity(isFocused ? 0.96 : 0.78)
                )
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .animation(.easeOut(duration: 0.14), value: isFocused)
            }
        }
        .buttonStyle(CloudLibraryTVButtonStyle())
        .gamePassDisableSystemFocusEffect()
    }
}

struct LibraryInlineSearchControl: View {
    let isActive: Bool
    let onActivate: () -> Void
    var focusedTarget: FocusState<CloudLibraryLibraryScreen.LibraryFocusTarget?>.Binding

    var body: some View {
        LibraryTabButton(
            title: "Search",
            systemImage: "magnifyingglass",
            isSelected: isActive,
            onSelect: onActivate
        )
        .animation(nil, value: isActive)
        .focused(focusedTarget, equals: .searchField)
        .accessibilityIdentifier(isActive ? "route_search_root" : "library_tab_search")
    }
}

struct SortButton: View {
    let title: String
    var icon: String = "arrow.up.arrow.down"
    let onSelect: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: onSelect) {
            FocusAwareView { isFocused in
                HStack(spacing: 10) {
                    Image(systemName: icon)
                    Text(title)
                        .lineLimit(1)
                }
                .font(StratixTypography.rounded(22, weight: .bold, dynamicTypeSize: dynamicTypeSize))
                .foregroundStyle(StratixTheme.Colors.textPrimary)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(isFocused ? 0.14 : 0.07))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .gamePassFocusRing(isFocused: isFocused, cornerRadius: 14)
            }
        }
        .buttonStyle(CloudLibraryTVButtonStyle())
        .gamePassDisableSystemFocusEffect()
    }
}
