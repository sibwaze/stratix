// CloudLibraryPresentationStore.swift
// Defines the cloud library presentation store.
//

import Observation
import StratixCore

@Observable
@MainActor
/// Caches shell, browse, and utility presentation projections so route hosts read pre-shaped view state.
final class CloudLibraryPresentationStore {
    let shellBuilder: CloudLibraryShellPresentationBuilder
    let browseBuilder: CloudLibraryBrowseRoutePresentationBuilder
    let utilityBuilder: CloudLibraryUtilityRoutePresentationBuilder

    var shellChromeProjection = CloudLibraryShellChromeProjection.empty
    var sideRailProjection = CloudLibrarySideRailShellProjection.empty
    var sideRailState = SideRailNavigationViewState(
        accountName: "",
        accountStatus: "",
        accountDetail: nil,
        profileImageURL: nil,
        profileInitials: "",
        navItems: [],
        trailingActions: []
    )
    var shellPresentationProjection = CloudLibraryShellPresentationProjection.empty
    var utilityRoutePresentation = CloudLibraryUtilityRoutePresentation.empty
    var browseRoutePresentation = CloudLibraryBrowseRoutePresentation.empty

    init(
        shellBuilder: CloudLibraryShellPresentationBuilder = .init(),
        browseBuilder: CloudLibraryBrowseRoutePresentationBuilder = .init(),
        utilityBuilder: CloudLibraryUtilityRoutePresentationBuilder = .init()
    ) {
        self.shellBuilder = shellBuilder
        self.browseBuilder = browseBuilder
        self.utilityBuilder = utilityBuilder
    }

    /// Rebuilds shell-wide chrome and utility projections from the latest profile, shell, and library snapshots.
    func rebuildShellPresentation(
        settingsStore: SettingsStore,
        profileSnapshot: ProfileShellSnapshot,
        libraryStatus: LibraryShellStatusSnapshot,
        consoleCount: Int,
        isLoadingCloudLibrary: Bool,
        regionOverrideDiagnostics: String?,
        viewModel: CloudLibraryViewModel
    ) {
        let shellProjection = shellBuilder.makeShellPresentation(
            profileSnapshot: profileSnapshot,
            libraryStatus: libraryStatus,
            settingsStore: settingsStore,
            libraryCount: viewModel.cachedLibraryCount,
            consoleCount: consoleCount
        )
        let utilityProjection = utilityBuilder.makeUtilityRoutePresentation(
            shellPresentation: shellProjection,
            profileSnapshot: profileSnapshot,
            isLoadingCloudLibrary: isLoadingCloudLibrary,
            regionOverrideDiagnostics: regionOverrideDiagnostics
        )

        if shellChromeProjection != shellProjection.shellChrome {
            shellChromeProjection = shellProjection.shellChrome
        }
        if sideRailProjection != shellProjection.sideRail {
            sideRailProjection = shellProjection.sideRail
            sideRailState = shellProjection.sideRail.sideRailState
        }
        if shellPresentationProjection != shellProjection {
            shellPresentationProjection = shellProjection
        }
        if utilityRoutePresentation != utilityProjection {
            utilityRoutePresentation = utilityProjection
        }
    }

    /// Rebuilds the browse-route presentation cache from route, load, focus, and view-model projection state.
    func rebuildBrowsePresentation(
        loadState: CloudLibraryLoadState,
        routeState: CloudLibraryRouteState,
        focusState: CloudLibraryFocusState,
        viewModel: CloudLibraryViewModel
    ) {
        let nextPresentation = browseBuilder.makeBrowseRoutePresentation(
            loadState: loadState,
            routeState: routeState,
            focusState: focusState,
            homeState: viewModel.cachedHomeState,
            libraryState: viewModel.cachedLibraryState,
            totalLibraryCount: viewModel.cachedLibraryCount,
            searchBrowseItems: viewModel.cachedSearchBrowseItems,
            searchResultItems: viewModel.cachedSearchResultItems,
            homeTileLookup: viewModel.cachedHomeTileLookup,
            libraryTileLookup: viewModel.cachedLibraryTileLookup,
            searchTileLookup: viewModel.cachedSearchTileLookup,
            combinedLibraryTileLookup: viewModel.cachedCombinedLibraryTileLookup
        )
        if browseRoutePresentation != nextPresentation {
            browseRoutePresentation = nextPresentation
        }
    }

