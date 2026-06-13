# Skill: run-pr-review

Deterministic pipeline review of a PR diff. Ported from Alibaba's Open Code Review architecture — combines file selection, smart bundling, and rule matching with Claude Code's built-in LLM for structured code review.

## Input

- `diff_content` — The full PR diff (unified diff format)
- `pr_title` — PR title for business context
- `pr_description` — PR description (optional)
- `repo_path` — Path to local repo clone (if available, for reading full file context)

## Workflow

### Step 1: Parse Diff → File List

Parse the unified diff to extract changed files. For each file, determine:
- `file_path` — Relative path from repo root
- `change_type` — `added`, `modified`, `deleted`, `renamed`
- `lines_added` — Number of added lines
- `lines_removed` — Number of removed lines
- `hunks` — List of change hunks with line ranges

Skip binary files (detect by binary markers in diff or file extension).

### Step 2: Apply Include/Exclude Rules

Load review rules from (first match wins):
1. `<repo>/.code-review-agent/review-rules.json`
2. `~/.code-review-agent/review-rules.json`
3. Built-in defaults

**Built-in default excludes:**
```
**/generated/**, **/vendor/**, **/node_modules/**,
**/*.g.dart, **/*.freezed.dart, **/*.mock.dart,
**/Pods/**, **/.gradle/**, **/build/**
```

**Built-in default rules (language-aware):**
- `**/*.java` → "Check for null safety, resource leaks, exception handling"
- `**/*.kt` → "Check for null safety, coroutine usage, thread safety"
- `**/*.dart` → "Check for null safety, widget lifecycle, state management"
- `**/*.py` → "Check for type hints, exception handling, SQL injection"
- `**/*.ts` → "Check for type safety, async handling, XSS"
- `**/*.swift` → "Check for memory management, error handling"
- `**/*mapper*.xml` → "Check SQL for injection risks and missing closing tags"
- `**/*.sql` → "Check for injection, missing indexes, destructive operations"

For each file in the diff, find the first matching rule. If no rule matches, use a generic review prompt.

### Step 3: Smart Bundling

Group related files into review bundles to provide cross-file context:

**Bundle rules:**
- **i18n pairs:** `*_en.properties` + `*_zh.properties` (or any locale pair)
- **Model + Mapper:** `*Model.java` + `*Mapper.xml`
- **Interface + Impl:** `*Repository.java` + `*RepositoryImpl.java`
- **Screen + Bloc:** `*_screen.dart` + `*_bloc.dart`
- **Test + Source:** If both test and source files changed, bundle them

Unbundled files review independently.

### Step 4: Review Each Bundle

For each bundle:

1. **Gather context:**
   - The diff hunks for all files in the bundle
   - If `repo_path` available: read the full content of changed files for context
   - The matching review rule
   - Business context from PR title/description

2. **Construct review prompt:**

```
You are reviewing a pull request. Analyze the following changes and provide structured feedback.

PR Context:
- Title: {pr_title}
- Description: {pr_description}
- Files in this bundle: {file_list}

Review Focus: {rule_for_bundle}

Changed files with diff:

--- {file_path_1} ({change_type}, +{added}/-{removed}) ---
{diff_hunks_1}

--- Full file context (if available) ---
{full_file_content_1}

--- {file_path_2} ---
...

Provide your review as JSON:
{
  "line_comments": [
    {
      "file_path": "path/to/file",
      "line_number": 42,
      "severity": "critical|high|medium|low",
      "message": "Clear description of the issue",
      "suggestion": "How to fix it (if applicable)"
    }
  ],
  "good_points": ["Positive observations"],
  "risk_factors": ["Potential risks"],
  "overall_quality_score": 85
}
```

3. **Execute review:** The agent analyzes the bundle and produces structured JSON output.

### Step 5: Aggregate Results

Combine results from all bundles:
- Merge all `line_comments` into one list
- Merge all `good_points` (deduplicated)
- Merge all `risk_factors` (deduplicated)
- Average `overall_quality_score` across bundles

## Output

```json
{
  "line_comments": [...],
  "good_points": [...],
  "risk_factors": [...],
  "overall_quality_score": 85,
  "files_reviewed": 8,
  "bundles_reviewed": 5,
  "skipped_files": ["generated/model.g.dart"]
}
```

## Error Handling

- **Diff too large (>100K chars):** Split into chunks by file groups, review each chunk
- **Binary files in diff:** Skip silently, note in output
- **No matching review rule:** Use generic prompt: "Review for bugs, security issues, and code quality"
- **Repo not available:** Review diff-only (no full file context), note reduced context in output
