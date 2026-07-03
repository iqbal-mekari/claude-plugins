// integration_test/helpers/test_helpers.dart
//
// TEMPLATE — adapt this file per project. It is NOT a drop-in library: copy
// the parts your app needs, delete the rest, and fill in every `// TODO:`
// with your app's real selectors, screens, and navigation graph. What should
// survive the copy is the *shape* of each helper — the defensive patterns
// around hangs, flakiness, locale, and CI stdout corruption — not the exact
// widget names used here as stand-ins.
//
// Where this file lives:
//   These helpers belong in `integration_test/helpers/` in the APP repo
//   under test (not in this plugin repo). Testcase and scenario files
//   produced by `create-patrol-test` / `compose-patrol-scenario` import them
//   from there, e.g.:
//     import '../helpers/test_helpers.dart';
//
// Cross-reference:
//   See shared-references/wait-strategies.md for the full explanation of
//   `pumpUntilReal` and the real-vs-simulated clock distinction: in short,
//   `$.pump(Duration)` advances Flutter's own test scheduler clock, NOT the
//   real wall clock — it does nothing to let a genuine network call or
//   native animation complete. Anywhere this file needs to wait on real I/O
//   it uses `pumpUntilReal` (or a native call) instead of a bare `$.pump`
//   loop. Read that doc before changing any of the waiting logic below.
//
// Patterns in this file:
//   1. launchApp / clearAppData — idempotent app boot + clean-slate reset
//   2. Credentials via --dart-define — non-secret defaults, override in CI
//   3. Checks — soft-assert collector (accumulate failures, don't stop early)
//   4. safeTap / safeTapText — guard-before-tap so a miss fails fast, not hangs
//   5. t() / existsEnId() — locale-safe text selectors (EN/ID)
//   6. robustLogin — retry wrapper around a flaky auth flow
//   7. ensureHome / tapNav — recover to a known screen, retry nav past overlays

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:your_app/main.dart' as app;

// =============================================================================
// 1. App lifecycle: launchApp() / clearAppData()
// =============================================================================

/// Module-level flag: has `app.main()` already been invoked in this bundle
/// run?
///
/// Patrol/the platform test orchestrator typically bundles every
/// `patrolTest` block in a scenario file into a single native test run — the
/// Flutter engine and widget tree PERSIST across those blocks. Calling
/// `app.main()` again from a later block would re-initialize providers/blocs
/// on top of an already-running app and produce confusing duplicate-init
/// errors. Guarding with a module-level flag makes [launchApp] idempotent:
/// safe to call at the top of every testcase, but it only boots the app once
/// per file/bundle.
bool _appStarted = false;

/// Whether [launchApp] has already booted the app during this run.
///
/// Exposed so other helpers (e.g. [ensureHome]) can tell "app never
/// launched" apart from "app launched but landed on an unexpected screen."
bool get appStarted => _appStarted;

/// Clears local app data/state so the next [launchApp] starts from a clean
/// slate. Call this from `setUpAll`, never from inside a `patrolTest`.
///
/// TODO: the actual mechanism is app/platform-specific. Common options:
///   * Android: shell out to `adb shell pm clear <applicationId>` as shown
///     below (only works when the test host has adb on PATH — fine for
///     local runs / an SDK-equipped CI runner, not for a bare device farm).
///   * iOS: there's no direct equivalent to `pm clear`; consider driving a
///     debug-only "reset local state" action via `$.native`, or reinstalling
///     the app between runs at the CI job level instead.
///   * Alternative: expose a hidden dev-menu action in the app itself that
///     clears local storage/secure storage, and trigger it via Patrol.
Future<void> clearAppData() async {
  _appStarted = false;
  try {
    // TODO: replace with your app's actual application/bundle identifier.
    await Process.start(
      'adb',
      ['shell', 'pm', 'clear', 'com.example.your_app'],
    );
  } catch (_) {
    // Best-effort — if adb isn't available (iOS host, sandboxed CI runner),
    // fall through. The app simply won't be reset for this run; tests that
    // rely on a clean slate should tolerate a pre-existing session too.
  }
}

