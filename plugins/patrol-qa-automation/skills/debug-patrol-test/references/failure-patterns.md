# Patrol Failure Patterns Reference

Catalog of known failure root causes and their fixes. Derived from real debugging sessions.

**This is a living knowledge base.** After debugging a new failure, append a new numbered pattern here — continue the existing sequence, never renumber or edit prior entries — so future debugging sessions benefit from it.

---

## 1. Coordinate-Based Tap Misses Target

**Error:** Element not found — or tap silently lands on wrong widget.  
**Symptom:** A `$.native.tap(Offset(x, y))` step either does nothing, navigates to wrong screen, or partially works (e.g. opens a dialog but dismisses on wrong button).

**Root cause:** Coordinates are calculated as pixel positions. These shift when:

- Screen resolution or density differs from the device used when the test was written
- A parent layout wraps or expands (e.g. bottom sheet height changes)
- The same flow runs on a different OS version

**Diagnosis:**

1. Run the view hierarchy dump command (see [cli-commands.md](../../shared-references/cli-commands.md)) — find the element's bounds
2. Compare to the `Offset(x, y)` — check if the tap position matches the element center
3. Off by more than ~10px → replace with a text/key selector

**Fix:** Replace coordinate tap with a text or key-based selector:

```dart
// Before (fragile)
await $.native.tap(Offset(350, 680));

// After (stable)
await $('Save').tap();
```

---

## 2. Exact Text Match Fails on Merged Accessibility Node

**Error:** `findsNothing` for a text element that IS visible on screen.  
**Symptom:** The text IS visible on screen (confirmed by screenshot) but `$('Field label')` still fails.

**Root cause:** Flutter `Row` widgets that combine a label + value into a single node produce a merged text:

```
Field label
Field value
```

Patrol's `$('Field label')` does an exact text match — it won't match `"Field label\nField value"`.

**Diagnosis:** In the native-tree, find the element and check its `text` or `label` value. If it contains the field value appended, this is the cause.

**Fix:**

```dart
// Wrong — exact match fails
expect($('Field label'), findsOneWidget);

// Correct — use containing finder
expect($(Row).containing($('Field label')), findsOneWidget);

// Or match the full merged text
await $('Field label Field value').waitUntilVisible();
```

---

## 3. Route Prefix in Parent Container Node

**Error:** Text match fails even when the element is visible.  
**Symptom:** Same as pattern 2 but even `$('Label')` doesn't work.

**Root cause:** Some parent containers emit text that starts with the screen's route path:

```
/feature/detail
Section heading
Section value
```

Because the text STARTS with the route (not the label), `$('Section heading')` still fails.

**Diagnosis:** In the native-tree, look at the parent container's text. If it starts with a `/route` path, this is the cause.

**Fix:** Use ancestor chaining to scope the search:

```dart
// Wrong — text includes route prefix
expect($('Section heading'), findsOneWidget);

// Correct — scope with ancestor chaining
await $(#sectionContainer).$('Section heading').tap();
```

---

## 4. Hint Text Contains Character Counter

**Error:** `findsNothing` for a text input field.  
**Symptom:** An input field is visible but `$('Reason')` fails.

**Root cause:** Android `EditText` hint text often includes a character counter appended by the framework: `"Reason\n0/200"`. Patrol's text match `'Reason'` won't match `"Reason\n0/200"`.

**Diagnosis:** In the native-tree, look for the field's hint value. If it's `"Label\n0/N"`, this is the cause.

**Fix:**

```dart
// Wrong — exact match fails
await $('Reason').tap();

// Correct — use Key-based selector
await $(#reasonField).tap();

// Or use containing
await $(TextField).containing($('Reason')).tap();
```

---

## 5. Dialog Blocking Target Element

**Error:** `findsNothing` for an element that IS in the view hierarchy.  
**Symptom:** The target element IS in the view hierarchy but a modal/bottom sheet is on top.

**Root cause:** A previous step (e.g. a time/date picker) was not properly dismissed. The dialog remains open and intercepts all touches, making elements behind it effectively unreachable.

**Diagnosis:**

