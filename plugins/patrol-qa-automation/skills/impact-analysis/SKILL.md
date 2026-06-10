---
name: impact-analysis
description: >
  Analyze code impact from PRs or branch diffs using tomo_search to identify
  affected modules and scopes in Flutter/Dart projects. Produces structured
  JSON output mapping impacted code to test cases that need reassessment.
  Uses full semantic AI matching — reads actual changed code and test case
  steps to determine functional impact. Output feeds into
  `regenerate-test-cases` skill.
  Trigger: impact analysis, analyze impact, which tests affected, PR impact,
  diff impact, what modules changed, tomo search.
---

# Impact Analysis Skill

Performs intelligent code impact analysis on Flutter/Dart projects using
[tomo_search](https://github.com/timiwinibiti/tomo_search) to identify
impacted scopes from git changes, then uses full semantic AI reasoning to
map those scopes to existing test cases that need reassessment.

## Scope

- **Flutter/Dart projects only** — tomo_search uses Dart AST analysis.
- Outputs structured JSON consumed by `regenerate-test-cases` or humans.
- Does NOT modify test cases — only identifies which ones are affected.

## Trigger Keywords

- "impact analysis", "analyze impact"
- "which tests are affected", "PR impact"
- "what modules changed", "tomo search"
- "diff impact", "test impact from PR"

## Input

Accepts **either**:

### 1. PR Reference

- GitHub PR URL: `https://github.com/org/repo/pull/123`
- PR number: `#123` (uses current repo context)

When a PR is provided:
1. Extract base and head branches via `gh pr view`.
2. Fetch the diff via `gh pr diff`.
3. Pass branches to tomo_search for scope detection.

### 2. Branch Name

- Branch name: `feature/attendance-clock-in`
- Compared against target branch (default: `develop`).

When a branch is provided:
1. Run `tomo_search git-diff <search_folder> <target_branch>` directly.

### 3. Optional Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `repo_path` | Current working directory | Path to the Flutter project root |
| `target_branch` | `develop` | Base branch for comparison |
| `search_folder` | `lib` | Folder to search for usage references |
| `search_method` | `git_grep` | Search strategy: `ast`, `git_grep`, `grep`, `hybrid` |

## Prerequisites

### tomo_search CLI

The skill requires `tomo_search` CLI to be globally available.

**Auto-installation flow:**

```
1. Check: `which tomo_search` or `dart pub global list | grep tomo_search`
2. If not found:
   a. Clone: `git clone -b develop https://github.com/timiwinibiti/tomo_search.git /tmp/tomo_search`
   b. Install: `cd /tmp/tomo_search && dart pub global activate --source path .`
   c. Verify: `tomo_search --help`
3. If installation fails:
   → PAUSE and ask user interactively to prepare the environment
   → Provide clear instructions on what's needed (Dart SDK, git, etc.)
```

### Dart SDK

tomo_search requires Dart SDK. If `dart` is not available, pause and ask
the user to install it (e.g., via Flutter SDK or standalone Dart).

## Workflow

```
Input (PR ref / Branch name)
        │
        ▼
Ensure tomo_search installed
  - Auto-install if missing
  - Pause & ask user if install fails
        │
        ▼
Resolve diff context
  - PR → extract base/head branches via `gh pr view`
  - Branch → use directly against target_branch
        │
        ▼
Run tomo_search
  - `tomo_search git-diff <search_folder> <target_branch> false`
  - Capture: impacted scopes, affected files, files needing testing
        │
        ▼
Gather code context
  - Read actual code diffs for impacted files (`git diff`)
  - Understand WHAT changed (not just WHERE)
        │
        ▼
Load test case CSVs
  - Scan `test-cases/` directory in the repo
  - Parse all CSV files (columns: Ticket, Feature Area, TC ID, Title,
    Preconditions, Steps, Expected Result, Category, Priority, Tags)
        │
        ▼
Full Semantic AI Matching
  - For each impacted scope + code change:
    - Read the actual modified code
    - Read test case steps and expected results
    - Reason: "Does this code change affect the behavior tested by this TC?"
  - Assign confidence: HIGH / MEDIUM / LOW
        │
        ▼
Output: Structured JSON
```

## tomo_search CLI Usage

### Analyze git diff (primary use case)

```bash
# From the Flutter project root
tomo_search git-diff lib develop false

# With staged changes
tomo_search git-diff lib develop true
```

### Analyze specific file changes

```bash
tomo_search analyze lib/features/attendance/clock_in_service.dart "10-14,25" lib git_grep
```

### Expected CLI output format

```
=== Git Diff Impact Analysis Tool ===

Comparing against: develop
Total changed files: N
Search method: git_grep

📝 Changed files:
 - lib/path/to/file.dart: lines X-Y, Z

🎯 All impacted scopes:
 - ClassName.methodName
 - AnotherClass.anotherMethod

📊 Detailed Analysis per File:
...

🧪 All files that need to be tested:
  - lib/path/to/consumer.dart
  - lib/path/to/another_consumer.dart
```

### Parsing tomo_search output

Extract from CLI output:
1. **Changed files** — files directly modified in the diff
2. **Impacted scopes** — classes/methods affected (AST-detected)
3. **Files that need testing** — all files that reference impacted scopes

## Semantic Matching Logic

The AI matching phase is the core differentiator from simple file-path
heuristics. For each impacted scope:

### Step 1: Understand the code change

Read the actual diff hunks. Determine:
- Is this a **behavioral change** (logic, validation, state transitions)?
- Is this a **UI change** (widget tree, layout, navigation)?
- Is this a **data change** (model fields, API response handling)?
- Is this a **cosmetic change** (renaming, formatting, comments)?

### Step 2: Match against test cases

For each test case in the CSVs:
- Read the **Steps** column — what user actions does this test perform?
- Read the **Expected Result** — what behavior is being validated?
- Read the **Preconditions** — what state does this test assume?
- Determine if the code change could alter any of these.

### Step 3: Assign confidence

| Confidence | Criteria |
|------------|----------|
| **HIGH** | Code change directly modifies the behavior being tested (e.g., validation logic change → validation test case) |
| **MEDIUM** | Code change affects a dependency of the tested behavior (e.g., service change → UI that uses the service) |
| **LOW** | Code change is in the same feature area but relationship is indirect (e.g., sibling method changed) |

### Step 4: Skip non-impacting changes

Do NOT flag test cases for:
- Comment-only changes
- Import reordering
- Variable renaming without behavioral impact
- Test file changes (they test themselves)
- Changes in unrelated feature modules

## Output Format

### Structured JSON

```json
{
  "analysis_metadata": {
    "timestamp": "2025-05-20T15:00:00+07:00",
    "source": "PR #123" | "branch: feature/xyz",
    "target_branch": "develop",
    "repo_path": "/path/to/flutter/app",
    "search_method": "git_grep",
    "tomo_search_version": "x.y.z"
  },
  "impact_summary": {
    "total_changed_files": 5,
    "total_impacted_scopes": 8,
    "total_files_needing_testing": 15,
    "total_test_cases_affected": 7
  },
  "impacted_modules": [
    {
      "module": "attendance",
      "path_pattern": "lib/features/attendance/",
      "scopes": ["AttendanceService.clockIn", "ClockInPage.build"],
      "changed_files": ["lib/features/attendance/clock_in_service.dart"],
      "change_type": "behavioral"
    }
  ],
  "impacted_scopes": [
    {
      "scope": "AttendanceService.clockIn",
      "file": "lib/features/attendance/clock_in_service.dart",
      "changed_lines": "10-14, 25",
      "change_summary": "Added geofence validation before clock-in submission",
      "consumers": [
        "lib/features/attendance/presentation/clock_in_page.dart",
        "lib/features/attendance/bloc/attendance_bloc.dart"
      ]
    }
  ],
  "recommended_test_cases": [
    {
      "tc_id": "TC005",
      "title": "User able to clock in successfully",
      "source_csv": "test-cases/ATT-123_attendance_test_cases.csv",
      "confidence": "HIGH",
      "reason": "clockIn method now includes geofence validation — this test validates successful clock-in which requires passing the new validation",
      "impacted_by_scopes": ["AttendanceService.clockIn"],
      "recommended_action": "MODIFY"
    },
    {
      "tc_id": "NEW",
      "title": "User not able to clock in outside geofence",
      "confidence": "HIGH",
      "reason": "New geofence validation added — no existing test case covers the failure scenario",
      "impacted_by_scopes": ["AttendanceService.clockIn"],
      "recommended_action": "CREATE"
    }
  ],
  "unaffected_test_cases": {
    "count": 17,
    "note": "These test cases are not impacted by the current changes"
  }
}
```

### Recommended Actions

| Action | Meaning |
|--------|---------|
| `MODIFY` | Existing test case steps or expected results need updating |
| `CREATE` | New test case needed — no existing coverage for this behavior |
| `REVIEW` | Test case may be affected — human review recommended (LOW confidence) |
| `REMOVE` | Tested behavior no longer exists (code deleted) |

## Integration with `regenerate-test-cases`

The output JSON from this skill serves as **pre-filtered input** for
`regenerate-test-cases`:

```
┌──────────────────┐         ┌─────────────────────────┐
│ impact-analysis  │────────▶│ regenerate-test-cases    │
│                  │  JSON   │                          │
│ • tomo_search    │         │ • Reads JSON output      │
│ • Scope detection│         │ • Focuses only on flagged│
│ • AI matching    │         │   test cases             │
│                  │         │ • Generates delta CSV     │
└──────────────────┘         └─────────────────────────┘
```

Instead of `regenerate-test-cases` scanning the entire diff blindly,
it receives a focused list of:
- Which test cases to modify (with reasons)
- Which new test cases to create (with scope context)
- Which test cases to remove (with deletion evidence)

## Human-in-the-Loop Gate (GATE 1)

After producing the impact analysis JSON, **always present a summary
and wait for explicit human approval** before considering the task
complete or piping output into `regenerate-test-cases`.

**Required behavior:**
1. Present: impact summary (total impacted scopes, affected test cases,
   recommended actions breakdown).
2. Ask the user: _"Impact analysis is ready. Would you like me to
   regenerate the affected test cases, make changes, or stop here?"_
3. **Wait for explicit confirmation** before any next step.
4. Only pipe into `regenerate-test-cases` if the user explicitly approves.

See [human-in-the-loop.md](../shared-references/human-in-the-loop.md)
for the full pipeline gate specification.

## Error Handling

| Scenario | Action |
|----------|--------|
| tomo_search not installed & auto-install fails | Pause, ask user to install Dart SDK + tomo_search |
| No git repository detected | Error: "Not a git repository" |
| Target branch doesn't exist | Error: suggest available branches |
| No changed files in diff | Report: "No changes detected — all test cases remain valid" |
| No test case CSVs found | Warning: skip matching phase, output only impacted scopes/modules |
| tomo_search returns no impacted scopes | Report: "Changes are cosmetic/non-functional — no test impact" |
| Large diff (>50 files) | Ask user to narrow scope to specific directories |

## Example Invocations

### From PR

```
User: "Run impact analysis on PR #42"

Agent:
1. gh pr view 42 --json baseRefName,headRefName
2. Ensure tomo_search installed
3. git checkout <head_branch>
4. tomo_search git-diff lib <base_branch> false
5. Parse output → semantic matching → JSON output
```

### From branch

```
User: "What's the test impact of branch feature/new-leave-form?"

Agent:
1. Ensure tomo_search installed
2. git checkout feature/new-leave-form
3. tomo_search git-diff lib develop false
4. Parse output → semantic matching → JSON output
```

### With explicit path

```
User: "Analyze impact on /Users/me/projects/talenta-app, branch feature/xyz"

Agent:
1. cd /Users/me/projects/talenta-app
2. Ensure tomo_search installed
3. tomo_search git-diff lib develop false
4. Parse output → semantic matching → JSON output
```
