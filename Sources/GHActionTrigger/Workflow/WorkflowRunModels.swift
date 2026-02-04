import Foundation

/// Status of a workflow run
public enum WorkflowRunStatus: String, Decodable, Sendable {
    case queued
    case inProgress = "in_progress"
    case completed
    case waiting
    case requested
    case pending
}

/// Conclusion of a completed workflow run
public enum WorkflowRunConclusion: String, Decodable, Sendable {
    case success
    case failure
    case cancelled
    case skipped
    case timedOut = "timed_out"
    case actionRequired = "action_required"
    case stale
    case neutral
    case startupFailure = "startup_failure"
}

/// Represents a workflow run from GitHub API
public struct WorkflowRun: Decodable, Sendable, Identifiable {
    public let id: Int
    public let name: String?
    public let workflowId: Int
    public let headBranch: String
    public let headSha: String
    public let status: WorkflowRunStatus
    public let conclusion: WorkflowRunConclusion?
    public let createdAt: Date
    public let updatedAt: Date
    public let runStartedAt: Date?
    public let htmlUrl: URL
    public let event: String
    public let runNumber: Int
    public let runAttempt: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case workflowId = "workflow_id"
        case headBranch = "head_branch"
        case headSha = "head_sha"
        case status
        case conclusion
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case runStartedAt = "run_started_at"
        case htmlUrl = "html_url"
        case event
        case runNumber = "run_number"
        case runAttempt = "run_attempt"
    }
}

/// Response from listing workflow runs
struct WorkflowRunsListResponse: Decodable, Sendable {
    let totalCount: Int
    let workflowRuns: [WorkflowRun]

    private enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case workflowRuns = "workflow_runs"
    }
}

// MARK: - Workflow Jobs

/// Status of a workflow job
public enum WorkflowJobStatus: String, Sendable {
    case queued
    case inProgress = "in_progress"
    case completed
    case waiting
    case pending
    case requested
    case unknown
}

extension WorkflowJobStatus: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = WorkflowJobStatus(rawValue: rawValue) ?? .unknown
    }
}

/// Conclusion of a completed workflow job
public enum WorkflowJobConclusion: String, Sendable {
    case success
    case failure
    case cancelled
    case skipped
    case timedOut = "timed_out"
    case actionRequired = "action_required"
    case neutral
    case stale
    case startupFailure = "startup_failure"
    case unknown
}

extension WorkflowJobConclusion: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = WorkflowJobConclusion(rawValue: rawValue) ?? .unknown
    }
}

/// Represents a step within a workflow job
public struct WorkflowStep: Decodable, Sendable {
    public let name: String
    public let status: WorkflowJobStatus
    public let conclusion: WorkflowJobConclusion?
    public let number: Int
    public let startedAt: Date?
    public let completedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case name
        case status
        case conclusion
        case number
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }
}

/// Represents a job within a workflow run
public struct WorkflowJob: Decodable, Sendable, Identifiable {
    public let id: Int
    public let runId: Int
    public let name: String
    public let status: WorkflowJobStatus
    public let conclusion: WorkflowJobConclusion?
    public let startedAt: Date?
    public let completedAt: Date?
    public let steps: [WorkflowStep]?
    public let htmlUrl: URL

    private enum CodingKeys: String, CodingKey {
        case id
        case runId = "run_id"
        case name
        case status
        case conclusion
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case steps
        case htmlUrl = "html_url"
    }
}

/// Response from listing workflow jobs
struct WorkflowJobsListResponse: Decodable, Sendable {
    let totalCount: Int
    let jobs: [WorkflowJob]

    private enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case jobs
    }
}

// MARK: - Filters

/// Filter options for listing workflow runs
public struct WorkflowRunsFilter: Sendable {
    public var workflowId: String?
    public var branch: String?
    public var event: String?
    public var status: WorkflowRunStatus?
    public var perPage: Int?
    public var page: Int?

    public init(
        workflowId: String? = nil,
        branch: String? = nil,
        event: String? = nil,
        status: WorkflowRunStatus? = nil,
        perPage: Int? = nil,
        page: Int? = nil
    ) {
        self.workflowId = workflowId
        self.branch = branch
        self.event = event
        self.status = status
        self.perPage = perPage
        self.page = page
    }

    func queryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let workflowId { items.append(URLQueryItem(name: "workflow_id", value: workflowId)) }
        if let branch { items.append(URLQueryItem(name: "branch", value: branch)) }
        if let event { items.append(URLQueryItem(name: "event", value: event)) }
        if let status { items.append(URLQueryItem(name: "status", value: status.rawValue)) }
        if let perPage { items.append(URLQueryItem(name: "per_page", value: String(perPage))) }
        if let page { items.append(URLQueryItem(name: "page", value: String(page))) }
        return items
    }
}
