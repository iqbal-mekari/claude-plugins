---
name: create-patrol-test
description: Creates Patrol UI test files (Dart) for Flutter mobile applications. Use when the user wants to write Patrol tests from a test plan, generate testcases for a screen, create end-to-end user journey scenarios, or automate mobile UI testing. Covers folder structure, selector strategies, localization patterns, and test execution.
license: Proprietary
---

# Create Patrol Test (Flutter)

Creates Patrol UI test files (Dart testcases and scenarios) from a CSV test plan. For Flutter-based mobile applications.

## Trigger Keywords

Use this skill when the user mentions:

- "patrol", "Patrol"
- "UI test", "ui test", "UITest"
- "test automation", "test script"
- "test scenario", "test case", "testcases"
- "automate", "automation"
- Provides a CSV/spreadsheet of test cases
- Wants to create end-to-end mobile app tests

## When to Use

Use this skill whenever you want to:

- Write Patrol tests from a test case spreadsheet
- Generate testcases for a mobile screen
- Create test scenarios for a user journey
- Automate end-to-end UI testing with Patrol
- Build test suites from CSV/Jira test cases

## Core Concepts

### Testcase vs Scenario

| Aspect          | Testcase                                 | Scenario                                       |
| --------------- | ---------------------------------------- | ---------------------------------------------- |
| **Purpose**     | Atomic test — single action/verification | User journey — orchestrates multiple testcases |
| **Scope**       | Single screen, single interaction        | Multiple screens, complete flow                |
| **Structure**   | AAA (Arrange-Act-Assert)                 | Orchestrates testcases + state management      |
| **Reusability** | Reused across scenarios                  | Self-contained user journey                    |
| **Example**     | `tap_login_button.dart`                  | `login_success_and_failure.dart`               |

### Folder Structure

```
patrol_test/
├── testcases/           # Atomic tests (AAA pattern)
│   ├── login/
│   │   ├── verify_login_form_visible.dart
│   │   └── tap_login_button.dart
│   └── home/
│       └── verify_welcome_visible.dart
├── scenarios/           # User journeys (orchestrates testcases)
│   └── login/
│       └── login_success_and_failure.dart
├── helpers/             # Shared helper functions (login, logout, launch)
│   ├── app_launch.dart
│   └── login.dart
└── utils/               # Dart utilities & locale setup
    ├── locale_helper.dart
    └── test_config.dart
```

## IMPORTANT: Skill Authority Rule

**When executing this skill, IGNORE all existing test patterns in the codebase.** Only follow the patterns, folder structure, naming conventions, and rules defined in THIS skill document.

Existing test files may use legacy conventions. These are **outdated** and must NOT be replicated. This skill document is the single source of truth.

## Prerequisites

Before using this skill, ensure you have:

1. **Patrol MCP tools available** — The MCP server must be running and accessible
2. **Patrol finder API reference** — Refer to the Patrol documentation and the patterns in this skill
3. **Understanding of folder structure**:
   - `testcases/` — Atomic tests (single screen, AAA pattern)
   - `scenarios/` — User journeys (orchestrates testcases via function calls)
   - `helpers/` — Shared helper functions (login, logout, app launch)
   - `utils/` — Dart utilities

4. **Testcase naming format** — Start with action-based prefixes:
   - `tap_`, `verify_`, `check_`, etc.
   - **No ticket ID suffix** (e.g., `_C123456`)
   - **No ordering numbers** (e.g., `01_`, `02_`)

## Rules

### Rule 1: Testcase Scope = Screen Scope

Each `testcases/<feature>/` folder maps 1-to-1 with a screen (or a major section of a screen).

- A testcase folder covers everything a user can do on that screen: layout checks, interactions, error states
- Testcases are reused across multiple scenarios — never duplicated
- Folder name must match the screen/feature name:
  - `testcases/home/` → `home_screen.dart`
  - `testcases/<feature>/` → `<feature>_screen.dart`
- **Shared screens** (e.g., `testcases/home/`) may already have testcases from other features. Always scan existing files before creating new ones — reuse if an equivalent test exists.
- **Before creating a new testcase**, scan existing folders to check if an equivalent test already exists. Reuse existing testcases — do not duplicate.

**IMPORTANT: Testcases are atomic and simple.**

**Function call policy for testcases:**