1. Take a screenshot — if a dialog/overlay covers the screen, this is the cause
2. Check the native-tree — the dialog's elements will appear at the TOP of the tree

**Fix:** Ensure the dismissal step actually works before proceeding:

```dart
// If the dismiss button is a known text
await $('Save').tap(); // verify via native-tree first

// If the dialog may or may not appear (conditional)
if (await $('Select time').exists) {
  await $('Save').tap();
}
```

---

## 6. Duplicate Text Label (Header + Button)

**Error:** The wrong element gets tapped (e.g. the screen title instead of the CTA button).  
**Symptom:** Test taps a label in the app bar when it should tap a button further down.

**Root cause:** Many screens show the same text in both the top bar title AND a button. `$('Submit')` always picks the first match (top of screen = the title).

**Diagnosis:** In the native-tree, count how many elements share the same text. More than one → use ancestor chaining.

**Fix:**

```dart
// Wrong — taps the title
await $('Submit').tap();

// Correct — taps the button using ancestor chaining
await $(Scaffold).$('Submit').tap();

// Or use a Key if available
await $(#submitButton).tap();
```

---

## 7. Missing Semantics on Flutter Widget

**Error:** No identifier, no text, nothing stable to select.  
**Symptom:** The element exists visually but has nothing stable to select.

**Root cause:** The Flutter widget has no `Semantics` wrapper and no inherent text.

**Fix:** Add `Semantics` to the Flutter source:

```dart
Semantics(
  identifier: 'widget_name',   // Maps to #widget_name in Patrol
  container: true,              // Always required
  child: YourWidget(),
)
```

Then use in Patrol:

```dart
await $(#widget_name).tap();
```

**Important:** Rebuild and reinstall the app after any Flutter code change. Patrol tests the compiled binary.

---

## 8. Time Picker / Date Picker Save Button Not Found

**Error:** Coordinate tap on time picker Save button does nothing or misses.  
**Root cause:** The Save button inside a custom picker component renders inside a bottom sheet. Its position varies by screen size.

**Fix:** Use the button's text instead of coordinates:

```dart
// Before (fragile)
await $.native.tap(Offset(350, 680));

// After (stable — Save button has text "Save" in native-tree)
await $('Save').tap();
```

---

## iOS-Specific Patterns

### 9. Element Found on Android but Not on iOS (Different Accessibility Tree)

**Error:** `findsNothing` on iOS for a selector that works on Android.  
**Root cause:** Flutter renders differently on iOS vs Android. The accessibility tree structure, text values, and node grouping can differ between platforms even for the same Flutter widget.

**Diagnosis:** Run the view hierarchy dump on both platforms and compare (see [cli-commands.md](../../shared-references/cli-commands.md)). Look for:

- Different text values (e.g. Android: `"Submit"` / iOS: `"Submit button"`)
- Different node grouping (merged vs split nodes)
- Elements present in one tree but absent in the other

**Fix:** Use platform-conditional logic when the selector must differ:

```dart
// Use Key-based selectors for cross-platform consistency
await $(#submitButton).tap();

// Or add a shared Semantics widget
Semantics(
  identifier: 'submit_button',
  container: true,
  child: YourWidget(),
)
```

---

### 10. `resource-id` Doesn't Exist on iOS

**Error:** `findsNothing` when using `Key` selector on iOS.  
**Root cause:** `resource-id` is an Android-only attribute. On iOS, the equivalent is `accessibilityIdentifier` — which is only set when `Semantics(identifier: '...')` is applied to the Flutter widget.

**Diagnosis:** Run the view hierarchy dump on iOS (see [cli-commands.md](../../shared-references/cli-commands.md)) — identifiers will be empty for all Flutter-rendered elements unless `Semantics(identifier:)` is present.

**Fix:** If both platforms need key-based selectors, the Flutter widget MUST have:

```dart
Semantics(
  identifier: 'my_widget',  // accessibilityIdentifier on iOS, resource-id on Android
  container: true,
  child: YourWidget(),
)
```

Rebuild and reinstall after adding `Semantics`.

---

