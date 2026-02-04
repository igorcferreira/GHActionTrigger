// GHActionTrigger - Swift library for triggering GitHub Actions
// https://github.com/apple/swift-argument-parser

// Re-export Foundation types for convenience
@_exported import struct Foundation.Date
@_exported import struct Foundation.URL

// MARK: - Authentication

// Public API
// - AuthenticationManager: Central coordinator for all authentication methods
// - GitHubCredentials: Token and credential data
// - AuthenticationStatus: Current auth state information
// - AuthenticationError: Error types for auth operations
// - AuthenticationProvider: Protocol for custom auth providers
// - DeviceFlowDelegate: Delegate for OAuth Device Flow UI callbacks

// Storage
// - TokenStorage: Protocol for custom token storage
// - KeychainStorage: macOS Keychain implementation

// Providers
// - EnvironmentAuthProvider: GITHUB_TOKEN environment variable support
// - DeviceFlowAuthProvider: OAuth Device Flow (primary)
// - PATAuthProvider: Personal Access Token support

// Configuration
// - Configuration: Default values and settings

// MARK: - Workflow

// Public API
// - WorkflowTrigger: Triggers GitHub Actions workflows
// - WorkflowIdentifier: Identifies a workflow (owner, repo, workflow ID)
// - WorkflowDispatchRequest: Request body for triggering workflows
// - WorkflowInfo: Information about a workflow
// - WorkflowError: Error types for workflow operations
