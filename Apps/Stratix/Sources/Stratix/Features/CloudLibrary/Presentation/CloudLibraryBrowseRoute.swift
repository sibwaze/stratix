// CloudLibraryBrowseRoute.swift
// Defines cloud library browse route for the Features / CloudLibrary surface.
//

import Foundation

enum CloudLibraryBrowseRoute: String, Hashable, Sendable {
    case home
    case library
    case consoles

    /// Maps legacy persisted destinations onto the current browse-route surface.
    static func normalized(from rawValue: String) -> (route: CloudLibraryBrowseRoute, libraryTabID: String?) {
        if rawValue == LibraryTabID.search {
            return (.library, LibraryTabID.search)
        }
        return (CloudLibraryBrowseRoute(rawValue: rawValue) ?? .home, nil)
    }
}

extension CloudLibraryBrowseRoute {
    var isHome: Bool { self == .home }

    var sideRailNavID: SideRailNavID {
        SideRailNavID(rawValue: rawValue) ?? .home
    }

    var heroBackgroundRoute: CloudLibrarySceneModel.HeroBackgroundRoute {
        CloudLibrarySceneModel.HeroBackgroundRoute(rawValue: rawValue) ?? .home
    }

    /// Maps browse routes onto the app-level route enum used by detail and shell state.
    var appRoute: AppRoute {
        switch self {
        case .home: .home
        case .library: .library
        case .consoles: .home
        }
    }
}

extension SideRailNavID {
    var browseRoute: CloudLibraryBrowseRoute {
        CloudLibraryBrowseRoute(rawValue: rawValue) ?? .home
    }
}
