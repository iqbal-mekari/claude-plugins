# Flutter Semantics for Patrol Testing

This reference covers how to properly wrap Flutter widgets with Semantics for reliable Patrol testing.

## Why Semantics?

Patrol interacts with your app through Flutter's test framework and native accessibility services. Flutter's `Semantics` widget allows you to:

1. Expose widgets to accessibility services
2. Provide stable identifiers that survive localization
3. Make widgets findable even without visible text

## Basic Semantics Wrapping

### Adding an Identifier

```dart
// Icon button without text
Semantics(
  identifier: 'settings_button',
  child: IconButton(
    icon: Icon(Icons.settings),
    onPressed: () => _openSettings(),
  ),
)
```

Access in Patrol:

```dart
$(#settings_button).tap();
```

### Container Semantics

When a widget contains text that Patrol can't detect:

```dart
// Custom card with text that might not be exposed
Semantics(
  container: true,
  child: Card(
    child: Column(
      children: [
        Text('Card Title'),
        Text('Card Description'),
      ],
    ),
  ),
)
```

This makes the entire card (including its text) detectable:

```dart
expect($('Card Title'), findsOneWidget);
expect($('Card Description'), findsOneWidget);
```

### Combined Identifier and Container

```dart
Semantics(
  identifier: 'product_card',
  container: true,
  child: ProductTile(product: product),
)
```

## Common Widget Patterns

### FloatingActionButton

```dart
Semantics(
  identifier: 'add_item_fab',
  child: FloatingActionButton(
    onPressed: _addItem,
    child: Icon(Icons.add),
  ),
)
```

### BottomNavigationBar Item

```dart
BottomNavigationBar(
  items: [
    BottomNavigationBarItem(
      icon: Icon(Icons.home),
      label: 'Home',
      // Already has text - no Semantics needed
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.settings),
      label: 'Settings',
      // Already has text - no Semantics needed
    ),
  ],
)
```

### Custom Button Widget

```dart
class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.identifier,
    required this.label,
    required this.onPressed,
  });

  final String identifier;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: identifier,
      container: true,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
```

### ListTile with Trailing Icon

```dart
Semantics(
  identifier: 'delete_list_tile',
  child: ListTile(
    title: 'Delete Item',
    trailing: Icon(Icons.delete),
    onTap: () => _deleteItem(),
  ),
)
```

### TextField with Identifier

```dart
Semantics(
  identifier: 'search_field',
  child: TextField(
    decoration: InputDecoration(
      hintText: 'Search...',
      prefixIcon: Icon(Icons.search),
    ),
    onChanged: _onSearchChanged,
  ),
)
```

## Multi-Language Support

When supporting multiple languages, use identifiers instead of text:

```dart
// DON'T: Text-based finder will break with localization
// $('Submit').tap();  // Fails in Spanish app

// DO: Use semantic identifiers
Semantics(
  identifier: 'submit_button',
  child: ElevatedButton(
    onPressed: _submit,
    child: Text(AppLocalizations.of(context).submit), // "Submit", "Enviar", etc.
  ),
)
```

```dart
// Patrol test works regardless of language
$(#submit_button).tap();
```

## Debugging Tips

### Check if Semantics is Applied

1. Use Flutter's accessibility inspector:
   - Run app in debug mode
   - Open accessibility inspector in devtools
   - Verify identifier appears in accessibility tree

2. Use Patrol's native-tree command via MCP:
   ```
   mcp_patrol_mcp_native-tree
   ```
   This shows what Patrol can see.

### Common Issues

| Issue                            | Cause                         | Fix                                                 |
| -------------------------------- | ----------------------------- | --------------------------------------------------- |
| Patrol can't find element        | No Semantics, no visible text | Add Semantics with identifier                       |
| Text visible but not detectable  | Widget doesn't expose text    | Add `container: true`                               |
| Multiple matches                 | Finder not unique             | Use ancestor chaining or add unique identifier      |
| Works in debug, fails in profile | Proguard strips semantics     | Configure proguard rules                            |

## ProGuard Configuration

If using ProGuard, preserve semantic identifiers:

```proguard
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep semantic identifiers
-keepattributes *Annotation*
-keep class com.your.package.** { *; }
```

## Reusable Semantics Wrapper Widget

```dart
class TestableWidget extends StatelessWidget {
  const TestableWidget({
    super.key,
    required this.identifier,
    this.container = false,
    required this.child,
  });

  final String identifier;
  final bool container;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: identifier,
      container: container,
      child: child,
    );
  }
}

// Usage
TestableWidget(
  identifier: 'login_button',
  container: true,
  child: ElevatedButton(...),
)
```