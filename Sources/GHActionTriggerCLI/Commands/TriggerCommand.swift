import ArgumentParser
import GHActionTrigger
import Foundation

struct TriggerCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "trigger",
        abstract: "Trigger a GitHub Actions workflow"
    )

    @Option(name: .shortAndLong, help: "Repository owner (username or organization)")
    var owner: String

    @Option(name: .shortAndLong, help: "Repository name")
    var repo: String

    @Option(name: .shortAndLong, help: "Workflow filename (e.g., ci.yml) or numeric ID")
    var workflow: String

    @Option(name: .long, help: "Git ref - branch name, tag, or SHA (default: main)")
    var ref: String = "main"

    @Option(name: .shortAndLong, parsing: .upToNextOption, help: "Workflow inputs as key=value pairs")
    var input: [String] = []

    @Flag(name: .long, help: "Wait for the workflow run to complete")
    var wait: Bool = false

    @Option(name: .long, help: "Poll interval in seconds when waiting (default: 2)")
    var pollInterval: Int = 2

    @Option(name: .long, help: "Timeout in seconds when waiting (default: 3600)")
    var timeout: Int = 3600

    func run() async throws {
        // Parse inputs into dictionary
        var inputs: [String: String]? = nil
        if !input.isEmpty {
            var parsedInputs: [String: String] = [:]
            for inputPair in input {
                let parts = inputPair.split(separator: "=", maxSplits: 1)
                guard parts.count == 2 else {
                    print("✗ Invalid input format: '\(inputPair)'")
                    print("  Expected format: key=value")
                    throw ExitCode.failure
                }
                parsedInputs[String(parts[0])] = String(parts[1])
            }
            inputs = parsedInputs
        }

        // Create workflow identifier
        let workflowId = WorkflowIdentifier(
            owner: owner,
            repo: repo,
            workflowId: workflow
        )

        // Set up authentication and trigger
        let storage = KeychainStorage()
        let authManager = AuthenticationManager(storage: storage)
        let trigger = WorkflowTrigger(authManager: authManager)

        print("Triggering workflow '\(workflow)' on \(owner)/\(repo)...")
        if let inputs, !inputs.isEmpty {
            print("  Ref: \(ref)")
            print("  Inputs: \(inputs.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))")
        } else {
            print("  Ref: \(ref)")
        }

        do {
            // If waiting, get existing runs before triggering to exclude them later
            var existingRunIds: Set<Int> = []
            if wait {
                let existingRuns = try await trigger.listRuns(
                    owner: owner,
                    repo: repo,
                    filter: WorkflowRunsFilter(perPage: 30)
                )
                existingRunIds = Set(existingRuns.map { $0.id })
            }

            try await trigger.trigger(workflow: workflowId, ref: ref, inputs: inputs)
            print("")
            print("✓ Workflow dispatch triggered successfully!")

            if wait {
                print("  Waiting for workflow run to start...")

                guard let run = try await trigger.findRecentRun(
                    workflow: workflowId,
                    ref: ref,
                    excludeRunIds: existingRunIds
                ) else {
                    print("")
                    print("⚠ Could not find workflow run. Check manually:")
                    print("  https://github.com/\(owner)/\(repo)/actions")
                    return
                }

                print("  Found run #\(run.runNumber) (ID: \(run.id))")
                print("  View at: \(run.htmlUrl)")
                print("")

                let finalRun = try await waitWithProgress(
                    trigger: trigger,
                    runId: run.id,
                    pollInterval: pollInterval,
                    timeout: timeout
                )

                print("")
                await printFinalResult(finalRun, trigger: trigger)
            } else {
                print("  View at: https://github.com/\(owner)/\(repo)/actions")
            }
        } catch let error as WorkflowError {
            print("")
            print("✗ \(error.localizedDescription)")
            throw ExitCode.failure
        } catch {
            print("")
            print("✗ Failed to trigger workflow: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }

    private func waitWithProgress(
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
                print("Run status: \(formatRunStatus(run.status))")
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

    private func formatRunStatus(_ status: WorkflowRunStatus) -> String {
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
