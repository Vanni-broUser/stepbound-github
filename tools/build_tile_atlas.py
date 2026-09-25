#!/usr/bin/env python3
"""Bake the tile atlas the game paints converted places from.

A place used to exist twice: as the ASCII rows the simulation reads and as
a PNG painted from those rows by a baker. A converted place has no PNG:
the renderer paints it at runtime from the same rows, one tile per glyph,
out of assets/tiles/atlas.png.

This is where the bakers' *art* goes on living once their *composition*
dies. A baker knew two things: how to paint a bench, and where the benches
are. The second is in the ASCII rows and belongs to the game; only the
first is here. The rows are never read by this script: it paints tiles,
not places.

    python tools/build_tile_atlas.py            repaint the atlas
    python tools/build_tile_atlas.py --check    fail if it is out of date
    python tools/build_tile_atlas.py --preview  draw the places for the eye

What the manifest says, per place, is a list of ordered rules: for the
glyphs of this rule, on this layer, take a tile out of this bucket. The
bucket is chosen by a handful of boolean keys (the parity of the cell, the
row, a neighbour), and the tile inside it by a hash of the position, so
the grit falls the same way at every start and nothing has to be saved.
Objects too big for a cell -- the railcar, a two-tile door -- are their
own images, anchored to the glyph that names them.
"""
from __future__ import annotations

import argparse
import json
import os
import random
import sys
import tempfile

from PIL import Image, ImageChops, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_street_level import (  # noqa: E402
    BLOOD,
    BLOOD_DARK,
    OUTLINE,
    RAINBOW,
    TILE,
    paint_chair,
    paint_emblem,
    paint_text,
    rect,
    shade,
    text_width,
)
from build_mall import Room, paint_blood  # noqa: E402
import build_airliner as airliner  # noqa: E402
import build_station as station  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILES = os.path.join("assets", "tiles")
ATLAS = os.path.join(TILES, "atlas.png")
MANIFEST = os.path.join(TILES, "atlas_manifest.json")
OBJECTS = os.path.join(TILES, "objects")

# How many times the same kind of tile is painted with fresh grit. The
# renderer picks between them with a hash of the tile's position: enough
# that no eye finds the repeat, few enough that the atlas stays small.
VARIANTS = 12

# One seed for the whole atlas: the tiles are art, and art that changes
# every time it is baked cannot be reviewed in a diff.
SEED = 20260925

