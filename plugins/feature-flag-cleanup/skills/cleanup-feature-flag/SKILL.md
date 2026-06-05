---
name: cleanup-feature-flag
description: Clean up feature flags from codebases. Removes flag checks, makes conditional code unconditional (graduate = keep enabled code, drop = remove enabled code), handles cascade cleanup via static analysis, cleans tests/config/docs. Use when the user wants to clean up, remove, graduate, drop, retire, or sunset a feature flag. Triggers on: "clean up feature flag", "remove feature flag", "graduate feature flag", "drop feature flag", "flag cleanup", "retire flag", "sunset flag".
argument-hint: <flag-name> <graduate|drop> <repository-path>
---

# Feature Flag Cleanup Skill

> *"A proper cleanup leaves no trace of the old regime."*

## When to Use

- User wants to remove a feature flag that is no longer needed
- User wants to "graduate" a flag (feature is permanently enabled)
- User wants to "drop" a flag (feature is being removed)
- User wants to "retire" or "sunset" a feature flag

## Input Requirements

Before starting, collect these inputs from the user:

| Input | Required | Description |
|-------|----------|-------------|
| **Flag name** | Yes | The string identifier (e.g., `flag_mod_xpm_travel`) |
| **Action** | Yes | `graduate` or `drop` |
| **Repository path** | Yes | Absolute path to the repository to clean |

### Action Definitions

- **Graduate** — The feature is permanently enabled. Remove the flag check, KEEP the code inside the `true`/enabled branch. Delete the `false`/disabled branch.
- **Drop** — The feature is being removed. Remove the flag check, DELETE the code inside the `true`/enabled branch. Keep the `false`/disabled/fallback branch.

---

## Execution Steps

### Phase 1: Discovery

> Discovery is reliable because flags are ALWAYS defined as string constants in a dedicated constants file per module. No confirmation checkpoint needed — proceed directly to transformation.

1. **Find the flag constant definition**
   - `grep` for the flag name string literal (e.g., `"flag_mod_xpm_travel"`) across the repository
   - This will locate the constant file/class (e.g., `FlagConstants.dart`, `FeatureFlags.kt`, `FeatureFlags.swift`)
   - Note the constant variable name (e.g., `kFlagModXpmTravel`, `FLAG_MOD_XPM_TRAVEL`)

2. **Trace all references via the constant name**
   - `grep` for the constant variable name across the entire repo (including `android/` and `ios/` directories for Flutter projects)
   - This gives the complete and exhaustive list of usage sites

3. **Categorize usages** (for transformation routing)
   - **Code conditionals**: if/else, ternary, switch, widget conditional rendering → Phase 2
   - **Config/registry entries**: flag registration, default value definitions → Phase 4
   - **Test references**: test mocks, test setup, flag-specific test cases → Phase 5
   - **Documentation**: comments, README references, changelog entries → Phase 6

4. **Proceed immediately** — no user confirmation needed. Results shown in summary.

### Phase 2: Code Transformation

For each code conditional usage, apply the correct transformation based on the action:

- **Graduate** → keep the `true`/enabled branch, remove the `false`/disabled branch
- **Drop** → keep the `false`/disabled branch, remove the `true`/enabled branch

> **See [cleanup-patterns.md](./references/cleanup-patterns.md)** for detailed transformation examples covering all 10 patterns: simple if/else, no-else blocks, collection-if, entire file/class, nested conditions, early returns, ternary expressions, variable assignments, Kotlin when expressions, and SwiftUI conditional views. Also includes boolean simplification rules and edge cases.

**Key principles:**
- Apply boolean simplification when flag is part of a compound expression
- Trace indirect usages (flag stored in variable → find all variable usages)
- If unsure about a transformation → skip it, leave a TODO comment
- Only resolve the TARGET flag — leave other flags/conditions untouched

### Phase 3: Cascade Cleanup

> Strategy: Leverage static analysis tools (not manual reasoning) to find cascade issues. Iterate until the analyzer reports no new warnings.

**Approach: Analyzer-Driven Iterative Cleanup**

```
loop:
  1. Run static analysis (`dart analyze`, Kotlin compiler, Swift build)
  2. Parse warnings/errors related to files already modified:
     - Unused imports
     - Unused variables/fields
     - Unused parameters
     - Unreachable code
     - Empty bodies/blocks
  3. If new warnings found → fix them
  4. If warnings create MORE orphaned code → repeat from step 1
  5. If no new warnings → exit loop (clean state achieved)
```

**What to fix in each iteration:**
1. **Dead imports**: Remove `import` lines that are no longer referenced
2. **Unused variables/fields**: Remove declarations that lost their only consumer
3. **Empty blocks**: Remove empty methods, empty classes, empty if-bodies
4. **Orphaned files** (drop action): If removing a class leaves a file with nothing in it → delete file
5. **Unused parameters**: Remove from private methods. For public APIs → flag in summary as "breaking change — needs manual review"

**Stopping conditions:**
- Analyzer reports zero new warnings on touched files → done
- Only remaining warnings are pre-existing (existed before cleanup) → done
- Iteration count exceeds 10 → stop, report remaining issues in summary

