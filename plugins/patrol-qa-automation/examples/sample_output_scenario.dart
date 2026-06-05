// Expected output: patrol_test/scenarios/login/login_full_journey.dart

import 'package:patrol/patrol.dart';
import 'package:your_app/main.dart';
import '../../helpers/login.dart';
import '../../helpers/logout.dart';
import '../../testcases/login/verify_login_form_visible.dart';
import '../../testcases/login/tap_login_button_valid.dart';
import '../../testcases/login/submit_empty_email.dart';
import '../../testcases/login/submit_wrong_password.dart';

/// Login full journey: happy path + error paths
void main() {
  patrolTest(
    'login_full_journey: happy path + error paths',
    ($) async {
      // Setup
      await $.pumpWidgetAndSettle(const MyApp());
      await $.platform.mobile.grantPermissionWhenInUse();

      // --- Happy Path ---
      await verifyLoginFormVisible($);
      await tapLoginButtonValid($);
      expect($('Welcome'), findsOneWidget);

      // --- Reset ---
      await performLogout($);
      await navigateToLogin($);

      // --- Error Path: Empty Email ---
      await submitEmptyEmail($);

      // --- Reset ---
      await navigateToLogin($);

      // --- Error Path: Invalid Credentials ---
      await submitWrongPassword($);
    },
  );
}
