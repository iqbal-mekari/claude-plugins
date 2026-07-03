---
name: compose-patrol-scenario
description: >
  Compose a Patrol scenario Dart file from a confirmed list of testcase
  files for Flutter mobile apps. Handles imports, helper function
  orchestration, state reset between independent error paths, and
  end-to-end validation via Patrol CLI. Invoke after all testcase Dart
  files are saved. For planning, triage, or testcase authoring — use
  patrol-test-creator agent.
  Trigger: compose scenario, create scenario dart, write patrol scenario,
  generate scenario file, assemble scenario.
---

# Compose Patrol Scenario Skill

Composes a Patrol scenario Dart file that orchestrates atomic testcases
into end-to-end user journeys for Flutter mobile apps.

Read and follow ALL rules in the skill document before starting:

```
skills/create-patrol-test/SKILL.md
```

## Scope

- Compose exactly **one scenario** per invocation.
- Orchestrate provided testcases via imports and function calls.
- Wire app launch and login in the `patrolTest()` setup.
- Insert state resets between independent error paths.
- Validate end-to-end via Patrol CLI before saving.

## Constraints

- DO NOT plan, triage, or write testcases.
- DO NOT duplicate testcase logic inline — call the imported
  testcase function for every action covered by an existing testcase.
- DO NOT add setup/teardown to testcase files — only scenarios
  manage lifecycle.
- DO NOT hardcode credentials, user IDs, or real tokens.
- DO NOT save until `patrol test --target <file>` passes end-to-end.

## Workflow

### Step 1 — Load references

1. Read `skills/create-patrol-test/SKILL.md` for rules and templates.
2. Read `skills/create-patrol-test/references/scenario_template.dart`
   for the template structure.
3. Read `integration_test/helpers/` to identify available shared
   helpers — notably `loginHelper($)` (login, calls `launchApp($)`
   internally) from `helpers/login_helper.dart`, `ensureHome($)` for
   state resets, and the `Checks` soft-assert collector from
   `helpers/test_helpers.dart`.
4. If this journey belongs in the always-run composite smoke set
   instead of a standalone per-journey file, read
   `skills/create-patrol-test/references/smoke_suite_template.dart`
   and see "Alternative: composite smoke suite" below.

### Step 2 — Review testcases

Read each provided testcase file to understand:

- What screen it operates on.
- Whether it ends with an assertion or a navigation action.
- Whether it accepts function parameters.

Group testcases into logical segments:

1. **Happy path** — primary success journey
2. **Error paths** — one independent failure scenario per group
3. **Edge cases** — conditional / optional UI paths

### Step 3 — Write scenario Dart

Structure:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import '../../helpers/app_helper.dart'; // clearAppData()
import '../../helpers/login_helper.dart'; // loginHelper($) — calls launchApp() internally
import '../../helpers/test_helpers.dart'; // Checks, existsEnId(), ensureHome(), etc.
import '../../testcases/<feature>/verify_screen_test.dart'
    show verifyScreenScenario;
import '../../testcases/<feature>/perform_action_test.dart'
    show performActionScenario;

void main() {
  setUpAll(clearAppData);

  patrolTest(
    '<feature>_<user_journey>: end-to-end journey',
    ($) async {
      final c = Checks();

      // === ARRANGE ===
      // Log in ONCE for the whole journey. loginHelper($) calls
      // launchApp($) internally, so this still satisfies the
      // launchApp-first rule — do not re-launch or re-login per step.
      await loginHelper($);

      // === ACT - Happy Path ===
      // Call the imported testcase scenario functions instead of
      // inlining their steps.
      await verifyScreenScenario($, c);
      await performActionScenario($, c);

      // === ASSERT - Happy Path ===
      c.verify('TC020', existsEnId($, 'Success', 'Berhasil'),
          'expected confirmation not shown for the happy path');

      // === Reset State ===
      await ensureHome($);

      // === ACT/ASSERT - Error Path ===
      // await verifyErrorScenario($, c);
      // c.verify('TC021', existsEnId($, 'Error message', 'Pesan galat'),
      //     'expected error message not shown');

      c.done();
    },
    tags: const ['P0'],
  );
}
```

Rules:

- Log in ONCE via `loginHelper($)` at the top of the journey — never
  re-launch or re-log-in per step; it already calls `launchApp($)`
  internally.
- Prefer calling an imported `<name>Scenario($, c)` function — exported
  by a `testcases/<feature>/` file and pulled in via
  `import '...' show fooScenario;` — over inlining steps. Only write
  inline code when no testcase covers the action yet.
- Use `if (await $('text').exists)` for conditional testcase calls.
- Pass data between testcase calls via function parameters when
  needed.
- Insert a state reset (`ensureHome($)` or logout) between each
  independent error scenario.
- Prefer `c.verify(...)` — the `Checks` soft-assert collector from
  `helpers/test_helpers.dart` — over a bare `expect()`, so one failure
  doesn't abort the rest of the journey. A bare `expect()` is still
  fine for a hard precondition the rest of the file depends on.
- End every `patrolTest` with `c.done()` instead of/alongside bare
  `expect()` calls — it fails the test if any check failed, but only
  after running everything and printing a summary.

### Step 4 — Run end-to-end

Run the full scenario with `patrol test --target`:

```bash
patrol test --target integration_test/scenarios/<feature>/<journey>.dart
```

When a step fails:

1. Inspect the view hierarchy FIRST via the CLI command (see [cli-commands.md](../shared-references/cli-commands.md)).
2. If hierarchy is insufficient, take a screenshot as a last resort.
3. Fix the scenario Dart file (do not modify testcase files).
4. Re-run to confirm the fix before saving.

### Step 5 — Save

Save to:

```
integration_test/scenarios/<feature>/<journey_name>.dart
```

### Alternative: composite smoke suite

If this journey belongs in the always-run smoke set alongside every
other feature — rather than living as a standalone per-journey file —
compose it as one entry inside the root
`integration_test/smoke_suite_test.dart` instead. That file runs a
SINGLE `patrolTest`, tagged `smoke`, under one login: it imports every
feature's exported `...Scenario` function and calls each through a
local `run(name, scenario, {recover = true})` wrapper that try/catches
the scenario (recording any failure into `Checks` without aborting the
rest) and calls `ensureHome($)` to recover between scenarios. Ordering
is deliberate — side-effecting scenarios (form submits, settings
changes, sign-out) run LATE. See
`skills/create-patrol-test/references/smoke_suite_template.dart` for
the full pattern.

## Output

Return a summary:

- **File saved**: path to created scenario
- **Testcases orchestrated**: list of imported functions in order
- **Helpers used**: shared helper files referenced
- **State resets**: where resets were inserted
- **Inline logic**: any assertions not covered by a testcase
  (should be minimal)
