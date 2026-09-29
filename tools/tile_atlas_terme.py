"""Inside the Baths of Diocletian in the tile atlas: the vestibule behind
the portal of Santa Maria degli Angeli and the great hall beyond it
(lib/core/levels/rome/terme.dart).

A module of its own, the way docs/level_pipeline.md wants the interiors to
go: build_tile_atlas.py only lists it. The hall is the baths' frigidarium,
which Michelangelo made into the church: floors of coloured marble, walls
washed in ochre over the Roman brick, the eight columns of red granite the
Romans set up, and the brass meridian let into the floor. What stands
taller than its cell leans out over the row above (`leaning`).
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw

from street_paint import (  # noqa: E402
    BLOOD,
    BLOOD_DARK,
    OUTLINE,
    TILE,
    rect,
    shade,
)
from tile_atlas_core import (  # noqa: E402
    TRANSPARENT,
    Atlas,
    leaning,
    neighbour_key,
    pattern_key,
    rule,
    tile_of,
)

TM_WALL_TOP = (50, 40, 36)
TM_WALL_TOP_LIGHT = (84, 68, 58)
TM_OCHRE = (206, 164, 110)
TM_OCHRE_DARK = (170, 128, 84)
TM_BRICK = (160, 94, 64)
TM_MARBLE_A = (214, 206, 190)
TM_MARBLE_B = (188, 176, 160)
TM_PORPHYRY = (120, 44, 42)
TM_SERPENTINE = (58, 92, 64)
TM_JOINT = (150, 140, 124)
TM_GRANITE = (148, 64, 56)
TM_GRANITE_DARK = (104, 42, 38)
TM_GRANITE_LIGHT = (184, 100, 88)
TM_CAPITAL = (226, 220, 204)
TM_CAPITAL_SHADE = (184, 176, 160)
TM_BRASS = (200, 164, 70)
TM_BRASS_LIGHT = (236, 206, 120)
TM_PEW = (98, 66, 40)
TM_PEW_TOP = (134, 94, 58)
TM_PEW_DARK = (62, 42, 26)
TM_ALTAR = (224, 216, 198)
TM_ALTAR_SHADE = (176, 166, 146)
TM_GOLD = (190, 156, 66)
TM_SKY = (200, 206, 196)
TM_RUBBLE = [(206, 196, 176), (170, 128, 84), (160, 94, 64), (120, 112, 100)]
TM_WALLS = "xWIwOA"
# The north wall, in tiles: every `W` of the place.
TM_NORTH_TILES = (38, 2)


# ------------------------------------------------------------ the floor


def paint_floor(d, rng, px, py, grey, inlay):
    """Marble slabs two cells square, pale and grey by turns, and here and
    there a roundel of porphyry ringed in green serpentine, the way the
    Romans laid their floors and the Popes laid them again."""
    rect(d, px, py, TILE, TILE, TM_MARBLE_B if grey else TM_MARBLE_A)
    rect(d, px, py, TILE, 1, TM_JOINT)
    rect(d, px, py, 1, TILE, TM_JOINT)
    if inlay:
        d.ellipse([px + 3, py + 3, px + 12, py + 12], fill=TM_PORPHYRY)
        d.ellipse([px + 5, py + 5, px + 10, py + 10], fill=TM_SERPENTINE)
    for _ in range(4):  # the grime of a year shut up
        rect(d, px + rng.randrange(16), py + rng.randrange(16), 1, 1,
             shade(TM_MARBLE_B, -30))
    if rng.random() < 0.15:  # a crack across the slab
        cx, cy = px + rng.randrange(2, 10), py + rng.randrange(2, 12)
        for i in range(6):
            rect(d, cx + i, cy + (i % 3) - 1, 1, 1, (120, 110, 98))


def paint_meridian(d, rng, px, py, sign):
    """The meridian: a strip of brass down the middle of a band of white
    marble, and every few slabs one of the signs of the zodiac in coloured
    stone beside it, where the noon sun falls in its month."""
    paint_floor(d, rng, px, py, False, False)
    rect(d, px + 4, py, 8, TILE, (232, 228, 216))
    rect(d, px + 7, py, 2, TILE, TM_BRASS)
    rect(d, px + 7, py, 1, TILE, TM_BRASS_LIGHT)
    if sign:
        rect(d, px + 10, py + 4, 5, 8, (40, 70, 110))
        rect(d, px + 11, py + 5, 3, 6, TM_GOLD)


def paint_edge(d, px, py, right):
    """The foot of a side wall where the floor meets the darkness."""
    rect(d, px + (12 if right else 0), py, 4, TILE, TM_WALL_TOP)
    rect(d, px + (12 if right else 3), py, 1, TILE, TM_WALL_TOP_LIGHT)


# ------------------------------------------------------------ the walls


def paint_north_wall(d, rng, w, h):
    """The north wall of the hall face on: the dark where the vault
    springs, the ochre wash over the Roman brick, pilasters of painted
    marble, and between them the great altarpieces in their gilt frames,
    gone dark with smoke; the plaster fallen to the brick in places and a
    hand dragged down it."""
    rect(d, 0, 0, w, h, TM_OCHRE)
    rect(d, 0, 0, w, 5, TM_WALL_TOP)
    rect(d, 0, 5, w, 2, shade(TM_OCHRE, 26))  # the cornice
    rect(d, 0, h - 5, w, 4, TM_MARBLE_B)  # the skirting
    rect(d, 0, h - 1, w, 1, TM_JOINT)
    bay = w // 6
    for i in range(7):  # the pilasters
        px = min(i * bay, w - 6)
        rect(d, px, 7, 6, h - 12, TM_PORPHYRY)
        rect(d, px + 1, 7, 1, h - 12, shade(TM_PORPHYRY, 30))
        rect(d, px, 7, 6, 2, TM_CAPITAL)
    for i in range(6):  # the altarpieces, one to a bay
        fx = i * bay + 14
        fw = bay - 22
        rect(d, fx - 2, 9, fw + 4, h - 16, TM_GOLD)
        rect(d, fx, 11, fw, h - 20, (58, 44, 36))
        for _ in range(fw // 3):  # what can still be made out of them
            rect(d, fx + rng.randrange(fw - 4), 11 + rng.randrange(h - 24),
                 rng.randint(2, 5), rng.randint(1, 3),
                 rng.choice(((120, 90, 60), (90, 70, 80), (150, 120, 80),
                             (70, 80, 90))))
    for _ in range(w // 40):  # the plaster gone to the brick
        bx, by = rng.randrange(w - 14), 8 + rng.randrange(h - 16)
        rect(d, bx, by, rng.randint(6, 12), rng.randint(3, 5), TM_BRICK)
    sx = rng.randrange(w - 10)  # a hand dragged down it
    rect(d, sx, 12, 3, 4, BLOOD)
    rect(d, sx + 1, 16, 1, 8, BLOOD_DARK)


def paint_side_wall(d, px, py, wall_below):
    """A side wall, or the wall between the hall and the vestibule, seen
    from above: its top, thick as the baths' walls are, and where the floor
    is below it a short face of ochre down to the marble."""
    if wall_below:
        rect(d, px, py, TILE, TILE, TM_WALL_TOP)
        rect(d, px + 2, py, TILE - 4, TILE, TM_WALL_TOP_LIGHT)
        rect(d, px + 4, py, TILE - 8, TILE, TM_WALL_TOP)
        return
    rect(d, px, py, TILE, 6, TM_WALL_TOP)
    rect(d, px, py, TILE, 1, TM_WALL_TOP_LIGHT)
    rect(d, px, py + 6, TILE, 6, TM_OCHRE_DARK)
    rect(d, px, py + 12, TILE, 3, TM_MARBLE_B)
    rect(d, px, py + 15, TILE, 1, TM_JOINT)


def paint_front_wall(d, px, py):
    rect(d, px, py, TILE, 7, TM_WALL_TOP)
    rect(d, px, py, TILE, 1, TM_WALL_TOP_LIGHT)
    rect(d, px, py + 7, TILE, 9, (6, 6, 8))


def paint_portal(d, px, py):
    """The way out, the planks torn off it: the daylight of the road."""
    rect(d, px, py, TILE, TILE, TM_WALL_TOP)
    rect(d, px + 3, py + 2, 10, TILE - 2, (170, 166, 154))
    rect(d, px + 3, py + 2, 10, 2, (206, 204, 196))
    rect(d, px, py + 9, 5, 3, (120, 88, 56))  # a plank hanging off it


# ------------------------------------------------------------ what stands


def paint_column(d, px, py):
    """One of the eight columns of red granite, seen from above and a
    little in front: its white capital leaning out over the row above, the
    shaft, polished once, and its base on the marble."""
    rect(d, px + 2, py + 12, 13, 4, (40, 30, 28))  # its shadow
    rect(d, px + 3, py - 8, 10, 22, TM_GRANITE)
    rect(d, px + 4, py - 8, 3, 22, TM_GRANITE_LIGHT)
    rect(d, px + 11, py - 8, 2, 22, TM_GRANITE_DARK)
    for sy in range(py - 6, py + 12, 3):  # the speckle of the granite
        rect(d, px + 5 + (sy * 7) % 6, sy, 1, 1, TM_GRANITE_DARK)
        rect(d, px + 8 + (sy * 5) % 4, sy + 1, 1, 1, TM_CAPITAL_SHADE)
    rect(d, px + 1, py - 14, 14, 7, TM_CAPITAL)  # the capital
    rect(d, px + 1, py - 9, 14, 2, TM_CAPITAL_SHADE)
    for vx in (px + 1, px + 12):  # its volutes
        rect(d, vx, py - 14, 3, 3, TM_CAPITAL_SHADE)
    rect(d, px + 2, py + 12, 12, 3, TM_CAPITAL)  # the base
    rect(d, px + 2, py + 14, 12, 1, TM_CAPITAL_SHADE)


def paint_altar(d, rng, px, py, top, first, last):
    """The high altar, `A`: marble up two steps, the frontal of coloured
    stone, the cloth pulled half off and the candlesticks knocked down."""
    if top:
        rect(d, px, py, TILE, 4, shade(TM_ALTAR, 18))
        rect(d, px, py + 4, TILE, 12, TM_ALTAR)
        rect(d, px + 2, py + 6, TILE - 4, 7, TM_PORPHYRY)
        rect(d, px + 4, py + 8, TILE - 8, 3, TM_SERPENTINE)
        if rng.random() < 0.5:
            rect(d, px + 3, py + 1, 10, 2, TM_GOLD)  # a candlestick down
    else:
        rect(d, px, py, TILE, TILE, TM_ALTAR_SHADE)
        rect(d, px, py, TILE, 3, TM_ALTAR)
        rect(d, px, py + 8, TILE, 3, shade(TM_ALTAR_SHADE, -18))
    if first:
        rect(d, px, py, 2, TILE, shade(TM_ALTAR_SHADE, -30))
    if last:
        rect(d, px + TILE - 2, py, 2, TILE, shade(TM_ALTAR_SHADE, -30))


def paint_pew(d, px, py, first, last):
    """A pew, `T`, facing the altar, shoved out of its rank."""
    skew = (px // TILE * 5 + py // TILE * 3) % 3 - 1
    rect(d, px, py + 11 + skew, TILE, 3, TM_PEW_DARK)
    rect(d, px, py + 3 + skew, TILE, 8, TM_PEW)
    rect(d, px, py + 3 + skew, TILE, 2, TM_PEW_TOP)
    rect(d, px, py + 9 + skew, TILE, 1, TM_PEW_DARK)
    if first:
        rect(d, px, py + 3 + skew, 2, 11, TM_PEW_DARK)
    if last:
        rect(d, px + TILE - 2, py + 3 + skew, 2, 11, TM_PEW_DARK)


def paint_drum(d, px, py):
    """A drum of granite on its side, `K`, rolled off a fallen pillar."""
    rect(d, px, py + 2, TILE, 12, OUTLINE)
    rect(d, px + 1, py + 3, 14, 10, TM_GRANITE)
    rect(d, px + 1, py + 3, 14, 3, TM_GRANITE_LIGHT)
    rect(d, px + 1, py + 10, 14, 3, TM_GRANITE_DARK)
    rect(d, px + 12, py + 3, 3, 10, TM_CAPITAL_SHADE)  # the broken face


def paint_rubble(d, rng, px, py):
    """Plaster, stucco and window glass come down off the vault."""
    for _ in range(3):
        rect(d, px + rng.randrange(11), py + rng.randrange(11),
             rng.randint(3, 5), rng.randint(2, 3), rng.choice(TM_RUBBLE))
    for _ in range(8):
        rect(d, px + rng.randrange(15), py + rng.randrange(15),
             rng.randint(1, 3), 1, rng.choice(TM_RUBBLE))
    if rng.random() < 0.4:
        rect(d, px + rng.randrange(12), py + rng.randrange(12), 3, 1,
             (170, 190, 184))


def paint_blood(d, rng, px, py):
    rect(d, px + 3, py + 5, 9, 6, BLOOD)
    rect(d, px + 5, py + 3, 5, 10, BLOOD)
    rect(d, px + 6, py + 6, 3, 3, BLOOD_DARK)
    for _ in range(4):
        rect(d, px + rng.randrange(16), py + rng.randrange(16), 1, 1, BLOOD)


def paint_daylight(d, rng, px, py):
    """Under a thermal window high in the wall: the half-moon of daylight
    it throws on the marble, parted by the shadows of its two mullions."""
    rect(d, px + 1, py + 3, 14, 11, shade(TM_MARBLE_A, 18))
    d.ellipse([px + 1, py + 1, px + 14, py + 12], fill=TM_SKY)
    rect(d, px + 1, py + 7, 14, 6, TM_SKY)
    for mx in (px + 5, px + 10):
        rect(d, mx, py + 2, 1, 11, shade(TM_MARBLE_A, -20))
    for _ in range(4):  # the dust turning in it
        rect(d, px + rng.randrange(15), py + rng.randrange(13), 1, 1,
             (236, 236, 226))


# ------------------------------------------------------------ the rules


def terme_diocleziano(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.termeDiocleziano."""
    def one(paint):
        return [atlas.bucket(lambda: tile_of(lambda d: paint(d, 0, 0)), 1)]

    def randomly(paint):
        return [atlas.bucket(lambda: tile_of(lambda d: paint(d, rng, 0, 0)))]

    floored = ".:b^TKEAO"
    # Slabs two cells square, grey on (x // 2 + y // 2) odd; a roundel
    # where x % 4 and y % 4 are both 1.
    def slab(index):
        grey, across, down = bool(index & 1), bool(index & 2), bool(index & 4)
        return atlas.bucket(lambda: tile_of(lambda d: paint_floor(
            d, rng, 0, 0, grey, across and down)))
    rules = [rule("ground", floored, [slab(i) for i in range(8)],
                  [pattern_key(1, 1, 2, 1, div=(2, 2)),
                   pattern_key(1, 0, 4, 1), pattern_key(0, 1, 4, 1)])]
    for right in (False, True):
        rules.append(rule(
            "ground", floored,
            [[], atlas.bucket(lambda r=right: tile_of(
                lambda d: paint_edge(d, 0, 0, r)), 1)],
            [neighbour_key(1 if right else -1, 0, "x")]))
    # A sign of the zodiac on every third slab of the meridian.
    rules.append(rule("ground", "m", [atlas.bucket(
        lambda s=sign: tile_of(lambda d: paint_meridian(d, rng, 0, 0, s)))
        for sign in (False, True)], [pattern_key(0, 1, 3, 0)]))

    rules.append(rule(
        "structures", "I",
        [atlas.bucket(lambda b=below: tile_of(
            lambda d: paint_side_wall(d, 0, 0, b)), 1)
         for below in (False, True)],
        [neighbour_key(0, 1, TM_WALLS)]))
    rules.append(rule("structures", "w", one(paint_front_wall)))
    rules.append(rule("structures", "E", one(paint_portal)))
    rules.append(rule("structures", ":", randomly(paint_rubble)))
    rules.append(rule("structures", "b", randomly(paint_blood)))
    rules.append(rule("structures", "^", randomly(paint_daylight)))
    rules.append(rule("structures", "K", one(paint_drum)))

    keys = [neighbour_key(-1, 0, "T"), neighbour_key(1, 0, "T")]
    rules.append(rule("structures", "T", [atlas.bucket(
        lambda i=index: tile_of(lambda d: paint_pew(
            d, 0, 0, not i & 1, not i & 2)), 1) for index in range(4)], keys))
    keys = [neighbour_key(-1, 0, "A"), neighbour_key(1, 0, "A"),
            neighbour_key(0, -1, "A")]
    rules.append(rule("structures", "A", [atlas.bucket(
        lambda i=index: tile_of(lambda d: paint_altar(
            d, rng, 0, 0, not i & 4, not i & 1, not i & 2)))
        for index in range(8)], keys))
    buckets, up = leaning(atlas, lambda i: paint_column, None, 1)
    rules.append(rule("structures", "O", buckets, pieces=up))
    w, h = (n * TILE for n in TM_NORTH_TILES)
    north = Image.new("RGBA", (w, h), TRANSPARENT)
    paint_north_wall(ImageDraw.Draw(north), rng, w, h)
    return {"void": "#000000", "voidGlyph": "x", "rules": rules,
            "objects": [{"glyph": "W",
                         "image": "termeDiocleziano_north_wall.png",
                         "tiles": list(TM_NORTH_TILES), "sprite": north}]}


PLACES = {
    "termeDiocleziano": terme_diocleziano,
}

PREVIEW_ROWS = {
    "termeDiocleziano": "terme-rows",
}
