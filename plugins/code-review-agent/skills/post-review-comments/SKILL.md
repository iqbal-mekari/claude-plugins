# Skill: post-review-comments

Post review findings as Bitbucket PR comments — one summary comment + inline comments per issue.

## Input

- `workspace` — Bitbucket workspace
- `repo` — Repository slug
- `pr_id` — PR number
- `review_file` — Path to the review markdown file written by Phase 5 (e.g., `~/.pr-review-agent/reviews/{workspace}_{repo}_PR{id}_{date}.md`)

The review file contains the full structured review in markdown. The JSON block at the bottom (`<details>` section) is used for extracting `line_comments` for inline posting.

## CRITICAL: Always Confirm Before Posting

**Never post comments without explicit user confirmation.** Show a preview of what will be posted and ask:

> "I'm about to post {count} comments to PR #{id}. This includes 1 summary comment and {inline_count} inline comments. Proceed?"

Only post after the user says yes.

## Workflow

### Step 1: Load Credentials

Read from `~/.pr-review-agent/.env` or environment variables:
- `BITBUCKET_EMAIL` / `PR_AGENT_BITBUCKET_EMAIL`
- `BITBUCKET_API_TOKEN` / `PR_AGENT_BITBUCKET_API_TOKEN`

### Step 2: Read Review File

Read the review markdown file. Extract:
- The markdown summary (everything above the `<details>` section) — used for the Bitbucket summary comment
- The JSON block inside `<details>` — used for extracting `line_comments` for inline posting

### Step 3: Post Summary Comment

Format the summary as markdown:

```markdown
## AI PR Review Summary

**Files reviewed:** {files_reviewed}
**Issues found:** {critical} critical / {high} high / {medium} medium
**Quality Score:** {score}/100
**Est. Review Time:** {time}

### Review Perspectives
| Persona | Score | Issues |
|---------|-------|--------|
| Security Sentinel | {score}/100 | {count} |
| Performance Pursuer | {score}/100 | {count} |
| Quality Custodian | {score}/100 | {count} |

### Key Risk Factors
{risk_factors as bullet list}

### Positive Observations
{good_points as bullet list}

---
*Reviewed by Code Review Agent*
```

Post via Bitbucket API:
```bash
curl -s -X POST -u "${EMAIL}:${TOKEN}" \
  -H "Content-Type: application/json" \
  "${BASE_URL}/repositories/${WORKSPACE}/${REPO}/pullrequests/${PR_ID}/comment" \
  -d '{"content": {"raw": "<markdown content>"}}'
```

### Step 4: Post Inline Comments

For each `line_comment` in the review results, post an inline comment:

```bash
curl -s -X POST -u "${EMAIL}:${TOKEN}" \
  -H "Content-Type: application/json" \
  "${BASE_URL}/repositories/${WORKSPACE}/${REPO}/pullrequests/${PR_ID}/comments" \
  -d '{
    "content": {"raw": "[{severity}] {message}\n\n> {suggestion}"},
    "inline": {
      "from": null,
      "to": null,
      "path": "{file_path}",
      "new_lines": {line_number}
    }
  }'
```

**Severity emoji mapping:**
- `critical` → 🔴
- `high` → 🟠
- `medium` → 🟡
- `low` → 🟢

Format each inline comment as:
```markdown
🔴 **[Critical]** {message}

> {suggestion}
```

### Step 5: Report Results

After posting, report:
- Number of comments posted successfully
- Any failures (with error details)
- Link to the PR for the user to verify

## Rate Limiting

Bitbucket allows ~1000 requests/hour. If posting many inline comments:
- Add a 100ms delay between posts
- If rate limited (429), wait and retry with exponential backoff

## Error Handling

- **401 on post:** Token expired or invalid. Ask user to update credentials.
- **403 on post:** Token lacks `pullrequests:write` permission. Guide user to create new token.
- **404 on post:** PR not found or merged. Inform user.
- **Inline comment fails to anchor:** The line may not exist in the diff. Post as a regular comment instead with file:line reference in the text.
- **Summary post fails:** Report error, suggest posting manually.

## Output

```
✅ Posted to PR #123:
   - 1 summary comment
   - 5 inline comments (3 high, 2 medium)
   - View: https://bitbucket.org/workspace/repo/pull-requests/123
```
