# Stepbound

Stepbound is a deterministic, turn-based survival game prototype built with Flutter and Flame.

- F0: reproducible Flutter project and GitLab CI.
- F1: platform-independent deterministic simulation core.
- F2: 384×216 pixel-art presentation, integer scaling, layered map rendering, 130 ms turn interpolation, input buffering, dead-zone camera, and debug overlays.

## Requirements

- Flutter 3.44.2 (stable)
- Dart 3.12.2
- Android Studio or the Android command-line tools for Android builds
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

## Run F2 in a browser

```bash
flutter run -d chrome
```

A browser-independent local server is also available:

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5173
```

Controls:

- Arrow keys or W/A/S/D: move
- Space or X: wait one turn
- E: interact with the faced tile
- G: toggle grid, collision cells, and perception ranges

The game renders at a fixed virtual resolution of 384×216 and scales only by whole-number multiples. Remaining screen space is letterboxed.

## Run on mobile

```bash
flutter run
```

Stepbound currently uses a single application ID: `com.genericlab.stepbound`.

## Run the F1 ASCII simulation
```bash
dart run bin/stepbound_runner.dart 20260920
```

Controls: W/A/S/D move, E interacts with the faced tile, X waits, and Q quits. The optional numeric argument is the deterministic seed.

## Sprite contract

Runtime character atlases live in `assets/sprites/` as transparent 96×96 PNG files. Each sheet contains a 4×6 grid of 16×24 frames:

- Rows: south, west, east, north
- Columns: idle_0, idle_1, walk_0, walk_1, walk_2, walk_3
- Anchor: bottom center of each frame

The current set includes the protagonist plus wanderer, sprinter, brute, and blind zombies. See `docs/art_direction.md` for the complete visual rules.

## Verification

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos --fatal-warnings
flutter test
flutter build web --release
flutter build apk --debug
```

GitLab CI runs formatting, static analysis, and tests with Flutter 3.44.2. Signed release builds belong on a protected local runner; signing secrets must never be committed.

## Architecture

- `lib/core`: pure Dart grid, entities, actions, systems, scheduler, events, serialization, and seeded RNG
- `lib/game`: Flame presentation, camera, render layers, turn interpolation, and debug tools
- `lib/input`: input adapters
- `lib/data`: data loading
- `lib/save`: persistence adapters
- `lib/ui`: Flutter interface
- `assets/balance/default.json`: external balance defaults
- `assets/sprites`: production sprite atlases and atlas contract
- `bin/stepbound_runner.dart`: headless ASCII runner

The simulation core imports no Flutter APIs. World time advances only when a `PlayerAction` is passed to `TurnScheduler.advance`.

See `CONTRIBUTING.md` for the GitLab workflow and `docs/target_devices.md` for the physical-device matrix.