# Stepbound art direction

## Visual target

Stepbound uses original pixel art shaped by the visual grammar of late GBA-era top-down monster-catching RPGs. Pokémon Emerald is a readability and color-discipline reference, not a source of characters, sprites, maps, symbols, or copied designs.

The result should feel compact, colorful, and immediately legible at native resolution while remaining recognizably Stepbound: post-apocalyptic, restrained, and slightly somber.

## Technical rules

- Virtual viewport: 384×216.
- World tiles: 16×16.
- Character frames: 16×24 with a stable bottom-center foot anchor.
- Scaling: integer multiples only; nearest-neighbor filtering; no antialiasing.
- Atlas size: 96×96 transparent PNG.
- Atlas rows: south, west, east, north.
- Atlas columns: idle_0, idle_1, walk_0, walk_1, walk_2, walk_3.
- Palette: compact shared palette with roughly 32 working colors.
- Rendering: clean pixel clusters, no gradients, blur, subpixel placement, or soft shadows.

## Character language

The protagonist uses a rust-red jacket, desaturated blue trousers, pale boots, dark hair, and an olive backpack. The silhouette must remain distinct from every enemy.

The wardrobe also includes four Halloween skins, all preserving Mario's
backpack and stable foot anchor:

- Ghost: an off-white sheet with dark eye holes, exposed hands and the
  backpack worn over the sheet.
- Vampire: charcoal medieval clothes, burgundy waistcoat, black cape with
  red lining and two small upper fangs.
- Jack-o'-lantern: moss-green medieval traveller clothes and a carved pumpkin
  helmet.
- Zombie: unmistakable olive-green skin and worn, patched versions of Mario's
  red top and blue trousers, kept readable and non-gory.

Their walk, gun and pickup sheets are generated from the production Mario
atlases by `tools/generate_halloween_skins.py`.

Every zombie has unmistakably green exposed skin. Use a sickly olive or yellow-green base, forest-green shadow, and a pale yellow-green highlight. At 16×24, a zombie must never be mistaken for a living human.

Archetype cues:

- Wanderer: thin, uneven posture, charcoal work clothes, slow understated stride.
- Sprinter: lean, forward posture, faded crimson jacket, exaggerated running stride.
- Brute: broad shoulders and arms, ochre work vest, heavy weighty stride.
- Blind: gaunt silhouette, violet-gray coat, off-white eye bandage, searching arms.

Keep the designs readable and non-gory. Archetypes should be distinguishable by silhouette before the player notices small details.

## Current production assets

The zombie atlases in `assets/characters/zombies/sprites/` are original pixel art, converted to the runtime 96×96 contract with nearest-neighbor sampling and verified in the Flame build. The runtime files are:

- `wanderer.png`
- `sprinter.png`
- `brute.png`
- `blind.png`
- `carabiniere.png`
- `mutilated.png`
- `burning.png`
- `drunk.png`

`assets/characters/atlas_manifest.json` is the machine-readable contract used by the project.

## Action sheets

Combat animations share the same 96×96, 4-rows-by-6-columns grid and are listed under `actionSheets` in the manifest. Rows keep the south/west/east/north order; the east row mirrors the west row.

- `mario/sprites/base_gun.png`: columns `aim_0..aim_2` (drawn-pistol stance held while aiming) and `fire_0..fire_2` (muzzle flash and recoil).
- `zombies/sprites/<type>_hit.png`: three-frame flinch repeated to fill the row.
- `zombies/sprites/<type>_bite.png`: wind-up, two lunge frames with an open maw, recovery.
- `zombies/sprites/<type>_death.png`: six-frame collapse from flinch to prone.

The common sheets are produced by `tools/generate_action_sprites.py`; the
Brute's walk and action sheets are reduced cell by cell from the detailed
384×384 masters in `assets/characters/zombies/sources/`, so neighbouring
frames never bleed across the runtime grid. The carabiniere and special
archetypes are derived by `tools/generate_carabiniere.py` and
`tools/generate_special_zombies.py`. Run the scripts from the repository root
with Python and Pillow.

## Props

Not everything drawn in the world is a character on the 96×96 grid. Props
are their own sheets, outside `atlas_manifest.json`, each with its own
contract, and the game draws them from a component of its own.

- `assets/characters/zombies/sprites/crucified.png`: 128×40, four 32×40 frames in a row — `hang_0`,
  `hang_1` (a breath lower), `twitch_0`, `twitch_1` (the fit). Two tiles
  wide and two and a half tall, it hangs on the back wall over the middle
  of the Duomo's altar once the mass is over. It follows the story frame
  `scene_crucified_zombie.jpg`: a zombie nailed to a dark wooden cross, cut
  off at the waist, arms spread along the beam with the hands nailed and
  bleeding, torn pale rags, a cross pendant, red eyes, and the blood of the
  trunk pouring down the post. Painted by
  `tools/generate_crucified_zombie.py`.

## Story scenes

The full-screen pictures of the story live in `assets/story/`. The three
intro frames are PNGs at the virtual 16:9 resolution doubled (768×432); the
scenes played during the game keep the source frame as it is, `scene_*.jpg`
at 1376×768.

They are drawn by hand and dropped in as they are: nothing in `tools/`
makes or remakes them, so nothing checks their pixels. What is checked,
by `test/story_scenes_test.dart` on every run of `flutter test`, is that
each one has the size the screens draw it at (the intro frames 768×432,
the scenes 768 tall and 1376 wide, a pixel either way). A new scene goes
in `assets/story/scenes` at that size, and the test says so if it does
not.
