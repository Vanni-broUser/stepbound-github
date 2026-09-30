# Asset layout

Assets are grouped by the part of the game that owns them, rather than by
file format:

- `characters/mario`: Mario's base look and selectable skins, split into
  `portraits` and `sprites`.
- `characters/npcs`: non-player characters, split into `portraits` and
  `sprites`.
- `characters/zombies`: zombie archetypes, split into `portraits` and
  `sprites`.
- `characters/atlas_manifest.json`: frame and animation contract shared by
  every character sheet.
- `objects`: generic objects that are not owned by a level or character.
- `levels/tiles`: the generated tile atlas and its manifest.
- `levels/places`: large props grouped by their level area (`hometown`,
  `rome`, and `train`).
- `story/scenes`: narrative stills used by cutscenes.
- `story/maps`: travel and level maps.
- `story/ui`: title and menu artwork.
- `story/placeholders`: temporary art that is not a production level asset.

Audio, balance data, the shared palette and branding keep their top-level
folders because they already represent a single domain.
