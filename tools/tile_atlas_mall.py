"""The hypermarket in the tile atlas: its two floors, the glossy floor
edged where it ends, the shopfronts along the back walls
(lib/core/levels/hometown/mall*.dart).

A module of its own, the way docs/level_pipeline.md wants the interiors
to go: build_tile_atlas.py only lists it. The painters stay in
tools/build_mall.py; here is what is made of them.
"""
from __future__ import annotations

import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_mall as mall  # noqa: E402
from street_paint import TILE, rect  # noqa: E402
from street_props import paint_trolley  # noqa: E402
from tile_atlas_core import (  # noqa: E402
    Atlas,
    Neighbourhood,
    TRANSPARENT,
    cell,
    leaning,
    neighbour_key,
    parity_key,
    pattern_key,
    rule,
    tile_of,
)

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
    from street_paint import read_rows  # noqa: PLC0415 - the shops

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
    return {"void": "#000000", "voidGlyph": "x", "rules": rules,
            "objects": objects}


def mall_ground(atlas: Atlas, rng) -> dict:
    return mall_floor(atlas, "mallGround", rng)


def mall_first(atlas: Atlas, rng) -> dict:
    return mall_floor(atlas, "mallFirst", rng)
