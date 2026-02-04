import Foundation

/// Protocol for token persistence
public protocol TokenStorage: Sendable {
    /// Save credentials for a given key
    func save(_ credentials: GitHubCredentials, for key: String) async throws

    /// Retrieve credentials for a given key
    func retrieve(for key: String) async throws -> GitHubCredentials?

    /// Delete credentials for a given key
    func delete(for key: String) async throws

    /// Check if credentials exist for a given key
    func exists(for key: String) async -> Bool
}
