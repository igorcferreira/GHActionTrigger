import Foundation

/// Environment variable authentication provider (highest priority for CI/CD)
public final class EnvironmentAuthProvider: AuthenticationProvider, Sendable {
    public let providerIdentifier = "environment"
    public let priority = 0 // Highest priority

    private let environmentKey: String

    public init(environmentKey: String = "GITHUB_TOKEN") {
        self.environmentKey = environmentKey
    }

    public func canProvideCredentials() async -> Bool {
        ProcessInfo.processInfo.environment[environmentKey] != nil
    }

    public func getCredentials() async throws -> GitHubCredentials {
        guard let token = ProcessInfo.processInfo.environment[environmentKey] else {
            throw AuthenticationError.noCredentialsAvailable
        }

        guard !token.isEmpty else {
            throw AuthenticationError.emptyToken
        }

        return GitHubCredentials(
            accessToken: token,
            tokenType: .environment,
            scope: nil,
            createdAt: Date(),
            expiresAt: nil
        )
    }

    public func clearCredentials() async throws {
        // Cannot clear environment variables
        throw AuthenticationError.cannotClearEnvironmentCredentials
    }
}