### 11. iOS Keyboard Blocks Element After Text Input

**Error:** `findsNothing` on the next step after `enterText`.  
**Symptom:** Works on Android, fails on iOS. The software keyboard stays up and covers the target element.

**Root cause:** On iOS simulators, the software keyboard does not auto-dismiss after `enterText`. Elements below the fold become unreachable while the keyboard is visible.

**Fix:** Dismiss the keyboard explicitly before the next interaction:

```dart
await $(#emailField).enterText('test@example.com');
await $.native.pressBack(); // Dismiss iOS soft keyboard
await $('Next').tap();
```

---

### 12. iOS Secure Text Field Not Receiving Input

**Error:** `enterText` silently does nothing on a password field.  
**Root cause:** iOS secure text fields sometimes lose focus between tap and `enterText`, especially if an animation is in progress.

**Fix:** Add a wait before inputting, and ensure the field is explicitly focused:

```dart
await $(#passwordField).tap();
await $.pumpWidgetAndSettle(); // Wait for animations
await $(#passwordField).enterText(password);
```

---

### 13. iOS Back Navigation Fails

**Error:** Test gets stuck on a screen — back button does nothing.  
**Root cause:** iOS uses a swipe-back gesture for navigation, not a hardware back button.

**Fix:** Use platform-specific back navigation:

```dart
// Cross-platform back
await $.native.pressBack();

// Or tap the explicit back button element by its text
await $('Back').tap();
```

---

### 14. Clean State Required for iOS (Keychain Persistence)

**Symptom:** iOS scenario picks up leftover auth tokens from a previous run. Login screen is skipped unexpectedly, or the wrong account is active.  
**Root cause:** iOS stores auth tokens in the Keychain, which persists across app restarts. Android uses SharedPreferences/databases which are wiped on reinstall.

**Fix:** Use Patrol's `--full-isolation` flag or clear state in `setUp()`:

```dart
// In test setup, use patrol's full isolation
// Run with: patrol test --full-isolation

// Or clear state programmatically in setUp()
setUp(() async {
  // Clear app data before each test
});
```

---

### 15. iOS Simulator Animation Timing

**Symptom:** `waitUntilVisible` timeouts on iOS even when the screen loads quickly on Android.  
**Root cause:** iOS simulators may not fully suppress all spring/transition animations in Flutter.

**Fix:** Increase `waitUntilVisible` timeouts for iOS-sensitive transitions:

```dart
// Use longer timeout for iOS-sensitive transitions
await $('Home Screen').waitUntilVisible(timeout: Duration(seconds: 10));

// Or use pumpWidgetAndSettle to wait for animations
await $.pumpWidgetAndSettle();
```

If animations are still causing flakiness, add explicit waits before the affected actions.

---

## 16. `pumpAndSettle()` Never Settles After WebView / Streaming / Continuous Animation

**Error:**
```
TimeoutException after 0:00:10.000000: Test timed out after 10 seconds.
```

**Symptom:** A step calls `await $.pumpAndSettle();` right after opening a WebView, kicking off a streaming response, or triggering a looping animation (spinner/shimmer), and the test hangs until an external timeout kills it.

**Root cause:** `pumpAndSettle()` keeps pumping frames until the scheduler reports nothing left to render. WebViews, streaming content, and continuous/looping animations keep scheduling new frames indefinitely, so that "settled" condition never arrives.

**Diagnosis:** Check what was triggered immediately before the hang — a WebView navigation, a streaming/chat-style response, or a spinner/shimmer loader. Any of these can keep the scheduler busy forever.

**Fix:** Replace the bare `pumpAndSettle()` with a bounded `pump(Duration)` loop that has an explicit exit condition:

```dart
// Before (hangs forever — scheduler never reports "settled")
await $.pumpAndSettle();

// After (bounded loop with an explicit exit condition)
var done = false;
for (var i = 0; i < 20 && !done; i++) {
  await $.pump(const Duration(milliseconds: 500));
  done = $('Expected result').exists;
}
```

See [`../../shared-references/wait-strategies.md`](../../shared-references/wait-strategies.md) for the real-vs-simulated clock distinction.

