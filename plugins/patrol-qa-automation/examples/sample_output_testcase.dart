// Expected output: integration_test/testcases/login/verify_login_form_visible.dart

import 'package:patrol/patrol.dart';
import 'package:your_app/main.dart';

/// Verify that the login form displays all expected elements
Future<void> verifyLoginFormVisible(PatrolIntegrationTester $) async {
  await $.pumpWidgetAndSettle(const MyApp());

  // Dismiss permission dialog if present
  if (await $('Allow').exists) {
    await $('Allow').tap();
  }

  // ASSERT - All login form elements are visible
  expect($('Email'), findsOneWidget);
  expect($('Password'), findsOneWidget);
  expect($('Login'), findsOneWidget);
  expect($('Forgot password'), findsOneWidget);
}
