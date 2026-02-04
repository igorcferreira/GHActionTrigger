//
//  GHActionTriggerCLI.swift
//  GHActionTrigger
//
//  Created by Igor Ferreira on 04/02/2026.
//
//  Swift Argument Parser
//  https://swiftpackageindex.com/apple/swift-argument-parser/documentation
import Foundation
import ArgumentParser
import GHActionTrigger

@main
struct GHActionTriggerCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ghaction",
        abstract: "Trigger GitHub Actions from the command line",
        version: "1.0.0",
        subcommands: [
            AuthCommand.self,
            TriggerCommand.self,
            RunsCommand.self
        ],
        defaultSubcommand: nil
    )
}
