import Foundation

/// Configuration for GHActionTrigger
public enum Configuration {
    /// Default OAuth App Client ID
    /// Note: Users should register their own OAuth App for production use
    /// or override via GHACTIONTRIGGER_CLIENT_ID environment variable
    public static var defaultClientId: String {
        // Check for custom client ID in environment
        if let envClientId = ProcessInfo.processInfo.environment["GHACTIONTRIGGER_CLIENT_ID"] {
            return envClientId
        }
        // Placeholder - users must provide their own client ID
        return "YOUR_GITHUB_OAUTH_APP_CLIENT_ID"
    }

    /// Default OAuth scopes for GitHub Actions triggering
    public static let defaultScopes = "repo workflow"

    /// Keychain service name for credential storage
    public static let keychainServiceName = "com.ghactiontrigger.auth"
}
