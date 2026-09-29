"""The barracks of the carabinieri in the tile atlas: the office with its
desks, counter and cabinets, in the Pokemon-Emerald room style on a dark
background (lib/core/levels/hometown/barracks.dart).

A module of its own, the way docs/level_pipeline.md wants the interiors
to go: build_tile_atlas.py only lists it. The art came from
tools/build_barracks.py, which the atlas replaced.
"""
from __future__ import annotations

import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_street_level import (  # noqa: E402
    BLOOD,
    BLOOD_DARK,
    OUTLINE,
    TILE,
    paint_emblem,
    rect,
)
from tile_atlas_core import (  # noqa: E402
    Atlas,
    TRANSPARENT,
    leaning,
    neighbour_key,
    rule,
    tile_of,
)

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
        "void": "#000000",
        "voidGlyph": "x",
        "rules": rules,
        "objects": [{"glyph": "O", "image": "barracks_exit.png",
                     "offsetY": -2, "sprite": door}],
    }
