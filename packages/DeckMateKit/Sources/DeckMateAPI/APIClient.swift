import Foundation
import DeckMateAuth
import DeckMateModels
import os

/// Live client against a HelmLog server.
///
/// Design goals:
///   - No singletons. A client is constructed with a `ServerIdentity`
///     and an `AuthStore`; callers inject it where they need it.
///   - Every call is `async throws` and surfaces a typed `APIError`.
///   - The transport (`URLSession`) is overridable so tests can inject
///     a `URLProtocol` stub.
///
/// This class intentionally only sketches the surface. Implementations of
/// `sessions()`, `track(for:)`, etc. are TODOs — filling them in is part
/// of the learning exercise and the v0.1 PRs.
public final class APIClient: Sendable {
    public let server: ServerIdentity
    public let auth: any AuthStore
    public let session: URLSession

    private static let log = Logger(subsystem: "com.helmlog.deckmate.api", category: "APIClient")

    public init(
        server: ServerIdentity,
        auth: any AuthStore,
        session: URLSession = .shared
    ) {
        self.server = server
        self.auth = auth
        self.session = session
    }

    // MARK: - History browser endpoints (v0.1)

    /// `GET /api/sessions` — paginated list of sessions for the logged-in boat.
    ///
    /// - Parameters:
    ///   - limit: maximum number of sessions to return (server clamps to 200).
    ///   - offset: skip this many sessions. For offset-based pagination.
    ///   - query: free-text search over session name and event. `nil` for no filter.
    ///   - kind: restrict to one `Session.Kind`. `nil` for all kinds.
    /// - Returns: a `SessionListPage` with `total` (server-side unfiltered
    ///   count) and the decoded `sessions` slice.
    public func sessions(
        limit: Int = 25,
        offset: Int = 0,
        query: String? = nil,
        kind: Session.Kind? = nil
    ) async throws -> SessionListPage {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        if let query { items.append(URLQueryItem(name: "q", value: query)) }
        if let kind { items.append(URLQueryItem(name: "type", value: kind.rawValue)) }
        return try await get(path: "/api/sessions", query: items)
    }

    /// `GET /api/sessions/{id}/track` — the session's GPS polyline.
    ///
    /// The server returns a GeoJSON `FeatureCollection`; we flatten it
    /// into a domain `Track` so callers don't deal with the envelope.
    /// Returns an empty track (not `throw`) if the session exists but
    /// has no recorded fixes.
    public func track(for sessionId: Int) async throws -> Track {
        let wire: TrackGeoJSON = try await get(path: "/api/sessions/\(sessionId)/track")
        return wire.toTrack(sessionId: sessionId)
    }

    /// `GET /api/polar` — current polar baseline for the logged-in boat.
    public func polar() async throws -> Polar {
        try await get(path: "/api/polar")
    }

    // MARK: - Live race-day endpoints (v0.1)

    /// A stream of live `InstrumentTick`s. v0.1 plan: subscribe to the
    /// HelmLog relay WebSocket at `/ws/instruments` and re-emit decoded
    /// ticks on an `AsyncStream` until the caller cancels.
    public func liveInstruments() -> AsyncThrowingStream<InstrumentTick, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: APIError.notImplemented)
            // TODO(v0.1): open `URLSessionWebSocketTask` and forward decoded ticks.
        }
    }

    /// `POST /api/sessions/start` — begin a race/practice session.
    public func startSession(name: String) async throws -> Session {
        try await post(path: "/api/sessions/start", body: ["name": name])
    }

    /// `POST /api/sessions/{id}/stop` — end a running session.
    public func stopSession(_ id: Int) async throws -> Session {
        try await post(path: "/api/sessions/\(id)/stop", body: [String: String]())
    }

    /// `POST /api/marks` — drop a race mark at the current boat position.
    public func dropMark(label: String) async throws {
        _ = try await postNoReturn(path: "/api/marks", body: ["label": label])
    }

    // MARK: - Internal helpers

    private func get<T: Decodable>(
        path: String,
        query: [URLQueryItem] = []
    ) async throws -> T {
        var request = try await baseRequest(path: path, query: query)
        request.httpMethod = "GET"
        return try await send(request)
    }

    private func post<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T {
        var request = try await baseRequest(path: path)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try DeckMateJSON.encoder.encode(body)
        return try await send(request)
    }

    private func postNoReturn<B: Encodable>(path: String, body: B) async throws -> Data {
        var request = try await baseRequest(path: path)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try DeckMateJSON.encoder.encode(body)
        let (data, response) = try await session.data(for: request)
        try Self.checkStatus(response)
        return data
    }

    private func baseRequest(
        path: String,
        query: [URLQueryItem] = []
    ) async throws -> URLRequest {
        guard
            let resolved = URL(string: path, relativeTo: server.baseURL),
            var components = URLComponents(url: resolved, resolvingAgainstBaseURL: true)
        else {
            throw APIError.invalidURL(path)
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            throw APIError.invalidURL(path)
        }
        var request = URLRequest(url: url)
        let credential = try await auth.credential(for: server)
        request.setValue(credential.headerValue, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        try Self.checkStatus(response)
        do {
            return try DeckMateJSON.decoder.decode(T.self, from: data)
        } catch {
            Self.log.error("decode failed for \(request.url?.absoluteString ?? "-"): \(error)")
            throw APIError.decodingFailed(error)
        }
    }

    private static func checkStatus(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        switch http.statusCode {
        case 200..<300: return
        case 401: throw APIError.unauthorized
        case 403: throw APIError.forbidden
        case 404: throw APIError.notFound
        case 400..<500: throw APIError.client(http.statusCode)
        default: throw APIError.server(http.statusCode)
        }
    }
}
