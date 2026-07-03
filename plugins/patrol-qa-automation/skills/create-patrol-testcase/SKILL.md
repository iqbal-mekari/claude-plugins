---
name: create-patrol-testcase
description: >
  Write a single atomic Patrol testcase Dart file for Flutter mobile apps.
  Handles selector discovery (native tree + screen source), localization
  mapping, Dart authoring, syntax validation, and test execution via Patrol
  CLI. Invoke when a confirmed test case needs to be written as a Patrol
  testcase. For planning, triage, or mapping — use patrol-test-creator agent.
  Trigger: write testcase, create testcase dart, write patrol testcase,
  generate testcase file.
---

# Create Patrol Testcase Skill

Writes a single atomic Patrol testcase Dart file. Receives a pre-triaged
test case and produces a validated, saved Dart file.

Read and follow ALL rules in the skill document before starting:

```
skills/create-patrol-test/SKILL.md
```

## Scope

- Write exactly **one atomic testcase** per invocation.
- Discover selectors from live UI and Flutter source.
- Map string literals to localization approach.
- Validate by running the test via Patrol CLI before saving.

## Constraints

- DO NOT plan, triage, or produce mapping tables.
- DO NOT handle navigation in a testcase — assume the screen is
  already active.
- DO NOT call other testcases from within a testcase (testcases are
  atomic — only scenarios orchestrate).
- DO NOT use pixel coordinates as selectors.
- DO NOT hardcode credentials, user IDs, or real tokens.
- DO NOT save the file until running via `patrol test --target <file>`
  confirms the test executes successfully.
- ONLY write code that is covered by the test case steps.

## Workflow

### Step 1 — Load references

1. Read `skills/create-patrol-test/SKILL.md` for rules and naming
   conventions.
2. Read `skills/create-patrol-test/references/testcase_template.dart`
   for the template structure.

### Step 2 — Gather selector context

Run both in parallel:

1. Read the Flutter screen file (`*_screen.dart`) for widget Keys
   and `Semantics(identifier: '...')` values.
2. Run the view hierarchy CLI command on the live device to get the
   element tree with text, identifiers, and bounds. See [cli-commands.md](../shared-references/cli-commands.md).

Apply the selector priority hierarchy — see
[shared-references/selector-rules.md](../shared-references/selector-rules.md)
for the full decision tree:

1. Text finder (`$('Login')`)
2. Key finder (`$(#emailField)`)
3. Type finder (`$(ElevatedButton)`)
4. Ancestor chaining (`$(Scaffold).$('Submit')`)
5. Containing finder (`$(Row).containing($('label'))`)

If no selector works, note that `Semantics(identifier: '...', container: true)` must
be added to the Flutter widget and the app rebuilt — include this in your output summary.

For any text finder, prefer the locale-safe helpers from
`helpers/test_helpers.dart` over a single hardcoded string — see Step 4.

### Step 3 — Map localization

1. Find string literals used in the test steps in the screen source.
2. Locate the string in both the primary and secondary locale l10n files.
3. Use one of these approaches in the test, in order of preference:
   - `t($, primaryLocaleText, secondaryLocaleText)` — locale-safe helper
     that returns whichever of the two locale strings is present as a
     `PatrolFinder` (preferred for tappable/assertable text).
   - `existsEnId($, primaryLocaleText, secondaryLocaleText)` — locale-safe
     bool check for whether either locale string is visible.
   - `bySemId(id)` / `bySemLabel(label)` — `Finder`s matching
     `Semantics.identifier` / `Semantics.label` when text is unstable.
   - Direct single-locale text matching: `$('Login').tap()` — only when
     the app under test is locked to one locale.

### Step 4 — Write Dart

Follow the two-form structure from `testcase_template.dart`:

1. **Export a top-level scenario function** —
   `Future<void> <action><Target>Scenario(PatrolIntegrationTester $, Checks c) async { ... }`
   holding the actual steps in AAA order:

   ```dart
   // ARRANGE — preconditions / setup
   // ACT     — user interactions
   // ASSERT  — expected UI state
   ```

   Exporting this function lets `scenarios/` files and `smoke_suite_test.dart`
   `import '...' show <action><Target>Scenario;` and reuse the steps instead
   of duplicating them.

