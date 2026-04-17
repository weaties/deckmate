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

    func testSessionsDecodesEnvelope() async throws {
        StubURLProtocol.stub(
            path: "/api/sessions",
            status: 200,
            json: """
            {
                "total": 42,
                "sessions": [
                    {
                        "id": 1, "type": "race", "name": "R1",
                        "start_utc": "2026-04-17T18:00:00.000Z",
                        "end_utc": null
                    },
                    {
                        "id": 2, "type": "practice", "name": "P1",
                        "start_utc": "2026-04-18T12:00:00.000Z",
                        "end_utc": "2026-04-18T13:30:00.000Z"
                    }
                ]
            }
            """
        )

        let client = makeClient()
        let page = try await client.sessions(limit: 25, offset: 0)
        XCTAssertEqual(page.total, 42)
        XCTAssertEqual(page.sessions.count, 2)
        XCTAssertEqual(page.sessions[0].id, 1)
        XCTAssertEqual(page.sessions[0].kind, .race)
        XCTAssertEqual(page.sessions[1].kind, .practice)
    }

    func testSessionsAppendsQueryItems() async throws {
        StubURLProtocol.stub(
            path: "/api/sessions",
            status: 200,
            json: #"{"total": 0, "sessions": []}"#
        )

        let client = makeClient()
        _ = try await client.sessions(limit: 50, offset: 25, query: "frostbite", kind: .race)

        let captured = StubURLProtocol.lastRequest
        XCTAssertEqual(captured?.url?.path, "/api/sessions")
        let query = captured.flatMap { $0.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } } ?? []
        XCTAssertTrue(query.contains(URLQueryItem(name: "limit", value: "50")))
        XCTAssertTrue(query.contains(URLQueryItem(name: "offset", value: "25")))
        XCTAssertTrue(query.contains(URLQueryItem(name: "q", value: "frostbite")))
        XCTAssertTrue(query.contains(URLQueryItem(name: "type", value: "race")))
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

/// Minimal URLProtocol stub. Swap `stub(path:status:json:)` per-test; inspect
/// `lastRequest` after the call to assert on the outgoing URL/headers/body.
final class StubURLProtocol: URLProtocol {
    struct Stub { let status: Int; let body: Data }
    nonisolated(unsafe) private static var stubs: [String: Stub] = [:]
    nonisolated(unsafe) static var lastRequest: URLRequest?

    static func reset() {
        stubs.removeAll()
        lastRequest = nil
    }
    static func stub(path: String, status: Int, json: String) {
        stubs[path] = Stub(status: status, body: json.data(using: .utf8)!)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
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
