# Maintainability and scalability backlog

This backlog records the remaining findings from the review of `main` at
`7061d62`. The duplicated balance configuration is intentionally omitted: this
change makes `assets/balance/default.json` authoritative and protects its
generated Dart representation with a CI check.

## P1 — Make saves resilient and migratable

`SaveGame.fromJson` relies on runtime casts, while the repository catches only
`FormatException`. Valid JSON with a missing field or an unexpected type can
therefore escape as a type error and break slot loading. A failed write also
leaves the camp menu in its saving state, without feedback or a retry path.

- Introduce a validated decoder returning a typed success or failure.
- Add incremental migrations instead of invalidating every older format.
- Preserve a last-known-good value before replacing a slot.
- Surface read and write failures in the menu and always leave the saving state.
- Test truncated JSON, missing fields, unknown enum values and failed writes.

## P1 — Add spatial indexing before expanding the world

World queries currently scan every entity or pickup. Each acting zombie also
rebuilds occupied positions and may run a breadth-first search across the map.
Every character receives a Flame component and is synchronised every frame,
including characters outside the visible place.

- Add deterministic benchmarks with 100, 500 and 1,000 entities.
- Maintain `GridPoint -> entity/pickup` indexes as positions change.
- Keep active simulation and presentation sets per place or spatial sector.
- Cull or unload presentation components outside the relevant area.
- Evaluate bounded A*, cached paths or shared flow fields only after measuring.
- Track changed map tiles incrementally instead of diffing the whole map on save.

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
job. The JUnit converter is globally activated at execution time. The README
also mentions `lib/input` and `lib/data`, although input currently lives under
`lib/game/input` and no runtime data loader occupies `lib/data`.

- Use an exact prebuilt Flutter image, or cache a prepared SDK.
- Pin the JUnit conversion tool instead of activating an implicit latest version.
- Investigate and remove the web-build warning about `CupertinoIcons`.
- Update the architecture section when directories move or remain placeholders.
