# Human-in-the-Loop Confirmation Gate

This document defines the explicit approval checkpoints where a human must confirm before the pipeline proceeds to the next phase.

## Pipeline Flow with Gates

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│  Phase 1: Test Case Generation                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                         │
│  Input: PRD / Jira ticket / Figma / Codebase / Existing CSV             │
│       ↓                                                                 │
│  Skill: create-test-cases / regenerate-test-cases / impact-analysis     │
│       ↓                                                                 │
│  Output: CSV in /test-cases/ + Jira comment                             │
│                                                                         │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │   🚦 GATE 1         │
                    │   Human reviews     │
                    │   generated test    │
                    │   cases CSV         │
                    │                     │
                    │   ✅ Approve        │
                    │   ✏️  Request edits  │
                    │   ❌ Reject         │
                    └──────────┬──────────┘
                               │ (only on ✅ Approve)
                               │
┌──────────────────────────────▼──────────────────────────────────────────┐
│                                                                         │
│  Phase 2: Automation Triage & Mapping                                   │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                         │
│  Agent: patrol-test-creator (planning stage)                            │
│       ↓                                                                 │
│  Output: Mapping table (CSV TC → Patrol test file, automate/skip/setup)  │
│                                                                         │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │   🚦 GATE 2         │
                    │   Human reviews     │
                    │   mapping table     │
                    │                     │
                    │   ✅ Confirm mapping │
                    │   ✏️  Adjust entries  │
                    │   ❌ Cancel          │
                    └──────────┬──────────┘
                               │ (only on ✅ Confirm)
                               │
┌──────────────────────────────▼──────────────────────────────────────────┐
│                                                                         │
│  Phase 3: Patrol Test Generation                                        │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                         │
│  Agent: patrol-test-creator → invokes:                                  │
│    • create-patrol-testcase skill (per testcase)                        │
│    • compose-patrol-scenario skill (per scenario)                       │
│       ↓                                                                 │
│  Output: Dart files in patrol_test/testcases/ and patrol_test/scenarios/ │
│                                                                         │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────────┐
│                                                                         │
│  Phase 4: Execution & Self-Healing                                      │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                         │
│  Agent: patrol-test-debugger (if failures occur)                        │
│    • Runs tests automatically after Dart test generation                │
│    • Screenshots + hierarchy inspection                                 │
│    • Auto-fixes selectors (self-healing)                                │
│    • Re-runs to verify fix                                              │
│       ↓                                                                 │
│  Output: Fixed Dart test files + updated failure-patterns.md            │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Gate Definitions

### Gate 1: Test Case Approval

**When:** After `create-test-cases`, `regenerate-test-cases`, or `impact-analysis` skill produces output.

**What the human reviews:**
- Completeness — are all features/requirements covered?
- Correctness — do steps match actual app behavior?
- Priority — are Smoke vs Regression categories correct?
- Scope — no out-of-scope API/backend test cases?

**Skill behavior:**
1. Present the generated test cases summary (count by category, coverage map).
2. Explicitly ask: _"Please review the test cases in `{csv_path}`. Shall I proceed to Patrol test creation, or would you like changes?"_
3. Wait for user response before proceeding.

**If edits requested:** Regenerate affected test cases and re-present for approval.

---

### Gate 2: Mapping Table Confirmation

**When:** After `patrol-test-creator` produces the triage/mapping table.

**What the human reviews:**
- Which test cases will be automated vs skipped
- Screen → folder mapping correctness
- Testcase file naming
- Any "needs setup" items that require Flutter code changes

**Agent behavior:**
1. Present the mapping table in a readable format.
2. Explicitly ask: _"Please confirm this mapping table. Should I proceed with writing the Patrol test files?"_
3. Wait for user response before delegating to sub-agents.

**If adjustments:** Update mapping entries and re-present.

---

## Implementation Rules for Agents and Skills

1. **Never skip gates 1 and 2.** Those gates are mandatory — agents and skills must pause and wait for human input.
2. **Present context.** Always show enough information at the gate for the human to make an informed decision (file paths, counts, key decisions made).
3. **No silent progression.** An agent or skill must not proceed from Phase 1 to Phase 2 or Phase 2 to Phase 3 without the human explicitly saying "proceed", "confirm", "yes", or equivalent.
4. **Loop on edits.** If the human requests changes at gates 1 or 2, the agent/skill applies them and re-presents for approval at the same gate.
5. **Record decisions.** After each gate approval, log the decision (what was approved and any modifications requested) in the session context for traceability.
