import ArgumentParser
import GHActionTrigger

struct AuthCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "auth",
        abstract: "Manage GitHub authentication",
        subcommands: [
            LoginCommand.self,
            LogoutCommand.self,
            StatusCommand.self,
            TokenCommand.self
        ],
        defaultSubcommand: StatusCommand.self
    )
}
