// CloudLibraryDetailPathBindingPolicy.swift
// Blocks NavigationStack pops while a stream session owns the screen.
//

import StratixModels

enum CloudLibraryDetailPathBindingPolicy {
    static func resolvedPath(
        currentPath: [TitleID],
        proposedPath: [TitleID],
        isStreamPresentationActive: Bool
    ) -> [TitleID] {
        if isStreamPresentationActive, proposedPath.count < currentPath.count {
            return currentPath
        }
        return proposedPath
    }
}