import Foundation

/// Typed errors surfaced by `APIClient`. Views switch over this to render
/// a specific message for each failure — don't catch and rethrow as
/// generic `Error` at call sites.
public enum APIError: Error, Sendable, Equatable {
    case invalidURL(String)
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case client(Int)
    case server(Int)
    case decodingFailed(Error)
    case notImplemented

    public static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL(let l), .invalidURL(let r)): return l == r
        case (.invalidResponse, .invalidResponse): return true
        case (.unauthorized, .unauthorized): return true
        case (.forbidden, .forbidden): return true
        case (.notFound, .notFound): return true
        case (.client(let l), .client(let r)): return l == r
        case (.server(let l), .server(let r)): return l == r
        case (.decodingFailed, .decodingFailed): return true
        case (.notImplemented, .notImplemented): return true
        default: return false
        }
    }
}
