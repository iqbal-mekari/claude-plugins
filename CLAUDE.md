# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A **Claude Code plugin monorepo** — not an application codebase. It contains AI agent definitions, skill definitions, and reference materials as Markdown, Dart templates, CSV examples, and JSON configuration. There is no application source code, no build system, no test runner, and no linting configuration.

Marketplace name: `mekari-tools` (install via `/plugin marketplace add iqbal-mekari/claude-plugins`).

## Repository Structure

```
.claude-plugin/marketplace.json   ← Plugin registry (lists all plugins)
plugins/
  patrol-qa-automation/           ← Patrol QA test automation
    .claude-plugin/plugin.json    ← Plugin metadata
    .mcp.json                     ← MCP server config (Patrol MCP)
    AGENTS.md                     ← Agent/skill instructions (authoritative reference)
    agents/                       ← Agent definitions (orchestrators only)
    skills/                       ← Skill definitions + shared references
    examples/                     ← Sample CSV input/output with pipeline walkthrough
  designer-agent/                 ← Design spec agent (UI/UX + Pixel recommendations)
    .claude-plugin/plugin.json    ← Plugin metadata
    .mcp.json                     ← MCP server config (Mekari Pixel MCP)
    AGENTS.md                     ← Agent/skill instructions
    agents/                       ← Sub-agent definitions (pixel-specialist)
    skills/                       ← Skill definitions (design-ui, pixel-lookup)
    examples/                     ← Sample input/output design specs
  feature-flag-cleanup/           ← Automated feature flag cleanup
    .claude-plugin/plugin.json    ← Plugin metadata
    AGENTS.md                     ← Agent/skill instructions
    agents/                       ← Agent definitions (feature-flag-cleaner)
    skills/                       ← Skill definitions (cleanup-feature-flag) + references
    examples/                     ← Sample invocation and output
  code-review-agent/              ← AI-powered Bitbucket PR review
    .claude-plugin/plugin.json    ← Plugin metadata
    AGENTS.md                     ← Agent/skill instructions
    agents/                       ← Agent definitions (pr-reviewer)
    skills/                       ← Skill definitions (6 skills)
    reviewers/                    ← Persona prompts (security, performance, quality)
    examples/                     ← Sample review output
  sync-upstream/                  ← Vendored-plugin sync with this repo
    .claude-plugin/plugin.json    ← Plugin metadata
    AGENTS.md                     ← Agent/skill instructions
    skills/                       ← Skill definitions (sync-upstream)
    examples/                     ← Reference settings.json + sync-state schema
```

When adding a new plugin: create `plugins/<name>/` with `.claude-plugin/plugin.json`, then register it in the root `.claude-plugin/marketplace.json`.

## Plugin Architecture: patrol-qa-automation

Two-agent system with skill-based workers for Patrol-based Flutter mobile UI test automation:

**Agents (user-invocable orchestrators):**
- `patrol-test-creator` — Takes CSV test cases, orchestrates Patrol Dart file production
- `patrol-test-debugger` — Autonomous debugging loop for failing Patrol tests

**Skills** (invocable directly or by agents):
- `create-patrol-test` — Authoritative rules for Patrol test creation
- `create-patrol-testcase` — Writes one atomic testcase Dart file
- `compose-patrol-scenario` — Composes scenario Dart from testcase files
- `debug-patrol-test` — Debug workflow for failing Patrol tests
- `debug-patrol-selector` — Diagnoses/fixes one failing selector
- `create-test-cases` — Generates new mobile UI test cases (includes Gate 1)
- `regenerate-test-cases` — Updates test cases from code diffs/PRs (includes Gate 1)
- `impact-analysis` — Identifies impacted modules & test cases from PR/branch diffs (includes Gate 1)

## Plugin Architecture: designer-agent

Design-to-spec agent that converts Figma, images, or text requirements into purposeful UI/UX design specifications with ASCII wireframes and verified Mekari Pixel widget recommendations. Does **not** generate Flutter code — outputs design specs only.

**Skills:**
- `design-ui` (`/design-ui`) — Main entry: classifies input, extracts requirements, spawns pixel-specialist, produces ASCII wireframe + Pixel widget recommendations
- `pixel-lookup` (`/pixel-lookup`) — Quick Pixel component search and documentation lookup

**Sub-agent:**
- `pixel-specialist` — Resolves UI descriptions into verified Pixel component manifest by querying the Mekari Pixel MCP server. Spawns from `/design-ui` only.

**Anti-hallucination gate:** The pixel-specialist queries MCP for every component. No component is recommended without verification via `mekari_pixel_list_components()`, `mekari_pixel_query()`, and `mekari_pixel_get()`. Unresolved elements are explicitly marked.

**Output format:**
1. ASCII wireframe (low-fidelity visual layout)
2. Design decisions with UX rationale
3. Verified widget recommendation table (component, tier, variant, design tokens)
4. UNRESOLVED elements list (if any)

