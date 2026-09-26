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
import re
import sys
import tempfile

from PIL import Image, ImageChops, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_street_level import (  # noqa: E402
    BLOOD,
    BLOOD_DARK,
    DOOR_GREEN,
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
    tile_of,
)

# Tiles to a row of the atlas image: 64 keeps it square-ish and inside the
# 4096 pixels every phone's GPU takes, up to four thousand tiles.
COLUMNS = 64

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILES = os.path.join("assets", "tiles")
ATLAS = os.path.join(TILES, "atlas.png")
MANIFEST = os.path.join(TILES, "atlas_manifest.json")
OBJECTS = os.path.join(TILES, "objects")

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
    # `9`, `c` and `d` are where the mass ends: plain floor until then.
    floored = ".*:p123PTSUE9cd"
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




# The railcar is one object, not tiles: its grime runs across the grid. It
# is painted at the size of the run of `M` in the far platform's rows;
# test/levels/tile_atlas_test.dart fails if the rows stop agreeing.
RAILCAR_TILES = (27, 3)
# Counted from the west end. The train faces east, like the locomotive
# inside it: its red tail is at the west end and its door at the back,
# like the train's own way in; the east end is the locomotive's nose.
RAILCAR_DOOR_TILE = 4
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
        # The painter's red cab at the west end is the train's tail; the
        # east end is shaped into the locomotive's nose.
        width, height = (n * TILE for n in RAILCAR_TILES)
        sprite = Image.new("RGBA", (width, height), TRANSPARENT)
        station.paint_railcar(
            ImageDraw.Draw(sprite), random.Random(SEED + 1),
            (0, 0, width, height), wrecked=False,
            door_x=RAILCAR_DOOR_TILE * TILE, open_door=open_door,
        )
        paint_locomotive_nose(sprite)
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
    floored = ".SLTCh*bBuofkEPlVaG"
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
# doorways onto the forecourt, the ticket windows, and two wrecked trains
# that are objects, the railcar standing derailed across the near track and
# the coach on its side across the far one.

STATION_RAILCAR_TILES = (11, 3)
STATION_COACH_TILES = (9, 3)


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
        rule("ground", "-", rails, [neighbour_key(-1, 0, "-")]),
        rule("ground", ",Mm9", [ballast]),
        rule("ground", "=TKn",
             [platform(0, False), platform(1, False),
              platform(0, True), platform(1, True)],
             [parity_key(), first_row_key("=", 0, "eq")]),
        rule("ground", ":",
             [hall(0), hall(1), platform(0, False), platform(1, False)],
             [parity_key(), first_row_key("=", 2, "le")]),
        rule("ground", ".EObZ*+U", [hall(0), hall(1)], [parity_key()]),
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
    # The trains are objects, so the dark line along the sides of the place
    # has to lie over them: the foreground.
    for right in (False, True):
        edge = atlas.bucket(lambda r=right: tile_of(
            lambda d: paint_side_edge(d, 0, 0, r)), 1)
        rules.append(rule("foreground", "-,Mm9=TKn:b#EOU.Z*+",
                          [[], edge], [neighbour_key(1 if right else -1,
                                                     0, "x")]))
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
    station.paint_toppled_coach(ImageDraw.Draw(coach), rng,
                                (0, 0, coach.width, coach.height))
    return {
        "void": "#060608",
        "voidGlyph": "x",
        "rules": rules,
        "objects": [
            {"glyph": "M", "image": "station_hall_railcar.png",
             "tiles": list(STATION_RAILCAR_TILES), "sprite": railcar},
            {"glyph": "m", "image": "station_hall_coach.png",
             "tiles": list(STATION_COACH_TILES), "sprite": coach},
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
    # edge, and the gap itself.
    rules.append(rule(
        "structures", "%",
        [atlas.bucket(lambda p=parity, u=up: cell(
            lambda d, gx, gy: airliner.roof_far(
                d, rng, near("%", (p, 0), u="%" if u else "."), gx, gy),
            p, 0)) for parity in (0, 1) for up in (False, True)],
        [neighbour_key(0, -1, "%"), parity_key()]))
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
                    {k: v for k, v in obj.items()
                     if k not in ("sprite", "openSprite")}
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
        made = set(os.listdir(os.path.join(tmp, OBJECTS)))
        left_over = sorted(set(os.listdir(os.path.join(ROOT, OBJECTS)))
                           - made)
        if left_over:
            raise SystemExit(
                f"{OBJECTS} holds pictures no painter makes any more: "
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
