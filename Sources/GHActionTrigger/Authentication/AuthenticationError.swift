import Foundation

/// Errors related to GitHub authentication
public enum AuthenticationError: Error, LocalizedError, Sendable {
    // General errors
    case noCredentialsAvailable
    case providerNotFound(String)
    case noInteractiveProviderAvailable
    case interactiveAuthNotSupported(provider: String)

    // Token errors
    case tokenExpired
    case invalidToken
    case emptyToken

    // Device Flow errors
    case deviceCodeRequestFailed
    case deviceCodeExpired
    case accessDenied
    case tokenRequestFailed(error: String, description: String?)
    case invalidTokenResponse

    // Storage errors
    case keychainError(status: OSStatus, operation: String)
    case cannotClearEnvironmentCredentials

    // Network errors
    case networkError(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .noCredentialsAvailable:
            return "No GitHub credentials available. Run 'ghaction auth login' to authenticate."
        case .providerNotFound(let id):
            return "Authentication provider '\(id)' not found."
        case .noInteractiveProviderAvailable:
            return "No interactive authentication provider available."
        case .interactiveAuthNotSupported(let provider):
            return "Provider '\(provider)' does not support interactive authentication."
        case .tokenExpired:
            return "GitHub token has expired. Please re-authenticate."
        case .invalidToken:
            return "The provided token is invalid or has been revoked."
        case .emptyToken:
            return "The token cannot be empty."
        case .deviceCodeRequestFailed:
            return "Failed to request device code from GitHub."
        case .deviceCodeExpired:
            return "Device code expired. Please try again."
        case .accessDenied:
            return "Access was denied. The user may have declined authorization."
        case .tokenRequestFailed(let error, let description):
            return "Token request failed: \(error)\(description.map { " - \($0)" } ?? "")"
        case .invalidTokenResponse:
            return "Received invalid response from GitHub token endpoint."
        case .keychainError(let status, let operation):
            return "Keychain \(operation) failed with status: \(status)"
        case .cannotClearEnvironmentCredentials:
            return "Cannot clear credentials from environment variables."
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        }
    }
}
