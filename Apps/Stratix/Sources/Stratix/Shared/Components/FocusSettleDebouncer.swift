// FocusSettleDebouncer.swift
// Defines focus settle debouncer for the Shared / Components surface.
//

import Foundation
import StratixCore

@MainActor
final class FocusSettleDebouncer {
    private var task: Task<Void, Never>?

    func schedule(
        debounce: UInt64 = StratixConstants.Timing.focusSettleDebounceNanoseconds,
        action: @escaping @MainActor () -> Void
    ) {
        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: debounce)
            guard !Task.isCancelled else { return }
            action()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

@MainActor
enum MainActorDeferredTask {
    /// Defers work until after the next run-loop turn so focusable views can publish first.
    static func schedule(
        task: inout Task<Void, Never>?,
        _ work: @escaping @MainActor () -> Void
    ) {
        task?.cancel()
        task = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            work()
        }
    }
}
