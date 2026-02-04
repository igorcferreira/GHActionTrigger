import Foundation
import Security

/// macOS Keychain-based token storage
public final class KeychainStorage: TokenStorage, @unchecked Sendable {
    private let serviceName: String
    private let accessGroup: String?
    private let lock = NSLock()

    public init(
        serviceName: String = "com.ghactiontrigger.auth",
        accessGroup: String? = nil
    ) {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
    }

    public func save(_ credentials: GitHubCredentials, for key: String) async throws {
        let data = try JSONEncoder().encode(credentials)

        try lock.withLock {
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: key,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]

            if let accessGroup {
                query[kSecAttrAccessGroup as String] = accessGroup
            }

            // Delete existing item first
            var deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: key
            ]
            if let accessGroup {
                deleteQuery[kSecAttrAccessGroup as String] = accessGroup
            }
            SecItemDelete(deleteQuery as CFDictionary)

            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw AuthenticationError.keychainError(status: status, operation: "save")
            }
        }
    }

    public func retrieve(for key: String) async throws -> GitHubCredentials? {
        try lock.withLock {
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: key,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]

            if let accessGroup {
                query[kSecAttrAccessGroup as String] = accessGroup
            }

            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)

            switch status {
            case errSecSuccess:
                guard let data = result as? Data else {
                    throw AuthenticationError.keychainError(status: status, operation: "retrieve")
                }
                return try JSONDecoder().decode(GitHubCredentials.self, from: data)
            case errSecItemNotFound:
                return nil
            default:
                throw AuthenticationError.keychainError(status: status, operation: "retrieve")
            }
        }
    }

    public func delete(for key: String) async throws {
        try lock.withLock {
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: key
            ]

            if let accessGroup {
                query[kSecAttrAccessGroup as String] = accessGroup
            }

            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw AuthenticationError.keychainError(status: status, operation: "delete")
            }
        }
    }

    public func exists(for key: String) async -> Bool {
        do {
            return try await retrieve(for: key) != nil
        } catch {
            return false
        }
    }
}
