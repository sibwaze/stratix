// StreamReconnectCoordinator.swift
// Defines the stream reconnect coordinator for the Streaming surface.
//

import Foundation
import DiagnosticsKit
import StreamingCore

struct StreamReconnectLauncher: Sendable {
    let disconnectCurrentSession: @Sendable @MainActor () async -> Void
    let prepareBridge: @Sendable @MainActor () async -> any WebRTCBridge
    let tryHotReconnect: @Sendable @MainActor (any WebRTCBridge) async -> Bool
    let relaunch: @Sendable @MainActor (StreamLaunchTarget, any WebRTCBridge) async -> Void
}

struct StreamReconnectEnvironment: Sendable {
    let autoReconnectEnabled: Bool
    let isStreamConnected: @Sendable @MainActor () -> Bool
    let launcher: StreamReconnectLauncher
    let publish: @Sendable @MainActor ([StreamAction]) -> Void
}

actor StreamReconnectCoordinator {
    private let policy: StreamReconnectPolicy

    private var reconnectAttempts = 0
    private var lastLaunchTarget: StreamLaunchTarget?
    private var lastStreamBridge: (any WebRTCBridge)?
    private var pendingAttemptTask: Task<Void, Never>?
    private var isRelaunchInFlight = false

    init(policy: StreamReconnectPolicy = StreamReconnectPolicy()) {
        self.policy = policy
    }

    func recordLaunchContext(
        target: StreamLaunchTarget,
        bridge: any WebRTCBridge
    ) {
        lastLaunchTarget = target
        lastStreamBridge = bridge
    }

    func reset() {
        pendingAttemptTask?.cancel()
        pendingAttemptTask = nil
        isRelaunchInFlight = false
        reconnectAttempts = 0
        lastLaunchTarget = nil
        lastStreamBridge = nil
    }

    func cancelActiveReconnectAttempts() {
        pendingAttemptTask?.cancel()
        pendingAttemptTask = nil
        isRelaunchInFlight = false
    }

    func reconnectAttemptCount() -> Int {
        reconnectAttempts
    }

    func handleLifecycleChange(
        event: StreamSessionLifecycleEvent,
        environment: StreamReconnectEnvironment
    ) async {
        switch event.lifecycle {
        case .connected:
            if reconnectAttempts > 0 {
                StreamMetricsPipeline.shared.recordMilestone(
                    .reconnectSuccess,
                    context: metricsContext,
                    targetID: metricsTargetID,
                    reconnectAttempt: reconnectAttempts,
                    reconnectOutcome: .success
                )
            }
            pendingAttemptTask?.cancel()
            pendingAttemptTask = nil
            isRelaunchInFlight = false
            reconnectAttempts = 0
            await environment.publish([
                .reconnectCompleted,
                .runtimePhaseSet(.streaming)
            ])

        case .failed:
            await scheduleReconnectIfNeeded(
                trigger: .failed,
                intent: event.disconnectIntent,
                environment: environment
            )

        case .disconnected:
            await scheduleReconnectIfNeeded(
                trigger: .disconnected(event.disconnectIntent),
                intent: event.disconnectIntent,
                environment: environment
            )

        default:
            break
        }
    }

    private func scheduleReconnectIfNeeded(
        trigger: StreamReconnectTrigger,
        intent: StreamingDisconnectIntent,
        environment: StreamReconnectEnvironment
    ) async {
        if shouldIgnoreReconnectTransitionLifecycle(intent) {
            return
        }

        let hasLaunchContext = lastLaunchTarget != nil
        let decision = policy.decision(
            intent: intent,
            autoReconnectEnabled: environment.autoReconnectEnabled,
            currentAttemptCount: reconnectAttempts,
            hasLaunchContext: hasLaunchContext
        )
        guard decision.shouldReconnect else {
            pendingAttemptTask?.cancel()
            pendingAttemptTask = nil
            isRelaunchInFlight = false
            if reconnectAttempts > 0 {
                StreamMetricsPipeline.shared.recordMilestone(
                    .reconnectFailure,
                    context: metricsContext,
                    targetID: metricsTargetID,
                    disconnectIntent: metricsDisconnectIntent(for: intent),
                    reconnectAttempt: reconnectAttempts,
                    reconnectTrigger: String(describing: trigger),
                    reconnectOutcome: .failure,
                    metadata: ["suppression_reason": String(describing: decision.suppressionReason ?? .attemptsExhausted)]
                )
            }
            await environment.publish([
                .streamDisconnected(intent),
                .reconnectSuppressed(decision.suppressionReason ?? .attemptsExhausted)
            ])
            return
        }

        guard pendingAttemptTask == nil,
              !isRelaunchInFlight,
              let target = lastLaunchTarget else {
            return
        }

        reconnectAttempts += 1
        StreamMetricsPipeline.shared.recordMilestone(
            .reconnectAttempt,
            context: metricsContext,
            targetID: metricsTargetID,
            disconnectIntent: metricsDisconnectIntent(for: intent),
            reconnectAttempt: reconnectAttempts,
            reconnectTrigger: String(describing: trigger)
        )
        await environment.publish([
            .streamDisconnected(intent),
            .reconnectScheduled(attempt: reconnectAttempts, trigger: trigger)
        ])

        pendingAttemptTask = Task { [weak self, policy, launcher = environment.launcher, attempt = reconnectAttempts] in
            try? await Task.sleep(for: policy.delayBeforeAttempt(attemptNumber: attempt))
            guard !Task.isCancelled else { return }
            await self?.runReconnectAttempt(
                target: target,
                launcher: launcher,
                environment: environment
            )
        }
    }

    private func runReconnectAttempt(
        target: StreamLaunchTarget,
        launcher: StreamReconnectLauncher,
        environment: StreamReconnectEnvironment
    ) async {
        pendingAttemptTask = nil
        isRelaunchInFlight = true

        let bridge = await launcher.prepareBridge()
        if await launcher.tryHotReconnect(bridge) {
            isRelaunchInFlight = false
            return
        }

        await launcher.disconnectCurrentSession()
        let freshBridge = await launcher.prepareBridge()

        let relaunchTask = Task { @MainActor in
            await launcher.relaunch(target, freshBridge)
        }
        _ = await waitForRelaunchCompletion(
            relaunchTask: relaunchTask,
            timeout: policy.relaunchTimeout
        )
        await relaunchTask.value

        isRelaunchInFlight = false

        guard !Task.isCancelled else { return }
        guard await !environment.isStreamConnected() else { return }

        await scheduleReconnectIfNeeded(
            trigger: .failed,
            intent: .reconnectable,
            environment: environment
        )
    }

    private func waitForRelaunchCompletion(
        relaunchTask: Task<Void, Never>,
        timeout: Duration
    ) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await relaunchTask.value
                return true
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return false
            }
            let finishedWithinTimeout = await group.next() ?? false
            group.cancelAll()
            return finishedWithinTimeout
        }
    }

    private var metricsContext: StreamMetricsLaunchContext? {
        switch lastLaunchTarget {
        case .cloud:
            return .cloud
        case .home:
            return .home
        case nil:
            return nil
        }
    }

    private var metricsTargetID: String? {
        lastLaunchTarget?.targetId
    }

    private func shouldIgnoreReconnectTransitionLifecycle(
        _ intent: StreamingDisconnectIntent
    ) -> Bool {
        guard intent == .reconnectTransition else { return false }
        if pendingAttemptTask != nil || isRelaunchInFlight {
            return true
        }
        // Hot reconnect failures surface as `.failed` with `.reconnectTransition` after the
        // in-flight attempt already owns the retry loop. Treat those as stale noise.
        return reconnectAttempts > 0
    }

    private func metricsDisconnectIntent(
        for intent: StreamingDisconnectIntent
    ) -> StreamMetricsDisconnectIntent {
        switch intent {
        case .userInitiated, .inactivityTimeout:
            return .userInitiated
        case .reconnectable:
            return .reconnectable
        case .reconnectTransition:
            return .reconnectTransition
        case .serverInitiated:
            return .serverInitiated
        }
    }
}