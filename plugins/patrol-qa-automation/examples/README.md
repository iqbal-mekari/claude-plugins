# Examples

This directory contains sample artifacts illustrating the pipeline's input/output format.

## Files

| File | Description |
|------|-------------|
| `sample_input_test_cases.csv` | Example CSV output from `qa-test-case-generator` (Gate 1 output) |
| `sample_output_testcase.dart` | Example Patrol atomic testcase Dart file (Phase 3 output) |
| `sample_output_scenario.dart` | Example Patrol scenario Dart file orchestrating testcases (Phase 3 output) |

## Pipeline Walkthrough

```
1. User provides: Jira ticket QON-1234 (Login feature)
       ↓
2. qa-test-case-generator → sample_input_test_cases.csv
       ↓
3. 🚦 GATE 1: Human reviews CSV, approves
       ↓
4. patrol-test-creator reads CSV, produces mapping table
       ↓
5. 🚦 GATE 2: Human confirms mapping table
       ↓
6. patrol-testcase-writer → sample_output_testcase.dart (×N files)
   patrol-scenario-composer → sample_output_scenario.dart
       ↓
7. Test files are generated and execution starts automatically
       ↓
8. mcp_patrol_mcp_run executes tests
       ↓
9. patrol-test-debugger auto-fixes failures (self-healing)
```
