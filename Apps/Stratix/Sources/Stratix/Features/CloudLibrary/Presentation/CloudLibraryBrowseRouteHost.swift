// CloudLibraryBrowseRouteHost.swift
// Defines cloud library browse route host for the Features / CloudLibrary surface.
//

import SwiftUI
import StratixCore

/// Renders the active browse destination and handles load-state gating for each route.
struct CloudLibraryBrowseRouteHost: View {
    @Environment(ShellBootstrapController.self) private var shellBootstrapController

    let presentation: CloudLibraryBrowseRoutePresentation
    let searchText: Binding<String>
    let isLibrarySearchActive: Bool
    let actions: CloudLibraryBrowseRouteActions

    var body: some View {
        switch presentation.browseRoute {
        case .consoles:
            CloudLibraryConsolesView(onRequestSideRailEntry: actions.requestSideRailEntry)
        case .home:
            loadStateGatedContent { loadedHomeContent }
        case .library:
            loadStateGatedContent { libraryScreen }
        }
    }

    @ViewBuilder
    /// Applies the shared load-state gate used by home and library before rendering live content.
    private func loadStateGatedContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if presentation.loadState.showsBrowseContent {
            content()
        } else if case .failedNoCache(let error) = presentation.loadState {
            errorPanel(error)
        } else {
            loadingPanel
        }
    }

    private var loadingPanel: some View {
        CloudLibraryStatusPanel(
            state: .init(
                kind: .loading,
                title: "Refreshing Game Pass",
                message: "Syncing your cloud catalog and recent titles.",
                primaryActionTitle: nil
            )
        )
    }

    private func errorPanel(_ error: String) -> some View {
        CloudLibraryStatusPanel(
            state: .init(
                kind: .error,
                title: "Couldn't load library",
                message: error,
                primaryActionTitle: "Try Again"
            ),
            onPrimaryAction: actions.refreshCloudLibrary
        )
    }

    private var loadedHomeContent: some View {
        CloudLibraryHomeScreen(
            state: presentation.homeState,
            preferredTitleID: presentation.preferredHomeTileID,
            onSelectRailItem: actions.homeSelectRailItem,
            onSelectCarouselPlay: actions.homeSelectCarouselPlay,
            onSelectCarouselDetails: actions.homeSelectCarouselDetails,
            onRequestSideRailEntry: actions.requestSideRailEntry,
            onFocusTileID: actions.homeFocusTileID,
            onSettledTileID: actions.homeSettledTileID,
            tileLookup: presentation.homeTileLookup
        )
        .equatable()
        .modifier(RouteHomeRootAccessibilityModifier(isEnabled: shellBootstrapController.phase == .ready))
    }

    private var libraryScreen: some View {
        CloudLibraryLibraryScreen(
            state: presentation.libraryState,
            tileLookup: presentation.combinedLibraryTileLookup,
            queryText: searchText,
            searchQuerySnapshot: searchText.wrappedValue,
            isLibrarySearchActive: isLibrarySearchActive,
            preferredTitleID: presentation.preferredLibraryTileID,
            onSelectTile: actions.librarySelectTile,
            onActivateSearch: actions.libraryActivateSearch,
            onFocusTileID: actions.libraryFocusTileID,
            onSettledTileID: actions.librarySettledTileID,
            onSelectTab: actions.librarySelectTab,
            onSelectFilter: actions.librarySelectFilter,
            onSelectSort: actions.librarySelectSort,
            onClearFilters: actions.libraryClearFilters,
            onClearSearch: actions.searchClearQuery,
            onRequestSideRailEntry: actions.requestSideRailEntry
        )
        .equatable()
    }
}

private struct RouteHomeRootAccessibilityModifier: ViewModifier {
    let isEnabled: Bool

    @ViewBuilder
    /// Delays the home-root accessibility marker until shell bootstrap has published a ready phase.
    func body(content: Content) -> some View {
        if isEnabled {
            content.accessibilityIdentifier("route_home_root")
        } else {
            content
        }
    }
}
