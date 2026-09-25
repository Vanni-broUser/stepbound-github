"""The machinery of the tile atlas, shared by every place painted from it.

tools/build_tile_atlas.py and the modules it takes places from (the city's
is tools/tile_atlas_city.py) describe *what* a place looks like: rules
that say, for these glyphs, take a tile out of this bucket. This module is
*how*: the atlas the tiles are packed into, the keys a rule can ask about a
cell, the helpers that cut a painter's picture into tiles, and the
reference draw that lib/game/render/tile_place_component.dart repeats.
"""
from __future__ import annotations

import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_street_level import TILE  # noqa: E402

# How many times the same kind of tile is painted with fresh grit. The
# renderer picks between them with a hash of the tile's position: enough
# that no eye finds the repeat, few enough that the atlas stays small.
VARIANTS = 12

# One seed for the whole atlas: the tiles are art, and art that changes
# every time it is baked cannot be reviewed in a diff.
SEED = 20260925

TRANSPARENT = (0, 0, 0, 0)

# The order the renderer draws in. Objects -- pictures too big or too
# particular for a tile -- go down between the structures and the
# foreground; `overhead` is for what stands into the tile above over
# everything else, the traffic lights and the trees.
LAYERS = ("ground", "structures", "objects", "foreground", "overhead")


