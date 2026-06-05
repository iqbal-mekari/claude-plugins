# Designer Agent Examples

This directory contains sample inputs and outputs demonstrating the designer agent pipeline.

## Pipeline Overview

```
Input (Figma / Image / Text)
  │
  ▼
Step 1: Classify input type
  │
  ▼
Step 2: Extract structured UI requirements
  │
  ▼
Step 3: pixel-specialist resolves → Verified Component Manifest
  │
  ▼
Step 4: ASCII wireframe + Design spec + Widget recommendations
```

## Files

| File | Description |
|------|-------------|
| `sample_input.txt` | Example text-based requirement for a screen |
| `sample_output.md` | Example design spec output (ASCII wireframe + Pixel recommendations) |

## How to Use

### Text requirement
```
/design-ui "Create an invoice creation screen with fields for client name, amount, due date, and notes. Include a submit button at the bottom."
```

### Image
```
/design-ui [attach screenshot]
```

### Figma
```
/design-ui https://www.figma.com/design/abc123/MyDesign?node-id=1-2
```
