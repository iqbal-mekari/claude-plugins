---
name: compose-patrol-scenario
description: >
  Compose a Patrol scenario Dart file from a confirmed list of testcase
  files for Flutter mobile apps. Handles imports, helper function
  orchestration, state reset between independent error paths, and
  end-to-end validation via Patrol MCP. Invoke after all testcase Dart
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
- Validate end-to-end via Patrol MCP before saving.

## Constraints

- DO NOT plan, triage, or write testcases.
- DO NOT duplicate testcase logic inline — call the imported
  testcase function for every action covered by an existing testcase.
- DO NOT add setup/teardown to testcase files — only scenarios
  manage lifecycle.
- DO NOT hardcode credentials, user IDs, or real tokens.
- DO NOT save until `mcp_patrol_mcp_run` passes end-to-end.

## Workflow

### Step 1 — Load references

1. Read `skills/create-patrol-test/SKILL.md` for rules and templates.
2. Read `skills/create-patrol-test/references/scenario_template.dart`
   for the template structure.
3. Read `patrol_test/helpers/` to identify available shared helpers
   (login, logout, navigation resets).

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
import 'package:patrol/patrol.dart';
import 'package:your_app/main.dart';
import '../helpers/login.dart';
import '../testcases/<feature>/verify_screen.dart';
import '../testcases/<feature>/perform_action.dart';

void main() {
  patrolTest(
    '<feature>_<user_journey>: end-to-end journey',
    ($) async {
      // === ARRANGE ===
      await $.pumpWidgetAndSettle(const MyApp());
      await $.platform.mobile.grantPermissionWhenInUse();
      await performLogin($);

      // === ACT - Happy Path ===
      await verifyScreen($);
      await performAction($);

      // === ASSERT - Happy Path ===
      expect($('Success'), findsOneWidget);

      // === Reset State ===
      await performLogout($);
      await navigateToLogin($);

      // === ACT - Error Path ===
      // await verifyErrorState($);
    },
  );
}
```

Rules:

- Use `if (await $('text').exists)` for conditional testcase calls.
- Pass data between testcase calls via function parameters when
  needed.
- Insert a state reset (logout or navigate to home) between each
  independent error scenario.
- End with `expect()` on a landmark element of the final screen.

### Step 4 — Run end-to-end

Run the full scenario with `mcp_patrol_mcp_run`:

```
mcp_patrol_mcp_run  testFile="patrol_test/scenarios/<feature>/<journey>.dart"
```

When a step fails:

1. Call `mcp_patrol_mcp_screenshot` to capture current screen.
2. Call `mcp_patrol_mcp_native-tree` to diagnose.
3. Fix the scenario Dart file (do not modify testcase files).
4. Re-run to confirm the fix before saving.

### Step 5 — Save

Save to:

```
patrol_test/scenarios/<feature>/<journey_name>.dart
```

## Output

Return a summary:

- **File saved**: path to created scenario
- **Testcases orchestrated**: list of imported functions in order
- **Helpers used**: shared helper files referenced
- **State resets**: where resets were inserted
- **Inline logic**: any assertions not covered by a testcase
  (should be minimal)
