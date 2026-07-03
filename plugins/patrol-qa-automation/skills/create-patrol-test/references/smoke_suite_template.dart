// integration_test/smoke_suite_test.dart
//
// Composite smoke suite — runs every feature's exported scenario function in
// ONE patrolTest with a SINGLE login, tagged 'smoke' (deliberately kept OUT
// of 'P0' so the composite run and the focused per-feature runs, tagged
// 'P0' in their own testcases/<feature>/*.dart files, never double-count in
// CI).
//
//   patrol test --target integration_test --tags smoke -d <device>
//
// Why one test: each feature already exposes a reusable scenario function
// (see the matching testcases/<feature>/*.dart files, which also expose a
// focused per-feature patrolTest tagged 'P0' for `--target` debugging).
// Composing them here pays the login cost ONCE instead of once per feature.
// Each scenario is wrapped so a failure in one is recorded (via Checks) but
// does not abort the rest, and the suite recovers to a known home screen
// between scenarios.
//
// Ordering is deliberate: read-only / navigation scenarios run first;
// scenarios with side effects (submitting a form, changing settings, signing
// out) run LATE so they don't disturb the state the earlier scenarios rely
// on.

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers/app_helper.dart';
import 'helpers/login_helper.dart';
import 'helpers/test_helpers.dart';
import 'testcases/login/login_test.dart' show loginScenario;
import 'testcases/home/home_navigation_test.dart' show homeNavigationScenario;
import 'testcases/list/list_screen_test.dart' show listScreenScenario;
import 'testcases/detail/detail_screen_test.dart' show detailScreenScenario;
import 'testcases/form/form_submit_test.dart' show formSubmitScenario;
import 'testcases/settings/settings_overview_test.dart'
    show settingsOverviewScenario;

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
      if (recover) {
        // Return to a known, tappable home screen so the next scenario
        // starts clean — dismisses any leftover sheet/dialog/pushed route
        // left behind by the scenario that just ran.
        await ensureHome($);
      }
    }

    // Login scenario drives its own login (asserts the login screen first).
    await run('login', loginScenario);

    // Read-only / navigation scenarios first.
    await run('home.navigation', homeNavigationScenario);
    await run('list.overview', listScreenScenario);
    await run('detail.overview', detailScreenScenario);

    // Side-effecting scenarios run late.
    await run('form.submit', formSubmitScenario);
    // Settings may sign out at the end — keep it LAST, and don't bother
    // recovering afterward.
    await run('settings.overview', settingsOverviewScenario, recover: false);

    c.done();
  }, tags: const ['smoke']);
}
