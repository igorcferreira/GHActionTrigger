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
            print(String(localized: "logout.confirmation", bundle: .module))
            print(String(localized: "logout.confirmationPrompt", bundle: .module), terminator: "")
            fflush(stdout)

            guard let response = readLine()?.lowercased(),
                  response == "y" || response == "yes" else {
                print(String(localized: "logout.cancelled", bundle: .module))
                return
            }
        }

        let storage = KeychainStorage()
        let authManager = AuthenticationManager(storage: storage)

        do {
            try await authManager.logout()
            print(String(localized: "logout.success", bundle: .module))
        } catch {
            print(String(format: String(localized: "logout.failed", bundle: .module), error.localizedDescription))
            throw ExitCode.failure
        }
    }
}
