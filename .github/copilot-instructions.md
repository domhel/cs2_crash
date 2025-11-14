# Copilot Instructions

## Architecture snapshot
- `lib/app_state.dart` holds all game mechanics in a singleton `AppState` (`ChangeNotifier`), tracking coins, bets, RNG timer state, and UX flags; treat it as the sole source of truth and mutate via its methods.
- The crash curve uses a `Timer.periodic` loop updating `currentFactor` with `pow(e, i / 100 / slowDown)` and a Bernoulli crash chance (`p = 1 / 68.5 / 20`); any gameplay tweaks must keep RNG + timer cadence aligned so listeners stay smooth.
- UI lives in `lib/main.dart` and is a single `Scaffold` with a hero factor display and a persistent `BottomSheet`; it watches `AppState.instance` through `ListenableBuilder` and rebuilds entirely when state changes.

## Core files & data
- `lib/main.dart`: assembles the Material app, theme, and cash-out button logic (switch expressions map `GameState` to button states).
- `lib/app_state.dart`: exposes `play(double bet)`, `cashOut()`, and `stop()`; it debits coins up front, only allows `bet <= coins`, and expands the coins label via `isCoinsTextExpanded` for win animations.
- `assets/icon*.png`: launcher icon sources; referenced by the `flutter_launcher_icons` block in `pubspec.yaml`.

## Workflows
- Install/update deps: `flutter pub get` (run after editing `pubspec.yaml`).
- Run the app: `flutter run -d macos` (desktop)
- Static checks/tests: `flutter analyze` and `flutter test`; there are no custom scripts, so keep additions fast and deterministic.
- Refresh platform icons when `assets/icon*.png` changes: `flutter pub run flutter_launcher_icons`.

## Patterns & conventions
- Access global state through `AppState.instance`; wrap new widgets with `ListenableBuilder`/`AnimatedBuilder` instead of introducing a second state source.
- Respect `GameState` transitions: `idle -> playing -> crashed` or `idle -> playing -> (cashOut)`; UI actions should guard on `cashedOut`/`crashed` exactly as the bottom button does.
- Use `notifyListeners()` after every mutation so the sheet and factor display stay synced; avoid long synchronous work inside the timer callback to keep 120 FPS updates.
- Persist lightweight flags via `SharedPreferences` (key `hasAskedForFeedback_v1`) and request reviews through `InAppReview` only after successful cash-outs (`cashOutCount >= 2`).
- Haptics/vibration guard: check `_hasVibrator` before calling `Vibration.vibrate()` and chain `HapticFeedback` futures as shown to stage medium/heavy impacts.

## Integration gotchas
- `Vibration.hasVibrator()` and `SharedPreferences.getInstance()` are kicked off in the private constructor; keep the singleton lazy-init pattern if adding async setup.
- The crash loop cancels the timer on both `crashed` and `cashOut`; forgetting to cancel leaks timers and keeps the UI stuck in `GameState.playing`.
- Keep currency math in doubles with `toStringAsFixed(2)` formatting; introduce new currency displays by reusing `TextTheme.headlineSmall` + tabular figures for consistent alignment.
- `fl_chart` is already declared—reuse it for history/analytics instead of pulling a new charting package.

## Feature tips
- When adding charts or stats, feed them from `AppState` fields (e.g., `cashOutCount`, `currentFactor`) and consider extending the notifier with immutable view models so rebuilds stay coarse-grained.
- To introduce settings, create methods on `AppState` that update prefs + local fields, then consume them via the same `ListenableBuilder` tree to avoid prop drilling.
- Platform code (Android/iOS/macOS) is untouched; prefer Dart-side plugins first and document any native changes inside the respective platform folders.
