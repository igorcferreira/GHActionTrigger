import ArgumentParser
import GHActionTrigger
import Foundation

struct RunsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "runs",
        abstract: "Manage and monitor workflow runs",
        subcommands: [
            ListRunsCommand.self,
            GetRunCommand.self,
            WatchRunCommand.self
        ],
        defaultSubcommand: ListRunsCommand.self
    )
}

// MARK: - List Runs

struct ListRunsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List recent workflow runs"
    )

    @Option(name: .shortAndLong, help: "Repository owner (username or organization)")
    var owner: String

    @Option(name: .shortAndLong, help: "Repository name")
    var repo: String

    @Option(name: .shortAndLong, help: "Filter by workflow filename (e.g., ci.yml)")
    var workflow: String?

    @Option(name: .long, help: "Filter by branch name")
    var branch: String?

    @Option(name: .long, help: "Filter by event type (e.g., push, pull_request, workflow_dispatch)")
    var event: String?

    @Option(name: .shortAndLong, help: "Maximum number of runs to show (default: 10)")
    var limit: Int = 10

    func run() async throws {
        let storage = KeychainStorage()
        let authManager = AuthenticationManager(storage: storage)
        let trigger = WorkflowTrigger(authManager: authManager)

        let filter = WorkflowRunsFilter(
            workflowId: workflow,
            branch: branch,
            event: event,
            perPage: limit
        )

        do {
            let runs = try await trigger.listRuns(owner: owner, repo: repo, filter: filter)

            if runs.isEmpty {
                print("No workflow runs found.")
                return
            }

            print("Recent workflow runs for \(owner)/\(repo):")
            print("")

            let dateFormatter = RelativeDateTimeFormatter()
            dateFormatter.unitsStyle = .abbreviated

            for run in runs.prefix(limit) {
                let statusIcon = statusIcon(for: run)
                let timeAgo = dateFormatter.localizedString(for: run.createdAt, relativeTo: Date())

                print("\(statusIcon) #\(run.runNumber) \(run.name ?? "Unnamed")")
                print("  Status: \(formatStatus(run.status))\(run.conclusion.map { ", \($0.rawValue)" } ?? "")")
                print("  Branch: \(run.headBranch) | Event: \(run.event) | \(timeAgo)")
                print("  URL: \(run.htmlUrl)")
                print("")
            }
        } catch let error as WorkflowError {
            print("✗ \(error.localizedDescription)")
            throw ExitCode.failure
        } catch {
            print("✗ Failed to list runs: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }

    private func statusIcon(for run: WorkflowRun) -> String {
        if let conclusion = run.conclusion {
            switch conclusion {
            case .success: return "✓"
            case .failure, .timedOut, .startupFailure: return "✗"
            case .cancelled, .skipped: return "⊘"
            default: return "●"
            }
        }
        switch run.status {
        case .completed: return "●"
        case .inProgress: return "◐"
        default: return "○"
        }
    }

    private func formatStatus(_ status: WorkflowRunStatus) -> String {
        switch status {
        case .queued: return "Queued"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .waiting: return "Waiting"
        case .requested: return "Requested"
        case .pending: return "Pending"
        }
    }
}

// MARK: - Get Run

struct GetRunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Get details of a specific workflow run"
    )

    @Option(name: .shortAndLong, help: "Repository owner (username or organization)")
    var owner: String

    @Option(name: .shortAndLong, help: "Repository name")
    var repo: String

    @Argument(help: "Workflow run ID")
    var runId: Int

    func run() async throws {
        let storage = KeychainStorage()
        let authManager = AuthenticationManager(storage: storage)
        let trigger = WorkflowTrigger(authManager: authManager)

        do {
            let run = try await trigger.getRun(owner: owner, repo: repo, runId: runId)

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short

            print("Workflow Run #\(run.runNumber)")
            print("")
            print("  Name:       \(run.name ?? "Unnamed")")
            print("  ID:         \(run.id)")
            print("  Status:     \(formatStatus(run.status))")
            if let conclusion = run.conclusion {
                print("  Conclusion: \(conclusion.rawValue)")
            }
            print("  Event:      \(run.event)")
            print("  Branch:     \(run.headBranch)")
            print("  Commit:     \(String(run.headSha.prefix(7)))")
            print("  Attempt:    \(run.runAttempt)")
            print("  Created:    \(dateFormatter.string(from: run.createdAt))")
            print("  Updated:    \(dateFormatter.string(from: run.updatedAt))")
            print("  URL:        \(run.htmlUrl)")
        } catch let error as WorkflowError {
            print("✗ \(error.localizedDescription)")
            throw ExitCode.failure
        } catch {
            print("✗ Failed to get run: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }

    private func formatStatus(_ status: WorkflowRunStatus) -> String {
        switch status {
        case .queued: return "Queued"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .waiting: return "Waiting"
        case .requested: return "Requested"
        case .pending: return "Pending"
        }
    }
}

// MARK: - Watch Run

struct WatchRunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "watch",
        abstract: "Watch a workflow run until completion"
    )

    @Option(name: .shortAndLong, help: "Repository owner (username or organization)")
    var owner: String

    @Option(name: .shortAndLong, help: "Repository name")
    var repo: String

    @Argument(help: "Workflow run ID")
    var runId: Int

    @Option(name: .long, help: "Poll interval in seconds (default: 10)")
    var pollInterval: Int = 10

    @Option(name: .long, help: "Timeout in seconds (default: 3600)")
    var timeout: Int = 3600

    func run() async throws {
        let storage = KeychainStorage()
        let authManager = AuthenticationManager(storage: storage)
        let trigger = WorkflowTrigger(authManager: authManager)

        do {
            // Get initial run info
            let initialRun = try await trigger.getRun(owner: owner, repo: repo, runId: runId)

            print("Watching workflow run #\(initialRun.runNumber) (\(initialRun.name ?? "Unnamed"))...")
            print("  URL: \(initialRun.htmlUrl)")
            print("")

            if initialRun.status == .completed {
                printFinalResult(initialRun)
                return
            }

            let finalRun = try await trigger.waitForCompletion(
                owner: owner,
                repo: repo,
                runId: runId,
                pollInterval: TimeInterval(pollInterval),
                timeout: TimeInterval(timeout)
            )

            print("")
            printFinalResult(finalRun)
        } catch let error as WorkflowError {
            print("")
            print("✗ \(error.localizedDescription)")
            throw ExitCode.failure
        } catch {
            print("")
            print("✗ Failed to watch run: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }

    private func formatStatus(_ status: WorkflowRunStatus) -> String {
        switch status {
        case .queued: return "Queued"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .waiting: return "Waiting"
        case .requested: return "Requested"
        case .pending: return "Pending"
        }
    }

    private func printFinalResult(_ run: WorkflowRun) {
        if let conclusion = run.conclusion {
            switch conclusion {
            case .success:
                print("✓ Workflow run completed successfully!")
            case .failure:
                print("✗ Workflow run failed.")
            case .cancelled:
                print("⚠ Workflow run was cancelled.")
            case .skipped:
                print("⚠ Workflow run was skipped.")
            case .timedOut:
                print("✗ Workflow run timed out.")
            default:
                print("⚠ Workflow run completed with conclusion: \(conclusion.rawValue)")
            }
        } else {
            print("⚠ Workflow run completed with unknown conclusion.")
        }
        print("  View at: \(run.htmlUrl)")
    }
}
