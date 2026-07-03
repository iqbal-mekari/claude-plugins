# Patrol Wait Strategies (Shared Reference)

This is the single source of truth for the real-vs-simulated clock distinction in Patrol tests — when to use `pumpUntil`, `pumpUntilReal`, `pumpAndSettle()`, or a bounded custom loop. Read this before writing any wait/timing logic.

## The Core Insight: Two Clocks, One Test

A Patrol test runs inside the Flutter test binding, which has its **own fake scheduler clock**. `$.pump(Duration)` advances that fake clock and triggers exactly one frame — it does **not** burn real wall-clock time, no matter how long the `Duration` argument is or how many times you call it.

This matters because plenty of things a test waits on do **not** live on the fake clock:

- A real HTTP round-trip (API call, auth flow, data fetch)
- A BLoC/Cubit event fired from `initState` that awaits a repository call
- A stream emission coming from a socket, timer backed by real OS I/O, or platform channel

These all need actual wall-clock time to complete outside the Flutter test binding. Pumping the fake clock 100 times with `Duration(seconds: 1)` each does not make an in-flight `http.get()` finish any faster — the request is still sitting on a real socket, waiting on a real server, in real time. If your wait condition depends on genuine async I/O, `$.pump` alone will spin forever without ever seeing the result.

**Rule of thumb:** if the condition your test is waiting on depends only on the widget tree re-rendering after work that already completed, `$.pump` (via `pumpUntil`, below) is enough. If it depends on something still in flight over real I/O, you need a helper that burns real time (`pumpUntilReal`, below).

---

## When `pumpAndSettle()` Never Settles

`pumpAndSettle()` keeps pumping frames until the scheduler reports no more frames are scheduled. That condition never arrives if something keeps scheduling frames indefinitely:

- WebView activity (embedded browser views schedule their own frames)
- Streaming content (chat responses, live data feeds)
- Continuous or looping animations (spinners, shimmer/skeleton loaders, marquee text)
- Ongoing BLoC/Cubit activity (e.g. a polling stream or a retry loop still running)

In any of these situations, a bare `pumpAndSettle()` call can hang **forever** — there is no internal timeout that saves you; it keeps pumping until the settle condition is met, which it never is.

**Rule:** never call bare `pumpAndSettle()` after triggering one of the situations above. Use a bounded `for` loop of `$.pump(Duration)` calls with an explicit exit condition and a hard maximum iteration count instead:

```dart
bool done = false;
for (var i = 0; i < 20 && !done; i++) {
  await $.pump(const Duration(milliseconds: 500));
  done = $('Expected result').exists;
}
```

This gives the animation/stream/WebView time to progress on each pump, while guaranteeing the loop exits even if `done` never flips true.

---

## `pumpUntil` — Widget-Tree State Only

Use `pumpUntil` when the condition depends **only** on the widget tree changing state that has already resolved — a local `setState` flag flipping, a synchronous Bloc state transition, a rebuild after a value already in memory. No real async dependency, no real time burned.

```dart
/// Polls [ready] by repeatedly pumping frames — for conditions that depend
/// ONLY on the widget tree (e.g. a local `setState` flag, a Bloc state that
/// updates synchronously). Burns virtually no real wall-clock time.
Future<bool> pumpUntil(
  PatrolIntegrationTester $,
  bool Function() ready, {
  int maxSeconds = 20,
}) async {
  for (var i = 0; i < maxSeconds; i++) {
    if (ready()) return true;
    await $.pump(const Duration(seconds: 1));
  }
  return ready();
}
```

The iteration count is bounded by `maxSeconds`, so a broken predicate fails fast instead of looping indefinitely — but remember, because `$.pump` doesn't burn real time, this loop itself completes almost instantly regardless of `maxSeconds`. If `ready()` depends on real async work, this function will simply exhaust its iterations and return `false` without ever giving the async work a chance to finish. That's your signal to reach for `pumpUntilReal` instead.

---

## `pumpUntilReal` — Real Async/Network Conditions

Use `pumpUntilReal` when the condition depends on real wall-clock time — a network response, a BLoC event awaiting a repository call fired from `initState`, or any other genuine async I/O. It burns real time via a deliberate native-wait trick:

