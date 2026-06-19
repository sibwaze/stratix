// SideRailNavList.swift
// Defines side rail nav list for the Shared / Components surface.
//

import SwiftUI

extension SideRailNavigationView {
    /// Main nav stack for the side rail, including the collapsed-mode re-entry behavior on the selected row.
    var navListView: some View {
        VStack(alignment: .leading, spacing: StratixTheme.SideRail.rowSpacing) {
            ForEach(orderedNavItems) { item in
                let isRowFocusable =
                    isRailExpanded || (collapsedSelectedNavFocusable && item.id == selectedNavID)
                SideRailNavButton(
                    item: item,
                    isSelected: item.id == selectedNavID && activeUtilityRoute == nil,
                    isExpanded: isRailExpanded,
                    isFocusable: isRowFocusable,
                    onSelect: {
                        onSelectNav(item.id)
                        collapseRail()
                    },
                    onRequestExpandWhenCollapsed: {
                        guard item.id == selectedNavID else { return }
                        expandRailAndFocusPreferredTarget()
                    },
                    onMoveToContent: moveFocusToContent
                )
                .focused($focusedTarget, equals: .nav(item.id))
                .onMoveCommand { direction in
                    guard isRailExpanded else { return }
                    if direction == .up, item.id == firstExpandedNavID {
                        focusedTarget = .account
                        return
                    }
                    if direction == .down, item.id == lastExpandedNavID, let firstActionID {
                        focusedTarget = .action(firstActionID)
                    }
                }
            }
        }
    }
}

/// Focus-aware side rail nav row that uses icon-only chrome with a green selected state.
private struct SideRailNavButton: View {
    let item: SideRailNavItemViewState
    let isSelected: Bool
    let isExpanded: Bool
    let isFocusable: Bool
    let onSelect: () -> Void
    var onRequestExpandWhenCollapsed: (() -> Void)? = nil
    var onMoveToContent: (() -> Void)? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: onSelect) {
            FocusAwareView { isFocused in
                let iconSize = isSelected ? StratixTheme.SideRail.selectedIconSize : StratixTheme.SideRail.iconSize
                Image(systemName: item.systemImage)
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
                    .gamePassFocusRing(isFocused: isFocused && !isSelected, cornerRadius: 14)
            }
        }
        .buttonStyle(CloudLibraryTVButtonStyle())
        .gamePassDisableSystemFocusEffect()
        .disabled(!isFocusable)
        .accessibilityLabel(Text(item.title))
        .accessibilityIdentifier(sideRailNavAccessibilityIdentifier)
        .accessibilityValue(Text(isSelected ? "selected" : "not_selected"))
        .onMoveCommand { direction in
            guard direction == .right || direction == .left else { return }
            if direction == .right {
                onMoveToContent?()
                return
            }
            guard isSelected, !isExpanded else { return }
            onRequestExpandWhenCollapsed?()
        }
    }

    /// Uses stable accessibility IDs so shell UI tests can target each primary route directly.
    private var sideRailNavAccessibilityIdentifier: String {
        switch item.id {
        case .home:
            return "side_rail_nav_home"
        case .library:
            return "side_rail_nav_library"
        case .consoles:
            return "side_rail_nav_consoles"
        }
    }
}