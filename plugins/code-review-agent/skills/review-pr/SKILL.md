# Skill: review-pr

Main entry point for PR review. Invoked as `/review-pr`. Delegates to the `pr-reviewer` agent for full pipeline orchestration.

## Invocation

```
/review-pr [workspace] [repo] [--skip-personas] [--max-prs N]
```

## Behavior

When invoked, this skill instructs the agent to:

1. **Load the `pr-reviewer` agent** from `agents/pr-reviewer.md`
2. **Execute the full pipeline** as defined in the agent definition
3. **Write results to a markdown file** at `~/.pr-review-agent/reviews/{workspace}_{repo}_PR{id}_{date}.md`

## Arguments

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `workspace` | No | From config (`BITBUCKET_WORKSPACE`) | Bitbucket workspace |
| `repo` | No | All repos | Repository slug |
| `--skip-personas` | No | false | Skip multi-persona analysis |
| `--max-prs N` | No | 10 | Max PRs to fetch |

## Quick Reference

```bash
# Review all PRs in default workspace
/review-pr

# Review PRs in specific repo
/review-pr myworkspace my-repo

# Review with pipeline only (no personas)
/review-pr --skip-personas

# Review up to 20 PRs
/review-pr --max-prs 20
```

## What Happens Under the Hood

1. `fetch-prs` → Bitbucket API → list of PRs
2. User selects PR(s)
3. `run-pr-review` → deterministic pipeline review
4. `run-persona-review` × 3 → Security + Performance + Quality (parallel)
5. `merge-review-findings` → deduplicated, scored results
6. Write to `~/.pr-review-agent/reviews/{workspace}_{repo}_PR{id}_{date}.md`
7. Optional: `post-review-comments` reads the review file → Bitbucket API

## Prerequisites

- `~/.pr-review-agent/.env` with Bitbucket credentials
- Git installed
- Network access to Bitbucket API

## Error Messages

- **"No credentials found"** → Guide user to create `~/.pr-review-agent/.env`
- **"API connection failed"** → Check credentials and network
- **"No PRs found"** → Check workspace/repo settings, verify user is a reviewer