TRANSPARENT = (0, 0, 0, 0)


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

    def pairs(self, make, count: int = VARIANTS
              ) -> tuple[list[int], list[int]]:
        """Like `bucket`, for a tile that leans out over the cell above:
        `make` returns (tile, overhang). The two lists have one entry per
        variant, so the renderer's choice of variant lands on both halves
        of the same painting; a variant that repeats an earlier pair is
        dropped from both."""
        tiles, ups, seen = [], [], set()
        for _ in range(count):
            tile, up = make()
            pair = (self.add(tile), self.add(up))
            if pair not in seen:
                seen.add(pair)
                tiles.append(pair[0])
                ups.append(pair[1])
        return tiles, ups

    def image(self, columns: int = 16) -> Image.Image:
        rows = (len(self.tiles) + columns - 1) // columns
        sheet = Image.new("RGBA", (columns * TILE, rows * TILE), TRANSPARENT)
        for i, tile in enumerate(self.tiles):
            sheet.paste(tile, ((i % columns) * TILE, (i // columns) * TILE))
        return sheet


def parity_key() -> dict:
    return {"kind": "parity"}


def row_key(y: int) -> dict:
    return {"kind": "row", "y": y}


def neighbour_key(dx: int, dy: int, glyphs: str) -> dict:
    return {"kind": "neighbour", "dx": dx, "dy": dy, "glyphs": glyphs}


def before_run_key(glyphs: str) -> dict:
    """What lies before the run of the cell's own glyph: a wall, say."""
    return {"kind": "beforeRun", "glyphs": glyphs}


def row_has_key(dy: int, glyph: str) -> dict:
    return {"kind": "rowHas", "dy": dy, "glyph": glyph}


def rule(layer: str, glyphs: str, buckets: list[list[int]],
         keys: list[dict] | None = None,
         up: list[list[int]] | None = None) -> dict:
    """`up`, if given, is drawn on the cell above: what the tile leans out
    over it. One bucket per bucket, as long as the bucket it goes with."""
    keys = keys or []
    assert len(buckets) == 2 ** len(keys), (layer, glyphs, len(buckets))
    out = {"layer": layer, "glyphs": glyphs, "keys": keys,
           "buckets": buckets}
    if up is not None:
        assert len(up) == len(buckets), (layer, glyphs)
        assert all(not u or len(u) == len(b) for u, b in zip(up, buckets)),             (layer, glyphs)
        out["up"] = up
    return out


def leaning(atlas: Atlas, paint_for, keys: list[dict] | None = None,
            count: int = VARIANTS):
    """The buckets and overhangs of a rule whose painters lean out over the
    cell above. `paint_for(index)` returns the painter, `paint(d, px, py)`,
    for the bucket `index` the keys choose. It is painted on a canvas two
    cells high: what falls on the cell above is the overhang. Returns
    `(buckets, up)`, to hand to `rule`."""
    buckets, ups = [], []
    for index in range(2 ** len(keys or [])):
        def make(i=index):
            canvas = Image.new("RGBA", (TILE, TILE * 2), TRANSPARENT)
            paint_for(i)(ImageDraw.Draw(canvas), 0, TILE)
            return (canvas.crop((0, TILE, TILE, TILE * 2)),
                    canvas.crop((0, 0, TILE, TILE)))
        tiles, up = atlas.pairs(make, count)
        # A painter that never reaches the cell above has no overhang.
        blank = all(atlas.tiles[u].getbbox() is None for u in up)
        buckets.append(tiles)
        ups.append([] if blank else up)
    return buckets, ups


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

    def is_wall(self, x: int, y: int) -> bool:
        return self.at(x, y) in station.WALLS


# --------------------------------------------------- the upper Duomo's art
# Moved here from tools/build_duomo_upper.py, which this atlas replaces:
# the dining hall and dormitory above the Duomo, where the community lives.

LINEN = (174, 164, 146)
LINEN_LIGHT = (208, 198, 178)


def paint_table(d, px, py):
    rect(d, px, py + 3, TILE, 9, WOOD)
    rect(d, px, py + 3, TILE, 2, WOOD_LIGHT)
    rect(d, px + 2, py + 12, 3, 3, shade(WOOD, -22))
    rect(d, px + 11, py + 12, 3, 3, shade(WOOD, -22))


def paint_refectory_chair(d, px, py):
    rect(d, px + 3, py + 4, 10, 7, WOOD)
    rect(d, px + 4, py + 5, 8, 2, WOOD_LIGHT)
    rect(d, px + 4, py + 11, 2, 4, shade(WOOD, -20))
    rect(d, px + 10, py + 11, 2, 4, shade(WOOD, -20))


def paint_bed(d, px, py):
    rect(d, px + 1, py + 2, 14, 13, WOOD)
    rect(d, px + 2, py + 3, 12, 10, LINEN)
    rect(d, px + 2, py + 3, 12, 3, LINEN_LIGHT)
    rect(d, px + 3, py + 4, 10, 2, (222, 214, 196))
    rect(d, px + 2, py + 12, 12, 2, shade(LINEN, -24))


def paint_cupboard(d, px, py):
    rect(d, px + 2, py, 12, 16, shade(WOOD, -16))
    rect(d, px + 3, py + 1, 10, 14, WOOD)
    rect(d, px + 8, py + 1, 1, 14, shade(WOOD, -28))
    rect(d, px + 6, py + 8, 1, 1, GOLD)
    rect(d, px + 10, py + 8, 1, 1, GOLD)


def paint_stairs_down(d, px, py):
    rect(d, px, py, TILE, TILE, (34, 32, 34))
    for step in range(4):
        inset = step * 2
        rect(d, px + inset, py + 2 + step * 3, TILE - inset, 2,
             shade(STONE, -step * 14))


def paint_locked_door(d, px, py):
    """A shut door with the same white interaction hand as the bar. It
    stands two tiles high, so it is an object, not a tile."""
    top = py - TILE
    rect(d, px + 1, top, TILE - 2, TILE * 2, (24, 22, 22))
    rect(d, px + 3, top + 2, TILE - 6, TILE * 2 - 3, (72, 48, 34))
    rect(d, px + 4, top + 3, TILE - 8, 2, (108, 76, 50))
    rect(d, px + 4, py + 2, TILE - 8, 1, (44, 30, 24))
    rect(d, px + 11, py + 7, 2, 2, (188, 158, 82))
    for ox, oy, width, height in ((7, 8, 2, 8), (5, 12, 6, 5), (4, 13, 2, 3)):
        rect(d, px + ox + 1, top + oy + 1, width, height, (24, 22, 22))
        rect(d, px + ox, top + oy, width, height, (244, 240, 228))


def paint_side_edge(d, px, py, right):
    """The dark line where a floor meets the darkness outside the room."""
    rect(d, px + (14 if right else 0), py, 2, TILE, (40, 40, 46))


def duomo_upper(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.duomoUpper, and its door object."""
    # The floor goes under everything that is not wall, void or the door.
    floor = [
        atlas.bucket(lambda p=parity: cell(
            lambda dd, gx, gy: duomo_floor(dd, rng, gx, gy), p, 0))
        for parity in (0, 1)
    ]
    walls = atlas.bucket(lambda: tile_of(lambda d: duomo_wall(d, 0, 0)), 1)
    front = atlas.bucket(
        lambda: tile_of(lambda d: duomo_wall(d, 0, 0, front=True)), 1)
    props = {
        "T": paint_table, "C": paint_refectory_chair, "B": paint_bed,
        "K": paint_cupboard, "D": paint_stairs_down,
        "d": lambda d, px, py: rect(d, px + 1, py, TILE - 2, 2, STONE_LIGHT),
    }
    rules = [
        rule("ground", ".*RTCBKDd", floor, [parity_key()]),
        rule("structures", "WI", [walls]),
        rule("structures", "w", [front]),
    ]
    for glyph, paint in props.items():
        rules.append(rule("structures", glyph, [atlas.bucket(
            lambda p=paint: tile_of(lambda d: p(d, 0, 0)), 1)]))
    for right in (False, True):
        dx = 1 if right else -1
        edge = atlas.bucket(lambda r=right: tile_of(
            lambda d: paint_side_edge(d, 0, 0, r)), 1)
        rules.append(rule("foreground", ".*RTCBKDd",
                          [[], edge], [neighbour_key(dx, 0, "x")]))
    door = Image.new("RGBA", (TILE, TILE * 2), TRANSPARENT)
    paint_locked_door(ImageDraw.Draw(door), 0, TILE)
    return {
        "void": "#060608",
        "voidGlyph": "x",
        "rules": rules,
        "objects": [{"glyph": "L", "image": "duomo_upper_door.png",
                     "offsetY": -1, "sprite": door}],
    }


def station_underpass(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.stationUnderpass: the corridor under
    the tracks, glazed tile over a dark plinth, lit by strip lights."""
    floor = atlas.bucket(lambda: cell(
        lambda d, gx, gy: station.paint_underpass_floor(d, rng, gx, gy)))
    wall = [
        atlas.bucket(lambda a=above: tile_of(
            lambda d: station.paint_underpass_wall(
                d, rng,
                Neighbourhood("W", lambda x, y, a=a: "W" if a else "."),
                0, 0)))
        for above in (False, True)
    ]
    front = atlas.bucket(
        lambda: tile_of(lambda d: station.paint_underpass_front(d, 0, 0)), 1)
    litter = atlas.bucket(
        lambda: tile_of(lambda d: station.paint_litter(d, rng, 0, 0)))
    blood = atlas.bucket(
        lambda: tile_of(lambda d: paint_blood(d, rng, 0, 0)))
    lamps = {
        glyph: atlas.bucket(lambda dead=dead: tile_of(
            lambda d: station.paint_lamp(d, 0, 0, dead)), 1)
        for glyph, dead in (("*", False), ("+", True))
    }

    def stairs(glyph):
        """The head of a flight: its two ends carry the handrail and half
        the arrow, so the key is whether the flight goes on beside it."""
        out = []
        for right in (False, True):
            for left in (False, True):
                out.append(atlas.bucket(lambda l=left, r=right, g=glyph:
                    tile_of(lambda d: station.paint_stairs(d, Neighbourhood(
                        g, lambda x, y, l=l, r=r, g=g: g
                        if (x == -1 and l) or (x == 1 and r) else "."),
                        0, 0)), 1))
        return out

    floored = ".:b*+Z"
    rules = [
        rule("ground", floored + "UD", [floor]),
        rule("structures", "W", wall, [neighbour_key(0, -1, "W")]),
        rule("structures", "w", [front]),
        rule("structures", ":", [litter]),
        rule("structures", "b", [blood]),
        rule("structures", "*", [lamps["*"]]),
        rule("structures", "+", [lamps["+"]]),
    ]
    for glyph in "UD":
        rules.append(rule("structures", glyph, stairs(glyph),
                          [neighbour_key(-1, 0, glyph),
                           neighbour_key(1, 0, glyph)]))
    for right in (False, True):
        edge = atlas.bucket(lambda r=right: tile_of(
            lambda d: paint_side_edge(d, 0, 0, r)), 1)
        rules.append(rule("foreground", floored + "UD", [[], edge],
                          [neighbour_key(1 if right else -1, 0, "x")]))
    return {"void": "#060608", "voidGlyph": "x", "rules": rules,
            "objects": []}


# ------------------------------------------------ the airliner cabin's art
# Painted by tools/build_airliner.py, which keeps the painters and lost the
# composition that baked this place; the roofs it opens on are still baked.

class Strip:
    """Three rows of a place, for a painter that asks whether the rows
    beside its own have a seat in them: what tells an aisle where the
    seats begin."""

    height = 3

    def __init__(self, above: bool, below: bool) -> None:
        self.rows = ["T" if above else ".", ".", "T" if below else "."]


def airliner_cabin(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.airlinerCabin: the hull seen from above,
    two banks of seats either side of the aisles, and the light that falls
    in at the two breaks."""
    floor = [
        atlas.bucket(lambda p=parity: cell(
            lambda d, gx, gy: airliner.cabin_floor(d, rng, gx, gy), p, 0))
        for parity in (0, 1)
    ]
    # A row with no seat in it is an aisle: the runner is laid down it, and
    # edged on whichever side the next row has seats. Bits, in key order:
    # this row has a seat, the row above has, the row below has.
    aisle = []
    for index in range(8):
        seated, above, below = (bool(index & 1), bool(index & 2),
                                bool(index & 4))
        aisle.append([] if seated else atlas.bucket(
            lambda a=above, b=below: cell(
                lambda d, gx, gy: airliner.cabin_aisle(
                    d, rng, Strip(a, b), gx, gy), 0, 1)))

    def hull(glyph):
        """The lockers are ribbed every third column: a pattern on x."""
        return [
            atlas.bucket(lambda g=gx: cell(
                lambda d, x, y: airliner.cabin_hull(
                    d, Neighbourhood(glyph, lambda *_: ".", (x, y)), x, y),
                g, 0), 1)
            for gx in (1, 0)
        ]

    def seat():
        out = []
        for below in (False, True):
            for above in (False, True):
                out.append(atlas.bucket(lambda a=above, b=below: tile_of(
                    lambda d: airliner.cabin_seat(d, Neighbourhood(
                        "T", lambda x, y, a=a, b=b: "T"
                        if (y == -1 and a) or (y == 1 and b) else "."),
                        0, 0)), 1))
        return out

    floored = ".:b*+ZM9KT"
    rules = [
        rule("ground", floored, floor, [parity_key()]),
        rule("ground", floored, aisle,
             [row_has_key(0, "T"), row_has_key(-1, "T"),
              row_has_key(1, "T")]),
    ]
    for glyph in "Ww":
        rules.append(rule("structures", glyph, hull(glyph),
                          [pattern_key(1, 0, 3)]))
    rules += [
        rule("structures", "I",
             [atlas.bucket(lambda: tile_of(lambda d: airliner.cabin_hull(
                 d, Neighbourhood("I", lambda *_: "."), 0, 0)), 1)]),
        rule("structures", "E", [atlas.bucket(lambda: tile_of(
            lambda d: airliner.cabin_break(d, 0, 0, roof=False)), 1)]),
        rule("structures", "O", [atlas.bucket(lambda: tile_of(
            lambda d: airliner.cabin_break(d, 0, 0, roof=True)), 1)]),
        rule("structures", "T", seat(),
             [neighbour_key(0, -1, "T"), neighbour_key(0, 1, "T")]),
        rule("structures", "K", [atlas.bucket(lambda: tile_of(
            lambda d: airliner.cabin_trolley(d, 0, 0)), 1)]),
        rule("structures", ":", [atlas.bucket(lambda: tile_of(
            lambda d: airliner.cabin_litter(d, rng, 0, 0)))]),
        rule("structures", "b", [atlas.bucket(lambda: tile_of(
            lambda d: airliner.cabin_blood(d, rng, 0, 0)))]),
    ]
    for glyph, steady in (("*", True), ("+", False)):
        rules.append(rule("structures", glyph, [atlas.bucket(
            lambda s=steady: tile_of(
                lambda d: airliner.cabin_lamp(d, 0, 0, s)), 1)]))
    return {"void": "#060608", "voidGlyph": "x", "rules": rules,
            "objects": []}



# ------------------------------------------------ the Bar Arcobaleno's art
# Moved here from tools/build_bar.py, which this atlas replaces: a chequered
# floor under broken glass and toppled chairs, the counter across the back,
# and the rainbow painted over the whole wall behind it.

CHECK_LIGHT = (176, 168, 150)
CHECK_DARK = (70, 64, 60)
BAR_WALL_FACE = (150, 120, 96)
BAR_WALL_TOP = (46, 40, 40)
SHELF = (86, 60, 40)
COUNTER = (110, 70, 44)
COUNTER_TOP = (150, 104, 66)
BOTTLES = [(60, 110, 60), (140, 90, 40), (180, 180, 170), (110, 40, 40),
           (60, 80, 120)]


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

    def is_wall(self, x, y):
        return self.at(x, y) in station.WALLS


def paint_bar_floor(d, rng, x, y):
    """Black and white tiles, four to a cell, grimy and cracked."""
    px, py = x * TILE, y * TILE
    for i in range(2):
        for j in range(2):
            light = (x * 2 + i + y * 2 + j) % 2
            rect(d, px + i * 8, py + j * 8, 8, 8,
                 CHECK_LIGHT if light else CHECK_DARK)
    for _ in range(4):
        rect(d, px + rng.randrange(16), py + rng.randrange(16), 1, 1,
             (100, 94, 86))
    if rng.random() < 0.15:
        cx, cy = px + rng.randrange(2, 12), py + rng.randrange(2, 12)
        for i in range(5):
            rect(d, cx + i, cy + (i % 3), 1, 1, (40, 36, 34))


def paint_glass(d, rng, px, py):
    """Broken bottles and glasses underfoot."""
    for _ in range(6):
        rect(d, px + rng.randrange(14), py + rng.randrange(14),
             rng.randint(1, 2), 1,
             rng.choice(((170, 200, 190), (90, 140, 90), (160, 110, 60))))


def paint_bar_back_wall(d, room, rng):
    """Shelves of bottles, most smashed, under the bar's rainbow painted
    across the whole wall, flaking."""
    ys = [y for y in range(room.height) if room.at(1, y) == "W"]
    top, bottom = min(ys), max(ys)
    x0 = min(x for x in range(room.width) if room.at(x, top) == "W")
    x1 = max(x for x in range(room.width) if room.at(x, top) == "W")
    px, py = x0 * TILE, top * TILE
    w, h = (x1 - x0 + 1) * TILE, (bottom - top + 1) * TILE
    rect(d, px, py, w, h, BAR_WALL_FACE)
    rect(d, px, py, w, 4, BAR_WALL_TOP)
    for i, colour in enumerate(RAINBOW):  # the mural, flaking off
        for x in range(px, px + w, 2):
            if rng.random() < 0.85:
                rect(d, x, py + 5 + i * 2, 2, 2, colour)
    sy = py + h - 4  # the shelf, bottles on it or smashed below
    rect(d, px, sy, w, 2, SHELF)
    for bx in range(px + 2, px + w - 2, 3):
        if rng.random() < 0.45:
            rect(d, bx, sy - 5, 2, 5, rng.choice(BOTTLES))
            rect(d, bx, sy - 6, 1, 1, (40, 40, 40))
    name = "BAR ARCOBALENO"  # the sign hung over the middle of the shelf
    tx = px + (w - text_width(name) * 2) // 2
    rect(d, tx - 3, py + 17, text_width(name) * 2 + 6, 14, OUTLINE)
    for i, letter in enumerate(name):
        paint_text(d, tx + i * 8, py + 19, letter,
                   RAINBOW[i % len(RAINBOW)], scale=2)


def paint_counter(d, room, x, y):
    px, py = x * TILE, y * TILE
    rect(d, px, py + 2, TILE, 13, COUNTER)
    rect(d, px, py + 2, TILE, 3, COUNTER_TOP)
    rect(d, px, py + 14, TILE, 2, (30, 26, 26))
    rect(d, px + (x * 5) % 12, py + 6, 1, 8, (84, 52, 32))
    if room.at(x + 1, y) != "K":
        rect(d, px + 14, py + 2, 2, 13, (84, 52, 32))
    if (x * 7) % 5 == 0:  # a glass still on the counter
        rect(d, px + 6, py, 2, 3, (170, 200, 190))


def paint_bar_table(d, px, py, first, last):
    rect(d, px, py + 13, TILE, 2, (30, 26, 26))
    rect(d, px, py + 4, TILE, 5, (130, 96, 60))
    rect(d, px, py + 4, TILE, 1, (160, 120, 80))
    if first:
        rect(d, px + 2, py + 9, 2, 5, (84, 60, 40))
    if last:
        rect(d, px + 12, py + 9, 2, 5, (84, 60, 40))


def paint_jukebox(d, px, py):
    """A jukebox, its dome smashed, only half of it lit by nothing."""
    rect(d, px + 2, py - 6, 28, 21, OUTLINE)
    rect(d, px + 3, py - 5, 26, 19, (120, 50, 60))
    rect(d, px + 5, py - 4, 22, 6, (200, 170, 90))
    for i, colour in enumerate(RAINBOW):
        rect(d, px + 5 + i * 4, py + 3, 3, 3, colour)
    rect(d, px + 8, py + 8, 16, 4, (40, 36, 40))
    rect(d, px + 12, py - 3, 6, 2, (30, 26, 26))  # the smashed dome


def paint_bar_front_wall(d, x, y):
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, BAR_WALL_TOP)
    rect(d, px, py + 3, TILE, 10, (60, 72, 84))
    rect(d, px + 3, py + 4, 2, 8, (110, 130, 150))
    if (x * 5) % 7 == 0:  # the window's smashed in
        rect(d, px + 6, py + 4, 6, 8, (20, 22, 26))


def paint_bar_door(d, px, py):
    rect(d, px, py, TILE, TILE, (150, 142, 124))
    rect(d, px + 1, py, 3, TILE, (70, 50, 36))  # the door hanging off
    rect(d, px + 5, py + 6, 3, 2, (120, 30, 30))


def paint_bar_locked_door(d, px, py):
    """The open service doorway under the dynamic locked-door component."""
    top = py - TILE
    rect(d, px + 1, top, TILE - 2, TILE * 2, OUTLINE)
    rect(d, px + 3, top + 2, TILE - 6, TILE * 2 - 3, (18, 16, 18))
    rect(d, px + 2, top + 1, 2, TILE * 2 - 2, (88, 58, 38))
    rect(d, px + 12, top + 1, 2, TILE * 2 - 2, (88, 58, 38))
    rect(d, px + 4, py + 12, TILE - 8, 4, (104, 96, 86))


# The wall behind the counter is painted as one piece, mural, sign and
# all: its size is the run of `W` in the bar's rows, and
# test/levels/tile_atlas_test.dart fails if they stop agreeing.
BAR_WALL_TILES = (20, 2)



POOL_FELT = (36, 98, 64)
POOL_FELT_DARK = (26, 76, 50)
POOL_RAIL = (74, 46, 28)
POOL_RAIL_LIGHT = (104, 68, 40)
POOL_POCKET = (16, 14, 14)
POOL_BALLS = [(226, 216, 196), (198, 58, 48), (58, 88, 168), (228, 188, 60)]

# Three ways the balls are left lying, so two cells of the same table do
# not show the same rack. Which one falls where is the usual hash.
POOL_RACKS = [
    ((2, 3, 0), (7, 2, 1), (11, 4, 2), (5, 8, 3)),
    ((3, 2, 1), (8, 5, 3), (12, 3, 0)),
    ((2, 6, 2), (6, 3, 0), (10, 7, 1), (12, 2, 3)),
]


def paint_pool_table(d, px, py, left, right, top, balls=0):
    """One cell of a pool table: the baize, the rail wherever the table
    ends, a pocket in every corner and the balls left on the cloth. The
    table is two rows deep, so `top` says which half this is."""
    rect(d, px, py, TILE, TILE, POOL_FELT)
    if top:
        rect(d, px, py, TILE, 5, POOL_RAIL)
        rect(d, px, py, TILE, 2, POOL_RAIL_LIGHT)
        rect(d, px, py + 5, TILE, 1, POOL_FELT_DARK)
    else:
        rect(d, px, py + TILE - 5, TILE, 5, POOL_RAIL)
        rect(d, px, py + TILE - 5, TILE, 1, POOL_RAIL_LIGHT)
        rect(d, px, py + TILE - 6, TILE, 1, POOL_FELT_DARK)
    if not left:
        rect(d, px, py, 3, TILE, POOL_RAIL)
        rect(d, px, py, 1, TILE, POOL_RAIL_LIGHT)
        rect(d, px + 3, py, 1, TILE, POOL_FELT_DARK)
    if not right:
        rect(d, px + TILE - 3, py, 3, TILE, POOL_RAIL)
        rect(d, px + TILE - 4, py, 1, TILE, POOL_FELT_DARK)
    for corner_x, there_x in ((0, not left), (TILE - 5, not right)):
        if not there_x:
            continue
        corner_y = 0 if top else TILE - 5
        d.ellipse([px + corner_x, py + corner_y,
                   px + corner_x + 4, py + corner_y + 4], fill=POOL_POCKET)
    if not top and left and right:  # the balls, on the open cloth
        for bx, by, colour in POOL_RACKS[balls % len(POOL_RACKS)]:
            d.ellipse([px + bx, py + by, px + bx + 3, py + by + 3],
                      fill=POOL_BALLS[colour])


def bar_arcobaleno(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.barArcobaleno."""
    floor = [
        atlas.bucket(lambda p=parity: cell(
            lambda dd, gx, gy: paint_bar_floor(dd, rng, gx, gy), p, 0))
        for parity in (0, 1)
    ]
    # The counter: the glass left on it falls on a pattern, so a key says
    # where. Its 1 px of grain follows the column too, but nothing hangs
    # on where that line sits, so those stay variants picked by the hash.
    counter = [[] for _ in range(4)]
    for column in range(60):  # 60 = every pair of the two patterns
        for right in (False, True):
            wide = Image.new("RGBA", ((column + 1) * TILE, TILE), TRANSPARENT)
            # The cell being painted is at `column`, so its neighbour is
            # the one after it, not the one after the origin.
            paint_counter(
                ImageDraw.Draw(wide),
                Neighbourhood("K", lambda x, y, r=right, c=column: "K"
                              if (x == c + 1 and r) else ".",
                              cell=(column, 0)),
                column, 0)
            index = (1 if right else 0) | (2 if (column * 7) % 5 == 0 else 0)
            tile = atlas.add(
                wide.crop((column * TILE, 0, (column + 1) * TILE, TILE)))
            if tile not in counter[index]:
                counter[index].append(tile)
    # The front wall's smashed windows fall on a pattern as well.
    front = [[], []]
    for column in range(7):
        wide = Image.new("RGBA", ((column + 1) * TILE, TILE), TRANSPARENT)
        paint_bar_front_wall(ImageDraw.Draw(wide), column, 0)
        tile = atlas.add(
            wide.crop((column * TILE, 0, (column + 1) * TILE, TILE)))
        index = 1 if (column * 5) % 7 == 0 else 0
        if tile not in front[index]:
            front[index].append(tile)
    # In key order: the bits are "the table goes on to the left", "to the
    # right" and "above", and the painter wants the opposite of the last
    # one -- a cell with nothing above it is the top half.
    pool = []
    for above in (False, True):
        for right in (False, True):
            for left in (False, True):
                racks = len(POOL_RACKS) if (left and right and above) else 1
                pool.append([atlas.add(tile_of(
                    lambda d, le=left, ri=right, ab=above, b=rack:
                    paint_pool_table(d, 0, 0, le, ri, not ab, b)))
                    for rack in range(racks)])
    floored = ".*:qbU+KTJDEP"
    rules = [
        rule("ground", floored, floor, [parity_key()]),
        rule("structures", "w", front, [pattern_key(5, 0, 7)]),
        rule("structures", "E", [atlas.bucket(
            lambda: tile_of(lambda d: paint_bar_door(d, 0, 0)), 1)]),
        rule("structures", ":", [atlas.bucket(
            lambda: tile_of(lambda d: paint_glass(d, rng, 0, 0)))]),
        rule("structures", "b", [atlas.bucket(
            lambda: tile_of(lambda d: paint_blood(d, rng, 0, 0)))]),
        rule("structures", "q", [atlas.bucket(
            lambda: tile_of(
                lambda d: paint_chair(d, 0, 0, toppled=True)), 1)]),
    ]
    for right in (False, True):
        edge = atlas.bucket(lambda r=right: tile_of(
            lambda d: paint_side_edge(d, 0, 0, r)), 1)
        rules.append(rule("foreground", floored, [[], edge],
                          [neighbour_key(1 if right else -1, 0, "x")]))
    # The pool tables are two rows deep and as long as the rows say: each
    # cell asks whether the table goes on beside and above it.
    rules.append(rule("foreground", "P", pool, [
        neighbour_key(-1, 0, "P"),
        neighbour_key(1, 0, "P"),
        neighbour_key(0, -1, "P"),
    ]))
    rules.append(rule("foreground", "K", counter,
                      [neighbour_key(1, 0, "K"), pattern_key(7, 0, 5)]))
    # The legs go where the run of tables ends, so the key is "there is a
    # table beside me" and the painter wants the opposite of it.
    rules.append(rule("foreground", "T", [
        atlas.bucket(lambda le=left, ri=right: tile_of(
            lambda d: paint_bar_table(d, 0, 0, not le, not ri)), 1)
        for right in (False, True) for left in (False, True)
    ], [neighbour_key(-1, 0, "T"), neighbour_key(1, 0, "T")]))
    wall = Image.new("RGBA", (BAR_WALL_TILES[0] * TILE,
                              BAR_WALL_TILES[1] * TILE), TRANSPARENT)
    paint_bar_back_wall(ImageDraw.Draw(wall),
                        Block("W", *BAR_WALL_TILES), rng)
    juke = Image.new("RGBA", (TILE * 2, TILE * 2), TRANSPARENT)
    paint_jukebox(ImageDraw.Draw(juke), 0, TILE)
    door = Image.new("RGBA", (TILE, TILE * 2), TRANSPARENT)
    paint_bar_locked_door(ImageDraw.Draw(door), 0, TILE)
    return {
        "void": "#060608", "voidGlyph": "x", "rules": rules,
        "objects": [
            {"glyph": "W", "image": "bar_back_wall.png",
             "tiles": list(BAR_WALL_TILES), "sprite": wall},
            {"glyph": "J", "image": "bar_jukebox.png", "offsetY": -1,
             "sprite": juke},
            {"glyph": "D", "image": "bar_service_door.png", "offsetY": -1,
             "sprite": door},
        ],
    }



# ------------------------------------------------------- the Duomo's art
# Moved here from tools/build_duomo.py, which this atlas replaces: the
# three-nave interior of the harbour Duomo, and the masonry vocabulary the
# floor above shares with it.

DUOMO_FLOOR = (116, 106, 94)
DUOMO_FLOOR_ALT = (130, 120, 106)
DUOMO_JOINT = (76, 70, 66)
STONE = (178, 168, 148)
STONE_LIGHT = (210, 198, 170)
STONE_DARK = (112, 104, 94)
WOOD = (86, 56, 36)
WOOD_LIGHT = (128, 86, 52)
GOLD = (184, 146, 54)


def duomo_floor(d, rng, x, y):
    """Worn flagstones, two tones on the parity of x + y, gritty."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, DUOMO_FLOOR if (x + y) % 2 else DUOMO_FLOOR_ALT)
    rect(d, px, py, TILE, 1, DUOMO_JOINT)
    rect(d, px, py, 1, TILE, DUOMO_JOINT)
    for _ in range(3):
        rect(d, px + rng.randrange(15), py + rng.randrange(15), 1, 1,
             DUOMO_JOINT)


def duomo_wall(d, px, py, front=False):
    rect(d, px, py, TILE, TILE, STONE_DARK if front else STONE)
    rect(d, px, py, TILE, 2, shade(STONE, 24))
    rect(d, px, py + 8, TILE, 1, STONE_DARK)


def paint_altar(d, px, py):
    rect(d, px, py + 3, TILE, 12, STONE)
    rect(d, px, py + 3, TILE, 3, STONE_LIGHT)
    rect(d, px + 2, py + 6, TILE - 4, 6, (188, 176, 150))
    rect(d, px + 7, py, 2, 5, GOLD)


def paint_column(d, px, py):
    d.ellipse([px + 2, py, px + 13, py + 15], fill=STONE_DARK)
    d.ellipse([px + 3, py + 1, px + 12, py + 13], fill=STONE)
    rect(d, px + 5, py + 2, 3, 11, STONE_LIGHT)
    rect(d, px + 1, py + 13, 14, 3, STONE_DARK)


def paint_pew(d, px, py):
    rect(d, px, py + 4, TILE, 8, WOOD)
    rect(d, px, py + 4, TILE, 2, WOOD_LIGHT)
    rect(d, px + 1, py + 12, 3, 3, shade(WOOD, -20))
    rect(d, px + 12, py + 12, 3, 3, shade(WOOD, -20))


def paint_statue(d, px, py):
    rect(d, px + 3, py + 12, 10, 4, STONE_DARK)
    rect(d, px + 5, py + 5, 6, 8, STONE)
    d.ellipse([px + 5, py + 1, px + 10, py + 6], fill=STONE_LIGHT)
    rect(d, px + 3, py + 7, 3, 5, STONE)
    rect(d, px + 10, py + 7, 3, 5, STONE)


def paint_duomo_stairs(d, px, py):
    rect(d, px, py, TILE, TILE, (42, 40, 42))
    for step in range(4):
        inset = step * 2
        rect(d, px + inset, py + 3 + step * 3, TILE - inset, 2,
             shade(STONE, -step * 14))


def paint_portal(d, px, py):
    rect(d, px, py, TILE, TILE, (26, 24, 26))
    rect(d, px + 3, py + 1, 10, TILE - 1, (186, 178, 160))
    rect(d, px + 5, py + 2, 6, TILE - 2, (220, 210, 188))
    rect(d, px, py, 3, TILE, WOOD)
    rect(d, px + 13, py, 3, TILE, WOOD)


def duomo(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.duomo. The altar stands on no floor:
    the baker skips it, and so do we."""
    floor = [
        atlas.bucket(lambda p=parity: cell(
            lambda dd, gx, gy: duomo_floor(dd, rng, gx, gy), p, 0))
        for parity in (0, 1)
    ]
    props = {
        "P": paint_column, "T": paint_pew, "S": paint_statue,
        "U": paint_duomo_stairs, "E": paint_portal, "A": paint_altar,
    }
    floored = ".*:p123PTSUE"
    rules = [
        rule("ground", floored, floor, [parity_key()]),
        rule("structures", "WI", [atlas.bucket(
            lambda: tile_of(lambda d: duomo_wall(d, 0, 0)), 1)]),
        rule("structures", "w", [atlas.bucket(
            lambda: tile_of(lambda d: duomo_wall(d, 0, 0, front=True)), 1)]),
    ]
    for glyph, paint in props.items():
        rules.append(rule("structures", glyph, [atlas.bucket(
            lambda p=paint: tile_of(lambda d: p(d, 0, 0)), 1)]))
    for right in (False, True):
        edge = atlas.bucket(lambda r=right: tile_of(
            lambda d: paint_side_edge(d, 0, 0, r)), 1)
        rules.append(rule("foreground", floored + "A", [[], edge],
                          [neighbour_key(1 if right else -1, 0, "x")]))
    return {"void": "#060608", "voidGlyph": "x", "rules": rules,
            "objects": []}



# ------------------------------------------- the Bar Arcobaleno's storeroom
# Moved here from tools/build_bar_backroom.py, which this atlas replaces:
# the cramped room behind the bar, shelves and crates on a bare screed.

BACKROOM_FLOOR = (80, 74, 68)
BACKROOM_FLOOR_ALT = (96, 88, 78)
BACKROOM_WALL = (112, 96, 82)
BACKROOM_WALL_DARK = (54, 46, 42)
BACKROOM_WOOD = (94, 62, 38)


def paint_backroom_floor(d, px, py, alternate):
    """Bare screed, laid in two tones, with the shadow of the course above."""
    rect(d, px, py, TILE, TILE,
         BACKROOM_FLOOR_ALT if alternate else BACKROOM_FLOOR)
    rect(d, px, py, TILE, 1, BACKROOM_WALL_DARK)


def paint_backroom_wall(d, px, py, front):
    rect(d, px, py, TILE, TILE,
         BACKROOM_WALL_DARK if front else BACKROOM_WALL)
    rect(d, px, py, TILE, 2, shade(BACKROOM_WALL, 20))


def paint_backroom_shelf(d, px, py):
    rect(d, px, py + 4, TILE, 11, BACKROOM_WOOD)
    rect(d, px, py + 4, TILE, 2, shade(BACKROOM_WOOD, 30))


def paint_backroom_crate(d, px, py):
    rect(d, px + 1, py + 2, 14, 13, BACKROOM_WOOD)
    rect(d, px + 2, py + 3, 12, 2, shade(BACKROOM_WOOD, 28))
    rect(d, px + 7, py + 3, 2, 11, shade(BACKROOM_WOOD, -24))


def paint_backroom_litter(d, rng, px, py):
    for _ in range(8):
        rect(d, px + rng.randrange(15), py + rng.randrange(15),
             rng.randint(1, 3), 1, (52, 48, 46))


def paint_backroom_door(d, px, py):
    rect(d, px, py, TILE, TILE, (28, 26, 28))
    rect(d, px + 4, py + 2, 8, TILE - 2, (176, 164, 144))


def bar_backroom(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.barBackroom."""
    floor = [
        atlas.bucket(lambda a=alternate: tile_of(
            lambda d: paint_backroom_floor(d, 0, 0, a)), 1)
        for alternate in (True, False)
    ]
    props = {
        "K": paint_backroom_shelf,
        "B": paint_backroom_crate,
        "E": paint_backroom_door,
    }
    # The floor goes under every glyph that is not wall or void; the door
    # covers its cell whole, the rest let it show.
    floored = ".*8KB:E"
    rules = [
        rule("ground", floored, floor, [parity_key()]),
        rule("structures", "WI",
             [atlas.bucket(lambda: tile_of(
                 lambda d: paint_backroom_wall(d, 0, 0, False)), 1)]),
        rule("structures", "w",
             [atlas.bucket(lambda: tile_of(
                 lambda d: paint_backroom_wall(d, 0, 0, True)), 1)]),
        rule("structures", ":", [atlas.bucket(
            lambda: tile_of(lambda d: paint_backroom_litter(d, rng, 0, 0)))]),
    ]
    for glyph, paint in props.items():
        rules.append(rule("structures", glyph, [atlas.bucket(
            lambda p=paint: tile_of(lambda d: p(d, 0, 0)), 1)]))
    for right in (False, True):
        edge = atlas.bucket(lambda r=right: tile_of(
            lambda d: paint_side_edge(d, 0, 0, r)), 1)
        rules.append(rule("foreground", floored, [[], edge],
                          [neighbour_key(1 if right else -1, 0, "x")]))
    return {"void": "#060608", "voidGlyph": "x", "rules": rules,
            "objects": []}




def pattern_key(a: int, b: int, mod: int, equals: int = 0) -> dict:
    """The bakers dot a wall with graffiti on (x * a + y * b) % mod: a
    pattern, not a throw of the dice, so the renderer works it out too."""
    return {"kind": "pattern", "a": a, "b": b, "mod": mod, "equals": equals}


def first_row_key(glyph: str, offset: int, compare: str) -> dict:
    """Against the first row of the place that holds `glyph`: the platform
    edge is the first row with a slab on it, and the baker paints that row
    differently. The row is read off the place's own ASCII, so it stays
    the one source of truth."""
    return {"kind": "firstRow", "glyph": glyph, "offset": offset,
            "compare": compare}


# The railcar is one object, not tiles: its grime runs across the grid. It
# is painted at the size of the run of `M` in the far platform's rows;
# test/levels/tile_atlas_test.dart fails if the rows stop agreeing.
RAILCAR_TILES = (27, 3)
RAILCAR_DOOR_TILE = 23


def station_far_side(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.stationFarSide: the far platform, the
    track and the railcar Luigi is holed up in."""
    def platform(parity: int, edge: bool):
        return atlas.bucket(lambda p=parity, e=edge: cell(
            lambda d, gx, gy: station.paint_platform(
                d, rng, gx, gy, 0 if e else -1), p, 0))

    def hall(parity: int):
        return atlas.bucket(lambda p=parity: cell(
            lambda d, gx, gy: station.paint_hall(d, rng, gx, gy), p, 0))

    ballast = atlas.bucket(
        lambda: tile_of(lambda d: station.paint_ballast(d, rng, 0, 0)))
    rails = [
        atlas.bucket(lambda c=continuing: tile_of(
            lambda d: station.paint_rails(
                d, rng, Neighbourhood("-", lambda x, y: "-" if c else "."),
                0, 0)))
        for continuing in (False, True)
    ]
    # In key order: bit 0 is "there is another wall above", which is the
    # opposite of the painter's own `top`, and bit 1 is the tag pattern.
    wall = []
    for tagged in (False, True):
        for above in (False, True):
            wall.append(atlas.bucket(lambda a=above, g=tagged: cell(
                lambda d, gx, gy: station.paint_back_wall(
                    d, rng,
                    Neighbourhood("W", lambda x, y, a=a: "W" if a else "."),
                    gx, gy),
                0 if g else 1, 0)))
    litter = atlas.bucket(
        lambda: tile_of(lambda d: station.paint_litter(d, rng, 0, 0)))

    def ends(paint, glyph):
        """Four tiles: the two ends of a run, its middle, and a run of one.
        `paint` is given a neighbourhood that says which sides continue."""
        out = []
        for right in (False, True):
            for left in (False, True):
                out.append(atlas.bucket(lambda l=left, r=right: tile_of(
                    lambda d: paint(d, Neighbourhood(
                        glyph,
                        lambda x, y, l=l, r=r: glyph
                        if (x == -1 and l) or (x == 1 and r) else ".",
                    ), 0, 0)), 1))
        return out

    rules = [
        # The ground, in the order the baker laid it: track, ballast, the
        # platform and its edge, and the booking hall's terrazzo elsewhere.
        rule("ground", "-", rails, [neighbour_key(-1, 0, "-")]),
        rule("ground", ",M", [ballast]),
        rule("ground", "=Tn",
             [platform(0, False), platform(1, False),
              platform(0, True), platform(1, True)],
             [parity_key(), first_row_key("=", 0, "eq")]),
        # Litter lies on the platform if it is near it, on the hall floor
        # if it is not: the baker drew the line two rows below the edge.
        rule("ground", ":",
             [hall(0), hall(1), platform(0, False), platform(1, False)],
             [parity_key(), first_row_key("=", 2, "le")]),
        rule("ground", "DP", [hall(0), hall(1)], [parity_key()]),
        rule("structures", "W", wall,
             [neighbour_key(0, -1, "W"), pattern_key(7, 5, 9)]),
        rule("structures", ":", [litter]),
        rule("structures", "D", ends(station.paint_stairs, "D"),
             [neighbour_key(-1, 0, "D"), neighbour_key(1, 0, "D")]),
    ]
    for right in (False, True):
        edge = atlas.bucket(lambda r=right: tile_of(
            lambda d: paint_side_edge(d, 0, 0, r)), 1)
        rules.append(rule("foreground", "-,M=TnD:P",
                          [[], edge], [neighbour_key(1 if right else -1,
                                                     0, "x")]))
    rules.append(rule("foreground", "T", ends(station.paint_bench, "T"),
                      [neighbour_key(-1, 0, "T"), neighbour_key(1, 0, "T")]))
    rules.append(rule("foreground", "n",
                      [atlas.bucket(lambda b=beam: tile_of(
                          lambda d: station.paint_post(d, Neighbourhood(
                              "n", lambda x, y, b=b: "n"
                              if (x == 1 and b) else "."), 0, 0)), 1)
                       for beam in (False, True)],
                      [neighbour_key(1, 0, "n")]))

    def railcar(open_door: bool) -> Image.Image:
        width, height = (n * TILE for n in RAILCAR_TILES)
        sprite = Image.new("RGBA", (width, height), TRANSPARENT)
        station.paint_railcar(
            ImageDraw.Draw(sprite), random.Random(SEED + 1),
            (0, 0, width, height), wrecked=False,
            door_x=RAILCAR_DOOR_TILE * TILE, open_door=open_door,
        )
        return sprite

    return {
        "void": "#060608",
        "voidGlyph": "x",
        "rules": rules,
        "objects": [
            {"glyph": "M", "image": "station_railcar.png",
             "tiles": list(RAILCAR_TILES), "sprite": railcar(False),
             "whenOpen": "station_railcar_open.png",
             "openSprite": railcar(True)},
        ],
    }



# ------------------------------------------------------ the barracks' art
# Moved here from tools/build_barracks.py, which this atlas replaces: the
# carabinieri's post, a Pokemon-Emerald room wrecked from end to end. The
# desks, counters and cabinets stand taller than their cell, so their
# tiles lean out over the row above (`leaning`).

BK_VOID = (6, 6, 8)
BK_WALL_TOP = (46, 48, 56)
BK_WALL_TOP_LIGHT = (70, 72, 82)
BK_WALL_FACE = (150, 162, 150)
BK_WALL_FACE_DARK = (118, 130, 120)
BK_WAINSCOT = (84, 70, 58)
BK_FLOOR_A = (170, 168, 156)
BK_FLOOR_B = (156, 154, 144)
BK_FLOOR_JOINT = (134, 132, 124)
BK_WOOD = (132, 92, 58)
BK_WOOD_LIGHT = (164, 120, 78)
BK_WOOD_DARK = (92, 62, 40)
BK_METAL = (120, 124, 132)
BK_METAL_LIGHT = (160, 164, 172)
BK_METAL_DARK = (78, 82, 90)
BK_NAVY = (34, 44, 84)
BK_PAPER = (226, 222, 206)
BK_WALLS = "xWQNSIw"


def paint_barracks_floor(d, rng, px, py):
    for i in (0, 8):
        for j in (0, 8):
            rect(d, px + i, py + j, 8, 8,
                 BK_FLOOR_A if (i + j) // 8 % 2 == 0 else BK_FLOOR_B)
    rect(d, px, py, TILE, 1, BK_FLOOR_JOINT)
    rect(d, px, py, 1, TILE, BK_FLOOR_JOINT)
    for _ in range(4):  # grime
        rect(d, px + rng.randrange(16), py + rng.randrange(16), 1, 1,
             (120, 118, 110))
    if rng.random() < 0.15:  # cracked tile
        cx, cy = px + rng.randrange(2, 12), py + rng.randrange(2, 12)
        for i in range(5):
            rect(d, cx + i, cy + (i % 3) - 1, 1, 1, (100, 98, 92))


def paint_barracks_wall(d, rng, px, py, upper):
    """Two-tile tall wall seen face on: dark top, pale face, wood
    skirting. `upper` is the top row of it."""
    if upper:  # ceiling edge and upper face
        rect(d, px, py, TILE, 5, BK_WALL_TOP)
        rect(d, px, py + 5, TILE, 11, BK_WALL_FACE)
        rect(d, px, py + 5, TILE, 1, BK_WALL_TOP_LIGHT)
    else:
        rect(d, px, py, TILE, TILE, BK_WALL_FACE)
        rect(d, px, py + 10, TILE, 6, BK_WAINSCOT)
        rect(d, px, py + 10, TILE, 1, BK_WOOD_LIGHT)
        rect(d, px, py + 15, TILE, 1, BK_WOOD_DARK)
    if rng.random() < 0.3:  # bullet holes and cracks
        hx, hy = px + rng.randrange(2, 14), py + rng.randrange(6, 10)
        rect(d, hx, hy, 1, 1, (40, 40, 40))
        rect(d, hx + 1, hy + 1, 1, 1, (100, 108, 100))


def paint_barracks_partition(d, px, py, wall_below):
    """Interior wall: dark top, and a short face where the floor is below."""
    if wall_below:
        rect(d, px, py, TILE, TILE, BK_WALL_TOP)
        rect(d, px + 1, py, TILE - 2, TILE, BK_WALL_TOP_LIGHT)
        rect(d, px + 3, py, TILE - 6, TILE, BK_WALL_TOP)
        return
    rect(d, px, py, TILE, 6, BK_WALL_TOP)
    rect(d, px, py, TILE, 1, BK_WALL_TOP_LIGHT)
    rect(d, px, py + 6, TILE, 10, BK_WALL_FACE_DARK)
    rect(d, px, py + 12, TILE, 4, BK_WAINSCOT)


def paint_barracks_front_wall(d, px, py):
    rect(d, px, py, TILE, 7, BK_WALL_TOP)
    rect(d, px, py, TILE, 1, BK_WALL_TOP_LIGHT)
    rect(d, px, py + 7, TILE, 9, BK_VOID)


def paint_barracks_edge(d, px, py, right):
    """Thin wall edge where the floor meets the darkness at the side."""
    rect(d, px + (12 if right else 0), py, 4, TILE, BK_WALL_TOP)
    rect(d, px + (12 if right else 3), py, 1, TILE, BK_WALL_TOP_LIGHT)


def paint_barracks_emblem(d, px, py):
    rect(d, px + 1, py + 1, 14, 9, BK_NAVY)
    paint_emblem(d, px + 3, py - 3)


def paint_notice_board(d, rng, px, py):
    rect(d, px + 1, py + 1, 14, 8, BK_WOOD_DARK)
    rect(d, px + 2, py + 2, 12, 6, (170, 130, 80))
    for _ in range(4):
        rect(d, px + rng.randrange(3, 11), py + rng.randrange(2, 6), 3, 2,
             BK_PAPER)
    rect(d, px + 5, py + 8, 3, 2, BK_PAPER)  # a sheet hanging loose


def paint_barracks_shelves(d, rng, px, py):
    rect(d, px + 1, py - 6, 14, 16, BK_WOOD_DARK)
    for sy in (py - 5, py + 1):
        rect(d, px + 2, sy + 5, 12, 1, BK_WOOD_LIGHT)
        for bx in range(px + 2, px + 14, 2):
            if rng.random() < 0.7:
                colour = rng.choice(((40, 70, 120), (150, 40, 40),
                                     (60, 110, 60), (200, 180, 90)))
                rect(d, bx, sy + 1, 2, 4, colour)


def paint_barracks_exit_door(d, px, py):
    """Door in the back wall, ajar, grey daylight behind, green EXIT sign.
    It reaches 19 px above its cell: an object."""
    rect(d, px, py - 14, TILE, 30, BK_WALL_TOP)
    rect(d, px + 2, py - 12, 12, 28, (70, 90, 110))
    rect(d, px + 4, py - 8, 8, 24, (150, 170, 186))
    rect(d, px + 5, py - 4, 6, 20, (190, 204, 214))
    rect(d, px + 2, py - 12, 3, 28, BK_WOOD)  # open leaf
    rect(d, px + 3, py + 2, 1, 2, (220, 190, 90))
    rect(d, px + 3, py - 19, 10, 5, (30, 120, 60))  # exit sign
    rect(d, px + 5, py - 18, 6, 3, (200, 250, 210))
    rect(d, px + 6, py - 17, 3, 1, (30, 120, 60))


def paint_barracks_entrance(d, px, py):
    """Front doorway: gap in the front wall with daylight and a mat."""
    rect(d, px, py, TILE, TILE, (238, 196, 110))
    rect(d, px + 2, py + 4, 12, 12, (252, 222, 150))
    rect(d, px, py, 2, 8, BK_WOOD)
    rect(d, px + 14, py, 2, 8, BK_WOOD)
    rect(d, px + 2, py - 4, 12, 3, (130, 40, 36))  # mat inside


def paint_barracks_desk(d, rng, px, py):
    """An office desk over two tiles: top, front panel, a broken monitor
    on the left half, papers and a spilt coffee on the right. Painted
    whole and cut in two, so the monitor never straddles the cut."""
    rect(d, px + 1, py + 15, 30, 1, (90, 88, 82))  # shadow
    rect(d, px, py + 2, 32, 9, BK_WOOD_LIGHT)
    rect(d, px, py + 2, 32, 1, (190, 150, 100))
    rect(d, px, py + 11, 32, 4, BK_WOOD_DARK)
    rect(d, px + 2, py + 11, 1, 4, OUTLINE)
    rect(d, px + 29, py + 11, 1, 4, OUTLINE)
    mx = px + 2 + rng.randrange(4)
    rect(d, mx, py - 3, 10, 7, (40, 42, 48))  # monitor
    rect(d, mx + 1, py - 2, 8, 5, (70, 90, 110))
    rect(d, mx + 3, py - 1, 1, 3, (220, 230, 240))  # cracked screen
    rect(d, mx + 4, py, 2, 1, (220, 230, 240))
    for _ in range(3):
        rect(d, px + 16 + rng.randrange(12), py + 3 + rng.randrange(5), 4, 3,
             BK_PAPER)
    if rng.random() < 0.5:  # coffee spill
        rect(d, px + 20, py + 6, 5, 2, (90, 60, 40))


def paint_barracks_counter(d, px, py, first, last):
    """Reception counter segment."""
    rect(d, px, py + 3, TILE, 8, BK_WOOD_LIGHT)
    rect(d, px, py + 3, TILE, 1, (190, 150, 100))
    rect(d, px, py + 11, TILE, 5, BK_NAVY)
    rect(d, px, py + 12, TILE, 1, (200, 40, 40))
    rect(d, px, py - 6, TILE, 9, (150, 190, 200))  # glass screen
    rect(d, px + 5, py - 6, 3, 9, (60, 70, 80))  # shattered
    rect(d, px + 4, py - 2, 5, 1, (200, 230, 240))
    if first:
        rect(d, px, py - 6, 1, 22, OUTLINE)
    if last:
        rect(d, px + 15, py - 6, 1, 22, OUTLINE)


def paint_barracks_cabinet(d, px, py):
    rect(d, px + 2, py - 6, 12, 22, BK_METAL_DARK)
    rect(d, px + 3, py - 5, 10, 20, BK_METAL)
    for dy in (-3, 3, 9):
        rect(d, px + 4, py + dy, 8, 4, BK_METAL_LIGHT)
        rect(d, px + 7, py + dy + 1, 2, 1, BK_METAL_DARK)
    rect(d, px + 3, py + 9, 11, 5, BK_METAL_LIGHT)  # drawer pulled out
    rect(d, px + 4, py + 9, 8, 2, BK_PAPER)


def paint_barracks_chair(d, px, py):
    """Office chair lying on its side."""
    rect(d, px + 2, py + 10, 12, 3, (40, 40, 44))
    rect(d, px + 3, py + 6, 5, 4, (60, 70, 110))
    rect(d, px + 8, py + 8, 6, 3, (60, 70, 110))
    rect(d, px + 12, py + 13, 2, 2, (30, 30, 30))
    rect(d, px + 3, py + 13, 2, 2, (30, 30, 30))


def paint_barracks_papers(d, rng, px, py):
    for _ in range(6):
        rect(d, px + rng.randrange(1, 12), py + rng.randrange(2, 13), 4, 3,
             BK_PAPER)
        rect(d, px + rng.randrange(1, 13), py + rng.randrange(2, 14), 3, 1,
             (180, 176, 164))


def paint_barracks_blood(d, rng, px, py):
    rect(d, px + 3, py + 5, 10, 6, BLOOD)
    rect(d, px + 5, py + 4, 5, 8, BLOOD)
    rect(d, px + 6, py + 7, 4, 3, BLOOD_DARK)
    rect(d, px + 12, py + 11, 2, 2, BLOOD)


def barracks(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.barracks."""
    floored = ".:b*+c3TCAhOE"

    def lean(paint, keys=None):
        return leaning(atlas, paint, keys)

    def one(paint):
        return [atlas.bucket(lambda: tile_of(lambda d: paint(d, 0, 0)), 1)]

    def randomly(paint):
        return [atlas.bucket(lambda: tile_of(
            lambda d: paint(d, rng, 0, 0)))]

    rules = [rule("ground", floored, randomly(paint_barracks_floor))]
    for right in (False, True):
        rules.append(rule(
            "ground", floored,
            [[], atlas.bucket(lambda r=right: tile_of(
                lambda d: paint_barracks_edge(d, 0, 0, r)), 1)],
            [neighbour_key(1 if right else -1, 0, "x")]))

    # The back wall is two courses: the top one has wall below it.
    rules.append(rule(
        "structures", "WQNS",
        [atlas.bucket(lambda u=upper: tile_of(
            lambda d: paint_barracks_wall(d, rng, 0, 0, u)))
         for upper in (False, True)],
        [neighbour_key(0, 1, "xWQNSw")]))
    rules.append(rule(
        "structures", "I",
        [atlas.bucket(lambda b=below: tile_of(
            lambda d: paint_barracks_partition(d, 0, 0, b)), 1)
         for below in (False, True)],
        [neighbour_key(0, 1, BK_WALLS)]))
    rules.append(rule("structures", "w", one(paint_barracks_front_wall)))

    buckets, up = lean(lambda i: paint_barracks_emblem)
    rules.append(rule("structures", "Q", buckets, up=up))
    rules.append(rule("structures", "N", randomly(paint_notice_board)))
    buckets, up = lean(lambda i: lambda d, px, py:
                       paint_barracks_shelves(d, rng, px, py))
    rules.append(rule("structures", "S", buckets, up=up))
    buckets, up = lean(lambda i: paint_barracks_entrance)
    rules.append(rule("structures", "E", buckets, up=up))
    rules.append(rule("structures", ":", randomly(paint_barracks_papers)))
    rules.append(rule("structures", "b", randomly(paint_barracks_blood)))

    # Furniture. A desk is two tiles, painted whole and cut: the key says
    # whether there is a desk to the left, which makes this its right half.
    desk_keys = [neighbour_key(-1, 0, "T")]
    buckets, up = lean(lambda i: lambda d, px, py: paint_barracks_desk(
        d, rng, px - TILE * i, py), desk_keys)
    rules.append(rule("structures", "T", buckets, desk_keys, up))
    counter_keys = [neighbour_key(-1, 0, "C"), neighbour_key(1, 0, "C")]
    buckets, up = lean(lambda i: lambda d, px, py: paint_barracks_counter(
        d, px, py, not i & 1, not i & 2), counter_keys)
    rules.append(rule("structures", "C", buckets, counter_keys, up))
    buckets, up = lean(lambda i: paint_barracks_cabinet)
    rules.append(rule("structures", "A", buckets, up=up))
    rules.append(rule("structures", "h", one(paint_barracks_chair)))

    door = Image.new("RGBA", (TILE, TILE * 3), TRANSPARENT)
    paint_barracks_exit_door(ImageDraw.Draw(door), 0, TILE * 2)
    return {
        "void": "#060608",
        "voidGlyph": "x",
        "rules": rules,
        "objects": [{"glyph": "O", "image": "barracks_exit.png",
                     "offsetY": -2, "sprite": door}],
    }



# --------------------------------------------------------- the train's art
# Moved here from tools/build_train.py, which this atlas replaces: two
# passenger coaches and the locomotive Mario and Luigi live in, seen from
# above. Two pieces are objects: the table with the map of Europe spread on
# it, and the nose of the locomotive, whose shape is worked out from the
# rows (the one place where this script reads them, because the picture is
# only right for one arrangement of them; the test that holds the rows to
# the manifest is what makes that safe).

TR_VOID = (6, 6, 8)
TR_FLOOR_A = (92, 88, 82)
TR_FLOOR_B = (82, 78, 74)
TR_FLOOR_LINE = (60, 58, 58)
TR_SHELL = (198, 194, 182)
TR_SHELL_DARK = (116, 118, 122)
TR_SHELL_LIGHT = (226, 220, 204)
TR_METAL = (112, 116, 124)
TR_METAL_DARK = (48, 52, 60)
TR_METAL_LIGHT = (174, 178, 184)
TR_GLASS = (34, 50, 66)
TR_GLASS_LIGHT = (76, 106, 126)
TR_SEAT = (62, 88, 124)
TR_SEAT_DARK = (38, 54, 78)
TR_WOOD = (128, 90, 54)
TR_WOOD_LIGHT = (166, 124, 76)
TR_LUGGAGE = (94, 64, 42)
TR_CONTROL = (50, 58, 62)
TR_CONTROL_LIGHT = (100, 116, 112)
TR_MAP = (196, 166, 72)
TR_MAP_DARK = (112, 86, 34)
TR_LAMP = (242, 232, 190)
TR_SAFETY = (214, 178, 48)
TR_COT_FRAME = (70, 76, 60)
TR_COT_CANVAS = (112, 118, 86)
# Mario's army blanket, folded square; Luigi's checked one, kicked about.
TR_MARIO_BLANKET = (78, 92, 70)
TR_LUIGI_BLANKET = (150, 52, 44)
TR_LUIGI_CHECK = (206, 186, 160)
TR_PILLOW = (214, 208, 190)
TR_BAG = (28, 30, 32)
TR_BAG_LIGHT = (70, 74, 78)
TR_GLASS_GREEN = (58, 118, 70)
TR_GLASS_BROWN = (122, 76, 30)
TR_CAN_RED = (178, 40, 38)
TR_CAN_SILVER = (184, 186, 190)
TR_PAPER = (226, 220, 200)
TR_PAPER_SHADE = (178, 170, 150)
TR_INK = (62, 58, 60)
TR_CRATE = (118, 84, 48)
TR_CRATE_DARK = (78, 54, 30)
TR_BOOK_COVERS = ((122, 38, 34), (40, 64, 104), (58, 86, 52))
TR_WINDSCREEN_FRAME = (36, 40, 46)
TR_ROWS = "train-interior-rows"
TR_MAP_TABLE_TILES = (4, 2)
# What a camp bed's pillow lies against.
TR_COT_WALLS = "xWwIiV"


def paint_train_floor(d, rng, x, y):
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, TR_FLOOR_A if (x + y) % 2 else TR_FLOOR_B)
    rect(d, px, py, TILE, 1, TR_FLOOR_LINE)
    rect(d, px, py, 1, TILE, TR_FLOOR_LINE)
    for _ in range(2):
        rect(d, px + rng.randrange(15), py + rng.randrange(15), 1, 1,
             shade(TR_FLOOR_A, rng.randrange(-22, 14)))


def paint_train_shell(d, glyph, x, y):
    """The hull: the roof edge on the north side with a window every four
    tiles, the belly on the south side, the pillars between the coaches."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, TR_METAL_DARK)
    if glyph == "W":
        rect(d, px, py + 3, TILE, 12, TR_SHELL)
        rect(d, px, py + 3, TILE, 2, TR_SHELL_LIGHT)
        if x % 4 in (1, 2):
            rect(d, px + 2, py + 6, 12, 7, TR_METAL_DARK)
            rect(d, px + 3, py + 7, 10, 5, TR_GLASS)
            rect(d, px + 4, py + 7, 5, 1, TR_GLASS_LIGHT)
    elif glyph == "w":
        rect(d, px, py, TILE, 12, TR_SHELL)
        rect(d, px, py, TILE, 2, TR_SHELL_LIGHT)
        rect(d, px, py + 11, TILE, 4, TR_SHELL_DARK)
    else:
        rect(d, px + 3, py, 10, TILE, TR_SHELL_DARK)
        rect(d, px + 5, py, 6, TILE, TR_METAL)
        rect(d, px + 6, py, 2, TILE, TR_METAL_LIGHT)


def paint_train_exit(d, px, py):
    rect(d, px, py, TILE, TILE, (24, 28, 32))
    rect(d, px, py, TILE, 2, TR_LAMP)
    rect(d, px, py + 12, TILE, 4, TR_METAL_DARK)
    rect(d, px + 2, py + 13, 12, 1, TR_METAL_LIGHT)
    for rail_x in (px + 1, px + 13):
        rect(d, rail_x, py + 2, 2, 11, TR_SAFETY)


def paint_train_seat(d, px, py, left_end, right_end):
    rect(d, px + 2, py + 2, 12, 12, TR_SEAT_DARK)
    rect(d, px + 3, py + 3, 10, 6, TR_SEAT)
    rect(d, px + 3, py + 10, 10, 3, shade(TR_SEAT, -18))
    rect(d, px + 3, py + 3, 10, 1, shade(TR_SEAT, 34))
    if left_end:
        rect(d, px + 1, py + 4, 2, 9, TR_METAL_LIGHT)
    if right_end:
        rect(d, px + 13, py + 4, 2, 9, TR_METAL_LIGHT)


def paint_train_table(d, px, py):
    rect(d, px + 1, py + 5, 14, 7, shade(TR_WOOD, -24))
    rect(d, px + 1, py + 3, 14, 7, TR_WOOD)
    rect(d, px + 2, py + 4, 12, 1, TR_WOOD_LIGHT)
    rect(d, px + 4, py + 10, 2, 5, TR_METAL_DARK)
    rect(d, px + 11, py + 10, 2, 5, TR_METAL_DARK)


def paint_train_luggage(d, rng, px, py):
    rect(d, px + 2, py + 4, 12, 10, TR_LUGGAGE)
    rect(d, px + 3, py + 5, 10, 2, shade(TR_LUGGAGE, 28))
    rect(d, px + 6, py + 1, 5, 4, TR_METAL_DARK)
    rect(d, px + 7, py + 2, 3, 3, TR_FLOOR_B)
    rect(d, px + rng.randrange(3, 11), py + 7, 2, 5,
         shade(TR_LUGGAGE, -28))


def paint_train_control(d, rng, px, py):
    rect(d, px + 1, py + 2, 14, 12, TR_CONTROL)
    rect(d, px + 2, py + 3, 12, 4, TR_CONTROL_LIGHT)
    for _ in range(4):
        colour = rng.choice(((178, 52, 42), (68, 146, 82), (214, 176, 54)))
        rect(d, px + rng.randrange(3, 13), py + rng.randrange(8, 12), 2, 2,
             colour)


def paint_train_map_table(d, room):
    """The table in the middle of the locomotive, the whole block of `P`
    tiles, with the yellowed map of Europe spread over it: a coastline, a
    few borders, and the route drawn on it in red."""
    tiles = [(x, y) for y in range(room.height) for x in range(room.width)
             if room.at(x, y) == "P"]
    left = min(x for x, _ in tiles) * TILE
    top = min(y for _, y in tiles) * TILE
    right = (max(x for x, _ in tiles) + 1) * TILE
    bottom = (max(y for _, y in tiles) + 1) * TILE
    width, height = right - left, bottom - top
    # The table: a dark edge, the top, and its legs at the corners.
    rect(d, left + 1, top + 3, width - 2, height - 3, shade(TR_WOOD, -34))
    rect(d, left + 1, top + 1, width - 2, height - 4, TR_WOOD)
    rect(d, left + 2, top + 2, width - 4, 1, TR_WOOD_LIGHT)
    for leg_x in (left + 2, right - 5):
        rect(d, leg_x, bottom - 3, 3, 3, TR_METAL_DARK)
    # The map, a little askew of the table's edges, its corners curling.
    mx, my, mw, mh = left + 5, top + 4, width - 10, height - 11
    rect(d, mx + 1, my + 1, mw, mh, shade(TR_MAP, -60))
    rect(d, mx, my, mw, mh, TR_MAP)
    sea = shade(TR_MAP, -26)
    rect(d, mx + 2, my + 2, 10, mh - 4, sea)
    rect(d, mx + 12, my + mh - 8, 18, 6, sea)
    rect(d, mx + mw - 12, my + 2, 10, 7, sea)
    for bx, by, bw, bh in ((mx + 6, my + 4, 4, 5), (mx + 18, my + 6, 9, 1),
                           (mx + 30, my + 3, 1, 9), (mx + 24, my + 12, 12, 1),
                           (mx + 40, my + 9, 1, 8)):
        rect(d, bx, by, bw, bh, TR_MAP_DARK)
    for cx, cy in ((mx, my), (mx + mw - 3, my + mh - 3)):
        rect(d, cx, cy, 3, 3, shade(TR_MAP, 36))
    # The route: from the heel of Italy north, a red line and its stops.
    route = ((mx + 30, my + mh - 5), (mx + 26, my + 14), (mx + 34, my + 9),
             (mx + 36, my + 3))
    d.line(route, fill=(172, 34, 30), width=1)
    for sx, sy in (route[0], route[-1]):
        rect(d, sx - 1, sy - 1, 3, 3, (172, 34, 30))


def paint_train_driver_seat(d, px, py):
    """One of the two drivers' chairs, its back to the room, facing the
    controls."""
    rect(d, px + 5, py + 12, 6, 3, TR_METAL_DARK)
    rect(d, px + 3, py + 3, 11, 10, TR_SEAT_DARK)
    rect(d, px + 5, py + 4, 8, 8, TR_SEAT)
    rect(d, px + 2, py + 2, 4, 12, TR_SEAT_DARK)
    rect(d, px + 3, py + 3, 2, 10, shade(TR_SEAT, 30))


def paint_train_cot(d, room, x, y, glyph):
    """One tile of a camp bed three tiles long: canvas stretched on a metal
    frame, a pillow at the end by the wall, a blanket over the rest."""
    px, py = x * TILE, y * TILE
    left = room.at(x - 1, y) != glyph
    right = room.at(x + 1, y) != glyph
    # The pillow goes at the end that is up against a wall.
    start = x
    while room.at(start - 1, y) == glyph:
        start -= 1
    pillow_left = room.at(start - 1, y) in TR_COT_WALLS
    rect(d, px, py + 2, TILE, 12, TR_COT_FRAME)
    rect(d, px + (2 if left else 0), py + 3,
         TILE - (2 if left else 0) - (2 if right else 0), 10, TR_COT_CANVAS)
    for leg_x in ((px + 1,) if left else ()) + ((px + 13,) if right else ()):
        rect(d, leg_x, py + 13, 2, 2, TR_METAL_DARK)
    if (left and pillow_left) or (right and not pillow_left):
        rect(d, px + (3 if left else 5), py + 4, 8, 8, TR_PILLOW)
        rect(d, px + (3 if left else 5), py + 10, 8, 2, shade(TR_PILLOW, -30))
        return
    if glyph == "B":
        # Tucked in tight, the edge turned down neatly.
        end = 3 if (right and pillow_left) or (left and not pillow_left) else 0
        start_x = px + (end if left else 0)
        rect(d, start_x, py + 4, TILE - end, 8, TR_MARIO_BLANKET)
        rect(d, start_x, py + 4, TILE - end, 1, shade(TR_MARIO_BLANKET, 30))
        if room.at(x - 1, y) == glyph and room.at(x + 1, y) == glyph:
            # The turned-down edge, next to the pillow.
            edge = px + (1 if pillow_left else 12)
            rect(d, edge, py + 4, 3, 8, shade(TR_MARIO_BLANKET, 22))
    else:
        # Half off the bed, in a heap.
        rect(d, px, py + 3, TILE, 11, TR_LUIGI_BLANKET)
        for cx in range(px, px + TILE, 4):
            rect(d, cx, py + 3, 2, 11, shade(TR_LUIGI_BLANKET, -24))
        for cy in range(py + 5, py + 14, 4):
            rect(d, px, cy, TILE, 1, TR_LUIGI_CHECK)
        if right:
            rect(d, px + 10, py + 13, 6, 3, TR_LUIGI_BLANKET)


def paint_train_bag(d, px, py):
    """A black bin bag knotted at the top."""
    rect(d, px + 3, py + 5, 10, 10, TR_BAG)
    rect(d, px + 2, py + 8, 12, 6, TR_BAG)
    rect(d, px + 6, py + 2, 4, 4, TR_BAG)
    rect(d, px + 7, py + 1, 2, 2, TR_BAG_LIGHT)
    rect(d, px + 4, py + 7, 2, 4, TR_BAG_LIGHT)
    rect(d, px + 3, py + 15, 10, 1, shade(TR_FLOOR_A, -30))


def paint_train_litter(d, rng, px, py):
    """An empty bottle and a crushed can left on the floor."""
    bottle = rng.choice((TR_GLASS_GREEN, TR_GLASS_BROWN))
    bx, by = px + rng.randrange(1, 5), py + rng.randrange(2, 6)
    rect(d, bx, by + 2, 8, 3, bottle)
    rect(d, bx + 8, by + 3, 3, 1, bottle)
    rect(d, bx + 1, by + 2, 6, 1, shade(bottle, 50))
    cx, cy = px + rng.randrange(7, 12), py + rng.randrange(9, 12)
    rect(d, cx, cy, 4, 3, TR_CAN_RED)
    rect(d, cx, cy, 1, 3, TR_CAN_SILVER)
    rect(d, cx + 1, cy + 1, 2, 1, shade(TR_CAN_RED, 40))


def paint_train_papers(d, rng, px, py):
    """Loose sheets with a few lines written on them."""
    for _ in range(2):
        sx, sy = px + rng.randrange(0, 7), py + rng.randrange(0, 7)
        rect(d, sx + 1, sy + 1, 8, 9, TR_PAPER_SHADE)
        rect(d, sx, sy, 8, 9, TR_PAPER)
        for line in range(sy + 2, sy + 8, 2):
            rect(d, sx + 1, line, rng.randrange(3, 7), 1, TR_INK)


def paint_train_books(d, px, py, first):
    """A crate for a desk, with books open on it and a stack beside."""
    rect(d, px, py + 3, TILE, 12, TR_CRATE_DARK)
    rect(d, px, py + 3, TILE, 10, TR_CRATE)
    rect(d, px, py + 7, TILE, 1, TR_CRATE_DARK)
    if first:
        # An open book, its pages spread.
        rect(d, px + 2, py + 1, 12, 8, TR_BOOK_COVERS[0])
        rect(d, px + 3, py + 2, 5, 6, TR_PAPER)
        rect(d, px + 8, py + 2, 5, 6, shade(TR_PAPER, -12))
        for line in range(py + 3, py + 8, 2):
            rect(d, px + 4, line, 3, 1, TR_INK)
            rect(d, px + 9, line, 3, 1, TR_INK)
        return
    # Another open face down, and a stack.
    rect(d, px + 1, py + 2, 7, 6, TR_BOOK_COVERS[1])
    rect(d, px + 4, py + 2, 1, 6, shade(TR_BOOK_COVERS[1], -30))
    for i, colour in enumerate(TR_BOOK_COVERS):
        rect(d, px + 9, py + 7 - 2 * i, 6, 2, colour)
        rect(d, px + 9, py + 7 - 2 * i, 6, 1, shade(colour, 30))
    rect(d, px + 2, py + 10, 6, 3, TR_PAPER)


def paint_train_lamp(d, px, py):
    rect(d, px + 3, py + 5, 10, 5, TR_METAL_DARK)
    rect(d, px + 4, py + 6, 8, 3, TR_LAMP)
    rect(d, px + 6, py + 10, 4, 1, shade(TR_LAMP, -52))


def train_nose_edge(room):
    """The outer edge of the locomotive's nose, in pixels, for every pixel
    row: through the outer side of each windscreen tile `V`, smoothed, and
    closed at the top and bottom where the shell's straight walls end."""
    anchors = []
    for y in range(room.height):
        vs = [x for x in range(room.width) if room.at(x, y) == "V"]
        if vs:
            anchors.append((y * TILE + TILE / 2, (vs[0] + 1) * TILE))
        else:
            walls = [x for x in range(room.width) if room.at(x, y) in "Ww"]
            anchors.append((y * TILE + TILE / 2, (walls[-1] + 1) * TILE))
    edge = []
    for py in range(room.height * TILE):
        # Interpolate between the anchors around this row, then average a
        # little either side so the steps of the tiles melt into a curve.
        def at(yy):
            yy = min(max(yy, anchors[0][0]), anchors[-1][0])
            for (y0, x0), (y1, x1) in zip(anchors, anchors[1:]):
                if y0 <= yy <= y1:
                    return x0 + (x1 - x0) * (yy - y0) / (y1 - y0)
            return anchors[-1][1]
        samples = [at(py + k) for k in range(-10, 11)]
        edge.append(sum(samples) / len(samples))
    return edge


def train_nose(room):
    """Clears everything past the nose's edge and draws the shell round it,
    with the windscreen just inside: glass along the front, a frame line,
    and the pillars at the two corners. Returns the picture and the tile
    it starts from: from the column before the first windscreen tile to
    the end of the row, over every row of the place."""
    edge = train_nose_edge(room)
    first = min(x for y in range(room.height) for x in range(room.width)
                if room.at(x, y) == "V") - 1
    left = first * TILE
    sprite = Image.new("RGBA", ((room.width - first) * TILE,
                                room.height * TILE), TRANSPARENT)
    pixels = sprite.load()
    glass_top = min(y for y in range(room.height)
                    if "V" in room.rows[y]) * TILE
    glass_bottom = (max(y for y in range(room.height)
                        if "V" in room.rows[y]) + 1) * TILE
    void = TR_VOID + (255,)
    for py in range(room.height * TILE):
        x_edge = int(round(edge[py]))
        if x_edge < left:
            continue
        for px in range(left, room.width * TILE):
            depth = x_edge - px
            if depth <= 0:
                colour = void
            elif depth <= 2:
                colour = TR_SHELL_DARK
            elif depth <= 4:
                colour = TR_SHELL
            elif depth <= 10 and glass_top + 4 <= py < glass_bottom - 4:
                light = 7 <= depth <= 8 and (py // 6) % 3 == 0
                colour = TR_GLASS_LIGHT if light else TR_GLASS
            elif depth == 11 and glass_top + 4 <= py < glass_bottom - 4:
                colour = TR_WINDSCREEN_FRAME
            else:
                continue
            pixels[px - left, py] = colour + (255,) if len(colour) == 3 \
                else colour
    # The pillars where the windscreen meets the roof and the floor.
    d = ImageDraw.Draw(sprite)
    for py in (glass_top + 3, glass_bottom - 6):
        x_edge = int(round(edge[py]))
        rect(d, x_edge - 12 - left, py, 9, 3, TR_SHELL_DARK)
    return sprite, first


def train_interior(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.trainInterior."""
    from build_street_level import read_rows  # noqa: PLC0415 - the nose

    rows = read_rows(TR_ROWS)
    floored = ".SLTCh*bBuofkEPlV"
    floor = [
        atlas.bucket(lambda p=parity: cell(
            lambda d, gx, gy: paint_train_floor(d, rng, gx, gy), p, 0))
        for parity in (0, 1)
    ]

    def one(paint):
        return [atlas.bucket(lambda: tile_of(lambda d: paint(d, 0, 0)), 1)]

    def randomly(paint):
        return [atlas.bucket(lambda: tile_of(
            lambda d: paint(d, rng, 0, 0)))]

    def run_ends(paint, glyph):
        """Four tiles for a run of `glyph`: key bit 0 is a neighbour to the
        left, bit 1 one to the right; `paint(d, first, last)`."""
        return [atlas.bucket(lambda i=i: tile_of(
            lambda d: paint(d, not i & 1, not i & 2)), 1) for i in range(4)]

    rules = [rule("ground", floored, floor, [parity_key()])]

    # The hull. The north wall has a window on two tiles in every four.
    rules.append(rule(
        "structures", "W",
        [atlas.bucket(lambda i=i: cell(
            lambda d, gx, gy: paint_train_shell(d, "W", gx, gy),
            1 if i in (1, 2) else 0, 0), 1) for i in range(4)],
        [pattern_key(1, 0, 4, 1), pattern_key(1, 0, 4, 2)]))
    rules.append(rule("structures", "w", [atlas.bucket(lambda: tile_of(
        lambda d: paint_train_shell(d, "w", 0, 0)), 1)]))
    rules.append(rule("structures", "Ii", [atlas.bucket(lambda: tile_of(
        lambda d: paint_train_shell(d, "I", 0, 0)), 1)]))
    rules.append(rule("structures", "E", one(paint_train_exit)))
    rules.append(rule(
        "structures", "S",
        run_ends(lambda d, left, right: paint_train_seat(d, 0, 0, left,
                                                         right), "S"),
        [neighbour_key(-1, 0, "S"), neighbour_key(1, 0, "S")]))
    rules.append(rule("structures", "T", one(paint_train_table)))
    rules.append(rule("structures", "L", randomly(paint_train_luggage)))
    rules.append(rule("structures", "C", randomly(paint_train_control)))
    rules.append(rule("structures", "h", one(paint_train_driver_seat)))
    rules.append(rule("structures", "*", one(paint_train_lamp)))

    # A camp bed: a run of `b` or `B`, its pillow at the end that lies
    # against a wall. Bits, in key order: something of the same glyph to
    # the left, to the right, and a wall before the start of the run.
    for glyph in "bB":
        buckets = []
        for index in range(8):
            same_left, same_right, walled = (
                bool(index & 1), bool(index & 2), bool(index & 4))

            def around(x, y, l=same_left, r=same_right, w=walled, g=glyph):
                before = "W" if w else "."
                if x == -1:
                    return g if l else before
                if x == -2:
                    return before if l else "."
                if x == 1:
                    return g if r else "."
                return "."
            room = Neighbourhood(glyph, around)
            buckets.append(atlas.bucket(lambda rm=room, g=glyph: tile_of(
                lambda d: paint_train_cot(d, rm, 0, 0, g)), 1))
        rules.append(rule("structures", glyph, buckets,
                          [neighbour_key(-1, 0, glyph),
                           neighbour_key(1, 0, glyph),
                           before_run_key(TR_COT_WALLS)]))
    rules.append(rule("structures", "u", one(paint_train_bag)))
    rules.append(rule("structures", "o", randomly(paint_train_litter)))
    rules.append(rule("structures", "f", randomly(paint_train_papers)))
    rules.append(rule(
        "structures", "k",
        [atlas.bucket(lambda f=first: tile_of(
            lambda d: paint_train_books(d, 0, 0, f)), 1)
         for first in (True, False)],
        [neighbour_key(-1, 0, "k")]))

    table = Image.new("RGBA", tuple(n * TILE for n in TR_MAP_TABLE_TILES),
                      TRANSPARENT)
    paint_train_map_table(ImageDraw.Draw(table),
                          Block("P", *TR_MAP_TABLE_TILES))
    nose, first = train_nose(Room(rows))
    return {
        "void": "#060608",
        "voidGlyph": "x",
        "rules": rules,
        "objects": [
            {"glyph": "P", "image": "train_map_table.png",
             "tiles": list(TR_MAP_TABLE_TILES), "sprite": table},
            {"at": [first, 0], "image": "train_nose.png", "sprite": nose,
             "under": [row[first:] for row in rows]},
        ],
    }


# ------------------------------------------------------ the reference draw
# What the renderer in lib/game/render/tile_place_component.dart has to do,
# written out once here so the manifest can be checked against the baked
# PNGs while they still exist, and so --preview can show a converted place
# without a device.

def variant(tiles: list[int], x: int, y: int) -> int:
    """Which of a bucket's tiles falls on this cell: a hash of the place
    in the grid, so the grit is the same at every start and there is no
    seed to save. lib/game/render/tile_place_component.dart repeats it."""
    return tiles[((x * 73856093) ^ (y * 19349663)) % len(tiles)]


def compose(rows: list[str], place: dict, tiles: list[Image.Image],
            opened: bool = False) -> Image.Image:
    width, height = len(rows[0]), len(rows)

    def at(x: int, y: int) -> str:
        if 0 <= x < width and 0 <= y < height:
            return rows[y][x]
        return "x"

    def first_row(glyph: str) -> int:
        return next((y for y in range(height) if glyph in rows[y]), 0)

    def truth(key: dict, x: int, y: int) -> bool:
        kind = key["kind"]
        if kind == "parity":
            return (x + y) % 2 == 1
        if kind == "neighbour":
            return at(x + key["dx"], y + key["dy"]) in key["glyphs"]
        if kind == "pattern":
            return (x * key["a"] + y * key["b"]) % key["mod"] == key["equals"]
        if kind == "beforeRun":
            here = at(x, y)
            start = x
            while at(start - 1, y) == here:
                start -= 1
            return at(start - 1, y) in key["glyphs"]
        if kind == "rowHas":
            return 0 <= y + key["dy"] < height and                 key["glyph"] in rows[y + key["dy"]]
        if kind == "firstRow":
            edge = first_row(key["glyph"]) + key["offset"]
            return y <= edge if key["compare"] == "le" else y == edge
        raise ValueError(kind)

    colour = place["void"].lstrip("#")
    void = tuple(int(colour[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
    out = Image.new("RGBA", (width * TILE, height * TILE), void)
    for layer in ("ground", "structures", "objects", "foreground"):
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
        for y in range(height):
            for x in range(width):
                glyph = at(x, y)
                for spec in place["rules"]:
                    if spec["layer"] != layer or glyph not in spec["glyphs"]:
                        continue
                    index = 0
                    for bit, key in enumerate(spec["keys"]):
                        if truth(key, x, y):
                            index |= 1 << bit
                    bucket = spec["buckets"][index]
                    if not bucket:
                        continue
                    out.alpha_composite(
                        tiles[variant(bucket, x, y)], (x * TILE, y * TILE))
                    up = spec.get("up")
                    if up and up[index] and y > 0:
                        out.alpha_composite(
                            tiles[variant(up[index], x, y)],
                            (x * TILE, (y - 1) * TILE))
    return out


# ----------------------------------------------------------------- writing

PLACES = {
    "barracks": barracks,
    "airlinerCabin": airliner_cabin,
    "barArcobaleno": bar_arcobaleno,
    "barBackroom": bar_backroom,
    "duomo": duomo,
    "duomoUpper": duomo_upper,
    "stationFarSide": station_far_side,
    "stationUnderpass": station_underpass,
    "trainInterior": train_interior,
}


def build() -> tuple[Atlas, dict]:
    atlas = Atlas()
    # Each place has a stream of its own: one shared by all would shift
    # every place after the one being added, and the diff of a conversion
    # would repaint the ones already done.
    places = {
        name: make(atlas, random.Random(f"{SEED}/{name}"))
        for name, make in sorted(PLACES.items())
    }
    manifest = {
        "format": "stepbound-tile-atlas-v1",
        "tileWidth": TILE,
        "tileHeight": TILE,
        "layers": ["ground", "structures", "foreground"],
        "palette": "assets/palette.gpl",
        "atlas": ATLAS.replace(os.sep, "/"),
        "columns": 16,
        "places": {
            name: {
                "void": place["void"],
                "voidGlyph": place["voidGlyph"],
                "rules": place["rules"],
                "objects": [
                    {k: v for k, v in obj.items()
                     if k not in ("sprite", "openSprite")}
                    for obj in place["objects"]
                ],
            }
            for name, place in places.items()
        },
    }
    return atlas, {"manifest": manifest, "places": places}


def save_object(sprite: Image.Image, path: str) -> None:
    """Write an object's picture unless the one there already holds the
    same pixels: the encoding of a PNG is not stable from one Pillow or
    zlib to the next, and a byte change is a diff nobody can review."""
    if os.path.exists(path):
        with Image.open(path) as old:
            if old.convert("RGBA").tobytes() == sprite.convert(
                    "RGBA").tobytes() and old.size == sprite.size:
                return
    sprite.save(path, optimize=True)


def write(root: str) -> None:
    atlas, built = build()
    os.makedirs(os.path.join(root, OBJECTS), exist_ok=True)
    atlas.image(built["manifest"]["columns"]).save(
        os.path.join(root, ATLAS), optimize=True)
    for place in built["places"].values():
        for obj in place["objects"]:
            save_object(obj["sprite"], os.path.join(root, OBJECTS,
                                                    obj["image"]))
            if "openSprite" in obj:
                save_object(obj["openSprite"],
                            os.path.join(root, OBJECTS, obj["whenOpen"]))
    with open(os.path.join(root, MANIFEST), "w", encoding="utf-8") as out:
        json.dump(built["manifest"], out, indent=2)
        out.write("\n")
    print(f"{ATLAS}: {len(atlas.tiles)} tile")
    for name in sorted(built["places"]):
        print(f"  {name}: {len(built['places'][name]['rules'])} regole, "
              f"{len(built['places'][name]['objects'])} oggetti")


# The marker of each converted place's ASCII rows, for --preview only: the
# atlas itself never reads a place.
PREVIEW_ROWS = {
    "barracks": "barracks-rows",
    "airlinerCabin": "airliner-cabin-rows",
    "barArcobaleno": "bar-rows",
    "barBackroom": "bar-backroom-rows",
    "duomo": "duomo-rows",
    "duomoUpper": "duomo-upper-rows",
    "stationFarSide": "far-platform-rows",
    "stationUnderpass": "underpass-rows",
    "trainInterior": "train-interior-rows",
}


def preview(root: str) -> None:
    from build_street_level import read_rows  # noqa: PLC0415 - preview only

    atlas, built = build()
    tiles = atlas.tiles
    for name, marker in sorted(PREVIEW_ROWS.items()):
        rows = read_rows(marker)
        place = built["places"][name]
        for opened in ([False, True] if any("openSprite" in o
                                            for o in place["objects"])
                       else [False]):
            image = compose(rows, place, tiles, opened=opened)
            out = os.path.join(
                root, f"preview_{name}{'_open' if opened else ''}.png")
            image.convert("RGB").save(out)
            print(f"{out}: {image.size[0]}x{image.size[1]}")


def compare(dump: str) -> None:
    """Hold the renderer in lib/game/render to this file's reference draw.
    `dump` holds what the game drew, one <place>.rgba per converted place,
    written by test/levels/tile_place_render_test.dart."""
    from build_street_level import read_rows  # noqa: PLC0415 - compare only

    atlas, built = build()
    failures = []
    for name, marker in sorted(PREVIEW_ROWS.items()):
        path = os.path.join(dump, f"{name}.rgba")
        if not os.path.exists(path):
            failures.append(f"{name}: the game drew nothing to {path}")
            continue
        rows = read_rows(marker)
        place = built["places"][name]
        expected = compose(rows, place, atlas.tiles).tobytes()
        with open(path, "rb") as f:
            drawn = f.read()
        if drawn != expected:
            wrong = sum(1 for a, b in zip(drawn[::4], expected[::4])
                        if a != b)
            failures.append(f"{name}: {wrong} pixels differ from the "
                            f"reference draw")
        else:
            print(f"{name}: drawn as the reference draws it")
    if failures:
        raise SystemExit("\n".join(failures))


def check() -> None:
    """The atlas is generated art: re-make it and see that nothing moved,
    the same gate tools/build_levels.py gives the baked backgrounds."""
    with tempfile.TemporaryDirectory() as tmp:
        write(tmp)
        for name in (ATLAS, MANIFEST):
            fresh = os.path.join(tmp, name)
            committed = os.path.join(ROOT, name)
            if not os.path.exists(committed):
                raise SystemExit(f"{name} is missing: run "
                                 f"python tools/build_tile_atlas.py")
            if name.endswith(".png"):
                with Image.open(committed) as a, Image.open(fresh) as b:
                    old, new = a.convert("RGBA"), b.convert("RGBA")
                    same = old.size == new.size and \
                        old.tobytes() == new.tobytes()
                    where = "" if same else (
                        f" (differisce in {ImageChops.difference(old, new).getbbox()})"
                        if old.size == new.size else
                        f" ({old.size} contro {new.size})")
            else:
                with open(committed, encoding="utf-8") as a, \
                        open(fresh, encoding="utf-8") as b:
                    same, where = a.read() == b.read(), ""
            if not same:
                raise SystemExit(
                    f"{name} is out of date{where}.\nRe-run it and commit "
                    f"the result:\n    python tools/build_tile_atlas.py")
            print(f"{name}: up to date")
        for entry in sorted(os.listdir(os.path.join(tmp, OBJECTS))):
            committed = os.path.join(ROOT, OBJECTS, entry)
            with Image.open(os.path.join(tmp, OBJECTS, entry)) as fresh:
                new = fresh.convert("RGBA")
            if not os.path.exists(committed):
                raise SystemExit(f"{OBJECTS}/{entry} is missing")
            with Image.open(committed) as a:
                if a.convert("RGBA").tobytes() != new.tobytes():
                    raise SystemExit(
                        f"{OBJECTS}/{entry} is out of date.\nRe-run it and "
                        f"commit the result:\n"
                        f"    python tools/build_tile_atlas.py")
            print(f"{OBJECTS}/{entry}: up to date")
    print("the tile atlas matches its painters")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true",
                        help="do not write anything: fail if the committed "
                             "atlas is not what the painters make today")
    parser.add_argument("--compare", metavar="DIR",
                        help="compare what the game drew into DIR "
                             "(TILE_RENDER_DUMP) with the reference draw")
    parser.add_argument("--preview", metavar="DIR",
                        help="draw the converted places into DIR, the way "
                             "the game will draw them")
    args = parser.parse_args()
    if args.check:
        check()
    elif args.compare:
        compare(args.compare)
    elif args.preview:
        os.makedirs(args.preview, exist_ok=True)
        preview(args.preview)
    else:
        write(ROOT)


if __name__ == "__main__":
    main()
