import XCTest
@testable import DeckMateKit

@MainActor
final class ServerConfigurationTests: XCTestCase {
    var defaults: UserDefaults!
    var keychain: FakeKeychain!
    let suiteName = "deckmate.tests.config"

    override func setUp() {
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        keychain = FakeKeychain()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testInitialStateIsUnconfigured() {
        let config = ServerConfiguration(userDefaults: defaults, keychain: keychain)
        XCTAssertNil(config.currentServer)
        XCTAssertNil(config.apiClient())
    }

    func testSavePersistsURLAndTokenAndSeedsAuthStore() async throws {
        let config = ServerConfiguration(userDefaults: defaults, keychain: keychain)
        let url = URL(string: "http://corvopi-tst1:3002")!

        try await config.save(url: url, bearerToken: "abc123")

        XCTAssertEqual(config.currentServer?.baseURL, url)
        XCTAssertEqual(defaults.string(forKey: "com.helmlog.deckmate.serverURL"), url.absoluteString)
        XCTAssertEqual(String(data: keychain.storage[url.absoluteString] ?? Data(), encoding: .utf8), "abc123")

        let credential = try await config.authStore.credential(for: ServerIdentity(baseURL: url))
        XCTAssertEqual(credential.headerValue, "Bearer abc123")
    }

    func testSaveTrimmsWhitespace() async throws {
        let config = ServerConfiguration(userDefaults: defaults, keychain: keychain)
        let url = URL(string: "http://corvopi-tst1:3002")!

        try await config.save(url: url, bearerToken: "   abc123\n ")

        let credential = try await config.authStore.credential(for: ServerIdentity(baseURL: url))
        XCTAssertEqual(credential.headerValue, "Bearer abc123")
    }

    func testSaveRejectsEmptyToken() async {
        let config = ServerConfiguration(userDefaults: defaults, keychain: keychain)
        let url = URL(string: "http://corvopi-tst1:3002")!

        do {
            try await config.save(url: url, bearerToken: "   ")
            XCTFail("expected .emptyToken")
        } catch ConfigurationError.emptyToken {
            // expected
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func testClearRemovesURLAndToken() async throws {
        let config = ServerConfiguration(userDefaults: defaults, keychain: keychain)
        let url = URL(string: "http://corvopi-tst1:3002")!
        try await config.save(url: url, bearerToken: "abc123")

        try await config.clear()

        XCTAssertNil(config.currentServer)
        XCTAssertNil(defaults.string(forKey: "com.helmlog.deckmate.serverURL"))
        XCTAssertNil(keychain.storage[url.absoluteString])
    }

    func testRestoreRehydratesFromPersistence() async throws {
        // First instance: save
        do {
            let config = ServerConfiguration(userDefaults: defaults, keychain: keychain)
            let url = URL(string: "http://corvopi-tst1:3002")!
            try await config.save(url: url, bearerToken: "abc123")
        }

        // Second instance with the same backing stores: should rehydrate
        let rehydrated = ServerConfiguration(userDefaults: defaults, keychain: keychain)
        XCTAssertEqual(
            rehydrated.currentServer?.baseURL.absoluteString,
            "http://corvopi-tst1:3002"
        )
        // Credential restore runs in a Task; give it a tick to complete.
        try await Task.sleep(nanoseconds: 10_000_000)
        let credential = try await rehydrated.authStore.credential(
            for: ServerIdentity(baseURL: URL(string: "http://corvopi-tst1:3002")!)
        )
        XCTAssertEqual(credential.headerValue, "Bearer abc123")
    }

    func testAPIClientReturnsNilWhenUnconfigured() {
        let config = ServerConfiguration(userDefaults: defaults, keychain: keychain)
        XCTAssertNil(config.apiClient())
    }

    func testAPIClientIsBuiltAfterSave() async throws {
        let config = ServerConfiguration(userDefaults: defaults, keychain: keychain)
        try await config.save(url: URL(string: "http://corvopi-tst1:3002")!, bearerToken: "abc123")
        XCTAssertNotNil(config.apiClient())
    }
}

/// In-memory `KeychainStoring` so tests don't touch the real Keychain.
final class FakeKeychain: KeychainStoring, @unchecked Sendable {
    var storage: [String: Data] = [:]

    func read(account: String) throws -> Data? {
        storage[account]
    }

    func write(account: String, data: Data) throws {
        storage[account] = data
    }

    func delete(account: String) throws {
        storage.removeValue(forKey: account)
    }
}
