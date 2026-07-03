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
integration_test/
├── smoke_suite_test.dart    # Composite suite — logs in ONCE, runs every
│                            # feature's exported ...Scenario, tags: ['smoke']
├── testcases/           # Atomic tests (AAA pattern)
│   ├── login/
│   │   ├── verify_login_form_visible.dart
│   │   └── tap_login_button.dart
│   └── home/
│       └── verify_welcome_visible.dart
├── scenarios/           # User journeys (orchestrates testcases)
│   └── login/
│       └── login_success_and_failure.dart
├── helpers/             # Shared helper functions
│   ├── app_helper.dart      ← launchApp($), clearAppData() — launchApp($)
│   │                          MUST be the first call in every patrolTest
│   ├── login_helper.dart    ← loginHelper($) — launches + signs in, calling
│   │                          launchApp($) internally
│   └── test_helpers.dart    ← Checks soft-assert collector + locale-safe
│                              selectors (t, existsEnId, bySemId, bySemLabel,
│                              isOnHome, pumpUntil, tapNav, ensureHome)
└── utils/               # Dart utilities & locale setup
    ├── locale_helper.dart
    └── test_config.dart
```

## IMPORTANT: Skill Authority Rule

**When executing this skill, IGNORE all existing test patterns in the codebase.** Only follow the patterns, folder structure, naming conventions, and rules defined in THIS skill document.

Existing test files may use legacy conventions. These are **outdated** and must NOT be replicated. This skill document is the single source of truth.

## Prerequisites

Before using this skill, ensure you have:

1. **Patrol CLI and platform tools available** — `patrol` CLI, `adb` (Android), and `xcrun simctl`/`idb` (iOS) must be installed and accessible
2. **Patrol finder API reference** — Refer to the Patrol documentation and the patterns in this skill
3. **Understanding of folder structure**:
   - `testcases/` — Atomic tests (single screen, AAA pattern)
   - `scenarios/` — User journeys (orchestrates testcases via function calls)
   - `helpers/` — Shared helper functions: `app_helper.dart` (`launchApp($)`, `clearAppData()`), `login_helper.dart` (`loginHelper($)`), `test_helpers.dart` (`Checks` + locale-safe selectors)
   - `utils/` — Dart utilities
   - `smoke_suite_test.dart` — composite suite at the root of `integration_test/`, single login, `tags: const ['smoke']`

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

**The exported scenario function idiom:**

Every testcase file has two forms, both present in the same file:

1. A thin `main()` containing exactly one `patrolTest`, tagged `P0` — lets the file run standalone via `patrol test --target <file> --tags P0` for fast, isolated debugging.
2. An exported top-level `Future<void> <name>Scenario(PatrolIntegrationTester $, Checks c)` function holding the actual steps — so `scenarios/` files and `smoke_suite_test.dart` can `import '...' show fooScenario;` and reuse the same logic instead of duplicating it.

The `main()`'s `patrolTest` body should do little more than launch (via `loginHelper($)`, or `launchApp($)` directly for a testcase that exercises the login screen itself — see Rule 8), construct a `Checks c`, call the exported scenario function, then `c.done()`. See `references/testcase_template.dart` for the full shape.

### Rule 2: Never Use Point Coordinates

> **Full reference:** See [shared-references/selector-rules.md](../shared-references/selector-rules.md) for the complete selector decision tree, accessibility node merging rules, and timeout conventions.

**Selector Priority Hierarchy**

Before writing selectors, gather context from:

1. **Live UI tree** — use the view hierarchy CLI command (`adb shell uiautomator dump` for Android, `idb ui describe-all` for iOS) for runtime element identifiers/text/states. See [cli-commands.md](../shared-references/cli-commands.md) for full commands.
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

**How to detect which case you're in:** Use the view hierarchy CLI command (see [cli-commands.md](../shared-references/cli-commands.md)) and look at the element's `text` or `label` field. If it contains extra content beyond the expected label, use ancestor chaining or `containing` to disambiguate.

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

**Locale-safe selector helpers** (from `helpers/test_helpers.dart` — see `references/test-helpers.dart` for the full API):

- `t($, en, id)` — returns whichever of the primary-locale or secondary-locale string is present, as a `PatrolFinder`. Prefer this over hardcoding a single locale's copy.
- `existsEnId($, en, id)` — returns a `bool` for whether either locale string is currently visible; pairs naturally with `Checks.verify` and with conditional execution (`if (existsEnId(...))`).
- `bySemId(id)` / `bySemLabel(label)` — return a `Finder` matching `Semantics.identifier` / `Semantics.label` directly, for when visible text alone is ambiguous or unreliable across locales.
- `isOnHome($)` — detects the home screen locale-independently.
- `pumpUntil($, () => condition, maxSeconds: n)` — polls a predicate until it's true or the timeout elapses. See [wait-strategies.md](../shared-references/wait-strategies.md) for when to reach for this versus `waitUntilVisible()`.
- `tapNav($, en, id)` — taps a nav destination (bottom bar, drawer, tab) by locale-safe label.
- `ensureHome($)` — recovers to a known home screen from wherever the app currently is; use between independent checks or scenarios instead of hand-rolling a reset path.

### Rule 4: Never Hardcode Credentials

Use environment variables or test accounts — never commit real credentials.

**Inject credentials and seed data via `--dart-define` with a non-secret default:**

```dart
const _testEmail = String.fromEnvironment('TEST_EMAIL', defaultValue: 'user@example.com');
const _testPassword = String.fromEnvironment('TEST_PASSWORD', defaultValue: 'Password123!');
```

Run with the values supplied at the command line: `patrol test --target <file> --dart-define=TEST_EMAIL=... --dart-define=TEST_PASSWORD=...`.

**When a required precondition wasn't injected, skip — don't fail:**

```dart
const seedId = String.fromEnvironment('TEST_SEED_ID', defaultValue: '');
if (seedId.isEmpty) {
  markTestSkipped('reason: needs TEST_SEED_ID via --dart-define');
  return;
}
```

A missing `--dart-define` is an environment gap, not a product defect — `markTestSkipped` reports that honestly instead of recording a false failure.

### Rule 5: Running Patrol Tests

Always validate test files by running them via `patrol test --target <file>`.

**When a test fails:**

1. **Inspect view hierarchy FIRST** — Use the platform-appropriate hierarchy dump command (`adb shell uiautomator dump` for Android, `idb ui describe-all` for iOS) to reveal real element text, identifiers, states. See [cli-commands.md](../shared-references/cli-commands.md).
2. **If hierarchy is insufficient, take a screenshot** — Use `adb shell screencap` or `xcrun simctl io booted screenshot` (LAST RESORT only)
3. **Trust hierarchy/screenshot as source of truth** — If hierarchy/screenshot show the previous screen but test output indicates it's on the next screen, the navigation FAILED. Fix the navigation step before proceeding.
4. Edit the Dart test file with the proposed fix
5. Run the file via `patrol test --target <file>` to validate
6. If still failing, repeat from step 1

**Navigation debugging:**

- If tap fails to navigate: Check for duplicate text labels (use ancestor chaining)
- If screen appears unchanged: Add `waitUntilVisible()` before the tap
- If element not found: Use the view hierarchy dump to get the exact text/identifier

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
| Polling a custom predicate | `pumpUntil($, () => condition, maxSeconds: n)` — see Rule 3 |

> See [wait-strategies.md](../shared-references/wait-strategies.md) for deeper guidance on choosing timeouts, polling with `pumpUntil`, and avoiding flaky waits.

### Rule 8: App Launch Must Be First

`launchApp($)` (from `helpers/app_helper.dart`) MUST be the first call inside every `patrolTest` — directly, or transitively via a helper that calls it internally, such as `loginHelper($)` (from `helpers/login_helper.dart`).

- Nothing exists on screen before that call. Calling `pumpAndSettle()` or any finder before `launchApp($)` (or a helper that calls it) will hang or throw.
- Use `loginHelper($)` for any testcase/scenario that assumes the user is already signed in. Use `launchApp($)` directly only for a testcase that exercises the login screen itself — logging in IS the thing under test there.
- Pair `setUpAll(clearAppData)` (also from `helpers/app_helper.dart`) at the top of `main()` so each run starts from a clean app state.

```dart
void main() {
  setUpAll(clearAppData);

  patrolTest('...', ($) async {
    await loginHelper($); // or: await launchApp($); for a login testcase
    // ...
  }, tags: const ['P0']);
}
```

### Rule 9: One `patrolTest` Per File — Use `Checks` for Multiple Assertions

Keep exactly ONE `patrolTest` per file. The Android Test Orchestrator only runs the FIRST app-launching test in a bundle — a second `patrolTest()` in the same file is silently skipped in CI, with no warning.

To report several logical checks from that one test, use the `Checks` soft-assert collector (from `helpers/test_helpers.dart` — see `references/test-helpers.dart` for the full API):

- `c.verify(id, ok, reason)` — records a pass/fail without throwing, so the rest of the test keeps running.
- `c.skip(id, why)` — records a check as intentionally skipped.
- `await c.verifyAsync(id, () async => ..., reason)` — same as `verify`, for an async probe.
- `c.done()` — call once, at the end of the `patrolTest` — fails the test if any recorded check failed, but only after everything ran and a summary printed.

A bare `expect()` is still appropriate for a hard stop the rest of the file genuinely depends on (e.g., a precondition element that must render before anything else can be checked).

### Rule 10: Tag Taxonomy — `P0` vs `smoke`

- `tags: const ['P0']` — a focused per-feature test, living in `testcases/<feature>/*.dart`. Run in isolation via `patrol test --target <file> --tags P0`.
- `tags: const ['smoke']` — reserved for the ONE composite suite, `smoke_suite_test.dart` at the root of `integration_test/`, which logs in once and runs every feature's exported scenario function. Run via `patrol test --target integration_test --tags smoke`.

These two tags are deliberately mutually exclusive — a test file carries one or the other, never both — so the focused runs and the composite run never double-count the same check in CI.

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

Navigate back to a known state before independent error scenarios. Prefer the `ensureHome($)` helper (from `helpers/test_helpers.dart` — Rule 3) over hand-rolled navigation, since it recovers to home regardless of where the previous scenario left off:

```dart
// Happy path
await verifyLoginSuccess($);

// Reset state — recovers to a known home screen, dismissing any leftover
// sheet/dialog/pushed route
await ensureHome($);

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

### Composite Smoke Suite Pattern

`smoke_suite_test.dart`, at the root of `integration_test/`, imports every feature's exported `...Scenario` function and runs them all inside ONE `patrolTest` tagged `smoke` (Rule 10), paying the login cost once instead of once per feature. See `references/smoke_suite_template.dart` for the full template.

```dart
void main() {
  setUpAll(clearAppData);

  patrolTest('smoke suite (all features, single login)', ($) async {
    final c = Checks();

    Future<void> run(
      String name,
      Future<void> Function(PatrolIntegrationTester, Checks) scenario, {
      bool recover = true,
    }) async {
      try {
        await scenario($, c);
      } catch (e) {
        c.verify(name, false, 'scenario threw: $e');
      }
      if (recover) await ensureHome($);
    }

    await run('login', loginScenario);
    // Read-only / navigation scenarios first.
    await run('home.navigation', homeNavigationScenario);
    // Side-effecting scenarios run late.
    await run('settings.overview', settingsOverviewScenario, recover: false);

    c.done();
  }, tags: const ['smoke']);
}
```

Key points:

- The local `run(name, scenario, {recover = true})` wrapper try/catches each scenario, recording a failure into `Checks` instead of letting it abort the rest of the suite, then calls `ensureHome($)` (Rule 3) to recover before the next scenario.
- **Ordering is deliberate** — read-only/navigation scenarios run first; side-effecting scenarios (form submits, settings changes, sign-out) run LATE so they don't disturb state earlier scenarios depend on. Pass `recover: false` for a scenario that intentionally ends the session (e.g., one that signs out).

## Lifecycle Setup

Every file containing a `patrolTest` — a testcase's own `main()`, a scenario, or the composite smoke suite — is responsible for its own launch and state reset, because each may run standalone via `--target` (Rule 8):

```dart
void main() {
  setUpAll(clearAppData); // helpers/app_helper.dart — reset to a clean install

  patrolTest(
    'user journey description',
    ($) async {
      await loginHelper($); // helpers/login_helper.dart — calls launchApp($)
      //                        internally, satisfying Rule 8

      final c = Checks();
      // ... test steps, recorded via c.verify(...) (Rule 9)
      c.done();
    },
    tags: const ['P0'],
  );
}
```

**Important:** `launchApp($)` (or a helper that calls it internally, like `loginHelper($)`) MUST come first — see Rule 8. Only a testcase/scenario that exercises the login screen itself calls `launchApp($)` directly instead of `loginHelper($)`.

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
| Calling `pumpAndSettle()`/a finder before `launchApp($)` | Nothing is on screen yet — hangs or throws (Rule 8)         | Call `launchApp($)` (or a helper like `loginHelper($)` that calls it) FIRST, always         |
| Multiple `patrolTest()` in one file       | Android Test Orchestrator only runs the first — the rest are silently skipped in CI (Rule 9) | One `patrolTest` per file; use `Checks` to report multiple logical checks                   |
| Failing the test when a `--dart-define` precondition is missing | Reports a false product defect for an environment gap (Rule 4) | `markTestSkipped('reason: ...')` and `return`                                        |
| Mixing `P0` and `smoke` tags on the same test | Double-counts the same check across focused and composite runs in CI (Rule 10) | Tag a file with exactly one of `P0` or `smoke`, never both                        |

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

After mapping is confirmed, implement each file following the testcase template (`references/testcase_template.dart`):

1. **Do NOT include navigation** — testcases are atomic and assume they're already on the target screen
2. Use the view hierarchy CLI command + source code to find selectors (Rule 2)
3. **Handle screens not ready for interaction** — Use retry pattern if needed
4. Write ARRANGE → ACT → ASSERT, recording each check via `Checks.verify` (Rule 9) rather than a bare `expect()`
5. Export the steps as a top-level `Future<void> <name>Scenario(PatrolIntegrationTester $, Checks c)` function, and give the file a thin `main()` that calls `loginHelper($)` (or `launchApp($)` for a login testcase) first, then that function, then `c.done()` (Rule 1, Rule 8)
6. Tag the file `tags: const ['P0']` (Rule 10)
7. Run via `patrol test --target <file> --tags P0` to validate before saving

**Step 6 · Write the scenario**

Once all testcases exist, compose the scenario (`references/scenario_template.dart`):

1. **PRIORITIZE existing testcases** — import each testcase's exported `...Scenario` function (Rule 1) and call it instead of duplicating steps
2. Only use inline code when no testcase exists for the action
3. Group testcases into logical user journey (happy path first, then error paths)
4. Reset to a known state between independent error paths with `ensureHome($)` (Rule 3) instead of hand-rolled navigate-and-logout steps
5. Wrap conditional testcases in `if (await $('text').exists)` or the locale-safe `existsEnId($, en, id)` (Rule 3)
6. Share one `Checks c` across every step and call `c.done()` once at the end (Rule 9)
7. Tag the file `tags: const ['P0']` (Rule 10)
8. End with assertion on final screen route or distinctive landmark element

**Step 7 · Wire into the composite smoke suite (once per feature)**

`smoke_suite_test.dart` (root of `integration_test/`, template in `references/smoke_suite_template.dart`) imports every feature's exported `...Scenario` function and runs them all under a SINGLE login, tagged `smoke` (Rule 10):

1. Import the feature's exported scenario function alongside the others already there
2. Add a `run('feature.case', fooScenario)` call inside the local `run(...)` wrapper — it try/catches the scenario into `Checks` and calls `ensureHome($)` to recover, so one feature's failure doesn't abort the rest
3. **Ordering matters** — read-only/navigation scenarios go first; side-effecting scenarios (form submits, settings changes, sign-out) go LATE so they don't disturb state earlier scenarios depend on. Pass `recover: false` only for a scenario that intentionally ends the session (e.g., sign-out)

## CLI Tool Usage

This skill uses CLI commands for device interaction and test execution.
See [shared-references/cli-commands.md](../shared-references/cli-commands.md) for full details.

- `patrol test --target <file>` — Run a Dart test file
- View hierarchy dump (`adb shell uiautomator dump` / `idb ui describe-all`) — Fetch native UI hierarchy for selector discovery (PRIMARY tool)
- Screenshot (`adb shell screencap` / `xcrun simctl io booted screenshot`) — Visual debugging (LAST RESORT only)
- `patrol devices` — Check connected devices

**Note:** Patrol CLI cannot run inline Dart code. Always write the complete test file, then run it. Use the write-run-observe-edit loop.

## References

Template files are available in the `references/` folder:

- `references/testcase_template.dart` — AAA pattern template for atomic testcases, including the launchApp-first `main()` + exported `...Scenario` function idiom (Rule 1, Rule 8, Rule 9)
- `references/scenario_template.dart` — User journey orchestration template, composing imported `...Scenario` functions under a single `loginHelper($)` call
- `references/smoke_suite_template.dart` — Composite smoke suite template: single login, every feature's exported scenario, ordered read-only-first / side-effects-last (Rule 10)
- `references/test-helpers.dart` — Reference for the `Checks` soft-assert collector and the locale-safe selector helpers (`t`, `existsEnId`, `bySemId`, `bySemLabel`, `isOnHome`, `pumpUntil`, `tapNav`, `ensureHome`) exposed by `helpers/test_helpers.dart` (Rule 3, Rule 9)
- `references/flutter-semantics.md` — Guide for adding `Semantics(identifier: '...')` to Flutter widgets
- [wait-strategies.md](../shared-references/wait-strategies.md) — Timeout/pumping guidance for `waitUntilVisible`, `pumpWidgetAndSettle`, and `pumpUntil` (Rule 7)
- [selector-rules.md](../shared-references/selector-rules.md) — Full selector decision tree (Rule 2)
- [cli-commands.md](../shared-references/cli-commands.md) — View hierarchy dump and screenshot commands (Rule 2, Rule 5)