---

## 17. `$.pump(Duration)` Burns Simulated Time, Not Real Time

**Error:**
```
Exception: Expected screen did not appear within 20s
```

**Symptom:** A loop of `await $.pump(const Duration(seconds: 1));` runs its full iteration count in well under a second of real time, and a condition gated on a network call or BLoC logic kicked off in `initState` never becomes true.

**Root cause:** `$.pump(Duration)` advances the Flutter test binding's fake scheduler clock only — it does not block for that duration of real wall-clock time. A real HTTP round-trip or any async I/O started in `initState` needs actual wall-clock time to complete; pumping the fake clock never gives it that time.

**Diagnosis:** Confirm the awaited condition depends on a real network/async response (not just a widget rebuild from already-resolved state). If the same test passes standalone (where incidental real time elapses during app bootstrap) but fails when chained after other steps, this is very likely the cause.

**Fix:** Use a helper that burns real wall-clock time between checks instead of a fake-clock pump loop:

```dart
// Before (fake-clock loop — never gives the network call time to resolve)
for (var i = 0; i < 20; i++) {
  await $.pump(const Duration(seconds: 1));
  if ($('Expected result').exists) break;
}

// After (burns real wall-clock time via a native dummy-selector wait)
final ready = await pumpUntilReal(
  $,
  () => $('Expected result').exists,
  maxSeconds: 20,
);
```

See [`../../shared-references/wait-strategies.md`](../../shared-references/wait-strategies.md) for the `pumpUntil` vs `pumpUntilReal` decision table and the `pumpUntilReal` implementation.

---

## 18. Native and Flutter Selectors Target the Wrong Rendering Surface

**Error:**
```
NativeAutomatorException: Could not find element with selector ...
```

**Symptom:** A `$.native.*` selector returns zero matches for a widget that is clearly visible and rendered by Flutter — or, conversely, a Flutter `$(...)` selector cannot find an element that lives in a WebView or a purely native dialog.

**Root cause:** Flutter widgets are painted by the Flutter engine onto a single native surface — they are not exposed as individual native view nodes, so native selectors (`$.native.*`, which query the platform accessibility tree) can't see them individually. The reverse is also true: pure-native elements (system dialogs, permission prompts) and WebView HTML content sit outside the Flutter widget tree, so Flutter finders (`$(...)`) can't see them either.

**Diagnosis:** Dump the native view hierarchy (see [cli-commands.md](../../shared-references/cli-commands.md)). If the target text appears only as part of one large Flutter surface node (not as its own labeled node), it's Flutter-rendered — use a Flutter selector. If it's absent from the Flutter widget tree but present in the native tree, it's native/WebView content — use a native selector.

**Fix:** Pick the selector API that matches the element's actual rendering layer:

```dart
// Wrong — Flutter widget queried via native selector, finds nothing
await $.native.tap(Selector(text: 'Submit'));

// Correct — Flutter widget via Flutter selector
await $('Submit').tap();

// Correct — native dialog / WebView content via native selector
await $.native.tap(Selector(text: 'Allow'));
```

---

## 19. `$('text')` Only Matches `Text` Widgets — Not `Semantics.label` or `Semantics.identifier`

**Error:**
```
// Returns 0 elements even though Semantics(label: 'App logo') is on screen
$('App logo').exists  // false
```

**Symptom:** A widget carries a `Semantics(label: '...')` or `Semantics(identifier: '...')` wrapper — often around a non-text child like an `Icon` or `Image` — but `$('the label text')` always reports no match, even though the element is visibly present.

**Root cause:** Patrol's `$(matching)` converts a `String` argument into `find.text(matching, findRichText: true)`, which only searches for `Text`/`RichText` widgets in the tree. It never queries the semantics tree, so it cannot see a `Semantics.label` or `Semantics.identifier` value on a widget with no `Text` descendant.

**Diagnosis:** Inspect the widget's source. If it's wrapped in `Semantics(label: ...)` or `Semantics(identifier: ...)` around a non-`Text` child (icon, image, custom paint), `$('label value').exists` will always be `false` regardless of what's visually on screen.