## Plugin Architecture: feature-flag-cleanup

Automated feature flag lifecycle agent that removes flag checks and cleans up cascade artifacts across Dart/Flutter, Kotlin, and Swift codebases.

**Agent:**
- `feature-flag-cleaner` — User-invocable orchestrator. Runs the full 7-phase cleanup pipeline: discovery, code transformation, cascade cleanup (analyzer-driven iterative), config/registry cleanup, test cleanup, documentation cleanup, and verification with summary.

**Skills:**
- `cleanup-feature-flag` (`/cleanup-feature-flag`) — Main entry: collects flag name + action (graduate/drop) + repo path, then executes the complete pipeline.

**Reference documents:**
- `cleanup-patterns.md` — 10 transformation patterns with before/after examples (simple if/else, no-else, collection-if, entire file, nested conditions, early returns, ternary, variable assignments, Kotlin when, SwiftUI views) plus boolean simplification rules.

**Key design decisions:**
- One flag per cleanup run — never batch
- Analyzer-driven cascade cleanup — iterates until static analysis reports zero new warnings
- Pre-existing failure aware — establishes test baseline before cleanup to distinguish new vs old failures
- Conservative on uncertainty — skips ambiguous transformations with TODO comments
- Scope boundary — code transformation only; branching, committing, and PR creation is the user's responsibility

## Plugin Architecture: code-review-agent

