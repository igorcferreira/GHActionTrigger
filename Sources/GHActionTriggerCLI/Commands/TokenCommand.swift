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
            print(String(localized: "token.prompt", bundle: .module), terminator: "")
            fflush(stdout)

            guard let input = readLine(), !input.isEmpty else {
                print(String(localized: "token.error.noTokenProvided", bundle: .module))
                throw ExitCode.failure
            }
            tokenValue = input
        }

        guard !tokenValue.isEmpty else {
            print(String(localized: "token.error.emptyToken", bundle: .module))
            throw ExitCode.failure
        }

        let storage = KeychainStorage()
        let patProvider = PATAuthProvider(storage: storage)

        print(String(localized: "token.validating", bundle: .module))

        do {
            let credentials = try await patProvider.storeToken(tokenValue)
            print(String(localized: "token.success", bundle: .module))
            print(String(format: String(localized: "token.success.type", bundle: .module), credentials.tokenType.rawValue))
        } catch AuthenticationError.invalidToken {
            print(String(localized: "token.error.invalid", bundle: .module))
            throw ExitCode.failure
        } catch {
            print(String(format: String(localized: "token.error.storeFailed", bundle: .module), error.localizedDescription))
            throw ExitCode.failure
        }
    }
}