**Fix:** Match on the semantics tree directly instead of the text-widget tree:

```dart
// Wrong — searches the Text widget tree, misses Semantics values entirely
$('App logo').exists

// Correct — Semantics.label: query the semantics tree
find.bySemanticsLabel('App logo').evaluate().isNotEmpty

// Correct — Semantics.identifier: match via widget predicate
find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.identifier == 'confirm_button',
).evaluate().isNotEmpty
```

Note the two APIs are not interchangeable: `find.bySemanticsLabel` only matches `Semantics.label`, and `find.byWidgetPredicate` on `identifier` only matches `Semantics.identifier`. Neither substitutes for the other.

---

## 20. `$.tester.tap()` Queues the Gesture but Never Flushes It

**Error:** No exception is thrown, but the tapped widget's callback (`onTap`/`onPressed`) never fires — navigation or state change never happens.

**Symptom:** `await $.tester.tap(someFinder);` completes without error, yet the app remains on the same screen as if nothing happened.

**Root cause:** `$.tester.tap()` (the raw `WidgetTester.tap()`) only enqueues the tap gesture in the test engine's event queue — it does not pump a frame afterward. Without a subsequent pump, Flutter never processes the queued gesture, so the widget's tap callback is never invoked.

**Diagnosis:** Check the native tree / screenshot immediately after the tap call — the screen is unchanged, and no subsequent state transition occurred, even though the tap itself didn't throw.

**Fix:** Prefer Patrol's own finder `.tap()`, which pumps automatically after tapping:

```dart
// Before (broken — tap queued but never flushed)
await $.tester.tap(someFinder);
// navigation never happens

// After (fixed — Patrol's tap() pumps automatically)
await $(someFinder).tap();
```

If `$.tester.tap()` must be used directly, follow it with an explicit pump: `await $.tester.tap(someFinder); await $.pump();`.

---

## 21. `.tap()` on a Zero-Match Finder Hangs Forever

**Error:** Test run stalls indefinitely at a single step — no timeout, no exception, no further progress.

**Symptom:** A step like `await $('Optional chip').tap();` never returns, freezing the entire test run. Killing the process is the only way to recover.

**Root cause:** Patrol's `PatrolFinder.tap()` internally calls `waitUntilVisible()` before tapping, and `waitUntilVisible()` polls with no default timeout while it waits for at least one match. If the finder has zero matches — because the element is conditionally rendered, data-dependent, or simply absent — the call blocks forever.

**Diagnosis:** Check whether the target element is optional or data-dependent. Confirm via the native tree that the element is genuinely absent, not just slow to render.

**Fix:** Guard any `.tap()` with an existence check first — skipping is always preferable to hanging:

```dart
// Before (broken — hangs forever if the finder never matches)
await $('Optional chip').tap();

// After (fixed — guard with an existence check before tapping)
Future<bool> safeTap(PatrolIntegrationTester $, Finder finder) async {
  if (finder.evaluate().isEmpty) return false;
  try {
    await $(finder).first.tap(settlePolicy: SettlePolicy.noSettle);
    return true;
  } catch (_) {
    return false;
  }
}

await safeTap($, find.text('Optional chip'));
```

**General rule:** Never call `.tap()` on a finder without first checking `finder.evaluate().isNotEmpty` (or `.exists`) — a `safeTap`-style helper should be the default way any test taps a conditionally-present element.

---

## 22. Unconditional `pressBack()` Backgrounds the App and Drops the Test Session

**Error:** Test hangs indefinitely mid-run; no further steps are logged after a back-press call.

**Symptom:** `await $.native.pressBack();` is called when the app is already on its top-level/home screen (no dialog, sheet, or pushed route to dismiss). The app backgrounds and the test never recovers.

**Root cause:** The OS interprets a back press with no route or overlay to pop as a request to leave the app — the same as pressing the home button. The test automation channel runs inside the app process; once the app is backgrounded, that channel is suspended, and the test client hangs waiting for a response that will never arrive.

