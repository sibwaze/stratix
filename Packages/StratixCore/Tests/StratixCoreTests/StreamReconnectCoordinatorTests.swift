// StreamReconnectCoordinatorTests.swift
// Exercises stream reconnect coordinator behavior.
//

import Testing
import DiagnosticsKit
import os
@testable import StratixCore
import StratixModels
import StreamingCore

@MainActor
@Suite(.serialized)
struct StreamReconnectCoordinatorTests {
    @Test
    func recordLaunchContext_andReset_trackReconnectState() async {
        let coordinator = StreamReconnectCoordinator(policy: StreamReconnectPolicy(maxAttempts: 3, retryDelay: .zero))
        await coordinator.recordLaunchContext(target: .cloud(makeTitleID()), bridge: TestWebRTCBridge())
        await coordinator.handleLifecycleChange(
            event: StreamSessionLifecycleEvent(
                lifecycle: .failed(StreamError(code: .unknown, message: "failed")),
                disconnectIntent: .reconnectable
            ),
            environment: makeReconnectEnvironment()
        )
        try? await Task.sleep(for: .milliseconds(20))
        #expect(await coordinator.reconnectAttemptCount() == 1)
        await coordinator.reset()
        #expect(await coordinator.reconnectAttemptCount() == 0)
    }

    @Test
    func reset_cancelsPendingReconnectTask() async {
        let coordinator = StreamReconnectCoordinator(
            policy: StreamReconnectPolicy(maxAttempts: 3, retryDelay: .milliseconds(100))
        )
        let session = makeStreamingSession()
        var relaunched = false

        await coordinator.recordLaunchContext(target: .cloud(makeTitleID()), bridge: TestWebRTCBridge())

        await coordinator.handleLifecycleChange(
            event: StreamSessionLifecycleEvent(
                lifecycle: .failed(StreamError(code: .unknown, message: "decode fail")),
                disconnectIntent: session.disconnectIntent
            ),
            environment: makeReconnectEnvironment(
                autoReconnectEnabled: true,
                relaunch: { _, _ in relaunched = true }
            )
        )

        await coordinator.reset()
        try? await Task.sleep(for: .milliseconds(150))

        #expect(await coordinator.reconnectAttemptCount() == 0)
        #expect(relaunched == false)
    }

    @Test
    func handleLifecycleChange_failed_triesHotReconnectBeforeRelaunch() async {
        let coordinator = StreamReconnectCoordinator(policy: StreamReconnectPolicy(maxAttempts: 3, retryDelay: .zero))
        var hotReconnectCalls = 0
        var relaunchCalls = 0

        await coordinator.recordLaunchContext(target: .cloud(makeTitleID()), bridge: TestWebRTCBridge())

        await coordinator.handleLifecycleChange(
            event: StreamSessionLifecycleEvent(
                lifecycle: .failed(StreamError(code: .unknown, message: "decode fail")),
                disconnectIntent: .reconnectable
            ),
            environment: makeReconnectEnvironment(
                autoReconnectEnabled: true,
                tryHotReconnect: { _ in
                    hotReconnectCalls += 1
                    return true
                },
                relaunch: { _, _ in
                    relaunchCalls += 1
                }
            )
        )
        try? await Task.sleep(for: .milliseconds(20))

        #expect(hotReconnectCalls == 1)
        #expect(relaunchCalls == 0)
    }

    @Test
    func handleLifecycleChange_failed_preparesFreshBridgeBeforeRelaunch() async {
        let coordinator = StreamReconnectCoordinator(policy: StreamReconnectPolicy(maxAttempts: 3, retryDelay: .zero))
        let initialBridge = TestWebRTCBridge()
        let preparedBridge = TestWebRTCBridge()
        var prepareBridgeCalls = 0
        var relaunchedBridge: (any WebRTCBridge)?

        await coordinator.recordLaunchContext(target: .cloud(makeTitleID()), bridge: initialBridge)

        await coordinator.handleLifecycleChange(
            event: StreamSessionLifecycleEvent(
                lifecycle: .failed(StreamError(code: .unknown, message: "decode fail")),
                disconnectIntent: .reconnectable
            ),
            environment: makeReconnectEnvironment(
                autoReconnectEnabled: true,
                prepareBridge: {
                    prepareBridgeCalls += 1
                    return preparedBridge
                },
                relaunch: { _, bridge in
                    relaunchedBridge = bridge
                }
            )
        )
        try? await Task.sleep(for: .milliseconds(20))

        #expect(prepareBridgeCalls == 2)
        #expect(relaunchedBridge as AnyObject === preparedBridge)
        #expect(relaunchedBridge as AnyObject !== initialBridge)
    }

