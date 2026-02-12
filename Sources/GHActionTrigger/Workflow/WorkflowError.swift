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
            return String(localized: "workflow.error.notAuthenticated", bundle: .module)

        case .workflowNotFound(let workflow, let repo):
            return String(format: String(localized: "workflow.error.workflowNotFound", bundle: .module), workflow, repo)

        case .repositoryNotFound(let owner, let repo):
            return String(format: String(localized: "workflow.error.repositoryNotFound", bundle: .module), owner, repo)

        case .permissionDenied:
            return String(localized: "workflow.error.permissionDenied", bundle: .module)

        case .workflowDispatchNotEnabled(let workflow):
            return String(format: String(localized: "workflow.error.workflowDispatchNotEnabled", bundle: .module), workflow)

        case .invalidRef(let ref):
            return String(format: String(localized: "workflow.error.invalidRef", bundle: .module), ref)

        case .rateLimited(let resetAt):
            if let resetAt {
                let formatter = RelativeDateTimeFormatter()
                let timeString = formatter.localizedString(for: resetAt, relativeTo: Date())
                return String(format: String(localized: "workflow.error.rateLimitedWithReset", bundle: .module), timeString)
            }
            return String(localized: "workflow.error.rateLimited", bundle: .module)

        case .networkError(let underlying):
            return String(format: String(localized: "workflow.error.networkError", bundle: .module), underlying.localizedDescription)

        case .httpError(let statusCode, let message):
            if let message {
                return String(format: String(localized: "workflow.error.httpErrorWithMessage", bundle: .module), statusCode, message)
            }
            return String(format: String(localized: "workflow.error.httpError", bundle: .module), statusCode)

        case .invalidInput(let key, let reason):
            return String(format: String(localized: "workflow.error.invalidInput", bundle: .module), key, reason)

        case .runNotFound(let runId, let repo):
            return String(format: String(localized: "workflow.error.runNotFound", bundle: .module), runId, repo)

        case .timeout(let reason):
            return String(format: String(localized: "workflow.error.timeout", bundle: .module), reason)

        case .runFailed(let runId, let conclusion):
            return String(format: String(localized: "workflow.error.runFailed", bundle: .module), runId, conclusion.rawValue)
        }
    }
}
