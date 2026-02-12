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
                    print(String(format: String(localized: "trigger.invalidInputFormat", bundle: .module), inputPair))
                    print(String(localized: "trigger.invalidInputFormat.expected", bundle: .module))
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

        print(String(format: String(localized: "trigger.triggering", bundle: .module), workflow, owner, repo))
        if let inputs, !inputs.isEmpty {
            print(String(format: String(localized: "trigger.ref", bundle: .module), ref))
            print(String(format: String(localized: "trigger.inputs", bundle: .module), inputs.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")))
        } else {
            print(String(format: String(localized: "trigger.ref", bundle: .module), ref))
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
            print(String(localized: "trigger.success", bundle: .module))

            if wait {
                print(String(localized: "trigger.waiting", bundle: .module))

                guard let run = try await trigger.findRecentRun(
                    workflow: workflowId,
                    ref: ref,
                    excludeRunIds: existingRunIds
                ) else {
                    print("")
                    print(String(localized: "trigger.warning.notFound", bundle: .module))
                    print(String(format: String(localized: "trigger.warning.checkUrl", bundle: .module), owner, repo))
                    return
                }

                print(String(format: String(localized: "trigger.foundRun", bundle: .module), run.runNumber, run.id))
                print(String(format: String(localized: "trigger.viewAt", bundle: .module), run.htmlUrl.absoluteString))
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
                print(String(format: String(localized: "trigger.viewAtGeneric", bundle: .module), owner, repo))
            }
        } catch let error as WorkflowError {
            print("")
            print(String(format: String(localized: "trigger.error.prefix", bundle: .module), error.localizedDescription))
            throw ExitCode.failure
        } catch {
            print("")
            print(String(format: String(localized: "trigger.error.failed", bundle: .module), error.localizedDescription))
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
                print(String(format: String(localized: "trigger.runStatus", bundle: .module), formatRunStatus(run.status)))
            }

            // Get and display job progress
            let jobs = try await trigger.getJobs(owner: owner, repo: repo, runId: runId)

            if !jobs.isEmpty && !headerPrinted {
                print("")
                print(String(localized: "trigger.jobs", bundle: .module))
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
                    print(String(localized: "trigger.runStatus.completedByJobs", bundle: .module))
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
        case .queued: return String(localized: "trigger.jobStatus.queued", bundle: .module)
        case .inProgress: return String(localized: "trigger.jobStatus.running", bundle: .module)
        case .waiting: return String(localized: "trigger.jobStatus.waiting", bundle: .module)
        case .completed: return String(localized: "trigger.jobStatus.completed", bundle: .module)
        case .pending: return String(localized: "trigger.jobStatus.pending", bundle: .module)
        case .requested: return String(localized: "trigger.jobStatus.requested", bundle: .module)
        case .unknown: return String(localized: "trigger.jobStatus.unknown", bundle: .module)
        }
    }

    private func formatRunStatus(_ status: WorkflowRunStatus) -> String {
        switch status {
        case .queued: return String(localized: "trigger.status.queued", bundle: .module)
        case .inProgress: return String(localized: "trigger.status.inProgress", bundle: .module)
        case .completed: return String(localized: "trigger.status.completed", bundle: .module)
        case .waiting: return String(localized: "trigger.status.waiting", bundle: .module)
        case .requested: return String(localized: "trigger.status.requested", bundle: .module)
        case .pending: return String(localized: "trigger.status.pending", bundle: .module)
        }
    }

    private func printFinalResult(_ run: WorkflowRun, trigger: WorkflowTrigger) async {
        // Get final job statuses
        if let jobs = try? await trigger.getJobs(owner: owner, repo: repo, runId: run.id) {
            print(String(localized: "trigger.finalJobResults", bundle: .module))
            for job in jobs {
                printJobStatus(job)
            }
            print("")
        }

        if let conclusion = run.conclusion {
            switch conclusion {
            case .success:
                print(String(localized: "trigger.result.success", bundle: .module))
            case .failure:
                print(String(localized: "trigger.result.failed", bundle: .module))
            case .cancelled:
                print(String(localized: "trigger.result.cancelled", bundle: .module))
            case .skipped:
                print(String(localized: "trigger.result.skipped", bundle: .module))
            case .timedOut:
                print(String(localized: "trigger.result.timedOut", bundle: .module))
            default:
                print(String(format: String(localized: "trigger.result.otherConclusion", bundle: .module), conclusion.rawValue))
            }
        } else {
            print(String(localized: "trigger.result.unknownConclusion", bundle: .module))
        }
        print(String(format: String(localized: "trigger.viewAt", bundle: .module), run.htmlUrl.absoluteString))
    }
}
