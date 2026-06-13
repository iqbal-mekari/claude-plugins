# Skill: merge-review-findings

Deduplicate and prioritize review findings from multiple sources (deterministic pipeline + persona sub-agents).

## Input

This skill receives findings from up to 4 sources:
1. **Deterministic pipeline** (from `run-pr-review`) — line-level comments with severity
2. **Security Sentinel** (from `run-persona-review`) — security-focused findings
3. **Performance Pursuer** (from `run-persona-review`) — performance-focused findings
4. **Quality Custodian** (from `run-persona-review`) — architecture/quality findings

Each source provides:
```json
{
  "good_points": ["..."],
  "attention_required": ["..."],
  "risk_factors": ["..."],
  "overall_quality_score": 85,
  "estimated_review_time": "15min",
  "line_comments": [
    {
      "file_path": "src/auth.py",
      "line_number": 42,
      "severity": "critical",
      "message": "SQL injection vulnerability",
      "suggestion": "Use parameterized queries"
    }
  ]
}
```

## Workflow

### Step 1: Collect All Line Comments

Gather `line_comments` from all sources into a single list. Tag each comment with its source (pipeline, security, performance, quality).

### Step 2: Deduplicate

Group comments by `file_path` + `line_number` (±2 lines tolerance). Within each group:
- If comments describe the same issue: keep the one with highest severity
- If comments describe different issues at the same location: keep both
- If comments from different sources complement each other: merge messages

**Similarity heuristic:** Comments are "the same issue" if they share 3+ keywords (excluding common words like "the", "is", "should").

### Step 3: Sort by Severity

Order: `critical` → `high` → `medium` → `low`

Within the same severity, sort by file path alphabetically.

### Step 4: Calculate Aggregate Metrics

**Quality Score:** Weighted average of all persona scores.
- Weight: pipeline=0.4, security=0.25, performance=0.2, quality=0.15
- If persona not available, redistribute weights equally

**Risk Factors:** Union of all persona `risk_factors` arrays (deduplicated).

**Good Points:** Union of all `good_points` arrays (deduplicated, max 5).

**Attention Required:** From deduplicated line_comments, extract the top issues (max 5) for the summary.

**Estimated Review Time:** Maximum of all persona estimates.

### Step 5: Group by Category

Tag each line comment with its category based on source:
- Security persona → `security`
- Performance persona → `performance`
- Quality persona → `quality`
- Pipeline → `general`

## Output

```json
{
  "summary": {
    "files_reviewed": 8,
    "total_issues": 5,
    "by_severity": { "critical": 1, "high": 2, "medium": 2, "low": 0 },
    "quality_score": 82,
    "estimated_review_time": "20min",
    "risk_factors": ["SQL injection risk", "N+1 query pattern"],
    "good_points": ["Clean separation of concerns", "Good error handling"]
  },
  "line_comments": [
    {
      "file_path": "src/auth.py",
      "line_number": 42,
      "severity": "critical",
      "message": "SQL injection vulnerability — user input not sanitized",
      "suggestion": "Use parameterized queries",
      "category": "security",
      "source": "security-sentinel"
    }
  ],
  "persona_scores": {
    "security": { "score": 72, "issues": 2 },
    "performance": { "score": 88, "issues": 1 },
    "quality": { "score": 85, "issues": 2 }
  }
}
```

---

## Return format (required)

Your FINAL assistant message — what the spawning agent will receive — MUST start with this header block:

  **Status**: success | partial | failed | blocked
  **Summary**: <one sentence describing what happened>

After the header, include the actual deliverable (whatever the task asked for in its prompt).

If applicable, also include below the deliverable:

  **Files touched**: <comma-separated paths or "(none)">
  **Findings worth promoting**: <bullet list of cross-task transferable facts; "(none)" if just routine work>

This format lets the spawning agent and the checkpoint writer extract your progress without parsing free-form prose. Do NOT precede the header with an introduction — your final message must start with "**Status**:".