/// Boots the app exactly once per bundle run, then waits for the first
/// screen (e.g. a login/splash screen) to render.
///
/// Idempotent: safe to call at the top of every testcase/scenario. Only the
/// first call actually invokes `app.main()`; later calls return immediately
/// because the widget tree from the first call is still live.
Future<void> launchApp(PatrolIntegrationTester $) async {
  if (_appStarted) return;

  // TODO: replace `app.main()` if your entrypoint needs more than a bare
  // call (e.g. `runZonedGuarded`, dependency injection, environment/config
  // bootstrapping) — call whatever your real `main.dart` does to start the
  // app the same way production does.
  app.main();

  // Bounded pump loop rather than a bare `pumpAndSettle()`. A real app with
  // ongoing animations/streams/state-management activity may never fully
  // settle, and `pumpAndSettle()` throws if it can't settle within its own
  // timeout — that would abort the whole test file on first launch. See
  // shared-references/wait-strategies.md for why a bounded pump loop is
  // preferred over both a bare `pumpAndSettle()` and an unbounded wait.
  for (var i = 0; i < 60; i++) {
    await $.pump(const Duration(milliseconds: 500));
    // TODO: replace with a real anchor on your app's first screen — e.g.
    // the login screen's title text, or a Semantics identifier on a splash
    // screen. Keep it locale-safe (see `t()` / `existsEnId()` below) if the
    // anchor is visible text rather than a stable identifier.
    if ($('Sign in').exists || $('Masuk').exists) break;
  }

  _appStarted = true;
}

// =============================================================================
// 2. Credentials via --dart-define
// =============================================================================

/// Test account credentials, injected at build/run time via `--dart-define`.
///
/// NEVER hardcode real credentials in test source. The defaults below are
/// non-secret placeholders only — override them per environment, e.g.:
///
///   patrol test --dart-define=TEST_EMAIL=you@example.com \
///               --dart-define=TEST_PASSWORD=your-test-password
const _email = String.fromEnvironment(
  'TEST_EMAIL',
  defaultValue: 'user@example.com',
);
const _password = String.fromEnvironment(
  'TEST_PASSWORD',
  defaultValue: 'password123',
);

// =============================================================================
// 3. Checks — soft-assert collector
// =============================================================================

/// Accumulates multiple pass/fail/skip outcomes within a single `patrolTest`
/// instead of stopping at the first failed `expect()`.
///
/// Useful when one test file exercises many independent checks (a smoke
/// journey, a long scenario with several assertion points) and you want a
/// complete picture of what broke, rather than aborting on the very first
/// failure and leaving the rest unexercised. Typical usage:
///
///   final c = Checks();
///   c.verify('TC001', $('Welcome').exists, 'welcome text not shown');
///   await c.verifyAsync('TC002', () async => someAsyncCondition(), 'timed out');
///   c.skip('TC003', 'precondition data not available in this environment');
///   c.done(); // prints summary, THEN fails the test if anything failed
class Checks {
  final List<String> _failures = [];
  final List<String> _passed = [];
  final List<String> _skipped = [];

  /// Records a pass/fail for [id] based on [ok]. [reason] is shown on failure.
  void verify(String id, bool ok, String reason) {
    if (ok) {
      _passed.add(id);
    } else {
      _failures.add('$id - $reason');
    }
  }

  /// Records that [id] was skipped (precondition unavailable, data-dependent,
  /// not applicable in this environment, etc.) rather than pass or fail.
  void skip(String id, String why) => _skipped.add('$id - $why');

  /// Async variant of [verify]: runs [check] and records the boolean result.
  /// A thrown error inside [check] is treated as a failure (not a crash of
  /// the whole collector), with the error message folded into the reason.
  Future<void> verifyAsync(
    String id,
    Future<bool> Function() check,
    String reason,
  ) async {
    try {
      verify(id, await check(), reason);
    } catch (e) {
      _failures.add('$id - $reason (threw: $e)');
    }
  }

  /// Strips characters outside printable 7-bit ASCII before printing.
  ///
  /// WHY THIS MATTERS: the on-device test process streams stdout back to the
  /// CLI runner in fixed-size byte chunks. If a printed string contains a
  /// multi-byte UTF-8 character (e.g. a curly quote, an em dash, a non-Latin
  /// glyph) and that character happens to land across a chunk boundary, the
  /// CLI's chunked UTF-8 decoder can receive a split/incomplete byte
  /// sequence. That throws a decode error on the HOST SIDE and can abort log
  /// relaying for the entire run — even though the on-device test itself
  /// passed. Keeping every printed summary strictly 7-bit ASCII makes the
  /// log relay immune to this failure mode. Replace anything outside the
  /// printable ASCII range (tab, newline, space through `~`) with `?`.
  static String _ascii(String s) =>
      s.replaceAll(RegExp(r'[^\x09\x0a\x20-\x7e]'), '?');

