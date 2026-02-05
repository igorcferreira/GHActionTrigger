# Trigger GitHub Actions Workflow

Trigger a GitHub Actions workflow using the ghaction CLI.

## Usage

```
/ghaction-cli:trigger-workflow [owner] [repo] [workflow] [options]
```

## Instructions

When the user wants to trigger a GitHub Actions workflow:

1. **Check authentication**:
   ```bash
   ghaction auth status
   ```
   If not authenticated, guide the user to authenticate first.

2. **Trigger the workflow**:
   ```bash
   ghaction trigger -o <owner> -r <repo> -w <workflow.yml> [options]
   ```

## Options

| Option | Short | Description |
|--------|-------|-------------|
| `--owner` | `-o` | Repository owner (required) |
| `--repo` | `-r` | Repository name (required) |
| `--workflow` | `-w` | Workflow filename e.g., `ci.yml` (required) |
| `--ref` | | Git ref - branch, tag, or SHA (default: main) |
| `--input` | `-i` | Workflow input as `key=value` (repeatable) |
| `--wait` | | Wait for completion and show progress |
| `--poll-interval` | | Seconds between status checks (default: 2) |
| `--timeout` | | Maximum wait time in seconds (default: 3600) |

## Examples

### Basic trigger
```bash
ghaction trigger -o igorcferreira -r GHActionTrigger -w ci.yml
```

### Trigger and wait for completion
```bash
ghaction trigger -o igorcferreira -r GHActionTrigger -w ci.yml --wait
```

### Trigger with inputs
```bash
ghaction trigger -o owner -r repo -w deploy.yml \
  --input environment=production \
  --input version=1.2.3 \
  --wait
```

### Trigger specific branch
```bash
ghaction trigger -o owner -r repo -w ci.yml --ref feature/my-branch
```

## Output with --wait

When using `--wait`, you'll see real-time progress:

```
✓ Workflow dispatch triggered successfully!
  Waiting for workflow run to start...
  Found run #17 (ID: 21691966064)
  View at: https://github.com/owner/repo/actions/runs/21691966064

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

## Status Icons

| Icon | Meaning |
|------|---------|
| `○` | Queued/Waiting |
| `◐` | In Progress |
| `✓` | Success |
| `✗` | Failed |
| `⊘` | Cancelled/Skipped |
