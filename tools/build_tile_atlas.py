#!/usr/bin/env python3
"""Bake the tile atlas the game paints converted places from.

A place used to exist twice: as the ASCII rows the simulation reads and as
a PNG painted from those rows by a baker. A converted place has no PNG:
the renderer paints it at runtime from the same rows, one tile per glyph,
out of assets/levels/tiles/atlas.png.

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
import re
import sys
import tempfile

from PIL import Image, ImageChops, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_street_level import (  # noqa: E402
    ASPHALT,
    ASPHALT_SPECKLE,
    BLOOD,
    BLOOD_DARK,
    DOOR_GREEN,
    LANE,
    OUTLINE,
    RAINBOW,
    TILE,
    paint_chair,
    paint_emblem,
    paint_text,
    paint_trolley,
    rect,
    shade,
    text_width,
)
from build_mall import Room, paint_blood  # noqa: E402
import build_airliner as airliner  # noqa: E402
import build_mall as mall  # noqa: E402
import build_station as station  # noqa: E402
import tile_atlas_city as city  # noqa: E402
from tile_atlas_core import (  # noqa: E402
    LAYERS,
    SEED,
    TRANSPARENT,
    Atlas,
    Block,
    Neighbourhood,
    before_run_key,
    between_key,
    cell,
    compose,
    first_row_key,
    leaning,
    neighbour_key,
    parity_key,
    pattern_key,
    row_has_key,
    rule,
    spread,
    tile_of,
)

# Tiles to a row of the atlas image: 64 keeps it square-ish and inside the
# 4096 pixels every phone's GPU takes, up to four thousand tiles.
COLUMNS = 64

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILES = os.path.join("assets", "levels", "tiles")
ATLAS = os.path.join(TILES, "atlas.png")
MANIFEST = os.path.join(TILES, "atlas_manifest.json")
PLACES_DIR = os.path.join("assets", "levels", "places")


def place_group(filename: str) -> str:
    """Return the level-area folder that owns a generated prop."""
    if filename.startswith(("duomo_", "termini_")):
        return "rome"
    if filename.startswith("train_"):
        return "train"
    return "hometown"


def place_asset(filename: str) -> str:
    return os.path.join(PLACES_DIR, place_group(filename), filename)


def manifest_place_asset(filename: str) -> str:
    return f"{place_group(filename)}/{filename}"

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
    """A shut door of planks with its iron lock. It stands two tiles high,
    so it is an object, not a tile. Nothing is painted on it to say it can
    be used: the game's white glint does that, as everywhere else."""
    top = py - TILE
    rect(d, px + 1, top, TILE - 2, TILE * 2, (24, 22, 22))
    rect(d, px + 3, top + 2, TILE - 6, TILE * 2 - 3, (72, 48, 34))
    rect(d, px + 4, top + 3, TILE - 8, 2, (108, 76, 50))
    for x in (6, 9):
        rect(d, px + x, top + 5, 1, TILE * 2 - 7, (56, 38, 28))
    rect(d, px + 3, top + 9, TILE - 6, 2, (54, 50, 50))
    rect(d, px + 3, py + 6, TILE - 6, 2, (54, 50, 50))
    rect(d, px + 4, py + 2, TILE - 8, 1, (44, 30, 24))
    rect(d, px + 10, py - 1, 3, 4, (60, 56, 56))
    rect(d, px + 11, py + 0, 1, 2, (20, 18, 18))


def paint_side_edge(d, px, py, right):
    """The dark line where a floor meets the darkness outside the room."""
    rect(d, px + (14 if right else 0), py, 2, TILE, (40, 40, 46))


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
    rules += side_walls(atlas)
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

    floored = ".:b*+ZM9KTr"
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
            lambda d: airliner.cabin_break(d, 0, 0, roof=False)), 1)]),
        rule("structures", "T", seat(),
             [neighbour_key(0, -1, "T"), neighbour_key(0, 1, "T")]),
        rule("structures", "K", [atlas.bucket(lambda: tile_of(
            lambda d: airliner.cabin_trolley(d, 0, 0)), 1)]),
        rule("structures", "r", [atlas.bucket(lambda: tile_of(
            lambda d: airliner.cabin_broken_seat(d, 0, 0)), 1)]),
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
    top = py - TILE + 6  # the top of the wall shows over it
    height = TILE * 2 - 6
    rect(d, px + 1, top, TILE - 2, height, OUTLINE)
    rect(d, px + 3, top + 2, TILE - 6, height - 3, (18, 16, 18))
    rect(d, px + 2, top + 1, 2, height - 2, (88, 58, 38))
    rect(d, px + 12, top + 1, 2, height - 2, (88, 58, 38))
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


def paint_portal(d, px, py):
    rect(d, px, py, TILE, TILE, (26, 24, 26))
    rect(d, px + 3, py + 1, 10, TILE - 1, (186, 178, 160))
    rect(d, px + 5, py + 2, 6, TILE - 2, (220, 210, 188))
    rect(d, px, py, 3, TILE, WOOD)
    rect(d, px + 13, py, 3, TILE, WOOD)


# ------------------------------------------------ the nave's great pieces
# The columns and the statues of the nave stand on two tiles by two and
# rise one tile over the row behind them: each is one picture, painted
# whole from the top-left cell of its block and cut into the cells it
# covers (`spread`). The row behind is drawn over whoever stands in it.

MARBLE = (206, 198, 182)
MARBLE_LIGHT = (234, 228, 214)
MARBLE_SHADE = (164, 154, 138)
MARBLE_DARK = (116, 106, 94)
INK = (36, 30, 28)
SKIN = (222, 184, 150)
SKIN_SHADE = (184, 142, 112)
HALO = (222, 186, 84)


def outlined(paint, width, height):
    """A figure painted on its own layer with a one-pixel dark outline
    round it, so it reads against the stone behind."""
    from PIL import ImageFilter  # noqa: PLC0415

    layer = Image.new("RGBA", (width, height), TRANSPARENT)
    paint(ImageDraw.Draw(layer))
    alpha = layer.getchannel("A").filter(ImageFilter.MaxFilter(3))
    edge = Image.new("RGBA", (width, height), INK + (255,))
    edge.putalpha(alpha)
    edge.alpha_composite(layer)
    return edge


def paint_great_column(d, px, py):
    """A column two tiles wide: a square plinth on the two cells of its
    block, a fluted shaft rising out of it one tile over the row behind,
    and its capital."""
    def column(c):
        top = 0
        # The plinth: its top face, then its front.
        rect(c, 1, 36, 30, 4, MARBLE_LIGHT)
        rect(c, 1, 40, 30, 7, MARBLE_SHADE)
        rect(c, 1, 46, 30, 1, MARBLE_DARK)
        rect(c, 27, 36, 4, 11, MARBLE_DARK)
        # The base mouldings.
        rect(c, 4, 32, 24, 4, MARBLE)
        rect(c, 4, 32, 24, 1, MARBLE_LIGHT)
        rect(c, 5, 35, 22, 1, MARBLE_SHADE)
        # The shaft, lit from the left: flutes every third pixel.
        tones = [MARBLE_SHADE, MARBLE, MARBLE_LIGHT, MARBLE_LIGHT, MARBLE,
                 MARBLE, MARBLE, MARBLE, MARBLE, MARBLE_SHADE, MARBLE_SHADE,
                 MARBLE_SHADE, MARBLE_SHADE, MARBLE_DARK, MARBLE_SHADE,
                 MARBLE_DARK, MARBLE_DARK, MARBLE_DARK]
        for i, tone in enumerate(tones):
            if i % 3 == 2:
                tone = shade(tone, -18)
            rect(c, 7 + i, top + 10, 1, 22, tone)
        # The capital: necking, bell with its volutes, abacus.
        rect(c, 6, top + 8, 20, 2, MARBLE_DARK)
        rect(c, 4, top + 4, 24, 4, MARBLE)
        rect(c, 4, top + 4, 24, 1, MARBLE_LIGHT)
        for vx in (2, 25):
            rect(c, vx, top + 4, 5, 5, MARBLE_SHADE)
            rect(c, vx + 1, top + 5, 3, 3, MARBLE_LIGHT)
            rect(c, vx + 2, top + 6, 1, 1, MARBLE_DARK)
        rect(c, 1, top, 30, 4, MARBLE_LIGHT)
        rect(c, 1, top + 3, 30, 1, MARBLE_SHADE)
    image = outlined(column, 32, 48)
    d._image.alpha_composite(image, (px, py - TILE))


# The six saints of the nave, each painted in the colours churches give
# them, so they are told apart at a glance.

def _head(c, cx, y, hair=None, beard=None):
    rect(c, cx - 3, y, 6, 6, SKIN)
    rect(c, cx + 1, y + 1, 2, 5, SKIN_SHADE)
    rect(c, cx - 2, y + 2, 1, 1, INK)
    rect(c, cx + 1, y + 2, 1, 1, INK)
    if hair:
        rect(c, cx - 3, y - 1, 6, 2, hair)
        rect(c, cx - 4, y, 1, 4, hair)
        rect(c, cx + 3, y, 1, 4, hair)
    if beard:
        rect(c, cx - 3, y + 4, 6, 3, beard)
        rect(c, cx - 2, y + 7, 4, 1, beard)


def _halo(c, cx, y):
    c.ellipse([cx - 6, y - 4, cx + 5, y + 7], outline=HALO, width=1)


def _robe(c, cx, top, bottom, top_half, bottom_half, colour, dark):
    for y in range(top, bottom):
        half = top_half + (bottom_half - top_half) * (y - top) // max(
            1, bottom - top - 1)
        rect(c, cx - half, y, 2 * half, 1, colour)
        rect(c, cx + half - 2, y, 2, 1, dark)


def saint_madonna(c, cx):
    _halo(c, cx, 3)
    # The blue mantle over her head and down to her feet, the white of her
    # dress down the front, her hands joined.
    _robe(c, cx, 2, 31, 5, 10, (44, 72, 152), (30, 48, 108))
    _robe(c, cx, 12, 31, 2, 4, (232, 224, 208), (200, 190, 172))
    _head(c, cx, 4)
    rect(c, cx - 4, 3, 8, 1, (232, 224, 208))
    rect(c, cx - 2, 14, 4, 3, SKIN)
    rect(c, cx - 6, 29, 12, 2, (196, 170, 80))


