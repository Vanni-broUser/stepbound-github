# Maintainability and scalability backlog

This backlog records the findings still open from the review of `main` at
`7061d62`, re-checked against `1b0261a` (2026-09-26), `7319a9e`
(2026-09-27) and `de39a1b` (2026-09-28) ahead of the first public demo,
the hometown level. What has been dealt with leaves the list: the commits
say what was done and why. The figures quoted were measured on the
development machine with a throwaway script over `lib/core`; a Go phone is
five to ten times slower. Figures from real phones live in
`docs/device_measurements.md`.

At `de39a1b`: analysis clean, 623 tests green, coverage floors 88–95%
held, dependencies at the newest resolvable versions, 36 merge requests
landed in the two days since the previous check. The project is in good
shape; nearly everything below is about the moment it goes public.

Suggested order: the publication ritual when the first build goes out,
then the rest. The release key has its copy outside GitLab (2026-09-28),
and the level-end save is awaited and reported.

## P1 — The publication ritual, for the day of the first public build

Nothing to do before the build itself: the mechanism is ready and its
switch is off. `publishedSaveFormat` is `null`, `SaveGame.format` moves
freely, and `test/published_save_test.dart` checks that nothing is frozen
while it is so. The ritual is written in one place,
`docs/save_policy.md` ("Quando una build diventa pubblica"), and runs in
the commit the build is made from: the format is fixed and the saves
frozen, the commit on `main` is tagged (the first tag of the repository;
`docs/device_measurements.md` had to guess which commit build 402 was),
the manual `privacy_policy_pages` job publishes the privacy page, whose
publisher details are already filled in. With `deploy_play` able to put
an App Bundle on a Play track and main taking eighteen merges a day, the
one risk is a build that reaches the public without that commit: tags
start with it, and every later build that leaves the team gets one.

## P1 — Errors in the field

Until this branch, an error nobody caught went to a console nobody reads:
`lib/bootstrap.dart` installed neither `FlutterError.onError` nor
`PlatformDispatcher.onError`, the privacy policy rules out crash
reporting, and the release manifest has no `INTERNET` permission. A player
would have seen a game that no longer answered, and nobody would have
known.

**Done here (first stage, no network).** `ErrorReporter`
(`lib/report/error_report.dart`) hooks both handlers and keeps the first
error; `CrashGuard` (`lib/ui/crash_guard.dart`) sits over the app and
swaps in `ErrorScreen`, sound paused, with two ways out: share the report
through the system's share sheet (`share_plus`, as a text file), or back
to the menu, which builds the app anew. The report holds the build
(`versionName`, `versionCode` and the commit CI passes as
`--dart-define=STEPBOUND_COMMIT`), the phone (model, Android version,
memory, from a method channel in `MainActivity.kt`), the error with its
stack trace, the slot, phase and place, the slot's save as JSON to load
and play the error back, and the trail (`Breadcrumbs`): place changes,
world events other than steps, bumps and noises, story lines shown and
the app's own turns (new game, load, menu, level complete). Nothing in the
report can stop it from being written: whatever fails says so in its
place. Release stack traces stay readable as long as `--obfuscate` is not
used.

**Left for later (second stage, if the demo grows).**

- A "Condividi il rapporto" entry in the pause menu, for the bugs that
  throw nothing: a script that never lets go of Mario is only in the
  trail, and today the trail can only be sent from the error screen.
- An opt-in switch, off by default, "Invia i rapporti automaticamente",
  posting the same file to a small endpoint. A Cloudflare Worker with R2
  or D1 costs nothing and has no server to keep patched; the runner
  machine would have to be exposed and kept up. Before the switch ships:
  `INTERNET` in the main manifest, the privacy policy rewritten (it
  promises no data leaves the phone), the Play data-safety form, a size
  limit and a rate limit on the endpoint, no device identifier in the
  payload.
