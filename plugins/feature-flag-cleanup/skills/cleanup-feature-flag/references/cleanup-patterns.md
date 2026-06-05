# Feature Flag Cleanup — Transformation Patterns Reference

> Reference document for the [Feature Flag Cleanup Skill](../SKILL.md). Contains detailed code transformation examples for each pattern the AI may encounter.

---

## Core Rule

| Action | Keep | Remove |
|--------|------|--------|
| **Graduate** | `true`/enabled branch | `false`/disabled branch |
| **Drop** | `false`/disabled/fallback branch | `true`/enabled branch |

---

## Pattern 1: Simple if/else

```dart
// BEFORE
if (featureFlag.isEnabled(FlagConstants.xpmTravel)) {
  showNewTravelUI();    // enabled branch
} else {
  showLegacyTravelUI(); // disabled branch
}

// AFTER (graduate): keep enabled branch
showNewTravelUI();

// AFTER (drop): keep disabled branch
showLegacyTravelUI();
```

---

## Pattern 2: No-else block (if-only)

```dart
// BEFORE
if (featureFlag.isEnabled(FlagConstants.xpmTravel)) {
  initTravelModule();
  registerTravelRoutes();
}
// (no else branch)

// AFTER (graduate): unwrap — keep the body, remove the if
initTravelModule();
registerTravelRoutes();

// AFTER (drop): delete entire block — code disappears completely
```

---

## Pattern 3: Collection-if in Flutter widget trees

```dart
// BEFORE
Column(
  children: [
    HeaderWidget(),
    if (featureFlag.isEnabled(FlagConstants.xpmTravel))
      TravelCard(),
    FooterWidget(),
  ],
)

// AFTER (graduate): remove the if condition, keep the widget
Column(
  children: [
    HeaderWidget(),
    TravelCard(),
    FooterWidget(),
  ],
)

// AFTER (drop): remove both the if AND the widget
Column(
  children: [
    HeaderWidget(),
    FooterWidget(),
  ],
)
```

---

## Pattern 4: Flag wrapping entire class/file

```dart
// Scenario: An entire file/class exists ONLY for the flagged feature.
// Example: `travel_module_screen.dart` is only imported/used behind the flag check.

// AI must trace: is this class ONLY reachable via the flag check?
// If yes → it's part of the feature scope.
// If no → it's shared code, leave it alone.

// graduate: keep the file, remove any flag checks inside it
// drop: DELETE the entire file, and remove all imports/references to it elsewhere
```

**Tracing rule:** Follow the import chain. If removing the flag check leaves zero import paths to the file, the file is orphaned and should be removed (for `drop`) or kept as-is (for `graduate`).

---

## Pattern 5: Nested / combined conditions

```dart
// BEFORE — flag combined with other logic
if (featureFlag.isEnabled(FlagConstants.xpmTravel) && user.hasPermission('travel')) {
  showTravelUI();
}

// AFTER (graduate): remove ONLY the flag part, keep other conditions
if (user.hasPermission('travel')) {
  showTravelUI();
}

// AFTER (drop): the flag condition was true-branch → remove entire block
// (since we're dropping the feature, permission check becomes irrelevant)
```

```dart
// BEFORE — flag OR'd with something
if (featureFlag.isEnabled(FlagConstants.xpmTravel) || isAdmin) {
  showTravelUI();
}

// AFTER (graduate): flag is always true → entire OR is true → unwrap
showTravelUI();

// AFTER (drop): flag is always false → simplify to remaining condition
if (isAdmin) {
  showTravelUI();
}
```

---

## Pattern 6: Early returns

```dart
// BEFORE
void initTravel() {
  if (!featureFlag.isEnabled(FlagConstants.xpmTravel)) return;
  // rest of initialization
  setupTravelRoutes();
  registerHandlers();
}

// AFTER (graduate): guard is never true → remove the guard line
void initTravel() {
  setupTravelRoutes();
  registerHandlers();
}

// AFTER (drop): guard is always true → method body never executes
// Option A: make it an empty method (if called from many places)
void initTravel() {}

// Option B: remove the method entirely and all call sites
// (AI decides based on whether callers exist and what happens without the call)
```

---

## Pattern 7: Ternary expressions

```dart
// BEFORE
final widget = featureFlag.isEnabled(FlagConstants.xpmTravel)
    ? TravelDashboard()
    : LegacyDashboard();

// AFTER (graduate): resolve to true branch
final widget = TravelDashboard();

// AFTER (drop): resolve to false branch
final widget = LegacyDashboard();
```

```dart
// BEFORE — inline ternary in widget tree
Text(featureFlag.isEnabled(FlagConstants.xpmTravel) ? 'Travel' : 'Trips')

// AFTER (graduate):
Text('Travel')

// AFTER (drop):
Text('Trips')
```

---

## Pattern 8: Variable assignments (indirect flag usage)

```dart
// BEFORE
final isTravelEnabled = featureFlag.isEnabled(FlagConstants.xpmTravel);
// ... later in code ...
if (isTravelEnabled) {
  showTravel();
} else {
  showLegacy();
}

// TRANSFORMATION STRATEGY:
// 1. Find the variable assignment
// 2. Trace ALL usages of `isTravelEnabled`
// 3. At each usage site, apply the same graduate/drop logic
// 4. Remove the variable declaration (now unused)
```

---

## Pattern 9: Switch/when expressions (Kotlin)

```kotlin
// BEFORE (Kotlin)
when {
    featureFlags.isEnabled(FLAG_XPM_TRAVEL) -> showNewTravel()
    else -> showLegacyTravel()
}

// AFTER (graduate): resolve to the flag's branch
showNewTravel()

// AFTER (drop): resolve to else branch
showLegacyTravel()
```

---

## Pattern 10: SwiftUI conditional views

```swift
// BEFORE (Swift)
var body: some View {
    VStack {
        HeaderView()
        if featureFlags.isEnabled(.xpmTravel) {
            TravelView()
        } else {
            LegacyView()
        }
        FooterView()
    }
}

// AFTER (graduate):
var body: some View {
    VStack {
        HeaderView()
        TravelView()
        FooterView()
    }
}

// AFTER (drop):
var body: some View {
    VStack {
        HeaderView()
        LegacyView()
        FooterView()
    }
}
```

---

## Boolean Simplification Rules

When a flag is part of a larger boolean expression, apply these simplification rules:

| Expression | Graduate (flag = always true) | Drop (flag = always false) |
|-----------|-------------------------------|----------------------------|
| `flag && X` | `X` | `false` (entire condition is false) |
| `flag \|\| X` | `true` (entire condition is true → unwrap) | `X` |
| `!flag` | `false` | `true` |
| `!flag && X` | `false` (dead code) | `X` |
| `!flag \|\| X` | `X` | `true` (unwrap) |

After boolean simplification, apply constant folding:
- `if (true) { A } else { B }` → `A`
- `if (false) { A } else { B }` → `B`
- `if (true) { A }` → `A` (unwrap)
- `if (false) { A }` → remove entirely

---

## Edge Cases

| Case | Handling |
|------|----------|
| Flag checked but never in a conditional (just logged/tracked) | Remove the logging/tracking line |
| Flag passed as parameter to another function | Trace into that function to understand the conditional |
| Flag in annotation/decorator | Remove the annotation |
| Flag in string interpolation (debug message) | Remove the debug message or simplify it |
| Multiple flags in one conditional (`flagA && flagB`) | Only resolve the TARGET flag, leave others as variables |
