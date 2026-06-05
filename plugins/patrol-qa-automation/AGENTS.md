# QA Agent UI Automation — Copilot Instructions

This workspace contains VS Code Copilot **agent definitions** and **skills** for mobile UI test automation on Flutter apps using the [Patrol](https://patrol.leancode.co/) framework. No application source code lives here.

## Critical Rules (read before any task)

1. **Read the relevant `SKILL.md` first.** It is the authoritative source — it overrides any legacy patterns found elsewhere.
2. **Never write Patrol test code without running it first.** Use `mcp_patrol_mcp_run` to validate each test file on the live device before considering it done.
3. **Never hardcode credentials.** Always use function parameters or test setup.
4. **Never use pixel coordinates** as a Patrol selector — they are brittle.
5. **Patrol MCP is a test runner, not a device driver.** You cannot tap/type/scroll via MCP — write complete Dart test files, then run them. The debugging loop is: edit file → run → observe → edit again.
6. **Sub-agents are not user-invocable.** `patrol-testcase-writer`, `patrol-scenario-composer`, and `patrol-selector-debugger` are spawned by orchestrators only.

## Agents

| Agent | Role | User-invocable |
|---|---|---|
| `qa-test-case-generator` | Generates mobile UI test cases from Jira/PRD/Figma | ✅ |
| `patrol-test-creator` | Orchestrates full Patrol test production from a CSV | ✅ |
| `patrol-test-debugger` | Autonomous loop to debug failing Patrol tests | ✅ |
| `patrol-testcase-writer` | Writes one atomic testcase Dart file | sub-agent |
| `patrol-scenario-composer` | Composes scenario Dart file from testcases | sub-agent |
| `patrol-selector-debugger` | Diagnoses and fixes one failing selector | sub-agent |

## Skills

| Skill | When to invoke |
|---|---|
| [`create-patrol-test`](skills/create-patrol-test/SKILL.md) | Writing Patrol testcase or scenario Dart files |
| [`debug-patrol-test`](skills/debug-patrol-test/SKILL.md) | Debugging a failing Patrol test |
| [`create-test-cases`](skills/create-test-cases/SKILL.md) | Generating new mobile UI test cases |
| [`regenerate-test-cases`](skills/regenerate-test-cases/SKILL.md) | Updating test cases from code diffs or PRs |
| [`impact-analysis`](skills/impact-analysis/SKILL.md) | Identifying impacted modules & test cases from PR/branch diffs via tomo_search |

## Patrol Conventions

**Folder layout** (in the target app repo, not here):
```
patrol_test/
├── testcases/<screen>/    ← atomic testcase Dart files
├── scenarios/<feature>/   ← orchestrating scenario Dart files
├── helpers/               ← shared helpers (login, logout, navigation)
└── utils/                 ← test utilities
```

**File naming:** `<verb>_<target>.dart` — e.g. `tap_login_button.dart`. No numeric prefixes, no ticket-ID suffixes.

**Selector priority (highest → lowest):**
1. Text finder — `$('Login')`
2. Key finder — `$(#emailField)` (Semantics `identifier:` or widget Key)
3. Type finder — `$(ElevatedButton)`
4. Ancestor chaining — `$(Scaffold).$('Submit')`
5. Containing finder — `$(Row).containing($('label'))`
6. If nothing works → add `Semantics(identifier: "...", container: true)` to Flutter source, rebuild

**Localization:** Use direct text matching `$('Login').tap()` for simple cases, or `AppLocalizations.of($)` for dynamic/localized strings.

**Semantics rule:** Always pair `identifier:` with `container: true`. Any change requires `flutter build` + reinstall before Patrol can detect it.

**Patrol finder patterns:**
- `$('text')` — match by visible text
- `$(#key)` — match by widget Key or Semantics identifier
- `$(Type)` — match by widget type
- `$(parent).$('child')` — ancestor chaining
- `$(Scrollable).containing($('text'))` — scrollable containing element

## Test Case Conventions

- IDs: `TC001`, `TC002`, … (sequential)
- Titles: `User able to …` (happy path) / `User not able to …` (negative)
- Categories: `Smoke` (P0 core happy path) or `Regression` (everything else)
- Output path: `/test-cases/{epic_key}_{short_desc}_test_cases.csv` + smoke-only variant

## Human-in-the-Loop Gates

The pipeline enforces **mandatory human approval checkpoints** for gates 1 and 2. See [human-in-the-loop.md](skills/shared-references/human-in-the-loop.md) for full details.

| Gate | Between | What's reviewed |
|------|---------|-----------------|
| Gate 1 | Test case generation → Patrol scripting | Generated CSV completeness & correctness |
| Gate 2 | Mapping table → Dart file writing | Triage decisions (automate/skip/setup) |

**Rule:** Agents must never proceed past gates 1 or 2 without explicit human approval.

After test file generation, execution starts automatically.

## Reference Files

- [Human-in-the-loop gates](skills/shared-references/human-in-the-loop.md) — mandatory approval checkpoints between pipeline phases
- [Selector rules](skills/shared-references/selector-rules.md) — single source of truth for Patrol selector strategies
- [Failure patterns](skills/debug-patrol-test/references/failure-patterns.md) — living knowledge base; check before debugging, append after fixing
- [Flutter Semantics guide](skills/create-patrol-test/references/flutter-semantics.md) — how to add `identifier:` to Flutter widgets
- [Testcase Dart template](skills/create-patrol-test/references/testcase_template.dart)
- [Scenario Dart template](skills/create-patrol-test/references/scenario_template.dart)
- [Examples](examples/) — sample CSV input, testcase Dart, and scenario Dart with pipeline walkthrough

## MCP Tools Available

| Tool | Use |
|---|---|
| `mcp_patrol_mcp_run` | Run a Dart test file on the device |
| `mcp_patrol_mcp_native-tree` | Dump native view hierarchy for selector discovery |
| `mcp_patrol_mcp_screenshot` | Screenshot for visual debugging |
| `mcp_patrol_mcp_status` | Check session state and connected device |
| `mcp_patrol_mcp_quit` | End the Patrol MCP session |
| Atlassian MCP | Read Jira tickets, post comments, read Confluence pages |
| Figma MCP | Fetch design context, screenshots, component metadata |

## Scope Limits

- **Patrol / mobile UI only.** Do not generate API tests, backend tests, or web tests.
- **No web, no desktop.** Scope is Flutter Android/iOS.
- **`create-test-cases` SKILL.md** gates test case structure — do not invent new fields.