  /// Prints a summary of passed/failed/skipped counts (plus full skip/failure
  /// lists), THEN fails the enclosing test via `expect()` if anything failed.
  /// Printing happens unconditionally — even a fully-passing run prints its
  /// summary — so CI logs always show what ran.
  void done() {
    // ignore: avoid_print
    print(_ascii(
      'Checks summary - passed: ${_passed.length}, '
      'failed: ${_failures.length}, skipped: ${_skipped.length}',
    ));
    if (_skipped.isNotEmpty) {
      // ignore: avoid_print
      print(_ascii('SKIPPED:\n  ${_skipped.join('\n  ')}'));
    }
    if (_failures.isNotEmpty) {
      // ignore: avoid_print
      print(_ascii('FAILED:\n  ${_failures.join('\n  ')}'));
    }
    expect(
      _failures,
      isEmpty,
      reason: _ascii('Checks failed:\n  ${_failures.join('\n  ')}'),
    );
  }
}

// =============================================================================
// Supporting finders — Semantics identifier / label lookups
// =============================================================================

/// Finder matching a widget by its `Semantics.identifier` (set via
/// `Semantics(identifier: '...', container: true)` on a custom widget).
/// Patrol's `$('x')` uses `find.text` and will NOT match an identifier —
/// use this instead. See shared-references/selector-rules.md for the full
/// selector priority order this plugin follows.
Finder bySemId(String id) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == id,
    );

/// Finder matching a widget by its `Semantics.label` (e.g. a brand logo or
/// icon-only control that carries an accessibility label but no visible
/// text).
Finder bySemLabel(String label) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == label,
    );

/// True once the app has reached its known post-login "home" screen.
///
/// TODO: this is the single most app-specific predicate in this file. Pick a
/// locale-independent, always-present anchor on your real home screen — a
/// `Semantics(identifier: 'home_screen_indicator')` on a persistent shell
/// widget (nav bar, app bar logo, etc.) is ideal because it does not depend
/// on visible text or the device's locale.
bool isOnHomeScreen(PatrolIntegrationTester $) =>
    bySemId('home_screen_indicator').evaluate().isNotEmpty;

// =============================================================================
// 5. Locale-safe primitives
// =============================================================================

/// Returns whichever of the English ([en]) or the second-locale ([id])
/// string is currently present in the widget tree, preferring [en] when
/// both or neither are present (so a failed assertion's error message shows
/// the English text, which is usually what's in the test's own comments).
///
/// Selectors that rely on visible text are inherently locale-dependent — the
/// same screen renders different strings depending on the device's active
/// locale. Rather than hardcoding one language, route every text lookup
/// through a helper like this so the same test passes on any locale the
/// device under test happens to be set to. `en` / `id` here are just two
/// example language codes (English / a second locale) — swap in whatever
/// locales your app actually ships.
PatrolFinder t(PatrolIntegrationTester $, String en, String id) {
  if ($(en).exists) return $(en);
  if ($(id).exists) return $(id);
  return $(en);
}

/// True when either the [en] or [id] localized label is visible. Use this
/// for boolean existence checks (e.g. inside [Checks.verify]) where you
/// don't need a finder back, just a locale-safe yes/no.
bool existsEnId(PatrolIntegrationTester $, String en, String id) =>
    $(en).exists || $(id).exists;

// =============================================================================
// Waiting primitives (simulated clock vs. real clock)
// =============================================================================
// Full explanation: shared-references/wait-strategies.md. Summary here only.

/// Pumps up to [maxSeconds] simulated seconds, returning true as soon as
/// [ready] holds. Good for waits that only need Flutter's own frame
/// scheduling to catch up (animations, already-resolved futures) — NOT for
/// anything waiting on real network/IO, since `$.pump(Duration)` does not
/// advance the real wall clock. Use [pumpUntilReal] for those.
Future<bool> pumpUntil(
  PatrolIntegrationTester $,
  bool Function() ready, {
  int maxSeconds = 20,
}) async {
  for (var i = 0; i < maxSeconds; i++) {
    if (ready()) return true;
    await $.pump(const Duration(seconds: 1));
  }
  return ready();
}

/// Like [pumpUntil] but burns REAL wall-clock time between checks (via a
/// native call that is expected to fail/time out), so it can wait for
/// conditions that depend on genuine network responses or native animations
/// that a simulated `$.pump` cannot advance. See
/// shared-references/wait-strategies.md for the full mechanics and rationale
/// — in short: a native call with a timeout blocks the test isolate for that
/// real duration even when it ultimately throws, which is exactly the "burn
/// real time" effect we want.
Future<bool> pumpUntilReal(
  PatrolIntegrationTester $,
  bool Function() ready, {
  int maxSeconds = 20,
  int realBurnMs = 2000,
}) async {
  final iterations = (maxSeconds * 1000 / realBurnMs).ceil();
  for (var i = 0; i < iterations; i++) {
    // Flush pending Flutter frames first.
    await $.pump(const Duration(milliseconds: 100));
    if (ready()) return true;
    // Burn real wall-clock time via a native call that always fails — a
    // selector that can never match, with a bounded timeout.
    try {
      await $.native.waitUntilVisible(
        Selector(text: '__pumpUntilReal_dummy__'),
        timeout: Duration(milliseconds: realBurnMs),
      );
    } catch (_) {
      // Expected — the dummy selector never matches. Real time elapsed.
    }
    await $.pump(const Duration(milliseconds: 100));
    if (ready()) return true;
  }
  return ready();
}