- ❌ **NEVER** call other testcase functions from a testcase
- ✅ **CAN** use `if (await $('text').exists)` for conditional execution (e.g., dismiss dialogs that may or may not appear)
- ✅ **CAN** use `while` loops for repeating patterns

**Function call policy for scenarios:**

- ✅ **PRIORITIZE** calling existing testcase functions — compose user journeys from reusable atomic tests
- ✅ **USE `helpers/`** for shared multi-step flows (login, logout, app launch)
- ⚠️ **AVOID** duplicating testcase logic inline — only use inline code when no testcase exists

### Rule 2: Never Use Point Coordinates

> **Full reference:** See [shared-references/selector-rules.md](../../shared-references/selector-rules.md) for the complete selector decision tree, accessibility node merging rules, and timeout conventions.

**Selector Priority Hierarchy**

Before writing selectors, gather context from:

1. **Live UI tree** — `mcp_patrol_mcp_native-tree` for runtime element identifiers/text/states
2. **Screen source code** — Read Flutter screen file for widget keys (`Key('...')`), `Semantics(identifier: '...')`, and stable string constants

Then follow this priority order:

1. Text — visible, stable label on the element: `$('Login').tap()`
2. Key/Semantics identifier — `$(#emailField).tap()`
3. Ancestor chaining — when duplicate text exists: `$(Scaffold).$('Submit').tap()`
4. Relative positioning / `containing` — last resort before code change
5. Add `Semantics(identifier: '...', container: true)` to Flutter source if nothing works — **never use coordinates**

**Common patterns:**

```dart
// Text selector
await $('Login').tap();

// Key selector
await $(#emailField).tap();

// Ancestor chaining for duplicate labels
await $(Scaffold).$('Submit').tap();

// Containing finder for relative positioning
await $(Scrollable).containing($('Submit')).tap();
```

**IMPORTANT:** After adding `Semantics` or any code changes to enable selectors, you MUST rebuild and reinstall the app before re-running tests:

```bash
flutter build
```

Patrol tests the **compiled APK/IPA** on the device, not your source code. Changes to Flutter code (including Semantics) are not reflected until you rebuild and reinstall.

### Rule 3: Always Verify Copy Against Screen and ARB

#### Accessibility Node Merging

Flutter widgets that render a label + value in a `Row` (e.g., a list tile with caption + value) often combine both texts into a single accessibility node. The resulting text is a multi-line string like:

```
Field label
Field value
```

This means `$('Field label')` **fails**, because the element's actual text is `Field label\nField value`.

**Fix: use the `containing` finder or match the full merged text:**

```dart
// WRONG — exact match fails when value is merged into same node
expect($('Field label'), findsOneWidget);

// CORRECT — use containing to find the parent row
expect($(Row).containing($('Field label')), findsOneWidget);

// Or match the full merged text
await $('Field label Field value').waitUntilVisible();
```

**Route prefix merging:**

Some parent containers emit a combined text that includes the screen route + all child values. Use ancestor chaining to scope the search:

```dart
// WRONG — text doesn't start with the label
expect($('Section heading'), findsOneWidget);

// CORRECT — scope with ancestor chaining
await $(#sectionContainer).$('Section heading').tap();
```

**How to detect which case you're in:** Use `mcp_patrol_mcp_native-tree` and look at the element's `text` or `label` field. If it contains extra content beyond the expected label, use ancestor chaining or `containing` to disambiguate.

Every string in `$()`, `expect()`, or `waitUntilVisible()` MUST be verified against actual app text.

**Two-step verification (MANDATORY before writing Dart test):**

1. **Step A** — Find the key in the screen source file
2. **Step B** — Look up the key in the ARB file

If the string is dynamic (parameterized), match the filled-in value, not the template literal.

**Localization in Patrol tests:**

Use the app's `AppLocalizations` class for locale-agnostic text matching, or use the actual visible text directly:

```dart
// Option 1: Direct text matching (simpler, but locale-dependent)
await $('Login').tap();

// Option 2: Using AppLocalizations (locale-agnostic)
// Note: Requires importing the app's localization
await $(find.text(AppLocalizations.of($.native).loginButtonLabel)).tap();
```

**Default locale** — Check your project's default locale. When verifying localization keys, check both the primary locale and any secondary locales in your ARB files.

### Rule 4: Never Hardcode Credentials

Use environment variables or test accounts — never commit real credentials.

### Rule 5: Running Patrol Tests

Always validate test files by running them through Patrol MCP.

