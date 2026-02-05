# Monitor GitHub Actions Runs

Monitor and check the status of GitHub Actions workflow runs using the ghaction CLI.

## Usage

```
/ghaction-cli:monitor-runs [owner] [repo] [command] [options]
```

## Instructions

When the user wants to check workflow run status:

1. **Check authentication**:
   ```bash
   ghaction auth status
   ```

2. **Use the appropriate runs subcommand**:
   - `runs list` - List recent workflow runs
   - `runs get` - Get details of a specific run
   - `runs watch` - Watch a run until completion

## List Runs

```bash
ghaction runs list -o <owner> -r <repo> [options]
```

### Options

| Option | Short | Description |
|--------|-------|-------------|
| `--owner` | `-o` | Repository owner (required) |
| `--repo` | `-r` | Repository name (required) |
| `--workflow` | `-w` | Filter by workflow filename |
| `--branch` | | Filter by branch name |
| `--event` | | Filter by event type (push, pull_request, workflow_dispatch) |
| `--limit` | `-l` | Maximum runs to show (default: 10) |

### Examples

```bash
# List recent runs
ghaction runs list -o igorcferreira -r GHActionTrigger

# Filter by workflow
ghaction runs list -o owner -r repo -w ci.yml --limit 5

# Filter by event type
ghaction runs list -o owner -r repo --event workflow_dispatch
```

## Get Run Details

```bash
ghaction runs get -o <owner> -r <repo> <run-id>
```

### Example

```bash
ghaction runs get -o igorcferreira -r GHActionTrigger 21691966064
```

### Output

```
Workflow Run #17

  Name:       CI
  ID:         21691966064
  Status:     Completed
  Conclusion: success
  Event:      workflow_dispatch
  Branch:     main
  Commit:     a1b2c3d
  Attempt:    1
  Created:    5 Feb 2026 at 00:10
  Updated:    5 Feb 2026 at 00:11
  URL:        https://github.com/owner/repo/actions/runs/21691966064
```

## Watch Run

Watch a run until it completes, showing live status updates:

```bash
ghaction runs watch -o <owner> -r <repo> <run-id> [options]
```

### Options

| Option | Description |
|--------|-------------|
| `--poll-interval` | Seconds between status checks (default: 10) |
| `--timeout` | Maximum wait time in seconds (default: 3600) |

### Example

```bash
ghaction runs watch -o igorcferreira -r GHActionTrigger 21691966064 --poll-interval 5
```

## Status Icons

| Icon | Meaning |
|------|---------|
| `○` | Queued/Waiting |
| `◐` | In Progress |
| `✓` | Success |
| `✗` | Failed/Timed Out |
| `⊘` | Cancelled/Skipped |
| `●` | Completed (other) |

## Common Workflows

### Check if latest CI passed
```bash
ghaction runs list -o owner -r repo -w ci.yml --limit 1
```

### Watch a specific run until done
```bash
ghaction runs watch -o owner -r repo 123456789
```
