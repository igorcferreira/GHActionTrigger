import ArgumentParser
import GHActionTrigger
import Foundation

struct StatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show current authentication status"
    )

    func run() async throws {
        let storage = KeychainStorage()
        let authManager = AuthenticationManager(storage: storage)

        let status = await authManager.status()

        if status.isAuthenticated {
            print("✓ Authenticated with GitHub")
            if let provider = status.provider {
                print("  Provider: \(provider)")
            }
            if let tokenType = status.tokenType {
                print("  Token type: \(tokenType.rawValue)")
            }
            if let scope = status.scope {
                print("  Scopes: \(scope)")
            }
            if let expiresAt = status.expiresAt {
                let formatter = RelativeDateTimeFormatter()
                print("  Expires: \(formatter.localizedString(for: expiresAt, relativeTo: Date()))")
            }
        } else {
            print("✗ Not authenticated")
            print("  Run 'ghaction auth login' to authenticate")

            // Check if GITHUB_TOKEN is expected but missing
            if ProcessInfo.processInfo.environment["GITHUB_TOKEN"] == nil {
                print("  Or set GITHUB_TOKEN environment variable")
            }
        }
    }
}
