import ArgumentParser
import GHActionTrigger
import Foundation

struct TokenCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "token",
        abstract: "Store a Personal Access Token"
    )

    @Option(name: .long, help: "Personal Access Token (reads from stdin if not provided)")
    var token: String?

    func run() async throws {
        let tokenValue: String

        if let provided = token {
            tokenValue = provided
        } else {
            print("Enter your GitHub Personal Access Token: ", terminator: "")
            fflush(stdout)

            guard let input = readLine(), !input.isEmpty else {
                print("No token provided.")
                throw ExitCode.failure
            }
            tokenValue = input
        }

        guard !tokenValue.isEmpty else {
            print("Token cannot be empty.")
            throw ExitCode.failure
        }

        let storage = KeychainStorage()
        let patProvider = PATAuthProvider(storage: storage)

        print("Validating token...")

        do {
            let credentials = try await patProvider.storeToken(tokenValue)
            print("✓ Token validated and stored successfully!")
            print("  Token type: \(credentials.tokenType.rawValue)")
        } catch AuthenticationError.invalidToken {
            print("✗ Invalid token. Please check your token and try again.")
            throw ExitCode.failure
        } catch {
            print("✗ Failed to store token: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}
