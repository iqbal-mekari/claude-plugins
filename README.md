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

## Install a Plugin

```
/plugin install patrol-qa-automation@mekari-tools
```

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
└── <future-plugins>/       ← Add more plugins here
```