- The report says nothing about what the player was doing with their
  fingers: if touch input turns out to matter, the trail can take the
  input controller's actions too.

## P2 — What is left of loading the places by area

- An area's places are composed one at a time as Mario walks into it
  (`PlaceLayers`), so a frame carries at most one picture. On a Redmi 9
  the harbour's, 2304×992 (8.7 MB) plus a front layer of the same size,
  composes in 257 ms with no visible hitch (`docs/device_measurements.md`);
  that phone has 6 GB, though. The harbour area holds about 28 MB of place
  images, the town about 29 MB: whether that fits a 2 GB phone, the
  minimum of `docs/target_devices.md`, is still unmeasured, and a kill in
  the background for memory is exactly the case the suspended save has
  to cover. Only a phone can settle it.
- On the Redmi 9, the CPU and GPU of that minimum, frames are skipped
  almost every second in the Duomo (six flickering torches) and two out
  of three readings in the barracks (nine lamps): the live part of
  `LightingComponent`. It plays well there; on anything slower it is the
  first thing to look at.
- New areas as the levels grow: a place's `area` decides what is loaded
  with it, so a big new district wants an area of its own.
- The simulation grid is still whole: 1902×62, 117,924 `Tile` objects
  (not bytes: about 3.5 MB with the pathfinder's scratch arrays), 92% of
  them the wall between places. Split it per level only if the benchmark
  or the save size ask for it: a save only stores the tiles that differ,
  and the most advanced test scenarios save in about 79 KB.

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

## P2 — What is left of release signing

Debug builds now carry `applicationIdSuffix = ".debug"`
(`android/app/build.gradle.kts`): they install beside the release, so a
debug key no longer conflicts with the release one. What remains:

- Debug APKs built by CI are still signed with a debug key generated anew
  in each job's container, so each one conflicts with the last and has to
  be installed after uninstalling it. A fixed debug keystore, checked in
  (a debug key is no secret), would let them update each other too.
- Keep the `versionCode` growing across every build that reaches a phone:
  GitLab (`CI_PIPELINE_IID`) and GitHub (`run_number`) number their builds
  differently.
- iOS: `build_ios_signed` and `deploy_testflight` exist, but the Xcode
  project has no team and the privacy policy already names iOS. Either
  configure the signing or say Android only until it is.

## P3 — What is left of the save hardening

Slots are now read as a typed result, damaged ones fall back on the save they
replaced, failed writes never leave the game stuck, and a slot is only
offered once its world, progress and story scripts have been rebuilt, and
the train's save at the end of the level is awaited, with the results
saying when it failed. One corner remains:

- `_onLifecycle` (`lib/app.dart`) raises `_putDown` as soon as the app
  goes inactive, even when `_suspend` wrote nothing because the game was
  not in a state it can come back to; if it became so before `paused`,
  nothing is written until the next `resumed`. Theoretical today, since
  the game does not move between the two; raise the flag only once a save
  is written.

## P3 — Smaller portrait files

The portraits are decoded at the height they are drawn (`PortraitImage`),
so memory is no longer the question; the files are. They are still PNGs of
1048×1501, some 7 MB under `assets/characters/mario/portraits` alone, for
pictures never shown above about 1000 pixels tall. Resize them only if the
download size matters, and mind that `tools/clean_portraits.py` works on
the full-size files. The scenes (JPEG, 1376×768) are fine.

## P3 — Release-only differences

What only a release build shows, to keep in mind while testing:

- `assert` is compiled out: the three in `lib/` guard nothing in a release.
- The `INTERNET` permission is only in the debug manifest (for hot reload):
  anything online added later needs it in `android/app/src/main`, and the
  privacy policy with it.
- R8 shrinks the plugins' Java/Kotlin code; a plugin relying on reflection
  can break there only. `share_plus` is the newest plugin: try the share
  sheet on a release build once.
- The key that signs gift links is in the APK (`docs/skin_unlock_links.md`
  says so and accepts it).

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
