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
import build_street_level as sl  # noqa: E402
from build_street_level import TILE, rect, shade  # noqa: E402
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

ROAD = "".join(sorted(sl.ROAD_GLYPHS))
BUILDINGS = "BHfKMGW#%0"
FACADE = "Hf"

GROUND = ground_config(
    buildings=BUILDINGS,
    roads=".-|ZVc",
    walks="=",
    floors="PLY,",
    footway="T/F",
    keep="~bRlo5g",
    lawn="g",
    lawnProps="Apn^<",
)

# The asphalt the baker laid under everything, and what shows under the
# buildings the objects stand on.
VOID = "#%02x%02x%02x" % sl.ASPHALT

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
        return self.at(x, y) in sl.ROAD_GLYPHS

    def is_building(self, x, y):
        return self.at(x, y) in sl.BUILDING_GLYPHS

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
        rect(d, 2, 7, 12, 2, sl.LANE)
    elif glyph == "|":
        rect(d, 7, 2, 2, 12, sl.LANE)
    elif glyph == "Z":
        for i in range(0, 16, 4):
            rect(d, 2, i + 1, 12, 2, sl.ZEBRA)
    elif glyph == "V":
        for i in range(0, 16, 4):
            rect(d, i + 1, 2, 2, 12, sl.ZEBRA)


def paint_curb(d, side):
    """The kerb along one side of a pavement tile that touches the road."""
    if side == "s":
        rect(d, 0, 14, TILE, 2, sl.CURB)
        rect(d, 0, 13, TILE, 1, sl.CURB_SHADOW)
    elif side == "n":
        rect(d, 0, 0, TILE, 2, sl.CURB)
        rect(d, 0, 2, TILE, 1, sl.CURB_SHADOW)
    elif side == "e":
        rect(d, 14, 0, 2, TILE, sl.CURB)
        rect(d, 13, 0, 1, TILE, sl.CURB_SHADOW)
    else:
        rect(d, 0, 0, 2, TILE, sl.CURB)
        rect(d, 2, 0, 1, TILE, sl.CURB_SHADOW)


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
            colour = sl.ALGAE[0] if inside > 0.55 else \
                sl.ALGAE[1 + (rng.random() < 0.25)]
            rect(d, px, py, 1, 1, colour)


