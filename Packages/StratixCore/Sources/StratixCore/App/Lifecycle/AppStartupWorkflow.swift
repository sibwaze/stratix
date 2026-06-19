// AppStartupWorkflow.swift
// Defines app startup workflow for the App / Lifecycle surface.
//

import Foundation
import DiagnosticsKit

struct AppStartupAppearEnvironment {
    let updateControllerSettings: @MainActor () -> Void
    let runAppLaunchHapticsProbe: @MainActor () -> Void
    let sessionOnAppear: @MainActor () async -> Void
}

struct AppStartupHydrationEnvironment {
    let isShellSuspendedForStreaming: Bool
    let isAuthenticated: Bool
    let shouldRestoreCachesBeforeBoot: Bool
    let restoreCachesFromDisk: @MainActor () async -> Void
    let makeShellBootHydrationPlan: @MainActor () -> ShellBootHydrationPlan?
    let beginShellBootHydration: @MainActor (
        ShellBootHydrationPlan?,
        @escaping @MainActor (Bool) async -> Void,
        @escaping @MainActor () async -> Void
    ) async -> Void
    let refreshCloudLibrary: @MainActor (Bool) async -> Void
    let prefetchArtwork: @MainActor () async -> Void
    let logInfo: @MainActor (String) -> Void
}

@MainActor
final class AppStartupWorkflow {
    func handleOnAppear(environment: AppStartupAppearEnvironment) async {
        environment.updateControllerSettings()
        await environment.sessionOnAppear()
        // Haptics probing scans connected controllers synchronously; run it only after
        // session restore so auth state can advance toward the first shell frame first.
        environment.runAppLaunchHapticsProbe()
    }

    func beginShellBootHydrationIfNeeded(environment: AppStartupHydrationEnvironment) async {
        guard !environment.isShellSuspendedForStreaming else {
            environment.logInfo("Shell boot hydration skipped: shell suspended for streaming")
            return
        }
        guard environment.isAuthenticated else { return }

        if environment.shouldRestoreCachesBeforeBoot {
            await environment.restoreCachesFromDisk()
        }

        await environment.beginShellBootHydration(
            environment.makeShellBootHydrationPlan(),
            { deferInitialRoutePublication in
                await environment.refreshCloudLibrary(deferInitialRoutePublication)
            },
            {
                await environment.prefetchArtwork()
            }
        )
    }
}