2. **Keep `main()` thin** — one `patrolTest` that calls `launchApp($)` (or a
   login helper like `loginHelper($)`, which calls `launchApp($)`
   internally) first, then constructs a `Checks()`, calls the exported
   scenario, and finishes with `c.done()`:

   ```dart
   void main() {
     setUpAll(clearAppData);
     patrolTest(
       '<action> <target>: <brief description>',
       ($) async {
         await loginHelper($); // or `await launchApp($);` for a login testcase
         final c = Checks();
         await <action><Target>Scenario($, c);
         c.done();
       },
       tags: const ['P0'],
     );
   }
   ```

Apply these rules while writing:

- **`launchApp($)` first, always.** Directly, or transitively via a login
  helper. Never call `pumpAndSettle()` or any finder before it — nothing
  exists on screen yet.
- **One `patrolTest` per file.** The Android Test Orchestrator only runs the
  FIRST app-launching test in a bundle — a second `patrolTest()` in the same
  file is silently skipped in CI. Report additional logical checks through
  `Checks`, not additional `patrolTest()` blocks.
- **Use `Checks` instead of a bare `expect()`** for anything that should be
  soft-asserted (from `helpers/test_helpers.dart`):
  - `c.verify(id, boolCondition, reason)` — record a pass/fail check.
  - `c.skip(id, why)` — record a step that could not be automated.
  - `await c.verifyAsync(id, () async { ... }, reason)` — record an async
    probe's result.
  - `c.done()` — call once, at the end of the `patrolTest` in `main()` (not
    inside the exported scenario). Fails the test if any check failed, but
    only after everything has run and a summary has printed.
  - A bare `expect()` is still fine for a genuine hard stop that the rest of
    the file depends on.
- **Locale-safe selectors** — use `t($, primaryLocaleText, secondaryLocaleText)`,
  `existsEnId($, primaryLocaleText, secondaryLocaleText)`, `bySemId(id)`, or
  `bySemLabel(label)` from `helpers/test_helpers.dart` (see Step 3).
- **Credentials and seed data via `--dart-define`, never hardcoded.** Declare
  with a non-secret default:
  `const _testEmail = String.fromEnvironment('TEST_EMAIL', defaultValue: 'user@example.com');`.
  If a required precondition was not injected, call
  `markTestSkipped('reason: needs X via --dart-define')` and `return` —
  do NOT fail the test.
- **Tag** every `patrolTest` with `tags: const ['P0']` for a focused
  per-feature testcase living in `testcases/<feature>/*.dart`.
- Still apply the general Patrol conventions from
  `create-patrol-test/SKILL.md`: finder patterns (text / Key / type /
  ancestor / containing), the `enterText()` pattern (tap the field first,
  then enter text), and `waitUntilVisible` timeout conventions.

### Step 5 — Validate by running

1. Run the test via `patrol test --target` to confirm it executes
   on the live device:
   ```bash
   patrol test --target integration_test/testcases/login/tap_login_button.dart --tags P0
   ```
2. If a step fails, inspect the view hierarchy FIRST via the CLI
   command (see [cli-commands.md](../shared-references/cli-commands.md)),
   then take a screenshot as a last resort. Fix the Dart file and
   re-run before saving.

### Step 6 — Save

Save the validated Dart file to:

```
integration_test/testcases/<feature>/<action>.dart
```

## Output

Return a summary:

- **File saved**: path to created testcase
- **Scenario exported**: name of the `<action><Target>Scenario` function
- **Finders used**: one line per element (text / Key / type / ancestor)
- **Localization approach**: locale-safe helper (`t`/`existsEnId`/`bySemId`/
  `bySemLabel`) or direct single-locale text
- **Semantics needed**: any Flutter widget changes required
- **Skipped steps**: any steps that could not be automated (recorded via
  `c.skip`)
