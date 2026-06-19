// AuthenticatedShellPresenceStatusTests.swift
// Exercises authenticated shell presence status resolution.
//

import Testing
@testable import Stratix
@testable import StratixCore

@MainActor
struct AuthenticatedShellPresenceStatusTests {
    @Test
    func resolvedPresenceStatus_prefersOnlineSignalFromActiveTitle() {
        let snapshot = ProfileShellSnapshot(
            preferredScreenName: "Player",
            profileImageURL: nil,
            gameDisplayName: "Player",
            gamertag: "player",
            gamerscore: "1000",
            presenceState: "Away",
            activeTitleName: "Forza Horizon 5",
            lastSeenTitleName: nil,
            onlineDeviceType: "Scarlett",
            isOnline: true,
            isLoadingCurrentUserPresence: false,
            lastCurrentUserPresenceError: nil,
            friendsCount: 0,
            friendsLastUpdatedAt: nil,
            friendsErrorText: nil
        )

        #expect(authenticatedShellResolvedPresenceStatus(from: snapshot) == "Online")
    }

    @Test
    func profilePresenceStatus_keepsResolvedStatusWhilePresenceIsLoading() {
        let settingsStore = SettingsStore(defaults: UserDefaults(suiteName: "AuthenticatedShellPresenceStatusTests.loading")!)
        let snapshot = ProfileShellSnapshot(
            preferredScreenName: "Player",
            profileImageURL: nil,
            gameDisplayName: "Player",
            gamertag: "player",
            gamerscore: "1000",
            presenceState: "Online",
            activeTitleName: "Halo Infinite",
            lastSeenTitleName: nil,
            onlineDeviceType: "Scarlett",
            isOnline: true,
            isLoadingCurrentUserPresence: true,
            lastCurrentUserPresenceError: nil,
            friendsCount: 0,
            friendsLastUpdatedAt: nil,
            friendsErrorText: nil
        )
        let libraryStatus = LibraryShellStatusSnapshot(
            needsReauth: false,
            isLoading: false,
            hasSections: true,
            lastErrorText: nil
        )

        #expect(
            authenticatedShellProfilePresenceStatus(
                profileSnapshot: snapshot,
                libraryStatus: libraryStatus,
                settingsStore: settingsStore
            ) == "Online"
        )
    }

    @Test
    func profilePresenceStatus_fallsBackToOnlineWhenPresenceUnknownAndLibraryHealthy() {
        let settingsStore = SettingsStore(defaults: UserDefaults(suiteName: "AuthenticatedShellPresenceStatusTests.unknown")!)
        let snapshot = ProfileShellSnapshot(
            preferredScreenName: "Player",
            profileImageURL: nil,
            gameDisplayName: "Player",
            gamertag: "player",
            gamerscore: "1000",
            presenceState: "Unknown",
            activeTitleName: nil,
            lastSeenTitleName: nil,
            onlineDeviceType: nil,
            isOnline: false,
            isLoadingCurrentUserPresence: false,
            lastCurrentUserPresenceError: nil,
            friendsCount: 0,
            friendsLastUpdatedAt: nil,
            friendsErrorText: nil
        )
        let libraryStatus = LibraryShellStatusSnapshot(
            needsReauth: false,
            isLoading: false,
            hasSections: true,
            lastErrorText: nil
        )

        #expect(
            authenticatedShellProfilePresenceStatus(
                profileSnapshot: snapshot,
                libraryStatus: libraryStatus,
                settingsStore: settingsStore
            ) == "Online"
        )
    }
}