    /// Produces a stable task token for shell and utility presentation rebuild work.
    func shellPresentationTaskID(
        settingsStore: SettingsStore,
        profileSnapshot: ProfileShellSnapshot,
        libraryStatus: LibraryShellStatusSnapshot,
        consoleCount: Int,
        isLoadingCloudLibrary: Bool,
        regionOverrideDiagnostics: String?,
        viewModel: CloudLibraryViewModel
    ) -> Int {
        var hasher = Hasher()
        hasher.combine(profileSnapshot.preferredScreenName ?? "")
        hasher.combine(profileSnapshot.profileImageURL)
        hasher.combine(profileSnapshot.gameDisplayName ?? "")
        hasher.combine(profileSnapshot.gamertag ?? "")
        hasher.combine(profileSnapshot.gamerscore ?? "")
        hasher.combine(profileSnapshot.presenceState ?? "")
        hasher.combine(profileSnapshot.activeTitleName ?? "")
        hasher.combine(profileSnapshot.lastSeenTitleName ?? "")
        hasher.combine(profileSnapshot.onlineDeviceType ?? "")
        hasher.combine(profileSnapshot.isOnline)
        hasher.combine(profileSnapshot.isLoadingCurrentUserPresence)
        hasher.combine(profileSnapshot.lastCurrentUserPresenceError ?? "")
        hasher.combine(profileSnapshot.friendsCount)
        hasher.combine(profileSnapshot.friendsLastUpdatedAt)
        hasher.combine(profileSnapshot.friendsErrorText ?? "")
        hasher.combine(libraryStatus.needsReauth)
        hasher.combine(libraryStatus.isLoading)
        hasher.combine(libraryStatus.hasSections)
        hasher.combine(libraryStatus.lastErrorText ?? "")
        hasher.combine(viewModel.cachedLibraryCount)
        hasher.combine(consoleCount)
        hasher.combine(isLoadingCloudLibrary)
        hasher.combine(regionOverrideDiagnostics ?? "")
        hasher.combine(settingsStore.shell.profileName)
        hasher.combine(settingsStore.shell.profilePresenceOverride)
        hasher.combine(settingsStore.profileImageURL)
        hasher.combine(settingsStore.stream.qualityPreset)
        hasher.combine(settingsStore.stream.codecPreference)
        hasher.combine(settingsStore.stream.lowLatencyMode)
        hasher.combine(settingsStore.stream.showStreamStats)
        return hasher.finalize()
    }

    /// Produces a stable task token for browse presentation rebuild work.
    func browsePresentationTaskID(
        loadState: CloudLibraryLoadState,
        routeState: CloudLibraryRouteState,
        focusState: CloudLibraryFocusState,
        viewModel: CloudLibraryViewModel
    ) -> Int {
        viewModel.browsePresentationMutationToken(
            loadState: loadState,
            routeState: routeState,
            focusState: focusState
        )
    }

    /// Clears every cached presentation surface so sign-out cannot leak shell UI from the prior session.
    func resetForSignOut() {
        shellChromeProjection = .empty
        sideRailProjection = .empty
        sideRailState = SideRailNavigationViewState(
            accountName: "",
            accountStatus: "",
            accountDetail: nil,
            profileImageURL: nil,
            profileInitials: "",
            navItems: [],
            trailingActions: []
        )
        shellPresentationProjection = .empty
        utilityRoutePresentation = .empty
        browseRoutePresentation = .empty
    }
}