**Diagnosis:** Check whether a back-press call fired without first confirming a dismissible dialog, sheet, or pushed route was actually present. If the app was already on its home/shell screen at the time, this is the cause.

**Fix:** Never fire `pressBack()` unconditionally. Prefer in-app pop navigation (a visible "Back"/close button) where available, and gate any native back-press behind a check that something dismissible is actually on top — with a bounded loop, not an unbounded one:

```dart
// Before (broken — unconditional back press backgrounds the app when already home)
await $.native.pressBack();

// After (fixed — only back-press while NOT on the home/shell screen, bounded loop)
for (var i = 0; i < 5 && !isOnHomeScreen($); i++) {
  try {
    await $.native.pressBack();
  } catch (_) {}
  await $.pump(const Duration(seconds: 1));
}
```

---

## 23. Home/Shell Detector False-Positives While a Dialog or Route Is Actually on Top

**Error:** A downstream step fails (e.g. "expected element not found") even though the test believes it already reached the home screen.

**Symptom:** A helper like `isOnHomeScreen($)` returns `true`, but a screenshot at that exact moment shows a full-screen route or a modal dialog covering the home screen.

**Root cause:** A "home/shell" detector typically checks for a persistent widget — e.g. a nav-bar logo or a Semantics identifier that lives in the shell scaffold. Persistent shell widgets often remain mounted in the widget tree even when a `ModalBarrier`, dialog, or a full-screen pushed route renders on top of them. Tree-presence is not the same as "currently the active/topmost screen."

**Diagnosis:** Compare `isOnHomeScreen($)` against a screenshot / native-tree dump taken at the same moment. If the detector reports `true` while a dialog or route is clearly on top, the detector is checking the wrong signal.

**Fix:** Strengthen the detector to also assert that no barrier, dialog, or extra route is stacked above the shell before declaring success:

```dart
// Before (false-positive — only checks that the shell widget is mounted)
bool isOnHomeScreen(PatrolIntegrationTester $) =>
    find.bySemanticsLabel('App logo').evaluate().isNotEmpty;

// After (fixed — also confirms nothing is stacked on top of the shell)
bool isOnHomeScreen(PatrolIntegrationTester $) =>
    find.bySemanticsLabel('App logo').evaluate().isNotEmpty &&
    find.byType(ModalBarrier).evaluate().isEmpty &&
    find.byType(Dialog).evaluate().isEmpty;
```

**General rule:** Any "are we home?" helper must check for the ABSENCE of overlays/dialogs/pushed routes, not just the PRESENCE of a persistent shell widget.

---

## 24. Stale Cached Widget Index Causes a `RangeError` After a Rebuild

**Error:**
```
RangeError (index): Index out of range: index should be less than 12: 15
```

**Symptom:** A loop captures `find.byType(SomeWidget).evaluate().length` once, then later indexes into the same finder with `.at(count - 1)` after the widget tree has rebuilt (e.g. a list re-rendered with a different item count, or the loop navigated away and back).

**Root cause:** The captured `count` (or any cached element index) reflects the tree at one point in time. If the tree rebuilds — new items loaded, a navigation happened, a filter changed the list — the live element count differs, and indexing with the stale value either throws `RangeError` or silently targets the wrong widget.

**Diagnosis:** Check whether a rebuild-triggering action (navigation, list reload, filter change) happens between when the count/index was captured and when it's used to index into the finder.

**Fix:** Re-evaluate the live element count on every use — never cache an index across a rebuild:

```dart
// Before (broken — stale count causes RangeError after tree rebuild)
final count = find.byType(SomeWidget).evaluate().length;
for (final idx in <int>[0, 1, count - 1]) {
  await $.tester.tap(find.byType(SomeWidget).at(idx));
  // ... navigate and come back, tree rebuilds
}

// After (fixed — re-evaluate count on every iteration)
for (final candidateOffset in <int>[0, 1, -1]) {
  final currentCount = find.byType(SomeWidget).evaluate().length;
  final idx = candidateOffset >= 0
      ? candidateOffset
      : currentCount + candidateOffset; // -1 => last element
  if (idx < 0 || idx >= currentCount) continue;
  await $.tester.tap(find.byType(SomeWidget).at(idx));
  // ... navigate and come back; currentCount is re-evaluated next iteration
}
```

