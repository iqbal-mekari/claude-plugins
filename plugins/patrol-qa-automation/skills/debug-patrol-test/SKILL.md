---
name: debug-patrol-test
description: "Debug failing Patrol UI test files for Android/iOS mobile apps. Use when a Patrol test fails, an element is not found, a tap does not navigate, an assertion fails, or a selector breaks. Triggers: 'patrol fails', 'element not found', 'test failed', 'debug patrol', 'patrol error', 'fix patrol test', 'patrol assertion failed'."
argument-hint: 'Provide the path to the failing Dart test file and the error message if available.'
---

# Debug Patrol Test

Diagnose and fix failing Patrol test files for Android/iOS mobile apps. Follows a **read → run → native-tree → fix → re-run** loop. Screenshots are a last resort when hierarchy inspection is insufficient.

## When to Use

- A Patrol test exits with a failure
- `Element not found` error in a testcase or scenario
- A tap doesn't navigate to the expected screen
- An `expect()` assertion fails despite the element appearing on screen
- A selector worked on one platform (Android/iOS) but not the other
- A test passes locally but fails on CI

## Prerequisites

- Patrol CLI and platform tools are available (`patrol devices` shows a connected device)
- The Dart test file path is known

---

## Debugging Workflow

### Phase 1 — Context Gathering (do all in parallel)

1. **Read the failing Dart test file** — understand the full test: imports, helper calls, selectors, assertions
2. **Read all imported helper files** — understand the complete execution path
3. **Check device status** — confirm the device is connected via `patrol devices`

### Phase 2 — Reproduce the Failure

4. **Run the test** via CLI:

   ```bash
   patrol test --target patrol_test/testcases/login/verify_login_form_visible.dart
   ```

   Capture the exact error: which assertion/action failed and the error message.

### Phase 3 — Diagnose

5. **Inspect the native view hierarchy FIRST** (PRIMARY debugging tool):

   ```bash
   # Android
   adb shell uiautomator dump /sdcard/window_dump.xml && adb pull /sdcard/window_dump.xml /tmp/window_dump.xml && cat /tmp/window_dump.xml
   # iOS
   idb ui describe-all
   ```

   See [cli-commands.md](../shared-references/cli-commands.md) for full commands.

   Look for:
   - The actual `text` or `label` value of the target element (never assume from screenshot)
   - Whether a dialog/overlay is blocking the target element
   - Whether the element exists but has different text than expected (hint text, concatenated values)
   - The `identifier` or `resourceName` if no stable text is available

6. **If hierarchy is insufficient, take a screenshot** (LAST RESORT):

   ```bash
   # Android
   adb shell screencap -p /sdcard/screenshot.png && adb pull /sdcard/screenshot.png /tmp/screenshot.png
   # iOS
   xcrun simctl io booted screenshot /tmp/screenshot.png
   ```

7. **Identify the root cause** using the [Common Failure Patterns](./references/failure-patterns.md) table.

### Phase 4 — Apply Fix and Verify

8. **Edit the Dart test file** with the proposed fix.

9. **Run the test again** to validate:
   ```bash
   patrol test --target patrol_test/testcases/login/verify_login_form_visible.dart
   ```

10. **Check pass/fail** via `patrol devices`.

11. If still failing, inspect the view hierarchy again, then repeat from Phase 3.

### Phase 5 — Record Unrecognized Failure Patterns

After a fix is confirmed, check if the root cause matches any entry in [failure-patterns.md](./references/failure-patterns.md).

**If the root cause is NOT already documented:**

1. Append a new entry to `references/failure-patterns.md` following the existing format:
   - **Error** — the exact Patrol error message or symptom
   - **Root cause** — why it happened
   - **Diagnosis** — how to identify it via screenshot/native-tree
   - **Fix** — the corrected Dart code with before/after example
2. Assign the next sequential pattern number.
3. Briefly mention the new entry in your final reply to the user.

This ensures the knowledge base grows with every debugging session and future failures are resolved faster.

### Exit Condition

Stop and report findings if:

- The same step fails 3 times with different attempted fixes
- The fix requires a Flutter code change (add `Semantics`, rebuild APK) — report exactly what change is needed
- The failure is in an external system (network, test account, backend data)

---

## Common Failure Patterns

See [failure-patterns.md](./references/failure-patterns.md) for the full reference table.

**Quick reference (most frequent):**

| Error                                        | Root Cause                                      | Fix                                                             |
| -------------------------------------------- | ----------------------------------------------- | --------------------------------------------------------------- |
| `findsNothing` for text element              | Exact match fails on partial/merged text        | Use `containing` finder or match full merged text               |
| `findsNothing` for text element              | Dialog/overlay blocking the element             | Dismiss the dialog first with `if (await $('Allow').exists)`    |
| `findsNothing` for text element              | Hint text includes character counter            | Use `Key`-based selector or `containing`                        |
| Tap does nothing / navigates wrong screen    | Duplicate text label (header + button)          | Use ancestor chaining: `$(Scaffold).$('Submit').tap()`          |
| Element found on Android but not iOS         | Different accessibility tree structure          | Use `native-tree` to inspect platform-specific identifiers      |
| `expect()` fails despite text on screen      | Label+value merged into one accessibility node  | Use `containing` finder or match full merged text               |
| Flow passes but wrong screen                 | Navigation succeeded but assertion is too loose | Tighten assertion to screen-specific element                    |

---

## Selector Decision Tree

For the full selector priority hierarchy, decision tree, and accessibility node merging rules, see [shared-references/selector-rules.md](../shared-references/selector-rules.md).

**Quick reference:**

```
native-tree element has text content (non-empty)?
  YES → use $('exact_text').tap()
  NO  → has resource-id / key?
        YES → use $(#keyOrId).tap()
        NO  → has a Semantics identifier?
              YES → use $(#semanticsIdentifier).tap()
              NO  → same text appears multiple times?
                    YES → use ancestor chaining: $(Parent).$('text').tap()
                    NO  → add Semantics(identifier: 'name', container: true) to Flutter widget
                          rebuild app, then use $(#name).tap()
```

**Never use `$.native.tap(Offset(x, y))`** unless absolutely no other option exists. If a coordinate-based tap exists in the file and is failing, replace it first.

---

## Key Rules (from create-patrol-test skill)

- **Patrol CLI cannot run inline Dart code** — Always write the complete test file, then run it. Use the write-run-observe-edit loop.
- **`$('text')` matches by text content** — Use `Key`-based selectors for elements without stable text.
- **Never use coordinates** — `$.native.tap(Offset(x,y))` breaks across screen sizes/densities.
- **Rebuild required after Flutter code changes** — `Semantics` additions are not reflected until you rebuild and reinstall the app.
- **Use `pumpWidgetAndSettle()`** — Let animations settle after navigation before asserting.

---

## Tool Sequence (copy-paste reference)

```
1. patrol devices                                    → check connected device
2. patrol test --target <test_file>                  → run failing test, get error
3. adb shell uiautomator dump / idb ui describe-all → get actual text/identifier values (PRIMARY)
4. adb shell screencap / xcrun simctl screenshot     → see where test stopped (LAST RESORT)
5. edit the Dart test file with fix
6. patrol test --target <test_file>                  → re-run to verify fix
7. patrol devices                                    → check pass/fail
8. append to failure-patterns.md                     → if root cause was new
```