def ground_rules(atlas: Atlas, rng) -> list[dict]:
    """The floors of the city, the same four places over. Each is the
    baker's own painter, painted where its patterns want it."""
    rules = []

    # The carriageway, and the markings on it, which belong to the glyph:
    # a car in the road stands on bare asphalt.
    rules.append(rule("ground", ".", randomly(
        atlas, rng, lambda d, r, x, y: sl.paint_road(d, r, Around(), x, y))))
    for glyph in "-|ZV":
        rules.append(rule("ground", glyph, [atlas.bucket(lambda g=glyph:
                          tile_of(lambda d: paint_marking(d, g)), 1)],
                          on="glyph"))
    # The car park, a stall line on every row but the aisles, y % 3 == 2.
    rules.append(rule("ground", "L", [atlas.bucket(lambda a=aisle: cell(
        lambda d, gx, gy: sl.paint_parking(
            d, rng, Around(default="L", origin=(gx, gy)), gx, gy),
        0, 2 if a else 0)) for aisle in (False, True)],
        [pattern_key(0, 1, 3, 2)]))

    # The pavement, its slabs alternating, a kerb on each side the road is.
    rules.append(rule("ground", "=", [atlas.bucket(lambda p=parity: cell(
        lambda d, gx, gy: sl.paint_sidewalk(
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
            lambda d, x, y: sl.paint_paving(d, rng, x, y), gx, gy))
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
            lambda d, x, y: sl.paint_stairs(d, level, x, y), gx, gy), 1)
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
            lambda d, x, y: sl.paint_yard_floor(d, rng, x, y), gx, gy))
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
            lambda d, x, y: sl.paint_grass(d, rng, x, y), gx, gy))
    rules.append(rule("ground", "g", [lawn(i) for i in range(4)],
                      [pattern_key(3, 5, 3, 1), pattern_key(3, 5, 3, 2)]))

    # The sea, with the scum on it, and under the boats.
    rules.append(rule("ground", "~bo5", randomly(
        atlas, rng, lambda d, r, x, y: sl.paint_water(d, r, x, y))))
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
        paint = sl.paint_parapet_west if west else sl.paint_parapet
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
        return (lambda d, px, py: sl.paint_pier(
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


def roof_rules(atlas: Atlas, rng, palette, region=None) -> list[dict]:
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

    def paint_fill(d, c, r):
        rect(d, 0, 0, TILE, TILE, c)
        dark = tuple(max(0, v - 20) for v in c)
        for _ in range(4):
            rect(d, r.randrange(TILE), r.randrange(TILE), 1, 1, dark)

    count = 2 ** (len(colour_keys) + len(region))
    fills = []
    for index in range(count):
        c = colour(index)
        fills.append([] if c is None else atlas.bucket(
            lambda c=c: tile_of(lambda d: paint_fill(d, c, rng))))
    rules = [rule("structures", "B", fills, colour_keys + region)]

    def paint_unit(d, r):
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
    rules.append(rule("structures", "B", [atlas.odds(lambda: tile_of(
        lambda d: paint_unit(d, rng) if rng.random() < 0.17 else None), 24)]))

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

    def paint_side(d, side, c):
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

    keys_n = len(colour_keys) + len(region)
    for side, roof_there, split in sides:
        buckets = []
        for index in range(2 ** (keys_n + 2)):
            c = colour(index & (2 ** keys_n - 1))
            more, split_here = bits(index >> keys_n, 2)
            in_region = region and not any(bits(index >> 4, len(region)))
            edge = not more or (split_here and not in_region)
            buckets.append([] if c is None or not edge else atlas.bucket(
                lambda s=side, c=c: tile_of(lambda d: paint_side(d, s, c)),
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
            lambda c=c: tile_of(lambda d: rect(
                d, 0, TILE - 3, TILE, 3,
                tuple(min(255, v + 24) for v in c))), 1))
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


def facade_rules(atlas: Atlas, rng, old_town: bool) -> list[dict]:
    """A band of `H` is the fronts of the buildings whose roofs are behind
    it, split where the roofs are: a colour to each building, a cornice
    along the top, windows, and on the street a shop or a door."""
    keys = facade_keys()
    colours = sl.OLD_TOWN_STONE if old_town else sl.FACADES

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
            4 if old_town else 1))
    rules = [rule("structures", FACADE, walls, keys)]

    # The floors above the street: a window to each tile.
    colour_keys = segment_keys()

    def paint_window(d, c, r):
        if old_town:
            stone = c
            wx, wy = 5, 3
            rect(d, wx - 1, wy - 1, 8, 12, shade(stone, 18))
            rect(d, wx, wy, 6, 10, sl.PANE if r.random() > 0.2
                 else sl.PANE_BROKEN)
            green = r.choice(sl.SHUTTERS)
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
        _, trim = c
        roll = r.random()
        pane = sl.PANE if roll > 0.25 else (
            sl.PANE_LIT if roll > 0.12 else sl.PANE_BROKEN)
        rect(d, 4, 3, 8, 10, trim)
        rect(d, 5, 4, 6, 8, pane)
        if pane == sl.PANE_BROKEN:
            rect(d, 6, 5, 2, 3, sl.PANE)

    # A window on every floor above the street: the key holds where there
    # is more front below. The palazzi of the old town keep the floor over
    # the street for their tall doorways, so there it takes two.
    window_keys = colour_keys + [neighbour_key(0, 2 if old_town else 1,
                                               FACADE)]
    windows = []
    for index in range(2 ** len(window_keys)):
        c = building(index & 7)
        upstairs = bits(index, 4)[3]
        windows.append([] if c is None or not upstairs else atlas.odds(
            lambda c=c: tile_of(lambda d: paint_window(d, c, rng)), 24))
    rules.append(rule("structures", FACADE, windows, window_keys))

    # The street level: a shop under an awning if the building is four
    # floors or more, a door on the middle tile of each building if not.
    keys = colour_keys + [neighbour_key(0, 1, FACADE),
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
        if tall:
            return lambda d, px, py, c=c: paint_shop(d, px, py, c, rng)
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
    return rules


def paint_shop(d, px, py, c, rng):
    """The shut shop at the foot of a tall building, under its striped
    awning, which the baker hung two pixels into the floor above."""
    shop_top = py + 2
    rect(d, px, shop_top, TILE, TILE - 2, sl.SHOP_DARK)
    rect(d, px, shop_top + 4, TILE, 1, (48, 40, 40))
    for i in range(0, TILE, 4):
        torn = rng.random() < 0.2
        rect(d, px + i, shop_top - 4, 4, 2 if torn else 4 + (i * 5 % 3),
             sl.RED if (i // 4) % 2 else sl.CREAM)


def paint_street_door(d, px, py, c, door, rng):
    """The street level of a short building: its door on the middle tile,
    boarded up or kicked in more often than not; the rest of the front
    tagged, or an air conditioner hanging off it."""
    wall, trim = c
    if door:
        door_x, door_y = px + 2, py + 2
        rect(d, door_x - 1, door_y - 1, 14, 15, trim)
        rect(d, door_x, door_y, 12, 14, (50, 36, 30))
        rect(d, door_x + 2, door_y + 2, 8, 1, (80, 60, 50))
        roll = rng.random()
        if roll < 0.65:
            sl.paint_boarded_door(d, rng, door_x, door_y, 12, 14)
        elif roll < 0.8:
            rect(d, door_x + 1, door_y + 1, 10, 13, (16, 12, 14))
            rect(d, door_x + 9, door_y + 1, 3, 13, (70, 50, 40))
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
        rect(d, px + 5, py + 3, 6, 8, sl.PANE if rng.random() > 0.3
             else sl.PANE_BROKEN)


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
        rect(d, door_x, door_y + 1, door_w, TILE - 2, sl.DOOR_GREEN)
        rect(d, door_x + door_w // 2, door_y + 1, 1, TILE - 2,
             shade(sl.DOOR_GREEN, -18))
        rect(d, door_x + 1, door_y + 1, door_w - 2, 3, (70, 70, 70))
        for i in range(1, door_w - 1, 2):
            rect(d, door_x + i, door_y + 2, 1, 1, (30, 30, 30))
        roll = rng.random()
        if roll < 0.2:
            rect(d, door_x + 1, door_y + 5, door_w - 2, TILE - 6,
                 (16, 12, 14))
        elif roll < 0.4:
            sl.paint_boards(d, door_x, door_y + 5, door_w, 8)
    elif rng.random() < 0.5:
        rect(d, px + 5, py + 4, 6, 6, (30, 30, 34))
        for i in range(0, 6, 2):
            rect(d, px + 5 + i, py + 4, 1, 6, (80, 80, 80))
    for _ in range(5):
        gx, gh = rng.randrange(TILE), rng.randint(2, 7)
        rect(d, px + gx, py + TILE - gh, 1, gh,
             shade(stone, -rng.randint(30, 60)))


# ------------------------------------------------------------------ props


def rest_of(glyph: str) -> list[dict]:
    """The keys that say a cell is the first of its picture: nothing of the
    same glyph west of it or north of it."""
    return [neighbour_key(-1, 0, glyph), neighbour_key(0, -1, glyph)]


def anchored(atlas: Atlas, layer: str, glyph: str, paint, reach,
             keys=None, count=None, count_one=False) -> dict:
    """A picture over a run of `glyph`, drawn from its first cell: `paint`
    is handed the index of the extra `keys` and returns the painter."""
    keys = keys or []
    all_keys = rest_of(glyph) + keys

    def paint_for(index):
        west, north = bits(index, 2)
        if west or north:
            return lambda d, px, py: None
        return paint(index >> 2)

    buckets, pieces = spread(atlas, paint_for, all_keys, reach,
                             1 if count_one else (count or 12))
    for index in range(len(buckets)):
        if index & 3:
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
            return lambda d, px, py: sl.paint_rubbish(d, rng, px, py, False)
        if wreck:
            return lambda d, px, py: sl.paint_airliner_wreckage(
                d, rng, px, py)
        return lambda d, px, py: sl.paint_debris(d, rng, px, py)
    single(":", debris, [near_heap, near_wreck])
    single("d", lambda i: lambda d, px, py: sl.paint_corpse(
        image_of(d), rng, px, py), reach=(1, 0, 1, 1))
    single("D", lambda i: lambda d, px, py: sl.paint_corpse_pile(
        image_of(d), rng, px, py), reach=(1, 1, 1, 1))
    single("F", lambda i: sl.paint_bin, count=1)
    single("S", lambda i: sl.paint_campfire, count=1)
    single("J", lambda i: sl.paint_road_block, count=1)
    single("Q", lambda i: sl.paint_cafe_table, count=1)
    single("h", lambda i: sl.paint_bar_doorway, count=1)
    single(";", lambda i: lambda d, px, py: sl.paint_rubbish(
        d, rng, px, py))
    # A trolley on its side where (x + y) is even.
    single("y", lambda i: lambda d, px, py: sl.paint_trolley(
        d, px, py, tipped=not i), [parity_key()], count=1)
    # The churchyard gate: a pier where the gate ends, its leaf folded
    # flat against it.
    single("x", lambda i: lambda d, px, py: sl.paint_gate(
        d, Around({(-1, 0): "x" if i & 1 else ".",
                   (1, 0): "x" if i & 2 else "."}, origin=(px // TILE, 0)),
        px, py, px // TILE, 0),
        [neighbour_key(-1, 0, "x"), neighbour_key(1, 0, "x")],
        (0, 1, 0, 0), 1)
    # The park: its railing, the gates in it, the rides of the playground,
    # (x * 7 + y * 3) % 3 of them.
    single("^", lambda i: lambda d, px, py: sl.paint_railing(
        d, Around({(-1, 0): "^" if i & 1 else ".",
                   (1, 0): "^" if i & 2 else "."}, origin=(px // TILE,
                                                             py // TILE)),
        px // TILE, py // TILE),
        [neighbour_key(-1, 0, "^"), neighbour_key(1, 0, "^")], count=1)
    single("<", lambda i: lambda d, px, py: sl.paint_park_gate(
        d, Around({(0, 1): "g" if i else "."}, origin=(px // TILE,
                                                       py // TILE)),
        px // TILE, py // TILE),
        [neighbour_key(0, 1, "gP")], (0, 1, 0, 0), 1)

    def ride(index):
        one_, two = bits(index, 2)
        kind = 1 if one_ else 2 if two else 0
        return lambda d, px, py: sl.paint_playground(d, px, py, kind)
    single("p", ride, [pattern_key(7, 3, 3, 1), pattern_key(7, 3, 3, 2)],
           (0, 1, 0, 0), 1)
    # A flower bed, its earth darker along the top of a run of them.
    single("&", lambda i: lambda d, px, py: sl.paint_flower_bed(
        d, rng, Around({(0, -1): "&" if i else "."}, origin=(px // TILE,
                                                             py // TILE)),
        px // TILE, py // TILE), [neighbour_key(0, -1, "&")])
    # The café's chairs, knocked over but for every third, and the litter
    # round them.

    def chair(index):
        def paint(d, px, py):
            sl.paint_chair(d, px, py, toppled=not index)
            for _ in range(3):
                rect(d, px + rng.randrange(14), py + rng.randrange(14), 2, 1,
                     rng.choice(sl.DEBRIS))
        return paint
    single("q", chair, [pattern_key(1, 1, 3, 0)])

    # The pictures over two cells or more, drawn from their first cell.
    colours = [(140, 40, 36), (70, 96, 130), (180, 170, 150), (60, 110, 80),
               (118, 118, 124), (162, 132, 62), (94, 78, 102),
               (198, 166, 112)]

    def car(burnt, flipped):
        return lambda i: lambda d, px, py: sl.paint_car(
            d, px, py, rng.choice(colours), burnt=burnt, flipped=flipped)
    rules.append(anchored(atlas, "foreground", "C", car(False, False),
                          (1, 0, 2, 0), count=8))
    rules.append(anchored(atlas, "foreground", "X", car(True, False),
                          (1, 0, 2, 0), count=8))
    rules.append(anchored(atlas, "foreground", "U", car(False, True),
                          (1, 0, 2, 0), count=8))
    for glyph, burnt in (("v", False), ("k", True)):
        rules.append(anchored(
            atlas, "foreground", glyph,
            lambda i, b=burnt: lambda d, px, py: sl.paint_car_vertical(
                d, px, py, rng.choice(colours), burnt=b),
            (0, 0, 0, 1), count=8))
    rules.append(anchored(atlas, "foreground", "a",
                          lambda i: sl.paint_ambulance, (1, 1, 1, 0),
                          count_one=True))
    rules.append(anchored(atlas, "foreground", "n",
                          lambda i: sl.paint_bench, (0, 0, 1, 0),
                          count_one=True))
    # A half-sunk boat, and from some, (x + y) % 3 == 1, two hands.
    rules.append(anchored(
        atlas, "foreground", "b",
        lambda i: lambda d, px, py: sl.paint_boat(d, px, py, hands=bool(i)),
        (0, 1, 2, 0), [pattern_key(1, 1, 3, 1)], count_one=True))
    rules.append(anchored(atlas, "foreground", "!",
                          lambda i: sl.paint_street_fountain, (0, 1, 1, 1),
                          count_one=True))
    # The back passage through the barracks and the hypermarket's fire
    # door, holes in the roofs round them.
    single("e", lambda i: lambda d, px, py: paint_back_passage(d, px, py),
           reach=(1, 0, 1, 0), count=1)
    single("j", lambda i: lambda d, px, py: paint_mall_back_door(d, px, py),
           reach=(1, 0, 1, 1), count=1)
    # A window on fire: the scorch on its frame; the flames are the game's.
    single("f", lambda i: lambda d, px, py: (
        rect(d, px + 2, py - 2, 12, 16, sl.SCORCH),
        rect(d, px + 4, py + 4, 8, 9, (60, 20, 14)),
        rect(d, px + 3, py + 13, 10, 2, (40, 36, 36))),
        reach=(0, 1, 0, 0), count=1)
    return rules


def paint_back_passage(d, px, py):
    """sl.paint_back_passage, for one cell."""
    rect(d, px - 2, py, 20, 16, (150, 136, 104))
    rect(d, px, py + 2, 16, 14, (26, 24, 26))
    rect(d, px + 2, py + 4, 12, 12, (44, 40, 40))
    rect(d, px + 3, py + 13, 10, 3, (80, 76, 70))
    rect(d, px + 3, py + 10, 10, 2, (66, 62, 58))


def paint_mall_back_door(d, px, py):
    """sl.paint_mall_back_door, for its one cell and the well below it."""
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


def paint_lane_bend(d, px, py):
    """Where a road turns, `c`: the line from the west curving round into
    the one going south, over the tile before it and the two below."""
    radius = TILE + TILE // 2
    cx, cy = px + 8 - radius, py + 8 + radius
    for step in range(0, 91, 3):
        a = math.radians(step)
        rect(d, round(cx + radius * math.sin(a)) - 1,
             round(cy - radius * math.cos(a)) - 1, 2, 2, sl.LANE)


def overhead_rules(atlas: Atlas, rng) -> list[dict]:
    """What stands into the tile above over everything else: the traffic
    lights, the road signs, the trees and the palms; and last, the grit the
    baker scattered over everything walkable."""
    rules = []

    def single(glyph, paint, keys=None, reach=(0, 0, 0, 0), count=12):
        buckets, pieces = spread(atlas, paint, keys, reach, count)
        rules.append(rule("overhead", glyph, buckets, keys, pieces))

    single("T", lambda i: sl.paint_traffic_light, reach=(0, 1, 0, 0),
           count=1)

    # Give way where the road runs alongside, no entry where a road block
    # or a wreck closes the street, and the blue plate anywhere else.
    def sign(index):
        road, closed = bits(index, 2)
        kind = 0 if road else 1 if closed else 2
        return lambda d, px, py: sl.paint_sign(d, px, py, kind)
    single("/", sign, [any_key(((-1, 0), (1, 0)), ROAD),
                       any_key(((-2, 0), (-1, 0), (1, 0), (2, 0)), "JCXU")],
           (0, 1, 0, 0), 1)
    single("A", lambda i: lambda d, px, py: sl.paint_tree(d, rng, px, py),
           reach=(0, 2, 0, 0))
    single("N", lambda i: lambda d, px, py: sl.paint_palm(d, rng, px, py),
           reach=(1, 2, 1, 0))

    def speck(d):
        if rng.random() < 0.33:
            rect(d, rng.randrange(TILE), rng.randrange(TILE),
                 rng.randint(1, 3), 1, rng.choice(sl.DEBRIS))
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


def storefronts(rows, level, name, rng) -> list[dict]:
    """The named shops along the bands of fronts, by the tables in
    build_street_level.py: each is painted for its band's height and
    placed where the table puts it."""
    out = []
    for x0, width, top, bottom in sl.column_runs(level, sl.FACADE_GLYPHS):
        for sx, sw, kind in level.storefronts.get(top, []):
            if not x0 <= sx < x0 + width:
                continue
            h = bottom - top + 1
            sprite = Image.new("RGBA", (sw * TILE, h * TILE), TRANSPARENT)
            sl.paint_storefront(ImageDraw.Draw(sprite), rng, 0, 0,
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


def city_place(atlas: Atlas, rng, name: str, marker, storefront_table,
               old_town=False, one_roof=None) -> dict:
    rows = sl.read_rows(marker) if marker else sl.read_rows()
    level = sl.Level(rows, storefront_table, old_town=old_town,
                     one_roof=one_roof)
    glyphs = set("".join(rows))
    ground_glyphs = "".join(sorted(glyphs - set(BUILDINGS)))

    rules = list(shared(atlas, "ground", lambda r: ground_rules(atlas, r)))
    region = None
    if one_roof is not None:
        row, column = one_roof
        region = [first_row_key("j", -1, "le"),
                  pattern_key(1, 0, 2, 1, div=(column, 1))]
    palette = sl.OLD_TOWN_ROOFS if old_town else sl.ROOFS
    rules += shared(atlas, f"roofs/{old_town}/{bool(region)}",
                    lambda r: roof_rules(atlas, r, palette, region))
    rules.append(roof_shadow_rule(atlas, ground_glyphs))
    rules += shared(atlas, f"facades/{old_town}",
                    lambda r: facade_rules(atlas, r, old_town))
    if "%" in glyphs:
        rules.append(yard_wall_rule(atlas, rng))
    if "c" in glyphs:
        buckets, pieces = spread(atlas, lambda i: paint_lane_bend, None,
                                 (2, 0, 0, 2), 1)
        rules.append(rule("structures", "c", buckets, None, pieces))
    if glyphs & set("_+["):
        scorched = "".join(sorted(set(ground_glyphs) - set("_+[")))
        rules.append(rule("structures", scorched, [[], atlas.bucket(
            lambda: tile_of(lambda d: sl.paint_airliner_scorch(
                d, rng, None, 0, 0)))], [any_key(around(1), "_+[")]))
    rules += shared(atlas, "props", lambda r: prop_rules(atlas, r))
    rules += shared(atlas, "overhead", lambda r: overhead_rules(atlas, r))

    objects = storefronts(rows, level, name, rng)
    specials = (
        ("KE", "barracks", lambda d, lv: sl.paint_barracks(d, lv)),
        ("Mm", "hypermarket", lambda d, lv: sl.paint_hypermarket(d, rng, lv)),
        ("G", "hospital", lambda d, lv: sl.paint_hospital(d, rng, lv)),
        ("0()", "station", lambda d, lv: sl.paint_station(d, rng, lv)),
        ("W", "duomo", lambda d, lv: sl.paint_duomo(d, rng, lv)),
        ("#(", "church", lambda d, lv: sl.paint_small_church(d, rng, lv)),
        ("_+[", "airliner", lambda d, lv: sl.paint_airliner(d, rng, lv)),
    )
    for marks, what, paint in specials:
        if marks[0] in glyphs:
            objects.append(picture(rows, level, f"{name}_{what}", paint,
                                   marks))
    hull = run_of(rows, "*")
    if hull:
        x, y, w, h = hull
        objects.append(picture(
            rows, level, f"{name}_hull",
            lambda d, lv: sl.paint_hull(d, rng, x * TILE, y * TILE,
                                        w * TILE, h * TILE), "*"))
    gantry = run_of(rows, "i")
    if gantry:
        objects.append(picture(
            rows, level, f"{name}_gantry",
            lambda d, lv: sl.paint_gantry(d, gantry[0] * TILE,
                                          gantry[1] * TILE), "i"))
    fountain = run_of(rows, "O")
    if fountain:
        x, y, w, _ = fountain
        objects.append(picture(
            rows, level, f"{name}_fountain",
            lambda d, lv: sl.paint_fountain(image_of(d), rng, x * TILE,
                                            y * TILE, w), "O"))
    boat = run_of(rows, "o5")
    if boat:
        x, y, w, h = boat
        objects.append(picture(
            rows, level, f"{name}_moored_boat",
            lambda d, lv: sl.paint_moored_boat(d, x * TILE, y * TILE,
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
            lambda d, x, y: sl.paint_yard_wall(d, rng, level, x, y), gx, gy))
    return rule("structures", "%", [wall(i) for i in range(8)], keys)


def street(atlas: Atlas, rng) -> dict:
    return city_place(atlas, rng, "street", None, sl.STREET_STOREFRONTS)


def north_district(atlas: Atlas, rng) -> dict:
    return city_place(atlas, rng, "northDistrict", "north-rows",
                      sl.NORTH_STOREFRONTS)


def harbour(atlas: Atlas, rng) -> dict:
    return city_place(atlas, rng, "harbour", "harbour-rows",
                      sl.HARBOUR_STOREFRONTS, old_town=True)


def mall_north_street(atlas: Atlas, rng) -> dict:
    rows = sl.read_rows("mall-north-rows")
    rear = next(y for y, row in enumerate(rows) if "j" in row)
    return city_place(atlas, rng, "mallNorthStreet", "mall-north-rows",
                      sl.MALL_NORTH_STOREFRONTS, one_roof=(rear, 50))


PLACES = {
    "harbour": harbour,
    "mallNorthStreet": mall_north_street,
    "northDistrict": north_district,
    "street": street,
}

PREVIEW_ROWS = {
    "harbour": "harbour-rows",
    "mallNorthStreet": "mall-north-rows",
    "northDistrict": "north-rows",
    "street": "level-rows",
}
