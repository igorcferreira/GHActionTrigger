import Foundation

/// Identifies a GitHub Actions workflow
public struct WorkflowIdentifier: Sendable, Equatable {
    /// Repository owner (username or organization)
    public let owner: String
    /// Repository name
    public let repo: String
    /// Workflow ID (filename like "ci.yml" or numeric ID)
    public let workflowId: String

    public init(owner: String, repo: String, workflowId: String) {
        self.owner = owner
        self.repo = repo
        self.workflowId = workflowId
    }

    /// Full repository path (owner/repo)
    public var fullRepo: String {
        "\(owner)/\(repo)"
    }
}

/// Request body for workflow dispatch API
public struct WorkflowDispatchRequest: Encodable, Sendable {
    /// Git reference (branch name, tag, or SHA)
    public let ref: String
    /// Optional workflow inputs
    public let inputs: [String: String]?

    public init(ref: String, inputs: [String: String]? = nil) {
        self.ref = ref
        self.inputs = inputs
    }
}

/// Information about a workflow
public struct WorkflowInfo: Decodable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let path: String
    public let state: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case path
        case state
    }
}

/// Response from listing workflows
struct WorkflowListResponse: Decodable, Sendable {
    let totalCount: Int
    let workflows: [WorkflowInfo]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case workflows
    }
}

/// GitHub API error response
struct GitHubErrorResponse: Decodable, Sendable {
    let message: String
    let documentationUrl: String?

    enum CodingKeys: String, CodingKey {
        case message
        case documentationUrl = "documentation_url"
    }
}
