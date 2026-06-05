# Patrol Selector Rules (Shared Reference)

This is the single source of truth for Patrol selector strategies across all skills and agents.

## Selector Priority Hierarchy

Before writing any selector, gather context from:

1. **Live UI tree** — `mcp_patrol_mcp_native-tree` for runtime element identifiers/text/states
2. **Screen source code** — Read Flutter screen file for widget keys (`Key('...')`), `Semantics(identifier: '...')`, and stable string constants

Then follow this priority order:

### 1. Text selector (highest priority)

Element has visible, stable text:

```dart
await $('Login').tap();
expect($('Welcome'), findsOneWidget);
```

### 2. Semantic identifier / Key

Element has no visible text but has a Key or Semantics identifier:

```dart
await $(#emailField).tap();
await $(#emailField).enterText('test@example.com');
```

**Flutter Semantics rule:** Always pair `identifier:` with `container: true`:

```dart
Semantics(
  identifier: 'widget_name',
  container: true,
  child: YourWidget(),
)
```

### 3. Widget type + ancestor chaining (when duplicate text exists)

When the same text appears multiple times (e.g., header + button), use ancestor chaining to disambiguate:

```dart
// Finds 'Submit' text inside a Scaffold descendant
await $(Scaffold).$('Submit').tap();

// Or use a more specific parent
await $(#formSection).$('Submit').tap();
```

### 4. Relative positioning / containing finder (last resort before code change)

```dart
// Find 'Submit' that is a descendant of the Terms section
await $('Terms and Conditions').$('Submit').tap();

// Or use containing to filter by descendant widgets
await $(Scrollable).containing($('Submit')).tap();
```

### 5. Add Semantics (when nothing else works)

If no selector works, add `Semantics(identifier: 'widget_key', container: true)` to the Flutter widget, rebuild, and use `$(#widget_key)` selector.

**NEVER use `$.native.tap(Offset(x, y))` with coordinates** — they break across screen sizes/densities.

---

## Accessibility Node Merging

Flutter widgets that render label + value in a `Row` often merge into a single accessibility node:

```
Field label
Field value
```

**Fix in Patrol:** Use the `containing` finder or `waitUntilVisible` with a partial match:

```dart
// WRONG — exact text match may fail on merged node
expect($('Field label'), findsOneWidget);

// CORRECT — use containing to find the parent row
expect($(Row).containing($('Field label')), findsOneWidget);

// Or wait for the merged text
await $('Field label Field value').waitUntilVisible();
```

**Route prefix merging:** Parent containers may emit route + child values in the native tree. Use more specific finders or the `containing` pattern:

```dart
// Use ancestor chaining to scope the search
await $(#sectionContainer).$('Section heading').tap();
```

**Detection:** Use `mcp_patrol_mcp_native-tree` and check the element's `text` or `label` field. If it contains a route prefix or extra content, use ancestor chaining or `containing` to disambiguate.

---

## Selector Decision Tree

```
native-tree element has text content (non-empty)?
  YES → use $('exact_text').tap()
  NO  → has resource-id / key?
        YES → use $(#keyOrId).tap()
        NO  → has a Semantics identifier?
              YES → use $(#semanticsIdentifier).tap()
              NO  → same text appears multiple times?
                    YES → use ancestor chaining: $(Parent).$('text').tap()
                    NO  → add Semantics(identifier: 'name', container: true)
                          rebuild app, then use $(#name).tap()
```

---

## Timeout Conventions

| Situation | Approach |
|-----------|----------|
| Wait for element to appear | `$('text').waitUntilVisible(timeout: Duration(seconds: 5))` |
| Wait for animations to settle | `await $.pumpWidgetAndSettle()` |
| Custom timeout for slow transitions | `$('text').waitUntilVisible(timeout: Duration(seconds: 10))` |

Patrol's `pumpWidgetAndSettle()` handles most animation settling automatically. Use `waitUntilVisible()` for elements that take time to appear (network loads, page transitions).

---

## Rebuild Requirement

After adding `Semantics` or any Flutter code changes:

1. Rebuild the app (`flutter build`)
2. Reinstall on device/emulator
3. Only then re-run Patrol tests

Patrol tests the **compiled APK/IPA**, not source code. Changes are not reflected until rebuild + reinstall.
