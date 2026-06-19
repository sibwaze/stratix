// NavigationTypes.swift
// Defines navigation types for the RouteState surface.
//

import Foundation
import StratixCore
import StratixModels
import XCloudAPI

/// Captures the app-level route used by shell state and detail restoration.
enum AppRoute: Equatable, Hashable {
    case home
    case library
    case detail(titleID: TitleID)
}

enum LibraryTabID {
    static let myGames = "my-games"
    static let fullLibrary = "full-library"
    static let search = "search"
}

/// Controls how the library view orders the current browse result set.
enum LibrarySortOption: String, CaseIterable, Hashable {
    case alphabetical
    case publisher
    case recentlyPlayed

    /// Provides the short label used by the library sort button.
    var label: String {
        switch self {
        case .alphabetical:
            return "A-Z"
        case .publisher:
            return "Publisher"
        case .recentlyPlayed:
            return "Recent"
        }
    }
}

/// Stores the mutable library query state shared across browse surfaces.
struct LibraryQueryState: Equatable {
    var searchText = ""
    var isLibrarySearchActive = false
    var selectedTabID = "full-library"
    var activeFilterIDs: Set<String> = []
    var sortOption: LibrarySortOption = .alphabetical
    var displayMode: CloudLibraryLibraryDisplayMode = .grid
    var scopedCategory: LibraryScopedCategoryContext?

    /// Produces a stable hash token for projection and scene-mutation change detection.
    func mutationToken(includingLibrarySearchActive: Bool) -> Int {
        var hasher = Hasher()
        hasher.combine(searchText.trimmingCharacters(in: .whitespacesAndNewlines))
        if includingLibrarySearchActive {
            hasher.combine(isLibrarySearchActive)
        }
        hasher.combine(selectedTabID)
        hasher.combine(sortOption.rawValue)
        hasher.combine(displayMode.rawValue)
        for filterID in activeFilterIDs.sorted() {
            hasher.combine(filterID)
        }
        if let scopedCategory = scopedCategory {
            hasher.combine(scopedCategory.alias)
            hasher.combine(scopedCategory.label)
            for titleID in scopedCategory.allowedTitleIDs.sorted(by: { $0.rawValue < $1.rawValue }) {
                hasher.combine(titleID.rawValue)
            }
        } else {
            hasher.combine("no_scoped_category")
        }
        return hasher.finalize()
    }
}

/// Narrows the visible library set to a specific category while preserving its label and allowed title IDs.
struct LibraryScopedCategoryContext: Equatable, Hashable, Sendable {
    let alias: String
    let label: String
    let allowedTitleIDs: Set<TitleID>
}

/// Represents the currently active stream launch target for cloud and home-console entry paths.
enum StreamContext: Identifiable {
    enum ID: Hashable {
        case cloud(TitleID)
        case home(consoleID: String)
    }

    case cloud(titleId: TitleID)
    case home(console: RemoteConsole)

    /// Produces a stable stream identity for routing, presentation, and cover presentation state.
    var id: ID {
        switch self {
        case .cloud(let titleId): return .cloud(titleId)
        case .home(let console): return .home(consoleID: console.serverId)
        }
    }
}
