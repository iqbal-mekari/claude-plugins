---
name: design-ui
description: Convert a design input (text prompt, screenshot, or Figma link) into a purposeful UI/UX design specification with ASCII wireframes and verified Mekari Pixel widget recommendations. Use when the user wants a design spec, wireframe, or component recommendation for a mobile screen. Triggers on: "design this screen", "create wireframe", "recommend pixel widgets", "design spec", "UI design", "UX design", "what components should I use", "design a form/list/detail for", or when the user provides a Figma link or screenshot with design intent.
---

# Design UI

Convert any design input into a purposeful UI/UX design specification: ASCII wireframes + verified Mekari Pixel widget recommendations. No code generation — design specs only.

## When to Use

- User provides a text description of a UI they want designed
- User provides a Figma link to a design
- User provides a screenshot or image of a UI
- User asks "what Pixel components should I use for X?"
- User asks for a wireframe or design spec
- User wants UX recommendations for a mobile screen

## Prerequisites Check

Before proceeding, verify the Mekari Pixel MCP server is available by calling `mekari_pixel_list_components()`.

If the MCP server is not available:
1. Check if `.mcp.json` exists and has the `mobile-pixel-mcp` server configured
2. If the token is `<SECRET_TOKEN>` or missing, ask the user:

> "The Mekari Pixel MCP server requires authentication. Please provide your API token so I can update `.mcp.json`."

3. Once the user provides the token, update `.mcp.json`:
```json
{
  "mcpServers": {
    "mobile-pixel-mcp": {
      "type": "sse",
      "url": "https://mobile-pixel-mcp-546272430844.asia-southeast1.run.app/sse",
      "headers": {
        "Authorization": "Bearer <USER_TOKEN>"
      }
    }
  }
}
```

4. Inform the user: "Token configured. Please restart the MCP server connection with `/mcp` and try again."

---

## Step 1 — Classify Input

Classify the user's input:

| Input Type | Detection |
|------------|-----------|
| Figma URL | Contains `figma.com/design/` or `figma.com/file/` |
| Image | File path ending in `.png`, `.jpg`, `.jpeg`, `.webp`, `.gif` |
| Text prompt | Everything else |

Validation:
- If Figma URL: verify Figma MCP is available (check for `mcp__figma` tools)
- If image path: verify file exists using `Read` tool
- If ambiguous: ask the user to clarify

---

## Step 2 — Extract Design Requirements

Based on input type, extract structured requirements:

### For IMAGE input (screenshot/photo)

Use Claude's native vision — read the image file directly with the `Read` tool, then analyze it:

1. **Layout**: overall pattern (list, form, dashboard, detail, settings), spatial hierarchy (header, body, footer)
2. **Elements**: for each UI element, describe type, content, style hints, position relative to others
3. **Colors**: semantic descriptions only ("blue primary accent", "light gray background") — NEVER hex values
4. **Typography**: hierarchy (large bold heading, medium regular body, small gray caption)
5. **Interactions**: tap targets, scrollable areas, navigation patterns
6. **UX intent**: what is the user trying to accomplish on this screen? What is the primary action?

Output the requirements in this format:

```markdown
## UI Requirements from Image Analysis

### Screen: <descriptive name>
### Purpose: <what the user accomplishes on this screen>

### Layout
- Top: <description>
- Body: <description>
- Bottom: <description>

### Elements
1. <element type> — <content>, <style>, <position>
2. ...

### Colors
- Background: <semantic color>
- Primary accent: <semantic color>
- Text: <semantic color>

### Typography
- Title: <size>, <weight>
- Body: <size>, <weight>

### Interactions
- <interaction description>

### UX Notes
- <purposeful design decisions and rationale>
```

### For FIGMA input

Extract `fileKey` and `nodeId` from the URL (convert `node-id=1-2` to `1:2`), then:
1. Call `get_design_context(fileKey, nodeId, clientLanguages="dart", clientFrameworks="flutter")`
2. Call `get_screenshot(fileKey, nodeId)` for visual reference
3. Parse the response into structured requirements (layout, elements, colors, typography, interactions, UX intent)

### For TEXT input

Parse directly:
- Extract screen name, purpose, layout structure, component descriptions, navigation flow
- Infer UX patterns from the description (e.g., "user fills form" → form with validation, submit button, loading state)
- Structure into the same requirements format as above

---

## Step 3 — Resolve Components (Anti-Hallucination Gate)

Spawn the `pixel-specialist` sub-agent with the structured requirements from Step 2.

```
Agent(
  subagent_type: "pixel-specialist",
  prompt: "Resolve these UI requirements into verified Mekari Pixel components.\n\n<structured requirements from Step 2>",
  isolation: "worktree"
)
```

The pixel-specialist will:
1. Call `mekari_pixel_list_components()` to get the canonical registry
2. For each UI element, call `mekari_pixel_query()` and `mekari_pixel_get()` to find and verify the component
3. Return a **Verified Component Manifest** — a table mapping each UI element to an actual component with tier, constructor, parameters, and variants

