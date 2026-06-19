// StreamSessionKeepaliveTests.swift
// Exercises stream session keepalive and resumability behavior.
//

import Foundation
import Testing
@testable import XCloudAPI
import StratixModels

@Suite(.serialized)
struct StreamSessionKeepaliveTests {
    @Test
    func startKeepalive_sendsImmediatelyBeforeIntervalSleep() async {
        let client = makeKeepaliveClient()
        let streamSession = await StreamSession(
            apiClient: client,
            response: StreamSessionStartResponse(
                sessionPath: "v5/sessions/cloud/test-session",
                sessionId: "session-1"
            )
        )

        await streamSession.startKeepalive(interval: 60)

        try? await Task.sleep(for: .milliseconds(100))

        let keepaliveRequests = URLProtocolStub.recordedRequests().filter {
            $0.url?.path.hasSuffix("/keepalive") == true
        }
        #expect(keepaliveRequests.count == 1)
        await streamSession.stopKeepalive()
    }

    @Test
    func ensureStreamingKeepaliveIfNeeded_doesNotRestartExistingTask() async {
        let client = makeKeepaliveClient()
        let streamSession = await StreamSession(
            apiClient: client,
            response: StreamSessionStartResponse(
                sessionPath: "v5/sessions/cloud/test-session",
                sessionId: "session-2"
            )
        )

        await streamSession.startKeepalive(interval: 60)
        try? await Task.sleep(for: .milliseconds(100))
        await streamSession.ensureStreamingKeepaliveIfNeeded()
        try? await Task.sleep(for: .milliseconds(100))

        let keepaliveRequests = URLProtocolStub.recordedRequests().filter {
            $0.url?.path.hasSuffix("/keepalive") == true
        }
        #expect(keepaliveRequests.count == 1)
        await streamSession.stopKeepalive()
    }

    @Test
    func activateReconnectGraceKeepalive_sendsImmediatePingAndAcceleratesCadence() async {
        let client = makeKeepaliveClient()
        let streamSession = await StreamSession(
            apiClient: client,
            response: StreamSessionStartResponse(
                sessionPath: "v5/sessions/cloud/test-session",
                sessionId: "session-2b"
            )
        )

        await streamSession.startKeepalive(interval: 60)
        try? await Task.sleep(for: .milliseconds(100))
        await streamSession.activateReconnectGraceKeepalive()
        try? await Task.sleep(for: .milliseconds(100))

        let keepaliveRequests = URLProtocolStub.recordedRequests().filter {
            $0.url?.path.hasSuffix("/keepalive") == true
        }
        #expect(keepaliveRequests.count == 2)
        await streamSession.stopKeepalive()
    }

    @Test
    func sendKeepaliveNow_doesNotRestartExistingLoop() async {
        let client = makeKeepaliveClient()
        let streamSession = await StreamSession(
            apiClient: client,
            response: StreamSessionStartResponse(
                sessionPath: "v5/sessions/cloud/test-session",
                sessionId: "session-3"
            )
        )

        await streamSession.startKeepalive(interval: 60)
        try? await Task.sleep(for: .milliseconds(100))
        await streamSession.sendKeepaliveNow()
        try? await Task.sleep(for: .milliseconds(100))

        let keepaliveRequests = URLProtocolStub.recordedRequests().filter {
            $0.url?.path.hasSuffix("/keepalive") == true
        }
        #expect(keepaliveRequests.count == 2)
        await streamSession.stopKeepalive()
    }

    @Test
    func isResumableForWebRTCReconnect_acceptsProvisionedAndReadyToConnect() async throws {
        for state in ["Provisioned", "ReadyToConnect"] {
            let client = makeStateClient(state: state)
            let streamSession = await StreamSession(
                apiClient: client,
                response: StreamSessionStartResponse(
                    sessionPath: "v5/sessions/cloud/test-session",
                    sessionId: "session-4"
                )
            )

            let isResumable = try await streamSession.isResumableForWebRTCReconnect()
            #expect(isResumable == true)
        }
    }

    @Test
    func isResumableForWebRTCReconnect_rejectsTerminalStates() async throws {
        for state in ["Ended", "Terminated", "Provisioning"] {
            let client = makeStateClient(state: state)
            let streamSession = await StreamSession(
                apiClient: client,
                response: StreamSessionStartResponse(
                    sessionPath: "v5/sessions/cloud/test-session",
                    sessionId: "session-5"
                )
            )

            let isResumable = try await streamSession.isResumableForWebRTCReconnect()
            #expect(isResumable == false)
        }
    }
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) private static var requests: [URLRequest] = []

    static func reset(handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)) {
        lock.lock()
        defer { lock.unlock() }
        self.handler = handler
        requests.removeAll()
    }

    static func recordedRequests() -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        URLProtocolStub.lock.lock()
        URLProtocolStub.requests.append(request)
        let handler = URLProtocolStub.handler
        URLProtocolStub.lock.unlock()

        guard let handler else {
            client?.urlProtocol(
                self,
                didFailWithError: NSError(domain: "URLProtocolStub", code: 0)
            )
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if !data.isEmpty {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeKeepaliveClient() -> XCloudAPIClient {
    URLProtocolStub.reset { request in
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: 204,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        return (response, Data())
    }

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [URLProtocolStub.self]
    let session = URLSession(configuration: config)
    return XCloudAPIClient(baseHost: "https://example.com", gsToken: "gs-token", session: session)
}

private func makeStateClient(state: String) -> XCloudAPIClient {
    URLProtocolStub.reset { request in
        let body = try JSONSerialization.data(withJSONObject: ["state": state])
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, body)
    }

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [URLProtocolStub.self]
    let session = URLSession(configuration: config)
    return XCloudAPIClient(baseHost: "https://example.com", gsToken: "gs-token", session: session)
}