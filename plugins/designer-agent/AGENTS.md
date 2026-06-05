# Designer Agent — Workspace Instructions

This plugin converts design inputs (Figma, images, or text requirements) into purposeful UI/UX design specifications with low-fidelity ASCII wireframes and verified Mekari Pixel widget recommendations.

## Critical Rules

1. **NEVER recommend a Pixel widget without verifying it exists via MCP.** Every component must be confirmed through `mekari_pixel_list_components()`, `mekari_pixel_query()`, or `mekari_pixel_get()`.
2. **NEVER guess constructor parameters.** Always query `mekari_pixel_get(name: "ComponentName")` for the actual API.
3. **NEVER invent design token values.** Use only documented MpColors, MpSpacing, MpRadius, MpTextStyles.
4. **Output is design specs, not code.** This agent produces ASCII wireframes and Pixel widget recommendations — it does not generate Flutter source code.
5. **Mark unresolved elements explicitly.** If no Pixel component exists for a UI element, mark it `UNRESOLVED` — never substitute or invent.

## Agent Hierarchy

| Agent | Role | Invocable |
|-------|------|-----------|
| `pixel-specialist` | Resolves UI descriptions into verified Pixel component manifest via MCP | Sub-agent only |

## Skills

| Skill | Invocation | Purpose |
|-------|------------|---------|
| `design-ui` | `/design-ui` | Main entry — classifies input, extracts requirements, produces ASCII wireframe + Pixel recommendations |
| `pixel-lookup` | `/pixel-lookup` | Quick Pixel component search and documentation lookup |

## MCP Tools

| Tool | Use |
|------|-----|
| `mekari_pixel_list_components` | Get full canonical component registry |
| `mekari_pixel_query` | Semantic search for components by description |
| `mekari_pixel_get` | Get full docs for a specific component by exact name |
| `mekari_pixel_compare_versions` | Compare component changes between versions |
| `mekari_pixel_list_available_versions` | List documented versions |
| Figma MCP (optional) | Fetch design context and screenshots from Figma URLs |

## Scope

- **Design specs only.** Output is ASCII wireframes + Pixel widget recommendations. No Flutter code.
- **Mekari Pixel exclusively.** All widget recommendations must come from the Pixel design system.
- **Mobile only.** Flutter Android/iOS. No web, no desktop.
