import Foundation

/// Protocol defining the interface for authentication providers
public protocol AuthenticationProvider: Sendable {
    /// Unique identifier for this provider
    var providerIdentifier: String { get }

    /// Priority level (lower = higher priority)
    var priority: Int { get }

    /// Check if this provider can provide credentials without user interaction
    func canProvideCredentials() async -> Bool

    /// Attempt to retrieve credentials
    func getCredentials() async throws -> GitHubCredentials

    /// Authenticate interactively (if supported)
    func authenticate() async throws -> GitHubCredentials

    /// Clear any stored credentials
    func clearCredentials() async throws
}

/// Default implementation for non-interactive providers
extension AuthenticationProvider {
    public func authenticate() async throws -> GitHubCredentials {
        throw AuthenticationError.interactiveAuthNotSupported(provider: providerIdentifier)
    }
}
