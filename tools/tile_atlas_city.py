"""The city's four places in the tile atlas: the street Mario wakes up in,
the north district, the street behind the hypermarket and the harbour.

tools/build_street_level.py used to bake them, and its painters are still
where the art is; what goes is the composition. The city was the part of
the plan that could still say no (see docs/level_pipeline.md), for one
reason above the others: the baker split every band of building into
palaces three to six tiles wide at random, so where one building ended was
state of the baker, not something the rows say. Here the split is a
pattern on the position instead -- a building starts every 15 columns at
0, 4 and 10, and every 4 rows -- so the rows alone decide it, and moving a
street moves its buildings with it.

What is left over is one-off pictures: the barracks, the hypermarket, the
hospital, the station, the Duomo, the church of San Nicola, the boat on the
stocks, the airliner, the named shops. They are objects, painted by the
baker's own painters and placed over the rows they were painted for, with
those rows kept beside them: tile_atlas_test.dart fails as soon as the
rows under one change.
"""
from __future__ import annotations

import math
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import street_airliner as plane  # noqa: E402
import street_buildings as buildings  # noqa: E402
import street_carousel as carousel  # noqa: E402
import street_ground as floors  # noqa: E402
import street_paint as brushes  # noqa: E402
import street_props as props  # noqa: E402
import build_termini as termini  # noqa: E402
from street_paint import TILE, rect, shade  # noqa: E402
from tile_atlas_core import (  # noqa: E402
    SEED,
    TRANSPARENT,
    Atlas,
    any_key,
    around,
    cell,
    find_cell,
    first_row_key,
    ground_config,
    neighbour_key,
    parity_key,
    pattern_key,
    rule,
    spread,
    tile_of,
)

ROAD = "".join(sorted(brushes.ROAD_GLYPHS))
# The stop line across a lane before a crossing: along the north edge of
# the cell, for traffic coming up from the south, or along its west edge,
# for traffic coming from the east.
STOP_NORTH, STOP_WEST = "▔", "▏"
# Where a centre line from the east bends round into the one going south:
# `c` the other way round.
BEND_EAST = "ɔ"
# The monument on the square south of the street of the company.
MONUMENT = "Ω"
# The children's carousel on the quay at the end of the harbour road.
CAROUSEL = "ç"
BUILDINGS = "BHfKMGW#%0]\"\u00a7\u00c6\u00a3"
FACADE = "Hf"
# A front and the doors set in it at street level: the floor over a door
# is not the street level, it has its windows like the rest.
FRONT = FACADE + "\u00ab"

GROUND = ground_config(
    buildings=BUILDINGS,
    roads=ROAD,
    walks="={}¦",
    floors="PLY,°",
    footway="T/F¤",
    keep="~bRlo5g",
    lawn="g",
    lawnProps="Apn^<",
)

# Rome: palazzi in ochre, Pompeian red, yellow and burnt orange, their
# trim travertine cream, under roofs of terracotta tiles.
ROME_FACADES = [
    ((200, 138, 70), (232, 220, 196)),
    ((170, 82, 58), (228, 214, 188)),
    ((214, 176, 104), (236, 226, 204)),
    ((192, 116, 76), (230, 218, 194)),
    ((222, 196, 150), (240, 232, 214)),
]
ROME_ROOFS = [(172, 84, 56), (158, 74, 50), (184, 96, 64), (150, 80, 60)]
ROME_SHUTTERS = [(92, 62, 40), (62, 84, 60), (110, 76, 46)]
ROME_BASE = (206, 198, 176)

# The asphalt the baker laid under everything, and what shows under the
# buildings the objects stand on.
VOID = "#%02x%02x%02x" % brushes.ASPHALT

# The roof of the barracks, a pale concrete a shade warmer than the city's.
BARRACKS_ROOF = (104, 98, 90)

# Where one building ends and the next begins, along a band of them: every
# 15 columns, buildings 4, 6 and 5 wide, and every 4 rows down a block.
SPAN = 15
STARTS = (0, 4, 10)
ENDS = (3, 9, 14)
BLOCK_ROWS = 4


class Around:
    """A made-up street round a cell, for a painter that looks at its
    neighbours while one of its tiles is painted. `cells` holds what the
    cells round `origin` show, by offset; the rest shows `default`."""

    def __init__(self, cells=None, default=".", origin=(0, 0),
                 surfaces=None, **options):
        self.cells = cells or {}
        self.default = default
        self.origin = origin
        self.surfaces = surfaces or {}
        self.rows = []
        self.width = self.height = 0
        self.storefronts = {}
        self.old_town = options.get("old_town", False)
        self.one_roof = None

    def at(self, x, y):
        return self.cells.get((x - self.origin[0], y - self.origin[1]),
                              self.default)

    def is_road(self, x, y):
        return self.at(x, y) in brushes.ROAD_GLYPHS

    def is_building(self, x, y):
        return self.at(x, y) in brushes.BUILDING_GLYPHS

    def surface(self, x, y):
        return self.surfaces.get((x - self.origin[0], y - self.origin[1]),
                                 "=")


def image_of(d) -> Image.Image:
    """The picture an ImageDraw draws on: some of the baker's painters paste
    sprites, the bodies, instead of drawing rectangles."""
    return d._image  # noqa: SLF001 - Pillow keeps it there


def bits(index: int, count: int) -> list[bool]:
    return [bool(index >> bit & 1) for bit in range(count)]


# ---------------------------------------------------------------- the ground


def one(atlas: Atlas, paint):
    return [atlas.bucket(lambda: tile_of(lambda d: paint(d, 0, 0)), 1)]


def randomly(atlas: Atlas, rng, paint):
    return [atlas.bucket(lambda: tile_of(lambda d: paint(d, rng, 0, 0)))]


def paint_marking(d, glyph):
    """The markings the baker painted over a road tile of `glyph`."""
    if glyph == "-":
        rect(d, 2, 7, 12, 2, brushes.LANE)
    elif glyph == "|":
        rect(d, 7, 2, 2, 12, brushes.LANE)
    elif glyph == "Z":
        for i in range(0, 16, 4):
            rect(d, 2, i + 1, 12, 2, brushes.ZEBRA)
    elif glyph == "V":
        for i in range(0, 16, 4):
            rect(d, i + 1, 2, 2, 12, brushes.ZEBRA)
    elif glyph == STOP_NORTH:
        rect(d, 1, 0, 14, 3, brushes.ZEBRA)
    elif glyph == STOP_WEST:
        rect(d, 0, 1, 3, 14, brushes.ZEBRA)


def paint_curb(d, side):
    """The kerb along one side of a pavement tile that touches the road."""
    if side == "s":
        rect(d, 0, 14, TILE, 2, brushes.CURB)
        rect(d, 0, 13, TILE, 1, brushes.CURB_SHADOW)
    elif side == "n":
        rect(d, 0, 0, TILE, 2, brushes.CURB)
        rect(d, 0, 2, TILE, 1, brushes.CURB_SHADOW)
    elif side == "e":
        rect(d, 14, 0, 2, TILE, brushes.CURB)
        rect(d, 13, 0, 1, TILE, brushes.CURB_SHADOW)
    else:
        rect(d, 0, 0, 2, TILE, brushes.CURB)
        rect(d, 2, 0, 1, TILE, brushes.CURB_SHADOW)


def paint_algae(d, rng):
    """A slick of green scum on the sea, kept to its tile: the baker's
    blobs ran across tiles, these are the same ragged dithered things
    one tile at a time."""
    cx, cy = rng.randrange(4, 12), rng.randrange(4, 12)
    rx, ry = rng.randint(4, 8), rng.randint(2, 4)
    for py in range(max(0, cy - ry), min(TILE, cy + ry + 1)):
        for px in range(max(0, cx - rx), min(TILE, cx + rx + 1)):
            inside = ((px - cx) / rx) ** 2 + ((py - cy) / ry) ** 2
            wobble = 0.15 * math.sin(px * 0.7 + cy) + 0.1 * math.cos(
                py * 1.3 + cx)
            if inside + wobble > 1:
                continue
            if inside > 0.55 and (px + py) % 2:
                continue
            colour = brushes.ALGAE[0] if inside > 0.55 else \
                brushes.ALGAE[1 + (rng.random() < 0.25)]
            rect(d, px, py, 1, 1, colour)