// =============================================================================
// 4. Guard-before-tap helpers
// =============================================================================

/// Taps [finder] if — and only if — it currently matches at least one
/// element. Returns `false` instead of hanging or throwing when there is no
/// match.
///
/// WHY THIS MATTERS: Patrol's `.tap()` internally calls `waitUntilVisible()`
/// before tapping. If [finder] matches ZERO elements, `waitUntilVisible()`
/// polls forever waiting for something that will never appear — it does not
/// fail fast, it HANGS, and that hang can consume the entire test run's time
/// budget. Checking `finder.evaluate().isNotEmpty` first turns a possible
/// infinite hang into an instant, clear "not found" outcome. Once we know
/// the element exists, we still use a short `visibleTimeout` on the tap
/// itself so a genuine hit-testability miss (e.g. covered by a loading
/// overlay) also fails fast rather than waiting out the default timeout.
Future<bool> safeTap(
  PatrolIntegrationTester $,
  Finder finder, {
  Duration visibleTimeout = const Duration(seconds: 3),
}) async {
  if (finder.evaluate().isEmpty) return false;
  try {
    await $(finder).first.tap(
          settlePolicy: SettlePolicy.noSettle,
          visibleTimeout: visibleTimeout,
        );
    return true;
  } catch (_) {
    return false;
  }
}

/// Like [safeTap] but takes an EN/ID text label pair instead of a raw
/// [Finder], routing through [existsEnId] so it stays locale-safe.
Future<bool> safeTapText(
  PatrolIntegrationTester $,
  String en, [
  String? id,
]) async {
  if ($(en).exists) return safeTap($, find.text(en));
  if (id != null && $(id).exists) return safeTap($, find.text(id));
  return false;
}

// =============================================================================
// 6. robustLogin — retry wrapper around a flaky auth flow
// =============================================================================