```dart
/// Pumps until [ready] returns true, burning REAL wall-clock time.
/// Use for conditions that depend on real HTTP/BLoC-in-initState, which
/// $.pump alone cannot wait for (it advances the fake clock only).
Future<bool> pumpUntilReal(
  PatrolIntegrationTester $,
  bool Function() ready, {
  int maxSeconds = 20,
  int realBurnMs = 2000,
}) async {
  final iterations = (maxSeconds * 1000 / realBurnMs).ceil();
  for (var i = 0; i < iterations; i++) {
    await $.pump(const Duration(milliseconds: 100));
    if (ready()) return true;
    try {
      // This selector never matches, so it burns ~realBurnMs of REAL time.
      await $.native.waitUntilVisible(
        Selector(text: '__pumpUntilReal_dummy__'),
        timeout: Duration(milliseconds: realBurnMs),
      );
    } catch (_) {}
    if (ready()) return true;
  }
  return ready();
}
```

**Why this trick works:** `$.native.waitUntilVisible` asks the native UI automator (Espresso/XCUITest under the hood) to find a selector, blocking for up to `timeout` of **real** wall-clock time before giving up and throwing. By pointing it at a selector that will never exist (`__pumpUntilReal_dummy__`), we get a real-time-bounded sleep for free — the native layer blocks for the full timeout looking for something that isn't there, throws when it can't find it, and we catch that exception and re-check `ready()`. It is a deliberate abuse of a real-time-bounded native wait to get sleep-like behavior inside a Patrol test, since Dart's own `Future.delayed`/`sleep` calls are not meaningful ways to advance the Flutter test binding's clock in this context.

---

## Decision Table

| Situation | Use |
|-----------|-----|
| Pure widget-tree state change (e.g. a local `setState` flag flips after a rebuild) | `pumpUntil` |
| Network/async/BLoC-in-`initState` condition | `pumpUntilReal` |
| Waiting for a native/platform UI element to appear | `$.native.waitUntilVisible(...)` |
| Waiting for a Flutter element with a bounded timeout | `$.waitUntilVisible($(...), timeout: ...)` |
| WebView, streaming content, or continuous/looping animation completion | Never a bare `pumpAndSettle()` — use a bounded `$.pump(Duration)` loop with an explicit exit condition |

---

## Timeout Conventions

- **Short waits (~2-5s):** local UI transitions, dialog open/close, simple navigation — these resolve on the fake clock or after a near-instant rebuild.
- **Longer ceilings (~15-20s):** anything network-dependent — page loads, form submissions, data fetches on screen entry.
- **Always bound the loop.** Every custom wait — `pumpUntil`, `pumpUntilReal`, or a hand-rolled `for` loop — must have an explicit max-iteration or max-seconds cap. An unbounded wait doesn't just fail the test; it hangs the whole CI runner until an external job-level timeout kills the run, wasting the full CI time budget instead of failing fast with a clear diagnostic.

---

## Common Pitfalls

| Pitfall | Consequence |
|---------|-------------|
| Bare `pumpAndSettle()` right after triggering a network call | Hangs indefinitely — the request keeps the widget tree active (or a WebView keeps scheduling frames), so the settle condition is never met |
| Using `pumpUntil` for a condition that depends on real async work | The loop pumps the fake clock repeatedly, but the underlying `Future`/HTTP response never resolves inside it, so `ready()` never flips true — it just burns through `maxSeconds` and returns `false` having made zero real progress |
| Forgetting a max-iteration / max-seconds bound on a custom wait loop | A broken predicate loops forever, hanging the test process and, by extension, the CI job until an external timeout force-kills the run |
| Assuming `$.pump(Duration)` advances real `Timer`/`Future.delayed` calls backed by genuine async I/O | It only advances the Flutter test binding's fake scheduler clock — real OS-backed I/O (sockets, HTTP clients, platform channels) is unaffected and still needs real wall-clock time to complete |
| Setting `realBurnMs` too high on `pumpUntilReal` | Wastes real CI minutes per iteration even when the condition resolves quickly — keep it in the 1-3s range and let the iteration count (`maxSeconds`) provide the overall ceiling |

---

## Closing Note

These helpers belong in `integration_test/helpers/` in the app under test, alongside the rest of the shared test scaffolding (login helpers, navigation helpers, etc.). A copy-adaptable template already wires up `pumpUntil`, `pumpUntilReal`, and related helpers — see [`../create-patrol-test/references/test-helpers.dart`](../create-patrol-test/references/test-helpers.dart) in this plugin.
