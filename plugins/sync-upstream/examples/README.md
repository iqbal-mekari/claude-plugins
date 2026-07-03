# Examples

| File | Purpose |
|------|---------|
| `consuming-project-settings.json` | Reference `.claude/settings.json` for a consuming project using project-local (vendored) plugins — registers the vendored directory as a local marketplace and enables only the plugins that project needs. Commit this file in the consuming project so teammates get the same setup. |
| `sync-state.example.json` | Example `.sync-state.json` placed at the vendored marketplace root (e.g., `vendor/claude-plugins/.sync-state.json`). Records the upstream URL and the last-synced upstream commit — the merge base for `/sync-upstream`. Created once at vendoring time, updated automatically by every sync. |

See the root `README.md` of the upstream repo for the full project-local installation walkthrough.