**Critical: Ignore pre-existing warnings.** Before starting cleanup, capture the baseline analyzer output. Only act on NEW warnings that appeared after the flag removal. Never fix unrelated pre-existing issues — that's scope creep.

**Important:** Only fix warnings in files already touched or that are DIRECTLY related to the flag removal. Do not go on a codebase-wide cleanup spree.

### Phase 4: Config & Registry Cleanup

1. **Remove flag constant definition** from the constants file
2. **Remove flag registration** from any initialization/registry code
3. **Remove Firebase Remote Config** entries if managed in code (JSON files, default configs)
4. **Remove feature toggle UI** entries if the flag appears in any admin/debug panel

### Phase 5: Test Cleanup

> Reason about what each test is ACTUALLY testing, not just whether it references the flag.

**Decision framework for each test that references the flag:**

1. **Is the flag the SOLE subject of the test?**
   - e.g., "should show legacy UI when flag is OFF"
   - `graduate` → DELETE the "flag OFF" test case, KEEP the "flag ON" test (unwrap it — it's now the default)
   - `drop` → DELETE the "flag ON" test case, KEEP the "flag OFF" test (unwrap it — it's now the default)

2. **Is the flag just part of the test setup (testing something else)?**
   - e.g., test sets flag ON in `setUp()` then tests travel booking flow
   - `graduate` → Remove the flag mock from setup, keep the test intact
   - `drop` → DELETE the entire test (the feature no longer exists)

3. **Is it a group/describe wrapper based on flag state?**
   - e.g., `group('when travel flag is enabled', () { ... })`
   - `graduate` → Unwrap the group: keep all inner tests, remove the group wrapper
   - `drop` → DELETE the entire group

4. **Is the flag mocked alongside other setup?**
   - e.g., `setUp() { mockFlag(ON); mockUser(admin); mockNetwork(online); }`
   - → Just remove the `mockFlag(ON)` line, leave everything else

**General rules:**
- Remove `import` of the flag constant from test files when no longer referenced
- If removing tests leaves an empty test file → delete the file
- If a test file has both flag-related and non-flag-related tests → keep the file, remove only flag tests

### Phase 6: Documentation Cleanup

1. **Remove flag references** from README, CHANGELOG, or inline comments
2. **Update feature documentation** if it mentions "behind flag X"
3. **Remove TODO/FIXME comments** related to the flag cleanup

### Phase 7: Verification & Summary

1. **Capture baseline** — Before running tests, establish a baseline:
   - Run tests BEFORE cleanup (stash changes) to identify pre-existing failures
   - Record which tests were already failing
2. **Run static analysis** — ensure no compile errors introduced
3. **Run existing tests** — compare results against baseline:
   - If test failures are ONLY pre-existing → cleanup is clean
   - If NEW test failures appear → investigate and fix
   - Report both pre-existing and new failures clearly
4. **Generate a summary** report:
   - List all files modified/deleted
   - Describe each transformation applied
   - Note any ambiguous cases marked for manual review
   - Report test results distinguishing pre-existing vs new failures

---

## Safety Guardrails

1. **No confirmation checkpoint** — discovery is reliable (constants file pattern), proceed autonomously
2. **If unsure about a transformation** — do NOT transform. Leave the code as-is and add a `// TODO(flag-cleanup): manual review needed - {reason}` comment above the uncertain code block
3. **One flag per cleanup** — don't batch multiple flags in one run
4. **If tests fail after transformation** — distinguish pre-existing vs new failures. Run tests on stashed (original) code to establish baseline. Only investigate NEW failures.
5. **If flag not found** — stop immediately and report to user
6. **Scope boundary** — only transform code, never create branches/commits/PRs

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Flag name not found anywhere | Stop immediately. Report "flag not found" to user. |
| Ambiguous transformation (unsure which branch) | Skip that usage. Add TODO comment. Continue with other usages. |
| Build fails after transformation | Report build errors to user. Do not undo. User decides. |
| Tests fail after transformation | Stash changes, run tests on original code to establish baseline. Report pre-existing vs new failures. Do not undo. |
| Cascade loop exceeds 10 iterations | Stop cascade. Report remaining warnings. Proceed to next phase. |
| Analyzer unavailable (tool not installed) | Warn user that cascade cleanup is best-effort without analyzer. Proceed with manual reasoning. |
| File permission / read-only issue | Skip that file. Report to user. Continue with other files. |

---

## Language-Specific Notes

### Dart/Flutter
- Flag checks may use `?.` null-safe access
- Widget conditionals may use `if` inside collection literals: `[if (flag) Widget()]`
- Look for `Visibility`, `Offstage`, or conditional `child:` patterns

### Kotlin (Android)
- May use `when` expressions instead of `if/else`
- Look for `@Composable` conditional rendering
- Feature flags may be injected via DI (Dagger/Hilt)

### Swift (iOS)
- May use `guard` statements
- Look for `#if` compile-time flags (different from runtime flags!)
- SwiftUI conditional views with `if` in `body`
