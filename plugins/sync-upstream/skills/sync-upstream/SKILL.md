---
name: sync-upstream
description: Sync project-locally installed (vendored) Claude Code plugins with their upstream marketplace repo. Performs a tracked three-way merge that pulls upstream improvements into the local plugin copies while preserving project-specific tailoring. Update-only — never adds new plugins, never removes local ones. Use when the user wants to sync, update, or pull plugin changes from upstream into a project. Triggers on: "sync upstream", "sync plugins", "update plugins from upstream", "pull plugin updates", "sync vendored plugins", "update local plugins".
argument-hint: [plugin-name] [--upstream <repo-url>]
---

# Sync Upstream Skill

> *"A well-run province adopts the empire's new laws without burning its own charters."*

## What This Skill Does

Consuming projects vendor plugins from the upstream marketplace repo (default: `https://github.com/iqbal-mekari/claude-plugins`) into a local directory and may tailor them. This skill updates those vendored copies from upstream via a **tracked three-way merge**:

- **base** = the upstream commit the local copy was last synced to (recorded in `.sync-state.json`)
- **ours** = the local vendored files (possibly tailored)
- **theirs** = the current upstream HEAD

Upstream improvements land; local tailoring survives; genuine contradictions are surfaced to the user instead of silently resolved.

## Hard Policies (non-negotiable)

1. **Update-only.** Never add a plugin that is not already vendored locally. Never delete a locally vendored plugin — even if upstream removed it. Adding/removing plugins is the user's decision, made outside this skill.
2. **Write only inside the vendored plugins directory** (plus its `.sync-state.json`). Never touch other project files, the user-level plugin cache (`~/.claude/plugins/`), or upstream.
3. **Never commit.** Leave all changes in the working tree for user review. Branching, committing, and pushing are the user's responsibility.
4. **Never leave conflict markers.** Every file must end the sync in a valid, marker-free state. Unresolvable conflicts get the local version kept plus a `TODO(sync-upstream)` note and an entry in the report.
5. **Three-way or no way.** Without a merge base, do NOT blindly overwrite local files with upstream. Use the bootstrap procedure (Phase 3) or stop.

## Input

| Input | Required | Default |
|-------|----------|---------|
| Plugin name | No | All vendored plugins |
| Upstream repo URL | No | Value of `upstream` in `.sync-state.json`, else `https://github.com/iqbal-mekari/claude-plugins` |
| Vendored plugins directory | No | Auto-detected (Phase 1) |

---

## Execution Phases

### Phase 1: Locate & Preflight

1. **Refuse to run inside the upstream repo itself.** If the current project's root `.claude-plugin/marketplace.json` declares `"name": "mekari-tools"` and the repo's git remote points at the upstream URL, stop: *"This is the upstream repo — sync-upstream runs in consuming projects."*
2. **Locate the vendored plugins directory**: search the project for a directory containing `.claude-plugin/marketplace.json` (conventional location: `vendor/claude-plugins/`). If multiple candidates or none found, ask the user for the path. If the project has none, stop — there is nothing to sync (this skill does not install plugins).
3. **Check git cleanliness**: `git status --porcelain -- <vendored-dir>`. If the vendored directory has uncommitted changes, stop and ask the user to commit or stash first — the merge result must be reviewable as a single clean diff.
4. **Read `.sync-state.json`** at the vendored directory root:

```json
{
  "upstream": "https://github.com/iqbal-mekari/claude-plugins",
  "lastSyncedCommit": "<full upstream commit SHA>",
  "lastSyncedAt": "<ISO 8601 timestamp>",
  "plugins": {
    "patrol-qa-automation": { "version": "1.1.0" },
    "sync-upstream": { "version": "1.0.0" }
  }
}
```

If the file is missing, note it — Phase 3 will bootstrap.

### Phase 2: Fetch Upstream

1. Clone upstream into the scratchpad (full history is needed for the merge base):
   ```bash
   git clone --filter=blob:none <upstream-url> <scratchpad>/upstream-sync
   ```
2. Record upstream HEAD SHA: `git -C <scratchpad>/upstream-sync rev-parse HEAD`.
3. If HEAD equals `lastSyncedCommit`, report "already up to date" and stop.

### Phase 3: Establish the Merge Base

- **Normal case**: base = `lastSyncedCommit` from `.sync-state.json`. Verify it exists upstream (`git cat-file -e <sha>`).
- **Bootstrap case** (`.sync-state.json` missing, or base SHA not found — e.g., history rewritten): infer a per-plugin base from versions:
  1. Read the local `plugin.json` version for each vendored plugin.
  2. In the upstream clone, walk `git log --format='%H' -- plugins/<name>/.claude-plugin/plugin.json` and find the most recent commit where the upstream version equals the local version. That commit is the plugin's base.
  3. If no upstream commit matches the local version (version was tailored locally), ask the user which upstream version the copy was originally taken from. If they don't know, fall back to a **supervised two-way diff**: present each differing file's local vs upstream version and let the user classify (keep local tailoring / adopt upstream) — never auto-overwrite.

