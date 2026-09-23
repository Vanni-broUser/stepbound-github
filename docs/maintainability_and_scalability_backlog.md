# Maintainability and scalability backlog

This backlog records the remaining findings from the review of `main` at
`7061d62`. Items already dealt with on this branch are kept, marked done, with
what is left of them, so the next reader knows what was measured and why the
rest was left alone.

Done here: the duplicated balance configuration (`assets/balance/default.json`
is authoritative and a CI check protects the generated Dart), the tile index
and the bounded path search below, and the web build, which no longer has a CI
job — the game is not distributed on the browser, and `analyze` plus the tests
already catch what that build caught.

## P1 — Make saves resilient

`SaveGame.fromJson` relies on runtime casts, while the repository catches only
`FormatException`. Valid JSON with a missing field or an unexpected type can
therefore escape as a type error and break slot loading. A failed write also
leaves the camp menu in its saving state, without feedback or a retry path.

- Introduce a validated decoder returning a typed success or failure.
- Keep bumping `SaveGame.format` for every change of shape. Migrations are
  deliberately out of scope: an old save reads as an empty slot, and that is
  the rule for this project.
- Preserve a last-known-good value before replacing a slot.
- Surface read and write failures in the menu and always leave the saving state.
- Test truncated JSON, missing fields, unknown enum values and failed writes.

## P1 — Spatial indexing (done, with the rest measured)

`tools/benchmark_world.dart` is the deterministic benchmark: the tutorial map
with 100, 500 and 1,000 entities spread over the walkable tiles, everybody
pointed at the player every turn, plus the cost of a single path query. On the
machine this was written on, before and after:

| measurement                          | before | after |
| ------------------------------------ | -----: | ----: |
| turn, 1,000 entities                  | 12.4 ms | 3.0 ms |
| one path, target 12 tiles away        | 79 us  | 4 us  |
| one path, target walled off (2,086 tiles) | 509 us | 25 us |

What changed:

- `WorldState` keeps a `GridPoint -> entity` and a `GridPoint -> pickup`
  index. `PositionComponent.position` notifies its world when it is written,
  so the AI, the player's action, the tutorial scripts and the tests all keep
  the index honest without knowing it exists. `entities` and `pickups` are
  read-only; `addEntity` is how somebody joins.
- `isBlocked` answers per tile, so the AI no longer rebuilds the whole
  `occupiedPoints` set for every zombie of every tick.
- `TileMap.shortestNextStep` runs on flat arrays stamped with a search
  number instead of hash maps keyed by `GridPoint`, and takes a
  `maxDistance`. `ZombieAi.pathfindingRange` caps it at 48 tiles: without a
  cap, a target that cannot be reached costs the whole walkable area before
  the search gives up, per zombie, per tick.
- Characters away from the camera are not synchronised and not drawn
  (`CharacterComponent.onScreen`). Mario and whoever the camera is panning to
  are never culled.

What is left, and why it waits:

- Per-place or per-sector active sets. `TurnScheduler.advance` still walks
  every entity twice per tick. At 1,000 entities that is a rounding error
  next to the path queries, so it is not worth the second index until the
  benchmark says otherwise.
- Off-screen characters are hidden, not unloaded: Flame still ticks their
  components. Cheap today, worth revisiting with a much larger cast.
- Saving still diffs the whole map. Tracking changed tiles incrementally is
  untouched.
- Cached paths or shared flow fields: not needed at these numbers.

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

## P2 — Make coverage account for every production library

The aggregate LCOV threshold counts only libraries loaded by tests. Production
adapters such as `PlayerAudio` and bootstrap code can be absent from both the
numerator and denominator, while the reported percentage still passes.

- Compare the LCOV file list with `lib/**/*.dart` and report missing libraries.
- Add per-area thresholds for core, persistence, UI and platform adapters.
- Cover corrupt saves, storage failures, every world-event codec and audio
  lifecycle behaviour.
- Add direct tests for currently uncovered cutscene and location-card widgets.

## P2 — Make asset generation reproducible

The Python asset tools have no pinned Python/Pillow environment, the largest
generator is over two thousand lines, and one story-image tool contains a
developer-specific downloads path. CI verifies some resulting contracts but
does not prove that checked-in assets can be regenerated reproducibly.

- Pin Python, Pillow and the expected `ffmpeg` version.
- Replace machine-specific paths with command-line arguments.
- Provide one documented asset-build entry point and deterministic seeds.
- Split the street generator into surfaces, buildings and props modules.
- Add a CI check for dimensions, manifests and deterministic output hashes.

## P3 — Clarify service ownership and disposal

`PlayerAudio` owns timers, players and pools and exposes `dispose`, but the app
bootstrap does not establish an owner that disposes it. This is mostly hidden
in a normally long-lived mobile process, but matters for tests, embedding and
restarts.

- Introduce an application service scope with explicit ownership.
- Dispose only services created by that scope; injected test services remain
  caller-owned.
- Add lifecycle tests covering pause, resume and disposal.

## P3 — Streamline CI and align documentation

Container jobs start from Flutter 3.44.0 and fetch/checkout 3.44.2 for every
job, which is the largest fixed cost left in the pipeline. The JUnit converter
is globally activated at execution time, so its version is whatever the day
brings. The README also described directories that hold nothing: `lib/input`
and `lib/data` are kept on purpose, but input lives under `lib/game/input`.

- Use an exact prebuilt Flutter image, or cache a prepared SDK.
- Pin the JUnit conversion tool instead of activating an implicit latest version.
- Update the architecture section when directories move or remain placeholders.
  Done here: the README says where input actually lives (`lib/game/input`) and
  that `lib/input` and `lib/data` are empty placeholders.