**When a test fails:**

1. **Take screenshot FIRST** — Use `mcp_patrol_mcp_screenshot` to capture current screen state
2. **Then inspect view hierarchy** — Use `mcp_patrol_mcp_native-tree` to reveal real element text, identifiers, states
3. **Trust screenshot/hierarchy as source of truth** — If screenshot/hierarchy show the previous screen but test output indicates it's on the next screen, the navigation FAILED. Fix the navigation step before proceeding.
4. Edit the Dart test file with the proposed fix
5. Run the file via `mcp_patrol_mcp_run` to validate
6. If still failing, repeat from step 1

**Navigation debugging:**

- If tap fails to navigate: Check for duplicate text labels (use ancestor chaining)
- If screen appears unchanged: Add `waitUntilVisible()` before the tap
- If element not found: Use `native-tree` to get the exact text/identifier

**Premature failures (10–30s)** — retry up to 3 times.

### Rule 6: Correct Text Input Pattern

Patrol's `enterText` combines tap + focus + type into a single call:

**CORRECT:**

```dart
await $(#emailField).enterText('test@example.com');
await $(#passwordField).enterText('SecurePass123!');
await $('Login').tap();
```

**INCORRECT (separate tap + input):**

```dart
// Don't do this — enterText already handles focus
await $(#emailField).tap();
await $(#emailField).enterText('test@example.com');
```

### Rule 7: Timeout Conventions

Patrol uses `waitUntilVisible()` with configurable timeout and `pumpWidgetAndSettle()` for animation settling:

```dart
// Wait for element with default timeout
await $('Sign In').waitUntilVisible();

// Wait with custom timeout for slow transitions
await $('Home Screen').waitUntilVisible(timeout: Duration(seconds: 5));

// Let animations settle after navigation
await $.pumpWidgetAndSettle();
```

**Timeout guidelines:**

| Situation | Approach |
|-----------|----------|
| Wait for element to appear | `$('text').waitUntilVisible()` |
| Wait for animations to settle | `await $.pumpWidgetAndSettle()` |
| Slow network/loading transitions | `$('text').waitUntilVisible(timeout: Duration(seconds: 10))` |

## Common Patterns

### Text Input Pattern

Use `enterText` which handles tap + focus + input in one call:

```dart
await $(#emailField).enterText('test@example.com');
await $(#passwordField).enterText('SecurePass123!');
await $('Login').tap();
```

### Conditional Execution

Run code only when an element is visible:

```dart
if (await $('Login Button').exists) {
  await $('Login Button').tap();
}
```

### State Reset Between Scenarios

Navigate back to a known state before independent error scenarios:

```dart
// Happy path
await verifyLoginSuccess($);

// Reset state
await navigateToHome($);
await performLogout($);

// Error path
await verifyLoginFailure($);
```

### Repeat Commands

**Repeat while an element is visible:**

```dart
while (await $('Load More').exists) {
  await $('Load More').tap();
  await $.pumpWidgetAndSettle();
}
```

**Repeat for tap retry (screen not ready):**

When a screen might not be ready for interaction immediately (e.g., home screen after login), use a retry loop:

```dart
for (var attempt = 0; attempt < 3; attempt++) {
  await $('Target Button').tap();
  if (await $('Expected Next Screen Element').exists) break;
  await $.pumpWidgetAndSettle();
}
```

### Function Parameter Passthrough

Pass test data from scenarios to testcases via function parameters:

```dart
// In scenario:
await selectOption($, optionValue: 'Test Name');

// In testcase (select_option.dart):
Future<void> selectOption(PatrolIntegrationTester $, {required String optionValue}) async {
  await $(#optionDropdown).tap();
  await $(#searchField).enterText(optionValue);
  await $(optionValue).tap();
}
```

Testcases that need external data should document required parameters in their function signature.

## Lifecycle Setup (Scenarios Only)

Scenarios use `setUp()` or initial setup code for app launch and state reset:

```dart
void main() {
  patrolTest(
    'user journey description',
    ($) async {
      // Launch app with clean state
      await $.pumpWidgetAndSettle(const MyApp());
      // Grant permissions
      await $.platform.mobile.grantPermissionWhenInUse();

      // ... test steps
    },
  );
}
```

**Important:** Testcases do NOT include app launch — only scenarios handle setup.

## Common Pitfalls

