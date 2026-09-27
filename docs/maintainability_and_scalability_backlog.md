# Maintainability and scalability backlog

This backlog records the findings still open from the review of `main` at
`7061d62`, re-checked against `1b0261a` (2026-09-26) ahead of the first
public demo, the hometown level. What has been dealt with leaves the list:
the commits say what was done and why.

Suggested order: measure a release build on the minimum phone, then settle
the save policy, then the rest.

## P1 — Measure a release build on the minimum phone

Nothing has been measured outside the test VM, and debug builds say nothing
about performance: Dart runs JIT-compiled, asserts are on and the APK is
several times the size. The minimum device in `docs/target_devices.md` is an
Android Go phone with 2 GB of RAM.

- Install a release APK on the minimum phone and on the mid-range one: the
  GitLab job `build_android_release_apk`, run with
  `STEPBOUND_DIAGNOSTICS=true`, shows frame rate, the slowest frame, the
  game's load time and the last area's over the game.
- Measure the time from "Continua" to the first frame of play, the time an
  area takes to compose, and the frame rate in the city and in the Duomo.
- Compare the places on screen with the previous version (see
  `docs/level_pipeline.md`).
- Record device, build, commit and figures in the merge request, as for the
  F0 smoke test.

The numbers decide how urgent the memory items below are.

## P1 — A save policy for the public demo

Once the demo is out, an update installs over the old one and keeps its
data: `docs/save_policy.md` says which save formats a build must still load.

- Keep the progress between levels (levels completed, zombies met, memories,
  outfits) apart from the state of the game in progress, so a format change
  can drop the second without the first, and the migration has less to
  carry.
- Decide whether the game should also save when the app goes to the
  background: today `AppLifecycleListener` in `lib/app.dart` only pauses
  audio and the clock, and only campfires and the end of a level write.
  Android kills background apps freely on cheap phones, and everything since
  the last campfire is lost. If checkpoints are the design, say so in the
  game.

## P2 — What is left of loading the places by area

- An area is composed on the UI isolate as Mario walks into it (into the
  harbour, during its card): measure the hitch on the minimum phone, and
  spread the work over frames or behind a fade if it shows.
- New areas as the levels grow: a place's `area` decides what is loaded
  with it, so a big new district wants an area of its own.
- The simulation grid (a few bytes a cell) is still whole; split it per
  level only if the benchmark or the save size ask for it.

## P2 — Smaller story portraits

The thirteen portraits are PNGs of 1048×1501: about 6 MB each once decoded,
shown at a fraction of that size. Resize them to what the dialogue box and
the zombie book actually draw, or decode them with `cacheWidth`. The scenes
(JPEG, 1376×768) are fine.

## P2 — Split application and game orchestration

`StepboundApp` combines application phases, persistence, audio lifecycle,
restart behaviour and widget composition. `StepboundGame` combines story
hosting, event presentation, camera, audio, place transitions, rendering and
save snapshots. They are also the most frequently changed source files
in the current history (1465 and 976 lines at `1b0261a`), and
`lib/game/input/touch_controls.dart` has since grown to 1488 lines, the
largest file of the game.

Extract small framework-free collaborators rather than adding a broad state
management framework:

- `AppFlowController` for menu, story, title and playing phases;
- `GameSession` for creation, restoration and snapshots;
- `WorldEventPresenter` for event-to-animation/audio routing;
- `PlaceTransitionController` for portals, location cards and camera hand-off;
- the touch controls split into the pad, the action buttons and the HUD
  badges.

## P2 — Compatibility code for development saves

Old development saves read as empty slots, yet code written to carry them
forward is still there, dead since the format moved on:
`HometownStage.restore` (`lib/game/levels/hometown_stage.dart`) reconciles
saves "made before the key quest existed" and ones missing the ring's
badge, and the comments of `HometownStage.afterCharacters` and of
`DuomoScript._startMassIfDressed` still speak of saves from before the
mass.

- Remove it, after checking that none of those lines also rebuilds the
  state of a current save (the priest gate, the stair cultist's tiles).
- Keep what `restoreGameWorld` (`lib/core/levels/game_world.dart`) does:
  doors, travel maps, and zombies and backpacks a save does not know come
  from the current level. With `docs/save_policy.md` it means content
  added to a level reaches the saves of the public build with no
  migration: write it down there as a rule.

## P2 — Make asset generation reproducible

The Python asset tools had no pinned Python/Pillow environment, the largest
generator is over two thousand lines, and one story-image tool contains a
developer-specific downloads path. CI verified some resulting contracts but
did not prove that checked-in assets can be regenerated reproducibly.

The levels are no longer part of this: see `docs/level_pipeline.md` for
what is left of them. What is left here:

- Pin the expected `ffmpeg` version, and the environment of the sprite, audio
  and quest-item generators.
- Replace machine-specific paths with command-line arguments
  (`tools/process_story_images.py`).
- Extend the regeneration check to the sprite atlases and the audio.

## P2 — Release signing and the debug builds

Android only updates an app with an APK signed by the same key. The release
key must be kept safe and backed up: losing it means the published app can
never be updated again. Debug APKs built by CI are signed with a debug key
generated anew in each job's container, so each one conflicts with the
last and has to be installed after uninstalling it.

- A fixed debug keystore, checked in (a debug key is no secret), would let
  the CI debug APKs update each other too.
- Keep the `versionCode` growing across every build that reaches a phone:
  GitLab and GitHub number their builds differently.

## P3 — What is left of the save hardening

Slots are now read as a typed result, damaged ones fall back on the save they
replaced, and failed writes never leave the game stuck. Two corners remain:

- The story scripts' state is not checked before loading: `restore` reads
  with lenient casts, but a field of the wrong type still throws when the game
  starts. Checking it needs a `StoryHost`, which only the game has.
- The save written aboard the train when the level ends is logged when it
  fails, but the results screen does not say so; the next campfire writes it.

## P3 — Place images outlive the game

`TilePlaceComponent.release()` is only called when Mario leaves an area,
not when the game is taken down (starting over at a campfire, game over,
back to the menu): the images of the last area go with the garbage
collector, and the static cache `_built` keeps them through the menu too.
Tens of megabytes held longer than needed on a 2 GB phone.

- Release a place's images in `TilePlaceComponent.onRemove`.
- Let the P1 figures say whether the cache should also be emptied when
  the game ends.

## P3 — Release-only differences

What only a release build shows, to keep in mind while testing:

- `assert` is compiled out: the three in `lib/` guard nothing in a release.
- The `INTERNET` permission is only in the debug manifest (for hot reload):
  anything online added later needs it in `android/app/src/main`.
- R8 shrinks the plugins' Java/Kotlin code; a plugin relying on reflection
  can break there only.

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
brings. `levels_check` is still `allow_failure`: if it has stayed green,
make it blocking (see `docs/level_pipeline.md`).

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
