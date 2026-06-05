# Feature Flag Cleanup — Workspace Instructions

This plugin automates the removal of feature flags from codebases. It discovers all usages of a flag, transforms conditional code into unconditional code (graduate = keep enabled branch, drop = remove enabled branch), cascades cleanup via static analysis, and updates tests, config, and documentation.

## Critical Rules

1. **Read `skills/cleanup-feature-flag/SKILL.md` before any task.** It is the authoritative source for the cleanup workflow.
2. **One flag per cleanup run.** Never batch multiple flags in a single execution.
3. **Never guess which branch to keep.** If ambiguous, skip the usage and add a `// TODO(flag-cleanup): manual review needed` comment.
4. **Establish a test baseline before cleanup.** Run tests on the original code to identify pre-existing failures. Only investigate NEW failures introduced by the cleanup.
5. **Never go on a codebase-wide cleanup spree.** Only fix cascade warnings in files already touched or directly related to the flag removal.
6. **Scope boundary — code transformation only.** Never create branches, commits, or PRs. That is the user's responsibility.

## Agent Hierarchy

| Agent | Role | Invocable |
|-------|------|-----------|
| `feature-flag-cleaner` | Orchestrates the full cleanup pipeline: discovery, transformation, cascade, config, tests, docs, verification | User-invocable |

## Skills

| Skill | Invocation | Purpose |
|-------|------------|---------|
| `cleanup-feature-flag` | `/cleanup-feature-flag` | Main entry — full 7-phase cleanup workflow from discovery to verification |

## Reference Documents

| File | Purpose |
|------|---------|
| `skills/cleanup-feature-flag/references/cleanup-patterns.md` | 10 transformation patterns with before/after examples for Dart, Kotlin, Swift |

## Supported Languages

| Language | Platform | Notes |
|----------|----------|-------|
| Dart / Flutter | Android, iOS, Web | Collection-if in widget trees, null-safe access, `Visibility`/`Offstage` patterns |
| Kotlin | Android | `when` expressions, `@Composable` conditionals, DI-injected flags (Dagger/Hilt) |
| Swift | iOS | `guard` statements, SwiftUI conditional views, `#if` compile-time flags (different from runtime!) |

## Scope

- **Code transformation only.** The agent removes flag checks and cleans up cascade artifacts. It does not create branches, commits, or PRs.
- **Runtime feature flags only.** Compile-time flags (`#if`, `#ifdef`) are out of scope.
- **One flag at a time.** Each invocation handles exactly one flag.
