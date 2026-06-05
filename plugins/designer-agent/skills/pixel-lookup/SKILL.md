---
name: pixel-lookup
description: Quick search for Mekari Pixel components. Look up component documentation, check if a component exists, or find the right component for a use case. Triggers on: "pixel lookup", "find component", "search components", "show me pixel", "what components", "component docs", "is there a component for", "what widget for", or when the user wants to explore the Mekari Pixel design system.
---

# Pixel Lookup

Quick search and documentation lookup for Mekari Pixel components.

## When to Use

- User asks "is there a component for X?"
- User wants to see all available components
- User wants documentation for a specific component
- User wants to find the right component for a use case
- User asks about Mekari Pixel design tokens, colors, spacing, etc.

## Prerequisites Check

Before proceeding, verify the Mekari Pixel MCP server is available by calling `mekari_pixel_list_components()`.

If the MCP server is not available:
1. Check if `.mcp.json` exists and has the `mobile-pixel-mcp` server configured
2. If the token is `<SECRET_TOKEN>` or missing, ask the user:

> "The Mekari Pixel MCP server requires authentication. Please provide your API token so I can update `.mcp.json`."

3. Once the user provides the token, update `.mcp.json` and inform the user to restart MCP with `/mcp`.

## Steps

### Step 1 — Parse Query

Determine the query type:

| Query Pattern | Action |
|---------------|--------|
| Starts with `Mp` or looks like a component name | `mekari_pixel_get(name: "<name>")` |
| "list all", "show all", "all components", category name | `mekari_pixel_list_components()` |
| Use case description | `mekari_pixel_query(query: "<user query>", n_results: 10)` |

### Step 2 — Execute Search

**For component name lookup:**
```
mekari_pixel_get(name: "MpButton")
```
Returns full documentation including constructor, parameters, variants.

**For listing all components:**
```
mekari_pixel_list_components()
```
Returns list of all components with kind, name, library, file_name.

**For semantic search:**
```
mekari_pixel_query(query: "notification banner that shows success messages", n_results: 5)
```
Returns ranked results with similarity scores.

### Step 3 — Format Results

For each component found, display:

```markdown
## <ComponentName>

- **Kind**: class / enum / mixin
- **Tier**: Atom / Component / Template / Page
- **Library**: mekari_pixel / mekari_pixel_icons / mekari_pixel_illustrations
- **File**: <file_name>

### Constructor
<constructor signature from MCP response>

### Key Parameters
<list of important parameters with types>

### Description
<description from MCP response>

### Variants
<list of variants/factories if applicable>
```

### Step 4 — Offer Follow-up

After presenting results:
- "Want me to look up a specific component's full API?"
- "Want me to design a screen using this component? Use `/design-ui` for that."
- "Want to see related components?"

## Example Interactions

**User**: "What button components are available?"
-> Call `mekari_pixel_query(query: "button", n_results: 10)`
-> Display MpButton (primary/secondary/tertiary/ghost/danger), MpButtonIcon, MpIconButton, MpFloatingActionButton

**User**: "MpToast"
-> Call `mekari_pixel_get(name: "MpToast")`
-> Display full docs including all variants (done/error/greetings/information/warning)

**User**: "Show me all atoms"
-> Call `mekari_pixel_list_components()`
-> Filter and display components where tier = Atom

**User**: "What component should I use for a date range picker?"
-> Call `mekari_pixel_query(query: "date range picker", n_results: 5)`
-> Display MpDatePickerField, MpDatePickerRangeField, MpDatePicker with recommendations

**User**: "Is there a card component?"
-> Call `mekari_pixel_query(query: "card", n_results: 5)`
-> Report: No dedicated MpCard exists. Recommend using Flutter's Card widget styled with MpRadius.large + MpElevations.xs + MpColors.bg.surface
