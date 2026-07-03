// integration_test/testcases/<feature>/<action>_<target>.dart
//
// Description: Brief description of what this testcase validates
// Screen: <Feature>Screen
// Priority: P0 | P1 | P2
// Tags: P0 — focused per-feature test (kept OUT of 'smoke', see
//       smoke_suite_template.dart, so the two runs never double-count)
// Parameters: (list any required function parameters)
//
// TWO FORMS IN THIS FILE:
//   1. A thin main() + patrolTest() — lets this file run standalone via
//      `patrol test --target <file> --tags P0` for fast, isolated debugging.
//   2. An exported top-level Future<void> actionTargetScenario(...) function
//      — so scenarios/ and smoke_suite_test.dart can import and reuse this
//      same logic (`import '...' show actionTargetScenario;`) instead of
//      duplicating it.
//
// RULES:
//   - `await launchApp($)` (or a login helper that calls it internally, e.g.
//     `loginHelper($)`) MUST be the first call in every patrolTest. Nothing
//     is on screen before that — calling pumpAndSettle() or a finder first
//     will hang or throw.
//   - Keep exactly ONE patrolTest per file. The Android Test Orchestrator
//     only runs the FIRST app-launching test in a bundle — a second
//     patrolTest() in the same file is silently skipped in CI. Use the
//     Checks soft-assert collector (see references/test-helpers.dart) to
//     report several logical checks from this one test instead of writing
//     several patrolTest() blocks.
//   - This exported scenario assumes launch/login already happened — either
//     by this file's own main(), or by whichever caller composed it (the
//     smoke suite logs in once, up front). The exception is a dedicated
//     "login" testcase/scenario, which owns calling launchApp($) itself
//     because logging in IS the thing under test.

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import '../../helpers/app_helper.dart'; // launchApp($), clearAppData()
import '../../helpers/login_helper.dart'; // loginHelper($) — calls launchApp() internally
import '../../helpers/test_helpers.dart'; // Checks, t(), existsEnId(), etc.

/// Atomic testcase: <action>_<target>
/// Validates: <brief description of what is being tested>
///
/// Exported so scenarios and the composite smoke suite can call this
/// directly instead of re-implementing the same steps.
Future<void> actionTargetScenario(PatrolIntegrationTester $, Checks c) async {
  // ARRANGE
  // Testcases assume the target screen is already reachable — they never
  // navigate via other testcases. If this testcase needs external data
  // (seeded account, feature flag, etc.), accept it as a function parameter:
  //   Future<void> actionTargetScenario(
  //     PatrolIntegrationTester $, Checks c, {required String optionValue}) async {

  // Example: skip gracefully instead of failing when a precondition was not
  // injected via --dart-define.
  const seedId = String.fromEnvironment('TEST_SEED_ID', defaultValue: '');
  if (seedId.isEmpty) {
    markTestSkipped('reason: needs TEST_SEED_ID via --dart-define');
    return;
  }

  // ACT
  // Prefer locale-safe selectors over a single hardcoded string:
  //   await t($, 'Save', 'Simpan').tap();
  //   await $(#targetField).enterText('example value');

  // ASSERT
  // Prefer the soft-assert Checks collector over a bare expect() so this
  // testcase composes cleanly into a scenario or the smoke suite without
  // aborting it on the first failure.
  c.verify(
    'TC001',
    existsEnId($, 'Success', 'Berhasil'),
    'expected confirmation not shown after the action',
  );

  // A bare expect() is still fine when a hard stop makes sense even inside
  // a composed run (e.g. a precondition the rest of the file depends on):
  // expect($(#targetField), findsOneWidget,
  //     reason: 'target field must render before continuing');
}

void main() {
  setUpAll(clearAppData);

  patrolTest(
    'action target: <brief description>',
    ($) async {
      // launchApp($) (via loginHelper($) here) MUST be the first call — see
      // the rule above. Call launchApp($) directly instead of loginHelper($)
      // only for a testcase that exercises the login screen itself.
      await loginHelper($);

      final c = Checks();
      await actionTargetScenario($, c);
      c.done();
    },
    tags: const ['P0'],
  );
}
