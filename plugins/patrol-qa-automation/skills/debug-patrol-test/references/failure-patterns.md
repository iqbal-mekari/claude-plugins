# Patrol Failure Patterns Reference

Catalog of known failure root causes and their fixes. Derived from real debugging sessions.

---

## 1. Coordinate-Based Tap Misses Target

**Error:** Element not found — or tap silently lands on wrong widget.  
**Symptom:** A `$.native.tap(Offset(x, y))` step either does nothing, navigates to wrong screen, or partially works (e.g. opens a dialog but dismisses on wrong button).

**Root cause:** Coordinates are calculated as pixel positions. These shift when:

- Screen resolution or density differs from the device used when the test was written
- A parent layout wraps or expands (e.g. bottom sheet height changes)
- The same flow runs on a different OS version

**Diagnosis:**

1. Run `mcp_patrol_mcp_native-tree` — find the element's bounds
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

**Diagnosis:** Run `mcp_patrol_mcp_native-tree` on both platforms and compare. Look for:

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

**Diagnosis:** Run `mcp_patrol_mcp_native-tree` on iOS — identifiers will be empty for all Flutter-rendered elements unless `Semantics(identifier:)` is present.

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
