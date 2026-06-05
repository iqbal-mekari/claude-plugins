// patrol_test/testcases/<feature>/<action>_<target>.dart
//
// Description: Brief description of what this testcase validates
// Screen: <Feature>Screen
// Priority: P0 | P1 | P2
// Parameters: (list any required function parameters)

import 'package:patrol/patrol.dart';
import 'package:your_app/main.dart';

/// Atomic testcase: <action>_<target>
/// Validates: <brief description of what is being tested>
Future<void> actionTarget(PatrolIntegrationTester $) async {
  // ARRANGE
  // Set up the initial state
  // If this testcase needs external data, use function parameters:
  //   Future<void> selectOption(PatrolIntegrationTester $, {required String optionValue}) async {

  await $.pumpWidgetAndSettle(const MyApp());

  // ACT
  // Perform the action being tested
  // Use Patrol finders for all interactions:
  // - $('Login').tap()
  // - $(#emailField).enterText('test@example.com')

  // ASSERT
  // Verify the expected outcome
  // - expect($('Welcome'), findsOneWidget)
  // - expect($(#homeScreen), findsOneWidget)
}
