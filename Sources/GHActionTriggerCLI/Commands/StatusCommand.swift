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
            print(String(localized: "status.authenticated", bundle: .module))
            if let provider = status.provider {
                print(String(format: String(localized: "status.authenticated.provider", bundle: .module), provider))
            }
            if let tokenType = status.tokenType {
                print(String(format: String(localized: "status.authenticated.tokenType", bundle: .module), tokenType.rawValue))
            }
            if let scope = status.scope {
                print(String(format: String(localized: "status.authenticated.scopes", bundle: .module), scope))
            }
            if let expiresAt = status.expiresAt {
                let formatter = RelativeDateTimeFormatter()
                print(String(format: String(localized: "status.authenticated.expires", bundle: .module), formatter.localizedString(for: expiresAt, relativeTo: Date())))
            }
        } else {
            print(String(localized: "status.notAuthenticated", bundle: .module))
            print(String(localized: "status.notAuthenticated.instruction1", bundle: .module))

            // Check if GITHUB_TOKEN is expected but missing
            if ProcessInfo.processInfo.environment["GITHUB_TOKEN"] == nil {
                print(String(localized: "status.notAuthenticated.instruction2", bundle: .module))
            }
        }
    }
}
