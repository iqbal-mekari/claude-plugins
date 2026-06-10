---
name: debug-patrol-selector
description: >
  Diagnose and fix a single failing Patrol selector in Flutter mobile apps.
  Takes a failing code snippet, captures screenshot, inspects native tree,
  diagnoses root cause, tests fixes, and returns a corrected selector or
  Semantics change. Invoke when a Patrol testcase or scenario fails because
  an element cannot be found, a tap does not navigate, or an assertion fails.
  For full testcase rewrites — use patrol-test-creator agent.
  Trigger: fix selector, debug selector, patrol selector fails, element not
  found, fix patrol finder, selector not working.
---

# Debug Patrol Selector Skill

Diagnoses and fixes failing Patrol selectors in Flutter mobile apps.
Receives a failing code snippet and returns a verified fix — either a
corrected finder or a `Semantics` change required in Flutter source code.

Read and follow ALL rules in the skill document before starting:

```
skills/create-patrol-test/SKILL.md
```

## Scope

- Diagnose why a single Patrol finder or assertion fails.
- Test corrected selectors by editing the file and running via
  `patrol test --target <file>`.
- Return a confirmed fix (selector update or Semantics addition).

## Constraints

- DO NOT modify testcase or scenario files directly — only return
  the fix for the caller to apply.
- DO NOT use pixel coordinates as a fix.
- DO NOT retry the same failing selector more than once.
- ONLY inspect the specific failing element — do not rewrite the
  whole testcase.

## Diagnosis Workflow

### Step 1 — Inspect native tree (PRIMARY)

Run the view hierarchy CLI command (see [cli-commands.md](../shared-references/cli-commands.md)) to inspect the native tree.

From the output, check:

- **Exact text content** — does it match the finder string?
- **Key/Semantics identifier** — does the element have one?
- **Duplicate text** — does the same string appear multiple times?
- **Merged nodes** — is a label+value merged into one node?
- **Route prefix** — does the text start with a route path?
- **Element bounds** — is the element on-screen and not obscured?

### Step 2 — Screenshot (LAST RESORT only)

If the hierarchy dump is insufficient (visual layout issues, overlapping elements, ambiguous z-order), capture a screenshot:

```bash
# Android
adb shell screencap -p /sdcard/screenshot.png && adb pull /sdcard/screenshot.png /tmp/screenshot.png
# iOS
xcrun simctl io booted screenshot /tmp/screenshot.png
```

### Step 3 — Read Flutter source (if needed)

If the hierarchy shows no Key/Semantics identifier and text is
ambiguous:

1. Read the Flutter screen file for widget Keys and
   `Semantics(identifier: '...')`.
2. Determine if `Semantics` needs to be added.

### Step 4 — Determine fix

Apply the selector priority hierarchy — see
[shared-references/selector-rules.md](../shared-references/selector-rules.md)
for the full decision tree:

1. **Text finder** — `$('Login')` — use if text matches exactly
2. **Key finder** — `$(#field)` — use if Key/Semantics identifier exists
3. **Ancestor chaining** — `$(Scaffold).$('Submit')` — use when text
   appears multiple times
4. **Containing finder** — `$(Row).containing($('label'))` — use when
   text is part of a merged node
5. **Type finder** — `$(ElevatedButton)` — use when text is unstable
6. **Add `Semantics(identifier: '...', container: true)`** — when no
   other selector is stable; never use coordinates

### Step 5 — Test the fix

Edit the Dart file with the corrected finder, then call
`patrol test --target <file>` to confirm the fix executes successfully on the
live device.

If the test fails, try the next selector strategy from Step 4.
Do not retry the same approach twice.

### Step 6 — Report

Return the fix without applying it to the caller's file (the caller
will apply it).

## Output

Return a structured fix report:

- **Root cause**: one-line diagnosis (e.g., "duplicate text — title
  and button both show 'Submit'")
- **Failing selector**: the original Dart code snippet
- **Fixed selector**: the corrected Dart snippet
- **Test result**: confirmed working / not confirmed
- **Semantics change required**: yes/no — if yes, include the exact
  `Semantics(identifier: '...', container: true, child: ...)` block
  to add to the Flutter widget
