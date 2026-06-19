// StreamSession.swift
// Defines stream session.
//

import Foundation
import DiagnosticsKit
import os
import StratixModels

/// Manages the lifecycle of a single xCloud/xHome streaming session.
/// Mirrors the state machine in xbox-xcloud-player's stream.ts.
public actor StreamSession {

    public enum State: Sendable, Equatable {
        case new
        case provisioning
        case provisioned
        case readyToConnect
        case error(String)
    }

    private let apiClient: XCloudAPIClient
    private let sessionPath: String
    public let sessionId: String

    private var state: State = .new
    private var keepaliveTask: Task<Void, Never>?
    private let logger = GLogger(category: .streaming)

    public init(apiClient: XCloudAPIClient, response: StreamSessionStartResponse) {
        self.apiClient = apiClient
        self.sessionId = response.sessionId ?? UUID().uuidString
        // sessionPath from server is relative e.g. "v5/sessions/home/XXXX"
        self.sessionPath = "/" + response.sessionPath
    }

    // MARK: - State polling

    /// Waits until the server signals one of the target states, then returns.
    @discardableResult
    public func waitForStates(
        _ targetStates: Set<String>,
        pollInterval: TimeInterval = 1.0,
        timeout: TimeInterval = 60,
        titleId: String? = nil,
        onIntermediateState: (@Sendable (String, Int?) -> Void)? = nil
    ) async throws -> State {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let stateResp: StreamStateResponse
            do {
                stateResp = try await apiClient.getSessionState(sessionPath: sessionPath)
            } catch {
                logger.error("Session state poll failed: \(error.localizedDescription)")
                throw StreamError(code: .signaling, message: "State poll error: \(error.localizedDescription)")
            }

            logger.info("Session state: \(stateResp.state)")

            if targetStates.contains(stateResp.state) {
                switch stateResp.state {
                case "ReadyToConnect":
                    self.state = .readyToConnect
                case "Provisioned":
                    self.state = .provisioned
                case "Provisioning", "WaitingForResources":
                    self.state = .provisioning
                default:
                    break
                }
                return self.state
            }

            switch stateResp.state {
            case "Provisioned":
                self.state = .provisioned
            case "Provisioning":
                self.state = .provisioning
            case "WaitingForResources":
                self.state = .provisioning
                var waitSecs: Int?
                if let tid = titleId {
                    waitSecs = try? await apiClient.getWaitTime(sessionPath: sessionPath, titleId: tid)?.estimatedTotalWaitTimeInSeconds
                }
                onIntermediateState?("WaitingForResources", waitSecs)
            default:
                if let err = stateResp.errorDetails {
                    logger.error("Session error from server: \(err.code): \(err.message)")
                    throw StreamError(code: .signaling, message: "\(err.code): \(err.message)")
                }
                logger.warning("Unknown session state: \(stateResp.state)")
            }
            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
        let wanted = targetStates.sorted().joined(separator: ", ")
        throw StreamError(code: .signaling, message: "Timed out waiting for \(wanted)")
    }

    /// Waits until the server signals ReadyToConnect, then returns.
    public func waitUntilReady(pollInterval: TimeInterval = 1.0, timeout: TimeInterval = 60) async throws {
        try await waitForStates(["ReadyToConnect"], pollInterval: pollInterval, timeout: timeout)
    }

    /// Waits until the server signals ReadyToConnect or Provisioned.
    public func waitUntilReadyOrProvisioned(
        pollInterval: TimeInterval = 1.0,
        timeout: TimeInterval = 60,
        titleId: String? = nil,
        onIntermediateState: (@Sendable (String, Int?) -> Void)? = nil
    ) async throws -> State {
        try await waitForStates(
            ["ReadyToConnect", "Provisioned"],
            pollInterval: pollInterval,
            timeout: timeout,
            titleId: titleId,
            onIntermediateState: onIntermediateState
        )
    }

    /// Waits until the server signals Provisioned, then returns.
    public func waitUntilProvisioned(
        pollInterval: TimeInterval = 1.0,
        timeout: TimeInterval = 60,
        titleId: String? = nil,
        onIntermediateState: (@Sendable (String, Int?) -> Void)? = nil
    ) async throws {
        try await waitForStates(
            ["Provisioned"],
            pollInterval: pollInterval,
            timeout: timeout,
            titleId: titleId,
            onIntermediateState: onIntermediateState
        )
    }

    // MARK: - SDP Exchange

    /// Sends our local SDP offer and returns the server's SDP answer.
    public func exchangeSDP(localSDP: String) async throws -> String {
        try await apiClient.sendSDPOffer(sessionPath: sessionPath, sdp: localSDP)
    }

    // MARK: - ICE Exchange

    /// Sends local ICE candidates and returns remote candidates.
    public func exchangeICE(localCandidates: [IceCandidatePayload], preferIPv6: Bool = false) async throws -> [IceCandidatePayload] {
        try await apiClient.sendICECandidates(sessionPath: sessionPath, candidates: localCandidates, preferIPv6: preferIPv6)
    }

    // MARK: - MSAL Auth

    public func sendMSALAuth(userToken: String) async throws {
        try await apiClient.sendMSALAuth(sessionPath: sessionPath, userToken: userToken)
    }

    // MARK: - Keepalive

    /// Backup HTTP keepalive while WebRTC transport is healthy. Keep this conservative:
    /// frequent pings during an active stream can make xCloud tear the session down early.
    public static let streamingKeepaliveInterval: TimeInterval = 30
    /// Faster cadence used only after WebRTC drops to keep the provisioned VM resumable.
    public static let reconnectGraceKeepaliveInterval: TimeInterval = 8

    private var keepaliveInterval: TimeInterval = streamingKeepaliveInterval

    public func startKeepalive(interval: TimeInterval = streamingKeepaliveInterval) {
        keepaliveInterval = interval
        scheduleKeepalive(sendImmediately: true)
    }

    /// Starts the conservative streaming cadence only when keepalive is not already running.
    public func ensureStreamingKeepaliveIfNeeded() {
        guard keepaliveTask == nil else { return }
        startKeepalive()
    }

    /// Restores the conservative streaming cadence after WebRTC reconnects.
    public func restoreStreamingKeepalive() {
        guard keepaliveInterval != Self.streamingKeepaliveInterval else { return }
        keepaliveInterval = Self.streamingKeepaliveInterval
        scheduleKeepalive(sendImmediately: false)
    }

    /// Sends an immediate keepalive without cancelling the active keepalive loop.
    public func sendKeepaliveNow() async {
        try? await apiClient.sendKeepalive(sessionPath: sessionPath)
    }

    /// Pings immediately and switches to the reconnect grace cadence after transport loss.
    public func activateReconnectGraceKeepalive() async {
        await sendKeepaliveNow()
        guard keepaliveInterval > Self.reconnectGraceKeepaliveInterval || keepaliveTask == nil else {
            return
        }
        keepaliveInterval = Self.reconnectGraceKeepaliveInterval
        scheduleKeepalive(sendImmediately: false)
    }

    public func stopKeepalive() {
        keepaliveTask?.cancel()
        keepaliveTask = nil
    }

    private func scheduleKeepalive(sendImmediately: Bool) {
        stopKeepalive()
        let sessionPath = sessionPath
        let apiClient = apiClient
        let interval = keepaliveInterval
        keepaliveTask = Task {
            if sendImmediately {
                try? await apiClient.sendKeepalive(sessionPath: sessionPath)
            }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { break }
                try? await apiClient.sendKeepalive(sessionPath: sessionPath)
            }
        }
    }

    /// Returns whether the server-side session can accept a WebRTC-only reconnect.
    public func isResumableForWebRTCReconnect() async throws -> Bool {
        let stateResp = try await apiClient.getSessionState(sessionPath: sessionPath)
        switch stateResp.state {
        case "Provisioned", "ReadyToConnect":
            return true
        default:
            return false
        }
    }

    // MARK: - Stop

    public func stop() async throws {
        stopKeepalive()
        try await apiClient.stopSession(sessionPath: sessionPath)
        self.state = .new
    }
}
