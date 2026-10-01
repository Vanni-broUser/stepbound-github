"""The church of San Nicola in the tile atlas: the nave of worn
flagstones, the pews shoved aside, the apse behind the altar, the hole in
the roof (lib/core/levels/hometown/church.dart).

A module of its own, the way docs/level_pipeline.md wants the interiors
to go: build_tile_atlas.py only lists it. The art came from
tools/build_church.py, which the atlas replaced.
"""
from __future__ import annotations

import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from street_paint import DOOR_GREEN, OUTLINE, TILE, rect, shade  # noqa: E402
from build_mall import paint_blood  # noqa: E402
from tile_atlas_core import (  # noqa: E402
    Atlas,
    Block,
    Neighbourhood,
    TRANSPARENT,
    cell,
    neighbour_key,
    pattern_key,
    rule,
    tile_of,
)

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


def paint_church_portal(d, px, py, west=True, east=True):
    """The way out, the leaves folded back and the square beyond them. A
    portal more than a cell wide has its leaves only at its two ends,
    [west] and [east]: between them the daylight runs on."""
    rect(d, px, py, TILE, TILE, (58, 54, 50))
    left = px + 4 if west else px
    right = px + TILE - 4 if east else px + TILE
    rect(d, left, py + 2, right - left, TILE - 2, (152, 146, 130))  # daylight
    for leaf, open_ in ((px, west), (px + TILE - 4, east)):
        if not open_:
            continue
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
    # Its leaves stand at the two ends of the portal, however wide.
    rules.append(rule("structures", "E", [atlas.bucket(
        lambda i=index: tile_of(lambda d: paint_church_portal(
            d, 0, 0, west=not i & 1, east=not i & 2)), 1)
        for index in range(4)],
        [neighbour_key(-1, 0, "E"), neighbour_key(1, 0, "E")]))
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
        "void": "#000000",
        "voidGlyph": "x",
        "rules": rules,
        "objects": [{"glyph": "W", "image": "church_apse.png",
                     "tiles": list(CH_APSE_TILES), "sprite": apse}],
    }
