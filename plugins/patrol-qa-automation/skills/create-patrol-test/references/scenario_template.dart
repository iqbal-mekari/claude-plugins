// patrol_test/scenarios/<feature>/<user_journey>.dart
//
// Description: Brief description of the user journey
// Coverage: <Feature>Screen -> <NextScreen> -> ...
// Priority: P0 | P1 | P2

import 'package:patrol/patrol.dart';
import 'package:your_app/main.dart';
import '../helpers/login.dart';
import '../testcases/<feature>/verify_screen.dart';
import '../testcases/<feature>/perform_action.dart';

/// Scenario: <feature>_<user_journey>
/// End-to-end user journey covering happy path and error paths
void main() {
  patrolTest(
    '<feature>_<user_journey>: end-to-end journey',
    ($) async {
      // === ARRANGE ===
      // Launch app with clean state
      await $.pumpWidgetAndSettle(const MyApp());
      await $.platform.mobile.grantPermissionWhenInUse();

      // Login (shared helper)
      await performLogin($);

      // === ACT - Happy Path ===
      // Navigate to feature screen and verify
      await verifyScreen($);
      await performAction($);

      // === ASSERT - Happy Path ===
      expect($('Success'), findsOneWidget);

      // === Reset State ===
      await performLogout($);
      await navigateToLogin($);

      // === ACT - Error Path ===
      // Test error scenarios
      // await verifyErrorState($);
    },
  );
}