AI-powered Bitbucket PR review agent with multi-persona analysis. Combines a deterministic pipeline (ported from Alibaba's Open Code Review) with specialized Security, Performance, and Quality sub-agents. No external CLI dependencies — all logic runs natively in Claude Code.

**Agent:**
- `pr-reviewer` — User-invocable orchestrator. Runs the full pipeline: fetch PRs → fetch diff → deterministic review → 3 parallel persona reviews → merge findings → present results → optional Bitbucket comment posting.

**Skills:**
- `review-pr` (`/review-pr`) — Main entry: full pipeline from fetch to post
- `fetch-prs` — Fetches Bitbucket PRs assigned to user (workspace-wide or repo-specific)
- `run-pr-review` — Deterministic pipeline: diff parsing → file filtering → smart bundling → rule-matched review
- `run-persona-review` — Spawns one persona sub-agent for focused review (Security/Performance/Quality)
- `merge-review-findings` — Deduplicates and prioritizes findings from all sources
- `post-review-comments` — Posts summary + inline comments to Bitbucket PR

**Reviewer personas (in `reviewers/`):**
- `security-sentinel` — OWASP Top 10, auth, injection, secrets, crypto
- `performance-pursuer` — N+1 queries, algorithm complexity, memory, I/O, concurrency
- `quality-custodian` — SOLID, architecture, naming, code smells, test coverage

**Key design decisions:**
- OCR as design inspiration, not dependency — ports OCR's deterministic pipeline concepts (file bundling, rule matching, structured output) without requiring the `ocr` CLI
- Multi-persona parallel execution — 3 sub-agents run concurrently via separate `actor` tool calls
- Bitbucket-only scope — no GitHub/GitLab support
- Always confirm before posting — never posts comments without explicit user approval
- Review rules support 4-layer priority chain: CLI flag > project config > global config > built-in defaults

## Plugin Architecture: sync-upstream

Sync agent for **consuming projects that vendor plugins project-locally** (a committed `vendor/claude-plugins/` local marketplace) instead of installing from the GitHub marketplace. Pulls upstream improvements from this repo into the vendored copies via a tracked three-way merge, preserving each project's local tailoring.

**Skills:**
- `sync-upstream` (`/sync-upstream`) — Full sync workflow: locate vendored plugins → fetch upstream → three-way merge (base = `lastSyncedCommit` in `.sync-state.json`, ours = local, theirs = upstream HEAD) → verify → report

**Key design decisions:**
- Update-only — never adds plugins not already vendored, never removes vendored plugins (even if dropped upstream)
- Three-way or no way — never blind-overwrites local files; missing merge base triggers version-matching bootstrap or supervised diff
- Runs in consuming projects only — refuses to run inside this upstream repo
- Rule conflicts surface to the user — parametric tailoring is preserved automatically; contradictory rule changes are never resolved silently
- Scope boundary — writes only inside the vendored plugins directory + `.sync-state.json`; never commits; never touches the user-level plugin cache

## Distribution Model

- **Standard mode (default):** projects enable plugins from the GitHub marketplace via checked-in `.claude/settings.json` (`extraKnownMarketplaces` + `enabledPlugins`). Project-specific *facts* (paths, module names, flavors) live in the project's own CLAUDE.md — no vendoring needed.
- **Project-local mode:** only for projects that must tailor plugin *rules*. They vendor plugins under `vendor/claude-plugins/`, register it as a local `directory` marketplace, and sync deliberately with `/sync-upstream`. See root `README.md` for the walkthrough.
- **Upstreaming:** lessons learned in projects flow back here — generalized (no project names/paths), appended to the right reference file, with a version bump in `plugin.json`. Every change must pass the litmus test: *would a different repo using this plugin benefit?*

## Critical Rules

1. **Read the relevant `SKILL.md` before any task** — it is the authoritative source, overriding any legacy patterns.
2. **Never write Patrol test code without running it.** Use `mcp_patrol_mcp_run` to validate on a live device.
3. **Never hardcode credentials** — use function parameters or test setup.
4. **Never use pixel coordinates** as Patrol selectors.
5. **Patrol MCP is a test runner, not a device driver.** Write complete Dart test files, then run them. Edit → run → observe → edit again.
6. **Skills can be invoked directly or by agents.** Agents orchestrate; skills execute.

## Patrol Selector Priority (highest to lowest)

1. Text — `$('Login')`
2. Key — `$(#emailField)` (Semantics `identifier:` or widget Key)
3. Type — `$(ElevatedButton)`
4. Ancestor chaining — `$(Scaffold).$('Submit')`
5. Containing — `$(Row).containing($('label'))`
6. Fallback — add `Semantics(identifier: "...", container: true)` to Flutter source, rebuild

Always pair `identifier:` with `container: true`. Any Semantics change requires `flutter build` + reinstall.

## Human-in-the-Loop Gates

Two mandatory human approval checkpoints exist in the pipeline:

| Gate | Between | What's reviewed |
|------|---------|-----------------|
| 1 | Test case generation → Patrol scripting | Generated CSV completeness & correctness |
| 2 | Mapping table → Dart file writing | Triage decisions (automate/skip/setup) |

Agents must never proceed past gates 1 or 2 without explicit human approval. See `skills/shared-references/human-in-the-loop.md`.

## Test Case Conventions

- IDs: `TC001`, `TC002`, ... (sequential)
- Titles: `User able to ...` (happy path) / `User not able to ...` (negative)
- Categories: `Smoke` (P0 core) or `Regression` (everything else)
- Output: `/test-cases/{epic_key}_{short_desc}_test_cases.csv` + smoke-only variant

## MCP Tools

| Tool | Use |
|------|-----|
| `mcp_patrol_mcp_run` | Run a Dart test file on device |
| `mcp_patrol_mcp_native-tree` | Dump native view hierarchy for selector discovery |
| `mcp_patrol_mcp_screenshot` | Screenshot for visual debugging |
| `mcp_patrol_mcp_status` | Check session state and connected device |
| `mcp_patrol_mcp_quit` | End Patrol MCP session |
| Atlassian MCP | Jira tickets, comments, Confluence pages |
| Figma MCP | Design context, screenshots, component metadata |

## Scope Limits

- **Patrol / mobile UI only.** No API tests, backend tests, or web tests.
- **No web, no desktop.** Flutter Android/iOS only.
- Do not invent new test case fields — `create-test-cases` SKILL.md gates structure.

## Key Reference Files

- `plugins/patrol-qa-automation/AGENTS.md` — Full agent/skill/convention details
- `skills/shared-references/selector-rules.md` — Patrol selector strategies (single source of truth)
- `skills/shared-references/human-in-the-loop.md` — Mandatory approval gates
- `skills/debug-patrol-test/references/failure-patterns.md` — Known failure patterns (append after fixing new ones)
- `skills/create-patrol-test/references/flutter-semantics.md` — How to add Semantics identifiers to Flutter widgets
- `skills/create-patrol-test/references/testcase_template.dart` — Testcase Dart template
- `skills/create-patrol-test/references/scenario_template.dart` — Scenario Dart template
- `plugins/designer-agent/AGENTS.md` — Designer agent/skill details and anti-hallucination rules
- `plugins/designer-agent/examples/sample_output.md` — Example design spec output format
- `plugins/feature-flag-cleanup/AGENTS.md` — Feature flag cleanup agent/skill details
- `plugins/feature-flag-cleanup/skills/cleanup-feature-flag/SKILL.md` — Cleanup workflow (7 phases)
- `plugins/feature-flag-cleanup/skills/cleanup-feature-flag/references/cleanup-patterns.md` — 10 transformation patterns with examples
- `plugins/code-review-agent/AGENTS.md` — Code review agent/skill details and critical rules
- `plugins/code-review-agent/agents/pr-reviewer.md` — PR reviewer agent pipeline definition
- `plugins/code-review-agent/skills/review-pr/SKILL.md` — Main entry point for PR review
- `plugins/code-review-agent/examples/sample_review_output.md` — Example review output format
- `plugins/sync-upstream/skills/sync-upstream/SKILL.md` — Vendored-plugin sync workflow (7 phases, merge matrix)
- `plugins/sync-upstream/examples/consuming-project-settings.json` — Reference `.claude/settings.json` for consuming projects
- `plugins/sync-upstream/examples/sync-state.example.json` — `.sync-state.json` schema (merge-base tracking)
