# GHActionTrigger

The GHActionTrigger is a Swift library and CLI tool which enables developers to trigger GitHub Actions through macOS apps or by CLI commands.

## Installation

### Homebrew (Recommended)

```bash
brew install igorcferreira/tap/ghaction
```

### From Source

```bash
git clone https://github.com/igorcferreira/GHActionTrigger.git
cd GHActionTrigger
swift build -c release
cp .build/release/ghaction /usr/local/bin/
```

## Folder Structure

- Sources/GHActionTrigger: Classes related to the Swift library, it holds the main logic.
- Sources/GHActionTriggerCLI: Implements the necessary code to expose the GHActionTrigger public methods/classes as a CLI command.

The `GHActionTriggerCLI` uses Apple's [Swift Argument Parser](https://github.com/apple/swift-argument-parser) library to accept input parameters and build the necessary executable.

## Dependencies

- **[swift-argument-parser](https://github.com/apple/swift-argument-parser)** (v1.2.0+) - Apple's library for CLI argument parsing

## Architecture

```
macOS Apps ─┬─► GHActionTrigger Library ─► GitHub Actions API
            │
CLI Users ──┴─► ghaction CLI (wraps library)
```

## Authentication

GHActionTrigger supports three authentication methods, checked in priority order:

| Priority | Method | Use Case |
|----------|--------|----------|
| 1 | Environment Variable | CI/CD pipelines |
| 2 | OAuth Device Flow | Interactive CLI usage |
| 3 | Personal Access Token | Manual fallback |

### Environment Variable (Recommended for CI/CD)

Set the `GITHUB_TOKEN` environment variable:

```bash
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
ghaction auth status
```

### OAuth Device Flow (Recommended for CLI)

Authenticate interactively using GitHub's Device Flow:

```bash
ghaction auth login --client-id <your-oauth-app-client-id>
```

This will display a code to enter at https://github.com/login/device. Use `--open-browser` to automatically open the URL.

To use OAuth Device Flow, you need to:
1. Create a GitHub OAuth App at https://github.com/settings/developers
2. Enable "Device Authorization Flow" in the app settings
3. Use the Client ID with `--client-id` or set `GHACTIONTRIGGER_CLIENT_ID` environment variable

### Personal Access Token

Store a PAT directly:

```bash
ghaction auth token --token ghp_xxxxxxxxxxxx
```

Create a PAT at https://github.com/settings/tokens with `repo` and `workflow` scopes.

### CLI Commands

```bash
# Check authentication status
ghaction auth status

# Login with OAuth Device Flow
ghaction auth login --client-id <id> [--scopes "repo workflow"] [--open-browser]

# Store a Personal Access Token
ghaction auth token --token <pat>

# Remove stored credentials
ghaction auth logout [--force]
```

### Programmatic Usage

```swift
import GHActionTrigger

// Create authentication manager
let authManager = AuthenticationManager()

// Get credentials (checks env var, then stored OAuth/PAT)
let credentials = try await authManager.getCredentials()

// Check status
let status = await authManager.status()
if status.isAuthenticated {
    print("Authenticated via \(status.provider ?? "unknown")")
}

// Use credentials for API requests
var request = URLRequest(url: apiURL)
request.setValue(credentials.authorizationHeader, forHTTPHeaderField: "Authorization")
```

## Triggering Workflows

Trigger GitHub Actions workflows that have `workflow_dispatch` enabled.

### CLI Usage

```bash
# Basic trigger (uses 'main' branch by default)
ghaction trigger --owner <owner> --repo <repo> --workflow <workflow.yml>

# Short form
ghaction trigger -o octocat -r hello-world -w ci.yml

# Specify a branch or tag
ghaction trigger -o octocat -r hello-world -w deploy.yml --ref release/v1.0

# With workflow inputs
ghaction trigger -o octocat -r hello-world -w deploy.yml \
  --input env=production \
  --input version=1.2.3
```

### CLI Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--owner` | `-o` | Repository owner (user or org) | Required |
| `--repo` | `-r` | Repository name | Required |
| `--workflow` | `-w` | Workflow filename or ID | Required |
| `--ref` | | Git ref (branch, tag, SHA) | `main` |
| `--input` | `-i` | Workflow input (key=value) | None |
| `--wait` | | Wait for workflow run to complete | `false` |
| `--poll-interval` | | Seconds between status checks (with --wait) | `10` |
| `--timeout` | | Maximum wait time in seconds (with --wait) | `3600` |

### Waiting for Completion

Use the `--wait` flag to monitor the triggered workflow until it completes. The CLI displays real-time progress including run status and job progress:

```bash
# Trigger and wait for completion
ghaction trigger -o octocat -r hello-world -w ci.yml --wait

# With custom poll interval and timeout
ghaction trigger -o octocat -r hello-world -w deploy.yml --wait --poll-interval 5 --timeout 1800
```

Example output with `--wait`:
```
✓ Workflow dispatch triggered successfully!
  Waiting for workflow run to start...
  Found run #17 (ID: 21691966064)
  View at: https://github.com/octocat/hello-world/actions/runs/21691966064

Run status: Queued
Run status: In Progress

Jobs:
  ◐ Build: running
      ▸ Run tests
  ✓ Lint: success

Run status: Completed

Final job results:
  ✓ Build: success
  ✓ Lint: success

✓ Workflow run completed successfully!
```

### Programmatic Usage

```swift
import GHActionTrigger

// Set up authentication and trigger
let authManager = AuthenticationManager()
let trigger = WorkflowTrigger(authManager: authManager)

// Define the workflow
let workflow = WorkflowIdentifier(
    owner: "octocat",
    repo: "hello-world",
    workflowId: "ci.yml"
)

// Trigger with inputs
try await trigger.trigger(
    workflow: workflow,
    ref: "main",
    inputs: ["env": "production", "version": "1.2.3"]
)

// List available workflows
let workflows = try await trigger.listWorkflows(owner: "octocat", repo: "hello-world")
for workflow in workflows {
    print("\(workflow.name) - \(workflow.path)")
}
```

### Requirements

- The workflow must have `workflow_dispatch` trigger enabled in its YAML:
  ```yaml
  on:
    workflow_dispatch:
      inputs:
        env:
          description: 'Environment'
          required: true
  ```
- Your token must have `repo` or `workflow` scope

## Monitoring Workflow Runs

Monitor and check the status of GitHub Actions workflow runs.

### CLI Usage

```bash
# List recent workflow runs
ghaction runs list -o octocat -r hello-world

# List runs with filters
ghaction runs list -o octocat -r hello-world --workflow ci.yml --limit 5

# Get details of a specific run
ghaction runs get -o octocat -r hello-world 123456789

# Watch a run until completion
ghaction runs watch -o octocat -r hello-world 123456789 --poll-interval 5
```

### Runs Command Options

**List runs:**
| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--owner` | `-o` | Repository owner | Required |
| `--repo` | `-r` | Repository name | Required |
| `--workflow` | `-w` | Filter by workflow filename | None |
| `--branch` | | Filter by branch name | None |
| `--event` | | Filter by event type | None |
| `--limit` | `-l` | Maximum runs to show | `10` |

**Get/Watch run:**
| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--owner` | `-o` | Repository owner | Required |
| `--repo` | `-r` | Repository name | Required |
| `<run-id>` | | Workflow run ID | Required |
| `--poll-interval` | | Seconds between checks (watch only) | `10` |
| `--timeout` | | Maximum wait time (watch only) | `3600` |

### Programmatic Usage

```swift
import GHActionTrigger

let authManager = AuthenticationManager()
let trigger = WorkflowTrigger(authManager: authManager)

// List recent runs
let runs = try await trigger.listRuns(
    owner: "octocat",
    repo: "hello-world",
    filter: WorkflowRunsFilter(event: "workflow_dispatch", perPage: 10)
)

for run in runs {
    print("#\(run.runNumber): \(run.status) - \(run.conclusion?.rawValue ?? "in progress")")
}

// Get a specific run
let run = try await trigger.getRun(owner: "octocat", repo: "hello-world", runId: 123456789)
print("Run status: \(run.status), conclusion: \(run.conclusion?.rawValue ?? "pending")")

// Get jobs for a run
let jobs = try await trigger.getJobs(owner: "octocat", repo: "hello-world", runId: 123456789)
for job in jobs {
    print("\(job.name): \(job.status) - \(job.conclusion?.rawValue ?? "in progress")")
    if let steps = job.steps {
        for step in steps {
            print("  - \(step.name): \(step.status)")
        }
    }
}

// Wait for a run to complete
let completedRun = try await trigger.waitForCompletion(
    owner: "octocat",
    repo: "hello-world",
    runId: 123456789,
    pollInterval: 10,
    timeout: 3600
)
print("Final status: \(completedRun.conclusion?.rawValue ?? "unknown")")
```
