import Foundation

/// The simplest possible `AuthStore`: one bearer token per server, held in
/// memory. Wrap this with a `KeychainStore`-backed variant (or the future
/// `BiometricGatedAuthStore`) before shipping.
///
/// This exists mainly for tests and for the initial "it compiles and
/// returns a credential" milestone.
public actor BearerTokenAuthStore: AuthStore {
    private var tokens: [ServerIdentity: Credential] = [:]

    public init(initial: [ServerIdentity: Credential] = [:]) {
        self.tokens = initial
    }

    public func set(_ credential: Credential, for server: ServerIdentity) {
        tokens[server] = credential
    }

    public func credential(for server: ServerIdentity) async throws -> Credential {
        guard let c = tokens[server] else { throw AuthError.missingCredential }
        if c.isExpired { throw AuthError.missingCredential }
        return c
    }

    public func clear(for server: ServerIdentity) async throws {
        tokens.removeValue(forKey: server)
    }
}
