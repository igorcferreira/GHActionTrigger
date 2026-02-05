# ghaction CLI Skill

This skill teaches agents how to use the ghaction CLI to trigger and monitor GitHub Actions workflows.

## When to Use

Use this skill when:
- The user wants to trigger a GitHub Actions workflow
- The user wants to check the status of workflow runs
- The user wants to monitor a workflow until completion
- The user asks about GitHub Actions in this repository

## Authentication

Before using ghaction, verify authentication:

```bash
ghaction auth status
```

If not authenticated, use one of these methods:

```bash
# Option 1: Environment variable (recommended for CI)
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx

# Option 2: Store a Personal Access Token
ghaction auth token --token ghp_xxxxxxxxxxxx

# Option 3: OAuth Device Flow (interactive)
ghaction auth login --client-id <oauth-app-client-id>
```

## Commands Reference

### Trigger Workflow

```bash
ghaction trigger -o <owner> -r <repo> -w <workflow.yml> [options]
```

**Options:**
- `-o, --owner` - Repository owner (required)
- `-r, --repo` - Repository name (required)
- `-w, --workflow` - Workflow filename (required)
- `--ref` - Git ref (default: main)
- `-i, --input` - Workflow input as key=value (repeatable)
- `--wait` - Wait for completion
- `--poll-interval` - Poll interval in seconds (default: 2)
- `--timeout` - Timeout in seconds (default: 3600)

### List Runs

```bash
ghaction runs list -o <owner> -r <repo> [options]
```

**Options:**
- `-w, --workflow` - Filter by workflow
- `--branch` - Filter by branch
- `--event` - Filter by event type
- `-l, --limit` - Max runs to show (default: 10)

### Get Run

```bash
ghaction runs get -o <owner> -r <repo> <run-id>
```

### Watch Run

```bash
ghaction runs watch -o <owner> -r <repo> <run-id> [options]
```

**Options:**
- `--poll-interval` - Poll interval (default: 10)
- `--timeout` - Timeout (default: 3600)

## Status Icons

| Icon | Meaning |
|------|---------|
| `○` | Queued/Waiting |
| `◐` | In Progress |
| `✓` | Success |
| `✗` | Failed |
| `⊘` | Cancelled/Skipped |

## Example Workflows

### Trigger CI and wait
```bash
ghaction trigger -o igorcferreira -r GHActionTrigger -w ci.yml --wait
```

### Deploy with inputs
```bash
ghaction trigger -o owner -r repo -w deploy.yml \
  --input environment=production \
  --input version=1.2.3 \
  --wait
```

### Check recent runs
```bash
ghaction runs list -o owner -r repo -w ci.yml --limit 5
```

## Error Handling

| Error | Solution |
|-------|----------|
| Not authenticated | Set GITHUB_TOKEN or run `ghaction auth token` |
| Workflow not found | Check workflow filename in `.github/workflows/` |
| Repository not found | Verify owner/repo and token permissions |
| workflow_dispatch not enabled | Add `workflow_dispatch` trigger to workflow YAML |
