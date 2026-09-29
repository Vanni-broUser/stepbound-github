# Maintainability and scalability backlog

This backlog records the findings still open from the review of `main` at
`7061d62`, re-checked against `1b0261a` (2026-09-26), `7319a9e`
(2026-09-27), `de39a1b` (2026-09-28) and `9447a38` (2026-09-29) ahead of
the first public demo, the hometown level. What has been dealt with
leaves the list: the commits say what was done and why. The figures
quoted were measured on the development machine with a throwaway script
over `lib/core`; a Go phone is five to ten times slower. Figures from
real phones live in `docs/device_measurements.md`.

At `9447a38`: analysis clean, 748 tests green, line coverage 95.7% with
every area above its floor (`tools/coverage_policy.json`), 34 merge
requests landed in the day since `de39a1b`. Since the previous check the
app's flow, the game's events, transitions, covers and campfire rest are
collaborators of their own with their own tests, the three largest test
files are twenty-seven files by theme, every generated picture and
sound is checked against its generator, and the tile atlas baker is one
module per place. The world grew too: the hospital, the Baths of
Diocletian, the road to Termini; the figures below are for that world.
The project is in good shape; nearly everything below is about the
moment it goes public.

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
- The simulation grid is still whole: 2953×62 at `9447a38`, 183,086
  `Tile` objects (not bytes: about 5 MB with the pathfinder's scratch
  arrays), 88% of them the wall between places. Split it per level only
  if the benchmark or the save size ask for it: a save only stores the
  tiles that differ, and the whole world of a save stays under the 64 KB
  `test/world/saves_test.dart` allows.

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

## P3 — What is left of asset generation

Every picture and sound in the repository that a script in `tools/` makes
is now checked against its script (2026-09-29): the tile atlas by
`levels_check`, the sprites, outfits, quest items, sign and icons by
`sprites_check` (`tools/build_sprites.py --check`, the generators run in
order in a temporary copy, pixels compared), both in the pinned Python of
`tools/requirements.txt`; the sounds by `tools/build_audio.py --check`,
byte for byte, with the ffmpeg build the script names. Running everything
found two sheets that had drifted (Lazio's throwable pose carried pistol
pixels from before the strip, Roma's gun sheet twelve pixels under the
pistol layer) and one broken path; all fixed. What is left:

- The audio check runs by hand: CI would need an image with that exact
  ffmpeg build and the twenty source files cached, or the sources moved
  into the repository (about 60 MB, and some licences want attribution,
  not redistribution). The sources were all still online on 2026-09-29.
- `clean_portraits.py` no longer fits the portraits: its dark-background
  rule cuts through the outlines of the priest's and the carabiniere's
  robes and uniform, and Lazio's, the vampire's and Roma's would change
  too. Nothing runs it; before it is run again on purpose, the rule wants
  a look, or the portraits it was written for have to be told apart from
  the ones drawn since.
- `process_story_images.py` needs the source art, which is outside the
  repository: the scenes cannot be regenerated by a machine that does not
  have it, and are not checked.
- `tools/build_tile_atlas.py` is split by place since 2026-09-29 (460
  lines, plus a `tile_atlas_<place>.py` for each interior), and the
  city's painters, once `tools/build_street_level.py`, are
  `tools/street_{paint,ground,buildings,props,airliner}.py` since the
  same day. The largest tools left are the Duomo's module (1400 lines
  for six places) and `tools/street_buildings.py` (about 1000).

## P3 — Smaller portrait files

The portraits are decoded at the height they are drawn (`PortraitImage`),
so memory is no longer the question; the files are. They are still PNGs of
1048×1501, some 7 MB under `assets/characters/mario/portraits` alone, for
pictures never shown above about 1000 pixels tall. Resize them only if the
download size matters, and mind that `tools/clean_portraits.py` works on
the full-size files. The scenes (JPEG, 1376×768) are fine.

## P3 — Release-only differences

What only a release build shows, to keep in mind while testing:

- `assert` is compiled out: the two in `lib/` guard nothing in a release.
- The `INTERNET` permission is only in the debug and profile manifests (for
  hot reload): anything online added later needs it in
  `android/app/src/main`, and the privacy policy with it.
- R8 shrinks the plugins' Java/Kotlin code; a plugin relying on reflection
  can break there only. `share_plus` is the newest plugin: try the share
  sheet on a release build once.
- The key that signs gift links is in the APK (`docs/skin_unlock_links.md`
  says so and accepts it).

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

`tools/benchmark_world.dart` measures a turn with the real cast, 500 and
1,000 entities, and the cost of a single path query. On the real world of
the game (125 entities at `9447a38`, the hospital and Rome included) a
turn costs about 0.1 ms (0.07 and 0.13 in two runs), 0.5 ms with 500
entities all hunting Mario: each item below is a rounding error, so none
of them is worth its complexity until the benchmark asks.

- `TurnScheduler.advance` walks every entity twice per tick. Keep active sets
  per place or spatial sector when that starts to show.
- The characters of every level are in Flame's world from the start, 125
  components ticking every frame, unlike the fires, torches, backpacks and
  burning ground, which come and go with their places. Worth scoping
  them too only with a much larger cast: they move, and the scripts
  raise them, wherever Mario is.
- Cached paths or shared flow fields: not needed at these numbers.
