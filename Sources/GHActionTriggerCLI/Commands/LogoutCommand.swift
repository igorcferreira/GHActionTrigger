import ArgumentParser
import GHActionTrigger
import Foundation

struct LogoutCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "logout",
        abstract: "Remove stored GitHub credentials"
    )

    @Flag(name: .long, help: "Skip confirmation prompt")
    var force: Bool = false

    func run() async throws {
        if !force {
            print("This will remove all stored GitHub credentials.")
            print("Continue? [y/N] ", terminator: "")
            fflush(stdout)

            guard let response = readLine()?.lowercased(),
                  response == "y" || response == "yes" else {
                print("Cancelled.")
                return
            }
        }

        let storage = KeychainStorage()
        let authManager = AuthenticationManager(storage: storage)

        do {
            try await authManager.logout()
            print("✓ Successfully logged out.")
        } catch {
            print("✗ Failed to logout: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}
