import XCTest
@testable import DeckMateAuth

final class BearerTokenAuthStoreTests: XCTestCase {
    func testReturnsStoredCredential() async throws {
        let server = ServerIdentity(baseURL: URL(string: "https://boat.local")!)
        let store = BearerTokenAuthStore()
        await store.set(Credential(headerValue: "Bearer xyz"), for: server)

        let c = try await store.credential(for: server)
        XCTAssertEqual(c.headerValue, "Bearer xyz")
    }

    func testMissingCredentialThrows() async {
        let server = ServerIdentity(baseURL: URL(string: "https://boat.local")!)
        let store = BearerTokenAuthStore()

        do {
            _ = try await store.credential(for: server)
            XCTFail("expected missingCredential")
        } catch let e as AuthError {
            XCTAssertEqual(e, .missingCredential)
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func testExpiredCredentialThrows() async {
        let server = ServerIdentity(baseURL: URL(string: "https://boat.local")!)
        let store = BearerTokenAuthStore()
        let past = Date.now.addingTimeInterval(-60)
        await store.set(Credential(headerValue: "Bearer old", expiresAt: past), for: server)

        do {
            _ = try await store.credential(for: server)
            XCTFail("expected missingCredential for expired token")
        } catch let e as AuthError {
            XCTAssertEqual(e, .missingCredential)
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func testClearRemovesCredential() async throws {
        let server = ServerIdentity(baseURL: URL(string: "https://boat.local")!)
        let store = BearerTokenAuthStore()
        await store.set(Credential(headerValue: "Bearer xyz"), for: server)

        try await store.clear(for: server)

        do {
            _ = try await store.credential(for: server)
            XCTFail("expected missingCredential after clear")
        } catch let e as AuthError {
            XCTAssertEqual(e, .missingCredential)
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }
}
