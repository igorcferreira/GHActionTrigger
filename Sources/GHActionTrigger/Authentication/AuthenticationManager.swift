import Foundation

/// Central manager for GitHub authentication
public actor AuthenticationManager {
    private var providers: [any AuthenticationProvider]
    private let storage: any TokenStorage
    private var cachedCredentials: GitHubCredentials?

    /// Create default providers in priority order
    public static func defaultProviders(
        storage: any TokenStorage,
        clientId: String
    ) -> [any AuthenticationProvider] {
        [
            EnvironmentAuthProvider(),                          // Priority 0 - CI/CD
            DeviceFlowAuthProvider(clientId: clientId, storage: storage), // Priority 1 - Interactive
            PATAuthProvider(storage: storage)                   // Priority 2 - Fallback
        ]
    }

    public init(
        providers: [any AuthenticationProvider]? = nil,
        storage: any TokenStorage = KeychainStorage(),
        clientId: String = Configuration.defaultClientId
    ) {
        self.storage = storage
        self.providers = (providers ?? Self.defaultProviders(storage: storage, clientId: clientId))
            .sorted { $0.priority < $1.priority }
    }

    /// Get credentials from the first available provider
    public func getCredentials() async throws -> GitHubCredentials {
        // Check cache first
        if let cached = cachedCredentials, !cached.isExpired {
            return cached
        }

        // Try each provider in priority order
        for provider in providers {
            if await provider.canProvideCredentials() {
                do {
                    let credentials = try await provider.getCredentials()
                    if !credentials.isExpired {
                        cachedCredentials = credentials
                        return credentials
                    }
                } catch {
                    // Log and continue to next provider
                    continue
                }
            }
        }

        throw AuthenticationError.noCredentialsAvailable
    }

    /// Authenticate interactively using the specified provider
    public func authenticate(using providerIdentifier: String? = nil) async throws -> GitHubCredentials {
        let provider: any AuthenticationProvider

        if let identifier = providerIdentifier {
            guard let found = providers.first(where: { $0.providerIdentifier == identifier }) else {
                throw AuthenticationError.providerNotFound(identifier)
            }
            provider = found
        } else {
            // Use DeviceFlow as default interactive provider
            guard let deviceFlow = providers.first(where: { $0 is DeviceFlowAuthProvider }) else {
                throw AuthenticationError.noInteractiveProviderAvailable
            }
            provider = deviceFlow
        }

        let credentials = try await provider.authenticate()
        cachedCredentials = credentials
        return credentials
    }

    /// Get the Device Flow provider for configuration
    public func getDeviceFlowProvider() -> DeviceFlowAuthProvider? {
        providers.first { $0 is DeviceFlowAuthProvider } as? DeviceFlowAuthProvider
    }

    /// Get the PAT provider for direct token storage
    public func getPATProvider() -> PATAuthProvider? {
        providers.first { $0 is PATAuthProvider } as? PATAuthProvider
    }

    /// Clear all stored credentials
    public func logout() async throws {
        cachedCredentials = nil
        for provider in providers {
            do {
                try await provider.clearCredentials()
            } catch AuthenticationError.cannotClearEnvironmentCredentials {
                // Expected for environment provider, ignore
                continue
            }
        }
    }

    /// Get current authentication status
    public func status() async -> AuthenticationStatus {
        for provider in providers {
            if await provider.canProvideCredentials() {
                do {
                    let credentials = try await provider.getCredentials()
                    return AuthenticationStatus(
                        isAuthenticated: true,
                        provider: provider.providerIdentifier,
                        tokenType: credentials.tokenType,
                        scope: credentials.scope,
                        expiresAt: credentials.expiresAt
                    )
                } catch {
                    continue
                }
            }
        }
        return AuthenticationStatus(
            isAuthenticated: false,
            provider: nil,
            tokenType: nil,
            scope: nil,
            expiresAt: nil
        )
    }
}
