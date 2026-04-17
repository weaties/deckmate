import XCTest
@testable import DeckMateAPI
@testable import DeckMateAuth
@testable import DeckMateModels

/// Uses `URLProtocol` to intercept `URLSession` traffic so we can assert
/// request/response behaviour without a live server. This is the idiomatic
/// way to test `URLSession`-based clients in Swift — study StubURLProtocol
/// below to see how it plugs in.
final class APIClientTests: XCTestCase {
    override func setUp() {
        StubURLProtocol.reset()
    }

    func testSessionsDecodesResponse() async throws {
        StubURLProtocol.stub(
            path: "/api/sessions",
            status: 200,
            json: """
            [
                {
                    "id": 1, "type": "race", "name": "R1",
                    "start_utc": "2026-04-17T18:00:00.000Z",
                    "end_utc": null
                }
            ]
            """
        )

        let client = makeClient()
        let sessions = try await client.sessions()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].id, 1)
        XCTAssertEqual(sessions[0].name, "R1")
    }

    func testUnauthorizedMapsToAPIError() async {
        StubURLProtocol.stub(path: "/api/sessions", status: 401, json: "{}")
        let client = makeClient()

        do {
            _ = try await client.sessions()
            XCTFail("expected .unauthorized")
        } catch let e as APIError {
            XCTAssertEqual(e, .unauthorized)
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    // MARK: - helpers

    private func makeClient() -> APIClient {
        let server = ServerIdentity(baseURL: URL(string: "https://boat.local")!)
        let auth = BearerTokenAuthStore()
        let credential = Credential(headerValue: "Bearer test")
        let expectation = XCTestExpectation()
        Task { await auth.set(credential, for: server); expectation.fulfill() }
        wait(for: [expectation], timeout: 1)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)

        return APIClient(server: server, auth: auth, session: session)
    }
}

/// Minimal URLProtocol stub. Swap `stub(path:status:json:)` per-test.
final class StubURLProtocol: URLProtocol {
    struct Stub { let status: Int; let body: Data }
    nonisolated(unsafe) private static var stubs: [String: Stub] = [:]

    static func reset() { stubs.removeAll() }
    static func stub(path: String, status: Int, json: String) {
        stubs[path] = Stub(status: status, body: json.data(using: .utf8)!)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard
            let url = request.url,
            let stub = Self.stubs[url.path]
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let response = HTTPURLResponse(
            url: url, statusCode: stub.status,
            httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