### Phase 4: Determine Sync Scope

Build the plugin list as the **intersection** of locally vendored plugins and upstream plugins:

- Upstream plugin not vendored locally → list in the report as *"available upstream, not installed — not adding (update-only policy)"*. Do not copy it.
- Local plugin absent upstream → warn *"upstream no longer ships this plugin — local copy left untouched"*. Do not delete it.
- If the user named a specific plugin, restrict scope to it (it must be vendored locally; otherwise stop and explain).

### Phase 5: Three-Way Merge (per plugin)

Enumerate files across base, theirs, and ours for `plugins/<name>/`, then apply this decision matrix per file:

| Upstream (base→theirs) | Local (base→ours) | Action |
|---|---|---|
| unchanged | anything | Keep ours (local tailoring or identical — either way, no-op) |
| changed | unchanged | Take theirs (fast-forward) |
| changed | changed | Textual merge via `git merge-file`; conflicts → semantic resolution (below) |
| added (new file) | absent locally | Add it — new files within an already-installed plugin are part of the update |
| deleted | unchanged | Delete locally |
| deleted | modified locally | Keep ours; flag in report for user decision |

Retrieve file contents with `git -C <clone> show <sha>:plugins/<name>/<path>`; write base/theirs to scratchpad temp files for `git merge-file`.

**Semantic conflict resolution** (for hunks `git merge-file` cannot auto-merge):

1. **Classify the local change**: is it *parametric tailoring* (project paths, module names, app-specific values) or a *rule change* (altered workflow, overridden policy)?
2. **Parametric tailoring** → keep the local values, weave the upstream structural/content changes around them.
3. **Rule change vs upstream rule change on the same rule** → do NOT pick silently. Show the user both versions with a one-line summary of each side's intent and a recommendation; apply their choice.
4. **Cannot resolve cleanly** → keep the local version, add `<!-- TODO(sync-upstream): upstream changed this section in <sha>; manual reconcile needed -->` (or `// TODO(sync-upstream): ...` in code files), and flag in the report.

**Version handling**: `plugin.json` takes the upstream `version` value; other locally tailored fields in `plugin.json` merge like any other file.

### Phase 6: Verify

1. Every `plugin.json` and the local `marketplace.json` parse as valid JSON.
2. `grep -rn '<<<<<<<' <vendored-dir>` returns nothing.
3. Update the local `marketplace.json` version fields to match each synced plugin's `plugin.json`.
4. The local `marketplace.json` plugin list is unchanged (same names, same count) — proof the update-only policy held.

### Phase 7: Update State & Report

1. Write `.sync-state.json`: `lastSyncedCommit` = upstream HEAD, `lastSyncedAt` = now, refresh plugin versions.
2. Report to the user:

| Plugin | Version | Fast-forwarded | Merged | Flagged |
|--------|---------|----------------|--------|---------|
| patrol-qa-automation | 1.1.0 → 1.2.0 | 4 files | 1 file | 0 |

   Plus:
   - Files where local tailoring was preserved through a merge (list them — these deserve a second look in review)
   - Flagged items needing user decisions (upstream-deleted-but-locally-modified files, unresolved rule conflicts)
   - Upstream plugins available but not installed (informational only)
3. **Remind the user** to:
   - Review the diff (`git diff -- <vendored-dir>`) and commit — this skill never commits
   - Sweep the project's `CLAUDE.md` for `TEMP-WORKAROUND` tags that this update supersedes, and remove them
   - Refresh the local marketplace if plugin content is cached (`/plugin marketplace update <local-marketplace-name>`)

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Run inside the upstream repo | Stop. Sync runs in consuming projects only. |
| No vendored plugins directory found | Ask user for the path; if none exists, stop — nothing to sync, and this skill does not install. |
| Vendored dir has uncommitted changes | Stop. Ask user to commit or stash first. |
| `.sync-state.json` missing | Bootstrap via version-matching (Phase 3). Never blind-overwrite. |
| Base SHA not found upstream (history rewritten) | Fall back to bootstrap version-matching; else supervised two-way diff. |
| Network/clone failure | Stop and report. No partial writes have occurred (clone precedes any local write). |
| Unresolvable merge conflict | Keep local version + `TODO(sync-upstream)` marker; flag in report; continue with remaining files. |
| Upstream removed a locally-vendored plugin | Keep local copy; warn in report. |
| User-named plugin not vendored locally | Stop. Explain the update-only policy; suggest the user install it deliberately if wanted. |
