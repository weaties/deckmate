import Foundation

/// Thin wrapper over the Security framework for reading/writing a single
/// bearer token per server. The goal is to keep every Keychain API call
/// in this one file so tests can fake `KeychainStoring` cleanly.
///
/// v0.1 behaviour: one `kSecClassGenericPassword` entry per server, with
/// `kSecAttrAccount = server.baseURL.absoluteString` and the token as the
/// data payload. When we add biometric gating we'll set
/// `kSecAttrAccessControl` with `.biometryCurrentSet`.
public protocol KeychainStoring: Sendable {
    func read(account: String) throws -> Data?
    func write(account: String, data: Data) throws
    func delete(account: String) throws
}

public struct KeychainStore: KeychainStoring {
    public let service: String

    public init(service: String = "com.helmlog.deckmate") {
        self.service = service
    }

    public func read(account: String) throws -> Data? {
        var query: [String: Any] = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess: return item as? Data
        case errSecItemNotFound: return nil
        default: throw AuthError.keychainFailure(status)
        }
    }

    public func write(account: String, data: Data) throws {
        let query = baseQuery(account: account)
        let attributes: [String: Any] = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        if updateStatus == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            if addStatus != errSecSuccess { throw AuthError.keychainFailure(addStatus) }
            return
        }
        throw AuthError.keychainFailure(updateStatus)
    }

    public func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw AuthError.keychainFailure(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
