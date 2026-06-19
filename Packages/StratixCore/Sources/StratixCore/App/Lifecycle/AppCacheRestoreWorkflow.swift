// AppCacheRestoreWorkflow.swift
// Defines app cache restore workflow for the App / Lifecycle surface.
//

import Foundation

struct AppCacheRestoreEnvironment {
    let isAuthenticated: Bool
    let restoreLibraryCaches: @MainActor (Bool) async -> Void
    let restoreAchievementCaches: @MainActor (Bool) async -> Void
    let restoreProfileCaches: @MainActor () async -> Void
}

@MainActor
final class AppCacheRestoreWorkflow {
    func run(environment: AppCacheRestoreEnvironment) async {
        guard environment.isAuthenticated else { return }
        async let libraryRestore: Void = environment.restoreLibraryCaches(true)
        async let achievementsRestore: Void = environment.restoreAchievementCaches(true)
        async let profileRestore: Void = environment.restoreProfileCaches()
        _ = await (libraryRestore, achievementsRestore, profileRestore)
    }
}
