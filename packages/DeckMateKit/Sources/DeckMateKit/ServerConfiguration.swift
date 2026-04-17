import Foundation
import Observation

#if canImport(DeckMateAPI)
import DeckMateAPI
#endif
#if canImport(DeckMateAuth)
import DeckMateAuth
#endif

/// App-wide persistent configuration: which HelmLog server the user is
/// pointed at, and the bearer token used to authenticate against it.
///
/// Splits persistence across two stores:
///
/// - **`UserDefaults`** for the server URL. Not secret, cheap to read
///   synchronously at launch, survives reinstall only if iCloud backup
///   is enabled (fine for a non-sensitive preference).
/// - **`KeychainStoring`** for the bearer token. Encrypted at rest, scoped
///   to this app's entitlement, never in plaintext on disk.
///
/// Exposed as `@Observable @MainActor` so SwiftUI views can read
/// `currentServer` directly and react to save/clear without refetching.
@Observable
@MainActor
public final class ServerConfiguration {
    public private(set) var currentServer: ServerIdentity?

    public let authStore: BearerTokenAuthStore

    private let userDefaults: UserDefaults
    private let keychain: any KeychainStoring
    private let serverURLKey = "com.helmlog.deckmate.serverURL"

    public init(
        userDefaults: UserDefaults = .standard,
        keychain: any KeychainStoring = KeychainStore()
    ) {
        self.userDefaults = userDefaults
        self.keychain = keychain
        self.authStore = BearerTokenAuthStore()
        self.restoreFromPersistence()
    }

    /// Construct an `APIClient` pointed at the current server, or `nil`
    /// if the user hasn't configured one yet. Called by screens that
    /// need to make HTTP requests.
    public func apiClient() -> APIClient? {
        guard let server = currentServer else { return nil }
        return APIClient(server: server, auth: authStore)
    }

    /// Save a new server URL + bearer token. Writes both persistence
    /// layers, then updates the in-memory auth store so the next API
    /// call has the credential.
    ///
    /// - Parameters:
    ///   - url: the server's base URL (e.g. `http://corvopi-tst1:3002`).
    ///   - bearerToken: the raw token string (without `Bearer ` prefix).
    public func save(url: URL, bearerToken: String) async throws {
        let trimmedToken = bearerToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            throw ConfigurationError.emptyToken
        }

        let server = ServerIdentity(baseURL: url)
        userDefaults.set(url.absoluteString, forKey: serverURLKey)

        guard let data = trimmedToken.data(using: .utf8) else {
            throw ConfigurationError.invalidToken
        }
        try keychain.write(account: url.absoluteString, data: data)

        await authStore.set(
            Credential(headerValue: "Bearer \(trimmedToken)"),
            for: server
        )
        currentServer = server
    }

    /// Forget the current server — removes the URL from `UserDefaults`,
    /// the token from the Keychain, and clears the in-memory auth store.
    public func clear() async throws {
        if let server = currentServer {
            try keychain.delete(account: server.baseURL.absoluteString)
            try await authStore.clear(for: server)
        }
        userDefaults.removeObject(forKey: serverURLKey)
        currentServer = nil
    }

    private func restoreFromPersistence() {
        guard
            let raw = userDefaults.string(forKey: serverURLKey),
            let url = URL(string: raw)
        else { return }

        let server = ServerIdentity(baseURL: url)
        currentServer = server

        // Pull the token out of the Keychain and prime the auth store.
        // If the token isn't there (e.g. Keychain was wiped), the URL
        // survives so the Settings screen shows the server but the user
        // is prompted to re-enter the token.
        if let data = try? keychain.read(account: url.absoluteString),
           let tokenString = String(data: data, encoding: .utf8) {
            Task {
                await authStore.set(
                    Credential(headerValue: "Bearer \(tokenString)"),
                    for: server
                )
            }
        }
    }
}

public enum ConfigurationError: Error, Sendable, Equatable {
    case emptyToken
    case invalidToken
}
