# Maintainability and scalability backlog

This backlog records the findings still open from the review of `main` at
`7061d62`. What has been dealt with leaves the list: the commits say what was
done and why.

## P2 — Split application and game orchestration

`StepboundApp` combines application phases, persistence, audio lifecycle,
restart behaviour and widget composition. `StepboundGame` combines input,
tutorial hosting, event presentation, camera, audio, place transitions,
rendering and save snapshots. They are also the most frequently changed source
files in the current history.

Extract small framework-free collaborators rather than adding a broad state
management framework:

- `AppFlowController` for menu, story, title and playing phases;
- `GameSession` for creation, restoration and snapshots;
- `WorldEventPresenter` for event-to-animation/audio routing;
- `GameInputController` for keyboard, touch and held-direction repeat;
- `PlaceTransitionController` for portals, location cards and camera hand-off.

## P2 — Make asset generation reproducible

The Python asset tools had no pinned Python/Pillow environment, the largest
generator is over two thousand lines, and one story-image tool contains a
developer-specific downloads path. CI verified some resulting contracts but
did not prove that checked-in assets can be regenerated reproducibly.

The level backgrounds are now covered: `tools/requirements.txt` pins the
environment, `tools/build_levels.py` is their one documented entry point, and
`--check` re-bakes them in CI (`levels_check`) and compares the pixels with
what is committed. A dimension invariant runs in `flutter test` as well
(`test/levels/level_background_dimensions_test.dart`), so a resized place is
caught without Python. What is left:

- Pin the expected `ffmpeg` version, and the environment of the sprite, audio
  and quest-item generators.
- Replace machine-specific paths with command-line arguments
  (`tools/process_story_images.py`).
- Split the street generator into surfaces, buildings and props modules.
- Extend the regeneration check to the sprite atlases and the audio.

The deeper cause, a place's layout living once in Dart and once in Python,
is addressed by the tile-atlas rendering of `docs/level_pipeline.md`.

## P3 — What is left of the save hardening

Slots are now read as a typed result, damaged ones fall back on the save they
replaced, and failed writes never leave the game stuck. Two corners remain:

- The tutorial scripts' state is not checked before loading: `restore` reads
  with lenient casts, but a field of the wrong type still throws when the game
  starts. Checking it needs a `TutorialHost`, which only the game has.
- The save written aboard the train when the level ends is logged when it
  fails, but the results screen does not say so; the next campfire writes it.

## P3 — Clarify service ownership and disposal

`PlayerAudio` owns timers, players and pools and exposes `dispose`, but the app
bootstrap does not establish an owner that disposes it. This is mostly hidden
in a normally long-lived mobile process, but matters for tests, embedding and
restarts.

- Introduce an application service scope with explicit ownership.
- Dispose only services created by that scope; injected test services remain
  caller-owned.
- Add lifecycle tests covering pause, resume and disposal.

## P3 — Streamline CI

Container jobs start from Flutter 3.44.0 and fetch/checkout 3.44.2 for every
job, which is the largest fixed cost left in the pipeline. The JUnit converter
is globally activated at execution time, so its version is whatever the day
brings.

- Use an exact prebuilt Flutter image, or cache a prepared SDK.
- Pin the JUnit conversion tool instead of activating an implicit latest version.

## P3 — Simulation cost as the world grows

`tools/benchmark_world.dart` measures a turn with 100, 500 and 1,000 entities
and the cost of a single path query. At those numbers each item below is a
rounding error next to the path queries, so none of them is worth its
complexity until the benchmark asks.

- `TurnScheduler.advance` walks every entity twice per tick. Keep active sets
  per place or spatial sector when that starts to show.
- Characters away from the camera are hidden, not unloaded: Flame still ticks
  their components. Worth revisiting with a much larger cast.
- Saving still diffs the whole map. Track changed tiles incrementally instead.
- Cached paths or shared flow fields: not needed at these numbers.
