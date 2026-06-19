// SideRailActionList.swift
// Defines side rail action list for the Shared / Components surface.
//

import SwiftUI

extension SideRailNavigationView {
    /// Trailing action stack shown below the main nav rows once the rail is expanded.
    var actionListView: some View {
        VStack(alignment: .leading, spacing: StratixTheme.SideRail.rowSpacing) {
            ForEach(trailingActions) { action in
                SideRailActionButton(
                    action: action,
                    isSelected: action.id == "settings" && activeUtilityRoute == .settings,
                    isExpanded: isRailExpanded,
                    isFocusable: isRailExpanded || (action.id == "settings" && activeUtilityRoute == .settings),
                    onSelect: {
                        onSelectAction(action.id)
                        collapseRail()
                    },
                    onMoveToContent: moveFocusToContent
                )
                .focused($focusedTarget, equals: .action(action.id))
                .onMoveCommand { direction in
                    guard isRailExpanded else { return }
                    if direction == .up, action.id == firstActionID, let lastExpandedNavID {
                        focusedTarget = .nav(lastExpandedNavID)
                        return
                    }
                    if direction == .down, action.id == lastActionID {
                        focusedTarget = .action(action.id)
                    }
                }
            }
        }
    }
}

/// Focus-aware trailing action row used for settings and any future shell-level rail actions.
private struct SideRailActionButton: View {
    let action: SideRailActionViewState
    let isSelected: Bool
    let isExpanded: Bool
    let isFocusable: Bool
    let onSelect: () -> Void
    var onMoveToContent: (() -> Void)? = nil

    var body: some View {
        Button(action: onSelect) {
            FocusAwareView { isFocused in
                let iconSize = isSelected ? StratixTheme.SideRail.selectedIconSize : StratixTheme.SideRail.iconSize
                Image(systemName: action.systemImage)
                    .font(.system(size: iconSize, weight: isSelected || isFocused ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected
                            ? Color.white.opacity(0.94)
                            : Color.white.opacity(isFocused ? 0.97 : 0.76)
                    )
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                isSelected
                                    ? StratixTheme.Colors.focusTint.opacity(0.48)
                                    : Color.white.opacity(isFocused ? 0.10 : 0.0)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(isFocused && !isSelected ? 0.18 : 0.0), lineWidth: 1)
                    )
                    .scaleEffect(isSelected ? 1.04 : (isFocused ? 1.02 : 1.0))
                    .animation(.easeOut(duration: 0.12), value: isSelected)
                    .animation(.easeOut(duration: 0.12), value: isFocused)
                    .frame(maxWidth: .infinity, minHeight: StratixTheme.SideRail.rowHeight, alignment: .center)
                    .gamePassFocusRing(isFocused: isExpanded && isFocused && !isSelected, cornerRadius: 14)
            }
        }
        .buttonStyle(CloudLibraryTVButtonStyle())
        .gamePassDisableSystemFocusEffect()
        .disabled(!isFocusable)
        .accessibilityIdentifier("side_rail_action_\(action.id)")
        .accessibilityLabel(Text(action.accessibilityLabel))
        .accessibilityValue(Text(isSelected ? "selected" : "not_selected"))
        .onMoveCommand { direction in
            guard direction == .right else { return }
            onMoveToContent?()
        }
    }
}