---

## 25. `Scrollable.ensureVisible` Hangs on an Offstage `IndexedStack` Child

**Error:** Test stalls indefinitely mid-step; no exception thrown, step counter frozen.

**Symptom:** A scroll-then-tap helper calls `Scrollable.ensureVisible(element)` on a widget that belongs to an inactive tab/page of an `IndexedStack` (or similar lazy-widget container), and the call never completes.

**Root cause:** `IndexedStack` wraps each non-active child in `Offstage(offstage: true)` and `TickerMode(enabled: false)`. `Scrollable.ensureVisible` animates the scroll position using an `AnimationController`, whose `Ticker` is disabled by `TickerMode` on an offstage subtree. The animation never advances, so the `Future` returned by `ensureVisible` never resolves — even though `find.text(...)` can still locate the widget (it exists in the tree; it just isn't mounted/visible).

**Diagnosis:** Confirm the target widget belongs to a non-active `IndexedStack` page (or an otherwise offstage subtree) at the time `ensureVisible` was called — often because a prior navigation didn't actually land on the expected tab.

**Fix:** Wrap `ensureVisible` in a bounded timeout with a no-op fallback, so the call never blocks indefinitely on an offstage element:

```dart
// Before (broken — hangs indefinitely on an offstage element)
await Scrollable.ensureVisible(
  elements.first,
  duration: const Duration(milliseconds: 400),
);

// After (fixed — bounded wait, no-op fallback on timeout)
await Scrollable.ensureVisible(
  elements.first,
  duration: const Duration(milliseconds: 400),
).timeout(const Duration(seconds: 2), onTimeout: () {});
```

**General rule:** Before scrolling to an element found via a tree-wide finder (which does not distinguish offstage from onstage), confirm the active tab/page actually matches where the element should live.

---

## 26. A Mid-Flight Interruption Dialog Blocks the Wait for the Expected Next Screen

**Error:** A `pumpUntil`-style wait times out waiting for the expected success screen, even though the triggering action (e.g. a submit tap) completed without error.

**Symptom:** After submitting a form or completing an action, an unexpected dialog appears (a confirmation prompt, an error dialog, or a forced update/notice dialog) instead of — or in front of — the expected next screen. The wait loop only checks for the expected screen's indicators, so it never notices the interruption and simply exhausts its timeout.

**Root cause:** The server or app can inject a dialog between the triggering action and the expected screen render — for example, a stale-state conflict response, a rate-limit notice, or a forced app-update prompt. If the wait condition checks only for success-screen indicators, it has no path to recognize and dismiss this interruption; it waits out its full duration and fails, often leaving the app in a state that also breaks the next test.

**Diagnosis:** Compare a passing standalone run against a failing composed/suite run — interruption dialogs are frequently timing- or state-dependent and appear only when prior steps changed server-side state. Screenshot or dump the native tree at the moment of timeout to confirm an unexpected dialog is on top.

**Fix:** Extend the wait loop to also detect and dismiss known interruption dialogs on each iteration, not just check for the expected screen:

```dart
// Before (broken — blocks for the full timeout if an interruption dialog appears)
final onSuccess = await pumpUntil(
  $,
  () => $('Success').exists,
  maxSeconds: 40,
);

// After (fixed — detects and dismisses a known interruption dialog mid-flight)
var onSuccess = false;
for (var i = 0; i < 40; i++) {
  if ($('Success').exists) {
    onSuccess = true;
    break;
  }
  // Known interruption: a conflict/notice dialog can appear between submit and success.
  if ($('Try again').exists) {
    await $('Try again').tap();
    await $.pump(const Duration(seconds: 2));
    continue;
  }
  await $.pump(const Duration(seconds: 1));
}
```

**General rule:** Any wait for a post-submit success screen should also poll for and handle known blocking dialogs the app/server may inject mid-flight — not assume the only two states are "still loading" and "success."
