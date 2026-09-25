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
    OUTLINE,
    RAINBOW,
    TILE,
    paint_chair,
    paint_text,
    rect,
    shade,
    text_width,
)
from build_mall import paint_blood  # noqa: E402
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


def row_has_key(dy: int, glyph: str) -> dict:
    return {"kind": "rowHas", "dy": dy, "glyph": glyph}


def rule(layer: str, glyphs: str, buckets: list[list[int]],
         keys: list[dict] | None = None) -> dict:
    keys = keys or []
    assert len(buckets) == 2 ** len(keys), (layer, glyphs, len(buckets))
    return {"layer": layer, "glyphs": glyphs, "keys": keys,
            "buckets": buckets}


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
    return out


# ----------------------------------------------------------------- writing

PLACES = {
    "airlinerCabin": airliner_cabin,
    "barArcobaleno": bar_arcobaleno,
    "barBackroom": bar_backroom,
    "duomo": duomo,
    "duomoUpper": duomo_upper,
    "stationFarSide": station_far_side,
    "stationUnderpass": station_underpass,
}


def build() -> tuple[Atlas, dict]:
    atlas = Atlas()
    rng = random.Random(SEED)
    places = {name: make(atlas, rng) for name, make in sorted(PLACES.items())}
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


def write(root: str) -> None:
    atlas, built = build()
    os.makedirs(os.path.join(root, OBJECTS), exist_ok=True)
    atlas.image(built["manifest"]["columns"]).save(
        os.path.join(root, ATLAS), optimize=True)
    for place in built["places"].values():
        for obj in place["objects"]:
            obj["sprite"].save(
                os.path.join(root, OBJECTS, obj["image"]), optimize=True)
            if "openSprite" in obj:
                obj["openSprite"].save(
                    os.path.join(root, OBJECTS, obj["whenOpen"]),
                    optimize=True)
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
    "airlinerCabin": "airliner-cabin-rows",
    "barArcobaleno": "bar-rows",
    "barBackroom": "bar-backroom-rows",
    "duomo": "duomo-rows",
    "duomoUpper": "duomo-upper-rows",
    "stationFarSide": "far-platform-rows",
    "stationUnderpass": "underpass-rows",
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
    parser.add_argument("--preview", metavar="DIR",
                        help="draw the converted places into DIR, the way "
                             "the game will draw them")
    args = parser.parse_args()
    if args.check:
        check()
    elif args.preview:
        os.makedirs(args.preview, exist_ok=True)
        preview(args.preview)
    else:
        write(ROOT)


if __name__ == "__main__":
    main()
