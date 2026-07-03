# Sync Upstream — Workspace Instructions

This plugin keeps **project-locally installed (vendored) plugins** in sync with the upstream marketplace repo (`iqbal-mekari/claude-plugins`). It performs a tracked three-way merge — upstream improvements land in the local copies while project-specific tailoring is preserved.

## Critical Rules

1. **Read `skills/sync-upstream/SKILL.md` before any task.** It is the authoritative source for the sync workflow.
2. **Update-only.** Never add a plugin that is not already vendored locally; never remove a vendored plugin, even if upstream dropped it.
3. **Three-way or no way.** Never blind-overwrite local files with upstream. The merge base comes from `.sync-state.json`; if missing, bootstrap by version-matching or run a supervised diff.
4. **Write only inside the vendored plugins directory** (plus `.sync-state.json`). Never touch the user-level plugin cache (`~/.claude/plugins/`) or any other project file.
5. **Never commit.** All changes stay in the working tree for user review.
6. **Never leave conflict markers.** Unresolvable conflicts keep the local version, get a `TODO(sync-upstream)` note, and are flagged in the report.

## Skills

| Skill | Invocation | Purpose |
|-------|------------|---------|
| `sync-upstream` | `/sync-upstream` | Full sync workflow: locate vendored plugins → fetch upstream → three-way merge → verify → report |

## Where This Runs

In **consuming projects** (e.g., a Flutter app repo) that vendor plugins under a local marketplace directory (conventionally `vendor/claude-plugins/`). It refuses to run inside the upstream marketplace repo itself.

## State File

`.sync-state.json` at the vendored marketplace root records the upstream URL, the last-synced upstream commit (the merge base), and per-plugin versions. See `examples/sync-state.example.json`.

## Scope

- **Sync only.** Installing new plugins, removing plugins, committing, and pushing are the user's responsibility.
- **One direction.** Upstream → local. Contributing local improvements back upstream is a separate, deliberate act in the upstream repo (generalize, bump version, push).
