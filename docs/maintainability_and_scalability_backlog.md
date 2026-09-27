# Maintainability and scalability backlog

This backlog records the findings still open from the review of `main` at
`7061d62`, re-checked against `1b0261a` (2026-09-26) and again against
`7319a9e` (2026-09-27) ahead of the first public demo, the hometown level.
What has been dealt with leaves the list: the commits say what was done
and why. The figures quoted were measured on the development machine with
a throwaway script over `lib/core`; a Go phone is five to ten times slower.

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
- Measure the frame rate indoors first: `LightingComponent` composes a
  full-room `saveLayer` every frame and cuts a `dstOut` circle per ring
  per lamp into it, up to a hundred circles a frame on the hypermarket's
  ground floor (32 lamps). Nothing in the simulation comes close: a turn
  with every zombie hunting costs 0.06 ms on the development machine.
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
  spread the work over frames or behind a fade if it shows. The harbour
  alone is an image of 2304×992 (8.7 MB) plus its front layer of the same
  size; the harbour area holds about 28 MB of place images, the town
  about 29 MB.
- New areas as the levels grow: a place's `area` decides what is loaded
  with it, so a big new district wants an area of its own.
- The simulation grid is still whole: 1902×62, 117,924 `Tile` objects
  (not bytes: about 3.5 MB with the pathfinder's scratch arrays), 92% of
  them the wall between places. Split it per level only if the benchmark
  or the save size ask for it: a save only stores the tiles that differ.

## P2 — Split application and game orchestration

`StepboundApp` combines application phases, persistence, audio lifecycle,
restart behaviour and widget composition. `StepboundGame` combines story
hosting, event presentation, camera, audio, place transitions, rendering and
save snapshots. They are also the most frequently changed source files in
the current history: `lib/app.dart` went from 976 lines at `1b0261a` to
1043 at `7319a9e`, `lib/game/stepbound_game.dart` came down from 1465 to
1000. (The touch controls, once the largest file of the game, are split
under `lib/game/input/` by zone, stick, badges and icons.)

Extract small framework-free collaborators rather than adding a broad state
management framework:

- `AppFlowController` for menu, story, title and playing phases;
- `GameSession` for creation, restoration and snapshots;
- `WorldEventPresenter` for event-to-animation/audio routing;
- `PlaceTransitionController` for portals, location cards and camera hand-off.

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
- `StepboundGame` has no teardown of its own either: no `onRemove`, and
  its eleven `ValueNotifier`s are never disposed. Harmless on its own,
  but every return to the menu adds to what the images already keep.

## P3 — Smaller portrait files

The seventeen portraits are decoded at the height they are drawn
(`PortraitImage`), so memory is no longer the question; the files are.
They are still PNGs of 1048×1501, some 15 MB of the APK, for pictures
never shown above about 1000 pixels tall. Resize them only if the
download size matters, and mind that `tools/clean_portraits.py` works on
the full-size files. The scenes (JPEG, 1376×768) are fine.

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
- The GitHub workflow repeats the GitLab jobs by hand (`docs/ci-pipeline.md`
  says so): every change to a job is made twice. Keep it in mind before
  adding jobs.

## P3 — Simulation cost as the world grows

`tools/benchmark_world.dart` measures a turn with 100, 500 and 1,000 entities
and the cost of a single path query. On the real world of the game (81
entities) a turn costs 0.05 ms, 0.06 ms with every zombie hunting Mario:
each item below is a rounding error, so none of them is worth its
complexity until the benchmark asks.

- `TurnScheduler.advance` walks every entity twice per tick. Keep active sets
  per place or spatial sector when that starts to show.
- Every level is in Flame's world from the start, not only the area Mario
  is in: 81 characters, 42 fires, 44 pieces of burning ground, 12 torches
  and 17 backpacks, some 200 components whose `update` runs every frame.
  Their drawing is culled; the ticking grows with every level added.
- Cached paths or shared flow fields: not needed at these numbers.
