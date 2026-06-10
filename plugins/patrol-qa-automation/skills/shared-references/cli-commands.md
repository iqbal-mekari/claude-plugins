# Patrol CLI Commands Reference (Shared Reference)

Single source of truth for CLI-based device interaction, test execution, and debugging across all skills and agents.

This document replaces the former Patrol MCP server (`patrol_mcp`). All device interaction now uses `patrol` CLI and platform tools directly.

---

## Platform Detection

Before running any platform-specific command, detect the target platform:

1. Check for Android emulator/device: `adb devices` (look for `emulator-*` or `device` status)
2. Check for iOS simulator: `xcrun simctl list devices booted` (look for `Booted` state)
3. If both are running, ask the user which platform to target.
4. Store the detected platform for the session to avoid re-detection.

```bash
# Quick check — run both, use whichever returns a device
adb devices
xcrun simctl list devices booted
```

---

## View Hierarchy (PRIMARY debugging tool)

This is the **primary** tool for selector discovery and debugging. Always start here.

### Android

```bash
adb shell uiautomator dump /sdcard/window_dump.xml && adb pull /sdcard/window_dump.xml /tmp/window_dump.xml && cat /tmp/window_dump.xml
```

**Output:** XML with node attributes:
- `text` — visible text content
- `resource-id` — Android resource ID (maps to Semantics identifier)
- `class` — Android widget class (e.g., `android.widget.TextView`)
- `content-desc` — content description (accessibility label)
- `bounds` — element position `[left,top][right,bottom]`
- `clickable`, `enabled`, `focused` — interaction states

**Parsing tips:**
- Search for `text="Login"` to find elements by visible text
- Search for `resource-id="com.example.app:id/emailField"` to find by ID
- Check `bounds` to understand element positioning and overlaps

### iOS (Simulator)

```bash
xcrun simctl spawn booted accessibility audit / --output /tmp/ax_tree.json 2>/dev/null
cat /tmp/ax_tree.json
```

If `accessibility audit` is unavailable, use `idb`:

```bash
idb ui describe-all --udid $(xcrun simctl list devices booted | grep -oE '[A-F0-9-]{36}' | head -1)
```

**Output:** JSON with element tree:
- `label` — accessibility label
- `value` — current value (text content, toggle state)
- `type` — element type (e.g., `StaticText`, `Button`, `TextField`)
- `identifier` — accessibility identifier (maps to Semantics identifier)
- `frame` — element position and size
- `enabled`, `focused` — interaction states

**Parsing tips:**
- Search for `"label": "Login"` to find elements by visible text
- Search for `"identifier": "emailField"` to find by Semantics identifier
- Check `frame` for element positioning

---

## Screenshots (LAST RESORT only)

**IMPORTANT:** Screenshots should ONLY be used when view hierarchy dumps are insufficient:
- Visual layout problems (overlapping, clipping, z-order)
- Dialog/overlay detection that hierarchy cannot resolve
- Color/visual state issues
- Confirming what the user sees on screen when hierarchy is ambiguous

### Android

```bash
adb shell screencap -p /sdcard/screenshot.png && adb pull /sdcard/screenshot.png /tmp/screenshot.png
```

### iOS (Simulator)

```bash
xcrun simctl io booted screenshot /tmp/screenshot.png
```

After capturing, use the `Read` tool to view the screenshot at `/tmp/screenshot.png`.

---

## Test Execution

### Run a single test file

```bash
patrol test --target <file_path>
```

Example:
```bash
patrol test --target patrol_test/testcases/login/tap_login_button.dart
```

### Run with develop mode (hot-restart capable)

```bash
patrol develop --target <file_path>
```

### Run all tests

```bash
patrol test
```

### Run specific tests by tag

```bash
patrol test --tags='smoke'
patrol test --exclude-tags='slow'
```

**Output:** stdout/stderr with:
- Pass/fail per test
- Dart stack traces on failure
- Patrol assertion errors (selector not found, timeout, etc.)

---

## Device Management

### List connected devices (Patrol-aware)

```bash
patrol devices
```

### Fallback — Flutter device list

```bash
flutter devices
```

### Android-specific

```bash
adb devices
```

### iOS-specific

```bash
xcrun simctl list devices booted
```

---

## Flutter Widget Tree (Complementary)

For Flutter-specific debugging beyond native hierarchy. Use when the native accessibility tree doesn't expose enough Flutter widget detail.

### Option 1: Debug helper test

Write a Patrol test that calls `debugDumpApp()` and prints to console:

```dart
import 'package:flutter/rendering.dart';

Future<void> dumpWidgetTree(PatrolIntegrationTester $) async {
  await $.pumpWidgetAndSettle(const MyApp());
  debugDumpApp(); // Prints widget tree to console
}
```

Run it via `patrol test --target <helper_file>` and parse the console output.

### Option 2: Parse patrol test stderr

The `patrol test` command outputs Dart framework errors, assertion failures, and widget tree information in its stderr. When a test fails, the error output often includes the relevant widget subtree.

---

## MCP-to-CLI Mapping

| Former MCP Tool | CLI Replacement | Notes |
|---|---|---|
| `mcp_patrol_mcp_run` | `patrol test --target <file>` | stdout/stderr for output |
| `mcp_patrol_mcp_native-tree` | `adb shell uiautomator dump` / `idb ui describe-all` | **PRIMARY** debugging tool |
| `mcp_patrol_mcp_screenshot` | `adb shell screencap` / `xcrun simctl io booted screenshot` | **LAST RESORT** only |
| `mcp_patrol_mcp_status` | `patrol devices` or `flutter devices` | Device/session check |
| `mcp_patrol_mcp_quit` | Not needed | CLI process exits naturally |
