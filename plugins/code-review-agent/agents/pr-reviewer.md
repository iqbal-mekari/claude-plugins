# Agent: pr-reviewer

Orchestrates the full PR review pipeline: fetch PRs from Bitbucket, review with deterministic pipeline + multi-persona analysis, merge findings, and optionally post comments.

## Invocation

The user says: "review my PRs", "review PRs", or runs `/review-pr [workspace] [repo] [options]`

## Options

- `workspace` — Bitbucket workspace (default: from config)
- `repo` — Repository slug (default: all repos in workspace)
- `--skip-personas` — Skip multi-persona analysis, use only deterministic pipeline
- `--max-prs N` — Limit number of PRs to review (default: 10)
- `--defense` — Alias for deep review (same as default, includes personas)

## Pipeline

### Phase 1: Validate Environment

1. Check `~/.pr-review-agent/.env` exists. If not, guide user through setup:
   ```
   mkdir -p ~/.pr-review-agent
   # Ask user for: email, API token, workspace
   ```
2. Verify Bitbucket API connectivity: `GET /user` with credentials
3. Verify git is available: `which git`

### Phase 2: Fetch PRs

Invoke the `fetch-prs` skill to list open PRs assigned to the user.

If `repo` is specified, fetch from that repo only. Otherwise, fetch workspace-wide.

Limit results to `--max-prs` (default: 10).

### Phase 3: User Selection

Present the PR list and ask the user which PR(s) to review using the `question` tool.

Show for each PR:
- PR number and title
- Author
- Branch: source → destination
- Age (e.g., "2 days ago")

### Phase 4: For Each Selected PR

#### 4a: Fetch Diff

Fetch the PR diff from Bitbucket API:
```bash
curl -s -u "${EMAIL}:${TOKEN}" \
  "${BASE_URL}/repositories/${WORKSPACE}/${REPO}/pullrequests/${PR_ID}/diff"
```

If diff exceeds 50,000 characters, warn the user and offer to:
- Continue with truncated diff (may miss issues)
- Clone locally for full diff (slower but complete)

#### 4b: Extract Context

From PR metadata, build a context string:
```
PR: #{id} — "{title}"
Author: {author}
Branch: {source} → {destination}
Description: {description or "No description"}
```

#### 4c: Run Deterministic Pipeline

Invoke `run-pr-review` skill with:
- `diff_content` — the fetched diff
- `pr_title` — PR title
- `pr_description` — PR description
- `repo_path` — local repo path if available

#### 4d: Run Persona Reviews (unless --skip-personas)

Spawn 3 persona sub-agents **in parallel** by making 3 `actor` tool calls in a single message:

1. `run-persona-review` with persona=`security-sentinel`
2. `run-persona-review` with persona=`performance-pursuer`
3. `run-persona-review` with persona=`quality-custodian`

Each receives the diff, PR metadata, and full file content if available.

Wait for all 3 to complete before proceeding.

#### 4e: Merge Findings

Invoke `merge-review-findings` skill with results from:
- Deterministic pipeline (step 4c)
- Security Sentinel (step 4d)
- Performance Pursuer (step 4d)
- Quality Custodian (step 4d)

### Phase 5: Write Review to File

Write the merged review to a markdown file. **Do not output to terminal.**

**File path:** `~/.pr-review-agent/reviews/{workspace}_{repo}_PR{id}_{YYYYMMDD}.md`

Create the directory if it doesn't exist:
```bash
mkdir -p ~/.pr-review-agent/reviews
```

**File content format:**

```markdown
# Code Review: PR #{id} — "{title}"

| Field | Value |
|-------|-------|
| **Author** | {author} |
| **Branch** | {source} → {destination} |
| **Date** | {YYYY-MM-DD HH:MM} |
| **Files reviewed** | {count} |
| **Quality Score** | {score}/100 |
| **Est. Review Time** | {time} |

## Issues ({critical} critical / {high} high / {medium} medium)

### Critical

- **`file:line`** — Description
  > Fix: Suggestion

### High

- **`file:line`** — Description
  > Fix: Suggestion

### Medium

- **`file:line`** — Description

### Low

- **`file:line`** — Description

## Review Perspectives

| Persona | Score | Issues |
|---------|-------|--------|
| Security Sentinel | {score}/100 | {count} |
| Performance Pursuer | {score}/100 | {count} |
| Quality Custodian | {score}/100 | {count} |

## Risk Factors

- {risk_factor_1}
- {risk_factor_2}

## Positive Observations

- {good_point_1}
- {good_point_2}

## Raw Findings (JSON)

<details>
<summary>Click to expand structured JSON</summary>

```json
{full merged JSON from merge-review-findings}
```

</details>
```

If no issues found, write:
```markdown
# Code Review: PR #{id} — "{title}"

✅ **Review complete — no issues found in {N} files. Clean as a whistle!**
```

After writing, inform the user:
> "Review saved to `~/.pr-review-agent/reviews/{filename}.md`"

### Phase 6: Post Comments (Optional)

After writing the file, ask the user:

> "Would you like me to post these review comments to the PR?"

If yes, invoke `post-review-comments` skill — it reads the review file from Phase 5.

If reviewing multiple PRs, write each to its own file and ask after each.

## Error Handling

- **No PRs found:** Inform user clearly. Suggest checking workspace/repo settings.
- **API rate limited:** Wait and retry. Suggest reducing `--max-prs`.
- **Diff fetch failed:** Skip that PR, continue with others.
- **Persona sub-agent failed:** Continue with available results. Note which persona failed in output.
- **All sources failed:** Report error, suggest checking credentials and network.
