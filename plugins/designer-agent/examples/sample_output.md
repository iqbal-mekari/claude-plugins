# Design Spec: Invoice Creation Screen

## UI Requirements

### Screen: New Invoice
### Purpose: Create a new invoice by filling in client, amount, date, and optional notes

### Layout
- Top: App bar with back navigation, screen title, save action
- Body: Scrollable form with labeled input fields
- Bottom: Full-width primary CTA button (sticky)

### Elements
1. App bar — title "New Invoice", back button, save action
2. Text field — client name, required, text input
3. Text field — amount, required, numeric with Rp prefix
4. Date picker field — due date, required, opens native picker
5. Text field — notes, optional, multiline
6. Button — primary, full-width, "Create Invoice"

---

## Verified Component Manifest

### Screen: New Invoice

| UI Element | Component | Tier | Library | Key Parameters | Variants / Notes |
|---|---|---|---|---|---|
| Screen layout | MpBasicLayout | Template | mekari_pixel | appBar, body, bottomNavigationBar | Wraps content in safe area |
| App bar | MpTextAppBar | Component | mekari_pixel | title, leading, actions | Leading = back button, actions = save |
| Client name field | MpTextField | Atom | mekari_pixel | label, hint, required, controller | Standard text field |
| Amount field | MpTextField | Atom | mekari_pixel | label, hint, prefix, textInputType, required | prefix = Text("Rp "), keyboardType = number |
| Due date field | MpDatePickerField | Component | mekari_pixel | label, onDateSelected, firstDate, lastDate | Read-only, opens picker on tap |
| Notes field | MpTextField | Atom | mekari_pixel | label, hint, minLines, maxLines | Multiline, not required |
| Submit button | MpButton | Atom | mekari_pixel | label, onPressed | MpButton.primary(), full-width |

### Design Tokens Referenced

| Token | Value | Usage Context |
|---|---|---|
| MpColors.bg.surface | semantic surface | Screen background |
| MpColors.text.primary | primary text | Labels, headings |
| MpColors.text.secondary | secondary text | Hints, placeholders |
| MpColors.text.subtle | subtle text | Optional field labels |
| MpColors.border.subtle | subtle border | Input field borders |
| MpSpacing.medium | 16dp | Section padding, field spacing |
| MpSpacing.small | 12dp | Between label and field |
| MpSpacing.large | 20dp | Bottom button padding |
| MpRadius.medium | 6dp | Input field corners |
| MpTextStyles.md | 16/24 w400 | Field labels |
| MpTextStyles.sm | 14/20 w400 | Field hints |

### UNRESOLVED

None — all elements have Pixel equivalents.

---

## ASCII Wireframe

```
┌─────────────────────────────────────────┐
│  ← New Invoice                   [Save] │  MpTextAppBar
├─────────────────────────────────────────┤
│                                         │
│  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐  │
│                                         │
│    Client Name *                        │  MpTextField (required)
│  │ ┌───────────────────────────────┐ │  │
│    │ Enter client name...          │    │
│  │ └───────────────────────────────┘ │  │
│                                         │
│    Amount *                             │  MpTextField (prefix: Rp)
│  │ ┌───────────────────────────────┐ │  │
│    │ Rp 0                          │    │
│  │ └───────────────────────────────┘ │  │
│                                         │
│    Due Date *                           │  MpDatePickerField
│  │ ┌───────────────────────────────┐ │  │
│    │ Select date              📅   │    │
│  │ └───────────────────────────────┘ │  │
│                                         │
│    Notes                                │  MpTextField (multiline)
│  │ ┌───────────────────────────────┐ │  │
│    │                               │    │
│    │                               │    │
│  │ └───────────────────────────────┘ │  │
│                                         │
│  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘  │
│                                         │
├─────────────────────────────────────────┤
│  ┌───────────────────────────────────┐  │
│  │         Create Invoice            │  │  MpButton.primary
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

---

## Design Decisions

### Screen Purpose
Create a new invoice by entering client details, amount, due date, and optional notes.

### Layout Rationale
- **Linear form layout** reduces cognitive load — fields are presented in a natural top-to-bottom flow matching the user's mental model (who → how much → when → notes).
- **Sticky bottom CTA** keeps the primary action always accessible without scrolling, following mobile form conventions.
- **Scrollable body** handles smaller screens or when the keyboard is open.
- **Required fields marked with *** — optional fields have "(optional)" in the hint text instead, reducing visual clutter.

### Component Choices
- **MpTextAppBar** over MpBaseAppBar: provides built-in title text and action slots, cleaner API for this use case.
- **MpTextField** for amount with `prefix: Text("Rp ")`: avoids a separate currency picker component; the prefix makes the currency obvious inline.
- **MpDatePickerField** over raw MpTextField: provides native date picker UX, prevents invalid date input, read-only field avoids keyboard confusion.
- **MpButton.primary** for submit: the primary variant has the highest visual weight, appropriate for the single CTA on this screen.

### Interaction Patterns
- **Field focus**: tapping a field scrolls it into view and opens the keyboard (standard Flutter behavior).
- **Date field tap**: opens the native date picker bottom sheet (MpDatePickerField handles this).
- **Save button**: disabled until required fields are filled; shows MpSpinner on submission.
- **Back navigation**: confirms unsaved changes via MpDialog before navigating away.

### Accessibility & Usability
- All fields have visible labels (not just placeholders) — labels persist when the field is focused.
- Touch targets meet minimum 48dp.
- Error states use MpColors.text.negative for inline validation messages.
- The "optional" hint on Notes prevents users from thinking they missed a required field.
