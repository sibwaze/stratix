// StreamInactivityWatchdog.swift
// Disconnects the stream after a configured period without controller input.
//

import Foundation

@MainActor
final class StreamInactivityWatchdog {
    private var watchdogTask: Task<Void, Never>?
    private var lastActivityAt = Date()

    func start(
        timeoutMinutes: Int,
        onTimeout: @escaping @MainActor () async -> Void
    ) {
        stop()
        lastActivityAt = Date()
        guard timeoutMinutes > 0 else { return }

        let timeoutSeconds = TimeInterval(timeoutMinutes * 60)
        watchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self, !Task.isCancelled else { return }
                let elapsed = Date().timeIntervalSince(self.lastActivityAt)
                guard elapsed >= timeoutSeconds else { continue }
                await onTimeout()
                return
            }
        }
    }

    func recordActivity() {
        lastActivityAt = Date()
    }

    func stop() {
        watchdogTask?.cancel()
        watchdogTask = nil
    }
}