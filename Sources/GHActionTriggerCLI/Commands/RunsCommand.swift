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
                await printFinalResult(initialRun, trigger: trigger)
                return
            }

            let finalRun = try await watchWithProgress(
                trigger: trigger,
                runId: runId,
                pollInterval: pollInterval,
                timeout: timeout
            )

            print("")
            await printFinalResult(finalRun, trigger: trigger)
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

    private func watchWithProgress(
        trigger: WorkflowTrigger,
        runId: Int,
        pollInterval: Int,
        timeout: Int
    ) async throws -> WorkflowRun {
        let deadline = Date().addingTimeInterval(TimeInterval(timeout))
        var lastJobStates: [Int: (status: WorkflowJobStatus, conclusion: WorkflowJobConclusion?)] = [:]
        var lastRunStatus: WorkflowRunStatus?
        var headerPrinted = false
        var staleCount = 0

        while Date() < deadline {
            let run = try await trigger.getRun(owner: owner, repo: repo, runId: runId)

            // Print run status changes
            if run.status != lastRunStatus {
                lastRunStatus = run.status
                print("Run status: \(formatStatus(run.status))")
            }

            // Get and display job progress
            let jobs = try await trigger.getJobs(owner: owner, repo: repo, runId: runId)

            if !jobs.isEmpty && !headerPrinted {
                print("")
                print("Jobs:")
                headerPrinted = true
            }

            for job in jobs {
                let lastState = lastJobStates[job.id]
                let currentState = (status: job.status, conclusion: job.conclusion)

                // Check if job state changed
                if lastState?.status != currentState.status || lastState?.conclusion != currentState.conclusion {
                    lastJobStates[job.id] = currentState
                    printJobStatus(job)
                }
            }

            // Primary check: run status is completed
            if run.status == .completed {
                return run
            }

            // Secondary check: all jobs have completed with conclusions
            if !jobs.isEmpty && allJobsCompleted(jobs) {
                // Jobs are done, fetch run one more time to get final status
                let finalRun = try await trigger.getRun(owner: owner, repo: repo, runId: runId)
                if finalRun.status == .completed {
                    return finalRun
                }
                // If still not showing completed but jobs are done, increment stale counter
                staleCount += 1
                if staleCount >= 3 {
                    // API is likely lagging, return the run with jobs-based completion
                    print("Run status: Completed (detected via jobs)")
                    return finalRun
                }
            } else {
                staleCount = 0
            }

            try await Task.sleep(for: .seconds(pollInterval))
        }

        throw WorkflowError.timeout(reason: "Workflow run \(runId) did not complete within \(timeout) seconds")
    }

    private func allJobsCompleted(_ jobs: [WorkflowJob]) -> Bool {
        return jobs.allSatisfy { job in
            job.status == .completed && job.conclusion != nil
        }
    }

    private func printJobStatus(_ job: WorkflowJob) {
        let icon = jobStatusIcon(job)
        let status = formatJobStatus(job)
        print("  \(icon) \(job.name): \(status)")

        // Show step progress for in-progress jobs
        if job.status == .inProgress, let steps = job.steps {
            for step in steps where step.status == .inProgress {
                print("      ▸ \(step.name)")
            }
        }
    }

    private func jobStatusIcon(_ job: WorkflowJob) -> String {
        if let conclusion = job.conclusion {
            switch conclusion {
            case .success: return "✓"
            case .failure, .timedOut: return "✗"
            case .cancelled, .skipped: return "⊘"
            default: return "●"
            }
        }
        switch job.status {
        case .completed: return "●"
        case .inProgress: return "◐"
        case .queued, .waiting, .pending, .requested, .unknown: return "○"
        }
    }

    private func formatJobStatus(_ job: WorkflowJob) -> String {
        if let conclusion = job.conclusion {
            return conclusion.rawValue
        }
        switch job.status {
        case .queued: return "queued"
        case .inProgress: return "running"
        case .waiting: return "waiting"
        case .completed: return "completed"
        case .pending: return "pending"
        case .requested: return "requested"
        case .unknown: return "unknown"
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

    private func printFinalResult(_ run: WorkflowRun, trigger: WorkflowTrigger) async {
        // Get final job statuses
        if let jobs = try? await trigger.getJobs(owner: owner, repo: repo, runId: run.id) {
            print("Final job results:")
            for job in jobs {
                printJobStatus(job)
            }
            print("")
        }

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
