# Feature Flag Cleanup — Pipeline Overview

## Cleanup Flow

```
┌─────────────────────────────────────────────────────────────┐
│  User Input                                                 │
│  flag name + action (graduate/drop) + repo path             │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Phase 1: Discovery                                         │
│  grep flag string → find constant → trace all references    │
│  categorize: code / config / tests / docs                   │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Phase 2: Code Transformation                               │
│  Apply graduate/drop logic to each usage                    │
│  Reference: cleanup-patterns.md (10 patterns)               │
│  Skip ambiguous cases with TODO comments                    │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Phase 3: Cascade Cleanup                                   │
│  Run analyzer → fix warnings → repeat until clean           │
│  (dead imports, unused vars, empty blocks, orphaned files)  │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Phase 4: Config & Registry Cleanup                         │
│  Remove flag constant, registration, Firebase config, UI    │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Phase 5: Test Cleanup                                      │
│  Graduate: unwrap flag-ON tests, delete flag-OFF tests      │
│  Drop: delete flag-ON tests, unwrap flag-OFF tests          │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Phase 6: Documentation Cleanup                             │
│  Remove flag refs from README, CHANGELOG, comments          │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Phase 7: Verification & Summary                            │
│  Baseline tests → run tests → compare → generate report     │
└─────────────────────────────────────────────────────────────┘
```

## Invocation Examples

**Graduate a flag (feature is permanently enabled):**
```
/cleanup-feature-flag flag_mod_xpm_travel graduate /path/to/your-app
```

**Drop a flag (feature is being removed):**
```
/cleanup-feature-flag flag_dev_experiment_42 drop /path/to/your-app
```
