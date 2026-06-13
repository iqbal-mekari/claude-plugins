# Skill: fetch-prs

Fetch open Bitbucket PRs assigned to the authenticated user.

## Prerequisites

Before fetching PRs, verify credentials exist:

```bash
# Check if .env file exists
test -f ~/.pr-review-agent/.env && echo "Config found" || echo "NOT CONFIGURED"
```

If not configured, tell the user to create `~/.pr-review-agent/.env`:

```bash
mkdir -p ~/.pr-review-agent
cat > ~/.pr-review-agent/.env << 'EOF'
BITBUCKET_EMAIL=user@example.com
BITBUCKET_API_TOKEN=your-api-token-here
BITBUCKET_WORKSPACE=your-workspace
EOF
chmod 600 ~/.pr-review-agent/.env
```

Never invent or hardcode credentials. Ask the user to provide them.

## Workflow

### Step 1: Load Credentials

Read from `~/.pr-review-agent/.env` (preferred) or environment variables:
- `BITBUCKET_EMAIL` or `PR_AGENT_BITBUCKET_EMAIL`
- `BITBUCKET_API_TOKEN` or `PR_AGENT_BITBUCKET_API_TOKEN`
- `BITBUCKET_WORKSPACE` or `PR_AGENT_BITBUCKET_WORKSPACE`
- `BITBUCKET_BASE_URL` (default: `https://api.bitbucket.org/2.0`)

### Step 2: Get Current User UUID

```bash
curl -s -u "${EMAIL}:${TOKEN}" "${BASE_URL}/user" | jq -r '.uuid'
```

Strip the `{` and `}` braces from the UUID if present.

### Step 3: Fetch PRs

**Workspace-wide** (no repo specified):
```bash
curl -s -u "${EMAIL}:${TOKEN}" \
  "${BASE_URL}/repositories/${WORKSPACE}/pullrequests?q=state%3D%22OPEN%22+AND+reviewers.uuid%3D%22${UUID}%22&sort=-updated_on&pagelen=30"
```

**Repo-specific** (repo slug provided):
```bash
curl -s -u "${EMAIL}:${TOKEN}" \
  "${BASE_URL}/repositories/${WORKSPACE}/${REPO}/pullrequests?q=state%3D%22OPEN%22+AND+reviewers.uuid%3D%22${UUID}%22&sort=-updated_on&pagelen=30"
```

### Step 4: Parse and Return

Extract from each PR in the response:
- `id` — PR number
- `title` — PR title
- `author.display_name` — Author name
- `source.branch.name` — Source branch
- `destination.branch.name` — Destination branch
- `created_on` — Creation date
- `updated_on` — Last update date
- `links.html.href` — PR URL
- `source.repository.full_name` — Repo slug (for workspace-wide)

Return as a structured list. If no PRs found, inform the user clearly.

### Step 5: Filter Already-Reviewed PRs

For each PR, check if the user has already approved or declined:
```bash
curl -s -u "${EMAIL}:${TOKEN}" \
  "${BASE_URL}/repositories/${WORKSPACE}/${REPO}/pullrequests/${PR_ID}/participants"
```

Filter out PRs where the current user's `state` is `approved` or `rejected`.

## Error Handling

- **401 Unauthorized**: Token is invalid or expired. Guide user to create a new API token.
- **403 Forbidden**: Token lacks required permissions. Needs `pullrequests:read` and `repositories:read`.
- **404 Not Found**: Workspace or repo doesn't exist, or token lacks access.
- **Rate limited**: Wait and retry. Bitbucket allows 1000 requests/hour.

## Output

Return a list of PRs with this information for each:
- PR number and title
- Author name
- Source → destination branch
- Age (human-readable: "2 hours ago", "3 days ago")
- Repo slug (if workspace-wide search)
- PR URL