def saint_peter(c, cx):
    _halo(c, cx, 3)
    _robe(c, cx, 10, 31, 5, 8, (54, 108, 70), (36, 76, 48))
    # The ochre mantle across him, the two keys held up in front.
    for y in range(12, 28):
        rect(c, cx - 7 + (y - 12) // 2, y, 7, 1, (198, 142, 52))
    _head(c, cx, 4, hair=(170, 168, 162), beard=(190, 188, 182))
    rect(c, cx + 2, 12, 2, 10, HALO)
    rect(c, cx + 1, 12, 4, 3, HALO)
    rect(c, cx + 4, 19, 2, 1, HALO)
    rect(c, cx - 1, 14, 2, 9, (196, 200, 208))
    rect(c, cx - 2, 14, 4, 3, (196, 200, 208))
    rect(c, cx - 3, 20, 2, 1, (196, 200, 208))


def saint_francis(c, cx):
    # The brown habit with its hood, the white cord, the arms held open
    # and a bird come to rest on one hand.
    _robe(c, cx, 10, 31, 5, 8, (112, 78, 48), (80, 54, 34))
    rect(c, cx - 5, 3, 10, 9, (96, 66, 40))
    _head(c, cx, 5, hair=(78, 56, 38))
    rect(c, cx - 1, 11, 2, 12, (230, 224, 208))
    rect(c, cx - 1, 19, 4, 1, (230, 224, 208))
    rect(c, cx - 12, 13, 7, 3, (112, 78, 48))
    rect(c, cx + 5, 13, 7, 3, (112, 78, 48))
    rect(c, cx - 14, 13, 2, 3, SKIN)
    rect(c, cx + 12, 13, 2, 3, SKIN)
    rect(c, cx + 11, 10, 4, 3, (96, 112, 132))
    rect(c, cx + 14, 11, 2, 1, (220, 160, 60))


def saint_conrad(c, cx):
    """Saint Conrad, the bishop Molfetta keeps in its cathedral: mitre,
    red cope with its gold band, the crozier."""
    _robe(c, cx, 12, 31, 3, 5, (234, 230, 220), (200, 196, 186))
    _robe(c, cx, 11, 29, 5, 10, (168, 30, 36), (120, 20, 26))
    rect(c, cx - 1, 11, 2, 18, HALO)
    _head(c, cx, 6, beard=(120, 110, 100))
    for y in range(0, 6):
        half = 1 + y // 2
        rect(c, cx - half - 1, y, 2 * half + 2, 1, (236, 232, 222))
    rect(c, cx - 3, 4, 6, 1, HALO)
    rect(c, cx, 0, 1, 6, HALO)
    rect(c, cx + 9, 2, 1, 29, HALO)
    rect(c, cx + 7, 1, 4, 1, HALO)
    rect(c, cx + 6, 2, 1, 3, HALO)
    rect(c, cx + 7, 4, 1, 1, HALO)


def saint_michael(c, cx):
    """Saint Michael: the wings spread, the armour, the red cloak, the
    sword raised and the devil under his feet."""
    wing = (228, 228, 222)
    for i in range(10):
        rect(c, cx - 5 - i, 3 + i // 2, 1, 14 - i, wing)
        rect(c, cx + 4 + i, 3 + i // 2, 1, 14 - i, wing)
    rect(c, cx - 14, 8, 2, 2, (180, 180, 176))
    rect(c, cx + 12, 8, 2, 2, (180, 180, 176))
    _robe(c, cx, 10, 27, 6, 9, (176, 36, 34), (126, 24, 24))
    rect(c, cx - 4, 10, 8, 8, (194, 200, 210))
    rect(c, cx - 4, 10, 8, 1, (232, 236, 242))
    rect(c, cx - 4, 17, 8, 1, (140, 146, 156))
    _head(c, cx, 4, hair=(214, 176, 90))
    rect(c, cx + 6, 0, 2, 11, (214, 220, 230))
    rect(c, cx + 4, 10, 6, 1, HALO)
    # The devil, flattened under him.
    rect(c, cx - 8, 27, 16, 4, (40, 26, 26))
    rect(c, cx - 8, 26, 2, 1, (150, 30, 24))
    rect(c, cx + 6, 26, 2, 1, (150, 30, 24))
    rect(c, cx - 6, 28, 1, 1, (230, 180, 60))


def saint_joseph(c, cx):
    """Saint Joseph, old and bearded, in purple and ochre, with his
    flowering lily."""
    _halo(c, cx, 3)
    _robe(c, cx, 10, 31, 5, 8, (96, 58, 118), (68, 40, 86))
    for y in range(10, 30):
        rect(c, cx + 1, y, 5 + (y - 10) // 5, 1, (176, 126, 58))
    _head(c, cx, 4, hair=(150, 146, 140), beard=(170, 166, 160))
    rect(c, cx - 6, 3, 1, 20, (62, 118, 52))
    for fx, fy in ((-8, 2), (-5, 3), (-7, 6), (-5, 8)):
        rect(c, cx + fx, fy, 3, 2, (244, 242, 232))
    rect(c, cx - 5, 15, 3, 3, SKIN)


SAINTS = {
    "M": saint_madonna, "K": saint_peter, "F": saint_francis,
    "V": saint_conrad, "Y": saint_michael, "G": saint_joseph,
}


def carved(figure):
    """The saint in bare grey stone: the colours they were painted in
    survive only as how light or dark each part of the stone is, stepped
    onto a few greys so the pixel art stays crisp."""
    greys = [(70, 70, 72), (104, 104, 106), (138, 138, 140), (170, 170, 170),
             (198, 198, 196), (226, 226, 222)]
    stone = figure.copy()
    pixels = stone.load()
    for y in range(stone.height):
        for x in range(stone.width):
            r, g, b, a = pixels[x, y]
            if a:
                light = (r * 299 + g * 587 + b * 114) // 1000
                pixels[x, y] = greys[min(len(greys) - 1,
                                         light * len(greys) // 240)] + (a,)
    return stone


def paint_saint(d, px, py, saint):
    """A statue two tiles by two: the saint, carved in grey stone, on a
    pedestal that fills the lower half of its block, the figure rising a
    tile over the row behind."""
    def statue(c):
        rect(c, 2, 30, 28, 4, MARBLE_LIGHT)
        rect(c, 2, 34, 28, 13, MARBLE_SHADE)
        rect(c, 26, 30, 4, 17, MARBLE_DARK)
        rect(c, 2, 46, 28, 1, MARBLE_DARK)
        rect(c, 9, 38, 14, 5, MARBLE_DARK)
        rect(c, 10, 39, 12, 3, MARBLE)
        figure = Image.new("RGBA", (32, 32), TRANSPARENT)
        saint(ImageDraw.Draw(figure), 16)
        c._image.alpha_composite(carved(figure), (0, 0))
    image = outlined(statue, 32, 48)
    d._image.alpha_composite(image, (px, py - TILE))


# --------------------------------------------------- the nave's masonry

WALL_CAP = (192, 182, 160)
WALL_CAP_LIGHT = (214, 204, 182)
WALL_JOINT = (160, 150, 130)
WALL_DROP = (70, 64, 58)


def paint_front_wall(d, px, py):
    """The top of the front wall, the same coping running east to west."""
    rect(d, px, py, TILE, TILE, WALL_CAP)
    rect(d, px, py + 5, TILE, 5, WALL_CAP_LIGHT)
    rect(d, px, py, TILE, 3, WALL_DROP)
    rect(d, px, py + TILE - 2, TILE, 2, STONE_DARK)
    rect(d, px + 11, py + 3, 1, TILE - 5, WALL_JOINT)


def paint_back_wall(d, px, py, upper):
    """The back wall's face, two courses of ashlar to a tile, joints
    staggered; a cornice along its top and a plinth along its foot."""
    rect(d, px, py, TILE, TILE, STONE)
    for course, joint in ((0, 0), (8, 8)):
        rect(d, px, py + course, TILE, 1, STONE_DARK)
        rect(d, px + joint, py + course, 1, 8, STONE_DARK)
        rect(d, px + joint + 1, py + course + 1, 6, 1, shade(STONE, 16))
    if upper:
        rect(d, px, py, TILE, 3, STONE_LIGHT)
        rect(d, px, py + 3, TILE, 1, STONE_DARK)
    else:
        rect(d, px, py + TILE - 3, TILE, 3, shade(STONE_DARK, -20))
        rect(d, px, py + TILE - 3, TILE, 1, STONE_DARK)


def paint_wall_shadow(d, px, py, side):
    """The shadow a wall throws on the floor at its foot."""
    shadow = (0, 0, 0, 70)
    if side == "left":
        rect(d, px, py, 3, TILE, shadow)
    elif side == "right":
        rect(d, px + TILE - 3, py, 3, TILE, shadow)
    else:
        rect(d, px, py, TILE, 4, shadow)


def duomo(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.duomo. The altar stands on no floor:
    the baker skips it, and so do we."""
    # `9`, `c` and `d` are where the mass ends: plain floor until then.
    floored = ".*:p123PTE9cd" + "".join(SAINTS)
    rules = duomo_masonry_rules(atlas, rng, floored,
                                unshaded="P" + "".join(SAINTS))
    for glyph, paint in {"T": paint_pew, "E": paint_portal,
                         "A": paint_altar}.items():
        rules.append(rule("structures", glyph, [atlas.bucket(
            lambda p=paint: tile_of(lambda d: p(d, 0, 0)), 1)]))
    # Each great piece is painted from the top-left cell of its block: the
    # one with none of its own glyph to the left or above.
    for glyph, paint in [("P", paint_great_column)] + [
            (g, lambda d, px, py, s=s: paint_saint(d, px, py, s))
            for g, s in SAINTS.items()]:
        keys = [neighbour_key(-1, 0, glyph), neighbour_key(0, -1, glyph)]
        buckets, pieces = spread(
            atlas,
            lambda i, p=paint: p if i == 0 else (lambda d, px, py: None),
            keys, reach=(0, 1, 1, 1), count=1)
        rules.append(rule("structures", glyph, buckets, keys, pieces))
    for right in (False, True):
        edge = atlas.bucket(lambda r=right: tile_of(
            lambda d: paint_side_edge(d, 0, 0, r)), 1)
        rules.append(rule("foreground", floored + "A", [[], edge],
                          [neighbour_key(1 if right else -1, 0, "x")]))
    # The door upstairs stands open: the cultist in front of it is what
    # keeps Mario out.
    return {"void": "#060608", "voidGlyph": "x", "rules": rules,
            "objects": [{"glyph": "U", "image": "duomo_nave_door.png",
                         "offsetY": -1, "sprite": stair_door(leaf=True)}]}


def paint_duomo_side(d, px, py, room_left, room_right, window=False,
                     end=False):
    """The top of a wall that runs north to south, seen from above: one
    long coping, its slabs butted end to end. On a side with the room below
    it the coping drops into the room; on a side with the dark outside it
    ends in a hard edge. A partition has the room on both sides. `end` is
    the south end of a stretch of partition, over a doorway: its face shows.
    `window` is a slit window cut through it, the daylight in the glass."""
    rect(d, px, py, TILE, TILE, WALL_CAP)
    rect(d, px + 5, py, 6, TILE, WALL_CAP_LIGHT)
    for room, x in ((room_left, px), (room_right, px + TILE - 3)):
        if room:
            rect(d, x, py, 3, TILE, WALL_DROP)
        else:
            rect(d, x + (0 if x == px else 1), py, 2, TILE, STONE_DARK)
    rect(d, px + 3, py + 11, TILE - 6, 1, WALL_JOINT)
    if window:
        rect(d, px + 5, py + 1, 6, 14, STONE_DARK)
        rect(d, px + 6, py + 2, 4, 12, (164, 184, 200))
        rect(d, px + 6, py + 2, 2, 12, (206, 220, 230))
    if end:
        rect(d, px, py + 9, TILE, 7, STONE)
        rect(d, px, py + 9, TILE, 1, STONE_LIGHT)
        rect(d, px + 7, py + 10, 1, 6, STONE_DARK)
        rect(d, px, py + 15, TILE, 1, STONE_DARK)


def paint_wall_crucifix(d, px, py):
    paint_back_wall(d, px, py, False)
    rect(d, px + 7, py + 1, 2, 12, shade(WOOD, -10))
    rect(d, px + 4, py + 4, 8, 2, shade(WOOD, -10))
    rect(d, px + 7, py + 5, 2, 5, (206, 188, 160))
    rect(d, px + 7, py + 1, 2, 1, GOLD)


def duomo_masonry_rules(atlas: Atlas, rng, floored: str,
                        unshaded: str = "") -> list[dict]:
    """The flagstones under `floored` and the walls round them, as every
    floor of the Duomo has them: the back wall's face, cornice on top and
    plinth at its foot; the side walls and partitions as one long coping
    seen from above, dropping into the room on the side it is on; the front
    wall's coping; and the shadow each throws on the floor at its foot,
    except under `unshaded`, the pieces painted whole from one cell."""
    floor = [
        atlas.bucket(lambda p=parity: cell(
            lambda dd, gx, gy: duomo_floor(dd, rng, gx, gy), p, 0))
        for parity in (0, 1)
    ]
    side_keys = [neighbour_key(-1, 0, "x"), neighbour_key(1, 0, "x"),
                 neighbour_key(0, 1, "d")]

    def sides(window):
        return [atlas.bucket(lambda i=index: tile_of(
            lambda d: paint_duomo_side(d, 0, 0, not i & 1, not i & 2,
                                       window, bool(i & 4))), 1)
                for index in range(8)]
    rules = [
        rule("ground", floored, floor, [parity_key()]),
        rule("structures", "W", [atlas.bucket(
            lambda u=upper: tile_of(lambda d: paint_back_wall(d, 0, 0, u)), 1)
            for upper in (False, True)], [neighbour_key(0, -1, "x")]),
        rule("structures", "X", [atlas.bucket(
            lambda: tile_of(lambda d: paint_wall_crucifix(d, 0, 0)), 1)]),
        rule("structures", "I", sides(False), side_keys),
        rule("structures", "o", sides(True), side_keys),
        rule("structures", "w", [atlas.bucket(
            lambda: tile_of(lambda d: paint_front_wall(d, 0, 0)), 1)]),
        rule("structures", "D", [atlas.bucket(
            lambda: tile_of(lambda d: paint_stairs_down(d, 0, 0)), 1)]),
    ]
    shaded = "".join(g for g in floored if g not in unshaded)
    for side, key in (("left", neighbour_key(-1, 0, "Io")),
                      ("right", neighbour_key(1, 0, "Io")),
                      ("top", neighbour_key(0, -1, "WXUL"))):
        rules.append(rule("structures", shaded, [[], atlas.bucket(
            lambda s=side: tile_of(
                lambda d: paint_wall_shadow(d, 0, 0, s)), 1)], [key]))
    return rules


# ------------------------------------------- the community's first floor
# The kitchen and the refectory west of the partition, the dormitory east
# of it.

def paint_long_table(d, rng, px, py, left, right, up, down):
    """One cell of a table that spans several: the planks run on from the
    cells beside it, and only its outer edges show a rim; along its front
    the apron and, at the corners, the legs. Bowls and bread lie about."""
    rect(d, px, py, TILE, TILE, WOOD)
    for sy in range(2, TILE, 4):
        rect(d, px, py + sy, TILE, 1, shade(WOOD, -12))
    if not up:
        rect(d, px, py, TILE, 2, WOOD_LIGHT)
    if not left:
        rect(d, px, py, 1, TILE, shade(WOOD, -30))
    if not right:
        rect(d, px + TILE - 1, py, 1, TILE, shade(WOOD, -30))
    if not down:
        rect(d, px, py + 10, TILE, 3, shade(WOOD, -26))
        rect(d, px, py + 13, TILE, 3, TRANSPARENT)
        if not left:
            rect(d, px + 1, py + 13, 2, 3, shade(WOOD, -34))
        if not right:
            rect(d, px + TILE - 3, py + 13, 2, 3, shade(WOOD, -34))
    what = rng.randrange(4)
    if what == 1:
        d.ellipse([px + 4, py + 3, px + 10, py + 8], fill=(214, 206, 188))
        d.ellipse([px + 5, py + 4, px + 9, py + 7], fill=(150, 96, 60))
    elif what == 2:
        rect(d, px + 5, py + 3, 6, 4, (196, 150, 92))
        rect(d, px + 6, py + 3, 4, 1, (220, 180, 120))
    elif what == 3:
        rect(d, px + 9, py + 2, 3, 5, (140, 150, 160))
        rect(d, px + 9, py + 2, 3, 1, (190, 198, 206))


def paint_chair_facing(d, px, py, facing):
    """A chair drawn up to a table from the side it stands on."""
    seat, back, leg = WOOD_LIGHT, shade(WOOD, -8), shade(WOOD, -28)
    if facing == "down":
        rect(d, px + 3, py + 1, 10, 5, back)
        rect(d, px + 4, py + 2, 8, 1, WOOD_LIGHT)
        rect(d, px + 3, py + 6, 10, 5, seat)
        rect(d, px + 3, py + 11, 2, 4, leg)
        rect(d, px + 11, py + 11, 2, 4, leg)
    elif facing == "up":
        rect(d, px + 3, py + 2, 10, 5, seat)
        rect(d, px + 3, py + 7, 10, 6, back)
        rect(d, px + 4, py + 8, 8, 1, WOOD_LIGHT)
        rect(d, px + 3, py + 13, 2, 2, leg)
        rect(d, px + 11, py + 13, 2, 2, leg)
    else:
        right = facing == "right"
        bx = px + 2 if right else px + 11
        rect(d, px + 3, py + 7, 10, 3, seat)
        rect(d, bx, py + 1, 3, 11, back)
        rect(d, bx + (1 if right else 1), py + 2, 1, 9, WOOD_LIGHT)
        rect(d, px + 3, py + 10, 2, 5, leg)
        rect(d, px + 11, py + 10, 2, 5, leg)


def paint_kitchen_counter(d, rng, px, py):
    """The kitchen counter: a stone top over wooden cupboards, with what
    is being cooked left on it."""
    rect(d, px, py, TILE, TILE, shade(WOOD, -10))
    rect(d, px, py, TILE, 6, STONE_LIGHT)
    rect(d, px, py + 6, TILE, 1, STONE_DARK)
    rect(d, px + 7, py + 7, 1, 8, shade(WOOD, -34))
    rect(d, px + 5, py + 10, 1, 1, GOLD)
    rect(d, px + 9, py + 10, 1, 1, GOLD)
    rect(d, px, py + 15, TILE, 1, (40, 30, 26))
    what = rng.randrange(4)
    if what == 1:
        rect(d, px + 3, py + 1, 5, 3, (120, 116, 112))
        rect(d, px + 4, py + 1, 3, 1, (170, 166, 160))
    elif what == 2:
        rect(d, px + 8, py + 1, 3, 4, (178, 120, 70))
    elif what == 3:
        rect(d, px + 2, py + 2, 7, 2, (196, 150, 92))


def paint_hearth(d, px, py, right):
    """The kitchen hearth, two cells wide: stone, the fire in it, the pot
    over the fire on the left and a pan on the right."""
    rect(d, px, py, TILE, TILE, STONE)
    rect(d, px, py, TILE, 2, STONE_LIGHT)
    rect(d, px, py + 15, TILE, 1, STONE_DARK)
    inner = px if right else px + 2
    rect(d, inner, py + 4, TILE - 2, 9, (30, 24, 22))
    for fx, colour in ((3, (200, 80, 30)), (7, (240, 160, 60)),
                       (11, (200, 80, 30))):
        rect(d, px + fx, py + 10, 3, 3, colour)
    if right:
        rect(d, px + 2, py + 6, 9, 2, (60, 60, 64))
        rect(d, px + 10, py + 6, 5, 1, (60, 60, 64))
    else:
        rect(d, px + 5, py + 4, 9, 6, (54, 52, 54))
        rect(d, px + 5, py + 4, 9, 1, (110, 108, 108))


def paint_sink(d, px, py):
    rect(d, px, py, TILE, TILE, shade(WOOD, -10))
    rect(d, px, py, TILE, 6, STONE_LIGHT)
    rect(d, px + 2, py + 1, 12, 4, STONE_DARK)
    rect(d, px + 3, py + 2, 10, 2, (110, 134, 150))
    rect(d, px + 7, py, 2, 2, (120, 120, 126))
    rect(d, px, py + 6, TILE, 1, STONE_DARK)
    rect(d, px + 7, py + 7, 1, 8, shade(WOOD, -34))
    rect(d, px, py + 15, TILE, 1, (40, 30, 26))


def paint_night_table(d, px, py):
    rect(d, px + 3, py + 5, 10, 10, shade(WOOD, -6))
    rect(d, px + 3, py + 5, 10, 2, WOOD_LIGHT)
    rect(d, px + 4, py + 9, 8, 1, shade(WOOD, -30))
    rect(d, px + 7, py + 11, 2, 1, GOLD)
    rect(d, px + 5, py + 2, 2, 4, (232, 226, 208))
    rect(d, px + 5, py + 1, 2, 1, (240, 190, 90))


def paint_dorm_bed(d, px, py, foot):
    """A bed of the dormitory, one cell wide and two long: the head with
    its pillow against the wall, the foot under a grey wool blanket."""
    blanket, fold = (112, 118, 126), (140, 146, 154)
    rect(d, px + 1, py, 14, TILE, WOOD)
    if foot:
        rect(d, px + 2, py, 12, 13, blanket)
        rect(d, px + 2, py + 11, 12, 1, shade(blanket, -20))
        rect(d, px + 1, py + 13, 14, 3, shade(WOOD, -18))
    else:
        rect(d, px + 1, py, 14, 2, shade(WOOD, -18))
        rect(d, px + 2, py + 2, 12, 14, LINEN)
        rect(d, px + 3, py + 3, 10, 5, (222, 214, 196))
        rect(d, px + 2, py + 11, 12, 5, blanket)
        rect(d, px + 2, py + 11, 12, 1, fold)


def paint_wardrobe(d, px, py):
    """A wardrobe, a cell wide and taller than a man: it rises a cell over
    the row behind it."""
    top = py - TILE
    rect(d, px + 1, top + 1, 14, 30, shade(WOOD, -10))
    rect(d, px + 1, top + 1, 14, 3, WOOD_LIGHT)
    rect(d, px + 2, top + 5, 5, 24, WOOD)
    rect(d, px + 9, top + 5, 5, 24, WOOD)
    rect(d, px + 7, top + 5, 2, 24, shade(WOOD, -34))
    rect(d, px + 6, top + 16, 1, 2, GOLD)
    rect(d, px + 9, top + 16, 1, 2, GOLD)
    rect(d, px + 1, top + 29, 14, 2, (40, 30, 26))


def duomo_upper(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.duomoUpper, and its door object."""
    rules = duomo_masonry_rules(atlas, rng, ".*RTCBKDdkFHnA")
    rules.append(rule(
        "structures", "T",
        [atlas.bucket(lambda i=index: tile_of(lambda d: paint_long_table(
            d, rng, 0, 0, bool(i & 1), bool(i & 2), bool(i & 4),
            bool(i & 8)))) for index in range(16)],
        [neighbour_key(-1, 0, "T"), neighbour_key(1, 0, "T"),
         neighbour_key(0, -1, "T"), neighbour_key(0, 1, "T")]))

    def facing(index):
        for bit, way in ((1, "down"), (2, "up"), (4, "right"), (8, "left")):
            if index & bit:
                return way
        return "down"
    rules.append(rule(
        "structures", "C",
        [atlas.bucket(lambda f=facing(index): tile_of(
            lambda d: paint_chair_facing(d, 0, 0, f)), 1)
         for index in range(16)],
        [neighbour_key(0, 1, "T"), neighbour_key(0, -1, "T"),
         neighbour_key(1, 0, "T"), neighbour_key(-1, 0, "T")]))
    rules.append(rule("structures", "k", [atlas.bucket(lambda: tile_of(
        lambda d: paint_kitchen_counter(d, rng, 0, 0)))]))
    rules.append(rule("structures", "F", [atlas.bucket(
        lambda r=right: tile_of(lambda d: paint_hearth(d, 0, 0, r)), 1)
        for right in (False, True)], [neighbour_key(-1, 0, "F")]))
    for glyph, paint in {"H": paint_sink, "K": paint_cupboard,
                         "n": paint_night_table,
                         "d": lambda d, px, py: rect(
                             d, px + 1, py, TILE - 2, 2, STONE_LIGHT)
                         }.items():
        rules.append(rule("structures", glyph, [atlas.bucket(
            lambda p=paint: tile_of(lambda d: p(d, 0, 0)), 1)]))
    rules.append(rule("structures", "B", [atlas.bucket(
        lambda f=foot: tile_of(lambda d: paint_dorm_bed(d, 0, 0, f)), 1)
        for foot in (False, True)], [neighbour_key(0, -1, "B")]))
    buckets, pieces = spread(atlas, lambda i: paint_wardrobe,
                             reach=(0, 1, 0, 0), count=1)
    rules.append(rule("structures", "A", buckets, pieces=pieces))
    door = Image.new("RGBA", (TILE, TILE * 2), TRANSPARENT)
    paint_locked_door(ImageDraw.Draw(door), 0, TILE)
    # Once the key has opened it, the stairs to the second floor show.
    return {
        "void": "#060608",
        "voidGlyph": "x",
        "rules": rules,
        "objects": [{"glyph": "L", "image": "duomo_upper_door.png",
                     "offsetY": -1, "sprite": door,
                     "whenOpen": "duomo_upper_door_open.png",
                     "openSprite": stair_door(leaf=True)}],
    }


# ------------------------------------------- the Duomo's doors and stairs
# Every way up inside the Duomo is a doorway in the back wall of the floor
# it leaves, two tiles high: the wall's lower course and the cell of the
# doorway itself, so they are objects. Inside it, in the dark, the stairs
# climb away. The ones Mario comes up by are the stairs `D` in the front
# wall of the next floor (`paint_stairs_down`).

STAIRWELL = (20, 18, 20)


def paint_stair_door(d, px, py, leaf=False):
    """A doorway two tiles high, (px, py) its top-left: an arch in a stone
    frame, and the steps going up into the dark behind it. With `leaf`, a
    wooden door stands open against its left jamb."""
    height = TILE * 2
    rect(d, px, py, TILE, height, STONE)
    rect(d, px, py, TILE, 2, shade(STONE, 24))
    rect(d, px + 1, py + 3, TILE - 2, height - 3, STONE_LIGHT)
    rect(d, px + 3, py + 7, TILE - 6, height - 7, STAIRWELL)
    rect(d, px + 4, py + 5, TILE - 8, 2, STAIRWELL)
    rect(d, px + 6, py + 4, TILE - 12, 1, STAIRWELL)
    # The steps: the lowest in the light from the room, the rest going
    # darker as they climb.
    for step in range(5):
        y = py + height - 3 - step * 4
        rect(d, px + 3, y, TILE - 6, 2, shade(STONE, -20 - step * 22))
        rect(d, px + 3, y + 2, TILE - 6, 1, shade(STAIRWELL, 6))
    if leaf:
        rect(d, px + 3, py + 8, 3, height - 9, WOOD)
        rect(d, px + 3, py + 8, 1, height - 9, WOOD_LIGHT)
        rect(d, px + 5, py + 18, 1, 2, GOLD)


def stair_door(leaf=False) -> Image.Image:
    door = Image.new("RGBA", (TILE, TILE * 2), TRANSPARENT)
    paint_stair_door(ImageDraw.Draw(door), 0, 0, leaf)
    return door


def paint_wall_window(d, px, py):
    """A narrow window in a side wall, the daylight through it."""
    duomo_wall(d, px, py)
    rect(d, px + 5, py + 2, 6, 12, STONE_DARK)
    rect(d, px + 6, py + 3, 4, 10, (164, 184, 200))
    rect(d, px + 6, py + 3, 4, 2, (206, 220, 230))


def paint_papers(d, rng, px, py):
    """Loose sheets on the flagstones."""
    for _ in range(3):
        x, y = px + rng.randrange(10), py + rng.randrange(11)
        rect(d, x, y, 5, 4, (214, 208, 190))
        rect(d, x + 1, y + 1, 3, 1, (140, 132, 120))


# ------------------------------------------------ Don Angelo's own room

PRIEST_RED = (112, 30, 34)
PRIEST_RED_LIGHT = (146, 48, 50)
BOOKS = [(116, 38, 36), (44, 64, 96), (58, 86, 52), (150, 120, 60),
         (90, 58, 40), (68, 40, 72)]


def paint_bookcase(d, rng, px, py):
    rect(d, px, py, TILE, TILE - 1, shade(WOOD, -24))
    for shelf in (1, 6, 11):
        x = px + 1
        while x < px + TILE - 2:
            width = rng.choice((1, 2, 2))
            tall = rng.randint(3, 4)
            rect(d, x, py + shelf + 4 - tall, width, tall, rng.choice(BOOKS))
            x += width + rng.choice((0, 0, 1))
        rect(d, px, py + shelf + 4, TILE, 1, WOOD_LIGHT)
    rect(d, px, py + TILE - 1, TILE, 1, (40, 30, 26))


def paint_kneeler(d, px, py):
    rect(d, px + 2, py + 2, 12, 4, WOOD)
    rect(d, px + 2, py + 2, 12, 1, WOOD_LIGHT)
    rect(d, px + 3, py + 6, 2, 7, shade(WOOD, -20))
    rect(d, px + 11, py + 6, 2, 7, shade(WOOD, -20))
    rect(d, px + 2, py + 11, 12, 3, PRIEST_RED)
    rect(d, px + 2, py + 11, 12, 1, PRIEST_RED_LIGHT)


def paint_priest_bed(d, px, py, foot):
    """His bed, one tile wide and two long: the head with its pillow, the
    foot under a red blanket."""
    rect(d, px + 1, py, 14, TILE, WOOD)
    if foot:
        rect(d, px + 2, py, 12, 13, PRIEST_RED)
        rect(d, px + 2, py + 10, 12, 1, shade(PRIEST_RED, -20))
        rect(d, px + 1, py + 13, 14, 3, shade(WOOD, -18))
    else:
        rect(d, px + 1, py, 14, 2, shade(WOOD, -18))
        rect(d, px + 2, py + 2, 12, 14, LINEN)
        rect(d, px + 3, py + 3, 10, 5, (222, 214, 196))
        rect(d, px + 2, py + 11, 12, 5, PRIEST_RED)
        rect(d, px + 2, py + 11, 12, 1, PRIEST_RED_LIGHT)


def paint_desk(d, px, py):
    paint_table(d, px, py)
    rect(d, px + 3, py + 4, 6, 4, (214, 208, 190))
    rect(d, px + 4, py + 5, 4, 1, (120, 112, 104))
    rect(d, px + 11, py + 3, 2, 4, (230, 224, 206))
    rect(d, px + 11, py + 2, 2, 1, (240, 200, 110))


def paint_rug(d, px, py, left, right, up, down):
    """The rug, gold-bordered on every side where it ends."""
    rect(d, px, py, TILE, TILE, PRIEST_RED)
    for x in range(px + (0 if left else 1), px + TILE, 4):
        rect(d, x + 1, py + 7, 2, 2, PRIEST_RED_LIGHT)
    if not left:
        rect(d, px, py, 2, TILE, GOLD)
    if not right:
        rect(d, px + TILE - 2, py, 2, TILE, GOLD)
    if not up:
        rect(d, px, py, TILE, 2, GOLD)
    if not down:
        rect(d, px, py + TILE - 2, TILE, 2, GOLD)


def duomo_second_floor(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.duomoSecondFloor: Don Angelo's room
    and the landing, and the doorway up the tower."""
    rules = duomo_masonry_rules(atlas, rng, ".*:rdDQNKBTCS")
    props = {
        "Q": None, "N": paint_kneeler, "K": paint_cupboard,
        "T": paint_desk, "C": paint_refectory_chair, "S": paint_statue,
        "d": lambda d, px, py: rect(d, px + 1, py, TILE - 2, 2, STONE_LIGHT),
    }
    rules.append(rule("structures", "Q", [atlas.bucket(lambda: tile_of(
        lambda d: paint_bookcase(d, rng, 0, 0)))]))
    for glyph, paint in props.items():
        if paint is not None:
            rules.append(rule("structures", glyph, [atlas.bucket(
                lambda p=paint: tile_of(lambda d: p(d, 0, 0)), 1)]))
    rules.append(rule("structures", "B", [atlas.bucket(
        lambda f=foot: tile_of(lambda d: paint_priest_bed(d, 0, 0, f)), 1)
        for foot in (False, True)], [neighbour_key(0, -1, "B")]))
    rules.append(rule(
        "structures", "r",
        [atlas.bucket(lambda i=index: tile_of(lambda d: paint_rug(
            d, 0, 0, bool(i & 1), bool(i & 2), bool(i & 4), bool(i & 8))), 1)
         for index in range(16)],
        [neighbour_key(-1, 0, "r"), neighbour_key(1, 0, "r"),
         neighbour_key(0, -1, "r"), neighbour_key(0, 1, "r")]))
    return {"void": "#060608", "voidGlyph": "x", "rules": rules,
            "objects": [{"glyph": "U", "image": "duomo_stair_arch.png",
                         "offsetY": -1, "sprite": stair_door()}]}


# ------------------------------------------------------ the bell tower

BRONZE = (150, 108, 52)
BRONZE_LIGHT = (196, 156, 84)
BRONZE_DARK = (92, 62, 30)


# The treads of a flight, from its foot (dimmest) to its head (lightest):
# the higher a step, the nearer the light of the doorway it climbs to.
FLIGHT_TREADS = [(150, 142, 128), (166, 158, 142), (182, 174, 158),
                 (198, 190, 174)]
FLIGHT_RISER = (70, 64, 60)
FLIGHT_KERB = (120, 112, 102)


# How many steps climb through one cell of a flight.
STEPS_PER_CELL = 4


def paint_flight_step(d, px, py, level, foot, head, left, right):
    """One cell of a broad stone flight climbing north, seen from above and
    a little in front: several narrow steps across it, each a pale tread
    with its nosing catching the light over a thin riser in shadow.
    `level` (0 for the cell at the foot, 3 at the head) and the place of a
    step within its cell lighten the treads as the flight climbs. A kerb
    runs down the flight's own sides only (`left`, `right`), so the cells
    of a row read as one wide flight; the foot is set off from the floor by
    a darker edge, and the head runs into the landing of the doorway."""
    pitch = TILE // STEPS_PER_CELL
    rect(d, px, py, TILE, TILE, FLIGHT_RISER)
    for step in range(STEPS_PER_CELL):
        climb = level * STEPS_PER_CELL + (STEPS_PER_CELL - 1 - step)
        lift = climb * 3
        tread = shade(FLIGHT_TREADS[0], lift - 6)
        sy = py + step * pitch
        rect(d, px, sy, TILE, pitch - 1, tread)
        rect(d, px, sy, TILE, 1, shade(tread, 24))
        rect(d, px, sy + pitch - 1, TILE, 1, shade(FLIGHT_RISER, -10))
    if left:
        rect(d, px, py, 3, TILE, FLIGHT_KERB)
        rect(d, px + 2, py, 1, TILE, shade(FLIGHT_KERB, -30))
    if right:
        rect(d, px + TILE - 3, py, 3, TILE, shade(FLIGHT_KERB, 18))
        rect(d, px + TILE - 3, py, 1, TILE, shade(FLIGHT_KERB, -20))
    if head:
        rect(d, px, py, TILE, 2, shade(FLIGHT_TREADS[3], 16))
    if foot:
        rect(d, px, py + TILE - 1, TILE, 1, (40, 36, 34))


def paint_railing(d, px, py, top, bottom):
    """The railing along a flight, seen from above: a wooden handrail on
    turned balusters, a newel post at either end, and the shadow it throws
    across the steps beside it."""
    shadow = (0, 0, 0, 60)
    rect(d, px + 11, py, 4, TILE, shadow)
    for by in (2, 6, 10, 14):
        rect(d, px + 8, py + by, 2, 2, shade(WOOD, -30))
        rect(d, px + 8, py + by, 1, 1, shade(WOOD, 10))
    rect(d, px + 5, py, 4, TILE, shade(WOOD, -12))
    rect(d, px + 5, py, 1, TILE, WOOD_LIGHT)
    rect(d, px + 8, py, 1, TILE, shade(WOOD, -34))
    for end, y in ((top, py + 1), (bottom, py + TILE - 7)):
        if end:
            rect(d, px + 3, y, 8, 6, shade(WOOD, -20))
            rect(d, px + 4, y + 1, 6, 4, WOOD)
            rect(d, px + 4, y + 1, 6, 1, WOOD_LIGHT)
            rect(d, px + 6, y + 2, 2, 2, GOLD)


def bell() -> Image.Image:
    """The bell, two tiles by two, hung from its beam."""
    size = TILE * 2
    image = Image.new("RGBA", (size, size), TRANSPARENT)
    d = ImageDraw.Draw(image)
    rect(d, 0, 2, size, 4, WOOD)
    rect(d, 0, 2, size, 1, WOOD_LIGHT)
    rect(d, 14, 5, 4, 3, shade(WOOD, -20))
    for y in range(8, 27):
        half = 5 + (y - 8) * 9 // 18
        rect(d, 16 - half, y, 2 * half, 1, BRONZE)
        rect(d, 16 - half, y, 2, 1, BRONZE_DARK)
        rect(d, 16 - half + 3, y, 2, 1, BRONZE_LIGHT)
        rect(d, 16 + half - 3, y, 3, 1, BRONZE_DARK)
    rect(d, 1, 26, size - 2, 3, BRONZE_DARK)
    rect(d, 2, 26, size - 4, 1, BRONZE_LIGHT)
    rect(d, 14, 29, 4, 3, (58, 50, 44))
    return image


def duomo_tower(atlas: Atlas, rng) -> dict:
    """The rules that paint either flight of the bell tower."""
    rules = duomo_masonry_rules(atlas, rng, ".*:s|KO")
    rules += [
        # How far a step is from the foot of its flight, from the steps
        # below it; whether it is the first or the last; and whether it is
        # at the left or the right end of its row of steps.
        rule("structures", "s", [atlas.bucket(
            lambda i=index: tile_of(lambda d: paint_flight_step(
                d, 0, 0, 3 - min(3, (i & 1) + (i >> 1 & 1) + (i >> 2 & 1)),
                not i & 1, not i & 8, not i & 16, not i & 32)), 1)
            for index in range(64)],
            [neighbour_key(0, 1, "s"), neighbour_key(0, 2, "s"),
             neighbour_key(0, 3, "s"), neighbour_key(0, -1, "s"),
             neighbour_key(-1, 0, "s"), neighbour_key(1, 0, "s")]),
        rule("structures", "|", [atlas.bucket(
            lambda i=index: tile_of(lambda d: paint_railing(
                d, 0, 0, not i & 1, not i & 2)), 1) for index in range(4)],
            [neighbour_key(0, -1, "|"), neighbour_key(0, 1, "|")]),
        rule("structures", "K", [atlas.bucket(
            lambda: tile_of(lambda d: paint_backroom_crate(d, 0, 0)), 1)]),
    ]
    return {"void": "#060608", "voidGlyph": "x", "rules": rules,
            "objects": [{"glyph": "U", "image": "duomo_stair_arch.png",
                         "offsetY": -1, "sprite": stair_door()}]}


def duomo_bells(atlas: Atlas, rng) -> dict:
    """The rules that paint the bell chamber, and its bell."""
    place = duomo_tower(atlas, rng)
    place["objects"].append({"glyph": "O", "image": "duomo_bell.png",
                             "tiles": [2, 2], "sprite": bell()})
    return place


# ------------------------------------------------ the top of the tower

TOWER_SLAB = (190, 180, 158)
TOWER_SLAB_ALT = (178, 168, 146)
TOWER_JOINT = (140, 130, 112)
NAVE_TILE = (86, 50, 38)
NAVE_TILE_LIGHT = (104, 62, 46)
NAVE_TILE_DARK = (56, 32, 26)


def paint_tower_slab(d, rng, x, y):
    """The stone the tower is roofed with, two tones on the parity of
    x + y, weathered."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, TOWER_SLAB if (x + y) % 2 else TOWER_SLAB_ALT)
    rect(d, px, py, TILE, 1, TOWER_JOINT)
    rect(d, px, py, 1, TILE, TOWER_JOINT)
    for _ in range(3):
        rect(d, px + rng.randrange(15), py + rng.randrange(15), 1, 1,
             TOWER_JOINT)


def paint_tower_parapet(d, px, py, low=False):
    """The parapet round the top, a block of stone seen from above; `low`
    is the stretch knocked down to a course, where Mario leans over."""
    rect(d, px, py, TILE, TILE, STONE_DARK)
    top = 5 if low else 1
    rect(d, px + 1, py + top, TILE - 2, TILE - top - 4, STONE)
    rect(d, px + 1, py + top, TILE - 2, 2, STONE_LIGHT)
    rect(d, px, py + TILE - 3, TILE, 3, (58, 54, 50))
    if low:
        rect(d, px + 1, py + 1, TILE - 2, 4, TOWER_SLAB_ALT)
        for dx in (2, 7, 12):
            rect(d, px + dx, py + top - 1, 2, 1, STONE_DARK)


def paint_lightning_rod(d, px, py):
    rect(d, px + 4, py + 12, 8, 3, STONE_DARK)
    rect(d, px + 7, py + 2, 2, 11, (84, 86, 92))
    rect(d, px + 7, py + 2, 1, 11, (150, 152, 158))
    rect(d, px + 6, py, 4, 3, (150, 152, 158))


def paint_hatch(d, px, py):
    """The hatch the stairs come up through, its lid thrown back north."""
    rect(d, px + 1, py, 14, 5, WOOD)
    rect(d, px + 1, py, 14, 1, WOOD_LIGHT)
    rect(d, px + 5, py + 1, 1, 4, shade(WOOD, -20))
    rect(d, px + 10, py + 1, 1, 4, shade(WOOD, -20))
    rect(d, px + 1, py + 5, 14, 11, STONE_DARK)
    rect(d, px + 3, py + 6, 10, 9, STAIRWELL)
    for step in range(3):
        rect(d, px + 3, py + 13 - step * 3, 10, 1,
             shade(STONE, -30 - step * 24))


def paint_nave_roof(d, x, y):
    """The roof of the nave, a long way below the tower: rows of clay
    tiles, dim with the distance."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, NAVE_TILE)
    for row in range(4):
        sy = py + row * 4
        rect(d, px, sy, TILE, 1, NAVE_TILE_DARK)
        for sx in range(px + (2 if (y * 4 + row) % 2 else 0), px + TILE, 4):
            rect(d, sx, sy + 1, 1, 3, NAVE_TILE_DARK)
            rect(d, sx + 1, sy + 1, 1, 2, NAVE_TILE_LIGHT)


def duomo_tower_roof(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.duomoTowerRoof."""
    slab = [atlas.bucket(lambda p=parity: cell(
        lambda d, gx, gy: paint_tower_slab(d, rng, gx, gy), p, 0))
        for parity in (0, 1)]
    nave = atlas.bucket(lambda: cell(
        lambda d, gx, gy: paint_nave_roof(d, gx, gy)), 1)
    rules = [
        rule("ground", ".:9Dn", slab, [parity_key()]),
        rule("structures", "=", [nave]),
        rule("structures", "^", [atlas.bucket(
            lambda: tile_of(lambda d: paint_tower_parapet(d, 0, 0)), 1)]),
        rule("structures", ">", [atlas.bucket(lambda: tile_of(
            lambda d: paint_tower_parapet(d, 0, 0, low=True)), 1)]),
        rule("structures", "n", [atlas.bucket(
            lambda: tile_of(lambda d: paint_lightning_rod(d, 0, 0)), 1)]),
        rule("structures", "D", [atlas.bucket(
            lambda: tile_of(lambda d: paint_hatch(d, 0, 0)), 1)]),
        rule("structures", ":", [atlas.bucket(lambda: tile_of(
            lambda d: airliner.roof_rubble(d, rng, 0, 0)))]),
    ]
    return {"void": "#060608", "voidGlyph": "x", "rules": rules,
            "objects": [duomo_tower_roof_view(rng)]}

# ------------------------------------------- the view from the bell tower
# Everything round the two tower tops is one picture: the Duomo of Molfetta
# seen from its own bell tower. After the real church (San Corrado, on the
# harbour): the central nave roofed by three pyramid domes in a row on
# hexagonal drums, the middle one the tallest, their stone slabs laid in
# diamonds that close on the apex; the aisles under single slopes of grey
# limestone slabs (chiancarelle); the two square towers of pale limestone
# at the east end, either side of the apse, over the seafront; and round it
# the white flat roofs of the old town.

SLAB = (176, 170, 158)
SLAB_LIGHT = (206, 200, 186)
SLAB_DARK = (124, 118, 108)
LIMESTONE = (216, 206, 184)
LIMESTONE_DARK = (168, 156, 134)
WHITEWASH = (238, 234, 224)
WHITEWASH_SHADE = (196, 190, 178)
ALLEY = (86, 82, 78)
PAVING = (198, 192, 178)
SEA = (40, 84, 112)
SEA_LIGHT = (84, 136, 160)


def _shadow(image, polygon, alpha=70):
    layer = Image.new("RGBA", image.size, TRANSPARENT)
    ImageDraw.Draw(layer).polygon(polygon, fill=(20, 18, 24, alpha))
    image.alpha_composite(layer)


def _slab_roof(d, rng, x0, y0, x1, y1, base, vertical):
    """A roof of limestone slabs in courses, lit by how `base` is set."""
    rect(d, x0, y0, x1 - x0, y1 - y0, base)
    if vertical:
        for x in range(x0, x1, 5):
            rect(d, x, y0, 1, y1 - y0, shade(base, -18))
            for y in range(y0 + rng.randrange(4), y1, 7):
                rect(d, x + 1, y, 4, 1, shade(base, -10))
    else:
        for y in range(y0, y1, 4):
            rect(d, x0, y, x1 - x0, 1, shade(base, -16))
            for x in range(x0 + (y // 4 % 2) * 3, x1, 6):
                rect(d, x, y + 1, 1, 3, shade(base, -10))


def _dome(image, cx, cy, radius, height):
    """A pyramid dome on its hexagonal drum, lit from the north-west."""
    import math  # noqa: PLC0415

    d = ImageDraw.Draw(image)
    drum = [(cx + (radius + 4) * math.cos(math.radians(a)),
             cy + (radius + 4) * math.sin(math.radians(a)) * 0.8)
            for a in range(0, 360, 60)]
    _shadow(image, [(x + height * 0.8, y + height * 0.5) for x, y in drum],
            80)
    front = [(x, y + 7) for x, y in drum]
    d.polygon(front, fill=LIMESTONE_DARK)
    d.polygon(drum, fill=LIMESTONE)
    base = [(cx + radius * math.cos(math.radians(a)),
             cy + radius * math.sin(math.radians(a)) * 0.8)
            for a in range(0, 360, 60)]
    apex = (cx, cy - height)
    for i in range(6):
        a, b = base[i], base[(i + 1) % 6]
        mid = math.radians(i * 60 + 30)
        light = 0.5 + 0.5 * math.cos(mid - math.radians(225))
        tone = tuple(int(SLAB_DARK[k] + (SLAB_LIGHT[k] - SLAB_DARK[k]) * light)
                     for k in range(3))
        d.polygon([a, b, apex], fill=tone)
        # The slabs, in courses that close on the apex.
        for t in (0.25, 0.5, 0.75):
            pa = (a[0] + (apex[0] - a[0]) * t, a[1] + (apex[1] - a[1]) * t)
            pb = (b[0] + (apex[0] - b[0]) * t, b[1] + (apex[1] - b[1]) * t)
            d.line([pa, pb], fill=shade(tone, -22), width=1)
        d.line([a, apex], fill=shade(tone, -40), width=1)
    d.ellipse([cx - 2, cy - height - 3, cx + 2, cy - height + 1],
              fill=SLAB_DARK)


def _old_town(d, rng, x0, y0, x1, y1):
    """Blocks of white houses with flat terraces, alleys between them."""
    y = y0
    while y < y1:
        depth = rng.randint(34, 58)
        x = x0
        while x < x1:
            width = rng.randint(30, 56)
            right = min(x + width, x1)
            bottom = min(y + depth, y1)
            if right - x > 10 and bottom - y > 12:
                white = shade(WHITEWASH, -rng.randrange(0, 14))
                rect(d, x, y, right - x, bottom - y - 6, white)
                rect(d, x, bottom - 6, right - x, 6, WHITEWASH_SHADE)
                for wx in range(x + 4, right - 4, 9):
                    rect(d, wx, bottom - 5, 3, 3, (70, 96, 70))
                rect(d, x, y, right - x, 2, shade(white, 10))
                rect(d, x, y, 2, bottom - y - 6, shade(white, 6))
                rect(d, right - 2, y, 2, bottom - y - 6, shade(white, -16))
                what = rng.randrange(5)
                tx = rng.randint(x + 4, max(x + 4, right - 12))
                ty = rng.randint(y + 4, max(y + 4, bottom - 18))
                if what == 0:
                    d.ellipse([tx, ty, tx + 8, ty + 8], fill=(150, 150, 154))
                    d.ellipse([tx + 1, ty + 1, tx + 7, ty + 5],
                              fill=(186, 186, 190))
                elif what == 1:
                    rect(d, tx, ty, 10, 8, WHITEWASH_SHADE)
                    rect(d, tx, ty, 10, 2, shade(WHITEWASH, 6))
                    rect(d, tx + 3, ty + 4, 4, 4, (90, 70, 56))
                elif what == 2:
                    for lx in range(tx, min(tx + 20, right - 2), 3):
                        rect(d, lx, ty + 2, 2, 3, rng.choice(
                            [(190, 60, 60), (70, 110, 170), (240, 240, 236),
                             (220, 190, 80)]))
                    rect(d, tx, ty + 1, min(20, right - 2 - tx), 1,
                         (120, 120, 120))
                elif what == 3:
                    rect(d, tx, ty, 4, 6, (170, 160, 150))
                    rect(d, tx, ty, 4, 2, (90, 84, 80))
            x = right + rng.randint(3, 5)
        y += depth + rng.randint(3, 5)


def paint_tower_view(rows, rng) -> Image.Image:
    width, height = len(rows[0]) * TILE, len(rows) * TILE
    image = Image.new("RGBA", (width, height), ALLEY + (255,))
    d = ImageDraw.Draw(image)
    towers = []
    for left in range(len(rows[0])):
        for top in range(len(rows)):
            if rows[top][left] == "^" and (left == 0 or rows[top][left - 1]
                                           != "^") and (
                    top == 0 or rows[top - 1][left] != "^"):
                right = left
                while right + 1 < len(rows[0]) and rows[top][right + 1] in \
                        "^>":
                    right += 1
                bottom = top
                while bottom + 1 < len(rows) and rows[bottom + 1][left] == "^":
                    bottom += 1
                if right - left > 2 and bottom - top > 2:
                    towers.append((left * TILE, top * TILE,
                                   (right + 1) * TILE, (bottom + 1) * TILE))
    towers.sort()
    (ax0, ay0, ax1, ay1), (bx0, _, bx1, by1) = towers[0], towers[-1]
    # South of the church it is the harbour map, as it runs there: the
    # sagrato in front of the towers, a row of palazzi with the alley and
    # its gate, the seafront road between its two sidewalks, the promenade
    # and its palms, the parapet, and only then the sea.
    front = ay1 + 30         # where the sagrato begins
    church_x0, church_x1 = ax0, bx1
    ridge = (bx0 + ax1) // 2
    palazzi = front + 36     # the row of palazzi across the sagrato
    kerb = palazzi + 54      # the sidewalk of the seafront road
    road = kerb + 12         # the road itself
    promenade = road + 60    # the far sidewalk, then the promenade
    quay = promenade + 40    # the parapet, and the sea past it

    rect(d, 0, quay, width, height - quay, SEA)
    for _ in range(40):
        wx, wy = rng.randrange(width), rng.randrange(quay + 6, height)
        rect(d, wx, wy, rng.randint(3, 8), 1, SEA_LIGHT)
    for bx, hull in ((70, (236, 236, 230)), (width - 120, (70, 110, 170))):
        by = quay + 14
        d.polygon([(bx, by), (bx + 26, by), (bx + 22, by + 8),
                   (bx + 4, by + 8)], fill=hull)
        rect(d, bx + 8, by - 5, 9, 5, (200, 180, 140))
        rect(d, bx + 2, by + 8, 22, 1, (30, 60, 80))
    rect(d, 0, quay - 5, width, 5, LIMESTONE_DARK)  # the parapet
    rect(d, 0, quay - 5, width, 1, LIMESTONE)
    for top_, bottom_ in ((kerb, road), (promenade, quay - 5)):
        rect(d, 0, top_, width, bottom_ - top_, PAVING)
        for x in range(0, width, 12):
            rect(d, x, top_, 1, bottom_ - top_, shade(PAVING, -14))
        for y in range(top_ + 8, bottom_, 8):
            rect(d, 0, y, width, 1, shade(PAVING, -10))
        rect(d, 0, bottom_ - 2, width, 2, shade(PAVING, -30))  # the kerb
    rect(d, 0, road, width, promenade - road, ASPHALT)
    for _ in range(width // 3):
        rect(d, rng.randrange(width), rng.randrange(road, promenade), 1, 1,
             ASPHALT_SPECKLE)
    middle = (road + promenade) // 2
    for x in range(4, width, 24):  # the dashed line down its middle
        rect(d, x, middle - 1, 12, 2, LANE)
    for px in range(40, width - 20, 96):  # palms along the promenade
        rect(d, px, promenade + 8, 3, 14, (110, 84, 56))
        d.ellipse([px - 9, promenade + 1, px + 12, promenade + 13],
                  fill=(60, 96, 52))
        d.ellipse([px - 5, promenade + 3, px + 8, promenade + 10],
                  fill=(84, 124, 66))

    # The old town either side of the church and north of it, down to the
    # seafront road; the sagrato in front of the towers, and across it the
    # palazzi, split by the alley with the churchyard gate at its top.
    _old_town(d, rng, 0, 0, church_x0 - 10, kerb - 4)
    _old_town(d, rng, church_x1 + 10, 0, width, kerb - 4)
    rect(d, church_x0 - 10, 0, church_x1 - church_x0 + 20, 26, PAVING)
    rect(d, church_x0 - 10, front, church_x1 - church_x0 + 20,
         palazzi - front, PAVING)
    for x in range(church_x0 - 10, church_x1 + 10, 12):
        rect(d, x, front, 1, palazzi - front, shade(PAVING, -14))
    _old_town(d, rng, church_x0 - 10, palazzi, ridge - 12, kerb - 4)
    _old_town(d, rng, ridge + 12, palazzi, church_x1 + 10, kerb - 4)
    rect(d, ridge - 12, palazzi - 2, 24, kerb - palazzi + 2, PAVING)
    for y in range(palazzi + 4, kerb, 8):
        rect(d, ridge - 12, y, 24, 1, shade(PAVING, -12))
    for x in range(ridge - 12, ridge + 12, 4):  # the gate's railings
        rect(d, x, palazzi - 2, 1, 7, (40, 34, 30))
    rect(d, ridge - 12, palazzi - 2, 24, 1, (40, 34, 30))

    # The church: the aisles under their single slopes, the nave between
    # the towers under its ridge, the east end between the towers.
    top = 26
    nave_x0, nave_x1 = ax1, bx0
    _slab_roof(d, rng, church_x0, top, nave_x0, ay0, SLAB_LIGHT, False)
    _slab_roof(d, rng, nave_x1, top, church_x1, by1 - (ay1 - ay0),
               SLAB, False)
    rect(d, church_x0, top, 3, ay0 - top, SLAB_DARK)
    rect(d, church_x1 - 3, top, 3, ay0 - top, SLAB_DARK)
    _slab_roof(d, rng, nave_x0, top, ridge, ay1 - 20, SLAB_LIGHT, True)
    _slab_roof(d, rng, ridge, top, nave_x1, ay1 - 20, SLAB_DARK, True)
    rect(d, ridge - 1, top, 3, ay1 - 20 - top, LIMESTONE)
    rect(d, church_x0, top - 6, church_x1 - church_x0, 6, LIMESTONE_DARK)
    rect(d, church_x0, top - 6, church_x1 - church_x0, 2, LIMESTONE)
    # The apse, its half round of slabs and its wall down to the seafront.
    apse_y = ay1 - 20
    d.pieslice([nave_x0 + 6, apse_y - 28, nave_x1 - 6, apse_y + 28], 0, 180,
               fill=SLAB)
    for r in range(8, 34, 6):
        d.arc([ridge - r * 1.5, apse_y - r, ridge + r * 1.5, apse_y + r],
              0, 180, fill=SLAB_DARK)
    rect(d, nave_x0 + 6, apse_y + 28, nave_x1 - nave_x0 - 12, front - apse_y
         - 28, LIMESTONE)
    rect(d, ridge - 2, apse_y + 34, 4, 10, (40, 34, 30))

    # The domes, east to west, the middle one the tallest.
    span = (ay0 - top) // 3
    for i, (radius, lift) in enumerate(((24, 20), (32, 30), (24, 20))):
        cy = top + span * i + span // 2 + 6
        _dome(image, ridge, cy, radius, lift)

    # The two towers: their tops are the tiles, cut out of the picture;
    # below each, its south face falling to the seafront, and its shadow
    # thrown south-east over what is beside it.
    for x0, y0, x1, y1 in ((ax0, ay0, ax1, ay1), (bx0, ay0, bx1, by1)):
        _shadow(image, [(x1, y0 + 10), (x1 + 44, y0 + 34), (x1 + 44, y1 + 30),
                        (x1, y1)], 60)
        rect(d, x0, y1, x1 - x0, front + 18 - y1, LIMESTONE)
        for y in range(y1 + 5, front + 18, 6):
            rect(d, x0, y, x1 - x0, 1, LIMESTONE_DARK)
        rect(d, x1 - 10, y1, 10, front + 18 - y1, LIMESTONE_DARK)
        cx = (x0 + x1) // 2
        rect(d, cx - 2, y1 + 8, 4, 12, (40, 34, 30))
        rect(d, x0, front + 16, x1 - x0, 2, (70, 64, 58))
        rect(d, x0 - 2, y0 - 2, x1 - x0 + 4, y1 - y0 + 4, (40, 34, 30))
    pixels = image.load()
    for x0, y0, x1, y1 in towers:
        for y in range(y0, y1):
            for x in range(x0, x1):
                pixels[x, y] = TRANSPARENT
    return image


def duomo_tower_roof_view(rng) -> dict:
    """The picture round the tower tops, as a placed object over the rows
    it was painted for."""
    from build_street_level import read_rows  # noqa: PLC0415

    rows = read_rows("duomo-roof-rows")
    return {"at": [0, 0], "image": "duomo_tower_view.png",
            "sprite": paint_tower_view(rows, rng), "under": rows}


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
    """A plank on trestles, liquor bottles standing along it."""
    rect(d, px, py + 8, TILE, 7, BACKROOM_WOOD)
    rect(d, px, py + 8, TILE, 2, shade(BACKROOM_WOOD, 30))
    for i, bx in enumerate((1, 5, 9, 13)):
        colour = LIQUORS[i % len(LIQUORS)]
        tall = i % 2 == 0
        top = py + (1 if tall else 3)
        rect(d, px + bx, top + 2, 3, py + 8 - top - 2, colour)
        rect(d, px + bx + 1, top, 1, 2, colour)  # the neck
        rect(d, px + bx + 1, top - 1, 1, 1, CORK)
        rect(d, px + bx, top + 4, 3, 2, (214, 204, 176))  # the label
        rect(d, px + bx, top + 2, 1, 2, shade(colour, 50))


# Wine and spirits: bottle glass, and what is in the clear ones.
LIQUORS = [(146, 92, 34), (196, 188, 170), (58, 104, 56), (120, 30, 36),
           (176, 130, 50)]
WINE_GLASS = [(40, 72, 40), (70, 24, 30), (34, 58, 34)]
CORK = (150, 110, 70)
WICKER = (158, 118, 62)
WICKER_DARK = (104, 74, 40)
DEMIJOHN_GLASS = (48, 98, 60)


def paint_demijohn(d, px, py):
    """A big wine demijohn, green glass in a wicker basket up to its
    shoulders, corked."""
    rect(d, px + 3, py + 14, 10, 2, (30, 26, 24))  # its shadow
    rect(d, px + 7, py, 2, 1, CORK)
    rect(d, px + 7, py + 1, 2, 3, DEMIJOHN_GLASS)  # the neck
    for dy, left, width in ((4, 5, 6), (5, 3, 10), (6, 2, 12), (7, 2, 12),
                            (8, 2, 12), (9, 2, 12), (10, 2, 12),
                            (11, 2, 12), (12, 2, 12), (13, 3, 10),
                            (14, 4, 8)):
        glass = dy < 8
        rect(d, px + left, py + dy, width, 1,
             DEMIJOHN_GLASS if glass else WICKER)
        if not glass:  # the weave
            for x in range(left + (dy % 2), left + width, 2):
                rect(d, px + x, py + dy, 1, 1, WICKER_DARK)
    rect(d, px + 4, py + 5, 1, 3, (130, 186, 130))  # the glass shines


def paint_wine_rack(d, px, py):
    """A wooden rack of wine bottles lying down, their bottoms out."""
    rect(d, px, py + 1, TILE, 14, shade(BACKROOM_WOOD, -30))
    rect(d, px, py + 1, TILE, 1, shade(BACKROOM_WOOD, 20))
    rect(d, px, py + 14, TILE, 1, BACKROOM_WOOD)
    for row, by in enumerate((3, 8)):
        for column, bx in enumerate((1, 6, 11)):
            glass = WINE_GLASS[(row + column) % len(WINE_GLASS)]
            rect(d, px + bx, py + by, 4, 4, glass)
            rect(d, px + bx + 1, py + by + 1, 1, 1, shade(glass, 60))
        rect(d, px, py + by + 4, TILE, 1, BACKROOM_WOOD)  # the shelf


def paint_liquor_crate(d, px, py):
    """An open crate of spirits, the bottles' necks sticking out."""
    for i, bx in enumerate((2, 6, 10)):
        colour = LIQUORS[(i + 1) % len(LIQUORS)]
        rect(d, px + bx, py + 3, 3, 6, colour)
        rect(d, px + bx + 1, py + 1, 1, 2, colour)
        rect(d, px + bx + 1, py, 1, 1, (170, 40, 40) if i == 1 else CORK)
        rect(d, px + bx, py + 3, 1, 2, shade(colour, 50))
    rect(d, px + 1, py + 7, 14, 8, BACKROOM_WOOD)
    rect(d, px + 1, py + 7, 14, 2, shade(BACKROOM_WOOD, 28))
    rect(d, px + 2, py + 11, 12, 1, shade(BACKROOM_WOOD, -24))


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
        "G": paint_demijohn,
        "R": paint_wine_rack,
        "C": paint_liquor_crate,
    }
    # The floor goes under every glyph that is not wall or void; the door
    # covers its cell whole, the rest let it show.
    floored = ".*8KB:EGRC"
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




# The railcar is one object, not tiles: its grime runs across the grid. It
# is painted at the size of the run of `M` in the far platform's rows;
# test/levels/tile_atlas_test.dart fails if the rows stop agreeing.
RAILCAR_TILES = (34, 3)
TERMINI_RAILCAR_TILES = (42, 3)
TERMINI_WALL_SIGN_TILES = (10, 2)
TERMINI_PLATFORM_SIGN_TILES = (3, 2)
STATION_SIGN_TILES = (8, 1)
# Counted from the west end. The train faces east, like the locomotive
# inside it: its red tail is at the west end and its door at the back,
# like the train's own way in; the east end is the locomotive's nose.
RAILCAR_DOOR_TILE = 5
TERMINI_RAILCAR_DOOR_TILE = 4
# How far back from the east end the nose starts to slope.
RAILCAR_NOSE = 46


def paint_locomotive_nose(sprite: Image.Image) -> None:
    """Shapes the east end of the railcar into a streamlined nose, side
    on: the roof curving down into a long raked windscreen and a rounded
    front, the livery bands running on into it, a headlight low down and
    the skirt tucked under. Whatever the railcar painter put there -- the
    last windows, a roof vent -- is painted over."""
    width, height = sprite.size
    px = sprite.load()
    start = width - RAILCAR_NOSE
    skirt_top, skirt_bottom = height - 12, height - 6
    band_bottom = height - 17  # where the blue band starts

    def edge(y):
        """The front's outline at pixel row `y`: an ellipse's quarter from
        the roof down to the waist, then straight, then under the skirt."""
        if y <= band_bottom + 5:
            t = y / (band_bottom + 5)
            return start + (RAILCAR_NOSE - 2) * (1 - (1 - t) ** 2) ** 0.5
        return width - 2 - max(0, y - skirt_top)

    green = station.LIVERY_GREEN
    for y in range(skirt_bottom):
        e = edge(y)
        for x in range(start, width):
            if x > e:
                px[x, y] = TRANSPARENT
                continue
            if y < 9:
                colour = shade(green, -38)
            elif y < 16:
                colour = green
            elif y < band_bottom:
                colour = station.LIVERY_WHITE
            elif y < skirt_top:
                colour = station.LIVERY_BLUE
            else:
                colour = shade(station.LIVERY_WHITE, -64)
            if x >= int(e) - 1:
                colour = station.METAL_DARK  # the outline
            px[x, y] = colour + (255,)
    # The windscreen: a band of glass following the slope, with a glint.
    for y in range(4, 22):
        e = int(edge(y))
        for x in range(max(start, e - 13), e - 2):
            px[x, y] = station.GLASS + (255,)
        if 6 <= y <= 12:
            px[max(start, e - 9), y] = shade(station.GLASS, 40) + (255,)
    # The pillar between the windscreen and the side window behind it.
    for y in range(9, 22):
        e = int(edge(y))
        px[max(start, e - 14), y] = station.METAL_DARK + (255,)
    # The same years of grime as the rest of the flank, run down the nose.
    rng = random.Random(SEED + 2)
    for _ in range(14):
        x = start + rng.randrange(RAILCAR_NOSE - 16)
        y0, length = rng.randrange(16, band_bottom - 4), rng.randint(3, 8)
        colour = rng.choice(((166, 160, 146), (146, 140, 126),
                             (176, 170, 156)))
        for y in range(y0, min(y0 + length, skirt_top)):
            if x < int(edge(y)) - 3:
                px[x, y] = colour + (255,)
    # The headlight, low on the front, and the coupler cover under it.
    for y in range(band_bottom - 3, band_bottom):
        e = int(edge(y))
        for x in range(e - 5, e - 2):
            px[x, y] = (250, 238, 180, 255)
    for y in range(skirt_top, skirt_top + 3):
        e = int(edge(y))
        for x in range(e - 4, e - 1):
            px[x, y] = station.METAL_DARK + (255,)


def station_railcar_sprite(tiles, door_tile, open_door: bool) -> Image.Image:
    """The intact train, with its red tail west and streamlined nose east."""
    width, height = (n * TILE for n in tiles)
    sprite = Image.new("RGBA", (width, height), TRANSPARENT)
    station.paint_railcar(
        ImageDraw.Draw(sprite), random.Random(SEED + 1),
        (0, 0, width, height), wrecked=False,
        door_x=door_tile * TILE, open_door=open_door,
    )
    paint_locomotive_nose(sprite)
    return sprite


# The blue of the name boards of every Italian station, and their white.
SIGN_BLUE = (22, 68, 142)
SIGN_BLUE_DARK = (12, 38, 86)
SIGN_BLUE_LIGHT = (44, 96, 172)
SIGN_WHITE = (238, 241, 236)
SIGN_POST = (92, 96, 104)


def paint_name_board(d, x, y, w, h, text, scale):
    """A station's name board: blue, a white rule inset along its edge and
    the name in white capitals in the middle, as on every platform in
    Italy, with a darker lip along the bottom."""
    rect(d, x, y, w, h, SIGN_BLUE_DARK)
    rect(d, x + 1, y + 1, w - 2, h - 2, SIGN_BLUE)
    rect(d, x + 1, y + 1, w - 2, 1, SIGN_BLUE_LIGHT)
    rect(d, x + 2, y + 2, w - 4, 1, SIGN_WHITE)
    rect(d, x + 2, y + h - 3, w - 4, 1, SIGN_WHITE)
    rect(d, x + 2, y + 2, 1, h - 4, SIGN_WHITE)
    rect(d, x + w - 3, y + 2, 1, h - 4, SIGN_WHITE)
    width = text_width(text) * scale
    paint_text(d, x + (w - width) // 2, y + (h - 5 * scale) // 2, text,
               SIGN_WHITE, scale=scale)


def termini_wall_sign() -> Image.Image:
    """ROMA TERMINI, high on the back wall over the train: a long board
    bolted to the wall on four brackets, its shadow under it."""
    width, height = (n * TILE for n in TERMINI_WALL_SIGN_TILES)
    sprite = Image.new("RGBA", (width, height), TRANSPARENT)
    d = ImageDraw.Draw(sprite)
    top, board = 3, 26
    rect(d, 2, top + board, width - 4, 2, (60, 56, 50, 140))  # its shadow
    for bx in (10, width // 3, 2 * width // 3, width - 12):
        rect(d, bx, top - 3, 2, 4, SIGN_POST)
    paint_name_board(d, 0, top, width, board, "ROMA TERMINI", 3)
    return sprite


def termini_platform_sign() -> Image.Image:
    """ROMA on its two posts at the edge of the platform: the board stands
    a tile above the cells its posts are in, in front of the train."""
    width, height = (n * TILE for n in TERMINI_PLATFORM_SIGN_TILES)
    sprite = Image.new("RGBA", (width, height), TRANSPARENT)
    d = ImageDraw.Draw(sprite)
    for post in (6, width - 8):
        rect(d, post, 10, 2, height - 12, SIGN_POST)
        rect(d, post, 10, 1, height - 12, shade(SIGN_POST, 30))
        rect(d, post - 1, height - 3, 4, 2, (40, 40, 44))  # its foot
    paint_name_board(d, 1, 0, width - 2, 19, "ROMA", 2)
    rect(d, 3, height - 2, width - 6, 2, (30, 30, 34, 110))  # its shadow
    return sprite


def paint_stairs_up(d, room, x, y):
    """The foot of a flight going up, `D` at Termini: the steps climb away
    through the front wall, each one higher and so nearer the light than the
    one before, between two handrails, under the green plate with the arrow
    up. Molfetta's go down into a dark well (build_station.paint_stairs)."""
    px, py = x * TILE, y * TILE
    glyph = room.at(x, y)
    first = room.at(x - 1, y) != glyph
    last = room.at(x + 1, y) != glyph
    rect(d, px, py, TILE, TILE, (70, 68, 64))
    for i, sy in enumerate(range(py + 4, py + TILE, 3)):
        tread = shade((118, 114, 106), 16 * i)
        rect(d, px, sy, TILE, 1, shade(tread, -46))  # the riser's edge
        rect(d, px, sy + 1, TILE, 2, tread)
    rect(d, px, py, TILE, 4, (40, 62, 48))  # the plate over the flight
    rect(d, px, py, TILE, 1, (78, 106, 84))
    if first:  # the arrow up, one half of it per cell
        for i in range(4):
            rect(d, px + 12 + i, py + 3 - i, 1, 1 + i, (232, 232, 220))
    elif last:
        for i in range(4):
            rect(d, px + i, py + i, 1, 4 - i, (232, 232, 220))
    for side, there in ((0, first), (TILE - 2, last)):
        if there:
            rect(d, px + side, py + 4, 2, TILE - 4, station.METAL_DARK)
            rect(d, px + side, py + 4, 2, 2, station.METAL_LIGHT)


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
        rule("ground", "=Tno",
             [platform(0, False), platform(1, False),
              platform(0, True), platform(1, True)],
             [parity_key(), first_row_key("=", 0, "eq")]),
        # Litter lies on the platform if it is near it, on the hall floor
        # if it is not: the baker drew the line two rows below the edge.
        rule("ground", ":",
             [hall(0), hall(1), platform(0, False), platform(1, False)],
             [parity_key(), first_row_key("=", 2, "le")]),
        rule("ground", "DP", [hall(0), hall(1)], [parity_key()]),
        rule("structures", "WlrQ", wall,
             [neighbour_key(0, -1, "WlrQ"), pattern_key(7, 5, 9)]),
        rule("structures", ":", [litter]),
        rule("structures", "D", ends(station.paint_stairs, "D"),
             [neighbour_key(-1, 0, "D"), neighbour_key(1, 0, "D")]),
    ]
    # Termini paints its rows with these rules too, and has no side walls.
    for right in (False, True):
        edge = atlas.bucket(lambda r=right: tile_of(
            lambda d: paint_side_edge(d, 0, 0, r)), 1)
        rules.append(rule("foreground", "-,M=TnD:P",
                          [[], edge], [neighbour_key(1 if right else -1,
                                                     0, "x")]))
    rules += side_walls(atlas)
    rules.append(rule("foreground", "T", ends(station.paint_bench, "T"),
                      [neighbour_key(-1, 0, "T"), neighbour_key(1, 0, "T")]))
    rules.append(rule("foreground", "n",
                      [atlas.bucket(lambda b=beam: tile_of(
                          lambda d: station.paint_post(d, Neighbourhood(
                              "n", lambda x, y, b=b: "n"
                              if (x == 1 and b) else "."), 0, 0)), 1)
                       for beam in (False, True)],
                      [neighbour_key(1, 0, "n")]))

    def station_sign(text: str, broken: bool) -> Image.Image:
        """A weathered Italian railway name board.

        The two halves still identify Molfetta together: grime has hidden
        MOLF on the west board, while the east board has lost its ETTA end.
        """
        width, height = (n * TILE for n in STATION_SIGN_TILES)
        sprite = Image.new("RGBA", (width, height), TRANSPARENT)
        d = ImageDraw.Draw(sprite)
        blue = (26, 78, 151)
        blue_dark = (14, 45, 93)
        blue_light = (48, 104, 181)
        white = (235, 239, 232)

        if broken:
            # The metal tears away directly after MOLF: there is no intact
            # blue gap that could have held the missing letters.
            d.polygon(
                [(1, 1), (39, 1), (43, 4), (39, 7), (44, 10),
                 (40, 14), (1, 14)],
                fill=blue,
            )
            d.line([(1, 1), (39, 1), (43, 4)], fill=white, width=1)
            d.line([(1, 14), (40, 14)], fill=white, width=1)
            d.line([(1, 1), (1, 14)], fill=white, width=1)
            d.line([(39, 2), (36, 7), (42, 10), (38, 14)],
                   fill=blue_dark, width=2)
            d.polygon([(48, 3), (60, 2), (57, 7), (46, 8)],
                      fill=blue_dark)
            d.polygon([(52, 4), (58, 3), (56, 5)], fill=blue_light)
            d.polygon([(69, 10), (78, 8), (75, 14), (66, 14)],
                      fill=blue)
            paint_text(d, 9, 3, text, white, scale=2)
        else:
            rect(d, 0, 0, width, height, blue_dark)
            rect(d, 1, 1, width - 2, height - 2, white)
            rect(d, 2, 2, width - 4, height - 4, blue)
            paint_text(d, width - 39, 3, text, white, scale=2)

            # Thick soot, rust and rain streaks conceal the missing MOLF.
            grime = (55, 58, 52)
            soot = (31, 35, 34)
            rust = (101, 70, 43)
            d.polygon([(2, 2), (83, 2), (88, 5), (84, 8), (89, 13),
                       (2, 13)], fill=grime)
            d.polygon([(2, 2), (69, 2), (83, 6), (76, 9), (24, 7)],
                      fill=soot)
            d.line([(12, 3), (12, 13)], fill=rust, width=2)
            d.line([(55, 2), (58, 12)], fill=rust, width=1)
            d.line([(82, 4), (85, 13)], fill=soot, width=2)
            d.point([(18, 10), (63, 5), (86, 11)], fill=(142, 129, 100))

        return sprite

    return {
        "void": "#060608",
        "voidGlyph": "x",
        "rules": rules,
        "objects": [
            {"glyph": "M", "image": "station_railcar.png",
             "tiles": list(RAILCAR_TILES),
             "sprite": station_railcar_sprite(
                 RAILCAR_TILES, RAILCAR_DOOR_TILE, False),
             "whenOpen": "station_railcar_open.png",
             "openSprite": station_railcar_sprite(
                 RAILCAR_TILES, RAILCAR_DOOR_TILE, True)},
            {"glyph": "l", "image": "station_sign_etta.png",
             "tiles": list(STATION_SIGN_TILES),
             "sprite": station_sign("ETTA", broken=False)},
            {"glyph": "r", "image": "station_sign_molf.png",
             "tiles": list(STATION_SIGN_TILES),
             "sprite": station_sign("MOLF", broken=True)},
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
    rules.append(rule("structures", "Q", buckets, pieces=up))
    rules.append(rule("structures", "N", randomly(paint_notice_board)))
    buckets, up = lean(lambda i: lambda d, px, py:
                       paint_barracks_shelves(d, rng, px, py))
    rules.append(rule("structures", "S", buckets, pieces=up))
    buckets, up = lean(lambda i: paint_barracks_entrance)
    rules.append(rule("structures", "E", buckets, pieces=up))
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
    rules.append(rule("structures", "A", buckets, pieces=up))
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
# Mario's red wool blanket, folded square; Luigi's green checked one,
# kicked about.
TR_MARIO_BLANKET = (160, 40, 36)
TR_LUIGI_BLANKET = (58, 104, 58)
TR_LUIGI_CHECK = (170, 196, 150)
TR_PILLOW = (214, 208, 190)
TR_BAG = (22, 24, 26)
TR_BAG_MID = (40, 43, 47)
TR_BAG_LIGHT = (96, 102, 110)
TR_BAG_TIE = (214, 176, 40)
TR_OUTLINE = (20, 18, 20)
TR_GLASS_GREEN = (40, 110, 58)
TR_GLASS_BROWN = (120, 68, 22)
TR_GLASS_CLEAR = (178, 204, 206)
TR_LABEL_RED = (182, 40, 40)
TR_LABEL_CREAM = (232, 220, 180)
TR_STAIN = (72, 58, 48)
TR_CAN_RED = (178, 40, 38)
TR_CAN_SILVER = (184, 186, 190)
TR_PAPER = (226, 220, 200)
TR_PAPER_SHADE = (178, 170, 150)
TR_INK = (62, 58, 60)
TR_CRATE = (118, 84, 48)
TR_CRATE_DARK = (78, 54, 30)
TR_AMMO_BOX = (70, 86, 52)
TR_BRASS = (206, 164, 70)
TR_BOOK_COVERS = ((122, 38, 34), (40, 64, 104), (58, 86, 52),
                  (108, 76, 40), (70, 44, 78))
TR_GILT = (214, 180, 86)
TR_PAGES = (236, 228, 204)
TR_PAGE_EDGE = (196, 186, 160)
TR_WINDSCREEN_FRAME = (36, 40, 46)
TR_ROWS = "train-interior-rows"
TR_MAP_TABLE_TILES = (4, 3)
TR_WEAPON_TABLE_TILES = (3, 1)
TR_FOOD_TABLE_TILES = (3, 1)
TR_CLOTH = (234, 226, 206)
TR_CLOTH_SHADE = (206, 196, 172)
TR_CLOTH_STRIPE = (178, 44, 40)
TR_HAM_RIND = (150, 84, 44)
TR_HAM_DARK = (168, 58, 62)
TR_BONE = (238, 232, 214)
TR_TWINE = (214, 200, 160)
TR_BOARD = (176, 128, 74)
TR_HAM = (214, 110, 112)
TR_HAM_FAT = (246, 226, 214)
TR_SALAMI = (140, 40, 44)
TR_SALAMI_FAT = (238, 214, 206)
TR_SALAMI_SKIN = (196, 190, 176)
TR_CHEESE = (240, 204, 96)
TR_CHEESE_RIND = (176, 124, 46)
TR_BREAD = (196, 138, 66)
TR_BREAD_CRUST = (138, 84, 34)
TR_CRUMB = (240, 220, 170)
TR_WINE = (96, 20, 34)
# The map of Europe: parchment land, faded blue sea, ink coasts.
TR_MAP_LAND = (222, 196, 120)
TR_MAP_SEA = (138, 166, 170)
TR_MAP_COAST = (150, 114, 58)
TR_NEEDLE = (186, 30, 28)
TR_GUN = (58, 60, 66)
TR_GUN_LIGHT = (128, 132, 140)
TR_SHELL_RED = (176, 36, 32)
TR_TABLE_DARK = (92, 62, 36)
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


def paint_train_end_wall(d, px, py, open_above=False, open_below=False):
    """An end wall of a coach, running north-south, seen from above: the
    top of the bulkhead as one band down the tile, lit on one edge and in
    shadow on the other, so that tile after tile it reads as a single
    wall. Where the aisle cuts through it the band is capped."""
    rect(d, px, py, TILE, TILE, TR_METAL_DARK)
    rect(d, px + 2, py, 12, TILE, TR_SHELL)
    rect(d, px + 2, py, 2, TILE, TR_SHELL_LIGHT)
    rect(d, px + 12, py, 2, TILE, TR_SHELL_DARK)
    if open_above:
        rect(d, px + 2, py, 12, 2, TR_SHELL_LIGHT)
    if open_below:
        rect(d, px + 2, py + 12, 12, 4, TR_SHELL_DARK)
        rect(d, px + 2, py + 11, 12, 1, TR_SHELL)


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


# Mario's clothes, as he wears them: a red flannel shirt and jeans.
TR_SHIRT = (156, 44, 40)
TR_SHIRT_DARK = (104, 28, 28)
TR_JEANS = (60, 86, 136)
TR_JEANS_DARK = (40, 58, 96)
# Luigi's: a white vest gone grey and olive shorts.
TR_VEST = (226, 222, 206)
TR_VEST_SHADE = (184, 178, 160)
TR_SHORTS = (96, 106, 56)
TR_SHORTS_DARK = (64, 72, 38)
TR_CASE_BLUE = (48, 64, 100)
TR_CASE_LINING = (206, 186, 150)
TR_SOCK_BLUE = (70, 96, 150)


# The clothes are drawn pixel by pixel from these: `o` the outline, then
# the colours each one names in its palette; `.` is left alone.
SHIRT = (
    "......oo......",
    "...oooooooo...",
    "..orrrRRrrro..",
    ".orrrrRRrrrro.",
    "orrorrrRrrorro",
    "oRRoRRRRRRoRRo",
    "orrorrrRrrorro",
    "oRRoRRRRRRoRRo",
    "orrorrrRrrorro",
    "oRRorrrRrroRRo",
    "oooorrrRrroooo",
    "...oRRRRRRo...",
    "...oooooooo...",
)
JEANS = (
    "....oo...",
    "...oooo..",
    "ooooooooo",
    "oBBBBBBBo",
    "obbbbbbbo",
    "obbbobbbo",
    "obcbobcbo",
    "obcbobcbo",
    "obbbobbbo",
    "obcbobcbo",
    "obbbobbbo",
    "oBBBoBBBo",
    "ooooooooo",
)
VEST = (
    "...oo.oo...",
    "...ow.wo...",
    "..oow.woo..",
    ".owwwowwwo.",
    "owwwwwwwwwo",
    "owwwwwswwwo",
    "owswwwwwwwo",
    "owwwwwwwswo",
    "owwwswwwwwo",
    "owwwwwwwwwo",
    "osssssssss o".replace(" ", ""),
    "ooooooooooo",
)
SHORTS = (
    "ooooooooooo",
    "odddddddddo",
    "ogggggggggo",
    "ogggsdgggso",
    "ogggo.ogggo",
    "ogggo.ogggo",
    "odddo.odddo",
    "ooooo.ooooo",
)
BRIEFS = (
    "ooooooooo",
    "osssssssso"[:9],
    "owwwwwwwo",
    ".owwwwwo.",
    "..owwwo..",
    "...ooo...",
)
BOXERS = (
    "ooooooooo",
    "osssssssso"[:9],
    "obwbwbwbo",
    "obwbwbwbo",
    "obwbooobo"[:9],
    "oooo.oooo",
)
SOCK = (
    "oooo..",
    "oxxo..",
    "owwo..",
    "owwo..",
    "owwooo",
    "owwwwo",
    "oooooo",
)


def _pattern(d, x, y, rows, palette, flip=False):
    """Draws `rows` with its top left corner at (x, y); `flip` mirrors it
    top to bottom, a garment dropped the other way up."""
    for dy, row in enumerate(reversed(rows) if flip else rows):
        for dx, key in enumerate(row):
            if key == ".":
                continue
            colour = TR_OUTLINE if key == "o" else palette[key]
            rect(d, x + dx, y + dy, 1, 1, colour)


def _shirt(d, x, y):
    _pattern(d, x, y, SHIRT, {"r": TR_SHIRT, "R": TR_SHIRT_DARK})


def _jeans(d, x, y):
    _pattern(d, x, y, JEANS, {"b": TR_JEANS, "B": TR_JEANS_DARK,
                              "c": shade(TR_JEANS, 26)})


def _vest(d, x, y, flip=False):
    _pattern(d, x, y, VEST, {"w": TR_VEST, "s": TR_VEST_SHADE}, flip)


def _shorts(d, x, y, flip=False):
    _pattern(d, x, y, SHORTS, {"g": TR_SHORTS, "d": TR_SHORTS_DARK,
                               "s": shade(TR_SHORTS, 24)}, flip)


def _pants(d, x, y, striped):
    if striped:
        _pattern(d, x, y, BOXERS, {"s": shade(TR_SOCK_BLUE, -30),
                                   "b": TR_SOCK_BLUE, "w": TR_VEST})
    else:
        _pattern(d, x, y, BRIEFS, {"s": TR_VEST_SHADE, "w": TR_VEST})


def _sock(d, x, y, band):
    _pattern(d, x, y, SOCK, {"x": band, "w": TR_VEST_SHADE})


def paint_train_wardrobe(d, px, py, width):
    """Mario's wardrobe, three tiles long against the wall: a bare rail on
    two uprights, and hung on it his clothes, the red flannel shirts and
    the jeans he wears."""
    w = width * TILE
    for ux in (px + 1, px + w - 3):
        rect(d, ux - 1, py + 1, 4, 14, TR_OUTLINE)
        rect(d, ux, py + 2, 2, 12, TR_METAL)
        rect(d, ux - 2, py + 13, 6, 3, TR_OUTLINE)  # its foot
        rect(d, ux - 1, py + 14, 4, 1, TR_METAL_DARK)
    rect(d, px + 1, py + 1, w - 2, 3, TR_OUTLINE)
    rect(d, px + 2, py + 2, w - 4, 1, TR_METAL_LIGHT)  # the rail
    if width == 1:
        _shirt(d, px + 1, py + 2)
        return
    _shirt(d, px + 4, py + 2)
    _jeans(d, px + 19, py + 2)
    _shirt(d, px + 29, py + 2)


def paint_train_suitcases(d, px, py, width):
    """Mario's two suitcases against the wall: a brown leather one lying
    flat, strapped shut, and beside it a blue hard case standing on its
    wheels, its handle down."""
    # the one lying flat, seen from above: lid, straps, the handle
    rect(d, px + 1, py + 3, 15, 12, TR_OUTLINE)
    rect(d, px + 2, py + 4, 13, 10, TR_LUGGAGE)
    rect(d, px + 2, py + 4, 13, 1, shade(TR_LUGGAGE, 30))
    rect(d, px + 2, py + 12, 13, 2, shade(TR_LUGGAGE, -24))  # its side
    for sx in (px + 5, px + 11):
        rect(d, sx, py + 4, 2, 10, shade(TR_LUGGAGE, -40))
        rect(d, sx, py + 8, 2, 1, TR_SAFETY)  # the buckles
    rect(d, px + 6, py + 14, 5, 2, TR_OUTLINE)  # the handle
    if width == 1:
        return
    # the one standing, taller than it is wide, ribbed
    x = px + TILE + 3
    rect(d, x - 1, py, 12, 16, TR_OUTLINE)
    rect(d, x, py + 1, 10, 13, TR_CASE_BLUE)
    for rx in range(x + 2, x + 9, 3):
        rect(d, rx, py + 3, 1, 10, shade(TR_CASE_BLUE, 26))
    rect(d, x, py + 1, 10, 1, shade(TR_CASE_BLUE, 40))
    rect(d, x + 3, py + 1, 4, 2, TR_METAL_LIGHT)  # the handle, pushed down
    rect(d, x, py + 14, 3, 2, TR_METAL_DARK)  # the wheels
    rect(d, x + 7, py + 14, 3, 2, TR_METAL_DARK)


def paint_train_open_suitcase(d, px, py, width):
    """One of Luigi's suitcases, left open on the floor: the lid thrown
    back against the wall, the lining showing, and his clothes spilling
    over the side."""
    w = width * TILE
    rect(d, px + 1, py, w - 2, 5, TR_OUTLINE)  # the lid, open
    rect(d, px + 2, py + 1, w - 4, 3, shade(TR_LUGGAGE, -20))
    rect(d, px + 3, py + 2, w - 6, 1, TR_CASE_LINING)
    rect(d, px + 1, py + 5, w - 2, 10, TR_OUTLINE)  # the case
    rect(d, px + 2, py + 6, w - 4, 8, TR_CASE_LINING)
    rect(d, px + 2, py + 13, w - 4, 1, shade(TR_CASE_LINING, -40))
    if width == 1:
        _vest(d, px + 2, py + 3)
        _sock(d, px + 9, py + 9, TR_LABEL_RED)
        return
    _vest(d, px + 2, py + 3)
    _shorts(d, px + 12, py + 6)
    _pants(d, px + 22, py + 5, striped=True)
    _sock(d, px + 24, py + 9, TR_SOCK_BLUE)  # spilling over the side


def paint_train_luigi_clothes(d, rng, px, py):
    """Luigi's clothes, thrown on the floor where he took them off: his
    vest, his shorts, or both in a heap."""
    kind = rng.randrange(3)
    flip = rng.random() < 0.5
    if kind == 0:
        _vest(d, px + rng.randrange(0, 5), py + rng.randrange(0, 4), flip)
    elif kind == 1:
        _shorts(d, px + rng.randrange(0, 5), py + rng.randrange(1, 8), flip)
    else:
        _vest(d, px, py, flip)
        _shorts(d, px + 5, py + 8)


def paint_train_underwear(d, rng, px, py):
    """Underpants and socks about the floor, never in pairs where they
    should be."""
    kind = rng.randrange(3)
    x, y = px + rng.randrange(0, 6), py + rng.randrange(1, 9)
    if kind == 0:
        _pants(d, x, y, striped=rng.random() < 0.5)
    elif kind == 1:
        _sock(d, px + rng.randrange(0, 4), py + rng.randrange(0, 3),
              rng.choice((TR_LABEL_RED, TR_SOCK_BLUE)))
        _sock(d, px + 9, py + 8, TR_LABEL_RED)
    else:
        _pants(d, px, py + 1, striped=False)
        _sock(d, px + 10, py + 8, TR_SOCK_BLUE)


def paint_train_control(d, rng, px, py):
    rect(d, px + 1, py + 2, 14, 12, TR_CONTROL)
    rect(d, px + 2, py + 3, 12, 4, TR_CONTROL_LIGHT)
    for _ in range(4):
        colour = rng.choice(((178, 52, 42), (68, 146, 82), (214, 176, 54)))
        rect(d, px + rng.randrange(3, 13), py + rng.randrange(8, 12), 2, 2,
             colour)


# Europe as the map on the table shows it, in (longitude, latitude): the
# mainland from Gibraltar round the coasts to the edge of the sheet in the
# east, and the islands big enough to show. The Black Sea is drawn over
# the land as water. Coarse on purpose: at a degree a pixel, this is all
# of the coast a map this size can hold.
EUROPE_MAINLAND = (
    (-5.6, 36.0), (-6.3, 36.8), (-7.4, 37.2), (-8.9, 37.0), (-8.8, 38.7),
    (-9.5, 39.4), (-8.7, 41.2), (-8.9, 42.9), (-9.3, 43.0), (-7.7, 43.7),
    (-5.8, 43.6), (-3.8, 43.4), (-1.8, 43.4), (-1.2, 44.7), (-1.1, 46.2),
    (-2.2, 47.2), (-4.7, 48.0), (-4.3, 48.7), (-1.6, 48.7), (-1.9, 49.7),
    (-1.1, 49.4), (0.2, 49.7), (1.6, 50.9), (3.2, 51.3), (4.0, 51.9),
    (4.7, 52.9), (6.8, 53.4), (8.5, 53.6), (8.6, 54.9), (8.1, 55.5),
    (8.6, 57.1), (10.6, 57.7), (10.3, 56.5), (10.9, 56.3), (10.0, 55.2),
    (10.9, 54.4), (12.2, 54.2), (14.2, 53.9), (16.0, 54.3), (18.7, 54.8),
    (19.9, 54.4), (21.1, 55.6), (21.0, 56.8), (22.6, 57.8), (24.2, 57.1),
    (23.5, 58.6), (24.4, 59.4), (28.0, 59.5), (30.2, 59.9), (27.0, 60.5),
    (22.9, 59.9), (21.4, 60.8), (21.5, 61.7), (21.5, 63.2), (25.4, 65.0),
    (24.2, 65.8), (22.1, 65.6), (21.0, 64.5), (19.3, 63.5), (17.9, 62.6),
    (17.2, 61.3), (17.3, 60.6), (18.8, 60.1), (18.1, 59.3), (16.7, 57.9),
    (16.4, 56.6), (15.6, 56.2), (14.3, 55.5), (12.9, 55.4), (12.6, 56.2),
    (11.9, 57.7), (11.2, 58.9), (10.6, 59.9), (9.6, 59.0), (8.0, 58.1),
    (5.6, 58.8), (5.2, 60.4), (5.0, 61.9), (6.5, 62.6), (8.0, 63.2),
    (10.4, 63.4), (11.3, 64.4), (12.6, 65.9), (14.4, 67.3), (16.0, 68.4),
    (18.9, 69.6), (23.7, 70.6), (25.8, 71.1), (28.5, 70.9), (31.0, 70.3),
    (33.0, 69.3), (36.0, 69.0), (41.0, 67.7), (46.0, 68.0), (46.0, 36.6),
    (36.2, 36.6), (34.6, 36.8), (32.5, 36.1), (30.6, 36.8), (29.1, 36.6),
    (27.3, 37.0), (26.3, 38.3), (26.6, 39.5), (26.2, 40.0), (26.1, 40.6),
    (24.4, 40.9), (22.9, 40.6), (22.6, 39.8), (23.1, 39.0), (24.0, 38.2),
    (23.0, 38.0), (22.5, 37.0), (21.7, 36.8), (21.1, 37.8), (21.3, 38.4),
    (20.2, 39.5), (19.4, 40.3), (19.5, 41.8), (18.5, 42.4), (16.4, 43.5),
    (15.2, 44.2), (14.5, 45.3), (13.7, 45.6), (12.3, 45.4), (12.3, 44.5),
    (13.6, 43.5), (14.2, 42.4), (16.2, 41.9), (15.9, 41.5), (16.9, 41.1),
    (18.5, 40.1), (18.4, 39.8), (17.1, 40.5), (16.5, 39.7), (17.1, 39.0),
    (16.1, 38.0), (15.6, 38.0), (15.8, 38.9), (15.6, 40.0), (14.3, 40.8),
    (13.0, 41.2), (12.2, 41.7), (11.1, 42.4), (10.5, 43.0), (10.2, 43.9),
    (8.9, 44.4), (7.5, 43.8), (6.0, 43.1), (4.8, 43.4), (3.2, 43.1),
    (3.2, 42.3), (2.2, 41.4), (0.9, 41.0), (-0.3, 39.5), (0.2, 38.8),
    (-0.5, 38.3), (-0.8, 37.6), (-2.1, 36.7), (-4.4, 36.7),
)
EUROPE_ISLANDS = (
    # Great Britain.
    ((-5.7, 50.1), (-3.0, 50.7), (1.4, 51.2), (1.7, 52.6), (0.3, 53.1),
     (-0.1, 54.0), (-1.4, 55.0), (-2.0, 55.8), (-2.4, 57.1), (-1.8, 57.5),
     (-3.3, 58.6), (-5.0, 58.6), (-5.7, 57.5), (-5.6, 56.3), (-4.9, 55.7),
     (-5.1, 54.8), (-3.2, 54.9), (-3.0, 53.4), (-4.6, 53.3), (-4.3, 52.3),
     (-5.2, 51.8), (-3.1, 51.4), (-4.2, 51.1)),
    # Ireland.
    ((-6.0, 52.2), (-6.2, 53.3), (-6.0, 54.1), (-5.9, 55.2), (-7.3, 55.3),
     (-8.4, 55.1), (-8.6, 54.3), (-10.0, 54.2), (-9.9, 53.0), (-9.4, 52.6),
     (-10.3, 51.9), (-9.5, 51.5), (-8.2, 51.8)),
    # Sicily, Sardinia, Corsica, Crete.
    ((12.4, 37.8), (13.4, 38.2), (15.6, 38.3), (15.1, 37.1), (14.3, 37.0),
     (12.6, 37.6)),
    ((8.4, 39.0), (9.0, 39.0), (9.7, 39.2), (9.8, 41.0), (9.3, 41.2),
     (8.2, 40.9), (8.4, 39.8)),
    ((8.6, 41.4), (9.4, 41.5), (9.5, 43.0), (8.7, 42.6)),
    ((23.5, 35.4), (26.3, 35.3), (26.1, 35.0), (24.0, 35.1)),
)
EUROPE_BLACK_SEA = (
    (28.0, 41.6), (28.7, 44.0), (29.7, 45.2), (30.7, 46.5), (32.0, 46.5),
    (33.5, 46.0), (32.5, 45.4), (33.5, 44.4), (35.3, 44.9), (36.5, 45.3),
    (37.5, 44.7), (38.5, 44.3), (39.8, 43.5), (41.6, 41.6), (41.0, 41.0),
    (39.5, 41.0), (36.0, 41.7), (35.0, 42.0), (33.0, 42.0), (31.3, 41.2),
    (29.1, 41.2),
)
EUROPE_BOUNDS = (-10.8, 35.0, 40.5, 71.8)  # west, south, east, north


# Nordkapp, as longitude and latitude.
NORTH_CAPE = (25.78, 71.17)


def paint_europe(width, height):
    """The map itself, `width` by `height` pixels: land, sea and the coast
    inked round the land, nothing drawn on it.
    Drawn four times over and brought down, so the coast is the shape of
    the real one and not of the polygon's corners."""
    scale = 4
    west, south, east, north = EUROPE_BOUNDS
    big = Image.new("RGB", (width * scale, height * scale), TR_MAP_SEA)
    draw = ImageDraw.Draw(big)

    def at(lon, lat):
        return ((lon - west) / (east - west) * width * scale,
                (north - lat) / (north - south) * height * scale)

    draw.polygon([at(*p) for p in EUROPE_MAINLAND], fill=TR_MAP_LAND)
    for island in EUROPE_ISLANDS:
        draw.polygon([at(*p) for p in island], fill=TR_MAP_LAND)
    draw.polygon([at(*p) for p in EUROPE_BLACK_SEA], fill=TR_MAP_SEA)
    small = big.resize((width, height), Image.BOX)
    sheet = Image.new("RGB", (width, height), TR_MAP_SEA)
    # Land where the pixel is more than half covered by it.
    half = (sum(TR_MAP_SEA) + sum(TR_MAP_LAND)) / 2
    land = [[sum(small.getpixel((x, y))) > half
             for x in range(width)] for y in range(height)]
    px = sheet.load()
    for y in range(height):
        for x in range(width):
            if not land[y][x]:
                continue
            coast = any(
                not (0 <= x + dx < width and 0 <= y + dy < height)
                or not land[y + dy][x + dx]
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            px[x, y] = TR_MAP_COAST if coast else TR_MAP_LAND
    return sheet


def paint_train_map_table(sprite):
    """The table in the middle of the locomotive, four tiles by three,
    with their map of Europe spread over it: the whole of it, from
    Portugal to the North Cape. Beside the map, a pencil and a compass."""
    d = ImageDraw.Draw(sprite)
    w, h = TR_MAP_TABLE_TILES[0] * TILE, TR_MAP_TABLE_TILES[1] * TILE
    # The table: a dark edge, the top, and its legs at the corners.
    rect(d, 0, h - 3, w, 3, TR_OUTLINE)
    for leg_x in (2, w - 5):
        rect(d, leg_x, h - 4, 3, 4, TR_METAL_DARK)
    rect(d, 0, 0, w, h - 3, TR_OUTLINE)
    rect(d, 1, 1, w - 2, h - 5, TR_WOOD)
    rect(d, 1, h - 5, w - 2, 1, shade(TR_WOOD, -34))
    rect(d, 2, 2, w - 4, 1, TR_WOOD_LIGHT)
    # The map, its shadow, a white margin and the sheet.
    mx, my, mw, mh = 4, 3, 44, h - 9
    rect(d, mx + 1, my + 1, mw, mh, shade(TR_WOOD, -50))
    rect(d, mx, my, mw, mh, TR_PAPER)
    sprite.paste(paint_europe(mw - 2, mh - 2), (mx + 1, my + 1))
    # A red X by the North Cape, where the two of them mean to end up,
    # drawn a little south of the tip so the coast still shows.
    west, south, east, north = EUROPE_BOUNDS
    cape_x = mx + 1 + round((NORTH_CAPE[0] - west) / (east - west)
                            * (mw - 2))
    cape_y = my + 1 + round((north - NORTH_CAPE[1]) / (north - south)
                            * (mh - 2))
    for i in range(-2, 3):
        rect(d, cape_x + i, cape_y + 2 + i, 1, 1, TR_LABEL_RED)
        rect(d, cape_x + i, cape_y + 2 - i, 1, 1, TR_LABEL_RED)
    # A pencil and a compass beside it.
    rect(d, 52, 6, 2, 12, TR_SAFETY)
    rect(d, 52, 18, 2, 2, TR_WOOD_LIGHT)
    rect(d, 52, 20, 2, 1, TR_OUTLINE)
    rect(d, 51, 26, 9, 9, TR_OUTLINE)
    rect(d, 52, 27, 7, 7, TR_METAL_LIGHT)
    rect(d, 53, 28, 5, 5, TR_PAPER)
    rect(d, 55, 28, 1, 2, TR_NEEDLE)
    rect(d, 55, 31, 1, 2, TR_OUTLINE)


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
    """A full black bin bag, as big as the tile, knotted with its yellow
    ties: lumpy with what is in it, creased between the lumps, and shiny
    where the lamps catch the plastic."""
    rect(d, px + 1, py + 14, 15, 2, TR_OUTLINE)  # its shadow
    lumps = ((2, 4, 12, 11), (0, 7, 16, 7), (1, 5, 14, 9))
    for bx, by, w, h in lumps:
        rect(d, px + bx, py + by - 1, w, h + 2, TR_OUTLINE)
    for bx, by, w, h in lumps:
        rect(d, px + bx + 1, py + by, w - 2, h, TR_BAG)
    # The lit side of each lump, its rim and the creases.
    rect(d, px + 2, py + 6, 5, 7, TR_BAG_MID)
    rect(d, px + 9, py + 6, 4, 6, TR_BAG_MID)
    rect(d, px + 7, py + 5, 1, 9, TR_OUTLINE)
    rect(d, px + 3, py + 6, 2, 1, TR_BAG_LIGHT)
    rect(d, px + 2, py + 7, 1, 4, TR_BAG_LIGHT)
    rect(d, px + 10, py + 6, 2, 1, TR_BAG_LIGHT)
    rect(d, px + 12, py + 7, 1, 2, TR_BAG_LIGHT)
    rect(d, px + 4, py + 12, 2, 1, TR_BAG_MID)
    # The neck gathered up and the knot, its two ties sticking out.
    rect(d, px + 5, py + 1, 6, 5, TR_OUTLINE)
    rect(d, px + 6, py + 2, 4, 3, TR_BAG_MID)
    rect(d, px + 7, py + 2, 1, 1, TR_BAG_LIGHT)
    rect(d, px + 3, py, 3, 2, TR_BAG_TIE)
    rect(d, px + 10, py, 3, 2, TR_BAG_TIE)
    rect(d, px + 6, py + 4, 4, 1, TR_BAG_TIE)


def paint_train_litter(d, rng, px, py):
    """What Luigi drinks, left where it was finished: a wine bottle, a
    beer or a clear one of grappa lying on its side, another standing or
    a crushed can, and the sticky ring the last drops left."""
    rect(d, px + rng.randrange(0, 5), py + rng.randrange(10, 13), 8, 3,
         TR_STAIN)

    def bottle(bx, by, glass, body, neck, label):
        """Lying left to right, the neck to the right, outlined."""
        rect(d, bx - 1, by - 1, body + 2, 7, TR_OUTLINE)
        rect(d, bx + body, by + 1, neck + 1, 3, TR_OUTLINE)
        rect(d, bx, by, body, 5, glass)
        rect(d, bx + body - 1, by + 1, 1, 3, glass)  # the shoulder
        rect(d, bx + body, by + 2, neck, 1, glass)
        rect(d, bx + body + neck - 1, by + 1, 1, 3, shade(glass, -45))
        rect(d, bx + 1, by + 1, body - 2, 1, shade(glass, 80))  # shine
        rect(d, bx, by + 4, body, 1, shade(glass, -40))
        if label:
            rect(d, bx + 2, by, 4, 5, label)
            rect(d, bx + 3, by + 2, 2, 1, TR_LABEL_RED)

    kind = rng.randrange(3)
    top = py + rng.randrange(1, 4)
    if kind == 0:  # wine, long and dark, its label cream
        bottle(px + 1, top, TR_GLASS_GREEN, 10, 4, TR_LABEL_CREAM)
    elif kind == 1:  # beer, shorter and brown
        bottle(px + 2, top, TR_GLASS_BROWN, 8, 3, TR_LABEL_CREAM)
    else:  # grappa, clear
        bottle(px + 1, top, TR_GLASS_CLEAR, 9, 4, TR_LABEL_RED)
    if rng.random() < 0.5:
        # Another standing up, seen from above: the round shoulder and
        # the mouth of its neck.
        sx, sy = px + rng.randrange(9, 12), py + rng.randrange(8, 11)
        glass = rng.choice((TR_GLASS_GREEN, TR_GLASS_BROWN))
        rect(d, sx, sy - 1, 4, 6, TR_OUTLINE)
        rect(d, sx - 1, sy, 6, 4, TR_OUTLINE)
        rect(d, sx, sy, 4, 4, glass)
        rect(d, sx + 1, sy + 1, 2, 2, shade(glass, -60))
        rect(d, sx, sy, 1, 1, shade(glass, 80))
    else:
        cx, cy = px + rng.randrange(9, 11), py + rng.randrange(9, 12)
        rect(d, cx - 1, cy - 1, 7, 6, TR_OUTLINE)
        rect(d, cx, cy, 5, 4, TR_CAN_RED)
        rect(d, cx, cy, 1, 4, TR_CAN_SILVER)
        rect(d, cx + 4, cy + 1, 1, 2, TR_CAN_SILVER)
        rect(d, cx + 1, cy + 1, 3, 1, shade(TR_CAN_RED, 45))


def paint_book_closed(d, bx, by, w, h, cover):
    """A hardback lying shut, seen from above: its cover, a darker spine
    down the left with two gilt bands, and the pages showing at the
    other three edges."""
    rect(d, bx - 1, by - 1, w + 2, h + 2, TR_OUTLINE)
    rect(d, bx, by, w, h, TR_PAGE_EDGE)
    rect(d, bx, by, w - 1, h - 1, cover)
    rect(d, bx, by, 2, h, shade(cover, -35))
    rect(d, bx, by + 1, 2, 1, TR_GILT)
    rect(d, bx, by + h - 3, 2, 1, TR_GILT)
    rect(d, bx + 2, by, w - 3, 1, shade(cover, 30))


def paint_book_open(d, bx, by, cover, rng):
    """A book open face up: two pages bowed into the spine, lines of print
    on them, the cover showing round the edge."""
    rect(d, bx - 1, by - 1, 14, 10, TR_OUTLINE)
    rect(d, bx, by, 12, 8, cover)
    rect(d, bx + 1, by, 5, 7, TR_PAGES)
    rect(d, bx + 6, by, 5, 7, shade(TR_PAGES, -10))
    rect(d, bx + 5, by, 2, 7, TR_PAGE_EDGE)  # the gutter
    for line in range(by + 1, by + 6):
        rect(d, bx + 1 + (line == by + 1), line, rng.randrange(2, 4), 1,
             TR_INK)
        rect(d, bx + 7, line, rng.randrange(2, 4), 1, TR_INK)


def paint_notebook(d, bx, by, rng):
    """A notebook of Mario's, open on squared paper, the notes in blue and
    a pencil across it."""
    rect(d, bx - 1, by - 1, 10, 12, TR_OUTLINE)
    rect(d, bx, by, 8, 10, TR_PAPER)
    rect(d, bx, by, 1, 10, (40, 40, 44))  # the spiral
    for line in range(by + 2, by + 9, 2):
        rect(d, bx + 2, line, rng.randrange(3, 6), 1, (48, 70, 140))
    rect(d, bx + 3, by + 7, 7, 1, (214, 170, 50))  # the pencil
    rect(d, bx + 9, by + 7, 1, 1, TR_INK)


def paint_train_papers(d, rng, px, py):
    """What Mario reads and writes, on the floor round his cot: a pile of
    hardbacks, a book left open, or his notebook with a loose sheet."""
    covers = list(TR_BOOK_COVERS)
    rng.shuffle(covers)
    kind = rng.choice((0, 0, 1, 2))  # mostly books
    if kind == 0:  # a pile, each book a little askew on the one below
        for i, (dx, dy) in enumerate(((2, 6), (3, 4), (2, 2))):
            paint_book_closed(d, px + dx + rng.randrange(0, 2), py + dy,
                              10 - i, 8, covers[i])
    elif kind == 1:
        paint_book_open(d, px + 2, py + 4, covers[0], rng)
    else:
        rect(d, px + 9, py + 3, 6, 7, TR_PAPER_SHADE)  # a loose sheet
        rect(d, px + 9, py + 2, 6, 7, TR_PAPER)
        for line in range(py + 4, py + 8, 2):
            rect(d, px + 10, line, 4, 1, TR_INK)
        paint_notebook(d, px + 2, py + 4, rng)


def paint_train_books(d, px, py, first):
    """A crate for a desk, with books on it: on the first half one open
    face up beside a closed one, on the second a pile of hardbacks and a
    row of them standing, their spines out."""
    rect(d, px, py + 3, TILE, 12, TR_CRATE_DARK)
    rect(d, px, py + 3, TILE, 10, TR_CRATE)
    rect(d, px, py + 7, TILE, 1, TR_CRATE_DARK)
    rect(d, px, py + 11, TILE, 1, TR_CRATE_DARK)
    if first:
        rng = random.Random(7)
        paint_book_open(d, px + 1, py + 2, TR_BOOK_COVERS[0], rng)
        paint_book_closed(d, px + 11, py + 8, 5, 6, TR_BOOK_COVERS[1])
        return
    # A pile of three, lying shut.
    for i, cover in enumerate(TR_BOOK_COVERS[1:4]):
        paint_book_closed(d, px + 1 + i % 2, py + 7 - 2 * i, 7, 5, cover)
    # Standing in a row: tall spines, a band of gilt on each.
    for i, cover in enumerate((TR_BOOK_COVERS[4], TR_BOOK_COVERS[0],
                               TR_BOOK_COVERS[2])):
        sx = px + 10 + 2 * i
        rect(d, sx, py + 1, 2, 11, TR_OUTLINE)
        rect(d, sx, py + 2, 2, 9, cover)
        rect(d, sx, py + 4, 2, 1, TR_GILT)
        rect(d, sx, py + 2, 1, 9, shade(cover, 25))


def _train_desk(d, px, py):
    """The crate Mario uses for a desk, seen from above."""
    rect(d, px, py + 3, TILE, 12, TR_CRATE_DARK)
    rect(d, px, py + 3, TILE, 10, TR_CRATE)
    rect(d, px, py + 7, TILE, 1, TR_CRATE_DARK)
    rect(d, px, py + 11, TILE, 1, TR_CRATE_DARK)


def paint_train_abacus(d, px, py):
    """The left end of the desk: a wooden abacus, its beads in red and
    cream on three wires, and beside it a grey pocket calculator with its
    green display and rows of keys."""
    _train_desk(d, px, py)
    # the abacus
    rect(d, px, py + 1, 9, 10, TR_OUTLINE)
    rect(d, px + 1, py + 2, 7, 8, TR_WOOD_LIGHT)
    rect(d, px + 2, py + 3, 5, 6, TR_CRATE_DARK)
    for i, wire in enumerate((py + 4, py + 6, py + 8)):
        rect(d, px + 2, wire, 5, 1, TR_METAL_LIGHT)
        for b in range(2 + i % 2):
            colour = TR_LABEL_RED if (b + i) % 2 else TR_LABEL_CREAM
            rect(d, px + 2 + b + i % 2 * 2, wire, 1, 1, colour)
    # the calculator
    rect(d, px + 9, py + 4, 7, 10, TR_OUTLINE)
    rect(d, px + 10, py + 5, 5, 8, TR_METAL)
    rect(d, px + 10, py + 5, 5, 2, (120, 170, 110))  # the display
    rect(d, px + 11, py + 6, 3, 1, (60, 90, 56))
    for ky in (py + 8, py + 10, py + 12):
        for kx in (px + 10, px + 12, px + 14):
            rect(d, kx, ky, 1, 1, TR_METAL_LIGHT)


def paint_train_mug(d, px, py):
    """The right end of the desk: Mario's tin mug and a candle stub in a
    puddle of its own wax."""
    _train_desk(d, px, py)
    rect(d, px + 2, py + 4, 6, 6, TR_OUTLINE)  # the mug, from above
    rect(d, px + 3, py + 5, 4, 4, TR_METAL_LIGHT)
    rect(d, px + 4, py + 6, 2, 2, (70, 44, 26))  # coffee
    rect(d, px + 8, py + 6, 2, 2, TR_OUTLINE)  # its handle
    rect(d, px + 10, py + 9, 5, 3, TR_LABEL_CREAM)  # wax
    rect(d, px + 11, py + 6, 3, 5, TR_PILLOW)  # the candle
    rect(d, px + 12, py + 4, 1, 2, TR_LAMP)  # its flame
    rect(d, px + 12, py + 5, 1, 1, (240, 170, 60))


def paint_train_food_table(d):
    """The narrow table the two of them eat at, three tiles long against
    the wall, seen from above: a white cloth with a red border, and on it
    a leg of prosciutto on its stand, a salame with a few slices cut, a
    wheel of cheese with a wedge out of it and a round loaf."""
    w, h = TR_FOOD_TABLE_TILES[0] * TILE, TR_FOOD_TABLE_TILES[1] * TILE
    rect(d, 1, h - 2, w - 2, 2, TR_OUTLINE)  # its shadow
    rect(d, 0, 0, w, h - 2, TR_OUTLINE)
    rect(d, 1, 0, w - 2, h - 3, TR_CLOTH)
    rect(d, 1, h - 5, w - 2, 1, TR_CLOTH_STRIPE)  # the border
    rect(d, 1, h - 4, w - 2, 1, TR_CLOTH_SHADE)

    # The prosciutto: the whole leg, lying on its side, broad and round
    # at the cut end, where the pink meat shows in its ring of white fat,
    # narrowing to the shank, with the bone and the string to hang it by.
    d.polygon([(2, 2), (8, 1), (15, 4), (15, 8), (8, 12), (2, 11)],
              fill=TR_OUTLINE)
    d.ellipse((1, 1, 11, 12), fill=TR_OUTLINE)
    d.polygon([(5, 2), (9, 2), (14, 5), (14, 7), (9, 11), (5, 11)],
              fill=TR_HAM_RIND)
    d.ellipse((2, 2, 10, 11), fill=TR_HAM_FAT)  # the fat round the cut
    d.ellipse((3, 3, 9, 10), fill=TR_HAM)
    rect(d, 4, 5, 3, 1, shade(TR_HAM, 28))
    rect(d, 5, 8, 3, 1, TR_HAM_DARK)
    rect(d, 11, 4, 3, 1, shade(TR_HAM_RIND, 30))  # the shine on the rind
    rect(d, 15, 5, 1, 3, TR_BONE)  # the bone at the shank
    rect(d, 16, 4, 1, 1, TR_TWINE)
    rect(d, 16, 8, 1, 1, TR_TWINE)

    # The salame: a long one with round ends, flecked with fat, the cut
    # end pale, and two slices off it.
    rect(d, 18, 2, 10, 6, TR_OUTLINE)
    rect(d, 17, 3, 12, 4, TR_OUTLINE)
    rect(d, 19, 3, 8, 4, TR_SALAMI)
    rect(d, 18, 4, 10, 2, TR_SALAMI)
    rect(d, 19, 3, 8, 1, shade(TR_SALAMI, 45))
    for fx, fy in ((20, 5), (22, 4), (24, 5), (26, 4)):
        rect(d, fx, fy, 1, 1, TR_SALAMI_FAT)
    rect(d, 27, 4, 1, 2, TR_SALAMI_FAT)  # the cut end
    rect(d, 17, 4, 1, 1, TR_TWINE)  # the knot
    for sx in (20, 24):
        rect(d, sx - 1, 8, 4, 5, TR_OUTLINE)
        rect(d, sx - 2, 9, 6, 3, TR_OUTLINE)
        rect(d, sx - 1, 9, 4, 3, TR_SALAMI)
        rect(d, sx, 10, 1, 1, TR_SALAMI_FAT)
        rect(d, sx + 2, 9, 1, 1, TR_SALAMI_FAT)

    # The cheese: a wheel, its rind, a wedge cut out of it.
    d.ellipse((28, 1, 39, 12), fill=TR_OUTLINE)
    d.ellipse((29, 2, 38, 11), fill=TR_CHEESE_RIND)
    d.ellipse((30, 3, 37, 10), fill=TR_CHEESE)
    d.polygon([(34, 6), (39, 1), (39, 6)], fill=TR_CLOTH)
    rect(d, 34, 6, 5, 1, TR_CHEESE_RIND)
    rect(d, 32, 7, 1, 1, TR_CHEESE_RIND)

    # The loaf, round, the cross cut into its crust.
    d.ellipse((39, 2, 47, 11), fill=TR_OUTLINE)
    d.ellipse((40, 3, 46, 10), fill=TR_BREAD)
    rect(d, 41, 4, 3, 1, shade(TR_BREAD, 34))
    rect(d, 43, 4, 1, 6, TR_BREAD_CRUST)
    rect(d, 41, 6, 5, 1, TR_BREAD_CRUST)


def paint_train_weapons(d):
    """Mario's weapons table, three tiles long against the wall, seen from
    above: the shotgun laid along it, the pistol with a magazine beside it,
    an open box of rounds standing in rows and a few red shotgun shells."""
    w, h = TR_WEAPON_TABLE_TILES[0] * TILE, TR_WEAPON_TABLE_TILES[1] * TILE
    rect(d, 1, h - 2, w - 2, 2, TR_OUTLINE)  # its shadow
    rect(d, 0, 0, w, h - 2, TR_OUTLINE)
    rect(d, 1, 0, w - 2, h - 3, TR_TABLE_DARK)
    for gx in range(1, w - 1, 8):  # the planks
        rect(d, gx, 0, 1, h - 3, shade(TR_TABLE_DARK, -22))
    rect(d, 1, h - 4, w - 2, 1, shade(TR_TABLE_DARK, -30))

    # The shotgun, all the way along: the barrel, the pump, the stock.
    rect(d, 2, 1, 34, 4, TR_OUTLINE)
    rect(d, 3, 2, 22, 1, TR_GUN_LIGHT)  # the barrel
    rect(d, 3, 3, 22, 1, TR_GUN)
    rect(d, 8, 2, 6, 2, TR_WOOD)  # the pump
    rect(d, 25, 2, 4, 2, TR_GUN)  # the receiver
    rect(d, 29, 1, 8, 4, TR_OUTLINE)
    rect(d, 29, 2, 7, 2, TR_WOOD_LIGHT)  # the stock
    rect(d, 30, 3, 6, 1, TR_WOOD)

    # The pistol, on its side: the slide with its port and sights, the
    # frame, the trigger in its guard and the grip raked back.
    rect(d, 2, 6, 13, 5, TR_OUTLINE)
    rect(d, 3, 7, 11, 2, TR_GUN_LIGHT)  # the slide
    rect(d, 3, 7, 11, 1, shade(TR_GUN_LIGHT, 40))
    rect(d, 8, 8, 2, 1, TR_OUTLINE)  # the ejection port
    rect(d, 3, 9, 11, 1, TR_GUN)  # the frame
    rect(d, 7, 10, 4, 3, TR_OUTLINE)  # the trigger guard
    rect(d, 8, 10, 2, 2, TR_TABLE_DARK)
    rect(d, 9, 10, 1, 1, TR_GUN)  # the trigger
    rect(d, 10, 10, 5, 3, TR_OUTLINE)
    rect(d, 11, 12, 5, 2, TR_OUTLINE)
    rect(d, 11, 10, 3, 2, TR_GUN)  # the grip, raked back
    rect(d, 12, 12, 3, 1, TR_GUN)
    rect(d, 12, 11, 1, 1, TR_GUN_LIGHT)
    # A magazine beside it.
    rect(d, 14, 7, 3, 7, TR_OUTLINE)
    rect(d, 15, 8, 1, 5, TR_GUN)
    rect(d, 15, 8, 1, 1, TR_BRASS)

    # The box of rounds, open: brass bases in rows, each with its primer.
    rect(d, 19, 6, 13, 8, TR_OUTLINE)
    rect(d, 20, 7, 11, 6, TR_AMMO_BOX)
    for bx in range(21, 30, 2):
        for by in (8, 10):
            rect(d, bx, by, 1, 1, TR_BRASS)
    rect(d, 20, 12, 11, 1, shade(TR_AMMO_BOX, -30))

    # Red shotgun shells lying about, their brass heads.
    for sx, sy in ((34, 7), (38, 9), (35, 11)):
        rect(d, sx - 1, sy - 1, 6, 3, TR_OUTLINE)
        rect(d, sx, sy, 3, 1, TR_SHELL_RED)
        rect(d, sx + 3, sy, 1, 1, TR_BRASS)
    rect(d, 41, 5, 4, 1, TR_GUN_LIGHT)  # a cleaning rod


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
    # Not under Mario's desk (K, q, k): it stands on black, a dark edge
    # above and below it.
    floored = ".SLTCh*bBuofEPlVaGYROcm"
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

    # The hull. The north wall has a window on two tiles in every four;
    # the end walls of the coaches, running north-south, are seen from
    # above as one band down their whole length, closed off only where
    # the aisle goes through. Key bits: the two of the windows, then a
    # wall above, below, to the left and to the right.
    def hull(i):
        window = 1 if i & 3 in (1, 2) else 0
        above, below = bool(i & 4), bool(i & 8)
        across = bool(i & 16) or bool(i & 32)
        if (above or below) and not across:
            return tile_of(lambda d: paint_train_end_wall(
                d, 0, 0, open_above=not above, open_below=not below))
        return cell(lambda d, gx, gy: paint_train_shell(d, "W", gx, gy),
                    window, 0)

    rules.append(rule(
        "structures", "W",
        [atlas.bucket(lambda i=i: hull(i), 1) for i in range(64)],
        [pattern_key(1, 0, 4, 1), pattern_key(1, 0, 4, 2),
         neighbour_key(0, -1, "W"), neighbour_key(0, 1, "W"),
         neighbour_key(-1, 0, "W"), neighbour_key(1, 0, "W")]))
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

    # Mario's wardrobe and suitcases, Luigi's open ones: each painted
    # whole and cut to the tile its place in the run asks for.
    def cut(paint, glyph, width):
        def tile(first, last):
            if first and last:
                return tile_of(lambda d: paint(d, 0, 0, 1))
            index = 0 if first else (width - 1 if last else 1)
            return tile_of(lambda d: paint(d, -index * TILE, 0, width))
        return rule("structures", glyph,
                    [atlas.bucket(lambda i=i: tile(not i & 1, not i & 2), 1)
                     for i in range(4)],
                    [neighbour_key(-1, 0, glyph), neighbour_key(1, 0, glyph)])

    rules.append(cut(paint_train_wardrobe, "R", 3))
    rules.append(cut(paint_train_suitcases, "Y", 2))
    rules.append(cut(paint_train_open_suitcase, "O", 2))
    rules.append(rule("structures", "c", randomly(paint_train_luigi_clothes)))
    rules.append(rule("structures", "m", randomly(paint_train_underwear)))
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
    rules.append(rule("structures", "k", one(
        lambda d, px, py: paint_train_books(d, px, py, True))))
    rules.append(rule("structures", "K", one(paint_train_abacus)))
    rules.append(rule("structures", "q", one(paint_train_mug)))

    table = Image.new("RGBA", tuple(n * TILE for n in TR_MAP_TABLE_TILES),
                      TRANSPARENT)
    paint_train_map_table(table)
    weapons = Image.new("RGBA",
                        tuple(n * TILE for n in TR_WEAPON_TABLE_TILES),
                        TRANSPARENT)
    paint_train_weapons(ImageDraw.Draw(weapons))
    food = Image.new("RGBA", tuple(n * TILE for n in TR_FOOD_TABLE_TILES),
                     TRANSPARENT)
    paint_train_food_table(ImageDraw.Draw(food))
    nose, first = train_nose(Room(rows))
    return {
        "void": "#060608",
        "voidGlyph": "x",
        "rules": rules,
        "objects": [
            {"glyph": "P", "image": "train_map_table.png",
             "tiles": list(TR_MAP_TABLE_TILES), "sprite": table},
            {"glyph": "a", "image": "train_weapons_table.png",
             "tiles": list(TR_WEAPON_TABLE_TILES), "sprite": weapons},
            {"glyph": "G", "image": "train_food_table.png",
             "tiles": list(TR_FOOD_TABLE_TILES), "sprite": food},
            {"at": [first, 0], "image": "train_nose.png", "sprite": nose,
             "under": [row[first:] for row in rows]},
        ],
    }



# ---------------------------------------------------------- the mall's art
# The hypermarket, two floors in the barracks' style. The painters stay in
# tools/build_mall.py; this is the composition that used to bake them.
# Two things in it are not tiles. The shopfronts along the back walls each
# have their own name and front, which no glyph says, so they are objects
# placed by hand over the rows they were painted for (`under`); and the
# pieces that stand taller than their cell -- the planters' ficus, the
# gate's posts, the fire exit -- lean out over the cell above.

MALL_ROWS = {"mallGround": "mall-ground-rows", "mallFirst": "mall-first-rows"}
MALL_SHOPS = {"mallGround": mall.GROUND_SHOPS, "mallFirst": mall.FIRST_SHOPS}
# Glyphs the mall floods with its glossy floor, and those it edges.
MALL_FLOOR = ".:bZ*PTKBUDEXg"
MALL_SHOP_FLOOR = "oLH"
MALL_SERVICE_FLOOR = "dcG"
MALL_EDGED = MALL_FLOOR + "+" + MALL_SHOP_FLOOR + MALL_SERVICE_FLOOR


def mall_courses(rows: list[str], x: int, y: int) -> int:
    """How many rows of wall (`W` or `Q`) stand under (x, y), itself
    included: the shopfronts are painted for that height."""
    n = 0
    while y + n < len(rows) and rows[y + n][x] in "WQ":
        n += 1
    return n


def mall_shop_walls(name: str, rows: list[str], rng) -> list[dict]:
    """The shopfronts of a place, one object per unbroken run of them along
    a wall: each shop is painted at its own place in the run's picture."""
    runs: dict[int, list[list]] = {}
    for (x0, y0), shop in sorted(MALL_SHOPS[name].items(),
                                 key=lambda e: (e[0][1], e[0][0])):
        row = runs.setdefault(y0, [])
        if row and row[-1][0] + row[-1][1] == x0:
            row[-1][1] += shop[0]
            row[-1][2].append((x0, shop))
        else:
            row.append([x0, shop[0], [(x0, shop)]])
    objects = []
    for y0, row in sorted(runs.items()):
        for x0, width, shops in row:
            courses = mall_courses(rows, x0, y0)
            sprite = Image.new("RGBA", (width * TILE, courses * TILE),
                               TRANSPARENT)
            for sx, shop in shops:
                one = Image.new("RGBA", (shop[0] * TILE, courses * TILE),
                                TRANSPARENT)
                mall.paint_shopfront(ImageDraw.Draw(one), shop, courses, rng)
                sprite.alpha_composite(one, ((sx - x0) * TILE, 0))
            objects.append({
                "at": [x0, y0],
                "image": f"{name}_shops_{x0}_{y0}.png",
                "sprite": sprite,
                "under": [rows[y][x0:x0 + width]
                          for y in range(y0, y0 + courses)],
            })
    return objects


def mall_floor(atlas: Atlas, name: str, rng) -> dict:
    """The rules that paint PlaceId.mallGround and PlaceId.mallFirst. The
    first floor has what the ground floor has not: Luigi's grocery, the
    service area behind the gate, the railing over the atrium."""
    from build_street_level import read_rows  # noqa: PLC0415 - the shops

    rows = read_rows(MALL_ROWS[name])
    first = name == "mallFirst"

    def gloss(parity):
        return atlas.bucket(lambda p=parity: cell(
            lambda d, gx, gy: mall.paint_floor(d, rng, gx, gy), p, 0))

    def service(pattern):
        # SERVICE_B where (x * 3 + y) % 4 == 0, which is the key holding.
        return atlas.bucket(lambda p=pattern: cell(
            lambda d, gx, gy: mall.paint_service_floor(d, rng, gx, gy),
            0 if p else 1, 0))

    def one(paint):
        return [atlas.bucket(lambda: tile_of(lambda d: paint(d, 0, 0)), 1)]

    def randomly(paint):
        return [atlas.bucket(lambda: tile_of(
            lambda d: paint(d, rng, 0, 0)))]

    def room_of(glyph, offsets, index):
        """The neighbourhood of a cell of `glyph` where the neighbour at
        offsets[bit] is `glyph` too when that bit of `index` is set."""
        shown = {off for bit, off in enumerate(offsets) if index >> bit & 1}
        return Neighbourhood(
            glyph, lambda x, y: glyph if (x, y) in shown else ".")

    rules = [rule("ground", MALL_FLOOR, [gloss(0), gloss(1)],
                  [parity_key()])]
    # A flickering lamp lies in the service area if what is to its left is.
    lit = [neighbour_key(-1, 0, "dc")]
    rules.append(rule("ground", "+",
                      [gloss(0), [], gloss(1), []],
                      lit + [parity_key()]))
    if first:
        rules.append(rule("ground", MALL_SHOP_FLOOR, randomly(
            lambda d, rng_, px, py: mall.paint_shop_floor(d, rng_, 0, 0))))
        # The joint between a shop's boards falls at (x * 5) % 12.
        for offset in range(12):
            joint = atlas.bucket(lambda o=offset: tile_of(
                lambda d: mall.paint_shop_joint(d, o)), 1)
            rules.append(rule("ground", MALL_SHOP_FLOOR, [[], joint],
                              [pattern_key(5, 0, 12, offset)]))
        rules.append(rule("ground", MALL_SERVICE_FLOOR,
                          [service(False), service(True)],
                          [pattern_key(3, 1, 4, 0)]))
        rules.append(rule("ground", "+",
                          [[], service(False), [], service(True)],
                          lit + [pattern_key(3, 1, 4, 0)]))
    for right in (False, True):
        edge = atlas.bucket(lambda r=right: tile_of(
            lambda d: rect(d, 14 if r else 0, 0, 2, TILE, (40, 40, 46))), 1)
        rules.append(rule("ground", MALL_EDGED, [[], edge],
                          [neighbour_key(1 if right else -1, 0, "x")]))

    # The back wall is two courses, the shopfronts hung on it are objects.
    walls = [atlas.bucket(lambda t=top, s=skirting: tile_of(
        lambda d: mall.paint_wall_face(d, t, s)), 1)
        for skirting in (True, False) for top in (True, False)]
    rules.append(rule("structures", "WQ", walls,
                      [neighbour_key(0, -1, "WQ"), neighbour_key(0, 1, "WQ")]))
    if first:
        rules.append(rule(
            "structures", "I",
            [atlas.bucket(lambda i=i: tile_of(
                lambda d: mall.paint_partition(
                    d, room_of("I", [(0, 1)], i), 0, 0)), 1)
             for i in range(2)],
            [neighbour_key(0, 1, "I")]))
        rules.append(rule("structures", "S", randomly(mall.paint_shelves)))
        rules.append(rule("foreground", "Q", one(mall.paint_panel)))
    if first:  # the railing over the atrium, its posts on alternate columns
        keys = [pattern_key(1, 0, 2, 1), pattern_key(7, 0, 11, 0)]
        columns = [2, 1, 0, 11]
    else:
        keys = [pattern_key(1, 0, 2, 1)]
        columns = [0, 1]
    rules.append(rule("structures", "w", [atlas.bucket(lambda c=c: cell(
        lambda d, gx, gy: mall.paint_front_wall(d, None, gx, gy, first),
        c, 0), 1) for c in columns], keys))
    rules.append(rule(
        "structures", "E",
        [atlas.bucket(lambda i=i: tile_of(
            lambda d: mall.paint_entrance(d, 0, 0, not i & 1, not i & 2)), 1)
         for i in range(4)],
        [neighbour_key(-1, 0, "E"), neighbour_key(1, 0, "E")]))
    stairs = [(0, -1), (-1, 0), (1, 0)]
    rules.append(rule(
        "structures", "UD",
        [atlas.bucket(lambda i=i, g=g: tile_of(
            lambda d: mall.paint_stairs(d, room_of(g, stairs, i), 0, 0)), 1)
         for g in "U" for i in range(8)],
        [neighbour_key(0, -1, "UD"), neighbour_key(-1, 0, "UD"),
         neighbour_key(1, 0, "UD")]))
    rules.append(rule("structures", ":", randomly(mall.paint_litter)))
    rules.append(rule("structures", "b", randomly(mall.paint_blood)))

    # Props, which lean out over the cell above where they stand tall.
    buckets, up = leaning(atlas, lambda i: lambda d, px, py:
                          mall.paint_planter(d, rng, px, py))
    rules.append(rule("structures", "P", buckets, pieces=up))
    rules.append(rule(
        "structures", "T",
        [atlas.bucket(lambda t=tipped: tile_of(
            lambda d: paint_trolley(d, 0, 0, tipped=t)), 1)
         for tipped in (True, False)], [parity_key()]))
    for glyph, paint in (("K", mall.paint_kiosk), ("B", mall.paint_long_bench)):
        rules.append(rule(
            "structures", glyph,
            [atlas.bucket(lambda i=i, p=paint: tile_of(
                lambda d: p(d, 0, 0, not i & 1, not i & 2)), 1)
             for i in range(4)],
            [neighbour_key(-1, 0, glyph), neighbour_key(1, 0, glyph)]))
    if first:
        # The gate's posts and, over the one against the wall, its lintel.
        keys = [neighbour_key(0, -1, "WQ")]
        buckets, up = leaning(atlas, lambda i: lambda d, px, py:
                              mall.paint_gate(d, Neighbourhood(
                                  "G", lambda x, y, i=i: "W"
                                  if (x, y) == (0, 0) and i else ".", (0, 1)),
                                  0, 1), keys)
        rules.append(rule("structures", "G", buckets, keys, up))
        rules.append(rule("structures", "g", one(
            lambda d, px, py: mall.paint_gate(
                d, Neighbourhood("g", lambda *_: "."), 0, 0))))

    objects = mall_shop_walls(name, rows, rng)
    if first:
        # ALIMENTARI hangs one row above Luigi's shelves, in the darkness.
        sign = Image.new("RGBA", (5 * TILE, TILE), TRANSPARENT)
        mall.paint_grocery_sign(ImageDraw.Draw(sign), 5)
        objects.append({"glyph": "S", "image": "mall_first_grocery_sign.png",
                        "tiles": [5, 1], "offsetY": -1, "sprite": sign})
        # The wall over the service area, past the gate.
        xs = [x for x in range(len(rows[0])) if rows[5][x] == "d"]
        courses = mall_courses(rows, xs[0], 3)
        wall = Image.new("RGBA", (len(xs) * TILE, courses * TILE),
                         TRANSPARENT)
        mall.paint_service_wall(ImageDraw.Draw(wall), (len(xs), courses), rng)
        objects.append({
            "at": [xs[0], 3], "image": "mall_first_service_wall.png",
            "sprite": wall,
            "under": [rows[y][xs[0]:xs[-1] + 1] for y in range(3, 3 + courses)],
        })
    else:
        # The fire exit through the back wall of the upper area.
        door = Image.new("RGBA", (TILE, TILE * 3), TRANSPARENT)
        mall.paint_exit(ImageDraw.Draw(door), 0, 2)
        objects.append({"glyph": "X", "image": "mall_ground_exit.png",
                        "offsetY": -2, "sprite": door})
    return {"void": "#060608", "voidGlyph": "x", "rules": rules,
            "objects": objects}


def mall_ground(atlas: Atlas, rng) -> dict:
    return mall_floor(atlas, "mallGround", rng)


def mall_first(atlas: Atlas, rng) -> dict:
    return mall_floor(atlas, "mallFirst", rng)



# --------------------------------------------------------- the church's art
# Moved here from tools/build_church.py, which this atlas replaces: San
# Nicola, a nave of worn flagstones between two ranks of pews shoved out of
# line, the roof fallen in. The wall behind the altar is one object, its
# fresco flaked over the whole width; everything else is tiles, and a good
# part of it is patterns on the position (the pews' skew, the niches in the
# side walls), which is what the pattern key is for.

CH_SLAB = (132, 124, 110)
CH_SLAB_ALT = (120, 113, 100)
CH_SLAB_JOINT = (92, 86, 78)
CH_PLASTER = (196, 186, 166)
CH_PLASTER_DARK = (150, 140, 124)
CH_STONE = (168, 160, 144)
CH_STONE_DARK = (120, 114, 102)
CH_WALL_TOP = (44, 40, 38)
CH_PEW = (96, 68, 42)
CH_PEW_TOP = (132, 96, 60)
CH_PEW_DARK = (64, 44, 28)
CH_GOLD = (168, 138, 62)
# Faded almost into the plaster: what a fresco looks like after a fire and
# a winter of rain through the roof.
CH_FRESCO = [(168, 146, 128), (150, 152, 158), (178, 160, 126),
             (146, 154, 140)]
CH_RUBBLE = [(150, 142, 128), (122, 116, 104), (176, 168, 152), (96, 92, 86)]
CH_SKY = (176, 186, 198)
# The wall behind the altar, in tiles: every `W` of the place.
CH_APSE_TILES = (22, 2)


def paint_church_floor(d, rng, x, y):
    """Big worn flagstones, two to a cell, gritty and cracked."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE,
         CH_SLAB if (x + y // 2) % 2 else CH_SLAB_ALT)
    rect(d, px, py, TILE, 1, CH_SLAB_JOINT)
    rect(d, px, py, 1, TILE, CH_SLAB_JOINT)
    for _ in range(4):
        rect(d, px + rng.randrange(16), py + rng.randrange(16), 1, 1,
             CH_SLAB_JOINT)
    if rng.random() < 0.18:
        cx, cy = px + rng.randrange(2, 12), py + rng.randrange(2, 12)
        for i in range(5):
            rect(d, cx + i, cy + (i % 3), 1, 1, (78, 72, 66))


def paint_church_plaster(d, rng, px, py):
    """Plaster, roof tiles and window glass down off the roof, underfoot:
    a few sherds big enough to see, and the dust of the rest."""
    for _ in range(3):
        rect(d, px + rng.randrange(11), py + rng.randrange(11),
             rng.randint(3, 5), rng.randint(2, 3), rng.choice(CH_RUBBLE))
    for _ in range(8):
        rect(d, px + rng.randrange(15), py + rng.randrange(15),
             rng.randint(1, 3), 1, rng.choice(CH_RUBBLE))
    if rng.random() < 0.4:  # a shard of window glass among it
        rect(d, px + rng.randrange(12), py + rng.randrange(12), 3, 1,
             (156, 176, 170))


def paint_church_apse(d, room, rng):
    """The wall behind the altar: plaster over ashlar with a blind arcade
    along it, the fresco flaked down to a few patches, the round-arched
    window over the altar boarded from outside, and the clean cross the
    crucifix left when it came down."""
    ys = [y for y in range(room.height) if room.at(1, y) == "W"]
    top, bottom = min(ys), max(ys)
    x0 = min(x for x in range(room.width) if room.at(x, top) == "W")
    x1 = max(x for x in range(room.width) if room.at(x, top) == "W")
    px, py = x0 * TILE, top * TILE
    w, h = (x1 - x0 + 1) * TILE, (bottom - top + 1) * TILE
    rect(d, px, py, w, h, CH_PLASTER)
    rect(d, px, py, w, 5, CH_WALL_TOP)
    rect(d, px, py + 5, w, 2, shade(CH_PLASTER, 26))  # the cornice
    for bx in range(px + 3, px + w - 6, 11):  # the blind arcade behind it
        d.ellipse([bx, py + 9, bx + 6, py + 15], fill=CH_PLASTER_DARK)
        rect(d, bx, py + 12, 7, h - 18, CH_PLASTER_DARK)
        rect(d, bx + 1, py + 13, 5, h - 19, shade(CH_PLASTER, -8))
    for _ in range(w // 12):  # what is left of the fresco over it: two or
        # three overlapping blotches apiece, so no edge comes out square
        bx, by = px + rng.randrange(w - 16), py + 9 + rng.randrange(h - 21)
        colour = rng.choice(CH_FRESCO)
        for _ in range(3):
            rect(d, bx + rng.randrange(-2, 5), by + rng.randrange(-2, 4),
                 rng.randint(5, 11), rng.randint(3, 7), colour)
    for _ in range(w // 9):  # and the plaster gone in patches
        bx, by = px + rng.randrange(w - 10), py + 8 + rng.randrange(h - 16)
        rect(d, bx, by, rng.randint(5, 10), rng.randint(3, 6),
             CH_STONE_DARK)
    # the round-arched window over the altar, boarded from the far side
    cx, wy = px + w // 2, py + 9
    frame, hole = shade(CH_PLASTER, 32), (24, 22, 24)
    d.ellipse([cx - 10, wy, cx + 10, wy + 20], fill=frame)
    d.ellipse([cx - 7, wy + 3, cx + 7, wy + 17], fill=hole)
    rect(d, cx - 10, wy + 10, 21, h - (wy - py) - 10, frame)
    rect(d, cx - 7, wy + 10, 15, h - (wy - py) - 10, hole)
    for i, by in enumerate((wy + 6, wy + 15)):  # the boards across it
        rect(d, cx - 9, by, 19, 3, (110, 84, 54) if i else (88, 66, 44))


def paint_church_side_wall(d, rng, x, y):
    """One cell of the aisle walls, `I`: ashlar with a niche here and
    there, its statue long gone."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, CH_STONE)
    rect(d, px, py, TILE, 2, CH_STONE_DARK)
    for _ in range(3):
        rect(d, px + rng.randrange(14), py + rng.randrange(14), 2, 1,
             CH_STONE_DARK)
    if (x * 7 + y * 5) % 6 == 0:
        rect(d, px + 4, py + 3, 8, 11, (58, 54, 52))
        rect(d, px + 5, py + 4, 6, 9, (34, 32, 32))


def paint_church_front_wall(d, x, y):
    """The facade seen from inside: ashlar, with the odd window high up."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, CH_WALL_TOP)
    rect(d, px, py + 3, TILE, 10, CH_STONE)
    rect(d, px, py + 3, TILE, 1, CH_STONE_DARK)
    if (x * 5) % 7 == 0:
        rect(d, px + 5, py + 4, 6, 8, (26, 28, 34))
        rect(d, px + 5, py + 4, 6, 1, CH_STONE_DARK)


def paint_church_portal(d, px, py):
    """The way out, the leaves folded back and the square beyond them."""
    rect(d, px, py, TILE, TILE, (58, 54, 50))
    rect(d, px + 4, py + 2, 8, TILE - 2, (152, 146, 130))  # the daylight
    for leaf in (px, px + TILE - 4):
        rect(d, leaf, py, 4, TILE, DOOR_GREEN)
        rect(d, leaf + 1, py + 1, 2, TILE - 2, shade(DOOR_GREEN, 18))


def paint_church_altar(d, room, rng, x, y):
    """The altar, `A`: a stone table up two steps, the cloth dragged half
    off it and the candlesticks knocked over. Without the candlestick and
    the cloth, which come from the column: see `church_altar_extras`."""
    px, py = x * TILE, y * TILE
    first, last = room.at(x - 1, y) != "A", room.at(x + 1, y) != "A"
    if room.at(x, y - 1) != "A":  # the table top
        rect(d, px, py, TILE, 4, shade(CH_STONE, 30))
        rect(d, px, py + 4, TILE, 6, (196, 186, 162))  # the altar cloth
        rect(d, px, py + 9, TILE, 2, (148, 138, 118))
        rect(d, px, py + 11, TILE, 5, CH_STONE)
    else:  # the steps up to it, chipped
        rect(d, px, py, TILE, TILE, shade(CH_STONE, -12))
        rect(d, px, py, TILE, 3, CH_STONE)
        rect(d, px, py + 8, TILE, 3, shade(CH_STONE, -22))
        for _ in range(3):
            rect(d, px + rng.randrange(13), py + rng.randrange(13), 2, 1,
                 CH_STONE_DARK)
    if first:
        rect(d, px, py, 2, TILE, CH_STONE_DARK)
    if last:
        rect(d, px + TILE - 2, py, 2, TILE, CH_STONE_DARK)


def church_altar_extras(d, candlestick):
    """What lies on the altar's top row: a candlestick knocked over on it
    (x % 4 == 3 in the baker), or the cloth hanging off the front
    (x % 4 == 2)."""
    if candlestick:
        rect(d, 2, 1, 11, 2, CH_GOLD)
        rect(d, 2, 0, 3, 3, shade(CH_GOLD, 30))
    else:
        rect(d, 4, 11, 8, 5, (196, 186, 162))


def paint_church_pew(d, room, x, y):
    """A pew, `T`: the bench with its back to the altar, shoved out of
    line with the rank it belongs to."""
    px, py = x * TILE, y * TILE
    skew = (x * 5 + y * 3) % 3 - 1
    rect(d, px, py + 11 + skew, TILE, 3, CH_PEW_DARK)  # its shadow
    rect(d, px, py + 3 + skew, TILE, 8, CH_PEW)
    rect(d, px, py + 3 + skew, TILE, 2, CH_PEW_TOP)
    rect(d, px, py + 9 + skew, TILE, 1, CH_PEW_DARK)
    if room.at(x - 1, y) != "T":
        rect(d, px, py + 3 + skew, 2, 11, CH_PEW_DARK)
    if room.at(x + 1, y) != "T":
        rect(d, px + TILE - 2, py + 3 + skew, 2, 11, CH_PEW_DARK)


def paint_church_drum(d, px, py):
    """A column drum on its side, `K`: the shaft of one of the nave's
    columns, rolled off its base, the plaster burst away from the stone."""
    rect(d, px, py + 1, TILE, 14, OUTLINE)
    rect(d, px + 1, py + 2, 14, 12, CH_STONE)
    rect(d, px + 1, py + 2, 14, 4, shade(CH_STONE, 34))
    rect(d, px + 1, py + 11, 14, 3, shade(CH_STONE, -26))
    for i in range(3):  # the fluting down the shaft
        rect(d, px + 3 + i * 4, py + 3, 1, 10, shade(CH_STONE, -16))
    rect(d, px + 1, py + 5, 4, 7, CH_PLASTER)  # plaster still clinging


def paint_church_roof_hole(d, rng, px, py):
    """Under a hole in the roof, `^`: daylight lies square on the slabs,
    and the tiles and laths that came down with it are heaped round the
    edges of it."""
    rect(d, px, py, TILE, TILE, shade(CH_SLAB, 28))
    rect(d, px + 2, py + 2, 12, 12, shade(CH_SLAB, 52))
    rect(d, px + 4, py + 3, 8, 9, CH_SKY)
    rect(d, px + 5, py + 4, 6, 3, shade(CH_SKY, 24))
    for _ in range(10):  # the dust of it, all round
        rect(d, px + rng.randrange(15), py + rng.randrange(15),
             rng.randint(1, 3), 1, rng.choice(CH_RUBBLE))
    rect(d, px, py + 12, 6, 3, (108, 82, 54))  # a lath down with the tiles
    rect(d, px + 10, py, 5, 2, (96, 74, 48))


def church(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.church."""
    def randomly(paint):
        return [atlas.bucket(lambda: tile_of(
            lambda d: paint(d, rng, 0, 0)))]

    # The slabs alternate on (x + y // 2) % 2: the parity of the column,
    # flipped for the rows two and three of every four.
    def slab(x_odd, y2, y3):
        gy = 3 if y3 else 2 if y2 else 0
        return atlas.bucket(lambda: cell(
            lambda d, gx, gy_: paint_church_floor(d, rng, gx, gy_),
            1 if x_odd else 0, gy))

    floored = ".:AbZ^TK9E"
    rules = [rule(
        "ground", floored,
        [slab(bool(i & 1), bool(i & 2), bool(i & 4)) for i in range(8)],
        [pattern_key(1, 0, 2, 1), pattern_key(0, 1, 4, 2),
         pattern_key(0, 1, 4, 3)])]
    # The niches of the aisle walls come and go on (x * 7 + y * 5) % 6.
    rules.append(rule(
        "structures", "I",
        [atlas.bucket(lambda n=niche: cell(
            lambda d, gx, gy: paint_church_side_wall(d, rng, gx, gy),
            0 if n else 1, 0)) for niche in (False, True)],
        [pattern_key(7, 5, 6, 0)]))
    rules.append(rule(
        "structures", "w",
        [atlas.bucket(lambda w=window: cell(
            lambda d, gx, gy: paint_church_front_wall(d, gx, gy),
            0 if w else 1, 0), 1) for window in (False, True)],
        [pattern_key(5, 0, 7, 0)]))
    rules.append(rule("structures", "E", [atlas.bucket(lambda: tile_of(
        lambda d: paint_church_portal(d, 0, 0)), 1)]))
    rules.append(rule("structures", ":", randomly(paint_church_plaster)))
    rules.append(rule("structures", "b", randomly(paint_blood)))
    rules.append(rule("structures", "^", randomly(paint_church_roof_hole)))

    # The altar, four cells by two: its ends, and the steps behind the top.
    def altar(index):
        left, right, above = bool(index & 1), bool(index & 2), bool(index & 4)
        room = Neighbourhood("A", lambda x, y, l=left, r=right, a=above:
                             "A" if (x, y) == (-1, 0) and l
                             or (x, y) == (1, 0) and r
                             or (x, y) == (0, -1) and a else ".")
        return atlas.bucket(lambda: tile_of(
            lambda d: paint_church_altar(d, room, rng, 0, 0)))
    rules.append(rule(
        "structures", "A", [altar(i) for i in range(8)],
        [neighbour_key(-1, 0, "A"), neighbour_key(1, 0, "A"),
         neighbour_key(0, -1, "A")]))
    # On the top row alone, a candlestick where x % 4 is 3 and the cloth
    # hanging off the front where it is 2.
    extras = [atlas.bucket(lambda c=c: tile_of(
        lambda d: church_altar_extras(d, c)), 1) for c in (True, False)]
    rules.append(rule(
        "structures", "A", [[], [], extras[0], [], extras[1], [], [], []],
        [neighbour_key(0, -1, "A"), pattern_key(1, 0, 4, 3),
         pattern_key(1, 0, 4, 2)]))
    rules.append(rule("structures", "K", [atlas.bucket(lambda: tile_of(
        lambda d: paint_church_drum(d, 0, 0)), 1)]))

    # A pew is shoved out of line by (x * 5 + y * 3) % 3 - 1: two keys
    # for the skew and two for the ends of the rank.
    def pew(index):
        skew_key = index & 3  # 1: skew 0 -> v=0, 2: v=1, otherwise v=2
        value = {1: 0, 2: 1}.get(skew_key, 2)
        left, right = bool(index & 4), bool(index & 8)
        gx = (2 * value) % 3  # (5 * gx) % 3 == value
        room = Neighbourhood(
            "T", lambda x, y, l=left, r=right, g=gx:
            "T" if (x, y) == (g - 1, 0) and l or (x, y) == (g + 1, 0) and r
            else ".", (gx, 0))
        return atlas.bucket(lambda: cell(
            lambda d, x, y: paint_church_pew(d, room, x, y), gx, 0), 1)
    rules.append(rule(
        "structures", "T", [pew(i) for i in range(16)],
        [pattern_key(5, 3, 3, 0), pattern_key(5, 3, 3, 1),
         neighbour_key(-1, 0, "T"), neighbour_key(1, 0, "T")]))

    apse = Image.new("RGBA", tuple(n * TILE for n in CH_APSE_TILES),
                     TRANSPARENT)
    paint_church_apse(ImageDraw.Draw(apse), Block("W", *CH_APSE_TILES), rng)
    return {
        "void": "#060608",
        "voidGlyph": "x",
        "rules": rules,
        "objects": [{"glyph": "W", "image": "church_apse.png",
                     "tiles": list(CH_APSE_TILES), "sprite": apse}],
    }



# --------------------------------------------------------- the station's art
# The booking hall and its platform, the one place of the station that was
# still baked. It is the far platform's sister -- same slabs, same rails,
# same painters, which stay in tools/build_station.py -- with what the far
# platform has not: the hall, the rubble where the roof came down, the
# doorways onto the forecourt, the ticket windows, and the wrecked trains,
# which are objects: the railcar standing derailed across the near track, and
# the hijacked train -- its coach still on the far track, the car behind it
# lying wheels up across the platform and the hall.

STATION_RAILCAR_TILES = (16, 3)
STATION_COACH_TILES = (19, 3)
STATION_UPRIGHT_TILES = (17, 3)
STATION_OVERTURNED_TILES = (3, 12)
# The burning car runs on off the west edge of the map: only its east end,
# where it parted from the car still upright, is in the place.
STATION_BURNING_TILES = (4, 3)
STATION_BURNING_LENGTH = 12


def side_walls(atlas: Atlas) -> list:
    """The rule for a station room's side walls `|`: one unbroken strip of
    coping down each side, its lit edge towards the room. It is the east
    wall when the darkness outside the place is beside it on the east."""
    return [rule("structures", "|",
                 [atlas.bucket(lambda r=right: tile_of(
                     lambda d: station.paint_side_wall(d, 0, 0, r)), 1)
                  for right in (False, True)],
                 [neighbour_key(1, 0, "x")])]


def station_hall(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.station."""
    def platform(parity: int, edge: bool):
        return atlas.bucket(lambda p=parity, e=edge: cell(
            lambda d, gx, gy: station.paint_platform(
                d, rng, gx, gy, 0 if e else -1), p, 0))

    def hall(parity: int):
        return atlas.bucket(lambda p=parity: cell(
            lambda d, gx, gy: station.paint_hall(d, rng, gx, gy), p, 0))

    def randomly(paint):
        return [atlas.bucket(lambda: tile_of(
            lambda d: paint(d, rng, 0, 0)))]

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

    ballast = atlas.bucket(
        lambda: tile_of(lambda d: station.paint_ballast(d, rng, 0, 0)))
    rails = [
        atlas.bucket(lambda c=continuing: tile_of(
            lambda d: station.paint_rails(
                d, rng, Neighbourhood("-", lambda x, y: "-" if c else "."),
                0, 0)))
        for continuing in (False, True)
    ]
    wall = []
    for tagged in (False, True):
        for above in (False, True):
            wall.append(atlas.bucket(lambda a=above, g=tagged: cell(
                lambda d, gx, gy: station.paint_back_wall(
                    d, rng,
                    Neighbourhood("W", lambda x, y, a=a: "W" if a else "."),
                    gx, gy),
                0 if g else 1, 0)))

    rules = [
        # The ground, in the order the baker laid it: track, ballast, the
        # platform and its edge, and the booking hall's terrazzo elsewhere.
        # The track runs on off the west edge of the map.
        rule("ground", "-", rails, [neighbour_key(-1, 0, "-x")]),
        rule("ground", ",MmCVH", [ballast]),
        rule("ground", "?", [atlas.bucket(lambda: tile_of(
            lambda d: station.paint_scorched_ballast(d, rng, 0, 0)))]),
        rule("ground", "=TKn9",
             [platform(0, False), platform(1, False),
              platform(0, True), platform(1, True)],
             [parity_key(), first_row_key("=", 0, "eq")]),
        rule("ground", ":",
             [hall(0), hall(1), platform(0, False), platform(1, False)],
             [parity_key(), first_row_key("=", 2, "le")]),
        rule("ground", ".EObZ*+Up", [hall(0), hall(1)], [parity_key()]),
        rule("structures", "W", wall,
             [neighbour_key(0, -1, "W"), pattern_key(7, 5, 9)]),
        # The facade: an arched window on every sixth column, boarded or
        # not, its glass gone.
        rule("structures", "w",
             [atlas.bucket(lambda g=window: cell(
                 lambda d, gx, gy: station.paint_front_wall(d, rng, gx, gy),
                 0 if g else 1, 0)) for window in (False, True)],
             [pattern_key(5, 0, 6, 0)]),
        # The rubble: the heap, with a girder on a pattern of the position,
        # and a dark lip on each side that meets what can be walked on.
        rule("structures", "#",
             [atlas.bucket(lambda g=girder: cell(
                 lambda d, gx, gy: station.paint_rubble_heap(d, rng, gx, gy),
                 *((0, 0) if g else (1, 0))))
              for girder in (False, True)],
             [pattern_key(5, 3, 7, 0)]),
    ]
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        lip = atlas.bucket(lambda o=(dx, dy): tile_of(
            lambda d: station.paint_rubble_lip(d, Neighbourhood(
                "#", lambda x, y, o=o: "." if (x, y) == o else "#"), 0, 0)),
            1)
        rules.append(rule("structures", "#", [lip, []],
                          [neighbour_key(dx, dy, "#x")]))
    for glyph in "EO":
        rules.append(rule(
            "structures", glyph,
            [atlas.bucket(lambda f=first: tile_of(
                lambda d: station.paint_doorway(d, 0, 0, f)), 1)
             for first in (True, False)],
            [neighbour_key(-1, 0, glyph)]))
    rules += [
        rule("structures", ":", randomly(station.paint_litter)),
        rule("structures", "b", randomly(paint_blood)),
        rule("structures", "U", ends(station.paint_stairs, "U"),
             [neighbour_key(-1, 0, "U"), neighbour_key(1, 0, "U")]),
    ]
    tactile_keys = [
        neighbour_key(0, -1, "pOU"),
        neighbour_key(1, 0, "pOU"),
        neighbour_key(0, 1, "pOU"),
        neighbour_key(-1, 0, "pOU"),
    ]
    rules.append(rule(
        "structures", "p",
        [atlas.bucket(
            lambda connections=i: tile_of(lambda d: station.paint_tactile_path(
                d, connections, 0, 0)), 1)
         for i in range(16)],
        tactile_keys,
    ))
    rules += side_walls(atlas)
    rules.append(rule("foreground", "T", ends(station.paint_bench, "T"),
                      [neighbour_key(-1, 0, "T"), neighbour_key(1, 0, "T")]))
    rules.append(rule("foreground", "K", [atlas.bucket(lambda: tile_of(
        lambda d: station.paint_ticket_window(d, 0, 0)), 1)]))
    rules.append(rule("foreground", "n",
                      [atlas.bucket(lambda b=beam: tile_of(
                          lambda d: station.paint_post(d, Neighbourhood(
                              "n", lambda x, y, b=b: "n"
                              if (x == 1 and b) else "."), 0, 0)), 1)
                       for beam in (False, True)],
                      [neighbour_key(1, 0, "n")]))

    railcar = Image.new("RGBA", tuple(n * TILE for n in STATION_RAILCAR_TILES),
                        TRANSPARENT)
    station.paint_railcar(ImageDraw.Draw(railcar), rng,
                          (0, 0, railcar.width, railcar.height),
                          wrecked=True)
    coach = Image.new("RGBA", tuple(n * TILE for n in STATION_COACH_TILES),
                      TRANSPARENT)
    station.paint_railcar(ImageDraw.Draw(coach), rng,
                          (0, 0, coach.width, coach.height),
                          wrecked=False, with_cab=False)
    upright = Image.new("RGBA", tuple(n * TILE for n in STATION_UPRIGHT_TILES),
                        TRANSPARENT)
    station.paint_railcar(ImageDraw.Draw(upright), rng,
                          (0, 0, upright.width, upright.height),
                          wrecked=False, with_cab=False)
    overturned = Image.new(
        "RGBA", tuple(n * TILE for n in STATION_OVERTURNED_TILES),
        TRANSPARENT)
    station.paint_overturned_train(
        ImageDraw.Draw(overturned), rng,
        (0, 0, overturned.width, overturned.height))
    burning = Image.new(
        "RGBA", (STATION_BURNING_TILES[1] * TILE,
                 STATION_BURNING_LENGTH * TILE), TRANSPARENT)
    station.paint_overturned_train(
        ImageDraw.Draw(burning), rng, (0, 0, burning.width, burning.height),
        burnt=True)
    # Painted lying north-south like the other, then turned to lie along
    # the track, its shadow to the south, and cut to the end that shows:
    # the torn gangway, facing the car it parted from.
    burning = burning.transpose(Image.Transpose.ROTATE_270)
    burning = burning.crop((burning.width - STATION_BURNING_TILES[0] * TILE,
                            0, burning.width, burning.height))
    return {
        "void": "#060608",
        "voidGlyph": "x",
        "rules": rules,
        "objects": [
            {"glyph": "H", "image": "station_hall_burning.png",
             "tiles": list(STATION_BURNING_TILES), "sprite": burning},
            {"glyph": "C", "image": "station_hall_upright.png",
             "tiles": list(STATION_UPRIGHT_TILES), "sprite": upright},
            {"glyph": "M", "image": "station_hall_railcar.png",
             "tiles": list(STATION_RAILCAR_TILES), "sprite": railcar},
            {"glyph": "m", "image": "station_hall_coach.png",
             "tiles": list(STATION_COACH_TILES), "sprite": coach},
            {"glyph": "V", "image": "station_hall_overturned.png",
             "tiles": list(STATION_OVERTURNED_TILES), "sprite": overturned},
        ],
    }



# ---------------------------------------------------------- the roofs' art
# The terraces the airliner's tail came down on, in the 3/4 view of the
# streets. The painters stay in tools/build_airliner.py; this is the
# composition that baked them. Nothing in it stands taller than its cell,
# so it is all tiles: the tar laid in strips on the parity of the row and
# stepped down at the first parapet, the coping and the party walls keyed
# on their neighbours, and the gap between the blocks, which is dark only
# where there is roof both above and below it in the column.

class Rows:
    """Just the rows of a place: what `build_airliner.lower` reads to find
    where the terrace steps down."""

    def __init__(self, rows: list[str]) -> None:
        self.rows = rows


def airliner_roofs(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.airlinerRoofs."""
    def deck(row: int, step: int):
        """The tar of row `row` on a terrace whose step is at row `step`:
        it is the lower terrace if the row is below the step, and laid in
        strips on the parity of the row."""
        rows = Rows(["." * 6] * step + ["^" * 6] + ["." * 6] * 3)
        return atlas.bucket(lambda: cell(
            lambda d, gx, gy: airliner.roof_deck(d, rng, rows, gx, gy),
            0, row))

    def one(paint):
        return [atlas.bucket(lambda: tile_of(lambda d: paint(d, 0, 0)), 1)]

    def randomly(paint):
        return [atlas.bucket(lambda: tile_of(
            lambda d: paint(d, rng, 0, 0)))]

    def near(glyph, at=(0, 0), **shown):
        """The neighbourhood of the cell `at` of `glyph`, in which the
        named neighbours (`l`, `r`, `u` for left, right, up) show what is
        given and the rest is bare."""
        offsets = {"l": (-1, 0), "r": (1, 0), "u": (0, -1)}
        cells = {(at[0] + offsets[k][0], at[1] + offsets[k][1]): v
                 for k, v in shown.items()}
        return Neighbourhood(glyph, lambda x, y: cells.get((x, y), "."), at)

    decked = ".:b&TnY"
    # Bits, in key order: the row is no lower than the step, and the row
    # is odd. Without the first (index 0 and 2) the terrace is the lower.
    rules = [rule(
        "ground", decked,
        [deck(2, 0), deck(0, 0), deck(1, 0), deck(1, 1)],
        [first_row_key("^", 0, "le"), pattern_key(0, 1, 2, 1)])]

    # A party wall between two blocks: bits are a wall to the left, a wall
    # to the right, and darkness or wall to the right (which side the roof
    # is on, for the walls that run north to south).
    walls = []
    for index in range(8):
        left, right, beyond = (bool(index & 1), bool(index & 2),
                               bool(index & 4))
        room = near("W", l="W" if left else ".",
                    r="W" if right else ("x" if beyond else "."))
        walls.append(atlas.bucket(lambda rm=room: tile_of(
            lambda d: airliner.roof_wall(d, rm, 0, 0)), 1))
    rules.append(rule("structures", "W", walls,
                      [neighbour_key(-1, 0, "W"), neighbour_key(1, 0, "W"),
                       neighbour_key(1, 0, "xW")]))
    rules.append(rule("structures", "^", [atlas.bucket(lambda: tile_of(
        lambda d: airliner.roof_parapet(d, near("^"), 0, 0, False)), 1)]))
    rules.append(rule(
        "structures", ">",
        [atlas.bucket(lambda i=i: tile_of(
            lambda d: airliner.roof_parapet(
                d, near(">", l=">" if i & 1 else ".",
                        r=">" if i & 2 else "."), 0, 0, True)), 1)
         for i in range(4)],
        [neighbour_key(-1, 0, ">"), neighbour_key(1, 0, ">")]))
    rules.append(rule("structures", ":", randomly(airliner.roof_rubble)))
    rules.append(rule("structures", "b", randomly(airliner.roof_blood)))
    rules.append(rule(
        "structures", "&",
        [atlas.bucket(lambda a=a: tile_of(
            lambda d: airliner.roof_scorch(d, 0, 0, a)), 1)
         for a in (False, True)],
        [pattern_key(0, 1, 2, 1)]))
    rules.append(rule("structures", "T", randomly(airliner.roof_stack)))
    rules.append(rule("structures", "n", one(airliner.roof_mast)))

    # The roof of the next block across the gap, its coping along the near
    # edge, what stands on it, and the gap itself.
    rules.append(rule(
        "ground", airliner.FAR_DECK,
        [atlas.bucket(lambda p=parity, u=up: cell(
            lambda d, gx, gy: airliner.roof_far(
                d, rng, near("%", (p, 0), u="%" if u else "."), gx, gy),
            p, 0)) for parity in (0, 1) for up in (False, True)],
        [neighbour_key(0, -1, airliner.FAR_DECK), parity_key()]))
    rules.append(rule("structures", "k", randomly(airliner.roof_stack)))
    rules.append(rule("structures", ";", randomly(airliner.roof_rubble)))
    rules.append(rule(
        "structures", "S",
        [atlas.bucket(lambda i=i: tile_of(
            lambda d: airliner.roof_stairs_down(
                d, near("S", u="S" if i & 1 else ".",
                        l="S" if i & 2 else ".",
                        r="S" if i & 4 else "."), 0, 0)), 1)
         for i in range(8)],
        [neighbour_key(0, -1, "S"), neighbour_key(-1, 0, "S"),
         neighbour_key(1, 0, "S")]))
    rules.append(rule("structures", "x", [[], atlas.bucket(lambda: tile_of(
        lambda d: airliner.roof_drop(d, rng, 0, 0)))], [between_key("x")]))

    # The tail of the airliner, in the roofline: two rows deep, so the
    # tube is shaded over both at once, seamed every fourth column and
    # closed at the ends. `D` is the break torn in it.
    def tail(glyph, index):
        above, seam, left, right = (bool(index & 1), bool(index & 2),
                                    bool(index & 4), bool(index & 8))
        gx = 0 if seam else 1
        room = near(glyph, (gx, 0), u="#" if above else ".",
                    l="#" if left else ".", r="#" if right else ".")
        paint = airliner.roof_tail if glyph == "#" else airliner.roof_break
        return atlas.bucket(lambda: cell(
            lambda d, x, y: paint(d, room, x, y), gx, 0), 1)
    tail_keys = [neighbour_key(0, -1, "#D"), pattern_key(1, 0, 4, 0),
                 neighbour_key(-1, 0, "#D"), neighbour_key(1, 0, "#D")]
    for glyph in "#D":
        rules.append(rule("structures", glyph,
                          [tail(glyph, i) for i in range(16)], tail_keys))
    return {"void": "#060608", "voidGlyph": "x", "rules": rules,
            "objects": []}


# ----------------------------------------------------------------- writing

PLACES = {
    "barracks": barracks,
    "church": church,
    "airlinerCabin": airliner_cabin,
    "airlinerRoofs": airliner_roofs,
    "barArcobaleno": bar_arcobaleno,
    "barBackroom": bar_backroom,
    "duomo": duomo,
    "duomoUpper": duomo_upper,
    "duomoSecondFloor": duomo_second_floor,
    "duomoTower": duomo_tower,
    "duomoBells": duomo_bells,
    "duomoTowerRoof": duomo_tower_roof,
    "mallFirst": mall_first,
    "mallGround": mall_ground,
    "station": station_hall,
    "stationFarSide": station_far_side,
    "stationUnderpass": station_underpass,
    "trainInterior": train_interior,
    **city.PLACES,
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
    # Termini keeps the same material rules and railcar, but has its own
    # art key so Molfetta's two place-name boards do not follow it to Rome.
    far_side = places["stationFarSide"]
    places["romeTermini"] = {
        **far_side,
        # Its stairs go up, not down: the rest of the far side's rules.
        "rules": [spec for spec in far_side["rules"]
                  if not (spec["layer"] == "structures"
                          and spec["glyphs"] == "D")] + [
            rule("structures", "D", [
                atlas.bucket(lambda l=left, r=right: tile_of(
                    lambda d: paint_stairs_up(d, Neighbourhood(
                        "D", lambda x, y, l=l, r=r: "D"
                        if (x == -1 and l) or (x == 1 and r) else "."),
                        0, 0)), 1)
                for right in (False, True) for left in (False, True)],
                [neighbour_key(-1, 0, "D"), neighbour_key(1, 0, "D")]),
        ],
        "objects": [{
            "glyph": "M",
            "image": "termini_railcar.png",
            "tiles": list(TERMINI_RAILCAR_TILES),
            "sprite": station_railcar_sprite(
                TERMINI_RAILCAR_TILES, TERMINI_RAILCAR_DOOR_TILE, False),
            "whenOpen": "termini_railcar_open.png",
            "openSprite": station_railcar_sprite(
                TERMINI_RAILCAR_TILES, TERMINI_RAILCAR_DOOR_TILE, True),
        }, {
            "glyph": "Q",
            "image": "termini_sign_wall.png",
            "tiles": list(TERMINI_WALL_SIGN_TILES),
            "sprite": termini_wall_sign(),
        }, {
            "glyph": "o",
            "image": "termini_sign_platform.png",
            # Its board stands a tile above the posts' cells.
            "offsetY": -1,
            "sprite": termini_platform_sign(),
        }],
    }
    manifest = {
        "format": "stepbound-tile-atlas-v1",
        "tileWidth": TILE,
        "tileHeight": TILE,
        "layers": [layer for layer in LAYERS if layer != "objects"],
        "palette": "assets/palette.gpl",
        "atlas": ATLAS.replace(os.sep, "/"),
        "columns": COLUMNS,
        "places": {
            name: {
                "void": place["void"],
                "voidGlyph": place["voidGlyph"],
                **{key: place[key] for key in ("outside", "ground")
                   if key in place},
                "rules": place["rules"],
                "objects": [
                    {
                        k: manifest_place_asset(v)
                        if k in ("image", "whenOpen") else v
                        for k, v in obj.items()
                        if k not in ("sprite", "openSprite")
                    }
                    for obj in place["objects"]
                ],
            }
            for name, place in places.items()
        },
    }
    return atlas, {"manifest": manifest, "places": places}


def manifest_json(manifest: dict) -> str:
    """The manifest as JSON, indented for a diff to read, with every list
    of numbers kept on one line: a bucket is a handful of tile numbers,
    and one to a line made the city's rules half a megabyte of line
    breaks."""
    text = json.dumps(manifest, indent=2)
    text = re.sub(r"\[\s*(-?\d+(?:,\s*-?\d+)*)\s*\]",
                  lambda m: "[" + ", ".join(re.split(r",\s*", m.group(1)))
                  + "]", text)
    text = re.sub(r"\[\s*\]", "[]", text)
    # and a list of those lists -- the buckets of a rule -- on one line too
    text = re.sub(r"\[\s*(\[[^\[\]]*\](?:,\s*\[[^\[\]]*\])*)\s*\]",
                  lambda m: "[" + ", ".join(
                      re.findall(r"\[[^\[\]]*\]", m.group(1))) + "]", text)
    return text + "\n"


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
    os.makedirs(os.path.join(root, TILES), exist_ok=True)
    atlas.image(built["manifest"]["columns"]).save(
        os.path.join(root, ATLAS), optimize=True)
    for place in built["places"].values():
        for obj in place["objects"]:
            image_path = os.path.join(root, place_asset(obj["image"]))
            os.makedirs(os.path.dirname(image_path), exist_ok=True)
            save_object(obj["sprite"], image_path)
            if "openSprite" in obj:
                open_path = os.path.join(root, place_asset(obj["whenOpen"]))
                os.makedirs(os.path.dirname(open_path), exist_ok=True)
                save_object(obj["openSprite"], open_path)
    with open(os.path.join(root, MANIFEST), "w", encoding="utf-8") as out:
        out.write(manifest_json(built["manifest"]))
    print(f"{ATLAS}: {len(atlas.tiles)} tile")
    for name in sorted(built["places"]):
        print(f"  {name}: {len(built['places'][name]['rules'])} regole, "
              f"{len(built['places'][name]['objects'])} oggetti")


# The marker of each converted place's ASCII rows, for --preview only: the
# atlas itself never reads a place.
PREVIEW_ROWS = {
    "barracks": "barracks-rows",
    "church": "church-rows",
    "airlinerCabin": "airliner-cabin-rows",
    "airlinerRoofs": "airliner-roof-rows",
    "barArcobaleno": "bar-rows",
    "barBackroom": "bar-backroom-rows",
    "duomo": "duomo-rows",
    "duomoUpper": "duomo-upper-rows",
    "duomoSecondFloor": "duomo-second-rows",
    "duomoTower": "duomo-tower-rows",
    "duomoBells": "duomo-bells-rows",
    "duomoTowerRoof": "duomo-roof-rows",
    "mallFirst": "mall-first-rows",
    "mallGround": "mall-ground-rows",
    "station": "station-rows",
    "stationFarSide": "far-platform-rows",
    "stationUnderpass": "underpass-rows",
    "trainInterior": "train-interior-rows",
    **city.PREVIEW_ROWS,
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
        made = set()
        for directory, _, filenames in os.walk(os.path.join(tmp, PLACES_DIR)):
            for entry in filenames:
                fresh_path = os.path.join(directory, entry)
                relative = os.path.relpath(fresh_path, tmp)
                made.add(relative)
                committed = os.path.join(ROOT, relative)
                with Image.open(fresh_path) as fresh:
                    new = fresh.convert("RGBA")
                if not os.path.exists(committed):
                    raise SystemExit(f"{relative} is missing")
                with Image.open(committed) as a:
                    if a.convert("RGBA").tobytes() != new.tobytes():
                        raise SystemExit(
                            f"{relative} is out of date.\nRe-run it and "
                            f"commit the result:\n"
                            f"    python tools/build_tile_atlas.py")
                print(f"{relative}: up to date")
        committed_objects = set()
        for directory, _, filenames in os.walk(os.path.join(ROOT, PLACES_DIR)):
            for entry in filenames:
                committed_objects.add(os.path.relpath(
                    os.path.join(directory, entry), ROOT))
        left_over = sorted(committed_objects - made)
        if left_over:
            raise SystemExit(
                f"{PLACES_DIR} holds pictures no painter makes any more: "
                f"{', '.join(left_over)}. Delete them.")
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
