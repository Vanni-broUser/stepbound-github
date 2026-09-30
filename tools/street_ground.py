"""The city's floors: the road and its sidewalks, paving, parking, yards,
grass, the water of the harbour with its parapets and the pier.
tools/tile_atlas_city.py cuts what they paint into tiles.
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from street_paint import (  # noqa: E402
    ASPHALT,
    ASPHALT_SPECKLE,
    CRACK,
    CURB,
    CURB_SHADOW,
    LANE,
    NAIL,
    OIL,
    PAVING,
    PAVING_ALT,
    PAVING_JOINT,
    SEA,
    SEA_DARK,
    SEA_SPECKLE,
    SEA_WAVE,
    TILE,
    WALK,
    WALK_ALT,
    WALK_JOINT,
    ZEBRA,
    rect,
    shade,
)

# ----------------------------------------------------------------- ground


def paint_road(d, rng, level, x, y):
    px, py = x * TILE, y * TILE
    glyph = level.at(x, y)
    rect(d, px, py, TILE, TILE, ASPHALT)
    for _ in range(5):
        rect(d, px + rng.randrange(16), py + rng.randrange(16), 1, 1, ASPHALT_SPECKLE)
    if rng.random() < 0.18:
        cx, cy = px + rng.randrange(2, 12), py + rng.randrange(2, 14)
        for i in range(rng.randint(4, 9)):
            rect(d, cx + i, cy + (i * 3 % 4) - 1, 1, 1, CRACK)
    if rng.random() < 0.06:
        rect(d, px + 3, py + 5, 7, 3, OIL)
        rect(d, px + 5, py + 4, 3, 5, OIL)
    if glyph == "-":
        rect(d, px + 2, py + 7, 12, 2, LANE)
    elif glyph == "|":
        rect(d, px + 7, py + 2, 2, 12, LANE)
    elif glyph == "Z":
        for i in range(0, 16, 4):
            rect(d, px + 2, py + i + 1, 12, 2, ZEBRA)
    elif glyph == "V":
        for i in range(0, 16, 4):
            rect(d, px + i + 1, py + 2, 2, 12, ZEBRA)


def paint_sidewalk(d, rng, level, x, y):
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, WALK if (x + y) % 2 else WALK_ALT)
    rect(d, px, py, 1, TILE, WALK_JOINT)
    rect(d, px, py + 8, TILE, 1, WALK_JOINT)
    if rng.random() < 0.1:
        rect(d, px + rng.randrange(3, 12), py + rng.randrange(3, 12), 3, 1, WALK_JOINT)
    # curbs on every edge that touches the road
    if level.is_road(x, y + 1):
        rect(d, px, py + 14, TILE, 2, CURB)
        rect(d, px, py + 13, TILE, 1, CURB_SHADOW)
    if level.is_road(x, y - 1):
        rect(d, px, py, TILE, 2, CURB)
        rect(d, px, py + 2, TILE, 1, CURB_SHADOW)
    if level.is_road(x + 1, y):
        rect(d, px + 14, py, 2, TILE, CURB)
        rect(d, px + 13, py, 1, TILE, CURB_SHADOW)
    if level.is_road(x - 1, y):
        rect(d, px, py, 2, TILE, CURB)
        rect(d, px + 2, py, 1, TILE, CURB_SHADOW)


def paint_paving(d, rng, x, y):
    """Stone slabs of the square, two per tile, a few cracked or missing."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, PAVING if (x + y) % 2 else PAVING_ALT)
    rect(d, px, py, TILE, 1, PAVING_JOINT)
    rect(d, px + (0 if y % 2 else 8), py, 1, TILE, PAVING_JOINT)
    rect(d, px + (8 if y % 2 else 0), py + 8, 1, 8, PAVING_JOINT)
    rect(d, px, py + 8, TILE, 1, PAVING_JOINT)
    if rng.random() < 0.15:
        cx, cy = px + rng.randrange(2, 10), py + rng.randrange(2, 10)
        for i in range(5):
            rect(d, cx + i, cy + (i % 3), 1, 1, PAVING_JOINT)
    if rng.random() < 0.015:
        rect(d, px + 9, py + 1, 7, 7, (70, 66, 60))  # a slab has come away
        rect(d, px + 10, py + 2, 5, 5, (58, 52, 46))


