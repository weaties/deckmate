import Foundation

/// The envelope returned by `GET /api/sessions` on the HelmLog server:
/// `{ "total": Int, "sessions": [Session, ...] }`.
///
/// `total` is the server-side count of sessions matching the query
/// (independent of `limit`/`offset`), useful for paginated UIs that want
/// to show "42 of 1,250 results".
public struct SessionListPage: Decodable, Hashable, Sendable {
    public let total: Int
    public let sessions: [Session]

    public init(total: Int, sessions: [Session]) {
        self.total = total
        self.sessions = sessions
    }
}
