# Skill: run-persona-review

Spawn a single persona sub-agent to analyze a PR diff from a specialized perspective.

## Input

- `persona` — Which persona to run: `security-sentinel`, `performance-pursuer`, or `quality-custodian`
- `diff_content` — The full PR diff
- `pr_title` — PR title
- `pr_author` — PR author name
- `source_branch` — Source branch name
- `dest_branch` — Destination branch name
- `full_files` — (Optional) Map of file_path → full content for additional context

## Workflow

### Step 1: Load Persona Prompt

Read the persona prompt from `reviewers/{persona}.md`.

The persona markdown files contain placeholder variables:
- `{title}` → PR title
- `{author}` → PR author
- `{source}` → Source branch
- `{destination}` → Destination branch
- `{diff}` → PR diff content
- `{ignore_instructions}` → (empty string, or instructions to skip certain files)

### Step 2: Substitute Placeholders

Replace all placeholders in the persona prompt with actual values.

### Step 3: Add Full File Context

If `full_files` is provided, append to the prompt:

```
## Full File Context (for deeper analysis)

The following files have been changed. Full content is provided for context:

--- path/to/file.py ---
{full_content}
---
```

Limit to the 5 largest changed files to avoid token overflow.

### Step 4: Spawn Sub-Agent

Use the `actor` tool to spawn a sub-agent:

```
actor({
  operation: {
    action: "run",
    subagent_type: "general",
    description: "Persona review: {persona}",
    prompt: "<the substituted persona prompt>"
  }
})
```

The sub-agent will analyze the diff and return structured JSON matching the persona's expected output format.

### Step 5: Validate Output

Verify the sub-agent returned valid JSON with the expected fields:
- `good_points` (array of strings)
- `attention_required` (array of strings)
- `risk_factors` (array of strings)
- `overall_quality_score` (number 0-100)
- `estimated_review_time` (string)
- `line_comments` (array of objects with `file_path`, `line_number`, `severity`, `message`)

If output is malformed, retry once with a simpler prompt. If still malformed, return empty result with error note.

## Output

Returns the persona's structured review JSON, tagged with the persona name:

```json
{
  "persona": "security-sentinel",
  "review": {
    "good_points": [...],
    "attention_required": [...],
    "risk_factors": [...],
    "overall_quality_score": 85,
    "estimated_review_time": "15min",
    "line_comments": [...]
  }
}
```

## Parallelism

When called by `pr-reviewer` agent, all 3 persona invocations should happen in parallel using separate `actor` tool calls in a single message. Do not run personas sequentially.

## Error Handling

- **Sub-agent timeout (>3min):** Return empty result with timeout error
- **Invalid JSON output:** Retry once, then return empty result
- **Persona file not found:** Error with message to check `reviewers/` directory
