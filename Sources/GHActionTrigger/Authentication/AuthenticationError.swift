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
            return String(localized: "auth.error.noCredentialsAvailable", bundle: .module)
        case .providerNotFound(let id):
            return String(format: String(localized: "auth.error.providerNotFound", bundle: .module), id)
        case .noInteractiveProviderAvailable:
            return String(localized: "auth.error.noInteractiveProviderAvailable", bundle: .module)
        case .interactiveAuthNotSupported(let provider):
            return String(format: String(localized: "auth.error.interactiveAuthNotSupported", bundle: .module), provider)
        case .tokenExpired:
            return String(localized: "auth.error.tokenExpired", bundle: .module)
        case .invalidToken:
            return String(localized: "auth.error.invalidToken", bundle: .module)
        case .emptyToken:
            return String(localized: "auth.error.emptyToken", bundle: .module)
        case .deviceCodeRequestFailed:
            return String(localized: "auth.error.deviceCodeRequestFailed", bundle: .module)
        case .deviceCodeExpired:
            return String(localized: "auth.error.deviceCodeExpired", bundle: .module)
        case .accessDenied:
            return String(localized: "auth.error.accessDenied", bundle: .module)
        case .tokenRequestFailed(let error, let description):
            if let description {
                return String(format: String(localized: "auth.error.tokenRequestFailedWithDescription", bundle: .module), error, description)
            } else {
                return String(format: String(localized: "auth.error.tokenRequestFailed", bundle: .module), error)
            }
        case .invalidTokenResponse:
            return String(localized: "auth.error.invalidTokenResponse", bundle: .module)
        case .keychainError(let status, let operation):
            return String(format: String(localized: "auth.error.keychainError", bundle: .module), operation, status)
        case .cannotClearEnvironmentCredentials:
            return String(localized: "auth.error.cannotClearEnvironmentCredentials", bundle: .module)
        case .networkError(let underlying):
            return String(format: String(localized: "auth.error.networkError", bundle: .module), underlying.localizedDescription)
        }
    }
}
