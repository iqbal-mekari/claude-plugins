// integration_test/scenarios/<feature>/<journey>.dart
//
// Description: Brief description of the end-to-end user journey
// Coverage: <Feature>Screen -> <NextScreen> -> ...
// Priority: P0 | P1 | P2
//
// Scenarios compose testcases into a user journey. PRIORITIZE calling an
// imported `...Scenario()` function (exported by a testcases/<feature>/ file)
// over inlining steps — only write inline code when no testcase covers the
// action yet.

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import '../../helpers/app_helper.dart'; // clearAppData()
import '../../helpers/login_helper.dart'; // loginHelper($) — calls launchApp() internally
import '../../helpers/test_helpers.dart'; // Checks, existsEnId(), ensureHome(), etc.
import '../../testcases/<feature>/verify_screen_test.dart'
    show verifyScreenScenario;
import '../../testcases/<feature>/perform_action_test.dart'
    show performActionScenario;

/// Scenario: <feature>_<user_journey>
/// End-to-end user journey covering the happy path and one error path,
/// under a single login.
void main() {
  setUpAll(clearAppData);

  patrolTest(
    '<feature>_<user_journey>: end-to-end journey',
    ($) async {
      final c = Checks();

      // === ARRANGE ===
      // loginHelper($) calls launchApp($) internally, so this still
      // satisfies the launchApp-first rule.
      await loginHelper($);

      // === ACT - Happy Path ===
      // Reuse exported testcase scenario functions instead of duplicating
      // their steps here.
      await verifyScreenScenario($, c);
      await performActionScenario($, c);

      // === ASSERT - Happy Path ===
      c.verify('TC020', existsEnId($, 'Success', 'Berhasil'),
          'expected confirmation not shown for the happy path');

      // === Reset State ===
      // Return to a known screen before an independent error path so one
      // failure doesn't cascade into the next check.
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