    @Test
    func handleLifecycleChange_failed_schedulesCloudReconnectWhenEligible() async {
        let coordinator = StreamReconnectCoordinator(policy: StreamReconnectPolicy(maxAttempts: 3, retryDelay: .zero))
        let session = makeStreamingSession()
        let bridge = TestWebRTCBridge()
        var published: [StreamAction] = []
        var disconnected = false
        var reconnectedTarget: StreamLaunchTarget?

        await coordinator.recordLaunchContext(target: .cloud(makeTitleID()), bridge: bridge)

        await coordinator.handleLifecycleChange(
            event: StreamSessionLifecycleEvent(
                lifecycle: .failed(StreamError(code: .unknown, message: "decode fail")),
                disconnectIntent: session.disconnectIntent
            ),
            environment: makeReconnectEnvironment(
                autoReconnectEnabled: true,
                disconnectCurrentSession: { disconnected = true },
                relaunch: { target, _ in reconnectedTarget = target },
                publish: { published.append(contentsOf: $0) }
            )
        )
        try? await Task.sleep(for: .milliseconds(20))

        #expect(published.contains(.reconnectScheduled(attempt: 1, trigger: .failed)))
        #expect(disconnected == true)
        #expect(reconnectedTarget == .cloud(makeTitleID()))
    }

    @Test
    func handleLifecycleChange_disconnected_suppressesReconnectWhenPolicyRejectsIt() async {
        let coordinator = StreamReconnectCoordinator(policy: StreamReconnectPolicy(maxAttempts: 0, retryDelay: .zero))
        let session = makeStreamingSession()
        var published: [StreamAction] = []
        var reconnected = false

        await coordinator.recordLaunchContext(target: .cloud(makeTitleID()), bridge: TestWebRTCBridge())

        await coordinator.handleLifecycleChange(
            event: StreamSessionLifecycleEvent(
                lifecycle: .disconnected,
                disconnectIntent: session.disconnectIntent
            ),
            environment: makeReconnectEnvironment(
                autoReconnectEnabled: true,
                relaunch: { _, _ in reconnected = true },
                publish: { published.append(contentsOf: $0) }
            )
        )

        #expect(reconnected == false)
        #expect(published.contains(.reconnectSuppressed(.attemptsExhausted)))
    }

    @Test
    func handleLifecycleChange_reconnectTransition_doesNotCancelActiveReconnectTask() async {
        let coordinator = StreamReconnectCoordinator(policy: StreamReconnectPolicy(maxAttempts: 3, retryDelay: .zero))
        let bridge = TestWebRTCBridge()
        var published: [StreamAction] = []
        var relaunched = false

        await coordinator.recordLaunchContext(target: .cloud(makeTitleID()), bridge: bridge)

        await coordinator.handleLifecycleChange(
            event: StreamSessionLifecycleEvent(
                lifecycle: .failed(StreamError(code: .unknown, message: "decode fail")),
                disconnectIntent: .reconnectable
            ),
            environment: makeReconnectEnvironment(
                autoReconnectEnabled: true,
                disconnectCurrentSession: {
                    await coordinator.handleLifecycleChange(
                        event: StreamSessionLifecycleEvent(
                            lifecycle: .disconnected,
                            disconnectIntent: .reconnectTransition
                        ),
                        environment: makeReconnectEnvironment(autoReconnectEnabled: true)
                    )
                },
                relaunch: { _, _ in relaunched = true },
                publish: { published.append(contentsOf: $0) }
            )
        )
        try? await Task.sleep(for: .milliseconds(20))

        #expect(relaunched == true)
        #expect(published.contains(.reconnectSuppressed(.reconnectTransition)) == false)
    }

    @Test
    func handleLifecycleChange_homeReconnect_usesHomeTarget() async {
        let coordinator = StreamReconnectCoordinator(policy: StreamReconnectPolicy(maxAttempts: 3, retryDelay: .zero))
        let session = makeStreamingSession()
        let bridge = TestWebRTCBridge()
        var relaunchedTarget: StreamLaunchTarget?

        await coordinator.recordLaunchContext(target: .home(consoleId: "console-1"), bridge: bridge)

        await coordinator.handleLifecycleChange(
            event: StreamSessionLifecycleEvent(
                lifecycle: .failed(StreamError(code: .network, message: "network")),
                disconnectIntent: session.disconnectIntent
            ),
            environment: makeReconnectEnvironment(
                autoReconnectEnabled: true,
                relaunch: { target, _ in relaunchedTarget = target }
            )
        )
        try? await Task.sleep(for: .milliseconds(20))

        #expect(relaunchedTarget == .home(consoleId: "console-1"))
    }

