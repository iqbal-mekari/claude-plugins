---
name: regenerate-test-cases
description: >
  Update existing mobile UI test cases when code changes are detected.
  Accepts git diffs, PR references, or existing test case CSVs as input.
  Identifies affected UI test cases and produces updated/new/removed cases.
  Focuses exclusively on mobile visual/interaction test cases. Does NOT
  generate API, web, or backend test cases.
  Trigger: regenerate test cases, update test cases, refresh test cases,
  sync test cases with code.
---

# Regenerate Test Cases Skill

Updates existing mobile UI test cases based on code changes. Compares
source code modifications against existing test coverage and produces
incremental updates — adding new UI cases, modifying affected ones,
and flagging obsolete cases for removal.

## Scope Restriction

**ONLY regenerate test cases for mobile app UI interactions.**

When analyzing code diffs, focus on changes that affect:
- Screen layouts and widget trees
- Navigation flows and routing
- UI state management (Bloc states → screen rendering)
- Form widgets and validation display
- Visual feedback (loading, error, empty states)

Ignore changes that only affect:
- API endpoints or HTTP clients (unless they change visible UI state)
- Database schemas or queries
- Backend logic without UI impact
- Web-specific code

## Trigger Keywords

- "regenerate test cases", "update test cases"
- "refresh test cases", "sync test cases"
- "test cases outdated", "code changed, update tests"
- "PR test impact", "what tests need updating"

## Input Sources

### 0. Impact Analysis JSON (Preferred — from `impact-analysis` skill)

When `impact-analysis` has already been run, its structured JSON output
provides a pre-filtered, high-confidence list of affected test cases:

1. Read the JSON output from `impact-analysis`.
2. Focus only on test cases with `recommended_action` of MODIFY, CREATE,
   or REMOVE.
3. Use the `reason` and `impacted_by_scopes` fields to understand WHY
   each test case is affected.
4. Skip the broad diff scanning phase — tomo_search already did it.

This is significantly more efficient than scanning raw diffs, especially
for large PRs, because tomo_search uses AST-level scope detection to
identify the precise blast radius.

### 1. Git Diff (Branch Comparison)

When the user references a branch or asks to compare against main:

1. Execute `git diff <base_branch>...<current_branch> --stat` to
   identify changed files.
2. Execute `git diff <base_branch>...<current_branch>` for detailed
   changes on relevant files.
3. Parse the diff to understand:
   - New features/endpoints added
   - Modified business logic or validation rules
   - Removed functionality
   - Changed UI components or screen flows
4. Cross-reference against existing test case CSV.

### 2. Pull Request Diff

When the user provides a PR reference:

1. Identify the PR's base and head branches.
2. Execute git diff between the branches.
3. Extract PR description for additional context on intent.
4. Follow the same analysis as git diff.

### 3. Existing Test Case CSV

When the user points to an existing CSV in `/test-cases/`:

1. Read and parse the CSV file.
2. Compare test case preconditions and steps against current code state.
3. Identify:
   - Test cases that reference removed/renamed components
   - Test cases with outdated expected results
   - Gaps where new code paths have no coverage

## Workflow

```
Input (Git Diff / PR / CSV reference)
        │
        ▼
Identify Changed Code
  - git diff --stat for file list
  - Detailed diff for logic changes
  - Categorize: added / modified / removed
        │
        ▼
Load Existing Test Cases
  - Read CSV from /test-cases/
  - Map test cases to features/components
        │
        ▼
Impact Analysis
  - Which test cases are affected?
  - What new scenarios are uncovered?
  - What cases are now obsolete?
        │
        ▼
Generate Delta
  - NEW: Test cases for added functionality
  - MODIFIED: Updated steps/expected results
  - REMOVED: Flag obsolete test cases
        │
        ▼
Output: Jira Comment + Updated CSV
```

## Impact Analysis Rules

### Code Change → Test Impact Mapping

| Code Change Type | Test Impact |
|-----------------|-------------|
| New UI screen/widget | New test cases for screen states and interactions |
| Modified widget layout | Update visual assertions on related TCs |
| Changed navigation flow | Update steps on affected TCs |
| New loading/error state handling | New visual state test cases |
| Removed screen/feature | Flag related TCs as REMOVED |
| Modified form validation display | Update expected validation messages |
| New permission-gated UI | New permission test cases (UI access) |
| Changed gesture interactions | Update interaction steps |

