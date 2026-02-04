import Foundation

/// Delegate protocol for Device Flow UI callbacks
public protocol DeviceFlowDelegate: AnyObject, Sendable {
    /// Called when the device code is received and user action is required
    func deviceFlowDidReceiveUserCode(userCode: String, verificationURL: String) async

    /// Called when authentication completes
    func deviceFlowDidComplete(success: Bool) async
}

/// GitHub OAuth Device Flow authentication provider
public final class DeviceFlowAuthProvider: AuthenticationProvider, @unchecked Sendable {
    public let providerIdentifier = "device-flow"
    public let priority = 1

    private let clientId: String
    private let scope: String
    private let storage: any TokenStorage
    private let storageKey = "github-oauth-token"
    private let urlSession: URLSession

    // GitHub Device Flow endpoints
    private let deviceCodeURL = URL(string: "https://github.com/login/device/code")!
    private let tokenURL = URL(string: "https://github.com/login/oauth/access_token")!

    /// Delegate for UI callbacks during device flow
    public weak var delegate: DeviceFlowDelegate?

    public init(
        clientId: String,
        scope: String = "repo workflow",
        storage: any TokenStorage,
        urlSession: URLSession = .shared
    ) {
        self.clientId = clientId
        self.scope = scope
        self.storage = storage
        self.urlSession = urlSession
    }

    public func canProvideCredentials() async -> Bool {
        await storage.exists(for: storageKey)
    }

    public func getCredentials() async throws -> GitHubCredentials {
        guard let credentials = try await storage.retrieve(for: storageKey) else {
            throw AuthenticationError.noCredentialsAvailable
        }

        if credentials.isExpired {
            throw AuthenticationError.tokenExpired
        }

        return credentials
    }

    public func authenticate() async throws -> GitHubCredentials {
        // Step 1: Request device code
        let deviceCode = try await requestDeviceCode()

        // Step 2: Notify delegate to display user code
        await delegate?.deviceFlowDidReceiveUserCode(
            userCode: deviceCode.userCode,
            verificationURL: deviceCode.verificationUri
        )

        // Step 3: Poll for token
        let credentials = try await pollForToken(deviceCode: deviceCode)

        // Step 4: Store credentials
        try await storage.save(credentials, for: storageKey)

        // Step 5: Notify success
        await delegate?.deviceFlowDidComplete(success: true)

        return credentials
    }

    public func clearCredentials() async throws {
        try await storage.delete(for: storageKey)
    }

    // MARK: - Private Methods

    private func requestDeviceCode() async throws -> DeviceCodeResponse {
        var request = URLRequest(url: deviceCodeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let encodedScope = scope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scope
        let body = "client_id=\(clientId)&scope=\(encodedScope)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AuthenticationError.deviceCodeRequestFailed
        }

        let decoder = JSONDecoder()
        return try decoder.decode(DeviceCodeResponse.self, from: data)
    }

    private func pollForToken(deviceCode: DeviceCodeResponse) async throws -> GitHubCredentials {
        let expirationTime = Date().addingTimeInterval(TimeInterval(deviceCode.expiresIn))
        var pollInterval = TimeInterval(deviceCode.interval)

        while Date() < expirationTime {
            // Wait for the specified interval
            try await Task.sleep(for: .seconds(pollInterval))

            // Check for cancellation
            try Task.checkCancellation()

            let result = try await requestToken(deviceCode: deviceCode.deviceCode)

            switch result {
            case .success(let credentials):
                return credentials

            case .pending:
                continue

            case .slowDown(let newInterval):
                pollInterval = TimeInterval(newInterval)
                continue

            case .error(let error):
                throw error
            }
        }

        throw AuthenticationError.deviceCodeExpired
    }

    private enum TokenPollResult {
        case success(GitHubCredentials)
        case pending
        case slowDown(Int)
        case error(AuthenticationError)
    }

    private func requestToken(deviceCode: String) async throws -> TokenPollResult {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let grantType = "urn:ietf:params:oauth:grant-type:device_code"
        let body = "client_id=\(clientId)&device_code=\(deviceCode)&grant_type=\(grantType)"
        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await urlSession.data(for: request)

        let decoder = JSONDecoder()
        let response = try decoder.decode(TokenResponse.self, from: data)

        // Check for errors first
        if let error = response.error {
            switch error {
            case "authorization_pending":
                return .pending
            case "slow_down":
                return .slowDown(response.interval ?? 10)
            case "expired_token":
                return .error(.deviceCodeExpired)
            case "access_denied":
                return .error(.accessDenied)
            default:
                return .error(.tokenRequestFailed(error: error, description: response.errorDescription))
            }
        }

        // Success - extract token
        guard let accessToken = response.accessToken else {
            return .error(.invalidTokenResponse)
        }

        let credentials = GitHubCredentials(
            accessToken: accessToken,
            tokenType: .oauth,
            scope: response.scope,
            createdAt: Date(),
            expiresAt: nil // GitHub OAuth tokens don't expire unless revoked
        )

        return .success(credentials)
    }
}