    @Test
    func explicitStop_followedByReset_doesNotLeaveReconnectTaskRunning() async {
        let coordinator = StreamReconnectCoordinator(
            policy: StreamReconnectPolicy(maxAttempts: 3, retryDelay: .milliseconds(100))
        )
        let session = makeStreamingSession()
        var disconnectCalls = 0
        var relaunchCalls = 0

        await coordinator.recordLaunchContext(target: .cloud(makeTitleID()), bridge: TestWebRTCBridge())

        await coordinator.handleLifecycleChange(
            event: StreamSessionLifecycleEvent(
                lifecycle: .failed(StreamError(code: .unknown, message: "decode fail")),
                disconnectIntent: session.disconnectIntent
            ),
            environment: makeReconnectEnvironment(
                autoReconnectEnabled: true,
                disconnectCurrentSession: { disconnectCalls += 1 },
                relaunch: { _, _ in relaunchCalls += 1 }
            )
        )

        await coordinator.reset()
        try? await Task.sleep(for: .milliseconds(150))

        #expect(disconnectCalls == 0)
        #expect(relaunchCalls == 0)
        #expect(await coordinator.reconnectAttemptCount() == 0)
    }

    @Test
    func handleLifecycleChange_staleReconnectTransition_doesNotSuppressActiveRetries() async {
        let coordinator = StreamReconnectCoordinator(
            policy: StreamReconnectPolicy(maxAttempts: 3, retryDelay: .zero, relaunchTimeout: .zero)
        )
        var published: [StreamAction] = []
        var relaunchCount = 0

        await coordinator.recordLaunchContext(target: .cloud(makeTitleID()), bridge: TestWebRTCBridge())

        await coordinator.handleLifecycleChange(
            event: StreamSessionLifecycleEvent(
                lifecycle: .failed(StreamError(code: .webrtc, message: "Connection lost: disconnected")),
                disconnectIntent: .reconnectable
            ),
            environment: makeReconnectEnvironment(
                autoReconnectEnabled: true,
                tryHotReconnect: { _ in false },
                relaunch: { _, _ in relaunchCount += 1 },
                publish: { published.append(contentsOf: $0) }
            )
        )
        try? await Task.sleep(for: .milliseconds(80))

        await coordinator.handleLifecycleChange(
            event: StreamSessionLifecycleEvent(
                lifecycle: .failed(StreamError(code: .webrtc, message: "Connection lost: disconnected")),
                disconnectIntent: .reconnectTransition
            ),
            environment: makeReconnectEnvironment(
                autoReconnectEnabled: true,
                tryHotReconnect: { _ in false },
                relaunch: { _, _ in relaunchCount += 1 },
                publish: { published.append(contentsOf: $0) }
            )
        )
        try? await Task.sleep(for: .milliseconds(80))

        #expect(published.contains(.reconnectSuppressed(.reconnectTransition)) == false)
        #expect(relaunchCount >= 2)
        #expect(published.contains(.reconnectScheduled(attempt: 2, trigger: .failed)))
    }

    @Test
    func handleLifecycleChange_failed_schedulesFollowUpAttemptAfterUnsuccessfulRelaunch() async {
        let coordinator = StreamReconnectCoordinator(
            policy: StreamReconnectPolicy(maxAttempts: 3, retryDelay: .zero, relaunchTimeout: .zero)
        )
        var published: [StreamAction] = []
        var relaunchCount = 0

        await coordinator.recordLaunchContext(target: .cloud(makeTitleID()), bridge: TestWebRTCBridge())

        await coordinator.handleLifecycleChange(
            event: StreamSessionLifecycleEvent(
                lifecycle: .failed(StreamError(code: .network, message: "offline")),
                disconnectIntent: .reconnectable
            ),
            environment: makeReconnectEnvironment(
                autoReconnectEnabled: true,
                isStreamConnected: { false },
                relaunch: { _, _ in relaunchCount += 1 },
                publish: { published.append(contentsOf: $0) }
            )
        )
        try? await Task.sleep(for: .milliseconds(50))

        #expect(relaunchCount == 1)
        #expect(published.contains(.reconnectScheduled(attempt: 1, trigger: .failed)))

        try? await Task.sleep(for: .milliseconds(50))

        #expect(relaunchCount >= 2)
        #expect(published.contains(.reconnectScheduled(attempt: 2, trigger: .failed)))
    }