class Atlas:
    """The tiles, packed into one image, identical ones stored once."""

    def __init__(self) -> None:
        self.tiles: list[Image.Image] = []
        self._index: dict[bytes, int] = {}

    def add(self, tile: Image.Image) -> int:
        key = tile.tobytes()
        if key not in self._index:
            self._index[key] = len(self.tiles)
            self.tiles.append(tile)
        return self._index[key]

    def bucket(self, make, count: int = VARIANTS) -> list[int]:
        """`count` paintings of the same tile, deduplicated: a tile with no
        randomness in it collapses back to one. `make` returns a tile."""
        indices = []
        for _ in range(count):
            index = self.add(make())
            if index not in indices:
                indices.append(index)
        return indices

    def group(self, make, count: int = VARIANTS) -> list[list[int]]:
        """Like `bucket`, for a picture cut over several cells: `make`
        returns its tiles in a fixed order, the anchor's first. The result
        has one list per cell with one entry per variant, so the
        renderer's choice of variant lands on every piece of the same
        painting; a variant that repeats an earlier one whole is dropped
        from all of them."""
        out: list[list[int]] = []
        seen = set()
        for _ in range(count):
            indices = tuple(self.add(tile) for tile in make())
            if indices in seen:
                continue
            seen.add(indices)
            if not out:
                out = [[] for _ in indices]
            for piece, index in zip(out, indices):
                piece.append(index)
        return out

    def blank(self, index: int) -> bool:
        return self.tiles[index].getbbox() is None

    def image(self, columns: int = 16) -> Image.Image:
        rows = (len(self.tiles) + columns - 1) // columns
        sheet = Image.new("RGBA", (columns * TILE, rows * TILE), TRANSPARENT)
        for i, tile in enumerate(self.tiles):
            sheet.paste(tile, ((i % columns) * TILE, (i // columns) * TILE))
        return sheet


# ---------------------------------------------------------------------- keys


def parity_key() -> dict:
    return {"kind": "parity"}


def neighbour_key(dx: int, dy: int, glyphs: str, ground: bool = False
                  ) -> dict:
    """The cell `dx`, `dy` away shows one of `glyphs`. With `ground` it is
    the floor under that cell that is asked about (see `ground_config`)."""
    key = {"kind": "neighbour", "dx": dx, "dy": dy, "glyphs": glyphs}
    if ground:
        key["ground"] = True
    return key


def any_key(cells, glyphs: str) -> dict:
    """Any of the cells at these offsets shows one of `glyphs`."""
    return {"kind": "any", "cells": [list(c) for c in cells],
            "glyphs": glyphs}


def around(radius: int = 1, self_too: bool = True):
    """The offsets of the square `radius` cells round a cell."""
    return [(dx, dy) for dy in range(-radius, radius + 1)
            for dx in range(-radius, radius + 1)
            if self_too or (dx, dy) != (0, 0)]


def between_key(glyph: str) -> dict:
    """Something other than `glyph` above and below in the column."""
    return {"kind": "between", "glyph": glyph}


def before_run_key(glyphs: str) -> dict:
    """What lies before the run of the cell's own glyph: a wall, say."""
    return {"kind": "beforeRun", "glyphs": glyphs}


def row_has_key(dy: int, glyph: str) -> dict:
    return {"kind": "rowHas", "dy": dy, "glyph": glyph}


def pattern_key(a: int, b: int, mod: int, equals: int = 0,
                div: tuple[int, int] = (1, 1), values=None) -> dict:
    """The bakers dot a wall with graffiti on (x * a + y * b) % mod: a
    pattern, not a throw of the dice, so the renderer works it out too.
    `div` reads the position in blocks of that many cells instead, and
    `values` accepts any of several remainders instead of one."""
    key = {"kind": "pattern", "a": a, "b": b, "mod": mod, "equals": equals}
    if div != (1, 1):
        key["divX"], key["divY"] = div
    if values is not None:
        key["values"] = sorted(values)
    return key


def first_row_key(glyph: str, offset: int, compare: str) -> dict:
    """Against the first row of the place that holds `glyph`: the platform
    edge is the first row with a slab on it, and the baker paints that row
    differently. The row is read off the place's own ASCII, so it stays
    the one source of truth."""
    return {"kind": "firstRow", "glyph": glyph, "offset": offset,
            "compare": compare}


# --------------------------------------------------------------------- rules


def piece(dx: int, dy: int, buckets: list[list[int]]) -> dict:
    return {"dx": dx, "dy": dy, "buckets": buckets}


def rule(layer: str, glyphs: str, buckets: list[list[int]],
         keys: list[dict] | None = None, pieces: list[dict] | None = None,
         on: str | None = None) -> dict:
    """For these glyphs, on this layer, take a tile out of the bucket the
    keys point at. `pieces` are drawn on the cells round it with the same
    variant: what the tile leans out over, or the rest of a picture two
    cells wide. `on` is "glyph" or "ground", which the rule matches: the
    glyph of the cell, or the floor under it (see `ground_config`); the
    ground layer matches the floor, every other the glyph."""
    keys = keys or []
    assert layer in LAYERS and layer != "objects", layer
    assert len(buckets) == 2 ** len(keys), (layer, glyphs, len(buckets))
    out = {"layer": layer, "glyphs": glyphs, "keys": keys,
           "buckets": buckets}
    for spec in pieces or []:
        assert len(spec["buckets"]) == len(buckets), (layer, glyphs)
        assert all(not p or len(p) == len(b)
                   for p, b in zip(spec["buckets"], buckets)), (layer, glyphs)
    if pieces:
        out["pieces"] = pieces
    if on is not None:
        out["on"] = on
    return out


def spread(atlas: Atlas, paint_for, keys: list[dict] | None = None,
           reach: tuple[int, int, int, int] = (0, 1, 0, 0),
           count: int = VARIANTS):
    """The buckets and pieces of a rule whose painters draw beyond their
    own cell. `paint_for(index)` returns the painter, `paint(d, px, py)`,
    for the bucket `index` the keys choose; it is painted with its cell at
    (px, py) on a canvas that reaches `reach` = (left, up, right, down)
    cells further, and cut up. Returns `(buckets, pieces)` for `rule`: a
    piece that stays blank in every bucket is left out."""
    left, up, right, down = reach
    offsets = [(dx, dy) for dy in range(-up, down + 1)
               for dx in range(-left, right + 1) if (dx, dy) != (0, 0)]
    buckets = []
    by_offset: dict[tuple[int, int], list[list[int]]] = {o: [] for o in offsets}
    for index in range(2 ** len(keys or [])):
        def make(i=index):
            canvas = Image.new("RGBA", ((left + 1 + right) * TILE,
                                        (up + 1 + down) * TILE), TRANSPARENT)
            paint_for(i)(ImageDraw.Draw(canvas), left * TILE, up * TILE)
            return [canvas.crop(((left + dx) * TILE, (up + dy) * TILE,
                                 (left + dx + 1) * TILE,
                                 (up + dy + 1) * TILE))
                    for dx, dy in [(0, 0)] + offsets]
        grouped = atlas.group(make, count)
        buckets.append(grouped[0])
        for offset, tiles in zip(offsets, grouped[1:]):
            blank = all(atlas.blank(t) for t in tiles)
            by_offset[offset].append([] if blank else tiles)
    pieces = [piece(dx, dy, by_offset[(dx, dy)]) for dx, dy in offsets
              if any(by_offset[(dx, dy)])]
    return buckets, pieces


def leaning(atlas: Atlas, paint_for, keys: list[dict] | None = None,
            count: int = VARIANTS):
    """A rule whose painters lean out over the cell above: a monitor on a
    desk, a shelf taller than the wall it stands on."""
    return spread(atlas, paint_for, keys, (0, 1, 0, 0), count)


def tile_of(paint) -> Image.Image:
    """A tile painted by a painter that draws at (0, 0)."""
    tile = Image.new("RGBA", (TILE, TILE), TRANSPARENT)
    paint(ImageDraw.Draw(tile))
    return tile


def cell(paint, gx: int = 0, gy: int = 0) -> Image.Image:
    """A tile painted by a painter that takes coordinates in tiles and
    works out the pixels itself: paint on a canvas big enough and cut out
    the cell asked for. Which cell matters: the floors alternate on the
    parity of x + y."""
    wide = Image.new("RGBA", ((gx + 1) * TILE, (gy + 1) * TILE), TRANSPARENT)
    paint(ImageDraw.Draw(wide), gx, gy)
    return wide.crop((gx * TILE, gy * TILE, (gx + 1) * TILE, (gy + 1) * TILE))


class Neighbourhood:
    """What a painter that looks at its neighbours is shown while its tile
    is being painted: the cell itself, at `cell` because a tile is not
    always painted at the origin, and whatever we want around it."""

    def __init__(self, glyph: str, around, cell=(0, 0)) -> None:
        self.glyph = glyph
        self.around = around
        self.cell = cell
        self.width = 1
        self.height = 1

    def at(self, x: int, y: int) -> str:
        return self.glyph if (x, y) == self.cell else self.around(x, y)


class Block:
    """A room that is nothing but one rectangle of `glyph`: what a painter
    that measures its own wall is shown while its image is painted."""

    def __init__(self, glyph, width, height):
        self.glyph = glyph
        self.width = width
        self.height = height

    def at(self, x, y):
        if 0 <= x < self.width and 0 <= y < self.height:
            return self.glyph
        return "x"


def placed(rows: list[str], x: int, y: int, width: int, height: int
           ) -> dict:
    """What an object placed by hand at (x, y) carries so the test can tell
    when the rows under it change: those rows, cut to its footprint."""
    return {"at": [x, y],
            "under": [rows[r][x:x + width] for r in range(y, y + height)]}


# ------------------------------------------------------------ the ground


def ground_config(**config) -> dict:
    """How an outdoor place finds the floor under a cell that is not one:
    a car stands on the carriageway, a lamp post on the pavement. The
    rules of the ground layer match that floor, not the glyph. The keys:

    - `buildings`: glyphs with no floor under them at all;
    - `roads`, `walks`: glyphs that are the carriageway (`.`) and the
      pavement (`=`); `floors`: glyphs that are a floor of their own;
    - `footway`: street furniture, which looks for its floor up and down
      its column as well as along its row;
    - `keep`: glyphs that keep their own glyph as their floor;
    - `lawn` and `lawnProps`: a prop of `lawnProps` next to `lawn` stands
      on the lawn.

    This is Level.surface in tools/build_street_level.py, which the
    reference draw calls, written down as data so the renderer in
    lib/game/render/tile_atlas.dart can repeat it."""
    return dict(config)


def ground_of(rows: list[str], config: dict, outside: str):
    """The floor under every cell, as the renderer works it out."""
    from build_street_level import Level  # noqa: PLC0415 - the reference

    level = Level(rows)
    height, width = len(rows), len(rows[0])

    def at(x, y):
        if 0 <= x < width and 0 <= y < height:
            return rows[y][x]
        return outside

    out = []
    for y in range(height):
        line = []
        for x in range(width):
            glyph = rows[y][x]
            if glyph in config["buildings"] or glyph in config["keep"]:
                line.append(glyph)
            elif glyph in config["lawnProps"] and config["lawn"] in (
                    at(x - 1, y), at(x + 1, y), at(x, y - 1), at(x, y + 1)):
                line.append(config["lawn"])
            else:
                line.append(level.surface(x, y))
        out.append("".join(line))
    return out


# ------------------------------------------------------ the reference draw
# What the renderer in lib/game/render/tile_place_component.dart has to do,
# written out once here so --preview can show a converted place without a
# device, and --compare can hold the renderer to it.

def variant(tiles: list[int], x: int, y: int) -> int:
    """Which of a bucket's tiles falls on this cell: a hash of the place
    in the grid, so the grit is the same at every start and there is no
    seed to save. lib/game/render/tile_place_component.dart repeats it."""
    return ((x * 73856093) ^ (y * 19349663)) % len(tiles)


def compose(rows: list[str], place: dict, tiles: list[Image.Image],
            opened: bool = False) -> Image.Image:
    width, height = len(rows[0]), len(rows)
    outside = place.get("outside", "x")

    def at(x: int, y: int) -> str:
        if 0 <= x < width and 0 <= y < height:
            return rows[y][x]
        return outside

    ground = ground_of(rows, place["ground"], outside) \
        if "ground" in place else rows

    def ground_at(x: int, y: int) -> str:
        if 0 <= x < width and 0 <= y < height:
            return ground[y][x]
        return outside

    def first_row(glyph: str) -> int:
        return next((y for y in range(height) if glyph in rows[y]), 0)

    def truth(key: dict, x: int, y: int) -> bool:
        kind = key["kind"]
        if kind == "parity":
            return (x + y) % 2 == 1
        if kind == "neighbour":
            look = ground_at if key.get("ground") else at
            return look(x + key["dx"], y + key["dy"]) in key["glyphs"]
        if kind == "any":
            return any(at(x + dx, y + dy) in key["glyphs"]
                       for dx, dy in key["cells"])
        if kind == "pattern":
            value = ((x // key.get("divX", 1)) * key["a"]
                     + (y // key.get("divY", 1)) * key["b"]) % key["mod"]
            if "values" in key:
                return value in key["values"]
            return value == key["equals"]
        if kind == "firstRow":
            edge = first_row(key["glyph"]) + key["offset"]
            return y <= edge if key["compare"] == "le" else y == edge
        if kind == "between":
            return any(at(x, r) != key["glyph"] for r in range(y)) and \
                any(at(x, r) != key["glyph"] for r in range(y + 1, height))
        if kind == "beforeRun":
            here = at(x, y)
            start = x
            while at(start - 1, y) == here:
                start -= 1
            return at(start - 1, y) in key["glyphs"]
        if kind == "rowHas":
            return 0 <= y + key["dy"] < height and \
                key["glyph"] in rows[y + key["dy"]]
        raise ValueError(kind)

    colour = place["void"].lstrip("#")
    void = tuple(int(colour[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
    out = Image.new("RGBA", (width * TILE, height * TILE), void)

    def draw(tile: int, x: int, y: int) -> None:
        if 0 <= x < width and 0 <= y < height:
            out.alpha_composite(tiles[tile], (x * TILE, y * TILE))

    for layer in LAYERS:
        if layer == "objects":
            for obj in place["objects"]:
                sprite = obj["openSprite"] if opened and "openSprite" in obj \
                    else obj["sprite"]
                if "at" in obj:
                    x0, y0 = obj["at"]
                else:
                    cells = [(x, y) for y in range(height)
                             for x in range(width) if at(x, y) == obj["glyph"]]
                    if not cells:
                        continue
                    x0 = min(x for x, _ in cells)
                    y0 = min(y for _, y in cells)
                out.alpha_composite(
                    sprite, (x0 * TILE, (y0 + obj.get("offsetY", 0)) * TILE))
            continue
        specs = [spec for spec in place["rules"] if spec["layer"] == layer]
        for y in range(height):
            for x in range(width):
                for spec in specs:
                    on = spec.get("on", "ground" if layer == "ground"
                                  else "glyph")
                    glyph = ground[y][x] if on == "ground" else rows[y][x]
                    if glyph not in spec["glyphs"]:
                        continue
                    index = 0
                    for bit, key in enumerate(spec["keys"]):
                        if truth(key, x, y):
                            index |= 1 << bit
                    bucket = spec["buckets"][index]
                    if not bucket:
                        continue
                    v = variant(bucket, x, y)
                    draw(bucket[v], x, y)
                    for extra in spec.get("pieces", []):
                        tiles_there = extra["buckets"][index]
                        if tiles_there:
                            draw(tiles_there[v], x + extra["dx"],
                                 y + extra["dy"])
    return out
