import Foundation

/// Triggers GitHub Actions workflows via the GitHub REST API
public actor WorkflowTrigger {
    private let authManager: AuthenticationManager
    private let urlSession: URLSession
    private let baseURL = "https://api.github.com"
    private let apiVersion = "2022-11-28"

    public init(
        authManager: AuthenticationManager,
        urlSession: URLSession = .shared
    ) {
        self.authManager = authManager
        self.urlSession = urlSession
    }

    /// Trigger a workflow dispatch event
    /// - Parameters:
    ///   - workflow: The workflow identifier (owner, repo, workflow ID)
    ///   - ref: Git reference (branch name, tag, or SHA)
    ///   - inputs: Optional workflow input parameters
    /// - Throws: WorkflowError if the trigger fails
    public func trigger(
        workflow: WorkflowIdentifier,
        ref: String,
        inputs: [String: String]? = nil
    ) async throws {
        // Get authentication credentials
        let credentials: GitHubCredentials
        do {
            credentials = try await authManager.getCredentials()
        } catch {
            throw WorkflowError.notAuthenticated
        }

        // Build the API URL
        let urlString = "\(baseURL)/repos/\(workflow.owner)/\(workflow.repo)/actions/workflows/\(workflow.workflowId)/dispatches"
        guard let url = URL(string: urlString) else {
            throw WorkflowError.invalidInput(key: "workflow", reason: "Invalid URL components")
        }

        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(credentials.authorizationHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(apiVersion, forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Encode the request body
        let dispatchRequest = WorkflowDispatchRequest(ref: ref, inputs: inputs)
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(dispatchRequest)

        // Make the request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw WorkflowError.networkError(underlying: error)
        }

        // Handle the response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WorkflowError.networkError(underlying: URLError(.badServerResponse))
        }

        try handleResponse(statusCode: httpResponse.statusCode, data: data, workflow: workflow, ref: ref)
    }

    /// List available workflows for a repository
    /// - Parameters:
    ///   - owner: Repository owner
    ///   - repo: Repository name
    /// - Returns: Array of workflow information
    /// - Throws: WorkflowError if the request fails
    public func listWorkflows(
        owner: String,
        repo: String
    ) async throws -> [WorkflowInfo] {
        // Get authentication credentials
        let credentials: GitHubCredentials
        do {
            credentials = try await authManager.getCredentials()
        } catch {
            throw WorkflowError.notAuthenticated
        }

        // Build the API URL
        let urlString = "\(baseURL)/repos/\(owner)/\(repo)/actions/workflows"
        guard let url = URL(string: urlString) else {
            throw WorkflowError.invalidInput(key: "repository", reason: "Invalid URL components")
        }

        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(credentials.authorizationHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(apiVersion, forHTTPHeaderField: "X-GitHub-Api-Version")

        // Make the request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw WorkflowError.networkError(underlying: error)
        }

        // Handle the response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WorkflowError.networkError(underlying: URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            let listResponse = try decoder.decode(WorkflowListResponse.self, from: data)
            return listResponse.workflows

        case 401:
            throw WorkflowError.notAuthenticated

        case 403:
            if let resetTime = parseRateLimitReset(from: httpResponse) {
                throw WorkflowError.rateLimited(resetAt: resetTime)
            }
            throw WorkflowError.permissionDenied

        case 404:
            throw WorkflowError.repositoryNotFound(owner: owner, repo: repo)

        default:
            let message = parseErrorMessage(from: data)
            throw WorkflowError.httpError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    // MARK: - Workflow Runs

    /// List workflow runs for a repository
    /// - Parameters:
    ///   - owner: Repository owner
    ///   - repo: Repository name
    ///   - filter: Optional filter criteria
    /// - Returns: Array of workflow runs
    /// - Throws: WorkflowError if the request fails
    public func listRuns(
        owner: String,
        repo: String,
        filter: WorkflowRunsFilter? = nil
    ) async throws -> [WorkflowRun] {
        let credentials = try await getCredentials()

        var components = URLComponents(string: "\(baseURL)/repos/\(owner)/\(repo)/actions/runs")!
        if let filter {
            components.queryItems = filter.queryItems()
        }

        guard let url = components.url else {
            throw WorkflowError.invalidInput(key: "repository", reason: "Invalid URL components")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(credentials.authorizationHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(apiVersion, forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WorkflowError.networkError(underlying: URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let listResponse = try decoder.decode(WorkflowRunsListResponse.self, from: data)
            return listResponse.workflowRuns

        case 401:
            throw WorkflowError.notAuthenticated

        case 403:
            if let resetTime = parseRateLimitReset(from: httpResponse) {
                throw WorkflowError.rateLimited(resetAt: resetTime)
            }
            throw WorkflowError.permissionDenied

        case 404:
            throw WorkflowError.repositoryNotFound(owner: owner, repo: repo)

        default:
            let message = parseErrorMessage(from: data)
            throw WorkflowError.httpError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    /// Get a specific workflow run by ID
    /// - Parameters:
    ///   - owner: Repository owner
    ///   - repo: Repository name
    ///   - runId: The workflow run ID
    /// - Returns: The workflow run details
    /// - Throws: WorkflowError if the request fails
    public func getRun(
        owner: String,
        repo: String,
        runId: Int
    ) async throws -> WorkflowRun {
        let credentials = try await getCredentials()

        let urlString = "\(baseURL)/repos/\(owner)/\(repo)/actions/runs/\(runId)"
        guard let url = URL(string: urlString) else {
            throw WorkflowError.invalidInput(key: "runId", reason: "Invalid URL components")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(credentials.authorizationHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(apiVersion, forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WorkflowError.networkError(underlying: URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(WorkflowRun.self, from: data)

        case 401:
            throw WorkflowError.notAuthenticated

        case 403:
            if let resetTime = parseRateLimitReset(from: httpResponse) {
                throw WorkflowError.rateLimited(resetAt: resetTime)
            }
            throw WorkflowError.permissionDenied

        case 404:
            throw WorkflowError.runNotFound(runId: runId, repo: "\(owner)/\(repo)")

        default:
            let message = parseErrorMessage(from: data)
            throw WorkflowError.httpError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    /// Get jobs for a specific workflow run
    /// - Parameters:
    ///   - owner: Repository owner
    ///   - repo: Repository name
    ///   - runId: The workflow run ID
    /// - Returns: Array of jobs in the run
    /// - Throws: WorkflowError if the request fails
    public func getJobs(
        owner: String,
        repo: String,
        runId: Int
    ) async throws -> [WorkflowJob] {
        let credentials = try await getCredentials()

        let urlString = "\(baseURL)/repos/\(owner)/\(repo)/actions/runs/\(runId)/jobs"
        guard let url = URL(string: urlString) else {
            throw WorkflowError.invalidInput(key: "runId", reason: "Invalid URL components")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(credentials.authorizationHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(apiVersion, forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WorkflowError.networkError(underlying: URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let jobsResponse = try decoder.decode(WorkflowJobsListResponse.self, from: data)
            return jobsResponse.jobs

        case 401:
            throw WorkflowError.notAuthenticated

        case 403:
            if let resetTime = parseRateLimitReset(from: httpResponse) {
                throw WorkflowError.rateLimited(resetAt: resetTime)
            }
            throw WorkflowError.permissionDenied

        case 404:
            throw WorkflowError.runNotFound(runId: runId, repo: "\(owner)/\(repo)")

        default:
            let message = parseErrorMessage(from: data)
            throw WorkflowError.httpError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    /// Find a recent workflow run matching the trigger criteria
    /// - Parameters:
    ///   - workflow: The workflow identifier
    ///   - ref: The git reference that was triggered
    ///   - excludeRunIds: Set of run IDs to exclude (runs that existed before triggering)
    ///   - timeout: Maximum time to wait for the run to appear (default: 60 seconds)
    /// - Returns: The matching workflow run, or nil if not found
    public func findRecentRun(
        workflow: WorkflowIdentifier,
        ref: String,
        excludeRunIds: Set<Int> = [],
        timeout: TimeInterval = 60
    ) async throws -> WorkflowRun? {
        let deadline = Date().addingTimeInterval(timeout)
        // Don't filter by event - get all recent runs for faster API response
        let filter = WorkflowRunsFilter(perPage: 20)

        while Date() < deadline {
            let runs = try await listRuns(
                owner: workflow.owner,
                repo: workflow.repo,
                filter: filter
            )

            // Find a workflow_dispatch run on our branch that wasn't in the excluded set
            if let matchingRun = runs.first(where: {
                $0.headBranch == ref &&
                $0.event == "workflow_dispatch" &&
                !excludeRunIds.contains($0.id)
            }) {
                return matchingRun
            }

            // Wait before polling again
            try await Task.sleep(for: .seconds(2))
        }

        return nil
    }

    /// Wait for a workflow run to complete
    /// - Parameters:
    ///   - owner: Repository owner
    ///   - repo: Repository name
    ///   - runId: The workflow run ID
    ///   - pollInterval: Time between status checks (default: 10 seconds)
    ///   - timeout: Maximum time to wait (default: 1 hour)
    ///   - onUpdate: Optional callback for status updates
    /// - Returns: The completed workflow run
    /// - Throws: WorkflowError if the request fails or times out
    public func waitForCompletion(
        owner: String,
        repo: String,
        runId: Int,
        pollInterval: TimeInterval = 10,
        timeout: TimeInterval = 3600,
        onUpdate: (@Sendable (WorkflowRun) -> Void)? = nil
    ) async throws -> WorkflowRun {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let run = try await getRun(owner: owner, repo: repo, runId: runId)

            onUpdate?(run)

            if run.status == .completed {
                return run
            }

            try await Task.sleep(for: .seconds(pollInterval))
        }

        throw WorkflowError.timeout(reason: "Workflow run \(runId) did not complete within \(Int(timeout)) seconds")
    }

    // MARK: - Private Methods

    private func getCredentials() async throws -> GitHubCredentials {
        do {
            return try await authManager.getCredentials()
        } catch {
            throw WorkflowError.notAuthenticated
        }
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await urlSession.data(for: request)
        } catch {
            throw WorkflowError.networkError(underlying: error)
        }
    }

    private func handleResponse(
        statusCode: Int,
        data: Data,
        workflow: WorkflowIdentifier,
        ref: String
    ) throws {
        switch statusCode {
        case 204:
            // Success - workflow dispatch accepted
            return

        case 401:
            throw WorkflowError.notAuthenticated

        case 403:
            throw WorkflowError.permissionDenied

        case 404:
            // Could be repo not found or workflow not found
            let message = parseErrorMessage(from: data)
            if message?.lowercased().contains("workflow") == true {
                throw WorkflowError.workflowNotFound(workflow: workflow.workflowId, repo: workflow.fullRepo)
            }
            throw WorkflowError.repositoryNotFound(owner: workflow.owner, repo: workflow.repo)

        case 422:
            // Unprocessable entity - usually invalid ref or workflow_dispatch not enabled
            let message = parseErrorMessage(from: data)
            if message?.lowercased().contains("workflow_dispatch") == true ||
               message?.lowercased().contains("event type") == true {
                throw WorkflowError.workflowDispatchNotEnabled(workflow: workflow.workflowId)
            }
            if message?.lowercased().contains("ref") == true ||
               message?.lowercased().contains("branch") == true {
                throw WorkflowError.invalidRef(ref: ref)
            }
            throw WorkflowError.httpError(statusCode: statusCode, message: message)

        case 429:
            throw WorkflowError.rateLimited(resetAt: nil)

        default:
            let message = parseErrorMessage(from: data)
            throw WorkflowError.httpError(statusCode: statusCode, message: message)
        }
    }

    private func parseErrorMessage(from data: Data) -> String? {
        let decoder = JSONDecoder()
        if let errorResponse = try? decoder.decode(GitHubErrorResponse.self, from: data) {
            return errorResponse.message
        }
        return nil
    }

    private func parseRateLimitReset(from response: HTTPURLResponse) -> Date? {
        if let resetHeader = response.value(forHTTPHeaderField: "X-RateLimit-Reset"),
           let resetTimestamp = Double(resetHeader) {
            return Date(timeIntervalSince1970: resetTimestamp)
        }
        return nil
    }
}
