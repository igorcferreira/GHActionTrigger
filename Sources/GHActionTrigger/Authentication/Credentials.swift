import Foundation

/// Represents GitHub authentication credentials
public struct GitHubCredentials: Sendable, Codable, Equatable {
    public let accessToken: String
    public let tokenType: TokenType
    public let scope: String?
    public let createdAt: Date
    public let expiresAt: Date?

    public enum TokenType: String, Sendable, Codable {
        case oauth = "oauth"
        case pat = "pat"
        case environment = "environment"
    }

    public init(
        accessToken: String,
        tokenType: TokenType,
        scope: String?,
        createdAt: Date,
        expiresAt: Date?
    ) {
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.scope = scope
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }

    public var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() >= expiresAt
    }

    /// Authorization header value
    public var authorizationHeader: String {
        "Bearer \(accessToken)"
    }
}

/// Response from GitHub Device Flow code request
public struct DeviceCodeResponse: Codable, Sendable {
    public let deviceCode: String
    public let userCode: String
    public let verificationUri: String
    public let expiresIn: Int
    public let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

/// Response from GitHub token exchange
public struct TokenResponse: Codable, Sendable {
    public let accessToken: String?
    public let tokenType: String?
    public let scope: String?
    public let error: String?
    public let errorDescription: String?
    public let interval: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case error
        case errorDescription = "error_description"
        case interval
    }
}

/// Authentication status information
public struct AuthenticationStatus: Sendable {
    public let isAuthenticated: Bool
    public let provider: String?
    public let tokenType: GitHubCredentials.TokenType?
    public let scope: String?
    public let expiresAt: Date?

    public init(
        isAuthenticated: Bool,
        provider: String?,
        tokenType: GitHubCredentials.TokenType?,
        scope: String?,
        expiresAt: Date?
    ) {
        self.isAuthenticated = isAuthenticated
        self.provider = provider
        self.tokenType = tokenType
        self.scope = scope
        self.expiresAt = expiresAt
    }
}