### File Pattern → Feature Area Mapping

Analyze file paths to determine UI-impacting areas:

- `**/screens/**`, `**/pages/**` → Screen state & navigation test cases
- `**/bloc/**`, `**/cubit/**` → UI state rendering test cases
- `**/widgets/**`, `**/components/**` → Component interaction test cases
- `**/routes/**`, `**/navigation/**` → Navigation flow test cases
- `**/theme/**`, `**/styles/**` → Visual appearance test cases

Ignore (no UI test impact):
- `**/repository/**`, `**/datasource/**` → Skip (API layer)
- `**/models/**`, `**/entities/**` → Skip (data layer)
- `**/services/**` → Skip (backend logic)

## Output Format

### Delta Summary

Before generating full test cases, present a summary:

```markdown
## Test Case Impact Analysis

**Branch:** feature/xyz → main
**Files Changed:** 12
**Existing Test Cases:** 24 (from CSV)

### Impact Summary
- 🆕 NEW: 5 test cases (new functionality)
- ✏️ MODIFIED: 3 test cases (updated behavior)
- 🗑️ REMOVED: 2 test cases (obsolete)
- ✅ UNCHANGED: 14 test cases (not affected)

### Details:
| Action | TC ID | Title | Reason |
|--------|-------|-------|--------|
| NEW | TC025 | User able to ... | New endpoint added in user_repository.dart |
| MODIFIED | TC008 | User able to ... | Validation logic changed in form_bloc.dart |
| REMOVED | TC012 | User able to ... | Feature removed (settings_screen.dart deleted) |
```

### Jira Comment

Post the delta summary + new/modified test cases as a comment:

```markdown
## Test Cases Update: {Ticket/PR Title}

*Regenerated by qa-test-case-generator | Trigger: {git diff / PR / manual}*

### Changes Summary
- 🆕 5 new | ✏️ 3 modified | 🗑️ 2 removed

### New Test Cases
| ID | Title | ... |

### Modified Test Cases
| ID | Title | Change Reason | ... |

### Removed Test Cases (Obsolete)
| ID | Title | Removal Reason |
```

### Updated CSV

Regenerate the full CSV with:
- New test cases appended
- Modified test cases updated in-place
- Removed test cases excluded (or marked with `[REMOVED]` tag)

**Filename:** Same as original, or `{identifier}_test_cases_v2.csv`
if user prefers versioning.

**IMPORTANT — Direct file writing only:**
Write updated CSV content directly by writing or editing the file.
Do NOT create Python scripts, shell scripts,
or any helper programs to generate the output. The agent has all the
data needed and must write the files itself in a single step.

## Preconditions for Regeneration

Before running this skill, verify:

1. **Existing CSV exists** — If no prior test cases exist, redirect
   to `create-test-cases` skill instead.
2. **Git context available** — The workspace must be a git repository
   with the relevant branches accessible.
3. **Clear base reference** — Know which branch/commit represents the
   "before" state.

## Human-in-the-Loop Gate (GATE 1)

After generating updated test cases, **always present a summary and
wait for explicit human approval** before considering the task complete
or passing output to downstream skills (e.g., patrol-test-creator).

**Required behavior:**
1. Present: delta summary (NEW/MODIFIED/REMOVED counts), coverage areas,
   and the updated CSV file path.
2. Ask the user: _"Updated test cases are ready for review at `{csv_path}`.
   Would you like me to proceed to Patrol test generation, make
   changes, or stop here?"_
3. **Wait for explicit confirmation** before any next step.
4. If the user requests changes, apply them and re-present.
5. Only proceed to Patrol automation if the user explicitly approves.

See [human-in-the-loop.md](../shared-references/human-in-the-loop.md)
for the full pipeline gate specification.

## Edge Cases

- **No existing CSV found:** Inform user and suggest running
  `create-test-cases` first.
- **Massive diff (>50 files):** Ask user to narrow scope to specific
  feature areas or directories.
- **No test impact detected:** Report that existing test cases remain
  valid — no changes needed.
- **Conflicting changes:** If a modification invalidates multiple test
  cases across different features, group changes by feature area.
