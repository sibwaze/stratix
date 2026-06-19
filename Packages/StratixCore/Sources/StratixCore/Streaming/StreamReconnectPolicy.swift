// StreamReconnectPolicy.swift
// Defines stream reconnect policy for the Streaming surface.
//

import Foundation
import StreamingCore

struct StreamReconnectDecision: Equatable {
    let shouldReconnect: Bool
    let suppressionReason: StreamReconnectSuppressionReason?
}

struct StreamReconnectPolicy {
    static let defaultMaxAttempts = 9
    static let defaultRetryDelay: Duration = .seconds(10)
    static let defaultRelaunchTimeout: Duration = .seconds(30)
    static let defaultHotReconnectTimeout: Duration = .seconds(60)

    static var defaultTotalRetryWindowSeconds: Int {
        Int(defaultRetryDelay.components.seconds) * defaultMaxAttempts
    }

    let maxAttempts: Int
    let retryDelay: Duration
    let relaunchTimeout: Duration
    let hotReconnectTimeout: Duration

    init(
        maxAttempts: Int = StreamReconnectPolicy.defaultMaxAttempts,
        retryDelay: Duration = StreamReconnectPolicy.defaultRetryDelay,
        relaunchTimeout: Duration = StreamReconnectPolicy.defaultRelaunchTimeout,
        hotReconnectTimeout: Duration = StreamReconnectPolicy.defaultHotReconnectTimeout
    ) {
        self.maxAttempts = maxAttempts
        self.retryDelay = retryDelay
        self.relaunchTimeout = relaunchTimeout
        self.hotReconnectTimeout = hotReconnectTimeout
    }

    func delayBeforeAttempt(attemptNumber: Int) -> Duration {
        attemptNumber <= 1 ? .zero : retryDelay
    }

    func decision(
        intent: StreamingDisconnectIntent,
        autoReconnectEnabled: Bool,
        currentAttemptCount: Int,
        hasLaunchContext: Bool
    ) -> StreamReconnectDecision {
        guard autoReconnectEnabled else {
            return .init(shouldReconnect: false, suppressionReason: .autoReconnectDisabled)
        }
        guard hasLaunchContext else {
            return .init(shouldReconnect: false, suppressionReason: .missingLaunchContext)
        }
        guard currentAttemptCount < maxAttempts else {
            return .init(shouldReconnect: false, suppressionReason: .attemptsExhausted)
        }

        switch intent {
        case .reconnectable, .serverInitiated:
            return .init(shouldReconnect: true, suppressionReason: nil)
        case .userInitiated, .reconnectTransition, .inactivityTimeout:
            return .init(
                shouldReconnect: false,
                suppressionReason: suppressionReason(for: intent)
            )
        }
    }

    func shouldReconnect(
        intent: StreamingDisconnectIntent,
        autoReconnectEnabled: Bool,
        currentAttemptCount: Int,
        hasLaunchContext: Bool
    ) -> Bool {
        decision(
            intent: intent,
            autoReconnectEnabled: autoReconnectEnabled,
            currentAttemptCount: currentAttemptCount,
            hasLaunchContext: hasLaunchContext
        ).shouldReconnect
    }

    func suppressionReason(
        for intent: StreamingDisconnectIntent
    ) -> StreamReconnectSuppressionReason {
        switch intent {
        case .userInitiated, .inactivityTimeout:
            return .userInitiatedDisconnect
        case .serverInitiated:
            return .serverInitiatedDisconnect
        case .reconnectTransition:
            return .reconnectTransition
        case .reconnectable:
            return .attemptsExhausted
        }
    }
}
