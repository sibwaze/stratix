// CloudLibraryLibraryScreenHeader.swift
// Defines cloud library library screen header for the CloudLibrary / Library surface.
//

import SwiftUI

extension CloudLibraryLibraryScreen {
    @ViewBuilder
    func header(scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(alignment: .center, spacing: 14) {
                HStack(spacing: 28) {
                    ForEach(state.tabs) { tab in
                        LibraryTabButton(
                            title: tab.title,
                            systemImage: tab.systemImage,
                            isSelected: !isLibrarySearchActive && tab.id == state.selectedTabID
                        ) {
                            NotificationCenter.default.post(name: .librarySearchResignKeyboard, object: nil)
                            onSelectTab(tab.id)
                        }
                        .accessibilityIdentifier("library_tab_\(tab.id)")
                        .focused($focusedTarget, equals: .tab(tab.id))
                        .onMoveCommand { direction in
                            NavigationPerformanceTracker.recordRemoteMoveStart(surface: "library", direction: direction)
                            if isLibrarySearchActive {
                                handleSearchActiveTabMove(from: tab.id, direction: direction, scrollProxy: scrollProxy)
                                return
                            }
                            switch direction {
                            case .left:
                                onRequestSideRailEntry()
                            case .right where tab.id == state.tabs.last?.id:
                                requestHeaderFocus(.searchField, scrollProxy: scrollProxy)
                            case .down:
                                requestFilterOrGridFocus(scrollProxy: scrollProxy)
                            default:
                                break
                            }
                        }
                    }

                    LibraryInlineSearchControl(
                        isActive: isLibrarySearchActive,
                        onActivate: {
                            if !isLibrarySearchActive {
                                onActivateSearch()
                            }
                            focusedTarget = .searchField
                            NotificationCenter.default.post(name: .librarySearchRequestKeyboard, object: nil)
                        },
                        focusedTarget: $focusedTarget
                    )
                    .onMoveCommand { direction in
                        NavigationPerformanceTracker.recordRemoteMoveStart(surface: "library", direction: direction)
                        switch direction {
                        case .left:
                            NotificationCenter.default.post(name: .librarySearchResignKeyboard, object: nil)
                            if let lastTab = state.tabs.last {
                                requestHeaderFocus(.tab(lastTab.id), scrollProxy: scrollProxy)
                            } else {
                                onRequestSideRailEntry()
                            }
                        case .right:
                            requestHeaderFocus(.headerButton("sort"), scrollProxy: scrollProxy)
                        case .down:
                            requestFilterOrGridFocus(scrollProxy: scrollProxy)
                        default:
                            break
                        }
                    }
                }
                .animation(nil, value: isLibrarySearchActive)

                Spacer(minLength: 16)

                HStack(alignment: .center, spacing: 14) {
                    if let summary = state.resultSummaryText {
                        Text(summary)
                            .font(StratixTypography.rounded(22, weight: .semibold, dynamicTypeSize: dynamicTypeSize))
                            .foregroundStyle(StratixTheme.Colors.textMuted)
                            .lineLimit(1)
                            .layoutPriority(-1)
                    }

                    SortButton(title: state.sortLabel, onSelect: onSelectSort)
                        .focused($focusedTarget, equals: .headerButton("sort"))
                        .onMoveCommand { direction in
                            NavigationPerformanceTracker.recordRemoteMoveStart(surface: "library", direction: direction)
                            switch direction {
                            case .left:
                                requestHeaderFocus(.searchField, scrollProxy: scrollProxy)
                            case .down:
                                requestFilterOrGridFocus(scrollProxy: scrollProxy)
                            default:
                                break
                            }
                        }

                    if !state.activeFilterLabels.isEmpty {
                        SortButton(title: "Show all", icon: "line.3.horizontal.decrease.circle.fill", onSelect: onClearFilters)
                            .focused($focusedTarget, equals: .headerButton("clear-filters"))
                            .onMoveCommand { direction in
                                NavigationPerformanceTracker.recordRemoteMoveStart(surface: "library", direction: direction)
                                if direction == .left {
                                    onRequestSideRailEntry()
                                } else if direction == .down {
                                    requestFilterOrGridFocus(scrollProxy: scrollProxy)
                                }
                            }
                    }
                }
            }
            .frame(width: libraryGridTileSpanWidth, alignment: .leading)
            .padding(.leading, gridEdgeFocusInset)

            if !state.filters.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(state.filters) { filter in
                            LibraryFilterChipButton(chip: filter) {
                                onSelectFilter(filter)
                            }
                            .focused($focusedTarget, equals: .filter(filter.id))
                            .onMoveCommand { direction in
                                NavigationPerformanceTracker.recordRemoteMoveStart(surface: "library", direction: direction)
                                switch direction {
                                case .right where filter.id == state.filters.last?.id:
                                    focusedTarget = .filter(filter.id)
                                case .down:
                                    if showsSearchNoMatches {
                                        requestClearSearchFocus(scrollProxy: scrollProxy)
                                    } else {
                                        requestGridFocus(scrollProxy: scrollProxy)
                                    }
                                case .up:
                                    requestHeaderFocus(.searchField, scrollProxy: scrollProxy)
                                default:
                                    break
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(width: libraryGridTileSpanWidth, alignment: .leading)
                .padding(.leading, gridEdgeFocusInset)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusScope(headerFocusNamespace)
        .focusSection()
        .id(Self.headerAnchorID)
    }

    private func handleSearchActiveTabMove(
        from tabID: String,
        direction: MoveCommandDirection,
        scrollProxy: ScrollViewProxy
    ) {
        guard let index = state.tabs.firstIndex(where: { $0.id == tabID }) else { return }

        switch direction {
        case .left:
            NotificationCenter.default.post(name: .librarySearchResignKeyboard, object: nil)
            if index > 0 {
                requestHeaderFocus(.tab(state.tabs[index - 1].id), scrollProxy: scrollProxy)
            } else {
                onRequestSideRailEntry()
            }
        case .right:
            NotificationCenter.default.post(name: .librarySearchResignKeyboard, object: nil)
            if index < state.tabs.count - 1 {
                requestHeaderFocus(.tab(state.tabs[index + 1].id), scrollProxy: scrollProxy)
            } else {
                requestHeaderFocus(.searchField, scrollProxy: scrollProxy)
            }
        case .down:
            requestFilterOrGridFocus(scrollProxy: scrollProxy)
        default:
            break
        }
    }

    func requestFilterOrGridFocus(scrollProxy: ScrollViewProxy) {
        if let firstFilter = state.filters.first {
            requestHeaderFocus(.filter(firstFilter.id), scrollProxy: scrollProxy)
        } else {
            requestGridFocus(scrollProxy: scrollProxy)
        }
    }

    @ViewBuilder
    func libraryEmptyStatePanel(scrollProxy: ScrollViewProxy) -> some View {
        if showsSearchNoMatches {
            searchNoMatchesPanel(scrollProxy: scrollProxy)
        } else {
            CloudLibraryStatusPanel(
                state: .init(
                    kind: .empty,
                    title: "Library is empty",
                    message: "Once cloud titles are available they will appear here.",
                    primaryActionTitle: nil
                )
            )
            .frame(height: 480)
        }
    }

    private func searchNoMatchesPanel(scrollProxy: ScrollViewProxy) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 18) {
                Text("No matches")
                    .font(StratixTypography.rounded(34, weight: .bold, dynamicTypeSize: dynamicTypeSize))
                    .foregroundStyle(StratixTheme.Colors.textPrimary)

                Text("No titles matched \"\(queryText)\". Try shorter keywords.")
                    .font(StratixTypography.rounded(18, weight: .medium, dynamicTypeSize: dynamicTypeSize))
                    .foregroundStyle(StratixTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 760)

                Button(action: onClearSearch) {
                    FocusAwareView { isFocused in
                        CloudLibraryActionButton(
                            action: .init(
                                id: "clear-search",
                                title: "Clear Search",
                                systemImage: "xmark",
                                style: .primary
                            ),
                            isFocused: isFocused
                        )
                        .gamePassFocusRing(isFocused: isFocused, cornerRadius: 24)
                    }
                }
                .focused($focusedTarget, equals: .clearSearch)
                .buttonStyle(CloudLibraryTVButtonStyle())
                .gamePassDisableSystemFocusEffect()
                .onMoveCommand { direction in
                    if direction == .up {
                        requestEmptyStateUpNavigation(scrollProxy: scrollProxy)
                    }
                }
            }
            .frame(maxWidth: 760)
            Spacer()
        }
        .frame(height: 480)
        .frame(maxWidth: .infinity)
        .focusSection()
        .id(Self.clearSearchAnchorID)
    }
}