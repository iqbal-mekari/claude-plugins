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

### Step 3 — Map localization

1. Find string literals used in the test steps in the screen source.
2. Locate the ARB key in the l10n files.
3. Use one of these approaches in the test:
   - Direct text matching: `$('Login').tap()` (preferred for simple
     cases)
   - `AppLocalizations.of($)` for dynamic/localized strings

### Step 4 — Write Dart

Follow the AAA pattern from the skill template:

```dart
// ARRANGE — preconditions / setup
// ACT     — user interactions
// ASSERT  — expected UI state
```

Apply relevant rules from SKILL.md:

- Patrol finder patterns (text, Key, type, ancestor, containing)
- `enterText()` pattern (tap field first, then enter text)
- Timeout conventions (`waitUntilVisible`)
- `pumpWidgetAndSettle()` for app launch

### Step 5 — Validate by running

1. Run the test via `patrol test --target` to confirm it executes
   on the live device:
   ```bash
   patrol test --target patrol_test/testcases/login/tap_login_button.dart
   ```
2. If a step fails, inspect the view hierarchy FIRST via the CLI
   command (see [cli-commands.md](../shared-references/cli-commands.md)),
   then take a screenshot as a last resort. Fix the Dart file and
   re-run before saving.

### Step 6 — Save

Save the validated Dart file to:

```
patrol_test/testcases/<screen>/<action_name>.dart
```

## Output

Return a summary:

- **File saved**: path to created testcase
- **Finders used**: one line per element (text / Key / type / ancestor)
- **Localization approach**: direct text or AppLocalizations
- **Semantics needed**: any Flutter widget changes required
- **Skipped steps**: any steps that could not be automated
