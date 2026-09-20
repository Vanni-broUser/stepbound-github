# Stepbound

Stepbound is a deterministic, turn-based survival game prototype built with Flutter. F0 establishes the reproducible mobile project and GitLab pipeline; F1 implements the platform-independent simulation core.

## Requirements

- Flutter 3.44.2 (stable)
- Dart 3.12.2
- Android Studio or the Android command-line tools
- Xcode for iOS builds

The pinned Flutter version is recorded in `.fvmrc` and `.flutter-version`.

## Fresh checkout

```bash
git clone https://gitlab.com/generic-lab/stepbound.git
cd stepbound
flutter --version
flutter pub get
flutter analyze --fatal-infos --fatal-warnings
flutter test
```

If FVM is installed, replace `flutter` with `fvm flutter`.

## Run the blank F0 shell

Android development flavor:

```bash
flutter run --flavor dev --target lib/main_dev.dart
```

Android production flavor:

```bash
flutter run --flavor prod --target lib/main_prod.dart
```

iOS uses the same commands and flavor names:

```bash
flutter run --flavor dev --target lib/main_dev.dart
flutter run --flavor prod --target lib/main_prod.dart
```

The application IDs are `com.genericlab.stepbound.dev` and `com.genericlab.stepbound` on both platforms. The shell is deliberately blank, landscape-only, and immersive; rendering begins in F2.

## Run the F1 ASCII simulation

```bash
dart run bin/stepbound_runner.dart 20260920
```

Controls: W/A/S/D move, E interacts with the faced tile, X waits, and Q quits. The optional numeric argument is the deterministic seed.

## Verification

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos --fatal-warnings
flutter test
flutter build apk --debug --flavor dev --target lib/main_dev.dart
```

GitLab CI runs formatting, static analysis, and tests with Flutter 3.44.2. Signed release builds belong on a protected local runner; signing secrets must never be committed.

## Architecture

- `lib/core`: pure Dart grid, entities, actions, systems, scheduler, events, serialization, seeded RNG
- `lib/game`: rendering, animation, and audio integration reserved for F2
- `lib/input`: input adapters
- `lib/data`: data loading
- `lib/save`: persistence adapters
- `lib/ui`: Flutter interface
- `assets/balance/default.json`: external balance defaults
- `bin/stepbound_runner.dart`: headless ASCII runner

The simulation core imports no Flutter APIs. World time advances only when a `PlayerAction` is passed to `TurnScheduler.advance`.

See `CONTRIBUTING.md` for the GitLab workflow and `docs/target_devices.md` for the physical-device matrix.
