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

Every zombie has unmistakably green exposed skin. Use a sickly olive or yellow-green base, forest-green shadow, and a pale yellow-green highlight. At 16×24, a zombie must never be mistaken for a living human.

Archetype cues:

- Wanderer: thin, uneven posture, charcoal work clothes, slow understated stride.
- Sprinter: lean, forward posture, faded crimson jacket, exaggerated running stride.
- Brute: broad shoulders and arms, ochre work vest, heavy weighty stride.
- Blind: gaunt silhouette, violet-gray coat, off-white eye bandage, searching arms.

Keep the designs readable and non-gory. Archetypes should be distinguishable by silhouette before the player notices small details.

## Current production assets

The zombie atlases in `assets/sprites/` are original pixel art, converted to the runtime 96×96 contract with nearest-neighbor sampling and verified in the Flame build. The runtime files are:

- `zombie_wanderer.png`
- `zombie_sprinter.png`
- `zombie_brute.png`
- `zombie_blind.png`
- `zombie_carabiniere.png`
- `zombie_mutilated.png`
- `zombie_burning.png`
- `zombie_drunk.png`

`assets/sprites/atlas_manifest.json` is the machine-readable contract used by the project.

## Action sheets

Combat animations share the same 96×96, 4-rows-by-6-columns grid and are listed under `actionSheets` in the manifest. Rows keep the south/west/east/north order; the east row mirrors the west row.

- `protagonist_gun.png`: columns `aim_0..aim_2` (drawn-pistol stance held while aiming) and `fire_0..fire_2` (muzzle flash and recoil).
- `zombie_<type>_hit.png`: three-frame flinch repeated to fill the row.
- `zombie_<type>_bite.png`: wind-up, two lunge frames with an open maw, recovery.
- `zombie_<type>_death.png`: six-frame collapse from flinch to prone.

The common sheets are produced by `tools/generate_action_sprites.py`; the carabiniere and special archetypes are derived by `tools/generate_carabiniere.py` and `tools/generate_special_zombies.py`. Run the scripts from the repository root with Python and Pillow.