def paint_parking(d, rng, level, x, y):
    """Asphalt of the car park with white stall lines; every third row is a
    driving aisle."""
    paint_road(d, rng, level, x, y)
    px, py = x * TILE, y * TILE
    if y % 3 != 2:
        rect(d, px, py + 1, 1, 14, (176, 172, 160))
    else:
        for i in range(0, 16, 8):
            rect(d, px + i + 2, py + 7, 4, 2, (176, 172, 160))


def paint_yard_floor(d, rng, x, y):
    """The shipyard's concrete: big poured slabs, cracked along their
    joints, stained with oil and old antifouling paint."""
    px, py = x * TILE, y * TILE
    slab = (104, 102, 98) if (x // 4 + y // 4) % 2 else (98, 96, 92)
    rect(d, px, py, TILE, TILE, slab)
    for _ in range(5):
        rect(d, px + rng.randrange(TILE), py + rng.randrange(TILE), 2, 1,
             shade(slab, rng.randint(-10, 8)))
    if x % 4 == 0:
        rect(d, px, py, 1, TILE, (78, 76, 74))
    if y % 4 == 0:
        rect(d, px, py, TILE, 1, (78, 76, 74))
    if rng.random() < 0.2:  # oil soaked into the slab
        rect(d, px + rng.randrange(9), py + rng.randrange(9), 6, 5, OIL)
    if rng.random() < 0.1:  # a splash of hull paint
        rect(d, px + rng.randrange(11), py + rng.randrange(12), 4, 3,
             rng.choice(((120, 60, 44), (60, 80, 104), (150, 146, 138))))


GRASS = [(62, 84, 44), (70, 92, 48), (56, 76, 40)]
GRASS_DRY = (110, 104, 62)


def paint_grass(d, rng, x, y):
    """Park lawn left to grow: uneven green, dry patches, tufts, a bit of
    bare earth."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, GRASS[(x * 3 + y * 5) % len(GRASS)])
    for _ in range(10):
        rect(d, px + rng.randrange(16), py + rng.randrange(15), 1, 2,
             rng.choice(GRASS + [GRASS_DRY]))
    if rng.random() < 0.25:
        rect(d, px + rng.randrange(10), py + rng.randrange(10), 5, 4, GRASS_DRY)
    if rng.random() < 0.08:
        rect(d, px + rng.randrange(8), py + rng.randrange(10), 6, 3, (84, 70, 52))


def paint_water(d, rng, x, y):
    """Dark, murky sea: a near-black teal with speckles and short ripples.
    The green scum floating on it is painted afterwards across tiles."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, SEA)
    for _ in range(3):  # darker swirls, so no two tiles look alike
        rect(d, px + rng.randrange(12), py + rng.randrange(14), rng.randint(3, 6), 2, SEA_DARK)
    for _ in range(6):
        rect(d, px + rng.randrange(16), py + rng.randrange(16), 1, 1, SEA_SPECKLE)
    for _ in range(2):
        wx, wy = px + rng.randrange(12), py + rng.randrange(1, 15)
        rect(d, wx, wy, rng.randint(2, 4), 1, SEA_WAVE)


def paint_parapet(d, rng, x, y):
    """Stone parapet of the seafront: the promenade behind it, then its
    pale capping and the face towards the sea, stained at the waterline."""
    px, py = x * TILE, y * TILE
    paint_water(d, rng, x, y)
    rect(d, px, py, TILE, 4, PAVING if x % 2 else PAVING_ALT)
    rect(d, px, py + 4, TILE, 3, (178, 168, 146))  # capping
    rect(d, px, py + 3, TILE, 1, (92, 86, 76))  # its inner edge
    rect(d, px, py + 6, TILE, 1, (140, 130, 112))
    rect(d, px, py + 7, TILE, 6, (126, 118, 102))  # face
    rect(d, px + (0 if x % 2 else 8), py + 7, 1, 6, (96, 90, 78))
    rect(d, px, py + 10, TILE, 1, (104, 98, 84))
    rect(d, px, py + 12, TILE, 1, (58, 70, 50))  # slime at the waterline
    rect(d, px, py + 13, TILE, 1, SEA_DARK)
    if rng.random() < 0.2:  # a chunk knocked out of the capping
        rect(d, px + rng.randrange(2, 11), py + 4, 4, 2, (86, 80, 70))
    if rng.random() < 0.12:  # rust streak from an old railing post
        rect(d, px + rng.randrange(2, 14), py + 7, 1, 5, (110, 64, 40))


def paint_parapet_west(d, rng, x, y):
    """The same parapet where the seafront turns south: the promenade to the
    east of it, the face towards the sea to the west."""
    px, py = x * TILE, y * TILE
    paint_water(d, rng, x, y)
    rect(d, px + 12, py, 4, TILE, PAVING if y % 2 else PAVING_ALT)
    rect(d, px + 9, py, 3, TILE, (178, 168, 146))  # capping
    rect(d, px + 12, py, 1, TILE, (92, 86, 76))
    rect(d, px + 9, py, 1, TILE, (140, 130, 112))
    rect(d, px + 3, py, 6, TILE, (126, 118, 102))  # face
    rect(d, px + 3, py + (0 if y % 2 else 8), 6, 1, (96, 90, 78))
    rect(d, px + 5, py, 1, TILE, (104, 98, 84))
    rect(d, px + 3, py, 1, TILE, (58, 70, 50))  # slime at the waterline
    rect(d, px + 2, py, 1, TILE, SEA_DARK)
    if rng.random() < 0.2:
        rect(d, px + 10, py + rng.randrange(2, 11), 2, 4, (86, 80, 70))
    if rng.random() < 0.12:
        rect(d, px + rng.randrange(4, 8), py + rng.randrange(2, 14), 5, 1, (110, 64, 40))


def paint_parapet_diagonal(d, rng, x, y, lower):
    """The parapet cut across a corner of the seafront at forty-five
    degrees, the promenade to the north-east and the sea to the south-west.
    The line runs through two cells a step: the one it enters from the west
    and, `lower`, the one under it it leaves through the south. Its bands
    are the plain parapet's, read along v - u instead of v, so that it
    meets the seafront's parapet west of it and the one running south under
    its last step without a seam."""
    px, py = x * TILE, y * TILE
    paint_water(d, rng, x, y)
    face, capping = (126, 118, 102), (178, 168, 146)
    for v in range(TILE):
        for u in range(TILE):
            s = v - u + (TILE if lower else 0)
            if s >= 14:
                continue  # the water, already painted
            colour = (PAVING if (u + v) // 8 % 2 else PAVING_ALT) if s <= 2                 else (92, 86, 76) if s == 3                 else capping if s <= 5                 else (140, 130, 112) if s == 6                 else (104, 98, 84) if s == 10                 else (58, 70, 50) if s == 12                 else SEA_DARK if s == 13                 else face
            rect(d, px + u, py + v, 1, 1, colour)
    if rng.random() < 0.3:  # a chunk knocked out of the capping
        u = rng.randrange(3, 10)
        v = u + 4 - (TILE if lower else 0)
        if 0 <= v < TILE - 2:
            rect(d, px + u, py + v, 2, 2, (86, 80, 70))


def paint_pier(d, rng, level, x, y):
    """Wooden pier over the water: grey weathered planks across it, a few
    missing, posts at the edges."""
    px, py = x * TILE, y * TILE
    paint_water(d, rng, x, y)
    plank, dark, rot = (132, 118, 96), (96, 84, 68), (70, 60, 50)
    rect(d, px, py, TILE, TILE, plank)
    for i in range(0, 16, 4):
        rect(d, px + i, py, 1, TILE, dark)
    if rng.random() < 0.18:  # a plank gone, the sea showing through
        gx = px + rng.randrange(0, 13, 4) + 1
        rect(d, gx, py, 3, TILE, SEA_DARK)
    if rng.random() < 0.3:
        rect(d, px + rng.randrange(13), py + rng.randrange(12), 3, 3, rot)
    for _ in range(4):
        rect(d, px + rng.randrange(16), py + rng.randrange(16), 1, 1, NAIL)
    if level.at(x, y - 1) != "l":
        rect(d, px, py, TILE, 1, (70, 62, 50))
        if x % 3 == 0:
            rect(d, px + 6, py - 2, 3, 3, (84, 66, 46))  # post
    if level.at(x, y + 1) != "l":
        rect(d, px, py + 13, TILE, 3, (60, 52, 44))  # its edge, then shadow
        rect(d, px, py + 15, TILE, 1, SEA_DARK)
        if x % 3 == 0:
            rect(d, px + 6, py + 13, 3, 3, (84, 66, 46))
