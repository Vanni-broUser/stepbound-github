# Maintainability and scalability backlog

This backlog records the findings still open from the review of `main` at
`7061d62`, re-checked against `1b0261a` (2026-09-26), `7319a9e`
(2026-09-27), `de39a1b` (2026-09-28), `9447a38` (2026-09-29) and
`57dadda` (2026-09-30) ahead of the first public demo, the hometown
level. What has been dealt with
leaves the list: the commits say what was done and why. The figures
quoted were measured on the development machine with a throwaway script
over `lib/core`; a Go phone is five to ten times slower. Figures from
real phones live in `docs/device_measurements.md`.

At `57dadda`: analysis clean, 840 tests green, line coverage 95.6% with
every area above its floor (`tools/coverage_policy.json`), the tile
atlas matching its painters (`tools/build_tile_atlas.py --check`), 30
merge requests landed in the day since `9447a38`. Nothing in the list
was closed or reopened by them: it was a day of world, not of
machinery. The palazzo past the airliner (three floors of flats) and the
company on its street, the Baths' exterior, the grappling hook and the
rocket launcher, the level restart per city, Chiara, the Bruto and the
call-centre zombie; the figures below are for that world, and the ones
that moved are marked. The project is in good shape; nearly everything
below is about the moment it goes public.

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

Since 2026-09-30 the trail also holds what the player asked for
(`input: cammina verso est`, `input: alza la pistola`, and `input
ignorato: interagisce` once per run when the game did not take it), a
held direction noted once, and the pause menu has a "Condividi il
rapporto" entry that sends the same report with no error in it: for the
bugs that throw nothing, a script that never lets go of Mario or a button
that does not answer.

**Left for later (second stage, if the demo grows).**

- An opt-in switch, off by default, "Invia i rapporti automaticamente",
  posting the same file to a small endpoint. A Cloudflare Worker with R2
  or D1 costs nothing and has no server to keep patched; the runner
  machine would have to be exposed and kept up. Before the switch ships:
  `INTERNET` in the main manifest, the privacy policy rewritten (it
  promises no data leaves the phone), the Play data-safety form, a size
  limit and a rate limit on the endpoint, no device identifier in the
  payload.

## P2 — What is left of loading the places by area

- An area's places are composed one at a time as Mario walks into it
  (`PlaceLayers`), so a frame carries at most one picture. On a Redmi 9
  the harbour's, 2304×992 (8.7 MB) plus a front layer of the same size,
  composes in 257 ms with no visible hitch (`docs/device_measurements.md`);
  that phone has 6 GB, though. The harbour area holds about 28 MB of
  decoded place images; the town, twenty-one places since the palazzo's
  three floors and the company joined it (2026-09-29 and 30), about 48 MB,
  up from 29; Rome's streets 18 MB. Whether that fits a 2 GB phone, the
  minimum of `docs/target_devices.md`, is still unmeasured, and a kill in
  the background for memory is exactly the case the suspended save has
  to cover. Only a phone can settle it, and the town is now the area to
  try first.
- On the Redmi 9, the CPU and GPU of that minimum, frames are skipped
  almost every second in the Duomo (six flickering torches) and two out
  of three readings in the barracks (nine lamps): the live part of
  `LightingComponent`. It plays well there; on anything slower it is the
  first thing to look at. The palazzo's floors are newer than every
  reading in `docs/device_measurements.md` (city, barracks, harbour,
  Duomo): 46×20 each with five to seven flickering lamps, the barracks'
  case again, three times over, plus the beacons blinking over the
  backpacks since the grappling hook. They want one reading on the phone
  before they are assumed to play like the barracks.
- New areas as the levels grow: a place's `area` decides what is loaded
  with it, so a big new district wants an area of its own.
- The simulation grid is still whole: 3493×62 at `57dadda`, 216,566
  `Tile` objects (not bytes: about 6 MB with the pathfinder's scratch
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

## P3 — Release-only differences

What only a release build shows, to keep in mind while testing:

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
the game (153 entities at `57dadda`) a turn costs about 0.5 ms, 3.5 ms
with 500 entities all hunting Mario, 9 ms with 1,000. Run side by side
with `9447a38` on the same machine, twice each, that commit takes 0.3,
1.9 and 9 ms: the real cast and the 500 cost nearly twice what they did,
the 1,000 the same, so it is not the machine. The one thing added to the
path of a turn since is `canStep`, asked for every neighbour the
pathfinder expands once a level has stairs (the palazzo's and the
company's, 2026-09-29), and the grid is a fifth wider. A turn happens at
a step, not at a frame, and half a millisecond is still a rounding error
against the 16 ms of one: each item below stays not worth its
complexity until the phone, not the benchmark, asks. If it does, `canStep`
is the first place to look.

- `TurnScheduler.advance` walks every entity twice per tick. Keep active sets
  per place or spatial sector when that starts to show.
- The characters of every level are in Flame's world from the start, 125
  components ticking every frame, unlike the fires, torches, backpacks and
  burning ground, which come and go with their places. Worth scoping
  them too only with a much larger cast: they move, and the scripts
  raise them, wherever Mario is.
- Cached paths or shared flow fields: not needed at these numbers.