<EXTREMELY-IMPORTANT>
You MUST wait for the pixel-specialist to return the manifest before proceeding. The manifest is the ONLY source of truth for which components exist. Do NOT recommend any component that is not in the manifest.
</EXTREMELY-IMPORTANT>

---

## Step 4 — Design the UI/UX

Using the verified manifest from Step 3 and the requirements from Step 2, produce the design specification.

### 4a. ASCII Wireframe

Create a low-fidelity ASCII wireframe showing the screen layout. Use box-drawing characters and clear labels.

Guidelines:
- Show the overall screen structure (app bar, body, bottom bar if applicable)
- Label each region with the component name from the manifest
- Show content hierarchy (title, subtitle, body, actions)
- Indicate scrollable areas
- Show interactive elements with action labels (e.g., [Submit], [Cancel])
- Use `┄┄┄` for dividers, `┌┐└┘` for containers, `│` for vertical separators

Example:

```
┌─────────────────────────────────────────┐
│ ← New Invoice                    [Save] │  MpTextAppBar
├─────────────────────────────────────────┤
│                                         │
│  Client Name                            │  MpTextField
│  ┌─────────────────────────────────┐    │
│  │ Enter client name...            │    │
│  └─────────────────────────────────┘    │
│                                         │
│  Amount                                 │  MpTextField
│  ┌─────────────────────────────────┐    │
│  │ Rp 0                            │    │
│  └─────────────────────────────────┘    │
│                                         │
│  Due Date                               │  MpDatePickerField
│  ┌─────────────────────────────────┐    │
│  │ Select date              📅     │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄  │
│                                         │
│  Notes                                  │  MpTextField (multiline)
│  ┌─────────────────────────────────┐    │
│  │                                 │    │
│  │                                 │    │
│  └─────────────────────────────────┘    │
│                                         │
├─────────────────────────────────────────┤
│  [ Create Invoice ]                     │  MpButton.primary
└─────────────────────────────────────────┘
```

### 4b. Purposeful UI/UX Design Spec

For each section of the screen, explain the UX rationale:

```markdown
## Design Decisions

### Screen Purpose
<What the user accomplishes here. One sentence.>

### Layout Rationale
- **Why this layout pattern?** <e.g., "Linear form layout reduces cognitive load for data entry tasks">
- **Why this element order?** <e.g., "Client name first because it contextualizes all subsequent fields">

### Component Choices
- **<Element>**: <Why this specific Pixel component and variant>
- **<Element>**: <Why this specific Pixel component and variant>

### Interaction Patterns
- **<Action>**: <What happens and why>
- **<State>**: <How the UI communicates state to the user>

### Accessibility & Usability
- <Notes on touch targets, readability, error states>
```

### 4c. Widget Recommendation Table

Combine the verified manifest with UX rationale into a final recommendation:

```markdown
## Recommended Mekari Pixel Widgets

| # | UI Element | Widget | Tier | Variant / Constructor | Design Token(s) | UX Rationale |
|---|---|---|---|---|---|---|
| 1 | Screen layout | MpBasicLayout | Template | MpBasicLayout(appBar:, body:) | MpColors.bg.surface | Standard scaffold with safe area |
| 2 | App bar | MpTextAppBar | Component | MpTextAppBar(title:, actions:) | — | Clear screen title + save action |
| 3 | Text input | MpTextField | Atom | MpTextField(label:, hint:, controller:) | MpTextStyles.sm | Standard form field with validation |
| 4 | Date picker | MpDatePickerField | Component | MpDatePickerField(label:, onDateSelected:) | — | Read-only field opens native picker |
| 5 | Submit button | MpButton | Atom | MpButton.primary(label:, onPressed:) | MpSpacing.medium | Primary CTA, full-width at bottom |

### Design Tokens

| Token | Value | Where Used |
|---|---|---|
| MpColors.bg.surface | screen background | Scaffold |
| MpColors.text.primary | headings | All labels |
| MpColors.text.secondary | hints/placeholder | TextField hints |
| MpSpacing.medium | 16dp | Section padding |
| MpSpacing.small | 12dp | Between fields |
| MpRadius.medium | 6dp | Input field corners |

### UNRESOLVED

| UI Element | Closest Match | Why Unresolved |
|---|---|---|
| <element> | <closest Pixel component> | <reason> |
```

---

## Step 5 — Present and Iterate

Present the complete design spec to the user:

1. ASCII wireframe
2. Design decisions with UX rationale
3. Widget recommendation table
4. Design tokens reference
5. Any UNRESOLVED elements

Then offer iteration:
- "Want me to adjust the layout or element arrangement?"
- "Want me to explore alternative component choices?"
- "Want me to design additional screens or flows?"
- "Want me to look up a specific component's full API with `/pixel-lookup`?"

---

## Error Handling

| Error | Action |
|-------|--------|
| MCP server not available | Ask user for token, update `.mcp.json` |
| Figma MCP not available | Inform user, offer to work from screenshot instead |
| Image file not found | Ask user to verify the file path |
| Pixel-specialist fails | Report error, suggest `/pixel-lookup` to verify components manually |
| No components resolved | Check if MCP server is responding |
| All elements UNRESOLVED | The requirements may be too abstract — ask user for more detail |
