# Mekari Claude Code Plugins

Internal plugin marketplace for Mekari Mobile team.

## Install Marketplace

```
/plugin marketplace add iqbal-mekari/claude-plugins
```

## Available Plugins

| Plugin | Description |
|--------|-------------|
| `patrol-qa-automation` | Patrol-based mobile UI test automation for Flutter apps |
| `designer-agent` | Design spec agent — Figma/images/text to ASCII wireframes + verified Mekari Pixel widget recommendations |
| `feature-flag-cleanup` | Automated feature flag cleanup — discover, transform, cascade, verify (Dart/Kotlin/Swift) |
| `code-review-agent` | AI-powered Bitbucket PR review with Security/Performance/Quality personas |
| `sync-upstream` | Sync project-local (vendored) plugins with this repo via tracked three-way merge |

## Install a Plugin

```
/plugin install patrol-qa-automation@mekari-tools
/plugin install designer-agent@mekari-tools
/plugin install feature-flag-cleanup@mekari-tools
/plugin install code-review-agent@mekari-tools
/plugin install sync-upstream@mekari-tools
```

## Installation Modes

| Mode | How | When to use |
|------|-----|-------------|
| **Standard (marketplace)** | Install from this GitHub marketplace; content lives in the user-level plugin cache | Default. No local tailoring of plugin rules. Updates arrive via marketplace refresh with zero project changes. |
| **Project-local (vendored)** | Copy plugins into the project repo as a local marketplace; sync deliberately with `/sync-upstream` | Only when a project must tailor plugin **rules** (not just parameters). Divergence becomes explicit, versioned, and reconciled on command. |

Rule of thumb: project-specific **facts** (paths, module names, flavors) belong in the project's `CLAUDE.md` — that works with standard mode and needs no vendoring. Vendor only when the plugin's own rules must differ per project.

## Project-Local (Vendored) Installation

Run these from the consuming project's root:

**1. Vendor the plugins you need** (plus `sync-upstream` itself):

```bash
git clone --depth 1 https://github.com/iqbal-mekari/claude-plugins /tmp/mekari-plugins
mkdir -p vendor/claude-plugins/plugins
cp -R /tmp/mekari-plugins/plugins/patrol-qa-automation vendor/claude-plugins/plugins/
cp -R /tmp/mekari-plugins/plugins/sync-upstream        vendor/claude-plugins/plugins/
cp -R /tmp/mekari-plugins/.claude-plugin               vendor/claude-plugins/
```

**2. Tailor the vendored marketplace manifest** — edit `vendor/claude-plugins/.claude-plugin/marketplace.json`:
- Rename the marketplace to `mekari-tools-local` (avoids clashing with the GitHub marketplace if also installed)
- Remove entries for plugins you did not vendor

**3. Record the merge base** — create `vendor/claude-plugins/.sync-state.json`:

```bash
git -C /tmp/mekari-plugins rev-parse HEAD   # → use as lastSyncedCommit
```

```json
{
  "upstream": "https://github.com/iqbal-mekari/claude-plugins",
  "lastSyncedCommit": "<sha from above>",
  "lastSyncedAt": "<now, ISO 8601>",
  "plugins": {
    "patrol-qa-automation": { "version": "1.1.0" },
    "sync-upstream": { "version": "1.0.0" }
  }
}
```

**4. Register and enable in the project's `.claude/settings.json`** (committed, so teammates get the same setup):

```json
{
  "extraKnownMarketplaces": {
    "mekari-tools-local": {
      "source": {
        "source": "directory",
        "path": "./vendor/claude-plugins"
      }
    }
  },
  "enabledPlugins": {
    "patrol-qa-automation@mekari-tools-local": true,
    "sync-upstream@mekari-tools-local": true
  }
}
```

Reference copy: `plugins/sync-upstream/examples/consuming-project-settings.json`.

**5. Commit** `vendor/claude-plugins/` and `.claude/settings.json`. Local tailoring of the vendored plugin files is now ordinary, reviewable project history.

## Syncing with Upstream

When this repo publishes improvements, consuming projects with vendored plugins pull them in with:

```
/sync-upstream
```

The skill performs a **tracked three-way merge** (base = last-synced upstream commit from `.sync-state.json`, ours = local tailored copy, theirs = upstream HEAD):

- Upstream-only changes fast-forward in; local-only tailoring is preserved untouched
- Files changed on both sides are merged; genuine rule contradictions are surfaced to you, never silently resolved
- **Update-only**: never adds plugins you didn't vendor, never removes ones you did — installing/removing is always your deliberate act

After a sync: review `git diff -- vendor/claude-plugins`, commit, then refresh the cache with `/plugin marketplace update mekari-tools-local` (plugin content is cached even for local marketplaces). Full workflow: `plugins/sync-upstream/skills/sync-upstream/SKILL.md`.

Upstreaming a lesson learned in a project goes the other direction: generalize it (strip project specifics), commit it in this repo, bump the plugin version — the next `/sync-upstream` (or marketplace refresh, for standard-mode projects) delivers it everywhere.

## Structure

```
plugins/
├── patrol-qa-automation/   ← Patrol QA test automation
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── agents/
│   ├── skills/
│   ├── examples/
│   └── ...
├── designer-agent/         ← Design spec agent (UI/UX + Pixel widgets)
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── agents/
│   ├── skills/
│   ├── examples/
│   └── ...
├── feature-flag-cleanup/   ← Automated feature flag cleanup
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── agents/
│   ├── skills/
│   ├── examples/
│   └── ...
├── code-review-agent/      ← Bitbucket PR review (multi-persona)
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── agents/
│   ├── skills/
│   ├── reviewers/
│   ├── examples/
│   └── ...
├── sync-upstream/          ← Vendored-plugin sync with this repo
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── skills/
│   ├── examples/
│   └── ...
└── <future-plugins>/       ← Add more plugins here
```
