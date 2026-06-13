# Code Review Agent — Workspace Instructions

This plugin provides AI-powered PR review for Bitbucket. It fetches PRs assigned to the user, reviews them using a deterministic pipeline with multi-persona sub-agents, and posts structured comments back to Bitbucket.

## Critical Rules

1. **Read `skills/review-pr/SKILL.md` before any review task.** It is the authoritative entry point.
2. **Never post comments to Bitbucket without user confirmation.** Always ask before posting.
3. **Never commit or log Bitbucket credentials.** Read from `~/.pr-review-agent/.env` or environment variables only.
4. **Always run persona sub-agents in parallel.** The 3 personas (Security, Performance, Quality) must execute concurrently, not sequentially.
5. **Deduplicate findings before presenting.** Same file + same line + similar issue = keep highest severity only.
6. **OCR is not installed.** This plugin implements OCR's deterministic pipeline concepts natively using Claude Code's built-in LLM. Do not attempt to invoke `ocr` CLI.

## Agent

| Agent | Role | Invocable |
|-------|------|----------|
| `pr-reviewer` | Orchestrates the full PR review pipeline: fetch → diff → review → personas → merge → post | ✅ |

## Skills

| Skill | Invocation | Purpose |
|-------|------------|----------|
| `review-pr` | `/review-pr` | Main entry — full pipeline from fetch to post |
| `fetch-prs` | (called by agent) | Fetch Bitbucket PRs assigned to user |
| `run-pr-review` | (called by agent) | Deterministic pipeline review of a PR diff |
| `run-persona-review` | (called by agent) | Spawn one persona sub-agent for focused review |
| `merge-review-findings` | (called by agent) | Deduplicate and prioritize findings from all sources |
| `post-review-comments` | (called by agent) | Post summary + inline comments to Bitbucket |

## Configuration

### Credentials (`~/.pr-review-agent/.env`)

```bash
BITBUCKET_EMAIL=user@example.com
BITBUCKET_API_TOKEN=your-api-token
BITBUCKET_WORKSPACE=your-workspace
BITBUCKET_BASE_URL=https://api.bitbucket.org/2.0
```

### Review Rules (optional)

Two locations, first match wins:
1. Project: `<repo>/.code-review-agent/review-rules.json`
2. Global: `~/.code-review-agent/review-rules.json`

```json
{
  "rules": [
    { "path": "**/*.java", "rule": "Check for null safety and resource leaks" },
    { "path": "**/*mapper*.xml", "rule": "Check SQL for injection risks" }
  ],
  "include": [],
  "exclude": ["**/generated/**", "**/*.g.dart"]
}
```

## Output Format

Reviews are written to markdown files, **not** output to terminal.

**File path:** `~/.pr-review-agent/reviews/{workspace}_{repo}_PR{id}_{date}.md`

Each file contains:
- PR metadata table (author, branch, date, files reviewed, quality score)
- Issues grouped by severity: Critical → High → Medium → Low
- Review perspectives table (persona scores and issue counts)
- Risk factors and positive observations
- Raw JSON findings in a collapsible `<details>` block (used for Bitbucket posting)

Reviews produce structured findings grouped by severity:
- **Critical**: Security vulnerabilities, data loss risks, crashes
- **High**: Bugs, significant performance issues, architectural violations
- **Medium**: Code smells, minor performance opportunities, naming issues
- **Low**: Style nits, documentation gaps

Each finding includes: file path, line number, severity, description, and optional fix suggestion.

## Scope

- **Bitbucket only.** No GitHub or GitLab support.
- **PR review only.** No CI/CD pipeline integration.
- **No external CLI.** All logic runs natively in Claude Code.
- **Read + comment only.** No auto-approve, no branch creation, no commits.
