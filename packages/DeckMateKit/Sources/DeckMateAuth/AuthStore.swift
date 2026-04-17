import Foundation

/// Pluggable authentication store. Every feature that needs a credential
/// goes through this protocol — never URLSession.shared's default cookies
/// and never a concrete token shoved into an HTTP header by the caller.
///
/// v0.1 ships `BearerTokenAuthStore` which keeps a single token in the
/// Keychain. Future implementations slot in behind the same protocol:
///
///   - `MagicLinkAuthStore`          — reuse the server's cookie flow
///   - `SignInWithAppleAuthStore`    — native Apple ID → exchanged bearer
///   - `BiometricGatedAuthStore`     — wraps any store, gated by Face/Touch ID
///   - `DevicePairingAuthStore`      — uses the device bearer tokens (#423)
///
/// The important bit: callers ask for `credential(for:)` each request; the
/// store decides whether to refresh, prompt the user, or fail.
public protocol AuthStore: Sendable {
    /// Returns an Authorization header value (e.g. `"Bearer xyz"`) valid
    /// at the time of call. Throws if authentication is unavailable —
    /// callers should surface that as a login prompt, not a generic error.
    func credential(for server: ServerIdentity) async throws -> Credential

    /// Forget the credential for this server (logout).
    func clear(for server: ServerIdentity) async throws
}

/// Identifies which boat / server a credential belongs to. A user can
/// have multiple boats and the Keychain should scope per-server.
public struct ServerIdentity: Hashable, Sendable, Codable {
    public let baseURL: URL
    /// Optional short label shown in UI ("My boat", "Friend's boat").
    public let nickname: String?

    public init(baseURL: URL, nickname: String? = nil) {
        self.baseURL = baseURL
        self.nickname = nickname
    }
}

/// The credential returned by `AuthStore`. Today this is an opaque bearer
/// token; if we move to signed requests, add a `sign(request:)` hook.
public struct Credential: Sendable, Hashable {
    public let headerValue: String
    public let expiresAt: Date?

    public init(headerValue: String, expiresAt: Date? = nil) {
        self.headerValue = headerValue
        self.expiresAt = expiresAt
    }

    public var isExpired: Bool {
        guard let e = expiresAt else { return false }
        return Date.now >= e
    }
}

/// Errors every `AuthStore` should throw. Keep this exhaustive so the UI
/// can switch over it and render a specific message for each case.
public enum AuthError: Error, Sendable, Equatable {
    case missingCredential
    case biometricsUnavailable
    case biometricsDenied
    case keychainFailure(OSStatus)
    case networkFailure
}
