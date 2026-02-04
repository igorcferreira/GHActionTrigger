import Foundation

/// Personal Access Token authentication provider
public final class PATAuthProvider: AuthenticationProvider, @unchecked Sendable {
    public let providerIdentifier = "pat"
    public let priority = 2

    private let storage: any TokenStorage
    private let storageKey = "github-pat-token"

    public init(storage: any TokenStorage) {
        self.storage = storage
    }

    public func canProvideCredentials() async -> Bool {
        await storage.exists(for: storageKey)
    }

    public func getCredentials() async throws -> GitHubCredentials {
        guard let credentials = try await storage.retrieve(for: storageKey) else {
            throw AuthenticationError.noCredentialsAvailable
        }
        return credentials
    }

    /// Store a PAT directly (non-interactive)
    public func storeToken(_ token: String) async throws -> GitHubCredentials {
        guard !token.isEmpty else {
            throw AuthenticationError.emptyToken
        }

        // Validate the token first
        let isValid = try await validateToken(token)
        guard isValid else {
            throw AuthenticationError.invalidToken
        }

        let credentials = GitHubCredentials(
            accessToken: token,
            tokenType: .pat,
            scope: nil, // PATs don't have scope metadata accessible
            createdAt: Date(),
            expiresAt: nil // Classic PATs don't expire; fine-grained PATs do
        )

        try await storage.save(credentials, for: storageKey)
        return credentials
    }

    public func clearCredentials() async throws {
        try await storage.delete(for: storageKey)
    }

    // MARK: - Private Methods

    private func validateToken(_ token: String) async throws -> Bool {
        guard let url = URL(string: "https://api.github.com/user") else {
            return false
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        return httpResponse.statusCode == 200
    }
}
