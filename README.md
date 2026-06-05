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

## Install a Plugin

```
/plugin install patrol-qa-automation@mekari-tools
/plugin install designer-agent@mekari-tools
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
├── designer-agent/         ← Design spec agent (UI/UX + Pixel widgets)
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── agents/
│   ├── skills/
│   ├── examples/
│   └── ...
└── <future-plugins>/       ← Add more plugins here
```
