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
  `STEPBOUND_DIAGNOSTICS=1`, shows frame rate, the slowest frame, the
  game's load time and the last area's over the game.
- Measure the time from "Continua" to the first frame of play, the time an
  area takes to compose, and the frame rate in the city and in the Duomo.
- Confirm the frame rate indoors: `LightingComponent` now draws the
  darkness with its steady lamps from an image composed once, and cuts
  only the flickering lamps, the torches and Mario's halo live, each in
  a layer no bigger than its pool. It was designed for the Go phone's
  GPU, not measured on it. Nothing in the simulation comes close: a turn
  with every zombie hunting costs 0.06 ms on the development machine.
- Compare the places on screen with the previous version (see
  `docs/level_pipeline.md`).
- Record device, build, commit and figures in the merge request, as for the
  F0 smoke test.

The numbers decide how urgent the memory items below are.

## P1 — A save policy for the public demo

Once the demo is out, an update installs over the old one and keeps its
data: `docs/save_policy.md` says which save formats a build must still load.

- The progress between levels (zombies met, memories, outfits, steps,
  fires lit) is its own object in the save, `progress`, apart from the
  game in progress: a migration that cannot carry the game keeps it and
  puts the level back at its start (`docs/save_policy.md`, "Cosa una
  migrazione tiene"). That is the rule; the first migration will be the
  first to apply it.
- The game put down (`docs/save_policy.md`, "Il salvataggio sospeso") is
  written whenever the app leaves the front or the player leaves for the
  menu, never in the middle of a story line or a scene: if a script ever
  holds Mario for long without a prompt up, that stretch goes unsaved.

## P2 — What is left of loading the places by area

- An area's places are composed one at a time as Mario walks into it
  (`PlaceLayers`), so a frame carries at most one picture; whether the
  harbour's, 2304×992 (8.7 MB) plus a front layer of the same size, is
  still a hitch on the minimum phone is for the P1 figures to say. The
  harbour area holds about 28 MB of place images, the town about 29 MB.
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

`GameSession` (`lib/game/game_session.dart`) now holds what a save records
around the game and makes the games that play it: `app.dart` is left with
the phases and the widgets. Extract the rest as small framework-free
collaborators too, rather than adding a broad state management framework:

- `AppFlowController` for menu, story, title and playing phases;
- `WorldEventPresenter` for event-to-animation/audio routing;
- `PlaceTransitionController` for portals, location cards and camera hand-off.

## P2 — Make asset generation reproducible

The Python asset tools had no pinned Python/Pillow environment, the largest
generator is over two thousand lines, and one story-image tool contains a
developer-specific downloads path. CI verified some resulting contracts but
did not prove that checked-in assets can be regenerated reproducibly.

The levels are no longer part of this: see `docs/level_pipeline.md` for
what is left of them. What is left here:

- Pin the expected `ffmpeg` version, and the environment of the sprite, audio
  and quest-item generators.
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
replaced, failed writes never leave the game stuck, and a slot is only
offered once its world, progress and story scripts have been rebuilt. One
corner remains:

- The save written aboard the train when the level ends is logged when it
  fails, but the results screen does not say so; the next campfire writes it.

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
job, which is the largest fixed cost left in the pipeline: cirruslabs has
published no 3.44.2 image, and GitLab only caches paths inside the project.

- Use an exact prebuilt Flutter image once there is one, or install the SDK
  under the project directory and cache it by version.
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
- The characters of every level are in Flame's world from the start, 81
  components ticking every frame, unlike the fires, torches, backpacks and
  burning ground, which come and go with their places. Worth scoping
  them too only with a much larger cast: they move, and the scripts
  raise them, wherever Mario is.
- Cached paths or shared flow fields: not needed at these numbers.
