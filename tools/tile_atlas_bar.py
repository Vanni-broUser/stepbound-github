"""The Bar Arcobaleno in the tile atlas, and its storeroom behind: the
chequered floor, the counter and the mural, the pool tables, and the
crates, racks and demijohns of the back room
(lib/core/levels/hometown/bar_arcobaleno.dart, bar_backroom.dart).

A module of its own, the way docs/level_pipeline.md wants the interiors
to go: build_tile_atlas.py only lists it. The art came from
tools/build_bar.py and tools/build_bar_backroom.py, which the atlas
replaced.
"""
from __future__ import annotations

import os
import sys

from PIL import Image, ImageDraw

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
from tile_atlas_core import (  # noqa: E402
    Atlas,
    Block,
    Neighbourhood,
    TRANSPARENT,
    cell,
    neighbour_key,
    paint_side_edge,
    parity_key,
    pattern_key,
    rule,
    tile_of,
)

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
        "void": "#000000", "voidGlyph": "x", "rules": rules,
        "objects": [
            {"glyph": "W", "image": "bar_back_wall.png",
             "tiles": list(BAR_WALL_TILES), "sprite": wall},
            {"glyph": "J", "image": "bar_jukebox.png", "offsetY": -1,
             "sprite": juke},
            {"glyph": "D", "image": "bar_service_door.png", "offsetY": -1,
             "sprite": door},
        ],
    }


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
    return {"void": "#000000", "voidGlyph": "x", "rules": rules,
            "objects": []}
