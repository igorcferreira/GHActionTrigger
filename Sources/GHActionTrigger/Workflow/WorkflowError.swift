import Foundation

/// Errors related to workflow operations
public enum WorkflowError: Error, LocalizedError, Sendable {
    /// No authentication credentials available
    case notAuthenticated

    /// Workflow not found in the repository
    case workflowNotFound(workflow: String, repo: String)

    /// Repository not found or not accessible
    case repositoryNotFound(owner: String, repo: String)

    /// Insufficient permissions to trigger workflow
    case permissionDenied

    /// Workflow does not have workflow_dispatch trigger enabled
    case workflowDispatchNotEnabled(workflow: String)

    /// Invalid git reference (branch, tag, or SHA)
    case invalidRef(ref: String)

    /// API rate limit exceeded
    case rateLimited(resetAt: Date?)

    /// Network error occurred
    case networkError(underlying: Error)

    /// HTTP error with status code
    case httpError(statusCode: Int, message: String?)

    /// Invalid input parameter
    case invalidInput(key: String, reason: String)

    /// Workflow run not found
    case runNotFound(runId: Int, repo: String)

    /// Timed out waiting for workflow run
    case timeout(reason: String)

    /// Workflow run failed
    case runFailed(runId: Int, conclusion: WorkflowRunConclusion)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Run 'ghaction auth login' or set GITHUB_TOKEN environment variable."

        case .workflowNotFound(let workflow, let repo):
            return "Workflow '\(workflow)' not found in repository '\(repo)'."

        case .repositoryNotFound(let owner, let repo):
            return "Repository '\(owner)/\(repo)' not found or not accessible."

        case .permissionDenied:
            return "Permission denied. Ensure your token has 'repo' or 'workflow' scope."

        case .workflowDispatchNotEnabled(let workflow):
            return "Workflow '\(workflow)' does not have 'workflow_dispatch' trigger enabled."

        case .invalidRef(let ref):
            return "Invalid git reference '\(ref)'. Must be a branch name, tag, or SHA."

        case .rateLimited(let resetAt):
            if let resetAt {
                let formatter = RelativeDateTimeFormatter()
                let timeString = formatter.localizedString(for: resetAt, relativeTo: Date())
                return "API rate limit exceeded. Resets \(timeString)."
            }
            return "API rate limit exceeded."

        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"

        case .httpError(let statusCode, let message):
            if let message {
                return "HTTP error \(statusCode): \(message)"
            }
            return "HTTP error \(statusCode)"

        case .invalidInput(let key, let reason):
            return "Invalid input '\(key)': \(reason)"

        case .runNotFound(let runId, let repo):
            return "Workflow run \(runId) not found in repository '\(repo)'."

        case .timeout(let reason):
            return "Timed out: \(reason)"

        case .runFailed(let runId, let conclusion):
            return "Workflow run \(runId) failed with conclusion: \(conclusion.rawValue)"
        }
    }
}
