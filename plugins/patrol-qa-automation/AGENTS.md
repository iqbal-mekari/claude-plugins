# QA Agent UI Automation — Copilot Instructions

This workspace contains VS Code Copilot **agent definitions** and **skills** for mobile UI test automation on Flutter apps using the [Patrol](https://patrol.leancode.co/) framework. No application source code lives here.

## Critical Rules (read before any task)

1. **Read the relevant `SKILL.md` first.** It is the authoritative source — it overrides any legacy patterns found elsewhere.
2. **Never write Patrol test code without running it first.** Use `patrol test --target <file>` to validate each test file on the live device before considering it done.
3. **Never hardcode credentials.** Always use function parameters or test setup.
4. **Never use pixel coordinates** as a Patrol selector — they are brittle.
5. **Patrol CLI is a test runner, not a device driver.** You cannot tap/type/scroll via CLI commands — write complete Dart test files, then run them. The debugging loop is: edit file → run → observe → edit again.

## Agents

| Agent | Role | User-invocable |
|---|---|---|
| `patrol-test-creator` | Orchestrates full Patrol test production from a CSV | ✅ |
| `patrol-test-debugger` | Autonomous loop to debug failing Patrol tests | ✅ |

## Skills

| Skill | When to invoke |
|---|---|
| [`create-patrol-test`](skills/create-patrol-test/SKILL.md) | Writing Patrol testcase or scenario Dart files (authoritative rules) |
| [`create-patrol-testcase`](skills/create-patrol-testcase/SKILL.md) | Writing a single atomic Patrol testcase Dart file |
| [`compose-patrol-scenario`](skills/compose-patrol-scenario/SKILL.md) | Composing a Patrol scenario Dart from testcase files |
| [`debug-patrol-test`](skills/debug-patrol-test/SKILL.md) | Debugging a failing Patrol test |
| [`debug-patrol-selector`](skills/debug-patrol-selector/SKILL.md) | Diagnosing and fixing a single failing Patrol selector |
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

| Gate | Between | What's reviewed | Enforced by |
|------|---------|-----------------|-------------|
| Gate 1 | Test case generation → Patrol scripting | Generated CSV completeness & correctness | `create-test-cases`, `regenerate-test-cases`, `impact-analysis` skills |
| Gate 2 | Mapping table → Dart file writing | Triage decisions (automate/skip/setup) | `patrol-test-creator` agent |

**Rule:** Agents and skills must never proceed past gates 1 or 2 without explicit human approval.

After test file generation, execution starts automatically.

## Reference Files

- [Human-in-the-loop gates](skills/shared-references/human-in-the-loop.md) — mandatory approval checkpoints between pipeline phases
- [Selector rules](skills/shared-references/selector-rules.md) — single source of truth for Patrol selector strategies
- [Failure patterns](skills/debug-patrol-test/references/failure-patterns.md) — living knowledge base; check before debugging, append after fixing
- [Flutter Semantics guide](skills/create-patrol-test/references/flutter-semantics.md) — how to add `identifier:` to Flutter widgets
- [Testcase Dart template](skills/create-patrol-test/references/testcase_template.dart)
- [Scenario Dart template](skills/create-patrol-test/references/scenario_template.dart)
- [Examples](examples/) — sample CSV input, testcase Dart, and scenario Dart with pipeline walkthrough

## CLI Tools Available

| Tool | Use |
|---|---|
| `patrol test --target <file>` | Run a Dart test file on the device |
| `adb shell uiautomator dump` / `idb ui describe-all` | Dump native view hierarchy for selector discovery (see [cli-commands.md](skills/shared-references/cli-commands.md)) |
| `adb shell screencap` / `xcrun simctl io booted screenshot` | Screenshot for visual debugging (LAST RESORT) |
| `patrol devices` / `flutter devices` | Check connected devices |
| Atlassian MCP | Read Jira tickets, post comments, read Confluence pages |
| Figma MCP | Fetch design context, screenshots, component metadata |

See [CLI Commands Reference](skills/shared-references/cli-commands.md) for full command details and platform-specific variants.

## Scope Limits

- **Patrol / mobile UI only.** Do not generate API tests, backend tests, or web tests.
- **No web, no desktop.** Scope is Flutter Android/iOS.
- **`create-test-cases` SKILL.md** gates test case structure — do not invent new fields.