def ground_rules(atlas: Atlas, rng) -> list[dict]:
    """The floors of the city, the same four places over. Each is the
    baker's own painter, painted where its patterns want it."""
    rules = []

    # The carriageway, and the markings on it, which belong to the glyph:
    # a car in the road stands on bare asphalt.
    rules.append(rule("ground", ".", randomly(
        atlas, rng, lambda d, r, x, y: floors.paint_road(d, r, Around(), x, y))))
    for glyph in "-|ZV" + STOP_NORTH + STOP_WEST:
        rules.append(rule("ground", glyph, [atlas.bucket(lambda g=glyph:
                          tile_of(lambda d: paint_marking(d, g)), 1)],
                          on="glyph"))
    # The car park, a stall line on every row but the aisles, y % 3 == 2.
    rules.append(rule("ground", "L", [atlas.bucket(lambda a=aisle: cell(
        lambda d, gx, gy: floors.paint_parking(
            d, rng, Around(default="L", origin=(gx, gy)), gx, gy),
        0, 2 if a else 0)) for aisle in (False, True)],
        [pattern_key(0, 1, 3, 2)]))

    # The pavement, its slabs alternating, a kerb on each side the road is.
    rules.append(rule("ground", "=", [atlas.bucket(lambda p=parity: cell(
        lambda d, gx, gy: floors.paint_sidewalk(
            d, rng, Around(default="=", origin=(gx, gy)), gx, gy), p, 0))
        for parity in (0, 1)], [parity_key()]))
    for side, (dx, dy) in (("s", (0, 1)), ("n", (0, -1)), ("e", (1, 0)),
                           ("w", (-1, 0))):
        rules.append(rule("ground", "=", [[], atlas.bucket(
            lambda s=side: tile_of(lambda d: paint_curb(d, s)), 1)],
            [neighbour_key(dx, dy, ROAD)]))

    # The paved squares: the slabs alternate on the parity of x + y, and
    # their joints on the parity of y.
    def paving(index):
        odd, odd_row = bits(index, 2)
        gx, gy = find_cell(lambda x, y: (x + y) % 2 == odd
                           and y % 2 == odd_row)
        return atlas.bucket(lambda: cell(
            lambda d, x, y: floors.paint_paving(d, rng, x, y), gx, gy))
    rules.append(rule("ground", "P", [paving(i) for i in range(4)],
                      [parity_key(), pattern_key(0, 1, 2, 1)]))

    # The hospital's steps: a handrail where the flight ends either side,
    # and the blood on every fifth step, (x * 7 + y * 3) % 5 == 0.
    def stairs(index):
        left, right, blood = bits(index, 3)
        gx, gy = find_cell(lambda x, y: ((x * 7 + y * 3) % 5 == 0) == blood)
        level = Around(origin=(gx, gy), surfaces={
            (-1, 0): "Y" if left else "=", (1, 0): "Y" if right else "="})
        return atlas.bucket(lambda: cell(
            lambda d, x, y: buildings.paint_stairs(d, level, x, y), gx, gy), 1)
    rules.append(rule("ground", "Y", [stairs(i) for i in range(8)],
                      [neighbour_key(-1, 0, "Y", ground=True),
                       neighbour_key(1, 0, "Y", ground=True),
                       pattern_key(7, 3, 5, 0)]))

    # The shipyard's concrete: poured in slabs four cells square.
    def yard(index):
        slab, west, north = bits(index, 3)
        gx, gy = find_cell(lambda x, y: ((x // 4 + y // 4) % 2 == 1) == slab
                           and (x % 4 == 0) == west and (y % 4 == 0) == north)
        return atlas.bucket(lambda: cell(
            lambda d, x, y: floors.paint_yard_floor(d, rng, x, y), gx, gy))
    rules.append(rule("ground", ",", [yard(i) for i in range(8)],
                      [pattern_key(1, 1, 2, 1, div=(4, 4)),
                       pattern_key(1, 0, 4, 0), pattern_key(0, 1, 4, 0)]))

    # The lawn, three greens on (x * 3 + y * 5) % 3.
    def lawn(index):
        one_, two = bits(index, 2)
        if one_ and two:
            return []
        want = 1 if one_ else 2 if two else 0
        gx, gy = find_cell(lambda x, y: (x * 3 + y * 5) % 3 == want)
        return atlas.bucket(lambda: cell(
            lambda d, x, y: floors.paint_grass(d, rng, x, y), gx, gy))
    rules.append(rule("ground", "g", [lawn(i) for i in range(4)],
                      [pattern_key(3, 5, 3, 1), pattern_key(3, 5, 3, 2)]))

    # The sea, with the scum on it, and under the boats.
    rules.append(rule("ground", "~bo5", randomly(
        atlas, rng, lambda d, r, x, y: floors.paint_water(d, r, x, y))))
    algae = atlas.odds(lambda: tile_of(
        lambda d: paint_algae(d, rng) if rng.random() < 0.35 else None), 24)
    rules.append(rule("ground", "~", [algae]))

    # The seafront's parapet: it faces west where the sea is west of it
    # and not south, and its stones alternate on the parity of x or y.
    def parapet(index):
        sea_west, sea_south, odd_x, odd_y = bits(index, 4)
        west = sea_west and not sea_south
        gx, gy = find_cell(lambda x, y: (x % 2 == 1) == odd_x
                           and (y % 2 == 1) == odd_y)
        paint = floors.paint_parapet_west if west else floors.paint_parapet
        return atlas.bucket(lambda: cell(
            lambda d, x, y: paint(d, rng, x, y), gx, gy))
    rules.append(rule("ground", "R", [parapet(i) for i in range(16)],
                      [neighbour_key(-1, 0, "~"), neighbour_key(0, 1, "~"),
                       pattern_key(1, 0, 2, 1), pattern_key(0, 1, 2, 1)]))

    # The pier: planks over the sea, its edges and, on every third column,
    # the posts standing up over them.
    keys = [neighbour_key(0, -1, "l"), neighbour_key(0, 1, "l"),
            pattern_key(1, 0, 3, 0)]

    def pier(index):
        above, below, post = bits(index, 3)
        level = Around({(0, -1): "l" if above else "~",
                        (0, 1): "l" if below else "~"}, default="~")
        tx, ty = find_cell(lambda x, y: (x % 3 == 0) == post, (0, 1))
        level.origin = (tx, ty)
        return (lambda d, px, py: floors.paint_pier(
            d, rng, level, px // TILE, py // TILE)), (tx, ty)
    buckets, pieces = spread(atlas, pier, keys, (0, 1, 0, 0))
    rules.append(rule("ground", "l", buckets, keys, pieces))
    return rules


# ----------------------------------------------------------------- the roofs


def segment_keys() -> list[dict]:
    """Which building of its band of 15 columns a cell is in: the first
    (4 wide), the second (6) or, neither, the third (5); and which band,
    odd or even, so that the colours of two bands next to each other do
    not meet the same."""
    return [pattern_key(1, 0, SPAN, values=range(0, 4)),
            pattern_key(1, 0, SPAN, values=range(4, 10)),
            pattern_key(1, 0, 2, 1, div=(SPAN, 1))]


def segment_of(first: bool, second: bool) -> int:
    return 0 if first else 1 if second else 2


def roof_fill(d, c, r):
    """A roof's tile in its colour `c`, with grit."""
    rect(d, 0, 0, TILE, TILE, c)
    dark = tuple(max(0, v - 20) for v in c)
    for _ in range(4):
        rect(d, r.randrange(TILE), r.randrange(TILE), 1, 1, dark)


def roof_unit(d, r):
    """What the baker scattered over a roof, one of them to a tile."""
    roll = r.random()
    ax, ay = r.randrange(3, 5), r.randrange(3, 6)
    if roll < 0.55:
        rect(d, ax, ay, 9, 6, (120, 120, 116))
        rect(d, ax + 1, ay + 1, 7, 1, (150, 150, 144))
        rect(d, ax, ay + 6, 9, 1, (46, 42, 40))
    elif roll < 0.8:
        rect(d, ax, ay, 4, 4, (90, 90, 88))
        rect(d, ax + 1, ay + 1, 2, 2, (40, 40, 42))
    else:
        rect(d, ax, ay, 10, 8, (50, 62, 76))
        rect(d, ax + 1, ay + 1, 8, 1, (90, 110, 130))


def roof_side(d, side, c):
    """The parapet along one side of a roof tile, "n", "w", "e" or "s"."""
    light = tuple(min(255, v + 24) for v in c)
    dark = tuple(max(0, v - 20) for v in c)
    if side == "n":
        rect(d, 0, 0, TILE, 2, light)
        rect(d, 0, 2, TILE, 1, dark)
    elif side == "w":
        rect(d, 0, 0, 2, TILE, light)
        rect(d, 2, 2, 1, TILE - 2, dark)
    elif side == "e":
        rect(d, TILE - 2, 0, 2, TILE, light)
    else:
        rect(d, 0, TILE - 2, TILE, 2, light)


def roof_street_side(d, c):
    """The top of the wall of a roof's side that faces the street."""
    rect(d, 0, TILE - 3, TILE, 3, tuple(min(255, v + 24) for v in c))


def paint_coppi(d, c, r):
    """A Roman roof tile, `B` in Rome: courses of curved terracotta tiles,
    their ridges catching the light and the channels between them dark, a
    tile slipped or broken here and there, lichen on the old ones."""
    light, dark = shade(c, 22), shade(c, -28)
    rect(d, 0, 0, TILE, TILE, c)
    for cy in range(0, TILE, 4):
        shift = 2 if (cy // 4) % 2 else 0
        for cx in range(-shift, TILE, 4):
            rect(d, cx, cy, 2, 3, light)
            rect(d, cx + 2, cy, 1, 3, dark)
        rect(d, 0, cy + 3, TILE, 1, shade(c, -40))
    for _ in range(r.randint(0, 2)):
        rect(d, r.randrange(TILE - 3), r.randrange(TILE - 2), 3, 2,
             r.choice((shade(c, -60), (120, 124, 96))))


def roof_chimney(d, r):
    """What stands on a tiled roof: a chimney pot, a TV aerial."""
    if r.random() < 0.6:
        cx, cy = r.randrange(3, 10), r.randrange(2, 8)
        rect(d, cx, cy, 5, 6, (190, 170, 150))
        rect(d, cx, cy, 5, 2, (120, 70, 50))
        rect(d, cx + 5, cy + 2, 2, 5, (60, 40, 34))
    else:
        ax, ay = r.randrange(3, 9), r.randrange(3, 9)
        rect(d, ax + 3, ay, 1, 7, (70, 70, 74))
        for i in range(3):
            rect(d, ax, ay + 1 + i * 2, 7 - i * 2 + 1, 1, (90, 90, 96))


def roof_rules(atlas: Atlas, rng, palette, region=None,
               coppi=False) -> list[dict]:
    """Every `B` is the roof of a building: a colour of `palette` to each
    building, grit on it, a unit or a skylight here and there, and a
    parapet along its edges -- where the band of roofs ends, or where the
    pattern of the position starts the next building. `region` is a pair
    of keys that hold outside the one building that has no splits in it
    at all, the back of the hypermarket."""
    colour_keys = segment_keys() + [pattern_key(0, 1, 2, 1,
                                                div=(1, BLOCK_ROWS))]
    region = region or []

    def colour(index) -> tuple:
        first, second, odd_band, odd_block = bits(index, 4)[:4]
        rest = bits(index >> 4, len(region))
        if region and not any(rest):
            return palette[0]
        if first and second:
            return None
        s = segment_of(first, second)
        return palette[(s + 3 * odd_band + 2 * odd_block) % len(palette)]

    fill = paint_coppi if coppi else roof_fill
    count = 2 ** (len(colour_keys) + len(region))
    fills = []
    for index in range(count):
        c = colour(index)
        fills.append([] if c is None else atlas.bucket(
            lambda c=c: tile_of(lambda d: fill(d, c, rng))))
    rules = [rule("structures", "B", fills, colour_keys + region)]

    unit = roof_chimney if coppi else roof_unit
    rules.append(rule("structures", "B", [atlas.odds(lambda: tile_of(
        lambda d: unit(d, rng) if rng.random() < 0.17 else None), 24)]))

    # The parapet, one side at a time. Each side's edge is the end of the
    # roofs or the start of the next building by the pattern -- except in
    # the one building, where only the end of the roofs counts.
    sides = (
        ("n", neighbour_key(0, -1, "B"),
         pattern_key(0, 1, BLOCK_ROWS, 0)),
        ("w", neighbour_key(-1, 0, "B"),
         pattern_key(1, 0, SPAN, values=STARTS)),
        ("e", neighbour_key(1, 0, "B"),
         pattern_key(1, 0, SPAN, values=ENDS)),
        ("s", neighbour_key(0, 1, "B"),
         pattern_key(0, 1, BLOCK_ROWS, BLOCK_ROWS - 1)),
    )

    keys_n = len(colour_keys) + len(region)
    for side, roof_there, split in sides:
        buckets = []
        for index in range(2 ** (keys_n + 2)):
            c = colour(index & (2 ** keys_n - 1))
            more, split_here = bits(index >> keys_n, 2)
            in_region = region and not any(bits(index >> 4, len(region)))
            edge = not more or (split_here and not in_region)
            buckets.append([] if c is None or not edge else atlas.bucket(
                lambda s=side, c=c: tile_of(lambda d: roof_side(d, s, c)),
                1))
        rules.append(rule("structures", "B", buckets,
                          colour_keys + region + [roof_there, split]))

    # The side of a building that faces the street shows the top of its
    # wall, a wider band of light; and its east side throws a shadow on
    # whatever is beside it.
    street = []
    for index in range(2 ** (keys_n + 1)):
        c = colour(index & (2 ** keys_n - 1))
        building_below = bits(index >> keys_n, 1)[0]
        street.append([] if c is None or building_below else atlas.bucket(
            lambda c=c: tile_of(lambda d: roof_street_side(d, c)), 1))
    rules.append(rule("structures", "B", street,
                      colour_keys + region
                      + [neighbour_key(0, 1, BUILDINGS)]))
    return rules


def roof_shadow_rule(atlas: Atlas, glyphs: str) -> dict:
    """The shadow a roof throws on the cell east of it."""
    return rule("structures", glyphs, [[], atlas.bucket(lambda: tile_of(
        lambda d: rect(d, 0, 0, 2, TILE, (30, 30, 34))), 1)],
        [neighbour_key(-1, 0, "B")])


# -------------------------------------------------------------- the facades


def facade_keys() -> list[dict]:
    return segment_keys() + [
        neighbour_key(0, -1, FACADE),
        neighbour_key(1, 0, FACADE),
        pattern_key(1, 0, SPAN, values=ENDS),
    ]


def facade_rules(atlas: Atlas, rng, old_town: bool,
                 rome: bool = False) -> list[dict]:
    """A band of `H` is the fronts of the buildings whose roofs are behind
    it, split where the roofs are: a colour to each building, a cornice
    along the top, windows, and on the street a shop or a door."""
    keys = facade_keys()
    colours = (brushes.OLD_TOWN_STONE if old_town
               else ROME_FACADES if rome else brushes.FACADES)

    def building(index):
        first, second, odd_band = bits(index, 3)
        if first and second:
            return None
        s = segment_of(first, second)
        return colours[(s + 3 * odd_band) % len(colours)]

    def paint_wall(d, c, top, east, r):
        if old_town:
            stone, joint = c, shade(c, -26)
            rect(d, 0, 0, TILE, TILE, stone)
            for row, cy in enumerate((4, 9, 14)):
                rect(d, 0, cy, TILE, 1, joint)
                for jx in range(0 if row % 2 else 5, TILE, 10):
                    rect(d, jx, cy - 4, 1, 4, joint)
            for _ in range(2):
                bx, by = r.randrange(TILE - 8), r.choice((0, 5, 10))
                rect(d, bx + 1, by, r.randint(4, 8), 4,
                     shade(stone, -r.randint(8, 18)))
            if top:
                rect(d, 0, 0, TILE, 3, shade(stone, 14))
                rect(d, 0, 3, TILE, 1, shade(stone, -44))
            if east:
                rect(d, TILE - 1, 0, 1, TILE, shade(stone, -40))
            return
        wall, trim = c
        rect(d, 0, 0, TILE, TILE, wall)
        if rome:
            # Plaster, patchy with age, and a heavy travertine cornice.
            for _ in range(5):
                rect(d, r.randrange(TILE - 3), r.randrange(TILE - 2),
                     r.randint(2, 5), r.randint(1, 3),
                     shade(wall, r.choice((-12, -8, 8))))
            if top:
                rect(d, 0, 0, TILE, 4, trim)
                rect(d, 0, 4, TILE, 1, shade(trim, -60))
                for dx in range(1, TILE, 4):
                    rect(d, dx, 2, 2, 2, shade(trim, -30))
            if east:
                rect(d, TILE - 2, 0, 2, TILE, shade(wall, -22))
            return
        if top:
            rect(d, 0, 0, TILE, 3, trim)
        if east:
            rect(d, TILE - 1, 0, 1, TILE, trim)

    walls = []
    for index in range(2 ** len(keys)):
        c = building(index)
        _, _, _, above, beside, split = bits(index, 6)
        top, east = not above, (not beside) or split
        walls.append([] if c is None else atlas.bucket(
            lambda c=c, t=top, e=east: tile_of(
                lambda d: paint_wall(d, c, t, e, rng)),
            4 if old_town or rome else 1))
    rules = [rule("structures", FACADE, walls, keys)]

    # The floors above the street: a window to each tile.
    colour_keys = segment_keys()

    def paint_window(d, c, r):
        if old_town:
            stone = c
            wx, wy = 5, 3
            rect(d, wx - 1, wy - 1, 8, 12, shade(stone, 18))
            rect(d, wx, wy, 6, 10, brushes.PANE if r.random() > 0.2
                 else brushes.PANE_BROKEN)
            green = r.choice(brushes.SHUTTERS)
            slat = shade(green, -30)
            roll = r.random()
            if roll < 0.4:
                rect(d, wx, wy, 6, 10, green)
                for ly in range(wy + 1, wy + 10, 2):
                    rect(d, wx, ly, 6, 1, slat)
                rect(d, wx + 3, wy, 1, 10, slat)
            elif roll < 0.8:
                for sx in (wx - 4, wx + 7):
                    rect(d, sx, wy, 3, 10, green)
                    for ly in range(wy + 1, wy + 10, 2):
                        rect(d, sx, ly, 3, 1, slat)
            elif roll < 0.92:
                rect(d, wx - 4, wy, 3, 10, green)
                for i in range(8):
                    rect(d, wx + 7 + i // 3, wy + 3 + i, 3, 1,
                         green if i % 2 else slat)
            if r.random() < 0.3:
                rect(d, wx - 3, wy + 10, 12, 1, (50, 50, 52))
                rect(d, wx - 3, wy + 7, 12, 1, (50, 50, 52))
                for i in range(0, 12, 2):
                    rect(d, wx - 3 + i, wy + 7, 1, 4, (50, 50, 52))
            return
        if rome:
            # A tall window in its travertine frame under a little
            # pediment, the wooden shutters open or shut, an iron railing
            # across it now and then.
            wall, trim = c
            wx, wy = 5, 4
            rect(d, wx - 1, wy - 1, 8, 12, trim)
            rect(d, wx, wy, 6, 10, brushes.PANE if r.random() > 0.2
                 else brushes.PANE_BROKEN)
            if r.random() < 0.5:
                d.polygon([(wx - 2, wy - 1), (wx + 3, wy - 4),
                           (wx + 8, wy - 1)], fill=trim)
                rect(d, wx - 2, wy - 1, 11, 1, shade(trim, -50))
            else:
                rect(d, wx - 2, wy - 3, 11, 2, trim)
                rect(d, wx - 2, wy - 1, 11, 1, shade(trim, -50))
            brown = r.choice(ROME_SHUTTERS)
            slat = shade(brown, -26)
            roll = r.random()
            if roll < 0.35:
                rect(d, wx, wy, 6, 10, brown)
                for ly in range(wy + 1, wy + 10, 2):
                    rect(d, wx, ly, 6, 1, slat)
            elif roll < 0.7:
                for sx in (wx - 4, wx + 7):
                    rect(d, sx, wy, 3, 10, brown)
                    for ly in range(wy + 1, wy + 10, 2):
                        rect(d, sx, ly, 3, 1, slat)
            if r.random() < 0.3:
                rect(d, wx - 2, wy + 7, 11, 1, (40, 40, 42))
                rect(d, wx - 2, wy + 10, 11, 1, (40, 40, 42))
                for i in range(0, 11, 2):
                    rect(d, wx - 2 + i, wy + 7, 1, 4, (40, 40, 42))
            rect(d, wx - 1, wy + 11, 8, 1, shade(trim, -40))
            return
        _, trim = c
        roll = r.random()
        pane = brushes.PANE if roll > 0.25 else (
            brushes.PANE_LIT if roll > 0.12 else brushes.PANE_BROKEN)
        rect(d, 4, 3, 8, 10, trim)
        rect(d, 5, 4, 6, 8, pane)
        if pane == brushes.PANE_BROKEN:
            rect(d, 6, 5, 2, 3, brushes.PANE)

    # A window on every floor above the street: the key holds where there
    # is more front below. The palazzi of the old town keep the floor over
    # the street for their tall doorways, so there it takes two.
    window_keys = colour_keys + [neighbour_key(0, 2 if old_town else 1,
                                               FRONT)]
    windows = []
    for index in range(2 ** len(window_keys)):
        c = building(index & 7)
        upstairs = bits(index, 4)[3]
        windows.append([] if c is None or not upstairs else atlas.odds(
            lambda c=c: tile_of(lambda d: paint_window(d, c, rng)), 24))
    rules.append(rule("structures", FACADE, windows, window_keys))

    # The street level: a door on the middle tile of each building. The
    # shops of Molfetta are the named ones (see storefronts); only Rome
    # tells its tall palazzi apart.
    keys = colour_keys + [neighbour_key(0, 1, FRONT),
                          neighbour_key(0, -3, FACADE),
                          pattern_key(1, 0, SPAN, values=(1, 6, 12))]

    def street_level(index):
        c = building(index & 7)
        above_street, tall, door = bits(index >> 3, 3)
        if c is None or above_street:
            return None
        if old_town:
            return (lambda d, px, py, c=c, dr=door:
                    paint_old_town_street(d, px, py, c, dr, rng))
        if rome:
            return (lambda d, px, py, c=c, dr=door, t=tall:
                    paint_rome_street(d, px, py, c, dr, t, rng))
        return lambda d, px, py, c=c, dr=door: paint_street_door(
            d, px, py, c, dr, rng)

    def paint_for(index):
        paint = street_level(index)
        return paint or (lambda d, px, py: None)

    buckets, pieces = spread(atlas, paint_for, keys, (0, 1, 0, 0), 24,
                             keep_odds=True)
    for index in range(len(buckets)):
        if street_level(index) is None:
            buckets[index] = []
            for extra in pieces:
                extra["buckets"][index] = []
    rules.append(rule("structures", FACADE, buckets, keys, pieces))
    rules.append(sliver_rule(atlas, rng, colours, old_town, rome,
                             paint_wall, paint_window))
    return rules


def sliver_rule(atlas: Atlas, rng, colours, old_town: bool, rome: bool,
                paint_wall, paint_window) -> dict:
    """No palazzo one column wide. The fronts are split into buildings on
    the pattern of the roofs, fifteen columns at a time, so where a band of
    fronts starts on the last column of one of them, or ends on the first,
    that column would stand alone. Painted over the rules above, it joins
    the building beside it instead: its colour, and no seam between them.
    A band of two columns, each the edge of its own building, becomes one
    building in the colour of the first."""
    keys = segment_keys() + [
        neighbour_key(-1, 0, FACADE),
        neighbour_key(1, 0, FACADE),
        neighbour_key(2, 0, FACADE),
        pattern_key(1, 0, SPAN, values=ENDS),
        pattern_key(1, 0, SPAN, values=STARTS),
        neighbour_key(0, -1, FACADE),
        neighbour_key(0, 1, FRONT),
    ]
    if old_town:
        keys.append(neighbour_key(0, 2, FRONT))

    def colour(segment, odd):
        return colours[(segment + 3 * odd) % len(colours)]

    made = {}

    def bucket(c, top, east, window, street):
        # The same tile for every index that asks for it.
        key = (c, top, east, window, street)
        if key not in made:
            def paint(d):
                paint_wall(d, c, top, east, rng)
                if window:
                    paint_window(d, c, rng)
                elif street and old_town:
                    paint_old_town_street(d, 0, 0, c, False, rng)
                elif street and rome:
                    paint_rome_street(d, 0, 0, c, False, False, rng)
                elif street:
                    paint_street_door(d, 0, 0, c, False, rng)
            made[key] = atlas.bucket(lambda: tile_of(paint),
                                     4 if window or street else 1)
        return made[key]

    buckets = []
    for index in range(2 ** len(keys)):
        (first, second, odd, left, right, far, end, start, above,
         front_below) = bits(index, 10)
        front_two_below = bits(index, 11)[10] if old_town else front_below
        if first and second:
            buckets.append([])
            continue
        s = segment_of(first, second)
        if end and right and not far:
            # The first of the last two: the next column joins it.
            c, east = colour(s, odd), False
        elif end and not left and right:
            # The first of a band, the last of its building: it joins the
            # next one.
            c, east = colour((s + 1) % 3, odd ^ (s == 2)), False
        elif start and left and not right:
            # The last of a band, the first of its building: it joins the
            # one before.
            c, east = colour((s - 1) % 3, odd ^ (s == 0)), True
        else:
            buckets.append([])
            continue
        buckets.append(bucket(c, not above, east, front_two_below,
                              not front_below))
    return rule("structures", FACADE, buckets, keys)


def paint_street_door(d, px, py, c, door, rng):
    """The street level of a short building: its door on the middle tile,
    boarded up more often than not, else shut; never kicked in, which
    would look like a way in where there is none. The rest of the front
    tagged, or an air conditioner hanging off it."""
    wall, trim = c
    if door:
        door_x, door_y = px + 2, py + 2
        rect(d, door_x - 1, door_y - 1, 14, 15, trim)
        rect(d, door_x, door_y, 12, 14, (50, 36, 30))
        rect(d, door_x + 2, door_y + 2, 8, 1, (80, 60, 50))
        if rng.random() < 0.65:
            buildings.paint_boarded_door(d, rng, door_x, door_y, 12, 14)
        return
    roll = rng.random()
    if roll < 0.3:
        rect(d, px + 4, py + 2, 9, 6, (180, 180, 174))
        rect(d, px + 5, py + 3, 5, 4, (120, 120, 116))
        rect(d, px + 8, py + 8, 1, 5, (60, 60, 62))
    elif roll < 0.55:
        for i in range(0, 14, 2):
            rect(d, px + 1 + i, py + 8 + (i % 4) // 2, 2, 1, (60, 150, 170))
        rect(d, px + 2, py + 11, 12, 1, (190, 60, 150))
    else:
        rect(d, px + 4, py + 2, 8, 10, trim)
        rect(d, px + 5, py + 3, 6, 8, brushes.PANE if rng.random() > 0.3
             else brushes.PANE_BROKEN)


def paint_rome_street(d, px, py, c, door, tall, rng):
    """The street level of a Roman palazzo: a rusticated travertine base,
    its courses cut deep; on the middle tile the great arched portone,
    dark wood and studs, and elsewhere a shop behind its steel shutter,
    the shutters of the tall ones tagged or forced."""
    rect(d, px, py, TILE, TILE, ROME_BASE)
    for cy in range(py + 3, py + TILE, 4):
        rect(d, px, cy, TILE, 1, shade(ROME_BASE, -44))
    rect(d, px, py, TILE, 2, shade(ROME_BASE, 18))
    if door:
        rect(d, px + 2, py + 3, 12, TILE - 3, shade(ROME_BASE, 14))
        d.ellipse([px + 3, py + 1, px + 12, py + 9], fill=(58, 36, 26))
        rect(d, px + 3, py + 5, 10, TILE - 5, (58, 36, 26))
        rect(d, px + 8, py + 5, 1, TILE - 5, (36, 22, 16))
        for sy in range(py + 7, py + TILE, 3):
            rect(d, px + 5, sy, 1, 1, (150, 120, 70))
            rect(d, px + 11, sy, 1, 1, (150, 120, 70))
        if rng.random() < 0.3:
            buildings.paint_boards(d, px + 4, py + 7, 8, 8)
        return
    if tall:
        rect(d, px + 1, py + 3, 14, TILE - 3, (40, 38, 38))
        for sy in range(py + 4, py + TILE, 2):
            rect(d, px + 1, sy, 14, 1, (132, 134, 138))
        if rng.random() < 0.4:
            for i in range(0, 12, 2):
                rect(d, px + 2 + i, py + 8 + (i % 4) // 2, 2, 1,
                     rng.choice(((200, 60, 150), (60, 170, 190),
                                 (230, 200, 60))))
        elif rng.random() < 0.3:
            rect(d, px + 1, py + 10, 14, TILE - 10, (16, 14, 16))
    elif rng.random() < 0.5:
        rect(d, px + 5, py + 4, 6, 7, (30, 30, 34))
        for i in range(0, 6, 2):
            rect(d, px + 5 + i, py + 4, 1, 7, (80, 80, 80))
    for _ in range(4):
        gx, gh = rng.randrange(TILE), rng.randint(2, 6)
        rect(d, px + gx, py + TILE - gh, 1, gh,
             shade(ROME_BASE, -rng.randint(30, 60)))


def paint_old_town_street(d, px, py, stone, door, rng):
    """The street level of a palazzo of the old town: an arched doorway
    with its green door on the middle tile, forced or boarded now and
    then; beside it a small barred window; soot climbing from the street
    all along."""
    if door:
        door_w, door_x, door_y = 10, px + 3, py + 1
        surround = shade(stone, 16)
        rect(d, door_x - 2, door_y + 1, door_w + 4, TILE - 2, surround)
        rect(d, door_x - 1, door_y - 1, door_w + 2, 2, surround)
        rect(d, door_x, door_y + 1, door_w, TILE - 2, brushes.DOOR_GREEN)
        rect(d, door_x + door_w // 2, door_y + 1, 1, TILE - 2,
             shade(brushes.DOOR_GREEN, -18))
        rect(d, door_x + 1, door_y + 1, door_w - 2, 3, (70, 70, 70))
        for i in range(1, door_w - 1, 2):
            rect(d, door_x + i, door_y + 2, 1, 1, (30, 30, 30))
        roll = rng.random()
        if roll < 0.2:
            rect(d, door_x + 1, door_y + 5, door_w - 2, TILE - 6,
                 (16, 12, 14))
        elif roll < 0.4:
            buildings.paint_boards(d, door_x, door_y + 5, door_w, 8)
    elif rng.random() < 0.5:
        rect(d, px + 5, py + 4, 6, 6, (30, 30, 34))
        for i in range(0, 6, 2):
            rect(d, px + 5 + i, py + 4, 1, 6, (80, 80, 80))
    for _ in range(5):
        gx, gh = rng.randrange(TILE), rng.randint(2, 7)
        rect(d, px + gx, py + TILE - gh, 1, gh,
             shade(stone, -rng.randint(30, 60)))


# ------------------------------------------------------------------ props


def rest_of(glyph: str, across: bool = False) -> list[dict]:
    """The keys that say a cell is the first of its picture: nothing of the
    same glyph west of it or north of it. A picture one row tall, `across`,
    only looks west: the same glyph north of it is another picture, like a
    car in the next lane, not the top of this one."""
    if across:
        return [neighbour_key(-1, 0, glyph)]
    return [neighbour_key(-1, 0, glyph), neighbour_key(0, -1, glyph)]


def anchored(atlas: Atlas, layer: str, glyph: str, paint, reach,
             keys=None, count=None, count_one=False, across=False) -> dict:
    """A picture over a run of `glyph`, drawn from its first cell: `paint`
    is handed the index of the extra `keys` and returns the painter.
    `across` is for a picture one row tall (see rest_of)."""
    keys = keys or []
    anchor = rest_of(glyph, across)
    all_keys = anchor + keys
    mask = (1 << len(anchor)) - 1

    def paint_for(index):
        if index & mask:
            return lambda d, px, py: None
        return paint(index >> len(anchor))

    buckets, pieces = spread(atlas, paint_for, all_keys, reach,
                             1 if count_one else (count or 12))
    for index in range(len(buckets)):
        if index & mask:
            buckets[index] = []
            for extra in pieces:
                extra["buckets"][index] = []
    return rule(layer, glyph, buckets, all_keys, pieces)


def prop_rules(atlas: Atlas, rng) -> list[dict]:
    """The baker's prop loop, glyph by glyph, in the foreground."""
    rules = []

    def single(glyph, paint, keys=None, reach=(0, 0, 0, 0), count=12):
        buckets, pieces = spread(atlas, paint, keys, reach, count)
        rules.append(rule("foreground", glyph, buckets, keys, pieces))

    # Debris: flattened rubbish next to the heaps, wreckage near the
    # airliner, and the ordinary kind everywhere else.
    near_heap = any_key(around(1), ";")
    near_wreck = any_key(around(1), "_+[")

    def debris(index):
        heap, wreck = bits(index, 2)
        if heap:
            return lambda d, px, py: props.paint_rubbish(d, rng, px, py, False)
        if wreck:
            return lambda d, px, py: plane.paint_airliner_wreckage(
                d, rng, px, py)
        return lambda d, px, py: props.paint_debris(d, rng, px, py)
    single(":", debris, [near_heap, near_wreck])
    single("d", lambda i: lambda d, px, py: props.paint_corpse(
        image_of(d), rng, px, py), reach=(1, 0, 1, 1))
    single("D", lambda i: lambda d, px, py: props.paint_corpse_pile(
        image_of(d), rng, px, py), reach=(1, 1, 1, 1))
    single("F", lambda i: props.paint_bin, count=1)
    single("S", lambda i: props.paint_campfire, count=1)
    single("J", lambda i: props.paint_road_block, count=1)
    single("Q", lambda i: props.paint_cafe_table, count=1)
    single("h", lambda i: buildings.paint_bar_doorway, count=1)
    # Wide open, its light falling out on the pavement below it.
    single("\u00ab", lambda i: buildings.paint_portone,
           reach=(0, 0, 0, 1), count=1)
    single(";", lambda i: lambda d, px, py: props.paint_rubbish(
        d, rng, px, py))
    # A trolley on its side where (x + y) is even.
    single("y", lambda i: lambda d, px, py: props.paint_trolley(
        d, px, py, tipped=not i), [parity_key()], count=1)
    # The churchyard gate: a pier where the gate ends, its leaf folded
    # flat against it.
    single("x", lambda i: lambda d, px, py: buildings.paint_gate(
        d, Around({(-1, 0): "x" if i & 1 else ".",
                   (1, 0): "x" if i & 2 else "."}, origin=(px // TILE, 0)),
        px, py, px // TILE, 0),
        [neighbour_key(-1, 0, "x"), neighbour_key(1, 0, "x")],
        (0, 1, 0, 0), 1)
    # The park: its railing, the gates in it, the rides of the playground,
    # (x * 7 + y * 3) % 3 of them.
    single("^", lambda i: lambda d, px, py: buildings.paint_railing(
        d, Around({(-1, 0): "^" if i & 1 else ".",
                   (1, 0): "^" if i & 2 else "."}, origin=(px // TILE,
                                                             py // TILE)),
        px // TILE, py // TILE),
        [neighbour_key(-1, 0, "^"), neighbour_key(1, 0, "^")], count=1)
    single("<", lambda i: lambda d, px, py: buildings.paint_park_gate(
        d, Around({(0, 1): "g" if i else "."}, origin=(px // TILE,
                                                       py // TILE)),
        px // TILE, py // TILE),
        [neighbour_key(0, 1, "gP")], (0, 1, 0, 0), 1)

    def ride(index):
        one_, two = bits(index, 2)
        kind = 1 if one_ else 2 if two else 0
        return lambda d, px, py: props.paint_playground(d, px, py, kind)
    single("p", ride, [pattern_key(7, 3, 3, 1), pattern_key(7, 3, 3, 2)],
           (0, 1, 0, 0), 1)
    # A flower bed, its earth darker along the top of a run of them.
    single("&", lambda i: lambda d, px, py: buildings.paint_flower_bed(
        d, rng, Around({(0, -1): "&" if i else "."}, origin=(px // TILE,
                                                             py // TILE)),
        px // TILE, py // TILE), [neighbour_key(0, -1, "&")])
    # The café's chairs, knocked over but for every third, and the litter
    # round them.

    def chair(index):
        def paint(d, px, py):
            props.paint_chair(d, px, py, toppled=not index)
            for _ in range(3):
                rect(d, px + rng.randrange(14), py + rng.randrange(14), 2, 1,
                     rng.choice(brushes.DEBRIS))
        return paint
    single("q", chair, [pattern_key(1, 1, 3, 0)])

    # The pictures over two cells or more, drawn from their first cell.
    colours = [(140, 40, 36), (70, 96, 130), (180, 170, 150), (60, 110, 80),
               (118, 118, 124), (162, 132, 62), (94, 78, 102),
               (198, 166, 112)]

    def car(burnt, flipped):
        return lambda i: lambda d, px, py: props.paint_car(
            d, px, py, rng.choice(colours), burnt=burnt, flipped=flipped)
    # Pile-ups stack cars of a kind lane on lane, so a car only looks
    # west for its other half.
    rules.append(anchored(atlas, "foreground", "C", car(False, False),
                          (1, 0, 2, 0), count=8, across=True))
    rules.append(anchored(atlas, "foreground", "X", car(True, False),
                          (1, 0, 2, 0), count=8, across=True))
    rules.append(anchored(atlas, "foreground", "U", car(False, True),
                          (1, 0, 2, 0), count=8, across=True))
    for glyph, burnt in (("v", False), ("k", True)):
        rules.append(anchored(
            atlas, "foreground", glyph,
            lambda i, b=burnt: lambda d, px, py: props.paint_car_vertical(
                d, px, py, rng.choice(colours), burnt=b),
            (0, 0, 0, 1), count=8))
    rules.append(anchored(atlas, "foreground", "a",
                          lambda i: props.paint_ambulance, (1, 1, 1, 0),
                          count_one=True))
    rules.append(anchored(atlas, "foreground", "n",
                          lambda i: props.paint_bench, (0, 0, 1, 0),
                          count_one=True))
    # A half-sunk boat, and from some, (x + y) % 3 == 1, two hands.
    rules.append(anchored(
        atlas, "foreground", "b",
        lambda i: lambda d, px, py: buildings.paint_boat(d, px, py, hands=bool(i)),
        (0, 1, 2, 0), [pattern_key(1, 1, 3, 1)], count_one=True))
    rules.append(anchored(atlas, "foreground", "!",
                          lambda i: buildings.paint_street_fountain, (0, 1, 1, 1),
                          count_one=True))
    # The back passage through the barracks and the hypermarket's fire
    # door, holes in the roofs round them.
    single("e", lambda i: lambda d, px, py: paint_back_passage(d, px, py),
           reach=(1, 0, 1, 0), count=1)
    single("j", lambda i: lambda d, px, py: paint_mall_back_door(d, px, py),
           reach=(1, 0, 1, 1), count=1)
    # A window on fire: the scorch on its frame; the flames are the game's.
    single("f", lambda i: lambda d, px, py: (
        rect(d, px + 2, py - 2, 12, 16, brushes.SCORCH),
        rect(d, px + 4, py + 4, 8, 9, (60, 20, 14)),
        rect(d, px + 3, py + 13, 10, 2, (40, 36, 36))),
        reach=(0, 1, 0, 0), count=1)
    return rules


def paint_back_passage(d, px, py):
    """The covered passage through the back of the barracks, `e`: an
    opening in the roofs, dark, with its steps going down."""
    rect(d, px - 2, py, 20, 16, (150, 136, 104))
    rect(d, px, py + 2, 16, 14, (26, 24, 26))
    rect(d, px + 2, py + 4, 12, 12, (44, 40, 40))
    rect(d, px + 3, py + 13, 10, 3, (80, 76, 70))
    rect(d, px + 3, py + 10, 10, 2, (66, 62, 58))


def paint_mall_back_door(d, px, py):
    """The hypermarket's fire exit `j`, seen from behind: only the opening
    shows, a concrete well biting one tile into the roof, the door swung
    open at its top and the exit sign lit at the bottom."""
    well = py + TILE
    rect(d, px - 2, py, 20, TILE * 2, (112, 108, 102))
    rect(d, px - 2, well + TILE - 3, 20, 3, (76, 74, 70))
    rect(d, px, py + 2, TILE, 14, (24, 24, 26))
    rect(d, px + 2, py + 4, 12, 12, (46, 44, 44))
    rect(d, px + 2, py + 13, 12, 3, (80, 76, 70))
    rect(d, px, py + 2, 4, 14, (118, 122, 130))
    rect(d, px + 1, py + 3, 2, 12, (158, 162, 170))
    rect(d, px + 3, py + 9, 1, 2, (220, 190, 90))
    rect(d, px + 4, well + 5, 8, 5, (30, 120, 60))
    rect(d, px + 6, well + 6, 4, 3, (210, 250, 220))


def paint_road_blood(d, rng, px, py):
    """A pool of blood on the road, `>`: a pool gone dark at its heart,
    or a smear where something was dragged, and spatter round either."""
    if rng.random() < 0.5:
        w, h = rng.randint(7, 11), rng.randint(5, 8)
        x, y = px + rng.randint(1, 15 - w), py + rng.randint(2, 15 - h)
        rect(d, x, y + 1, w, h - 2, brushes.BLOOD)
        rect(d, x + 1, y, w - 2, h, brushes.BLOOD)
        rect(d, x + w // 3, y + h // 3, max(2, w // 3), max(2, h // 3),
             brushes.BLOOD_DARK)
    else:
        y = py + rng.randint(4, 10)
        for i in range(rng.randint(10, 14)):
            rect(d, px + 1 + i, y + (i // 4) % 2, 1, rng.randint(2, 3),
                 brushes.BLOOD_DARK if i % 3 else brushes.BLOOD)
    for _ in range(rng.randint(3, 6)):
        rect(d, px + rng.randrange(15), py + rng.randrange(15), 1, 1,
             brushes.BLOOD)


def paint_lane_bend(d, px, py):
    """Where a road turns, `c`: the line from the west curving round into
    the one going south, over the tile before it and the two below."""
    radius = TILE + TILE // 2
    cx, cy = px + 8 - radius, py + 8 + radius
    for step in range(0, 91, 3):
        a = math.radians(step)
        rect(d, round(cx + radius * math.sin(a)) - 1,
             round(cy - radius * math.cos(a)) - 1, 2, 2, brushes.LANE)


def paint_lane_bend_east(d, px, py):
    """`c` mirrored: the line from the east curving round into the one
    going south, over the tile after it and the two below."""
    radius = TILE + TILE // 2
    cx, cy = px + 8 + radius, py + 8 + radius
    for step in range(0, 91, 3):
        a = math.radians(step)
        rect(d, round(cx - radius * math.sin(a)) - 1,
             round(cy - radius * math.cos(a)) - 1, 2, 2, brushes.LANE)


def overhead_rules(atlas: Atlas, rng) -> list[dict]:
    """What stands into the tile above over everything else: the traffic
    lights, the road signs, the trees and the palms; and last, the grit the
    baker scattered over everything walkable."""
    rules = []

    def single(glyph, paint, keys=None, reach=(0, 0, 0, 0), count=12):
        buckets, pieces = spread(atlas, paint, keys, reach, count)
        rules.append(rule("overhead", glyph, buckets, keys, pieces))

    single("T", lambda i: props.paint_traffic_light, reach=(0, 1, 0, 0),
           count=1)

    # Give way where the road runs alongside, no entry where a road block
    # or a wreck closes the street, and the blue plate anywhere else.
    def sign(index):
        road, closed = bits(index, 2)
        kind = 0 if road else 1 if closed else 2
        return lambda d, px, py: props.paint_sign(d, px, py, kind)
    single("/", sign, [any_key(((-1, 0), (1, 0)), ROAD),
                       any_key(((-2, 0), (-1, 0), (1, 0), (2, 0)), "JCXU")],
           (0, 1, 0, 0), 1)
    single("A", lambda i: lambda d, px, py: props.paint_tree(d, rng, px, py),
           reach=(0, 2, 0, 0))
    single("N", lambda i: lambda d, px, py: buildings.paint_palm(d, rng, px, py),
           reach=(1, 2, 1, 0))

    def speck(d):
        if rng.random() < 0.33:
            rect(d, rng.randrange(TILE), rng.randrange(TILE),
                 rng.randint(1, 3), 1, rng.choice(brushes.DEBRIS))
    rules.append(rule("overhead", ROAD + "=:PL,", [atlas.odds(
        lambda: tile_of(speck), 24)]))
    return rules


# ------------------------------------------------------------ the objects


def picture(rows: list[str], level, name: str, paint, glyphs: str) -> dict:
    """One of the baker's one-off pictures, painted by its own painter over
    the whole place and cut to the tiles it reaches. It is placed where it
    was painted, and keeps the rows of the cells of `glyphs` it was painted
    for."""
    canvas = Image.new("RGBA", (len(rows[0]) * TILE, len(rows) * TILE),
                       TRANSPARENT)
    paint(ImageDraw.Draw(canvas), level)
    left, top, right, bottom = canvas.getbbox()
    x0, y0 = left // TILE, top // TILE
    x1, y1 = -(-right // TILE), -(-bottom // TILE)
    cells = [(x, y) for y in range(len(rows)) for x in range(len(rows[0]))
             if rows[y][x] in glyphs]
    gx0, gx1 = min(x for x, _ in cells), max(x for x, _ in cells)
    gy0, gy1 = min(y for _, y in cells), max(y for _, y in cells)
    return {
        "image": f"{name}.png",
        "sprite": canvas.crop((x0 * TILE, y0 * TILE, x1 * TILE, y1 * TILE)),
        "at": [x0, y0],
        "underAt": [gx0, gy0],
        "under": [rows[y][gx0:gx1 + 1] for y in range(gy0, gy1 + 1)],
    }


def lone_columns(level) -> list[int]:
    """The columns a shop leaves standing alone: between a shop and the
    next building, or two shops, one column of a building of its own.
    The sliver rule joins a lone column at the edge of a band of fronts to
    its neighbour; next to a shop there is nothing to join it to, so the
    tables must not leave one."""
    lone = []
    for x0, width, top, _ in brushes.column_runs(level,
                                                 brushes.FACADE_GLYPHS):
        x1 = x0 + width - 1
        shops = [(sx, sx + sw - 1) for sx, sw, _ in
                 level.storefronts.get(top, []) if x0 <= sx <= x1]
        pieces, x = [], x0
        while x <= x1:
            shop = next((s for s in shops if s[0] == x), None)
            if shop:
                pieces.append(("shop", shop[0], shop[1]))
                x = shop[1] + 1
                continue
            end = min([building_end(x), x1]
                      + [s[0] - 1 for s in shops if x < s[0]])
            pieces.append(("house", x, end))
            x = end + 1
        for i, (kind, a, b) in enumerate(pieces):
            if kind != "house" or a != b or width < 2:
                continue
            before = pieces[i - 1] if i else None
            after = pieces[i + 1] if i + 1 < len(pieces) else None
            joined = (a == x0 and after and after[0] == "house"
                      or a == x1 and before and before[0] == "house"
                      or before and before[0] == "house"
                      and before[1] == before[2] == x0
                      or after and after[0] == "house"
                      and after[1] == after[2] == x1)
            if not joined:
                lone.append(a)
    return lone


def storefronts(rows, level, name, rng) -> list[dict]:
    """The named shops along the bands of fronts, by the tables in
    street_buildings.py: each is painted for its band's height and
    placed where the table puts it."""
    out = []
    for x0, width, top, bottom in brushes.column_runs(level, brushes.FACADE_GLYPHS):
        for sx, sw, kind in level.storefronts.get(top, []):
            if not x0 <= sx < x0 + width:
                continue
            h = bottom - top + 1
            sprite = Image.new("RGBA", (sw * TILE, h * TILE), TRANSPARENT)
            buildings.paint_storefront(ImageDraw.Draw(sprite), rng, 0, 0,
                                sw * TILE, h * TILE, kind)
            out.append({
                "image": f"{name}_shop_{sx}_{top}.png",
                "sprite": sprite,
                "at": [sx, top],
                "under": [rows[y][sx:sx + sw] for y in range(top, bottom + 1)],
            })
    return out


def run_of(rows: list[str], glyphs: str):
    cells = [(x, y) for y in range(len(rows)) for x in range(len(rows[0]))
             if rows[y][x] in glyphs]
    if not cells:
        return None
    x0 = min(x for x, _ in cells)
    y0 = min(y for _, y in cells)
    return x0, y0, max(x for x, _ in cells) - x0 + 1, \
        max(y for _, y in cells) - y0 + 1


# -------------------------------------------------------------- the places

# Rules that are the same in every place are made once, from their own
# stream of random numbers, and shared: four copies of the city's asphalt
# would weigh four times as much and look the same.
_shared: dict[tuple[int, str], list[dict]] = {}


def shared(atlas: Atlas, name: str, make) -> list[dict]:
    """The rules `make` makes for the whole city, once per atlas."""
    key = (id(atlas), name)
    if key not in _shared:
        _shared[key] = make(random.Random(f"{SEED}/city/{name}"))
    return _shared[key]


def building_start(x: int) -> int:
    """The first column of the building of the roof pattern `x` is in."""
    return x - x % SPAN + max(s for s in STARTS if s <= x % SPAN)


def building_end(x: int) -> int:
    """The last column of the building of the roof pattern `x` is in."""
    return x - x % SPAN + min(e for e in ENDS if e >= x % SPAN)


def barracks_lots(rows: list[str]) -> list[tuple[tuple, tuple]]:
    """The buildings round the barracks, as (left, top, right, bottom) and
    colour: the pattern of the roofs would cut slivers of them against its
    front. The barracks has its roof behind its front and nowhere else;
    either side of it, the building the pattern puts there reaches up to
    it, in a band as tall as the roof behind and another as tall as the
    front; and the buildings under it rise to the forecourt's row, one row
    above where the pattern starts them, so nothing is left between."""
    cells = [(x, y) for y, row in enumerate(rows)
             for x, glyph in enumerate(row) if glyph == "K"]
    left = min(x for x, _ in cells)
    right = max(x for x, _ in cells)
    top = min(y for _, y in cells)
    bottom = max(y for _, y in cells)
    west = building_start(left - 2)
    east = building_end(right + 4)
    palette = brushes.ROOFS
    lots = [
        ((left, 0, right, top - 1), BARRACKS_ROOF),
        ((west, 0, left - 1, top), palette[0]),
        ((west, top + 1, left - 1, bottom), palette[2]),
        ((right + 1, 0, east, top), palette[3]),
        ((right + 1, top + 1, east, bottom), palette[1]),
    ]
    # Under it, the roofs of the next block, cut where the pattern cuts
    # them and where the road runs between them, each in a colour neither
    # the building above it nor the one before it has.
    under = bottom + 2
    low = under - under % BLOCK_ROWS + BLOCK_ROWS - 1

    def colour_under(x, end):
        above = {c for (l, _, r, b), c in lots
                 if b == bottom and l <= end and r >= x}
        before = {c for (_, t, r, _), c in lots if t == bottom + 1
                  and r == x - 1}
        return next(c for c in palette if c not in above | before)

    x = west
    while x <= east:
        if rows[under][x] != "B":
            x += 1
            continue
        end = x
        while (end + 1 <= east and rows[under][end + 1] == "B"
               and building_start(end + 1) != end + 1):
            end += 1
        lots.append(((x, bottom + 1, end, low), colour_under(x, end)))
        x = end + 1
    return lots


def barracks_block(rows: list[str], name: str) -> dict:
    """The roofs round the barracks, painted as one picture over the
    pattern's: see `barracks_lots`. Each keeps the grit, the units and the
    parapets of any roof, the parapets along its own edges."""
    lots = barracks_lots(rows)
    rng = random.Random(f"{SEED}/city/{name}/barracks-block")
    x0 = min(box[0] for box, _ in lots)
    y0 = min(box[1] for box, _ in lots)
    x1 = max(box[2] for box, _ in lots)
    y1 = max(box[3] for box, _ in lots)
    sprite = Image.new("RGBA", ((x1 - x0 + 1) * TILE, (y1 - y0 + 1) * TILE),
                       TRANSPARENT)

    def glyph(x, y):
        if 0 <= y < len(rows) and 0 <= x < len(rows[0]):
            return rows[y][x]
        return "B"

    for (left, top, right, bottom), c in lots:
        def inside(x, y, box=(left, top, right, bottom)):
            return box[0] <= x <= box[2] and box[1] <= y <= box[3]

        for y in range(top, bottom + 1):
            for x in range(left, right + 1):
                if glyph(x, y) != "B":
                    continue
                tile = tile_of(lambda d: None)
                d = ImageDraw.Draw(tile)
                roof_fill(d, c, rng)
                if rng.random() < 0.17:
                    roof_unit(d, rng)
                for side, (dx, dy) in (("n", (0, -1)), ("w", (-1, 0)),
                                       ("e", (1, 0)), ("s", (0, 1))):
                    if not inside(x + dx, y + dy) or \
                            glyph(x + dx, y + dy) != "B":
                        roof_side(d, side, c)
                if glyph(x, y + 1) not in BUILDINGS:
                    roof_street_side(d, c)
                sprite.alpha_composite(tile, ((x - x0) * TILE,
                                              (y - y0) * TILE))
    return {
        "image": f"{name}_barracks_block.png",
        "sprite": sprite,
        "at": [x0, y0],
        "under": [row[x0:x1 + 1] for row in rows[y0:y1 + 1]],
    }


def city_place(atlas: Atlas, rng, name: str, marker, storefront_table,
               old_town=False, one_roof=None, rome=False) -> dict:
    rows = brushes.read_rows(marker) if marker else brushes.read_rows()
    level = brushes.Level(rows, storefront_table, old_town=old_town,
                     one_roof=one_roof)
    glyphs = set("".join(rows))
    ground_glyphs = "".join(sorted(glyphs - set(BUILDINGS)))

    rules = list(shared(atlas, "ground", lambda r: ground_rules(atlas, r)))
    region = None
    if one_roof is not None:
        row, column = one_roof
        region = [first_row_key("j", -1, "le"),
                  pattern_key(1, 0, 2, 1, div=(column, 1))]
    palette = (brushes.OLD_TOWN_ROOFS if old_town
               else ROME_ROOFS if rome else brushes.ROOFS)
    style = "/rome" if rome else ""
    rules += shared(atlas, f"roofs/{old_town}/{bool(region)}{style}",
                    lambda r: roof_rules(atlas, r, palette, region,
                                         coppi=rome))
    rules.append(roof_shadow_rule(atlas, ground_glyphs))
    rules += shared(atlas, f"facades/{old_town}{style}",
                    lambda r: facade_rules(atlas, r, old_town, rome))
    if "]" in glyphs:
        # Under the front of Termini, which is its own picture.
        rules.append(rule("structures", "]", [atlas.bucket(lambda: tile_of(
            lambda d: rect(d, 0, 0, TILE, TILE, termini.TERMINI_STONE)),
            1)]))
        rules.append(rule("structures", "{", [atlas.bucket(lambda: tile_of(
            lambda d: rect(d, 0, 0, TILE, TILE, (18, 18, 22))), 1)]))
    if '"' in glyphs:
        # Under Santa Maria Maggiore, which is its own picture, and the
        # shadow at the foot of its column.
        rules.append(rule("structures", '"', [atlas.bucket(lambda: tile_of(
            lambda d: rect(d, 0, 0, TILE, TILE, termini.SMM_ROOF_DARK)),
            1)]))
        rules.append(rule("structures", ">`", [atlas.bucket(lambda: tile_of(
            lambda d: rect(d, 3, 10, 12, 5, (40, 38, 40))), 1)]))
    if termini.TERME in glyphs:
        # Under the Baths of Diocletian, which are their own picture, and
        # the dark of their open portal.
        rules.append(rule("structures", termini.TERME, [atlas.bucket(
            lambda: tile_of(lambda d: rect(d, 0, 0, TILE, TILE,
                                           termini.TERME_TOP)), 1)]))
        rules.append(rule("structures", termini.TERME_DOOR, [atlas.bucket(
            lambda: tile_of(lambda d: rect(d, 0, 0, TILE, TILE,
                                           (20, 16, 16))), 1)]))
    if "}" in glyphs:
        rules.append(rule("structures", "}", [
            atlas.bucket(lambda f=first: tile_of(
                lambda d: termini.paint_wall_breach(d, rng, 0, 0, f)))
            for first in (False, True)], [neighbour_key(-1, 0, "%")]))
    if "%" in glyphs:
        rules.append(yard_wall_rule(atlas, rng))
    if "c" in glyphs:
        buckets, pieces = spread(atlas, lambda i: paint_lane_bend, None,
                                 (2, 0, 0, 2), 1)
        rules.append(rule("structures", "c", buckets, None, pieces))
    if BEND_EAST in glyphs:
        buckets, pieces = spread(atlas, lambda i: paint_lane_bend_east, None,
                                 (0, 0, 2, 2), 1)
        rules.append(rule("structures", BEND_EAST, buckets, None, pieces))
    if ">" in glyphs and '"' not in glyphs:
        rules.append(rule("structures", ">",
                          randomly(atlas, rng, paint_road_blood)))
    if glyphs & set("_+["):
        scorched = "".join(sorted(set(ground_glyphs) - set("_+[")))
        rules.append(rule("structures", scorched, [[], atlas.bucket(
            lambda: tile_of(lambda d: plane.paint_airliner_scorch(
                d, rng, None, 0, 0)))], [any_key(around(1), "_+[")]))
    rules += shared(atlas, "props", lambda r: prop_rules(atlas, r))
    # The roadblock east of Termini, in Rome only (Molfetta's `m`, `s`,
    # `t`, `u` and `w` are other things): the carabinieri `m` and police
    # `s` cars on their roofs and `u` and `w` still on their wheels, two
    # cells each, stacked lane on lane, and the tank `t`.
    # Their own stream, so nothing else in the place is painted anew.
    block_rng = random.Random(f"{SEED}/{name}/roadblock")
    for glyph, police, paint in (
            ("m", False, termini.paint_service_car),
            ("s", True, termini.paint_service_car),
            ("u", False, termini.paint_service_car_upright),
            ("w", True, termini.paint_service_car_upright)):
        if rome and glyph in glyphs:
            rules.append(anchored(
                atlas, "foreground", glyph,
                lambda i, p=police, f=paint: lambda d, px, py: f(
                    d, block_rng, px, py, p),
                (1, 0, 2, 0), count=4, across=True))
    rules += shared(atlas, "overhead", lambda r: overhead_rules(atlas, r))

    lone = lone_columns(level)
    assert not lone, f"{name}: palazzi one column wide at {lone}"
    objects = storefronts(rows, level, name, rng)
    if "K" in glyphs:
        objects.insert(0, barracks_block(rows, name))
    specials = (
        ("KE", "barracks", lambda d, lv: buildings.paint_barracks(d, lv)),
        ("Mm", "hypermarket", lambda d, lv: buildings.paint_hypermarket(d, rng, lv)),
        ("G$", "hospital", lambda d, lv: buildings.paint_hospital(d, rng, lv)),
        ("\u00c6\u00d8", "factory",
         lambda d, lv: buildings.paint_factory(d, rng, lv)),
        ("0()", "station", lambda d, lv: buildings.paint_station(d, rng, lv)),
        ("W", "duomo", lambda d, lv: buildings.paint_duomo(d, rng, lv)),
        ("#(", "church", lambda d, lv: buildings.paint_small_church(d, rng, lv)),
        ("_+[", "airliner", lambda d, lv: plane.paint_airliner(d, rng, lv)),
        ("]{", "termini", lambda d, lv: termini.paint_termini_front(
            d, rng, lv)),
        ("£", "bank", lambda d, lv: termini.paint_bank(d, rng, lv)),
        ('">`', "basilica", lambda d, lv: termini.paint_santa_maria_maggiore(
            d, rng, lv)),
        (termini.TERME + termini.TERME_DOOR + termini.TERME_SIGN, "terme",
         lambda d, lv: termini.paint_terme_diocleziano(d, rng, lv)),
    )
    for marks, what, paint in specials:
        if marks[0] in glyphs:
            objects.append(picture(rows, level, f"{name}_{what}", paint,
                                   marks))
    tank = run_of(rows, "t") if rome else None
    if tank:
        x, y, w, h = tank
        objects.append(picture(
            rows, level, f"{name}_tank",
            lambda d, lv: termini.paint_tank(d, x * TILE, y * TILE,
                                             w * TILE, h * TILE), "t"))
    hull = run_of(rows, "*")
    if hull:
        x, y, w, h = hull
        objects.append(picture(
            rows, level, f"{name}_hull",
            lambda d, lv: buildings.paint_hull(d, rng, x * TILE, y * TILE,
                                        w * TILE, h * TILE), "*"))
    gantry = run_of(rows, "i")
    if gantry:
        objects.append(picture(
            rows, level, f"{name}_gantry",
            lambda d, lv: buildings.paint_gantry(d, *(v * TILE for v in gantry)),
            "i"))
    monument = run_of(rows, MONUMENT)
    if monument:
        x, y, _, _ = monument
        objects.append(picture(
            rows, level, f"{name}_monument",
            lambda d, lv: props.paint_monument(image_of(d), rng, x * TILE,
                                               y * TILE), MONUMENT))
    ride = run_of(rows, CAROUSEL)
    if ride:
        x, y, w, h = ride
        objects.append(picture(
            rows, level, f"{name}_carousel",
            lambda d, lv: carousel.paint_carousel(d, x * TILE, y * TILE, w, h),
            CAROUSEL))
    fountain = run_of(rows, "O")
    if fountain:
        x, y, w, _ = fountain
        objects.append(picture(
            rows, level, f"{name}_fountain",
            lambda d, lv: props.paint_fountain(image_of(d), rng, x * TILE,
                                            y * TILE, w), "O"))
    boat = run_of(rows, "o5")
    if boat:
        x, y, w, h = boat
        objects.append(picture(
            rows, level, f"{name}_moored_boat",
            lambda d, lv: buildings.paint_moored_boat(d, x * TILE, y * TILE,
                                               w * TILE, h * TILE), "o5"))
    return {
        "void": VOID,
        "voidGlyph": " ",
        "outside": "B",
        "ground": GROUND,
        "rules": rules,
        "objects": objects,
    }


def yard_wall_rule(atlas: Atlas, rng) -> dict:
    """The shipyard's wall, `%`: concrete panels jointed every third column,
    capped along the top where it stands over the yard, a joint on its
    east side where it ends."""
    keys = [pattern_key(1, 0, 3, 0), neighbour_key(0, 1, BUILDINGS),
            neighbour_key(1, 0, BUILDINGS)]

    def wall(index):
        joint, below, east = bits(index, 3)
        gx, gy = find_cell(lambda x, y: (x % 3 == 0) == joint)
        level = Around({(0, 1): "%" if below else ",",
                        (1, 0): "%" if east else ","}, origin=(gx, gy))
        return atlas.bucket(lambda: cell(
            lambda d, x, y: buildings.paint_yard_wall(d, rng, level, x, y), gx, gy))
    return rule("structures", "%", [wall(i) for i in range(8)], keys)


def street(atlas: Atlas, rng) -> dict:
    return city_place(atlas, rng, "street", None, brushes.STREET_STOREFRONTS)


def north_district(atlas: Atlas, rng) -> dict:
    return city_place(atlas, rng, "northDistrict", "north-rows",
                      brushes.NORTH_STOREFRONTS)


def harbour(atlas: Atlas, rng) -> dict:
    return city_place(atlas, rng, "harbour", "harbour-rows",
                      brushes.HARBOUR_STOREFRONTS, old_town=True)


def mall_north_street(atlas: Atlas, rng) -> dict:
    rows = brushes.read_rows("mall-north-rows")
    rear = next(y for y, row in enumerate(rows) if "j" in row)
    return city_place(atlas, rng, "mallNorthStreet", "mall-north-rows",
                      brushes.MALL_NORTH_STOREFRONTS, one_roof=(rear, 50))


BRICK = (150, 84, 60)
BRICK_DARK = (108, 58, 42)
MORTAR = (176, 160, 136)


def paint_ruined_fronts(d, rng, rows, x0, x1, y0, y1):
    """The palazzi east of Termini, gone worst: plaster fallen away in
    sheets down to the brick, cracks running from the windows, blood
    thrown across the fronts and run down them, hands dragged through it,
    and windows and doorways boarded up by whoever held out inside. Laid
    over the fronts the rules paint, so it keeps to their windows and
    doors: a window on every floor over the street, a door on the columns
    the pattern puts one (`STARTS` shifted, as `street_level` reads it)."""
    T = TILE

    def at(x, y):
        return ((x - x0) * T, (y - y0) * T)

    # Plaster fallen off, the brick under it.
    for _ in range((x1 - x0 + 1) // 2):
        x, y = rng.randint(x0, x1), rng.randint(y0, y1 - 1)
        px, py = at(x, y)
        px += rng.randrange(-6, 8)
        py += rng.randrange(0, 8)
        w, h = rng.randint(8, 18), rng.randint(6, 12)
        pts = [(px, py + 2), (px + w // 3, py), (px + w, py + 3),
               (px + w - 2, py + h), (px + w // 2, py + h - 2), (px + 1, py + h)]
        d.polygon(pts, fill=BRICK)
        for by in range(py + 2, py + h, 3):
            d.line([(px + 1, by), (px + w - 2, by)], fill=MORTAR)
            for bx in range(px + (by // 3 % 2) * 3, px + w - 2, 6):
                d.point((bx, by + 1), fill=MORTAR)
        d.line(pts[:3], fill=shade(BRICK, 50))
    # Cracks from the corners of the windows.
    for _ in range((x1 - x0 + 1) // 2):
        px, py = at(rng.randint(x0, x1), rng.randint(y0, y1 - 1))
        cx, cy = px + rng.choice((3, 12)), py + rng.choice((3, 14))
        for _ in range(rng.randint(4, 9)):
            nx, ny = cx + rng.randint(-3, 3), cy + rng.randint(1, 3)
            d.line([(cx, cy), (nx, ny)], fill=(60, 44, 36))
            cx, cy = nx, ny
    # Windows boarded up, some of them, on every floor over the street.
    for y in range(y0, y1):
        for x in range(x0, x1 + 1):
            if rows[y][x] not in FACADE or rng.random() > 0.2:
                continue
            px, py = at(x, y)
            # Three planks nailed across the frame, crooked, the dark of
            # the room between them.
            rect(d, px + 5, py + 4, 6, 10, (16, 14, 16))
            for i, by in enumerate((py + 4, py + 8, py + 11)):
                tilt = rng.choice((-1, 0, 1))
                wood = (122, 92, 60) if i % 2 == 0 else (98, 72, 46)
                for bx in range(-1, 9):
                    rect(d, px + 4 + bx, by + (tilt * bx) // 8, 1, 2, wood)
                rect(d, px + 4, by, 1, 1, (40, 36, 34))
                rect(d, px + 11, by + tilt, 1, 1, (40, 36, 34))
    # The doorways on the street, barricaded: planks and a wardrobe's back.
    for x in range(x0, x1 + 1):
        if x % SPAN not in (1, 6, 12) or rows[y1][x] not in FACADE:
            continue
        px, py = at(x, y1)
        rect(d, px + 3, py + 2, 10, 14, (46, 32, 24))
        buildings.paint_boarded_door(d, rng, px + 3, py + 2, 10, 14)
    # Blood: thrown across the fronts, run down in drips, hands smeared.
    for _ in range(x1 - x0 + 1):
        px, py = at(rng.randint(x0, x1), rng.randint(y0, y1))
        cx, cy = px + rng.randrange(T), py + rng.randrange(4, T)
        colour = rng.choice((brushes.BLOOD, brushes.BLOOD_DARK, (120, 20, 20)))
        r = rng.randint(1, 3)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=colour)
        for _ in range(rng.randint(3, 7)):
            rect(d, cx + rng.randint(-6, 6), cy + rng.randint(-5, 5), 1, 1,
                 colour)
        for _ in range(rng.randint(1, 3)):
            dx = cx + rng.randint(-r, r)
            rect(d, dx, cy, 1, rng.randint(4, 12), colour)
    for _ in range(max(2, (x1 - x0 + 1) // 5)):
        px, py = at(rng.randint(x0, x1), y1)
        hx, hy = px + rng.randrange(2, 10), py + rng.randrange(1, 6) - 6
        for i in range(4):  # the fingers dragged down
            rect(d, hx + i * 2, hy, 1, rng.randint(6, 10), brushes.BLOOD)
        rect(d, hx, hy + 5, 8, 3, brushes.BLOOD)


COBBLES = "°"
BASALT = (86, 84, 84)
BASALT_JOINT = (44, 42, 44)
TRAVERTINE = (210, 202, 180)


def paint_sampietrini(d, rng, px, py):
    """Rome's sampietrini, `°`: little squares of dark basalt set in
    courses, each course half a stone along from the last, the sand of the
    joints between them. Every stone its own shade; now and then one has
    come out and left its hole."""
    rect(d, px, py, TILE, TILE, BASALT_JOINT)
    for row in range(4):
        shift = 2 if row % 2 else 0
        for col in range(-1, 4):
            sx, sy = px + col * 4 + shift, py + row * 4
            stone = shade(BASALT, rng.randint(-14, 14))
            if rng.random() < 0.02:
                stone = (30, 28, 30)
            for x in range(max(sx, px), min(sx + 3, px + TILE)):
                rect(d, x, sy, 1, 3, stone)
            if px <= sx < px + TILE:
                rect(d, sx, sy, 1, 1, shade(stone, 22))  # worn smooth


def paint_sampietrini_edge(d, side):
    """The travertine kerbstones that frame a run of sampietrini on the
    side where the square's slabs begin; where they run into a road, the
    asphalt simply starts."""
    light, dark = TRAVERTINE, shade(TRAVERTINE, -46)
    if side == "n":
        rect(d, 0, 0, TILE, 2, light)
        rect(d, 0, 2, TILE, 1, dark)
    elif side == "s":
        rect(d, 0, 14, TILE, 2, light)
        rect(d, 0, 13, TILE, 1, dark)
    elif side == "w":
        rect(d, 0, 0, 2, TILE, light)
        rect(d, 2, 0, 1, TILE, dark)
    else:
        rect(d, 14, 0, 2, TILE, light)
        rect(d, 13, 0, 1, TILE, dark)
    for i in range(3, TILE, 5):  # the joints between the kerbstones
        if side in "ns":
            rect(d, i, 0 if side == "n" else 14, 1, 2, dark)
        else:
            rect(d, 0 if side == "w" else 14, i, 2, 1, dark)


def sampietrini_rules(atlas: Atlas) -> list[dict]:
    """The sampietrini and their kerbstones. Their own stream, so nothing
    else in the atlas is painted anew for them."""
    stones = random.Random(f"{SEED}/city/sampietrini")
    rules = [rule("ground", COBBLES, randomly(atlas, stones,
                                                paint_sampietrini))]
    for side, (dx, dy) in (("n", (0, -1)), ("s", (0, 1)), ("w", (-1, 0)),
                           ("e", (1, 0))):
        rules.append(rule("ground", COBBLES, [atlas.bucket(
            lambda s=side: tile_of(lambda d: paint_sampietrini_edge(d, s)),
            1), []], [neighbour_key(dx, dy, COBBLES + ROAD, ground=True)]))
    return rules


def piazza_cinquecento(atlas: Atlas, rng) -> dict:
    place = city_place(atlas, rng, "piazzaCinquecento",
                       "piazza-cinquecento-rows", brushes.ROME_PIAZZA_STOREFRONTS,
                       rome=True)
    # After the city's floors, before anything stands on them.
    rules = place["rules"]
    last = max(i for i, r in enumerate(rules) if r["layer"] == "ground")
    rules[last + 1:last + 1] = sampietrini_rules(atlas)
    # The palazzi east of the station: their whole band of fronts.
    rows = brushes.read_rows("piazza-cinquecento-rows")
    east = max(x for row in rows for x, glyph in enumerate(row)
               if glyph == "]") + 1
    cells = [(x, y) for y, row in enumerate(rows)
             for x, glyph in enumerate(row) if glyph in FACADE and x >= east]
    # Only the band beside the station, not the palazzi further down.
    y0 = min(y for _, y in cells)
    y1 = y0
    while any((x, y1 + 1) in set(cells) for x, _ in cells):
        y1 += 1
    cells = [(x, y) for x, y in cells if y <= y1]
    x0, x1 = min(x for x, _ in cells), max(x for x, _ in cells)
    ruin = random.Random(f"{SEED}/city/piazzaCinquecento/ruin")
    sprite = Image.new("RGBA", ((x1 - x0 + 1) * TILE, (y1 - y0 + 1) * TILE),
                       TRANSPARENT)
    paint_ruined_fronts(ImageDraw.Draw(sprite), ruin, rows, x0, x1, y0, y1)
    # The sheet strung across Via Cavour, over whoever walks down it.
    road = [x for x, glyph in enumerate(rows[21]) if glyph not in "B "]
    bx0, bx1 = road[0] - 1, road[-1] + 1
    banner = Image.new("RGBA", ((bx1 - bx0 + 1) * TILE, TILE), TRANSPARENT)
    termini.paint_street_banner(ImageDraw.Draw(banner), 0, 0, banner.width,
                                "LA FINE DEL MONDO")
    place["objects"].append({
        "image": "piazzaCinquecento_banner.png",
        "sprite": banner,
        # Over the cars and whoever walks down the street under it.
        "overhead": True,
        "at": [bx0, 21],
        "under": [rows[21][bx0:bx1 + 1]],
    })
    place["objects"].append({
        "image": "piazzaCinquecento_ruined_fronts.png",
        "sprite": sprite,
        "at": [x0, y0],
        "under": [row[x0:x1 + 1] for row in rows[y0:y1 + 1]],
    })
    return place


def industry_street(atlas: Atlas, rng) -> dict:
    return city_place(atlas, rng, "industryStreet", "industry-street-rows",
                      {})


def monument_square(atlas: Atlas, rng) -> dict:
    return city_place(atlas, rng, "monumentSquare", "monument-square-rows",
                      brushes.MONUMENT_SQUARE_STOREFRONTS)


def via_marsala(atlas: Atlas, rng) -> dict:
    return city_place(atlas, rng, "viaMarsala", "via-marsala-rows",
                      brushes.VIA_MARSALA_STOREFRONTS, rome=True)


PLACES = {
    "harbour": harbour,
    "industryStreet": industry_street,
    "mallNorthStreet": mall_north_street,
    "monumentSquare": monument_square,
    "northDistrict": north_district,
    "piazzaCinquecento": piazza_cinquecento,
    "street": street,
    "viaMarsala": via_marsala,
}

PREVIEW_ROWS = {
    "harbour": "harbour-rows",
    "industryStreet": "industry-street-rows",
    "mallNorthStreet": "mall-north-rows",
    "monumentSquare": "monument-square-rows",
    "northDistrict": "north-rows",
    "piazzaCinquecento": "piazza-cinquecento-rows",
    "street": "level-rows",
    "viaMarsala": "via-marsala-rows",
}