/// Drives the app's generic login/auth flow: enters credentials and submits.
///
/// TODO: replace the stub body with your app's real login screen selectors.
/// Keep using the `--dart-define`-backed [_email] / [_password] constants
/// rather than literals so CI can override them without touching source.
Future<void> _performLoginFlow(PatrolIntegrationTester $) async {
  // TODO: adjust selectors to match your login form. Prefer Key/Semantics
  // identifiers over text for input fields (labels are often localized —
  // see shared-references/selector-rules.md selector priority order).
  await $(#emailField).enterText(_email);
  await $(#passwordField).enterText(_password);

  // Submit button label kept locale-safe via `t()`.
  await t($, 'Log in', 'Masuk').tap(settlePolicy: SettlePolicy.noSettle);

  // TODO: replace with a real wait for post-login navigation to complete.
  // Prefer `pumpUntilReal` here if login involves a real network call.
  await pumpUntilReal($, () => isOnHomeScreen($), maxSeconds: 20);
}

/// Logs in, retrying on transient auth failures.
///
/// Auth flows that hop through a web view / external identity provider (or
/// simply flake under CI load) occasionally throw partway through — a field
/// not found, a slow redirect, a dropped submit. On failure, we recover by
/// pressing the native back button a few times to dismiss whatever overlay
/// or web view is stuck on screen and return to the app's own login screen,
/// then retry the whole flow. Succeeds as soon as the home screen is
/// reached; only surfaces the underlying exception if every attempt fails.
Future<void> robustLogin(PatrolIntegrationTester $, {int attempts = 3}) async {
  for (var attempt = 1; attempt <= attempts; attempt++) {
    try {
      await _performLoginFlow($);
    } catch (_) {
      // Fall through to the home-check + recovery below rather than
      // propagating immediately — we still want to retry.
    }
    if (await pumpUntil($, () => isOnHomeScreen($), maxSeconds: 8)) return;

    if (attempt < attempts) {
      // Recovery: dismiss whatever screen/overlay/web view we're stuck on
      // via native back presses, so the next _performLoginFlow() call finds
      // the login screen's fields again instead of a half-submitted form.
      for (var k = 0; k < 5; k++) {
        if (existsEnId($, 'Sign in', 'Masuk') || isOnHomeScreen($)) break;
        try {
          await $.native.pressBack();
        } catch (_) {}
        await $.pump(const Duration(seconds: 2));
      }
      if (isOnHomeScreen($)) return;
    }
  }
  // Final attempt: surface the real failure if still not logged in, rather
  // than silently swallowing it after retries are exhausted.
  if (!isOnHomeScreen($)) await _performLoginFlow($);
}

// =============================================================================
// 7. ensureHome / tapNav — recovery to a known screen + resilient nav taps
// =============================================================================

/// Taps a navigation destination (e.g. a bottom-nav / nav-rail item) by its
/// EN-or-ID label, retrying past transient loading overlays that make the
/// destination visible but not yet hit-testable.
///
/// IMPORTANT: never call `.first.tap()` on a finder with zero matches —
/// Patrol's tap does `finder.hitTestable().first`, and `.first` on an empty
/// iterable throws `Bad state: No element` instead of waiting. So this
/// always confirms the label exists first via [pumpUntil], then attempts
/// the tap.
///
/// Retries use [pumpUntilReal]-style real-clock waits between attempts (see
/// shared-references/wait-strategies.md) rather than `$.pump(Duration)`,
/// because a loading overlay blocking hit-testing is typically waiting on a
/// real network response — simulated pumping alone will never clear it.
Future<bool> tapNav(PatrolIntegrationTester $, String en, String id) async {
  final present = await pumpUntil(
    $,
    () => $(en).exists || $(id).exists,
    maxSeconds: 45,
  );
  if (!present) return false;

  for (var attempt = 0; attempt < 5; attempt++) {
    final f = $(en).exists ? $(en) : $(id);
    try {
      // Short visibleTimeout so a hit-testability miss fails fast instead of
      // wasting the tap's default timeout on every retry.
      await f.first.tap(
        settlePolicy: SettlePolicy.noSettle,
        visibleTimeout: const Duration(milliseconds: 500),
      );
      await $.pump(const Duration(seconds: 1));
      return true;
    } catch (_) {
      // Visible but not hit-testable — likely a loading overlay. Burn real
      // wall-clock time via a native call on a selector that can never
      // match, giving the overlay a chance to clear before the next attempt.
      try {
        await $.native.waitUntilVisible(
          Selector(text: '__nav_overlay_wait__'),
          timeout: const Duration(seconds: 3),
        );
      } catch (_) {
        // Expected — dummy selector never matches. Real time consumed.
      }
    }
  }
  return false;
}

/// Brings the app to a known "home" screen at the start of a test, so every
/// testcase/scenario can assume a consistent starting point regardless of
/// where a previous test in the same bundle left off.
///
/// Because the widget tree persists across `patrolTest` blocks in one file
/// (see [_appStarted]), a prior test may have left the app on an inner
/// screen (e.g. a detail or settings screen) where blindly re-running the
/// login flow would be wrong. This recovers gracefully:
///   * app not launched yet        → run the full login flow (boots app too)
///   * already on the home screen  → return immediately
///   * on the login screen         → run the login flow
///   * on some inner screen        → navigate/pop back toward home
Future<void> ensureHome(PatrolIntegrationTester $) async {
  if (!appStarted) {
    await robustLogin($);
    return;
  }
  if (isOnHomeScreen($)) return;
  if (existsEnId($, 'Sign in', 'Masuk')) {
    await robustLogin($);
    return;
  }

  for (var i = 0; i < 8 && !isOnHomeScreen($); i++) {
    // TODO: list the nav destinations your app actually exposes. `Home` is
    // the generic example destination that should always route back toward
    // the home screen from wherever the test happens to be.
    if (existsEnId($, 'Home', 'Beranda')) {
      await tapNav($, 'Home', 'Beranda');
    } else if (existsEnId($, 'Sign in', 'Masuk')) {
      // We were logged out mid-test — recover with a full login instead of
      // trying to pop back from a screen that no longer exists.
      await robustLogin($);
      return;
    } else {
      // Pop the current route back toward home. Prefer Flutter's own
      // pageBack; fall back to a native back press (more reliable for
      // popping pushed routes / dismissing sheets/dialogs).
      try {
        await $.tester.pageBack();
      } catch (_) {
        try {
          await $.native.pressBack();
        } catch (_) {}
      }
      await $.pump(const Duration(seconds: 1));
    }
  }
  // Deliberately do NOT call robustLogin() as a blind fallback here — on an
  // unrecognized inner screen it would tap non-existent login fields and
  // throw. If home was never reached, the caller's own checks will surface
  // that failure with more context than this helper could provide.
}
