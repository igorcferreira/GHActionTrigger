import ArgumentParser
import GHActionTrigger
import Foundation
#if os(macOS)
import AppKit
#endif

struct LoginCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "login",
        abstract: "Authenticate with GitHub using OAuth Device Flow"
    )

    @Option(name: .long, help: "GitHub OAuth App Client ID")
    var clientId: String?

    @Option(name: .long, help: "OAuth scopes (space-separated)")
    var scopes: String = "repo workflow"

    @Flag(name: .long, help: "Open verification URL in browser automatically")
    var openBrowser: Bool = false

    func run() async throws {
        let resolvedClientId = clientId ?? Configuration.defaultClientId

        // Check if client ID is configured
        if resolvedClientId == "YOUR_GITHUB_OAUTH_APP_CLIENT_ID" {
            print(String(localized: "login.error.noClientId", bundle: .module))
            print("")
            print(String(localized: "login.instructions.header", bundle: .module))
            print(String(localized: "login.instructions.step1", bundle: .module))
            print(String(localized: "login.instructions.step2", bundle: .module))
            print(String(localized: "login.instructions.step3", bundle: .module))
            print(String(localized: "login.instructions.step3a", bundle: .module))
            print(String(localized: "login.instructions.step3b", bundle: .module))
            print("")
            print(String(localized: "login.instructions.alternative", bundle: .module))
            print(String(localized: "login.instructions.alternativeCommand", bundle: .module))
            throw ExitCode.failure
        }

        let storage = KeychainStorage()
        let provider = DeviceFlowAuthProvider(
            clientId: resolvedClientId,
            scope: scopes,
            storage: storage
        )

        // Set up CLI delegate for user prompts
        let delegate = CLIDeviceFlowDelegate(openBrowser: openBrowser)
        provider.delegate = delegate

        print(String(localized: "login.starting", bundle: .module))

        do {
            let credentials = try await provider.authenticate()
            print("\n" + String(localized: "login.success", bundle: .module))
            if let scope = credentials.scope {
                print(String(format: String(localized: "login.success.scopes", bundle: .module), scope))
            }
        } catch {
            await delegate.deviceFlowDidComplete(success: false)
            print("\n" + String(format: String(localized: "login.failed", bundle: .module), error.localizedDescription))
            throw ExitCode.failure
        }
    }
}

/// CLI implementation of DeviceFlowDelegate
final class CLIDeviceFlowDelegate: DeviceFlowDelegate, @unchecked Sendable {
    private let openBrowser: Bool

    init(openBrowser: Bool) {
        self.openBrowser = openBrowser
    }

    func deviceFlowDidReceiveUserCode(userCode: String, verificationURL: String) async {
        print("")
        print("┌────────────────────────────────────────────────┐")
        print(String(localized: "login.deviceFlow.title", bundle: .module))
        print("├────────────────────────────────────────────────┤")
        print(String(format: String(localized: "login.deviceFlow.openUrl", bundle: .module), verificationURL.padding(toLength: 34, withPad: " ", startingAt: 0)) + " │")
        print(String(format: String(localized: "login.deviceFlow.enterCode", bundle: .module), userCode.padding(toLength: 28, withPad: " ", startingAt: 0)) + " │")
        print("└────────────────────────────────────────────────┘")
        print("")
        print(String(localized: "login.deviceFlow.waiting", bundle: .module))

        if openBrowser {
            #if os(macOS)
            if let url = URL(string: verificationURL) {
                NSWorkspace.shared.open(url)
            }
            #endif
        }
    }

    func deviceFlowDidComplete(success: Bool) async {
        // Handled by run() method
    }
}