    @Test
    func reconnectLifecycle_recordsAttemptsSuccessAndFailureMilestones() async {
        let coordinator = StreamReconnectCoordinator(policy: StreamReconnectPolicy(maxAttempts: 1, retryDelay: .zero))
        let records = OSAllocatedUnfairLock(initialState: [StreamMetricsRecord]())
        let token = StreamMetricsPipeline.shared.registerSink(
            StreamMetricsSink(name: #function) { record in
                records.withLock { $0.append(record) }
            }
        )
        defer { StreamMetricsPipeline.shared.unregisterSink(token) }

        await coordinator.recordLaunchContext(target: .cloud(makeTitleID("metrics-reconnect")), bridge: TestWebRTCBridge())

        await coordinator.handleLifecycleChange(
            event: StreamSessionLifecycleEvent(
                lifecycle: .failed(StreamError(code: .unknown, message: "decode fail")),
                disconnectIntent: .reconnectable
            ),
            environment: makeReconnectEnvironment(autoReconnectEnabled: true)
        )
        try? await Task.sleep(for: .milliseconds(20))

        var reconnectRecords = records.withLock { allRecords in
            allRecords.compactMap { record -> StreamMetricsMilestoneRecord? in
                guard case .milestone(let milestone) = record.payload else { return nil }
                return milestone.targetID == "metrics-reconnect" ? milestone : nil
            }
        }
        #expect(reconnectRecords.contains { $0.milestone == StreamMetricsMilestone.reconnectAttempt && $0.reconnectAttempt == 1 })

        await coordinator.handleLifecycleChange(
            event: StreamSessionLifecycleEvent(
                lifecycle: .connected,
                disconnectIntent: .reconnectable
            ),
            environment: makeReconnectEnvironment(autoReconnectEnabled: true)
        )
        reconnectRecords = records.withLock { allRecords in
            allRecords.compactMap { record -> StreamMetricsMilestoneRecord? in
                guard case .milestone(let milestone) = record.payload else { return nil }
                return milestone.targetID == "metrics-reconnect" ? milestone : nil
            }
        }
        #expect(reconnectRecords.contains { $0.milestone == StreamMetricsMilestone.reconnectSuccess && $0.reconnectOutcome == StreamMetricsReconnectOutcome.success })

        await coordinator.handleLifecycleChange(
            event: StreamSessionLifecycleEvent(
                lifecycle: .failed(StreamError(code: .unknown, message: "decode fail")),
                disconnectIntent: .reconnectable
            ),
            environment: makeReconnectEnvironment(autoReconnectEnabled: true)
        )
        try? await Task.sleep(for: .milliseconds(20))
        await coordinator.handleLifecycleChange(
            event: StreamSessionLifecycleEvent(
                lifecycle: .failed(StreamError(code: .unknown, message: "decode fail again")),
                disconnectIntent: .reconnectable
            ),
            environment: makeReconnectEnvironment(autoReconnectEnabled: true)
        )

        reconnectRecords = records.withLock { allRecords in
            allRecords.compactMap { record -> StreamMetricsMilestoneRecord? in
                guard case .milestone(let milestone) = record.payload else { return nil }
                return milestone.targetID == "metrics-reconnect" ? milestone : nil
            }
        }
        #expect(reconnectRecords.contains { $0.milestone == StreamMetricsMilestone.reconnectFailure && $0.reconnectOutcome == StreamMetricsReconnectOutcome.failure })
    }
}

private func makeReconnectEnvironment(
    autoReconnectEnabled: Bool = true,
    isStreamConnected: @escaping @Sendable @MainActor () -> Bool = { false },
    disconnectCurrentSession: @escaping @Sendable @MainActor () async -> Void = {},
    prepareBridge: @escaping @Sendable @MainActor () async -> any WebRTCBridge = { TestWebRTCBridge() },
    tryHotReconnect: @escaping @Sendable @MainActor (any WebRTCBridge) async -> Bool = { _ in false },
    relaunch: @escaping @Sendable @MainActor (StreamLaunchTarget, any WebRTCBridge) async -> Void = { _, _ in },
    publish: @escaping @Sendable @MainActor ([StreamAction]) -> Void = { _ in }
) -> StreamReconnectEnvironment {
    StreamReconnectEnvironment(
        autoReconnectEnabled: autoReconnectEnabled,
        isStreamConnected: isStreamConnected,
        launcher: StreamReconnectLauncher(
            disconnectCurrentSession: disconnectCurrentSession,
            prepareBridge: prepareBridge,
            tryHotReconnect: tryHotReconnect,
            relaunch: relaunch
        ),
        publish: publish
    )
}
