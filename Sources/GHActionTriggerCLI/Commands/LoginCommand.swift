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
            print("Error: No GitHub OAuth App Client ID configured.")
            print("")
            print("To authenticate, you need to:")
            print("1. Create a GitHub OAuth App at https://github.com/settings/developers")
            print("2. Enable 'Device Authorization Flow' in the app settings")
            print("3. Either:")
            print("   - Set GHACTIONTRIGGER_CLIENT_ID environment variable")
            print("   - Or use --client-id flag with your Client ID")
            print("")
            print("Alternatively, use a Personal Access Token:")
            print("  ghaction auth token --token <your-pat>")
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

        print("Starting GitHub authentication...")

        do {
            let credentials = try await provider.authenticate()
            print("\n✓ Successfully authenticated with GitHub!")
            if let scope = credentials.scope {
                print("  Scopes: \(scope)")
            }
        } catch {
            await delegate.deviceFlowDidComplete(success: false)
            print("\n✗ Authentication failed: \(error.localizedDescription)")
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
        print("│         GitHub Device Authorization            │")
        print("├────────────────────────────────────────────────┤")
        print("│  1. Open: \(verificationURL.padding(toLength: 34, withPad: " ", startingAt: 0)) │")
        print("│  2. Enter code: \(userCode.padding(toLength: 28, withPad: " ", startingAt: 0)) │")
        print("└────────────────────────────────────────────────┘")
        print("")
        print("Waiting for authorization...")

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