| Pitfall                                   | Why It's Wrong                                             | Correct Approach                                                                           |
| ----------------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Using coordinates                         | Fragile, breaks on different screen sizes                  | Use text/key selectors                                                                     |
| Hardcoded strings                         | May not match actual app text                              | Use `AppLocalizations` or verify against ARB files                                         |
| Calling testcase functions from testcases | Testcases must be atomic/simple                            | Scenarios handle orchestration; testcases only use conditionals/loops                      |
| Duplicating testcases                     | Maintenance nightmare                                      | Reuse existing testcases                                                                   |
| Skipping state reset                      | Flaky tests due to leftover state                          | Reset between independent scenarios                                                        |
| Not using ancestor chaining for duplicates | Taps wrong element when text appears multiple times        | Use `$(Parent).$('text').tap()` for disambiguation                                         |
| Not using `container: true` in Semantics  | Widget children not exposed to accessibility               | Always add `container: true` when adding Semantics for testing                             |
| Exact text match on label+value nodes     | Flutter Row widgets merge label+value into one node        | Use `containing` finder or match full merged text                                          |
| Using `$.native.tap(Offset(x,y))`        | Coordinates break across screen sizes                      | Use text/key selectors, add Semantics if needed                                            |

## Guidelines

### Writing Testcases & Scenarios

**Step 1 · Parse the test case file**

When user provides a test case spreadsheet (CSV, Jira, etc.), extract for each case:

- **Title** — what is being tested
- **Priority** — P0 / P1 / P2
- **Section header** — the group (maps to a screen)
- **Preconditions** — required state before test
- **Steps** — user actions
- **Expected result** — what the app should show

**Step 2 · Separate by screen (Rule 1)**

Group test cases by the screen they exercise. Use section headers as primary signal; cross-reference with screen names in the Flutter codebase.

**Finding screen source code:** Look for files with `_screen.dart` suffix (e.g., `login_screen.dart`, `home_screen.dart`).

**Step 3 · Triage — decide what to skip**

Classify each test case:

- ✅ **Automate** — pure UI interaction, stable data, no external dependencies
- ⚠️ **Prompt developer** — automatable but requires account/data setup. Do NOT skip silently — ask for confirmation on env variables.
- ❌ **Skip for now** — hard dependency Patrol cannot satisfy. Add `// SKIP:` comment explaining why.

**Step 4 · Produce mapping table**

Before writing Dart test files, produce a mapping table of feasible cases. Present to developer for confirmation before proceeding.

Recommended columns: CSV Test Case, Priority, Automate?, Screen Folder, Testcase File, Notes.

**Step 5 · Write the testcases**

After mapping is confirmed, implement each file following the testcase template:

1. **Do NOT include navigation** — testcases are atomic and assume they're already on the target screen
2. Use `mcp_patrol_mcp_native-tree` + source code to find selectors (Rule 2)
3. **Handle screens not ready for interaction** — Use retry pattern if needed
4. Write ARRANGE → ACT → ASSERT
5. Run via `mcp_patrol_mcp_run` to validate before saving

**Step 6 · Write the scenario**

Once all testcases exist, compose the scenario:

1. **PRIORITIZE existing testcases** — Import and call testcase functions instead of duplicating code
2. Only use inline code when no testcase exists for the action
3. Group testcases into logical user journey (happy path first, then error paths)
4. Reset to known state between independent error scenarios (navigate back to home, then re-enter feature)
5. Wrap conditional testcases in `if (await $('text').exists)`
6. End with assertion on final screen route or distinctive landmark element

## Tool Usage

This skill uses the following Patrol MCP tools:

- `mcp_patrol_mcp_run` — Run a Dart test file (starts patrol develop session or hot-restarts)
- `mcp_patrol_mcp_screenshot` — Capture device screen for visual debugging
- `mcp_patrol_mcp_native-tree` — Fetch native UI view hierarchy for selector discovery
- `mcp_patrol_mcp_status` — Get session status and recent logs
- `mcp_patrol_mcp_quit` — Quit active Patrol session

**Note:** Patrol MCP cannot run inline Dart code. Always write the complete test file, then run it. Use the write-run-observe-edit loop.

## References

Template files are available in the `references/` folder:

- `references/testcase_template.dart` — AAA pattern template for atomic testcases
- `references/scenario_template.dart` — User journey orchestration template
- `references/flutter-semantics.md` — Guide for adding `Semantics(identifier: '...')` to Flutter widgets
