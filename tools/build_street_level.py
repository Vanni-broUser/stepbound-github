#!/usr/bin/env python3
"""The city's painters: the street Mario wakes up in, the north district,
the street behind the hypermarket and the harbour.

They were baked here, one picture each. They are not any more: the game
paints them from their rows out of the tile atlas, whose city rules are in
tools/tile_atlas_city.py and use the painters below -- the floors, the
props, the one-off buildings, the named shops. What is gone is the
composition, which split the city into palaces at random.

Everything is 16x16 tiles in 3/4 view. Fires, the barracks flag, backpacks
and characters were never painted here: the game draws and animates them
on top.
"""
from __future__ import annotations

import math
import os
import re

from PIL import Image, ImageDraw

TILE = 16
LEVELS_DIR = os.path.join("lib", "core", "levels", "tutorial")

ROAD_GLYPHS = set(".-|ZVc")
WALK_GLYPHS = set("=")
BUILDING_GLYPHS = set("BHfKMGW#%0")
FACADE_GLYPHS = set("Hf")
# Street furniture: it stands on the footway, not in the road, so it
# looks for its floor up and down its column as well as sideways.
FOOTWAY_GLYPHS = set("T/F")

ASPHALT = (44, 46, 52)
ASPHALT_SPECKLE = (52, 54, 60)
CRACK = (30, 31, 36)
OIL = (34, 34, 40)
WALK = (98, 96, 92)
WALK_ALT = (86, 84, 82)
WALK_JOINT = (72, 70, 68)
CURB = (132, 128, 120)
CURB_SHADOW = (60, 58, 58)
LANE = (190, 170, 90)
ZEBRA = (170, 166, 150)
RED = (170, 30, 30)
CREAM = (206, 196, 176)
SHOP_DARK = (30, 26, 26)
PANE = (34, 40, 56)
PANE_LIT = (230, 150, 60)
PANE_BROKEN = (14, 12, 14)
PAVING = (120, 112, 100)
PAVING_ALT = (108, 102, 92)
PAVING_JOINT = (84, 78, 72)
WOOD = (122, 92, 60)
WOOD_DARK = (86, 62, 40)
NAIL = (40, 36, 34)
SCORCH = (20, 16, 16)
BLOOD = (92, 14, 14)
BLOOD_DARK = (60, 10, 10)
DEBRIS = [(70, 66, 60), (90, 80, 66), (60, 56, 54), (110, 96, 76)]
# The airliner down on the crossroads behind the hypermarket: bare skin,
# the livery along its side, and what the fire left of both.
HULL = (206, 204, 198)
HULL_LIGHT = (234, 232, 226)
HULL_SHADE = (148, 148, 146)
HULL_DARK = (86, 86, 88)
HULL_SEAM = (172, 172, 170)
LIVERY = (46, 70, 108)
LIVERY_LIGHT = (72, 104, 150)
CABIN_WINDOW = (26, 30, 38)
WING = (160, 160, 160)
WING_DARK = (92, 92, 94)
NACELLE = (150, 152, 156)
NACELLE_DARK = (86, 88, 94)
HULL_SHADOW = (28, 26, 28)
FACADES = [
    ((116, 58, 48), (80, 38, 34)),
    ((96, 98, 104), (68, 70, 76)),
    ((150, 132, 104), (110, 94, 72)),
    ((70, 84, 96), (50, 60, 70)),
]
# The old town by the harbour: whitewashed limestone, green shutters, flat
# pale terraces instead of dark roofs.
OLD_TOWN_STONE = [(214, 208, 192), (202, 196, 180), (222, 218, 204), (194, 188, 172)]
OLD_TOWN_ROOFS = [(170, 164, 150), (160, 154, 142), (180, 174, 160), (152, 148, 138)]
SHUTTERS = [(44, 142, 104), (52, 150, 78), (40, 126, 96)]
DOOR_GREEN = (40, 66, 52)
SEA = (28, 38, 38)
SEA_DARK = (22, 30, 32)
SEA_SPECKLE = (36, 48, 46)
SEA_WAVE = (54, 68, 64)
ALGAE = [(38, 52, 34), (52, 70, 38), (68, 88, 42)]
ROOFS = [(66, 60, 58), (74, 70, 72), (60, 64, 70), (80, 72, 64)]
CLOTHES = [(70, 80, 110), (110, 60, 50), (80, 90, 70), (60, 60, 66), (130, 120, 96)]
SKIN = [(200, 160, 130), (150, 110, 84), (180, 190, 150)]
HAIR = [(40, 30, 26), (90, 70, 40), (20, 20, 22)]
OUTLINE = (16, 12, 14)

# Shops along a street, by band top row: (first column, width, kind).
# They are decorations: every one is wrecked and shut. The rest of a band
# with shops gets ordinary houses.
STREET_STOREFRONTS = {
    38: [
        (4, 5, "kebab"),
        (9, 4, "alimentari"),
        (20, 5, "pizzeria"),
        (25, 4, "bar"),
        (29, 5, "abbigliamento"),
        (34, 6, "burger"),
    ],
}
NORTH_STOREFRONTS = {
    27: [(38, 7, "barsport")],
    30: [
        (63, 6, "elettronica"),
        (70, 5, "kebab2"),
    ],
}
MALL_NORTH_STOREFRONTS = {
    3: [
        (4, 5, "pizzeria"),
        (11, 4, "alimentari"),
        (17, 6, "barsport"),
        (26, 6, "elettronica"),
        (34, 5, "abbigliamento"),
        (41, 5, "gelateria"),
    ],
}
HARBOUR_STOREFRONTS = {
    7: [(123, 5, "arcobaleno")],  # up the alley, its door `h` at column 125
    15: [
        (54, 6, "gelateria"),
        (78, 6, "pescheria"),  # past the alley, with the palazzi east of it
    ],
}
RAINBOW = [(220, 60, 50), (240, 150, 50), (240, 220, 70), (90, 190, 80),
           (70, 150, 220), (130, 90, 200)]

# 3x5 pixel font for shop signs.
FONT = {
    "A": ("010", "101", "111", "101", "101"),
    "B": ("110", "101", "110", "101", "110"),
    "C": ("011", "100", "100", "100", "011"),
    "D": ("110", "101", "101", "101", "110"),
    "E": ("111", "100", "110", "100", "111"),
    "F": ("111", "100", "110", "100", "100"),
    "G": ("011", "100", "101", "101", "011"),
    "H": ("101", "101", "111", "101", "101"),
    "I": ("111", "010", "010", "010", "111"),
    "K": ("101", "101", "110", "101", "101"),
    "L": ("100", "100", "100", "100", "111"),
    "M": ("101", "111", "111", "101", "101"),
    "N": ("110", "101", "101", "101", "101"),
    "O": ("010", "101", "101", "101", "010"),
    "P": ("110", "101", "110", "100", "100"),
    "R": ("110", "101", "110", "101", "101"),
    "S": ("011", "100", "010", "001", "110"),
    "T": ("111", "010", "010", "010", "010"),
    "U": ("101", "101", "101", "101", "111"),
    "V": ("101", "101", "101", "101", "010"),
    "Z": ("111", "001", "010", "100", "111"),
    " ": ("000", "000", "000", "000", "000"),
    "0": ("010", "101", "101", "101", "010"),
    "5": ("111", "100", "110", "001", "110"),
    "%": ("101", "001", "010", "100", "101"),
    "-": ("000", "000", "111", "000", "000"),
    "!": ("010", "010", "010", "000", "010"),
}


def text_width(text: str) -> int:
    return len(text) * 4 - 1


def paint_text(d, x, y, text, colour, missing=(), scale=1, tilted=()):
    """Draws `text` with the 3x5 font, `scale` pixels per dot; letters whose
    index is in `missing` have fallen off the sign, the ones in `tilted`
    hang crooked from a single screw."""
    for i, letter in enumerate(text):
        if i in missing:
            continue
        for row, bits in enumerate(FONT[letter]):
            for col, bit in enumerate(bits):
                if bit == "1":
                    drop = (col * scale) // 2 if i in tilted else 0
                    rect(d, x + (i * 4 + col) * scale, y + row * scale + drop,
                         scale, scale, colour)


def read_rows(marker: str = "level-rows") -> list[str]:
    """The ASCII rows between `// <marker>-start` and `// <marker>-end`, in
    whichever place file of lib/core/levels/tutorial holds them."""
    for name in sorted(os.listdir(LEVELS_DIR)):
        with open(os.path.join(LEVELS_DIR, name), encoding="utf-8") as source:
            text = source.read()
        if f"// {marker}-start" in text:
            block = text.split(f"// {marker}-start", 1)[1].split(f"// {marker}-end", 1)[0]
            return re.findall(r"'([^']+)'", block)
    raise ValueError(f"no rows marked {marker} in {LEVELS_DIR}")


def rect(d: ImageDraw.ImageDraw, x, y, w, h, c) -> None:
    if w > 0 and h > 0:
        d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)


class Level:
    def __init__(self, rows: list[str], storefronts=None, old_town=False,
                 one_roof=None):
        self.rows = rows
        self.storefronts = storefronts or {}
        # Old town: white palazzi with green shutters, pale terraces.
        self.old_town = old_town
        # One building, not a patchwork: (row, column) -- from that row
        # down and west of that column the roof is painted whole (the back
        # of the hypermarket, in the north street).
        self.one_roof = one_roof
        self.height = len(rows)
        self.width = len(rows[0])

    def at(self, x: int, y: int) -> str:
        if 0 <= x < self.width and 0 <= y < self.height:
            return self.rows[y][x]
        return "B"

    def is_road(self, x, y) -> bool:
        return self.at(x, y) in ROAD_GLYPHS

    def is_building(self, x, y) -> bool:
        return self.at(x, y) in BUILDING_GLYPHS

    @staticmethod
    def _floor(glyph: str) -> str | None:
        """The floor `glyph` paves, if it paves one."""
        if glyph in WALK_GLYPHS:
            return "="
        if glyph in ROAD_GLYPHS:
            return "."
        if glyph in "PLY,":
            return glyph
        return None

    def _floor_along(self, x: int, y: int, dx: int, dy: int):
        """The nearest floor from (x, y) one way, and how many tiles off it
        is, never looking through a wall: a prop is paved with the street it
        stands in, not with what lies beyond the building beside it."""
        nx, ny, away = x + dx, y + dy, 1
        while (0 <= nx < self.width and 0 <= ny < self.height
               and not self.is_building(nx, ny)):
            floor = self._floor(self.rows[ny][nx])
            if floor is not None:
                return floor, away
            nx, ny, away = nx + dx, ny + dy, away + 1
        return None, 0

    def surface(self, x: int, y: int) -> str:
        """Floor under a prop or actor (`=` sidewalk, `.` road, `P` paving,
        `L` parking, `Y` stairs): the nearest floor beside it, never through
        a wall, and where two are equally near, whichever more of them say.

        A vehicle belongs to the carriageway it stands in, which runs along
        its row: a car in the outside lane has the kerb down one whole side
        of it and only the lane it blocks at its ends, so looking all round
        used to pave it with the sidewalk. Street furniture belongs instead
        to the footway beside it, and a footway runs whichever way its
        street does, so the lights and the signs look up and down their
        column too -- otherwise the ones on a side street's pavement take
        the tarmac of the road they stand at the mouth of."""
        glyph = self.at(x, y)
        floor = self._floor(glyph)
        if floor is not None:
            return floor
        ways = [(-1, 0), (1, 0)]
        if glyph in FOOTWAY_GLYPHS:
            ways += [(0, -1), (0, 1)]
        found = [self._floor_along(x, y, dx, dy) for dx, dy in ways]
        near = [f for f, away in found
                if f is not None and away == min(
                    (a for g, a in found if g is not None), default=0)]
        if glyph in FOOTWAY_GLYPHS and any(f != "." for f in near):
            # Nothing on a post stands in the carriageway: at a corner, with
            # the road on two sides of it and the kerb on the others, the
            # kerb wins however the neighbours happen to count up.
            near = [f for f in near if f != "."]
        if len(set(near)) == 1:
            return near[0]
        votes = {"=": 0, ".": 0, "P": 0, "L": 0, "Y": 0, ",": 0}
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                g = self.at(x + dx, y + dy)
                if g in WALK_GLYPHS:
                    votes["="] += 1 + (dy == 0)
                elif g in ROAD_GLYPHS:
                    votes["."] += 1 + (dy == 0)
                elif g in "PLY,":
                    votes[g] += 1 + (dy == 0)
        # Equally near and disagreeing: whichever more sides say, then the
        # neighbours, then the order of `votes`, so the pick never wavers.
        order = list(votes)
        return max(near or order,
                   key=lambda f: (near.count(f), votes[f], -order.index(f)))


def column_runs(level: Level, glyphs: set[str], skip=None):
    """Vertical runs of `glyphs`, grouped into bands of adjacent columns
    sharing the same top and bottom row. Yields (x0, width, top, bottom).
    Cells `skip(x, y)` accepts are left out, as if they were not there."""
    def taken(x, y):
        return level.at(x, y) in glyphs and not (skip and skip(x, y))

    runs: dict[tuple[int, int], list[int]] = {}
    for x in range(level.width):
        y = 0
        while y < level.height:
            if taken(x, y):
                top = y
                while y < level.height and taken(x, y):
                    y += 1
                runs.setdefault((top, y - 1), []).append(x)
            else:
                y += 1
    for (top, bottom), columns in runs.items():
        start = columns[0]
        previous = start
        for x in columns[1:] + [None]:
            if x is not None and x == previous + 1:
                previous = x
                continue
            yield start, previous - start + 1, top, bottom
            if x is not None:
                start = previous = x


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


# -------------------------------------------------------------- buildings


def paint_roof_block(d, rng, level, sx, sy, sw, sh):
    px, py, w, h = sx * TILE, sy * TILE, sw * TILE, sh * TILE
    roofs = OLD_TOWN_ROOFS if level.old_town else ROOFS
    c = roofs[rng.randrange(len(roofs))]
    light = tuple(min(255, v + 24) for v in c)
    dark = tuple(max(0, v - 20) for v in c)
    rect(d, px, py, w, h, c)
    for _ in range(sw * sh * 4):
        rect(d, px + rng.randrange(w), py + rng.randrange(h), 1, 1, dark)
    # parapet around the building, with a thin inner shadow
    rect(d, px, py, w, 2, light)
    rect(d, px, py, 2, h, light)
    rect(d, px + w - 2, py, 2, h, light)
    rect(d, px, py + h - 2, w, 2, light)
    rect(d, px + 2, py + 2, w - 4, 1, dark)
    rect(d, px + 2, py + 2, 1, h - 4, dark)
    # the side facing the street casts a shadow on the sidewalk
    for tx in range(sx, sx + sw):
        if not level.is_building(tx, sy + sh):
            rect(d, tx * TILE, py + h - 3, TILE, 3, light)
    for ty in range(sy, sy + sh):
        if not level.is_building(sx + sw, ty):
            rect(d, px + w, ty * TILE, 2, TILE, (30, 30, 34))
    # rooftop units
    for _ in range(max(1, sw * sh // 6)):
        ax = px + rng.randrange(5, max(6, w - 15))
        ay = py + rng.randrange(5, max(6, h - 14))
        roll = rng.random()
        if roll < 0.55:
            rect(d, ax, ay, 9, 6, (120, 120, 116))
            rect(d, ax + 1, ay + 1, 7, 1, (150, 150, 144))
            rect(d, ax, ay + 6, 9, 1, dark)
        elif roll < 0.8:
            rect(d, ax, ay, 4, 4, (90, 90, 88))
            rect(d, ax + 1, ay + 1, 2, 2, (40, 40, 42))
        elif roll < 0.92 and w >= 48 and h >= 48:
            rect(d, ax, ay, 14, 12, (90, 70, 56))
            rect(d, ax, ay, 14, 3, (120, 96, 74))
            rect(d, ax, ay + 12, 14, 1, dark)
        else:  # skylight
            rect(d, ax, ay, 10, 8, (50, 62, 76))
            rect(d, ax + 1, ay + 1, 8, 1, (90, 110, 130))


def shade(c, amount):
    return tuple(max(0, min(255, v + amount)) for v in c)


def paint_boarded_door(d, rng, x, y, w, h):
    """Planks nailed across a door: three crooked boards and a brace."""
    for i, by in enumerate((y + 2, y + 6, y + 10)):
        tilt = rng.choice((-1, 0, 1))
        colour = WOOD if i % 2 == 0 else (136, 104, 70)
        for bx in range(-2, w + 2):
            rect(d, x + bx, by + (tilt * bx) // w, 1, 3, colour)
        rect(d, x - 1, by + 1, 1, 1, NAIL)
        rect(d, x + w, by + 1 + tilt, 1, 1, NAIL)
    for i in range(h - 2):
        rect(d, x + 1 + i * (w - 3) // (h - 2), y + 1 + i, 2, 1, WOOD_DARK)


SHOPS = {
    # kind: (wall, trim, board, letters, sign text, missing letters)
    "kebab": ((150, 132, 104), (110, 94, 72), (150, 34, 26), (246, 206, 70), "KEBAB", ()),
    "alimentari": ((96, 98, 104), (68, 70, 76), (40, 96, 52), (232, 232, 220), "ALIMENTARI", (6,)),
    "pizzeria": ((116, 58, 48), (80, 38, 34), (226, 220, 200), (150, 34, 26), "PIZZERIA", ()),
    "bar": ((70, 84, 96), (50, 60, 70), (70, 44, 30), (236, 214, 160), "BAR", ()),
    "abbigliamento": ((120, 104, 120), (84, 70, 86), (60, 40, 90), (236, 226, 240), "ABBIGLIAMENTO", (3, 9)),
    "burger": ((140, 126, 96), (100, 88, 64), (170, 30, 28), (250, 200, 50), "BURGER", ()),
    "elettronica": ((84, 90, 104), (58, 62, 74), (26, 46, 96), (120, 220, 240), "ELETTRONICA", (4,)),
    "kebab2": ((122, 112, 92), (88, 78, 62), (36, 92, 58), (250, 226, 120), "KEBAB", (2,)),
    "barsport": ((104, 86, 70), (70, 56, 46), (30, 60, 110), (240, 210, 90), "BAR SPORT", (5,)),
    "pescheria": ((214, 208, 192), (170, 164, 148), (34, 70, 118), (236, 236, 226), "PESCHERIA", (7,)),
    "gelateria": ((222, 218, 204), (176, 170, 156), (226, 170, 180), (120, 40, 60), "GELATERIA", ()),
    # Letters in rainbow colours (see paint_storefront), all still there.
    "arcobaleno": ((196, 186, 168), (150, 140, 124), (30, 28, 36), RAINBOW[0], "BAR ARCOBALENO", ()),
}


def paint_shutter(d, x, y, w, h, drop):
    """Roller shutter pulled down to `drop` px, dented and tagged."""
    rect(d, x, y, w, h, SHOP_DARK)
    rect(d, x, y, w, drop, (104, 106, 108))
    for sy in range(y + 1, y + drop, 2):
        rect(d, x, sy, w, 1, (84, 86, 90))
    rect(d, x + w // 3, y + drop - 3, 3, 3, (60, 62, 66))  # dent
    # graffiti tag
    for i in range(0, min(w - 4, 14), 2):
        rect(d, x + 2 + i, y + 3 + (i % 4) // 2, 2, 1, (60, 150, 170))
    rect(d, x + 3, y + 6, min(w - 6, 10), 1, (190, 60, 150))


def paint_torn_awning(d, rng, x, y, w):
    """Striped café awning, ripped and sagging, rags hanging off it."""
    for i in range(0, w, 4):
        colour = (180, 40, 36) if (i // 4) % 2 else (226, 218, 196)
        drop = 0 if rng.random() < 0.7 else rng.randint(2, 6)
        rect(d, x + i, y, 4, 5 + drop, colour)
        if rng.random() < 0.25:
            rect(d, x + i, y + 1, 4, 3, (30, 26, 26))  # a hole
    rect(d, x, y - 1, w, 1, (60, 60, 62))
    rect(d, x + w // 3, y + 4, 1, 6, (60, 60, 62))  # a broken strut


def paint_smashed_display(d, x, y, w, h):
    """Shop window with its glass smashed in: looted shelves and a couple of
    dead screens still on display."""
    rect(d, x, y, w, h, (14, 16, 22))
    rect(d, x, y + h - 3, w, 1, (60, 60, 64))  # shelf
    for i, sx in enumerate(range(x + 1, x + w - 5, 7)):
        rect(d, sx, y + h - 9, 6, 6, (40, 42, 48))
        rect(d, sx + 1, y + h - 8, 4, 4, (26, 40, 52) if i % 2 else (10, 12, 16))
        rect(d, sx + 2, y + h - 7, 1, 2, (160, 200, 220))  # crack
    for i in range(0, w, 3):  # glass teeth still in the frame
        rect(d, x + i, y, 1, 1 + (i * 7) % 4, (150, 180, 200))
        rect(d, x + i + 1, y + h - 1, 1, 1, (150, 180, 200))


def paint_boards(d, x, y, w, h):
    """Planks nailed across a smashed window."""
    rect(d, x, y, w, h, (20, 22, 28))
    for i in range(0, w, 5):
        rect(d, x + i + 1, y + (i * 3) % 4, 2, 2, (140, 170, 190))  # glass
    wood, dark = (122, 92, 60), (86, 62, 40)
    for i in range(0, max(w, h)):
        rect(d, x + i * w // max(w, h), y + i * h // max(w, h), 3, 2, wood)
        rect(d, x + w - 3 - i * w // max(w, h), y + i * h // max(w, h), 3, 2, dark)
    rect(d, x, y + h // 2 - 1, w, 3, wood)


def paint_icon(d, kind, x, y):
    """8x8 icon on the sign, top-left at (x, y)."""
    if kind.startswith("kebab"):
        rect(d, x + 3, y, 1, 8, (170, 170, 170))
        for i, wdt in enumerate((2, 4, 5, 5, 4, 3)):
            rect(d, x + 4 - wdt // 2, y + 1 + i, wdt, 1, (150, 90, 40) if i % 2 else (190, 120, 60))
    elif kind == "pizzeria":
        rect(d, x + 1, y + 1, 6, 6, (230, 190, 90))
        rect(d, x + 2, y + 2, 4, 4, (200, 60, 40))
        rect(d, x + 3, y + 3, 1, 1, (250, 240, 220))
        rect(d, x + 5, y + 4, 1, 1, (70, 120, 50))
    elif kind.startswith("bar"):
        rect(d, x + 1, y + 3, 5, 4, (240, 236, 226))
        rect(d, x + 6, y + 4, 1, 2, (240, 236, 226))
        rect(d, x + 2, y + 3, 3, 1, (110, 70, 40))
        rect(d, x + 2, y, 1, 2, (200, 200, 200))
        rect(d, x + 4, y + 1, 1, 2, (200, 200, 200))
    elif kind == "burger":
        rect(d, x + 1, y + 1, 6, 2, (220, 150, 60))
        rect(d, x, y + 3, 8, 1, (90, 170, 60))
        rect(d, x + 1, y + 4, 6, 2, (110, 60, 30))
        rect(d, x + 1, y + 6, 6, 1, (220, 150, 60))
    elif kind == "alimentari":
        rect(d, x + 1, y + 3, 6, 4, (150, 110, 60))
        rect(d, x + 2, y + 1, 2, 2, (200, 50, 40))
        rect(d, x + 4, y + 2, 2, 2, (240, 200, 60))
    elif kind == "elettronica":  # an old television set
        rect(d, x, y + 1, 8, 6, (60, 64, 70))
        rect(d, x + 1, y + 2, 5, 4, (120, 220, 240))
        rect(d, x + 2, y + 3, 2, 1, (230, 250, 255))
        rect(d, x + 6, y + 2, 1, 1, (200, 60, 40))
        rect(d, x + 2, y, 1, 1, (160, 160, 160))
        rect(d, x + 5, y, 1, 1, (160, 160, 160))
        rect(d, x + 1, y + 7, 1, 1, (40, 40, 44))
        rect(d, x + 6, y + 7, 1, 1, (40, 40, 44))
    elif kind == "pescheria":  # a fish
        rect(d, x + 1, y + 3, 5, 3, (170, 190, 200))
        rect(d, x + 2, y + 2, 3, 1, (170, 190, 200))
        rect(d, x + 2, y + 6, 3, 1, (170, 190, 200))
        rect(d, x + 6, y + 2, 1, 5, (130, 150, 160))
        rect(d, x + 2, y + 3, 1, 1, (30, 30, 34))
    elif kind == "gelateria":  # a cone
        rect(d, x + 2, y, 4, 3, (240, 220, 200))
        rect(d, x + 3, y + 1, 2, 1, (170, 90, 60))
        for i in range(4):
            rect(d, x + 2 + i // 2, y + 3 + i, 4 - i, 1, (200, 150, 80))
    elif kind == "arcobaleno":  # a little rainbow
        for i, colour in enumerate(RAINBOW[:4]):
            rect(d, x + i, y + 1 + i, 8 - i * 2, 1, colour)
            rect(d, x + i, y + 1 + i, 1, 7 - i, colour)
            rect(d, x + 7 - i, y + 1 + i, 1, 7 - i, colour)
    elif kind == "abbigliamento":
        rect(d, x + 3, y, 2, 1, (200, 200, 200))
        rect(d, x + 1, y + 2, 6, 1, (200, 200, 200))
        rect(d, x + 1, y + 2, 1, 3, (200, 200, 200))
        rect(d, x + 6, y + 2, 1, 3, (200, 200, 200))
        rect(d, x + 2, y + 3, 4, 5, (170, 120, 190))


def paint_storefront(d, rng, px, py0, w, h, kind):
    wall, trim, board, letters, text, missing = SHOPS[kind]
    rect(d, px, py0, w, h, wall)
    rect(d, px, py0, w, 3, trim)
    rect(d, px + w - 1, py0, 1, h, trim)
    shop_top = py0 + h - 17
    sign_top = shop_top - 12
    # flats upstairs
    for wy in range(py0 + 8, sign_top - 10, 14):
        for wx in range(px + 5, px + w - 8, 12):
            roll = rng.random()
            pane = PANE if roll > 0.3 else (PANE_LIT if roll > 0.15 else PANE_BROKEN)
            rect(d, wx - 1, wy - 1, 8, 10, trim)
            rect(d, wx, wy, 6, 8, pane)
    # sign board: text, icon, cracks and soot
    rect(d, px + 2, sign_top, w - 4, 11, OUTLINE)
    rect(d, px + 3, sign_top + 1, w - 6, 9, board)
    if kind == "pizzeria":
        rect(d, px + 3, sign_top + 1, 4, 9, (40, 120, 60))
        rect(d, px + w - 7, sign_top + 1, 4, 9, (180, 36, 30))
    label_w = text_width(text) + (10 if w - 6 >= text_width(text) + 12 else 0)
    lx = px + (w - label_w) // 2
    if label_w > text_width(text):
        paint_icon(d, kind, lx, sign_top + 2)
        lx += 10
    if kind == "arcobaleno":
        for i, letter in enumerate(text):
            paint_text(d, lx + i * 4, sign_top + 3, letter, RAINBOW[i % len(RAINBOW)])
    else:
        paint_text(d, lx, sign_top + 3, text, letters, missing)
    rect(d, px + w - 6, sign_top + 1, 1, 9, OUTLINE)  # crack at the edge
    rect(d, px + w - 5, sign_top + 5, 1, 5, OUTLINE)
    rect(d, px + 3, sign_top + 7, 6, 3, (40, 30, 30))  # soot
    # ground floor: wrecked and shut
    rect(d, px + 2, shop_top, w - 4, 17, trim)
    door_w = 12
    door_x = px + (w - door_w) // 2
    window_w = (w - 8 - door_w) // 2
    if kind == "arcobaleno":  # its door kicked in: the one you can go through
        rect(d, door_x, shop_top + 2, door_w, 15, (12, 10, 12))
        rect(d, door_x, shop_top + 2, 3, 15, (70, 50, 36))  # the door, hanging
        rect(d, door_x + 1, shop_top + 8, 1, 2, (180, 160, 90))
    else:
        paint_shutter(d, door_x, shop_top + 2, door_w, 15, 15)
    for wx in (px + 3, door_x + door_w + 1):
        if kind in ("kebab", "kebab2", "bar", "burger"):
            paint_boards(d, wx, shop_top + 2, window_w, 12)
        elif kind in ("elettronica", "barsport"):
            paint_smashed_display(d, wx, shop_top + 2, window_w, 12)
        else:
            paint_shutter(d, wx, shop_top + 2, window_w, 12, 8 + rng.randrange(4))
    if kind == "barsport":
        paint_torn_awning(d, rng, px + 2, shop_top - 3, w - 4)
        for _ in range(8):  # grime and splashes on the wall
            rect(d, px + rng.randrange(2, w - 6), py0 + rng.randrange(4, h - 6),
                 rng.randint(2, 5), rng.randint(1, 3), rng.choice(((60, 48, 40), BLOOD_DARK)))
    # scorch marks licking up from the shop
    for _ in range(3):
        sx = px + rng.randrange(3, w - 6)
        rect(d, sx, shop_top - 2, 4, 3, (36, 30, 30))
        rect(d, sx + 1, shop_top - 5, 2, 3, (36, 30, 30))


def paint_barracks(d, level):
    """Carabinieri barracks: cream facade, dark blue sign with the flaming
    grenade, barred windows and a wide-open front door spilling light."""
    if not any("K" in row for row in level.rows):
        return
    cells = [(x, y) for y in range(level.height) for x in range(level.width)
             if level.at(x, y) in "KE" and level.at(x, y + 1) not in "BK"
             or level.at(x, y) == "K"]
    xs = [x for x, _ in cells]
    ys = [y for _, y in cells]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    px, py, w, h = x0 * TILE, y0 * TILE, (x1 - x0 + 1) * TILE, (y1 - y0 + 1) * TILE
    stone, stone_dark = (206, 190, 150), (160, 144, 108)
    rect(d, px, py, w, h, stone)
    rect(d, px, py, w, 4, (120, 106, 80))  # cornice
    rect(d, px, py + h - 6, w, 6, stone_dark)  # plinth
    for bx in range(px, px + w, 8):
        rect(d, bx, py + h - 6, 1, 6, (130, 116, 86))
    # sign across the top with the emblem
    sign_w = text_width("CARABINIERI") + 20
    sx = px + (w - sign_w) // 2
    rect(d, sx, py + 6, sign_w, 11, OUTLINE)
    rect(d, sx + 1, py + 7, sign_w - 2, 9, (24, 34, 72))
    paint_text(d, sx + 16, py + 9, "CARABINIERI", (240, 240, 236))
    paint_emblem(d, sx + 3, py + 4)
    # barred windows
    door_x = next(x for x in range(level.width) for y in range(level.height)
                  if level.at(x, y) == "E") * TILE
    for wx in range(px + 8, px + w - 8, 18):
        if door_x - 14 <= wx <= door_x + 16:
            continue
        rect(d, wx - 1, py + 24, 12, 16, stone_dark)
        rect(d, wx, py + 25, 10, 14, (30, 36, 48))
        for bar in range(wx + 1, wx + 10, 3):
            rect(d, bar, py + 25, 1, 14, (80, 84, 90))
        rect(d, wx, py + 31, 10, 1, (80, 84, 90))
    # the open door: stone arch, doors swung inwards, warm light inside
    dx, dy = door_x - 4, py + h - 30
    rect(d, dx, dy, 24, 30, stone_dark)
    rect(d, dx + 2, dy + 2, 20, 28, (70, 50, 30))
    rect(d, dx + 4, dy + 4, 16, 26, (238, 196, 110))
    rect(d, dx + 6, dy + 8, 12, 22, (252, 222, 150))
    rect(d, dx + 8, dy + 14, 8, 16, (255, 238, 190))
    rect(d, dx + 2, dy + 4, 3, 26, (100, 66, 36))  # door leaves
    rect(d, dx + 19, dy + 4, 3, 26, (100, 66, 36))
    rect(d, dx + 3, dy + 16, 1, 2, (220, 190, 90))  # handles
    rect(d, dx + 20, dy + 16, 1, 2, (220, 190, 90))
    rect(d, dx + 7, dy - 3, 10, 2, (230, 230, 230))  # lamp over the door
    rect(d, dx + 9, dy - 1, 6, 1, (255, 240, 180))
    # light spilling on the forecourt and a doormat
    spill = [(252, 222, 150), (220, 196, 140), (170, 156, 120)]
    for i, colour in enumerate(spill):
        rect(d, dx + 2 - i * 2, py + h + i * 3, 20 + i * 4, 3, colour)
    rect(d, dx + 6, py + h, 12, 3, (130, 40, 36))


def paint_emblem(d, x, y):
    """Flaming grenade, 11x13, top-left at (x, y)."""
    flame = [(250, 210, 80), (230, 120, 40), (200, 60, 30)]
    for i, (fx, fy, fw, fh) in enumerate(((4, 0, 3, 5), (2, 2, 2, 3), (7, 2, 2, 3), (5, 1, 1, 5))):
        rect(d, x + fx, y + fy, fw, fh, flame[i % 3])
    rect(d, x + 3, y + 5, 5, 2, (200, 170, 70))  # collar
    rect(d, x + 2, y + 7, 7, 6, (200, 170, 70))  # grenade
    rect(d, x + 1, y + 8, 9, 4, (200, 170, 70))
    rect(d, x + 3, y + 8, 2, 2, (250, 230, 150))
    rect(d, x + 4, y + 10, 3, 1, (130, 100, 40))


# ------------------------------------------------------------ hypermarket


def paint_hypermarket(d, rng, level):
    """Multi-storey hypermarket at the end of the north road: clad in grey
    panels, ribbon windows on the upper floors; on the first floor, where
    the eye falls, a giant sign missing half its letters between two
    advertising hoardings ripped to shreds; at street level its doors stand
    open on the dark hall."""
    cells = [(x, y) for y in range(level.height) for x in range(level.width)
             if level.at(x, y) == "M"]
    if not cells:
        return
    xs = [x for x, _ in cells]
    ys = [y for _, y in cells]
    px, py = min(xs) * TILE, min(ys) * TILE
    w, h = (max(xs) - min(xs) + 1) * TILE, (max(ys) - min(ys) + 1) * TILE
    panel, panel_dark, trim = (150, 150, 146), (118, 118, 116), (84, 84, 86)
    rect(d, px, py, w, h, panel)
    for bx in range(px, px + w, 8):  # cladding seams
        rect(d, bx, py, 1, h, panel_dark)
    rect(d, px, py, w, 5, trim)  # parapet
    rect(d, px, py + 5, w, 1, (60, 60, 62))
    # the entrance, where the `m` doors are
    doors = [x for y in range(level.height) for x in range(level.width)
             if level.at(x, y) == "m"]
    door_x, door_w = min(doors) * TILE, len(doors) * TILE
    ground = py + h - 26
    # upper floors: ribbon windows, panes smashed here and there
    band_top = ground - 30  # where the signs start, low enough to be seen
    for floor, wy in enumerate(range(py + 10, band_top - 12, 18)):
        rect(d, px + 4, wy - 1, w - 8, 12, trim)
        for wx in range(px + 5, px + w - 8, 8):
            roll = rng.random()
            pane = (40, 50, 64) if roll > 0.35 else (PANE_BROKEN if roll > 0.1 else PANE_LIT)
            rect(d, wx, wy, 7, 10, pane)
            if pane == PANE_BROKEN:
                rect(d, wx + 1, wy, 2, 3, (90, 110, 130))
                rect(d, wx + 4, wy + 7, 2, 3, (90, 110, 130))
            else:
                rect(d, wx + 1, wy + 1, 1, 3, (90, 110, 130))
        if floor == 0:  # soot streaks from a fire on the upper floor
            for sx in (px + w // 3, px + w // 3 + 9):
                rect(d, sx, wy - 7, 7, 7, (60, 58, 58))
                rect(d, sx + 2, wy - 11, 3, 4, (80, 78, 76))
    # the first floor carries the signs: the giant name over the entrance,
    # letters fallen off or hanging crooked, and ripped hoardings either side
    sign_text = "IPERMERCATO"
    sign_w = text_width(sign_text) * 2 + 12
    sx = door_x + door_w // 2 - sign_w // 2
    sy = band_top + 2
    rect(d, sx, sy, sign_w, 16, OUTLINE)
    rect(d, sx + 1, sy + 1, sign_w - 2, 14, (150, 26, 30))
    paint_text(d, sx + 6, sy + 3, sign_text, (250, 236, 200),
               missing=(2, 7), scale=2, tilted=(9,))
    for wire_x in (sx + 6 + 2 * 8 + 2, sx + 6 + 7 * 8 + 2):  # bare wires
        rect(d, wire_x, sy + 5, 1, 6, (40, 40, 44))
        rect(d, wire_x + 1, sy + 10, 1, 3, (40, 40, 44))
    rect(d, sx + sign_w - 20, sy + 1, 1, 14, OUTLINE)  # cracks
    rect(d, sx + 30, sy + 7, 8, 1, OUTLINE)
    for (left, right), text in (((px + 8, sx - 8), "SCONTI -50%"),
                                ((sx + sign_w + 8, px + w - 8), "OFFERTE!")):
        hw = min(right - left, 64)
        paint_hoarding(d, rng, left + (right - left - hw) // 2, sy, hw, 17, text)
    # ground floor: a canopy over the entrance, its doors stuck open
    rect(d, px, ground - 2, w, 2, trim)
    rect(d, door_x - 6, ground - 6, door_w + 12, 5, (40, 110, 70))  # canopy
    for i in range(0, door_w + 12, 6):
        rect(d, door_x - 6 + i, ground - 1, 3, 2 + (i * 5) % 4, (40, 110, 70))
    rect(d, door_x - 6, ground - 6, door_w + 12, 1, (70, 150, 100))
    paint_text(d, door_x + (door_w - text_width("ENTRATA")) // 2, ground - 6 + 0,
               "ENTRATA", (230, 240, 230))
    # through the doorway: the dark hall and its glossy floor
    rect(d, door_x, ground, door_w, 26, (14, 14, 18))
    for fy in range(ground + 12, ground + 26, 4):
        shade = 60 + (fy - ground) * 4
        rect(d, door_x, fy, door_w, 3, (shade, shade - 2, shade - 6))
    for fx in range(door_x + 4, door_x + door_w, 10):  # floor joints fanning out
        rect(d, fx, ground + 12, 1, 14, (50, 50, 54))
    rect(d, door_x + 6, ground + 4, 8, 6, (40, 40, 46))  # shelves far inside
    rect(d, door_x + door_w - 16, ground + 5, 10, 5, (46, 40, 40))
    # the sliding glass panels, pushed aside and cracked
    for gx in (door_x - 2, door_x + door_w - 6):
        rect(d, gx, ground, 8, 26, (40, 56, 70))
        rect(d, gx + 2, ground + 3, 1, 18, (150, 180, 200))
        rect(d, gx + 4, ground + 9, 3, 1, (150, 180, 200))
    rect(d, door_x - 2, ground, door_w + 4, 1, trim)
    # shop windows either side, papered over with torn special offers
    for wx in (px + 8, door_x + door_w + 12):
        ww = door_x - 12 - px - 8 if wx == px + 8 else px + w - 8 - wx
        rect(d, wx, ground + 2, ww, 20, (22, 24, 30))
        for i, ox in enumerate(range(wx, wx + ww - 15, 16)):
            rect(d, ox, ground + 2, 1, 20, trim)
            roll = rng.random()
            if roll < 0.35:
                paint_poster(d, rng, ox + 2, ground + 4, 12, 14, i)
            elif roll < 0.6:
                paint_smashed_display(d, ox + 1, ground + 3, 15, 18)
            elif roll < 0.8:
                paint_boards(d, ox + 1, ground + 3, 15, 18)
            else:
                rect(d, ox + 3, ground + 4, 2, 8, (60, 70, 86))  # reflection
    # scorch and graffiti on the plinth
    for gx in range(px + 12, px + w - 12, 34):
        rect(d, gx, py + h - 5, 10, 1, (190, 60, 150))
        rect(d, gx + 2, py + h - 4, 8, 1, (60, 150, 170))


DUOMO_STONE = (216, 198, 160)
DUOMO_LIGHT = (232, 218, 184)
DUOMO_SHADE = (184, 164, 128)
DUOMO_DARK = (140, 122, 94)
DUOMO_JOINT = (196, 178, 142)
DUOMO_ROOF = (170, 150, 118)
DUOMO_ROOF_DARK = (136, 118, 90)
DUOMO_HOLE = (34, 28, 26)


def _ashlar(d, rng, x, y, w, h, base=DUOMO_STONE):
    """Limestone blocks: courses 4 px tall, staggered joints, a few paler
    or darker blocks, salt and grime."""
    rect(d, x, y, w, h, base)
    for row, cy in enumerate(range(y, y + h, 4)):
        rect(d, x, cy, w, 1, DUOMO_JOINT)
        for jx in range(x + (row % 2) * 5, x + w, 10):
            rect(d, jx, cy, 1, 4, DUOMO_JOINT)
        for bx in range(x + (row % 2) * 5, x + w - 9, 10):
            roll = rng.random()
            if roll < 0.12:
                rect(d, bx + 1, cy + 1, 9, 3, DUOMO_LIGHT)
            elif roll < 0.2:
                rect(d, bx + 1, cy + 1, 9, 3, DUOMO_SHADE)


def _arch_window(d, x, y, w, h, frame=DUOMO_LIGHT):
    """Round-headed opening: a stone frame, dark inside."""
    r = w // 2
    rect(d, x - 1, y + r - 1, w + 2, h - r + 1, frame)
    for dy in range(r + 1):
        half = round(math.sqrt(max(0, r * r - (r - dy) ** 2)))
        rect(d, x + r - half - 1, y + dy - 1, 2 * half + 2, 1, frame)
        rect(d, x + r - half, y + dy, 2 * half, 1, DUOMO_HOLE)
    rect(d, x, y + r, w, h - r, DUOMO_HOLE)


def _bifora(d, x, y, w, h):
    """Two arched openings side by side, a slim column between them."""
    half = (w - 2) // 2
    _arch_window(d, x, y, half, h)
    _arch_window(d, x + half + 2, y, half, h)
    rect(d, x + half, y + half // 2, 2, h - half // 2, DUOMO_LIGHT)


def _blind_arcade(d, x, y, w):
    """The little blind arches running under the cornices."""
    rect(d, x, y + 5, w, 1, DUOMO_SHADE)
    for ax in range(x + 1, x + w - 4, 6):
        rect(d, ax, y + 1, 4, 1, DUOMO_SHADE)
        rect(d, ax, y + 1, 1, 4, DUOMO_SHADE)
        rect(d, ax + 4, y + 1, 1, 4, DUOMO_SHADE)


def _pyramid(d, cx, top, base, half):
    """A stone pyramid roof, lit from the west."""
    for dy in range(base - top):
        span = half * dy // max(1, base - top - 1)
        rect(d, cx - span, top + dy, span, 1, DUOMO_ROOF)
        rect(d, cx, top + dy, span + 1, 1, DUOMO_ROOF_DARK)
        if dy % 3 == 2:
            rect(d, cx - span, top + dy, 2 * span + 1, 1, DUOMO_SHADE)


def _tower(d, rng, x, y, w, h):
    """A square bell tower: courses of stone, a string course at each
    level, a bifora at each of the two belfries, a cornice at the top."""
    _ashlar(d, rng, x, y, w, h)
    rect(d, x + w - 4, y, 4, h, DUOMO_SHADE)  # its east side, in shadow
    rect(d, x - 2, y, w + 4, 4, DUOMO_LIGHT)  # the cornice
    rect(d, x - 2, y + 4, w + 4, 1, DUOMO_DARK)
    for ly, lh in ((y + 9, 16), (y + 34, 18), (y + 62, 12)):
        _bifora(d, x + w // 2 - 7, ly, 14, lh)
        rect(d, x - 1, ly + lh + 3, w + 2, 2, DUOMO_LIGHT)  # string course
        rect(d, x - 1, ly + lh + 5, w + 2, 1, DUOMO_DARK)


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


def paint_flower_bed(d, rng, level, x, y):
    """A bed raised behind a kerb of the same stone as the paving: dry
    earth, a shrub gone leggy and some weeds over the edge."""
    px, py = x * TILE, y * TILE
    kerb, earth = (192, 184, 166), (78, 62, 48)
    rect(d, px, py, TILE, TILE, kerb)
    rect(d, px + 2, py + 2, TILE - 4, TILE - 4, earth)
    rect(d, px, py, TILE, 2, shade(kerb, 16))
    rect(d, px, py + TILE - 2, TILE, 2, shade(kerb, -34))
    if level.at(x, y - 1) != "&":
        rect(d, px + 2, py + 2, TILE - 4, 1, shade(earth, -18))
    for _ in range(9):
        rect(d, px + 2 + rng.randrange(TILE - 5), py + 2 + rng.randrange(TILE - 5),
             2, 1, shade(earth, rng.randint(-12, 14)))
    for _ in range(7):  # what is left growing in it
        gx = px + 3 + rng.randrange(TILE - 7)
        gy = py + 4 + rng.randrange(TILE - 9)
        green = rng.choice(((74, 96, 52), (92, 112, 58), (60, 80, 46)))
        rect(d, gx, gy, 2, rng.randint(3, 6), green)
    if rng.random() < 0.4:
        rect(d, px + rng.randrange(3, 11), py + TILE - 3, 4, 3, (86, 100, 58))


def paint_street_fountain(d, px, py):
    """The drinking fountain of the piazzetta, over two cells by two: a
    low kerbed basin, green with algae, and the stone column standing in
    it with its brass spout over a scalloped bowl."""
    stone, lit, dark = (196, 186, 166), (216, 208, 190), (140, 130, 112)
    water, algae = (62, 78, 72), (78, 96, 58)
    w = h = 2 * TILE
    # the basin: a rounded kerb, the water inside it barely moving
    d.rounded_rectangle([px + 1, py + 6, px + w - 2, py + h - 2], radius=9,
                        fill=stone, outline=dark)
    d.rounded_rectangle([px + 5, py + 10, px + w - 6, py + h - 6], radius=6,
                        fill=water)
    for i in range(px + 6, px + w - 6, 5):
        rect(d, i, py + h - 9, 3, 2, algae)
    rect(d, px + 2, py + 6, w - 4, 2, lit)          # the light on the kerb
    rect(d, px + 2, py + h - 4, w - 4, 2, dark)
    # the column, standing in the middle of it
    cx = px + w // 2
    rect(d, cx - 5, py + h - 16, 10, 7, dark)       # its plinth
    rect(d, cx - 4, py + h - 17, 8, 2, lit)
    rect(d, cx - 4, py - 4, 8, h - 13, stone)       # the shaft
    rect(d, cx - 4, py - 4, 2, h - 13, lit)
    rect(d, cx + 2, py - 4, 2, h - 13, dark)
    for cy in range(py + 2, py + h - 14, 7):        # grime run down it
        rect(d, cx - 3, cy, 5, 1, shade(stone, -22))
    rect(d, cx - 6, py - 8, 12, 5, stone)           # the cap
    rect(d, cx - 6, py - 8, 12, 2, lit)
    rect(d, cx - 3, py - 11, 6, 3, dark)
    rect(d, cx - 1, py + 6, 4, 3, (132, 104, 44))   # the brass spout
    rect(d, cx - 5, py + 9, 10, 4, stone)           # the scalloped bowl
    rect(d, cx - 4, py + 10, 8, 2, dark)
    rect(d, cx - 1, py + 13, 2, 6, (118, 140, 150))  # the trickle it still runs


def paint_small_church(d, rng, level):
    """San Nicola, up in the warren of alleys: one plain gabled front in
    the same limestone as the Duomo, a small rose window over an arched
    portal, a bell gable with its bell on the west corner, and two worn
    steps down to the square."""
    cells = [(x, y) for y in range(level.height) for x in range(level.width)
             if level.at(x, y) == "#"]
    if not cells:
        return
    x0 = min(x for x, _ in cells) * TILE
    y0 = min(y for _, y in cells) * TILE
    w = (max(x for x, _ in cells) + 1) * TILE - x0
    bottom = (max(y for _, y in cells) + 1) * TILE
    cx = x0 + w // 2
    paint_roof_block(d, rng, level, x0 // TILE, y0 // TILE, w // TILE,
                     (bottom - y0) // TILE)

    # the nave, its gable rising over the front
    nave_l, nave_r = x0, x0 + w
    gable_top = y0 + 14
    front = y0 + 30
    _ashlar(d, rng, nave_l, front, nave_r - nave_l, bottom - front)
    for dy in range(front - gable_top):  # the gable, sloping both ways
        span = (nave_r - nave_l) * dy // (2 * (front - gable_top))
        _ashlar(d, rng, cx - span, gable_top + dy, 2 * span + 1, 1)
        rect(d, cx - span, gable_top + dy, 3, 1, DUOMO_LIGHT)
        rect(d, cx + span - 2, gable_top + dy, 3, 1, DUOMO_DARK)
    rect(d, nave_l, front - 1, nave_r - nave_l, 2, DUOMO_LIGHT)
    _blind_arcade(d, nave_l + 2, front + 2, nave_r - nave_l - 4)

    # the rose window, plain: a ring of stone with eight spokes, set in the
    # front wall between the cornice and the portal
    rose_y = front + 16
    d.ellipse([cx - 9, rose_y - 9, cx + 9, rose_y + 9], fill=DUOMO_LIGHT)
    d.ellipse([cx - 7, rose_y - 7, cx + 7, rose_y + 7], fill=DUOMO_HOLE)
    for i in range(8):
        a = math.pi * i / 4
        rect(d, cx + round(5 * math.cos(a)), rose_y + round(5 * math.sin(a)),
             1, 1, DUOMO_SHADE)

    # The portal, standing open on the dark of the nave: both leaves are
    # folded back against the jambs, and the daylight falling through lies
    # in a wedge across the worn steps -- the church of San Nicola can be
    # walked into, unlike the Duomo behind its gate.
    door_w = 16
    dx = cx - door_w // 2
    _arch_window(d, dx, bottom - 26, door_w, 26)
    rect(d, dx, bottom - 21, door_w, 21, (16, 14, 18))
    for leaf in (dx, dx + door_w - 4):
        rect(d, leaf, bottom - 19, 4, 19, DOOR_GREEN)
        rect(d, leaf + 1, bottom - 18, 2, 17, shade(DOOR_GREEN, 18))
        rect(d, leaf, bottom - 19, 4, 1, shade(DOOR_GREEN, -20))
    for i, sy in enumerate((bottom - 4, bottom - 2)):
        rect(d, cx - door_w, sy, door_w * 2, 2, shade(DUOMO_STONE, -8 * i))
    rect(d, dx + 4, bottom - 4, door_w - 8, 4, shade(DUOMO_STONE, 22))

    # the bell gable on the west corner, a bell hanging in its arch
    bx, by = x0, y0 + 8
    _ashlar(d, rng, bx, by, 20, front - by + 8)
    rect(d, bx, by, 20, 3, DUOMO_LIGHT)
    _arch_window(d, bx + 5, by + 7, 8, 14)
    rect(d, bx + 7, by + 13, 4, 5, (96, 82, 46))  # the bell
    rect(d, bx + 6, by + 17, 6, 2, (120, 102, 58))


def paint_yard_wall(d, rng, level, x, y):
    """Concrete panels with a capping along the top, rust running down
    them and the odd sprayed tag."""
    px, py = x * TILE, y * TILE
    slab, joint = (146, 142, 134), (110, 106, 100)
    rect(d, px, py, TILE, TILE, slab)
    for _ in range(6):
        rect(d, px + rng.randrange(TILE), py + rng.randrange(TILE), 2, 1,
             shade(slab, -rng.randint(6, 16)))
    if x % 3 == 0:  # the joint between one panel and the next
        rect(d, px, py, 1, TILE, joint)
    if not level.is_building(x, y + 1):  # the top of the wall, then shadow
        rect(d, px, py, TILE, 4, (176, 172, 164))
        rect(d, px, py + 4, TILE, 1, joint)
        rect(d, px, py + TILE - 3, TILE, 3, (40, 40, 44))
    if not level.is_building(x + 1, y):
        rect(d, px + TILE - 2, py, 2, TILE, joint)
    if rng.random() < 0.25:
        rect(d, px + rng.randrange(2, 13), py + 5, 1, rng.randint(4, 9),
             (126, 74, 46))
    if rng.random() < 0.12:
        rect(d, px + 3, py + 7, 9, 4, (70, 86, 110))


def paint_hull(d, rng, px, py, w, h):
    """A fishing boat up on the stocks, seen from above with her bow to the
    west: white topsides over a red bottom, the deck open amidships, the
    wheelhouse aft, and timber shores holding her upright."""
    white, shadow = (186, 182, 172), (120, 116, 110)
    red, deck, rail = (128, 52, 40), (146, 118, 78), (208, 204, 194)
    keel_y = py + h // 2

    def half_width(i):
        """Fine at the stem, full amidships, still broad at the transom."""
        t = i / (w - 20)
        return int((h // 2 - 6) * min(1.0, 0.18 + 1.5 * t ** 0.6))

    for i in range(w - 20):  # her shadow, cast south-east under the hull
        half = half_width(i)
        rect(d, px + 12 + i, keel_y - half + 5, 1, 2 * half, (58, 56, 56))
    for i in range(w - 20):  # the red bottom, widest at the turn of the bilge
        half = half_width(i)
        rect(d, px + 8 + i, keel_y - half, 1, 2 * half, red)
    for i in range(w - 20):  # the white topsides inside it
        half = max(1, half_width(i) - 4)
        rect(d, px + 8 + i, keel_y - half, 1, 2 * half, white)
        if i % 11 == 0:
            rect(d, px + 8 + i, keel_y - half, 1, 2 * half, shadow)
    for i in range(w - 20):  # the capping rail all the way round
        half = half_width(i) - 4
        if half > 0:
            rect(d, px + 8 + i, keel_y - half, 1, 2, rail)
            rect(d, px + 8 + i, keel_y + half - 2, 1, 2, shadow)
    rect(d, px + w - 14, keel_y - h // 2 + 8, 2, h - 16, rail)  # the transom

    hold_x = px + 8 + (w - 20) // 3
    rect(d, hold_x, keel_y - h // 4, (w - 20) // 3, h // 2, deck)  # the hold
    rect(d, hold_x, keel_y - h // 4, (w - 20) // 3, 2, shade(deck, -24))
    house_x = px + w - 44
    rect(d, house_x, keel_y - 14, 24, 28, (168, 160, 146))  # the wheelhouse
    rect(d, house_x, keel_y - 14, 24, 2, rail)
    rect(d, house_x + 2, keel_y - 10, 20, 7, PANE)
    rect(d, house_x + 9, keel_y - 22, 3, 9, (150, 146, 138))  # her mast
    for bx in range(px + 20, px + w - 24, 24):  # shores under the bilge
        for by in (keel_y - half_width(bx - px - 8) - 6, keel_y + half_width(bx - px - 8) + 2):
            rect(d, bx, by, 5, 5, (108, 84, 56))
            rect(d, bx - 1, by + 4, 7, 2, (80, 62, 42))
    for _ in range(w // 10):  # rust weeping from the fastenings
        rect(d, px + 10 + rng.randrange(w - 26), keel_y - rng.randrange(-h // 3, h // 3),
             3, 1, shade(red, -rng.randint(10, 40)))


def paint_gantry(d, px, py):
    """The gantry crane over the stocks: two legs, a jib across them and
    the hook block hanging still."""
    steel, rust = (150, 134, 70), (120, 86, 48)
    for lx in (px + 2, px + 24):
        rect(d, lx, py - 26, 5, 56, steel)
        rect(d, lx + 1, py - 26, 1, 56, rust)
        rect(d, lx - 3, py + 28, 11, 4, (70, 70, 74))
    rect(d, px - 22, py - 30, 56, 6, steel)  # the jib
    rect(d, px - 22, py - 24, 56, 1, rust)
    for i in range(px - 20, px + 32, 8):  # its lattice
        rect(d, i, py - 24, 1, 5, rust)
    rect(d, px - 4, py - 24, 2, 18, (60, 60, 64))  # the fall
    rect(d, px - 7, py - 6, 8, 7, (80, 78, 82))    # the hook block


def paint_duomo(d, rng, level):
    """The Duomo of Molfetta on the harbour, in pale limestone: the nave's
    gabled front with its rose window and arched portal, the aisles either
    side under sloping roofs, a pyramid-roofed dome behind the gable, and
    the two square bell towers rising above it all."""
    cells = [(x, y) for y in range(level.height) for x in range(level.width)
             if level.at(x, y) == "W"]
    if not cells:
        return
    x0 = min(x for x, _ in cells) * TILE
    y0 = min(y for _, y in cells) * TILE
    w = (max(x for x, _ in cells) + 1) * TILE - x0
    bottom = (max(y for _, y in cells) + 1) * TILE
    cx = x0 + w // 2
    # the old town's roofs behind it, where nothing of the Duomo stands
    paint_roof_block(d, rng, level, x0 // TILE, y0 // TILE, w // TILE,
                     (bottom - y0) // TILE)

    tower_w = 34
    tower_top = y0 + 2
    tower_bottom = bottom - 60
    left_tower = x0 + 18
    right_tower = x0 + w - 18 - tower_w
    _tower(d, rng, left_tower, tower_top, tower_w, tower_bottom - tower_top)
    _tower(d, rng, right_tower, tower_top + 6, tower_w, tower_bottom - tower_top - 6)

    # the dome behind the gable: a square drum under a stone pyramid
    drum_top = y0 + 44
    _ashlar(d, rng, cx - 22, drum_top, 44, 22)
    _pyramid(d, cx, y0 + 22, drum_top + 1, 26)
    _arch_window(d, cx - 3, drum_top + 7, 6, 11)

    # the aisles, their roofs sloping down away from the nave
    aisle_top = bottom - 70
    nave_l, nave_r = cx - 46, cx + 46
    for ax0, ax1, rising in ((x0, nave_l, True), (nave_r, x0 + w, False)):
        _ashlar(d, rng, ax0, aisle_top, ax1 - ax0, bottom - aisle_top)
        for i in range(ax1 - ax0):
            t = i if rising else (ax1 - ax0 - 1 - i)
            drop = 10 - t * 10 // (ax1 - ax0)
            rect(d, ax0 + i, aisle_top - 12 + drop, 1, 12 - drop, DUOMO_ROOF)
            rect(d, ax0 + i, aisle_top - 12 + drop, 1, 1, DUOMO_ROOF_DARK)
        _blind_arcade(d, ax0, aisle_top + 1, ax1 - ax0)
        _arch_window(d, (ax0 + ax1) // 2 - 3, aisle_top + 22, 6, 18)
    rect(d, x0 + w - 4, aisle_top, 4, bottom - aisle_top, DUOMO_SHADE)

    # the nave's front: gable, cornice of little arches, rose window, portal
    nave_top = bottom - 94
    _ashlar(d, rng, nave_l, nave_top, nave_r - nave_l, bottom - nave_top)
    peak = nave_top - 22
    for dy in range(22):
        span = (nave_r - nave_l) // 2 * dy // 21
        _ashlar(d, rng, cx - span, peak + dy, 2 * span, 1)
        rect(d, cx - span - 2, peak + dy, 2, 1, DUOMO_LIGHT)  # its coping
        rect(d, cx + span, peak + dy, 2, 1, DUOMO_SHADE)
    rect(d, cx, peak - 6, 1, 6, DUOMO_DARK)  # the cross on the gable
    rect(d, cx - 2, peak - 4, 5, 1, DUOMO_DARK)
    _blind_arcade(d, nave_l, nave_top + 1, nave_r - nave_l)
    _arch_window(d, cx - 3, nave_top - 12, 6, 12)
    # rose window
    ry = nave_top + 30
    for rr, colour in ((11, DUOMO_LIGHT), (9, DUOMO_SHADE), (7, DUOMO_HOLE)):
        for dy in range(-rr, rr + 1):
            half = round(math.sqrt(rr * rr - dy * dy))
            rect(d, cx - half, ry + dy, 2 * half + 1, 1, colour)
    for a in range(0, 360, 45):
        rad = math.radians(a)
        for s in range(2, 7):
            rect(d, round(cx + s * math.cos(rad)), round(ry + s * math.sin(rad)),
                 1, 1, DUOMO_SHADE)
    rect(d, cx - 1, ry - 1, 3, 3, DUOMO_LIGHT)
    # the portal: a deep round arch, both leaves folded open. The churchyard
    # gate, not this door, keeps Mario out until Don Angelo accepts him.
    pw, ph = 26, 42
    px, py = cx - pw // 2, bottom - ph
    _arch_window(d, px - 4, py - 4, pw + 8, ph + 4, DUOMO_LIGHT)
    rect(d, px - 4, py + 9, pw + 8, ph - 9, DUOMO_SHADE)
    _arch_window(d, px, py, pw, ph, DUOMO_SHADE)
    rect(d, px + 3, py + 13, pw - 6, ph - 13, (28, 24, 26))
    for leaf_x in (px, px + pw - 5):
        rect(d, leaf_x, py + 12, 5, ph - 12, (84, 44, 30))
        rect(d, leaf_x + 1, py + 13, 2, ph - 14, (118, 70, 42))
    rect(d, px + 5, bottom - 4, pw - 10, 4, (170, 156, 132))
    # grime climbing from the sidewalk, and the blood of the first night
    for _ in range(40):
        gx = x0 + rng.randrange(w)
        if nave_l <= gx < nave_r and px - 4 <= gx < px + pw + 4:
            continue
        rect(d, gx, bottom - rng.randint(2, 14), 1, rng.randint(2, 8), DUOMO_SHADE)
    rect(d, px - 10, bottom - 12, 4, 6, BLOOD_DARK)
    rect(d, px - 9, bottom - 6, 2, 6, BLOOD_DARK)


def paint_poster(d, rng, x, y, w, h, i):
    """Paper poster, half torn away."""
    colours = [(230, 200, 60), (220, 70, 50), (240, 236, 220)]
    rect(d, x, y, w, h, colours[i % 3])
    rect(d, x + 2, y + 2, w - 4, 3, (170, 30, 30) if i % 3 != 1 else (250, 240, 200))
    for tx in range(0, w, 2):  # ragged tear across the bottom
        top = y + h // 2 + rng.randrange(h // 2)
        rect(d, x + tx, top, 2, y + h - top, (22, 24, 30))


def paint_hoarding(d, rng, x, y, w, h, text):
    """Advertising panel: frame, faded poster with its slogan, strips of
    paper peeled off and hanging down, bare board showing through."""
    rect(d, x - 1, y - 1, w + 2, h + 2, OUTLINE)
    rect(d, x, y, w, h, (70, 66, 60))  # bare board
    rect(d, x, y, w, h - 4, (226, 196, 70))
    rect(d, x, y + h - 6, w, 2, (200, 60, 40))
    if text_width(text) <= w - 4:
        paint_text(d, x + (w - text_width(text)) // 2, y + 3, text, (170, 30, 30),
                   missing=(len(text) // 2,))
    for _ in range(max(2, w // 10)):  # torn away below the slogan
        tx, tw = x + rng.randrange(w - 6), rng.randint(3, 8)
        top = y + 9 + rng.randrange(max(1, h - 12))
        rect(d, tx, top, tw, y + h - top, (70, 66, 60))
        rect(d, tx + 1, y + h, 2, rng.randint(3, 7), (226, 196, 70))  # dangling strip


# --------------------------------------------------------------- hospital


def paint_hospital(d, rng, level):
    """The hospital at the end of the west road: pale plastered block, rows
    of windows (some with sheets begging for help), a red cross, the
    OSPEDALE sign and the emergency entrance, its glass doors smeared with
    blood."""
    cells = [(x, y) for y in range(level.height) for x in range(level.width)
             if level.at(x, y) == "G"]
    if not cells:
        return
    xs = [x for x, _ in cells]
    ys = [y for _, y in cells]
    px, py = min(xs) * TILE, min(ys) * TILE
    w, h = (max(xs) - min(xs) + 1) * TILE, (max(ys) - min(ys) + 1) * TILE
    wall, wall_dark, trim = (206, 212, 204), (170, 178, 170), (120, 130, 126)
    rect(d, px, py, w, h, wall)
    rect(d, px, py, w, 5, trim)
    rect(d, px, py + 5, w, 1, (90, 96, 94))
    for bx in range(px + 31, px + w, 32):  # structural pillars
        rect(d, bx, py + 6, 3, h - 6, wall_dark)
    # sign and red cross at the top
    text = "OSPEDALE"
    tw = text_width(text) * 2
    sx = px + (w - tw) // 2 + 10
    rect(d, sx - 16, py + 8, tw + 22, 14, (240, 240, 236))
    rect(d, sx - 16, py + 21, tw + 22, 1, trim)
    paint_text(d, sx, py + 10, text, (40, 70, 140), missing=(4,), scale=2)
    rect(d, sx - 13, py + 12, 8, 2, (200, 30, 30))  # the cross
    rect(d, sx - 10, py + 9, 2, 8, (200, 30, 30))
    rect(d, sx - 14, py + 11, 10, 4, (200, 30, 30))
    rect(d, sx - 11, py + 8, 4, 10, (200, 30, 30))
    # floors of windows, some shattered, some with sheets hung out
    ground = py + h - 30
    sheets = 0
    for wy in range(py + 28, ground - 12, 16):
        for wx in range(px + 6, px + w - 10, 12):
            roll = rng.random()
            pane = (60, 80, 96) if roll > 0.3 else (PANE_BROKEN if roll > 0.1 else PANE_LIT)
            rect(d, wx - 1, wy - 1, 9, 12, trim)
            rect(d, wx, wy, 7, 10, pane)
            if pane == PANE_BROKEN:
                rect(d, wx + 1, wy + 7, 5, 1, BLOOD)
            if sheets < 3 and rng.random() < 0.07:
                sheets += 1
                rect(d, wx - 1, wy + 3, 9, 16, (236, 234, 226))
                rect(d, wx, wy + 6, 7, 1, (150, 30, 30))
                rect(d, wx + 1, wy + 9, 5, 1, (150, 30, 30))
                rect(d, wx + 2, wy + 12, 3, 1, (150, 30, 30))
    # emergency entrance at the bottom centre
    door_w = 60
    dx = px + (w - door_w) // 2
    rect(d, dx - 6, ground - 8, door_w + 12, 7, (200, 36, 32))  # canopy
    paint_text(d, dx + (door_w - text_width("PRONTO SOCCORSO")) // 2, ground - 7,
               "PRONTO SOCCORSO", (250, 246, 236))
    rect(d, dx - 6, ground - 1, door_w + 12, 1, (120, 20, 20))
    rect(d, dx, ground, door_w, 30, (14, 14, 18))
    for gx in range(dx + 1, dx + door_w, 11):
        rect(d, gx, ground + 1, 10, 29, (40, 52, 62))
        rect(d, gx + 2, ground + 4, 6, 14, (14, 14, 18))  # smashed pane
        rect(d, gx + 1, ground + 18, 3, 8, BLOOD)  # smeared hands
        rect(d, gx + 5, ground + 14, 2, 10, BLOOD_DARK)
    rect(d, dx - 8, ground + 14, 6, 16, (200, 200, 196))  # a stretcher on end
    rect(d, dx - 7, ground + 16, 4, 12, (236, 236, 230))
    rect(d, dx + door_w + 3, ground + 6, 4, 24, (60, 60, 64))  # drip stand
    rect(d, dx + door_w + 1, ground + 6, 8, 1, (60, 60, 64))


def paint_stairs(d, level, x, y):
    """A step of the hospital's wide staircase, with a handrail at the ends
    and a nosing shadow on every step."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, (176, 172, 162))
    rect(d, px, py + 6, TILE, 2, (136, 132, 124))  # nosing shadow
    rect(d, px, py + 8, TILE, 7, (160, 156, 146))
    rect(d, px, py + 14, TILE, 2, (126, 122, 114))
    if level.surface(x - 1, y) != "Y" or level.is_building(x - 1, y):
        rect(d, px, py, 2, TILE, (70, 72, 76))
    if level.surface(x + 1, y) != "Y" or level.is_building(x + 1, y):
        rect(d, px + 14, py, 2, TILE, (70, 72, 76))
    if (x * 7 + y * 3) % 5 == 0:
        rect(d, px + 4, py + 10, 5, 2, BLOOD)


# ------------------------------------------------------------------ props


def paint_ambulance(d, px, py):
    """Ambulance crashed and abandoned, side-on over two tiles."""
    x, y = px - 1, py + 15
    rect(d, x + 2, y - 1, 32, 2, (24, 24, 28))
    rect(d, x + 2, y - 15, 30, 13, (230, 230, 224))
    rect(d, x + 24, y - 12, 7, 5, (40, 60, 70))  # windscreen
    rect(d, x + 2, y - 8, 30, 2, (200, 36, 32))  # stripe
    rect(d, x + 9, y - 14, 2, 6, (200, 36, 32))  # cross
    rect(d, x + 7, y - 12, 6, 2, (200, 36, 32))
    rect(d, x + 16, y - 17, 5, 2, (40, 80, 200))  # beacon
    rect(d, x + 2, y - 3, 30, 1, (150, 150, 146))
    for wx in (x + 5, x + 23):
        rect(d, wx, y - 3, 6, 4, (18, 18, 20))
        rect(d, wx + 2, y - 2, 2, 2, (70, 70, 74))
    rect(d, x + 3, y - 14, 5, 8, (20, 20, 24))  # back doors hanging open
    rect(d, x + 14, y - 6, 6, 3, BLOOD)


def paint_cafe_table(d, px, py):
    """Round café table, dirty, with a knocked-over glass."""
    rect(d, px + 3, py + 14, 11, 2, (30, 30, 34))
    rect(d, px + 7, py + 8, 2, 7, (60, 60, 64))
    rect(d, px + 2, py + 5, 12, 4, (190, 186, 176))
    rect(d, px + 3, py + 4, 10, 1, (216, 212, 200))
    rect(d, px + 4, py + 6, 3, 1, (100, 70, 40))  # spilled drink
    rect(d, px + 10, py + 5, 2, 1, (180, 200, 210))


def paint_chair(d, px, py, toppled):
    """Plastic café chair, most of them knocked over."""
    colour, dark = (226, 222, 210), (160, 156, 146)
    rect(d, px + 3, py + 14, 10, 1, (30, 30, 34))
    if toppled:
        rect(d, px + 2, py + 9, 12, 3, colour)
        rect(d, px + 2, py + 12, 2, 2, dark)
        rect(d, px + 11, py + 5, 2, 5, dark)
        rect(d, px + 7, py + 6, 2, 3, dark)
        return
    rect(d, px + 4, py + 3, 8, 5, colour)
    rect(d, px + 4, py + 8, 8, 2, dark)
    rect(d, px + 4, py + 10, 1, 4, dark)
    rect(d, px + 11, py + 10, 1, 4, dark)


def paint_fountain(image, rng, px, py, size):
    """Round fountain filling a size x size block: stone rim, murky water
    stained with blood, a headless statue on its pedestal."""
    d = ImageDraw.Draw(image)
    r = size * TILE // 2 - 1
    cx, cy = px + size * TILE // 2, py + size * TILE // 2
    d.ellipse([cx - r, cy - r + 4, cx + r, cy + r], fill=(40, 38, 40))  # shadow
    d.ellipse([cx - r, cy - r, cx + r, cy + r - 3], fill=(168, 160, 146))
    d.ellipse([cx - r + 4, cy - r + 3, cx + r - 4, cy + r - 6], fill=(126, 118, 108))
    d.ellipse([cx - r + 7, cy - r + 6, cx + r - 7, cy + r - 9], fill=(42, 62, 58))
    d.ellipse([cx - r + 14, cy - r + 12, cx - 2, cy + 2], fill=(52, 76, 70))
    d.ellipse([cx + 6, cy + 3, cx + r - 12, cy + r - 16], fill=(90, 20, 20))  # blood
    rect(d, cx + 10, cy + 6, 7, 3, (120, 26, 24))
    for i in range(0, 360, 30):  # rim blocks
        bx = cx + int((r - 2) * math.cos(math.radians(i)))
        by = cy - 1 + int((r - 3) * math.sin(math.radians(i)))
        rect(d, bx, by, 1, 2, (120, 114, 104))
    rect(d, cx - r + 1, cy - 4, 5, 4, (70, 66, 60))  # chipped rim
    rect(d, cx + r - 8, cy - r + 8, 4, 5, (70, 66, 60))
    # basin in the middle, pedestal and a statue with its head knocked off
    d.ellipse([cx - 12, cy - 6, cx + 12, cy + 8], fill=(150, 144, 132))
    d.ellipse([cx - 9, cy - 4, cx + 9, cy + 5], fill=(42, 62, 58))
    rect(d, cx - 4, cy - 10, 9, 12, (150, 144, 132))
    rect(d, cx - 4, cy, 9, 2, (100, 96, 88))
    rect(d, cx - 3, cy - 26, 7, 16, (180, 174, 160))
    rect(d, cx - 5, cy - 23, 2, 8, (160, 154, 140))  # arms
    rect(d, cx + 4, cy - 25, 2, 5, (160, 154, 140))
    rect(d, cx - 2, cy - 27, 5, 1, (120, 114, 104))  # broken neck
    rect(d, cx - 1, cy - 20, 3, 6, (140, 134, 122))
    rect(d, cx + 16, cy - 12, 5, 4, (180, 174, 160))  # the head, in the water
    rect(d, cx + 17, cy - 11, 1, 1, (60, 56, 52))
    rect(d, cx - 3, cy - 22, 2, 3, BLOOD)  # handprint on the statue
    for _ in range(10):  # floating rubbish
        rect(d, cx + rng.randrange(-r + 10, r - 12), cy + rng.randrange(-r + 10, r - 14),
             2, 1, rng.choice(DEBRIS))


def paint_tree(d, rng, px, py):
    """Dead tree in a square stone planter, bare branches over the tile."""
    rect(d, px + 1, py + 13, 15, 2, (30, 30, 34))
    rect(d, px + 1, py + 5, 14, 9, (140, 134, 122))
    rect(d, px + 2, py + 6, 12, 6, (60, 46, 36))  # soil
    rect(d, px + 1, py + 12, 14, 2, (110, 104, 94))
    trunk = (70, 54, 42)
    rect(d, px + 7, py - 8, 2, 16, trunk)
    for bx, by, length, step in ((3, -6, 5, -1), (9, -10, 5, 1), (5, -14, 4, -1),
                                 (8, -16, 3, 1), (10, -4, 4, 1)):
        for i in range(length):
            rect(d, px + bx + i * step if step > 0 else px + bx + 4 - i,
                 py + by - i // 2, 1, 1, trunk)
    for _ in range(4):  # the last dry leaves
        rect(d, px + rng.randrange(2, 14), py - rng.randrange(4, 17), 1, 1, (120, 90, 50))


def paint_bench(d, px, py):
    """Park bench over two tiles, one slat snapped."""
    rect(d, px + 1, py + 14, 30, 2, (30, 30, 34))
    for lx in (px + 3, px + 27):
        rect(d, lx, py + 9, 2, 6, (50, 50, 54))
    wood, dark = (130, 96, 60), (92, 66, 42)
    rect(d, px + 1, py + 3, 30, 2, wood)  # backrest
    rect(d, px + 1, py + 6, 30, 2, dark)
    rect(d, px + 1, py + 9, 30, 2, wood)  # seat
    rect(d, px + 1, py + 11, 30, 1, dark)
    rect(d, px + 16, py + 9, 4, 3, (30, 30, 34))  # snapped slat
    rect(d, px + 2, py + 2, 1, 10, (50, 50, 54))
    rect(d, px + 29, py + 2, 1, 10, (50, 50, 54))


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


def _station_arch(d, x, y, w, h, frame, hole):
    """Round-headed opening, `w` wide and `h` tall to the ground, in a
    raised stone frame: the arcade the station's front is made of."""
    r = w // 2
    for dy in range(r + 1):
        half = round(math.sqrt(max(0, r * r - (r - dy) ** 2)))
        rect(d, x + r - half - 2, y + dy - 2, 2 * half + 4, 1, frame)
        rect(d, x + r - half, y + dy, 2 * half, 1, hole)
    rect(d, x - 2, y + r, 2, h - r, frame)
    rect(d, x + w, y + r, 2, h - r, frame)
    rect(d, x, y + r, w, h - r, hole)


def paint_station(d, rng, level):
    """The station at the top of the block, `0`: the low provincial kind
    the south is full of, a long body of round-arched openings between
    pilasters, a cornice over them, and a raised middle bay carrying the
    clock and the name. The two openings the map marks `(` and `)` are the
    doors, standing open on the dark of the booking hall, and each one goes
    somewhere; the rest are windows, their glass mostly gone."""
    cells = [(x, y) for y in range(level.height) for x in range(level.width)
             if level.at(x, y) == "0"]
    if not cells:
        return
    x0, x1 = min(x for x, _ in cells), max(x for x, _ in cells)
    y0, y1 = min(y for _, y in cells), max(y for _, y in cells)
    px, py = x0 * TILE, y0 * TILE
    w, h = (x1 - x0 + 1) * TILE, (y1 - y0 + 1) * TILE
    wall, wall_dark = (226, 214, 184), (196, 182, 150)
    trim, plinth = (238, 230, 206), (146, 142, 132)
    roof, hole = (150, 142, 128), (26, 26, 30)
    rect(d, px, py, w, h, wall)
    rect(d, px, py, w, 9, roof)  # the flat roof, seen edge on
    rect(d, px, py + 7, w, 2, (110, 104, 96))
    rect(d, px, py + 9, w, 3, trim)  # the cornice under it
    rect(d, px, py + 12, w, 1, wall_dark)
    ground = py + h - 3
    rect(d, px, ground, w, 3, plinth)  # the plinth it stands on
    # The front is the stretch standing over the forecourt: an arcade of
    # openings two tiles wide, the rest of the building a blind end.
    front = [ax for ax in range(x0, x1, 2)
             if level.at(ax, y1 + 1) not in BUILDING_GLYPHS
             and level.at(ax + 1, y1 + 1) not in BUILDING_GLYPHS]
    if not front:
        return
    # the middle bay: raised, carrying the clock and the name, the middle
    # opening of the arcade under it
    middle = front[len(front) // 2] * TILE + TILE
    bx, bw = middle - 36, 72
    rect(d, bx, py, bw, h - 3, wall)
    rect(d, bx, py, bw, 6, roof)
    rect(d, bx, py + 5, bw, 2, (110, 104, 96))
    rect(d, bx, py + 7, bw, 3, trim)  # its own cornice
    for edge in (bx, bx + bw - 3):  # the pilasters framing it
        rect(d, edge, py + 10, 3, h - 13, wall_dark)
        rect(d, edge, py + 10, 1, h - 13, trim)
    for ax in front:
        sx = ax * TILE + 4
        rect(d, sx - 4, py + 13, 4, h - 16, wall_dark)  # the pilaster beside it
        rect(d, sx - 4, py + 13, 1, h - 16, trim)
        if level.at(ax, y1) in "()":
            _station_arch(d, sx, ground - 36, 24, 36, trim, hole)
            rect(d, sx + 2, ground - 18, 20, 18, (14, 14, 16))  # the hall
            rect(d, sx, ground - 3, 24, 3, (176, 170, 158))  # its worn step
            for leaf in (sx, sx + 20):  # the doors, folded back
                rect(d, leaf, ground - 24, 4, 22, (66, 58, 46))
                rect(d, leaf + 1, ground - 23, 2, 20, (92, 82, 66))
        else:
            _station_arch(d, sx, ground - 36, 24, 32, trim, (52, 58, 66))
            for gy in range(ground - 26, ground - 4, 7):  # the glazing bars
                rect(d, sx, gy, 24, 1, trim)
            rect(d, sx + 11, ground - 30, 2, 26, trim)
            if rng.random() < 0.7:  # panes gone, and boards over the gap
                rect(d, sx + rng.randrange(1, 13), ground - 24, 10, 9, hole)
                rect(d, sx + 1, ground - 20, 22, 3, (122, 92, 60))
            rect(d, sx, ground - 4, 24, 4, wall_dark)  # its sill
    cx, cy = bx + bw // 2, py + 24
    d.ellipse([cx - 11, cy - 11, cx + 11, cy + 11], fill=trim)  # the clock
    d.ellipse([cx - 9, cy - 9, cx + 9, cy + 9], fill=(238, 234, 220))
    for tick in range(12):
        tx = cx + round(7 * math.sin(tick * math.pi / 6))
        ty = cy - round(7 * math.cos(tick * math.pi / 6))
        rect(d, tx, ty, 1, 1, (90, 86, 80))
    rect(d, cx, cy - 6, 1, 7, (40, 38, 36))  # stopped at ten past eleven
    rect(d, cx, cy, 6, 1, (40, 38, 36))
    rect(d, cx - 1, cy - 1, 2, 2, (40, 38, 36))
    name = "STAZIONE"
    nx = cx - (text_width(name) * 2) // 2
    rect(d, nx - 5, cy + 15, text_width(name) * 2 + 10, 14, (40, 60, 46))
    rect(d, nx - 5, cy + 15, text_width(name) * 2 + 10, 1, (80, 110, 86))
    paint_text(d, nx, cy + 18, name, (236, 236, 224), missing=(5,), scale=2,
               tilted=(7,))


def paint_railing(d, level, x, y):
    """A length of the park's iron railing, `^`: uprights on a bottom rail
    with a rail across their heads, a post wherever the run ends or a gate
    breaks it. Painted low in the tile so the lawn shows behind it."""
    px, py = x * TILE, y * TILE
    iron, iron_dark, iron_light = (58, 62, 66), (36, 38, 42), (96, 100, 104)
    rect(d, px, py + 13, TILE, 2, iron_dark)  # its shadow on the ground
    for bar in range(px + 1, px + TILE, 3):
        rect(d, bar, py + 4, 1, 9, iron)
        rect(d, bar, py + 4, 1, 1, iron_light)
    rect(d, px, py + 3, TILE, 2, iron)  # the rail over their heads
    rect(d, px, py + 3, TILE, 1, iron_light)
    rect(d, px, py + 11, TILE, 1, iron_dark)
    for side, neighbour in ((0, level.at(x - 1, y)), (TILE - 3, level.at(x + 1, y))):
        if neighbour != "^":
            rect(d, px + side, py + 1, 3, 14, iron)
            rect(d, px + side, py + 1, 3, 2, iron_light)
            rect(d, px + side, py + 14, 3, 1, iron_dark)


def paint_park_gate(d, level, x, y):
    """A gate in the park railing, `<`: both leaves swung right back
    against the posts, so the path runs straight through."""
    px, py = x * TILE, y * TILE
    iron, iron_light = (58, 62, 66), (96, 100, 104)
    inside = 1 if level.at(x, y + 1) in "gP" else -1  # which way the park lies
    for side in (0, TILE - 3):  # the posts, taller than the railing
        rect(d, px + side, py - 1, 3, 17, iron)
        rect(d, px + side, py - 1, 3, 2, iron_light)
        rect(d, px + side, py - 3, 3, 2, (150, 140, 90))  # a brass finial
    for side in (1, TILE - 5):  # the leaves, folded back along the railing
        top = py + 4 if inside > 0 else py + 2
        rect(d, px + side, top, 4, 10, (40, 44, 48))
        for bar in range(px + side, px + side + 4, 2):
            rect(d, bar, top + 1, 1, 8, iron_light)


def paint_rubbish(d, rng, px, py, deep=True):
    """The rubbish heaped in the corner of the car park: split sacks, boxes
    gone soft, a bin on its side. `deep` piles them shoulder high, too deep
    to climb; the rest is the same rubbish trodden flat around the heaps,
    which you can walk over."""
    sacks = [(28, 28, 32), (40, 38, 42), (20, 22, 26), (34, 32, 30)]
    if deep:
        rect(d, px, py + 12, TILE, 4, (26, 26, 28))  # the shadow it sits in
        for _ in range(4):
            sw, sh = rng.randint(7, 10), rng.randint(6, 8)
            sx = px + rng.randrange(0, TILE - sw + 1)
            sy = py + rng.randrange(0, TILE - sh)
            rect(d, sx, sy, sw, sh, rng.choice(sacks))
            rect(d, sx + 1, sy, sw - 2, 1, (72, 70, 76))  # the light on top
            rect(d, sx + 1, sy + sh - 1, sw - 2, 1, (14, 14, 16))
            if rng.random() < 0.3:  # a split, and what is coming out of it
                rect(d, sx + 2, sy + 2, 3, 2, rng.choice(DEBRIS))
        if rng.random() < 0.5:  # a cardboard box slumped on top
            bx, by = px + rng.randrange(1, 7), py + rng.randrange(0, 7)
            rect(d, bx, by, 9, 7, (118, 88, 58))
            rect(d, bx, by, 9, 1, (146, 112, 74))
            rect(d, bx + 1, by + 3, 7, 1, (84, 62, 40))
    else:
        for _ in range(3):  # flattened sacks, low enough to step over
            sw = rng.randint(5, 9)
            sx = px + rng.randrange(0, TILE - sw + 1)
            sy = py + rng.randrange(1, TILE - 4)
            rect(d, sx, sy, sw, 3, rng.choice(sacks))
            rect(d, sx + 1, sy, sw - 2, 1, (62, 60, 66))
    for _ in range(6):  # what has spilled out of them
        rect(d, px + rng.randrange(14), py + rng.randrange(15), 2, 1,
             rng.choice(DEBRIS))


def paint_playground(d, px, py, kind):
    """Broken playground rides, rusted and left to the weeds: a swing with
    one chain snapped, a slide on its side, a merry-go-round off its pivot."""
    rust, rust_dark = (150, 80, 50), (96, 50, 34)
    paint_red, paint_blue = (170, 50, 44), (60, 90, 140)
    rect(d, px + 1, py + 14, 14, 2, (30, 34, 26))
    if kind == 0:  # swing frame, one seat hanging from a single chain
        rect(d, px + 1, py - 8, 2, 22, rust)
        rect(d, px + 13, py - 8, 2, 22, rust)
        rect(d, px + 1, py - 9, 14, 2, rust_dark)
        rect(d, px + 5, py - 7, 1, 12, (120, 120, 126))
        rect(d, px + 4, py + 5, 5, 2, paint_red)
        rect(d, px + 10, py - 7, 1, 5, (120, 120, 126))  # snapped chain
        rect(d, px + 9, py + 11, 5, 2, paint_red)  # its seat, on the ground
    elif kind == 1:  # slide knocked over
        rect(d, px + 1, py + 8, 14, 4, paint_blue)
        rect(d, px + 1, py + 7, 14, 1, (110, 140, 180))
        rect(d, px + 11, py + 2, 2, 11, rust)
        rect(d, px + 13, py + 3, 2, 10, rust_dark)
        for sy in range(py + 3, py + 12, 3):
            rect(d, px + 11, sy, 4, 1, rust_dark)
    else:  # merry-go-round tipped off its pivot
        rect(d, px + 1, py + 7, 14, 6, rust_dark)
        rect(d, px + 2, py + 6, 12, 5, paint_red)
        rect(d, px + 7, py + 3, 2, 5, rust)
        rect(d, px + 3, py + 4, 10, 1, rust)
        rect(d, px + 4, py + 8, 3, 2, (230, 200, 70))
        rect(d, px + 9, py + 8, 3, 2, (230, 200, 70))


def paint_trolley(d, px, py, tipped=False):
    """Abandoned shopping trolley."""
    wire, dark = (170, 172, 176), (96, 98, 104)
    rect(d, px + 2, py + 14, 12, 1, (24, 24, 28))
    if tipped:
        rect(d, px + 2, py + 6, 11, 8, dark)
        for i in range(3, 13, 3):
            rect(d, px + i, py + 6, 1, 8, wire)
        rect(d, px + 2, py + 6, 11, 1, wire)
        rect(d, px + 13, py + 4, 2, 2, (40, 40, 44))
        rect(d, px + 13, py + 11, 2, 2, (40, 40, 44))
        return
    rect(d, px + 3, py + 4, 10, 7, dark)
    for i in range(4, 13, 3):
        rect(d, px + i, py + 4, 1, 7, wire)
    rect(d, px + 3, py + 4, 10, 1, wire)
    rect(d, px + 3, py + 11, 10, 1, wire)
    rect(d, px + 12, py + 2, 3, 1, (200, 40, 40))  # handle
    rect(d, px + 4, py + 13, 2, 2, (30, 30, 34))
    rect(d, px + 11, py + 13, 2, 2, (30, 30, 34))


def paint_road_block(d, px, py):
    """Concrete barrier blocking the road, striped red and white."""
    rect(d, px, py + 14, 16, 2, (24, 24, 28))
    rect(d, px, py + 5, 16, 10, (150, 148, 140))
    rect(d, px, py + 5, 16, 2, (184, 182, 172))
    rect(d, px + 1, py + 12, 14, 2, (110, 108, 102))
    for i in range(0, 16, 6):
        rect(d, px + i, py + 8, 3, 3, (190, 40, 36))
    rect(d, px + 5, py + 6, 1, 4, (90, 88, 84))  # crack


def paint_gate(d, level, px, py, x, y):
    """The open churchyard gate under its dynamic closed-gate component."""
    iron, shine = (38, 38, 42), (92, 94, 100)
    rect(d, px, py + 13, 16, 3, shade(PAVING, -30))  # the threshold slab
    left_pier = level.at(x - 1, y) != "x"
    right_pier = level.at(x + 1, y) != "x"
    if left_pier or right_pier:
        sx = px if left_pier else px + 11
        rect(d, sx, py - 1, 5, 17, OLD_TOWN_STONE[0])
        rect(d, sx, py - 1, 5, 2, shade(OLD_TOWN_STONE[0], 16))
        rect(d, sx + 4, py - 1, 1, 17, shade(OLD_TOWN_STONE[0], -40))
        rect(d, sx, py + 5, 5, 1, shade(OLD_TOWN_STONE[0], -26))
        rect(d, sx, py + 11, 5, 1, shade(OLD_TOWN_STONE[0], -26))
        # The corresponding leaf is folded flat against its pier.
        lx = px + 5 if left_pier else px + 8
        rect(d, lx, py + 1, 3, 13, iron)
        rect(d, lx, py + 1, 1, 13, shine)


def paint_car(d, px, py, body, burnt=False, flipped=False):
    """Side-on car filling two tiles, wheels on the tile bottom."""
    x, y = px - 1, py + 15
    rect(d, x + 2, y - 1, 32, 2, (24, 24, 28))  # ground shadow
    dark = tuple(max(0, v - 40) for v in body)
    if flipped:
        rect(d, x, y - 10, 34, 8, dark)
        rect(d, x + 6, y - 4, 22, 4, (30, 30, 34))
        for wx in (x + 4, x + 24):
            rect(d, wx, y - 14, 6, 4, (20, 20, 22))
            rect(d, wx + 2, y - 13, 2, 2, (70, 70, 74))
        rect(d, x + 2, y - 11, 30, 1, (26, 26, 30))
        return
    glass = (20, 20, 20) if burnt else (40, 60, 70)
    rect(d, x + 2, y - 8, 30, 6, body)
    rect(d, x + 8, y - 14, 18, 6, body)
    rect(d, x + 10, y - 13, 6, 4, glass)
    rect(d, x + 18, y - 13, 6, 4, glass)
    rect(d, x + 2, y - 3, 30, 1, dark)
    for wx in (x + 5, x + 23):
        rect(d, wx, y - 3, 6, 4, (18, 18, 20))
        rect(d, wx + 2, y - 2, 2, 2, (70, 70, 74))
    if burnt:
        for i in range(0, 30, 3):
            rect(d, x + 2 + i, y - 8 + (i % 2), 2, 2, (26, 24, 24))
        rect(d, x + 8, y - 14, 18, 2, (30, 26, 26))


def paint_car_vertical(d, px, py, body, burnt=False):
    """Car parked north-south over two stacked tiles starting at (px, py)."""
    dark = tuple(max(0, v - 40) for v in body)
    glass = (20, 20, 20) if burnt else (40, 60, 70)
    bottom = py + 30
    rect(d, px + 2, bottom, 13, 2, (24, 24, 28))
    rect(d, px + 1, bottom - 26, 14, 26, body)
    rect(d, px + 3, bottom - 22, 10, 5, glass)
    rect(d, px + 3, bottom - 15, 10, 7, dark)
    rect(d, px + 3, bottom - 7, 10, 2, glass)
    for wy in (bottom - 24, bottom - 7):
        rect(d, px, wy, 2, 5, (18, 18, 20))
        rect(d, px + 14, wy, 2, 5, (18, 18, 20))
    if burnt:
        for i in range(0, 24, 3):
            rect(d, px + 2 + (i * 5 % 10), bottom - 25 + i, 3, 2, (26, 24, 24))


def paint_campfire(d, px, py):
    """A camp's fire pit: ring of stones, crossed logs, ash. The flame is
    animated in game."""
    rect(d, px + 1, py + 13, 14, 2, (24, 24, 28))  # shadow
    for sx, sy in ((2, 9), (5, 7), (9, 7), (12, 9), (13, 12), (2, 12), (5, 14), (10, 14)):
        rect(d, px + sx, py + sy, 3, 2, (120, 116, 108))
        rect(d, px + sx, py + sy, 3, 1, (156, 152, 142))
    rect(d, px + 4, py + 10, 8, 4, (40, 36, 34))  # ash bed
    rect(d, px + 3, py + 11, 10, 2, (110, 72, 40))  # logs
    rect(d, px + 6, py + 9, 2, 5, (92, 60, 34))
    rect(d, px + 9, py + 9, 2, 5, (130, 86, 48))
    rect(d, px + 6, py + 12, 4, 1, (230, 120, 40))  # embers
    rect(d, px + 8, py + 13, 1, 1, (255, 200, 90))


def paint_bin(d, px, py):
    rect(d, px + 3, py + 15, 11, 1, (24, 24, 28))
    rect(d, px + 3, py + 6, 10, 10, (58, 64, 58))
    rect(d, px + 3, py + 6, 10, 2, (86, 92, 84))
    rect(d, px + 5, py + 9, 1, 6, (44, 48, 44))
    rect(d, px + 9, py + 9, 1, 6, (44, 48, 44))
    rect(d, px + 4, py + 5, 8, 2, SCORCH)


def paint_sign(d, px, py, kind):
    """A road sign on its post, `/`: give way at the mouth of a side
    street, no entry where a street is closed, or the blue plate that
    points the way. Like the traffic lights it stands into the tile above,
    so it reads at eye level rather than flat on the pavement."""
    white, red, blue = (236, 234, 228), (186, 40, 36), (36, 62, 118)
    rect(d, px + 7, py + 14, 4, 2, (24, 24, 28))  # its shadow
    rect(d, px + 8, py - 2, 2, 17, (146, 144, 138))  # the post
    rect(d, px + 8, py - 2, 1, 17, (184, 182, 176))
    if kind == 0:  # give way: a triangle on its point
        for i in range(7):
            rect(d, px + 2 + i, py - 10 + i, 14 - i * 2, 1, red)
            if 1 <= i < 5:
                rect(d, px + 4 + i, py - 9 + i, 10 - i * 2, 1, white)
    elif kind == 1:  # no entry
        d.ellipse([px + 2, py - 11, px + 14, py + 1], fill=red)
        d.ellipse([px + 4, py - 9, px + 12, py - 1], fill=red)
        rect(d, px + 4, py - 6, 9, 3, white)
    else:  # the way to the station
        rect(d, px, py - 10, 16, 10, blue)
        rect(d, px, py - 10, 16, 1, (76, 106, 166))
        rect(d, px, py - 1, 16, 1, (22, 38, 74))
        rect(d, px + 3, py - 6, 8, 2, white)  # the arrow, pointing on
        for i in range(3):
            rect(d, px + 9 + i, py - 7 - i, 1, 3 + i * 2, white)
        rect(d, px + 2, py - 9, 5, 1, (150, 170, 210))
        rect(d, px + 2, py - 3, 7, 1, (150, 170, 210))


def paint_traffic_light(d, px, py):
    rect(d, px + 6, py + 14, 5, 2, (24, 24, 28))
    rect(d, px + 7, py - 6, 2, 21, (50, 52, 56))
    rect(d, px + 5, py - 12, 6, 9, (30, 30, 34))
    rect(d, px + 7, py - 11, 2, 2, (200, 40, 30))
    rect(d, px + 7, py - 8, 2, 2, (70, 64, 30))
    rect(d, px + 7, py - 5, 2, 1, (30, 70, 40))


_BODY_SOURCE = os.path.join("assets", "sprites", "zombie_wanderer.png")
_bodies: list[Image.Image] = []


def body_sprite(rng) -> Image.Image:
    """A civilian lying on the ground: a character frame seen from above,
    turned on its side, with human skin and random clothes."""
    if not _bodies:
        sheet = Image.open(_BODY_SOURCE).convert("RGBA")
        _bodies.extend(sheet.crop((c * 16, 0, c * 16 + 16, 24)) for c in (0, 1))
    frame = rng.choice(_bodies).copy()
    skin = rng.choice(SKIN)
    clothes = rng.choice(CLOTHES)
    for y in range(frame.height):
        for x in range(frame.width):
            r, g, b, a = frame.getpixel((x, y))
            if a < 100:
                continue
            if g > r + 10 and g > b:  # zombie green -> human skin
                shade = g / 200
                frame.putpixel((x, y), tuple(int(c * min(1.2, shade + 0.35)) for c in skin) + (a,))
            elif y >= 11 and max(r, g, b) > 24:  # clothes
                lum = (r + g + b) / 3 / 70
                frame.putpixel((x, y), tuple(min(255, int(c * lum)) for c in clothes) + (a,))
    turned = frame.rotate(90 if rng.random() < 0.5 else -90, expand=True)
    return turned


def paint_body(image, rng, x, y):
    """Lying body centred on (x, y) with a pool of blood under it."""
    body = body_sprite(rng)
    d = ImageDraw.Draw(image)
    rect(d, x - 9, y - 3, 18, 7, BLOOD_DARK)
    rect(d, x - 6, y - 4, 12, 9, BLOOD)
    image.paste(body, (x - body.width // 2, y - body.height // 2), body)


def paint_corpse(image, rng, px, py):
    paint_body(image, rng, px + 8, py + 9)


def paint_corpse_pile(image, rng, px, py):
    """Two bodies, one lying across the other."""
    d = ImageDraw.Draw(image)
    rect(d, px - 6, py + 4, 28, 11, BLOOD_DARK)
    paint_body(image, rng, px + 6, py + 11)
    paint_body(image, rng, px + 11, py + 6)


def paint_debris(d, rng, px, py):
    for _ in range(7):
        rect(d, px + rng.randrange(1, 14), py + rng.randrange(2, 14),
             rng.randint(1, 3), rng.randint(1, 2), rng.choice(DEBRIS))
    rect(d, px + 5, py + 9, 1, 1, (180, 200, 210))  # glass glint
    rect(d, px + 10, py + 4, 1, 1, (180, 200, 210))


# ------------------------------------------------------------------- main


def airliner_body(level):
    """The columns of the fuselage, each with the rows it covers. The body
    is drawn from these as one tube rather than tile by tile, so the crown,
    the livery and the windows run the length of it without stepping."""
    body = {}
    for y in range(level.height):
        for x in range(level.width):
            if level.at(x, y) in "_[":
                top, bottom = body.get(x, (y, y))
                body[x] = (min(top, y), max(bottom, y))
    return body


def _smooth(values, window, passes=2):
    """A box blur over a list of pixel heights: it turns the staircase the
    tile grid makes of a long diagonal object into a straight line."""
    out = list(values)
    half = window // 2
    for _ in range(passes):
        source = out
        out = []
        for i in range(len(source)):
            lo, hi = max(0, i - half), min(len(source), i + half + 1)
            out.append(sum(source[lo:hi]) / (hi - lo))
    return out


def airliner_edges(body):
    """The top and bottom of the tube at every pixel across it: read off
    the middle of each column, drawn straight between them, then smoothed
    so the body rides up the block instead of stepping up it."""
    columns = sorted(body)
    marks = [(x * TILE + TILE // 2, body[x][0] * TILE, (body[x][1] + 1) * TILE)
             for x in columns]
    first, last = columns[0] * TILE, (columns[-1] + 1) * TILE
    tops, bottoms = [], []
    for px in range(first, last):
        if px <= marks[0][0]:
            top, bottom = marks[0][1], marks[0][2]
        elif px >= marks[-1][0]:
            top, bottom = marks[-1][1], marks[-1][2]
        else:
            i = next(i for i in range(len(marks) - 1) if marks[i + 1][0] > px)
            (ax, at, ab), (bx, bt, bb) = marks[i], marks[i + 1]
            t = (px - ax) / (bx - ax)
            top, bottom = at + (bt - at) * t, ab + (bb - ab) * t
        tops.append(top)
        bottoms.append(bottom)
    tops = _smooth(tops, 3 * TILE)
    bottoms = _smooth(bottoms, 3 * TILE)
    return {px: (round(tops[i]), round(bottoms[i]))
            for i, px in enumerate(range(first, last))}


def paint_airliner(d, rng, level):
    """The airliner across the crossroads. Everything it covers is laid
    down in soot first, so nothing of the street or the roofs shows through
    where the drawn shape and the tiles disagree; then the fuselage goes on
    as one smooth tube, lit along the crown and in shadow along the belly,
    with the livery, the cabin windows, the flight deck at the nose and the
    tear `[` where the skin is peeled back; then the wings."""
    body = airliner_body(level)
    if not body:
        return
    for y in range(level.height):
        for x in range(level.width):
            if level.at(x, y) in "_+[":
                rect(d, x * TILE, y * TILE, TILE, TILE, SCORCH)

    paint_airliner_wings(d, rng, level, tail=True)

    edges = airliner_edges(body)
    nose = min(edges)
    for px, (top, bottom) in sorted(edges.items()):
        h = bottom - top
        rect(d, px, top, 1, h, HULL)
        rect(d, px, top, 1, max(3, h // 5), HULL_LIGHT)
        rect(d, px, bottom - h // 4, 1, h // 4, HULL_SHADE)
        rect(d, px, bottom - 3, 1, 3, HULL_DARK)
        rect(d, px, top, 1, 1, HULL_DARK)
        line = top + round(h * 0.64)
        rect(d, px, line, 1, 3, LIVERY)
        rect(d, px, line, 1, 1, LIVERY_LIGHT)
        if (px - nose) % 6 < 3 and px > nose + 30:
            rect(d, px, top + round(h * 0.30), 1, 3, CABIN_WINDOW)
        if (px - nose) % 48 == 0:
            rect(d, px, top + 2, 1, h - 5, HULL_SEAM)
        if rng.random() < 0.08:  # soot, and the dirt of the days since
            rect(d, px, top + rng.randrange(2, max(3, h - 3)),
                 rng.randint(1, 3), 1, shade(HULL_SHADE, -34))
        rect(d, px, bottom, 1, 3, HULL_SHADOW)  # the shadow it throws

    paint_airliner_nose(d, edges, nose)
    paint_airliner_wings(d, rng, level, tail=False)

    for y in range(level.height):
        for x in range(level.width):
            if level.at(x, y) == "[":
                paint_airliner_tear(d, level, x, y)


def paint_airliner_nose(d, edges, nose):
    """The nose, scorched and rounded off, the flight deck glazed over."""
    top, bottom = edges[nose]
    rect(d, nose, top, 3, bottom - top, SCORCH)
    rect(d, nose + 3, top, 2, 3, HULL_DARK)
    rect(d, nose + 3, bottom - 3, 2, 3, HULL_DARK)
    rect(d, nose + 5, top + 4, 7, 4, CABIN_WINDOW)
    rect(d, nose + 5, top + 4, 7, 1, LIVERY_LIGHT)


def _hull(points):
    """The convex hull of a set of points, counter-clockwise (Andrew's
    monotone chain): a wing drawn from the hull of its tiles comes out as
    the straight-edged panel it is instead of a staircase."""
    points = sorted(set(points))
    if len(points) < 3:
        return points

    def half(source):
        out = []
        for p in source:
            while len(out) >= 2:
                (ax, ay), (bx, by) = out[-2], out[-1]
                if (bx - ax) * (p[1] - ay) - (by - ay) * (p[0] - ax) > 0:
                    break
                out.pop()
            out.append(p)
        return out[:-1]

    return half(points) + half(points[::-1])


def _wing_groups(level):
    """The `+` tiles, grouped into the pieces they make: two wings and two
    tailplanes, each of them one run of touching tiles."""
    left = {(x, y) for y in range(level.height) for x in range(level.width)
            if level.at(x, y) == "+"}
    groups = []
    while left:
        seed = left.pop()
        group, queue = {seed}, [seed]
        while queue:
            x, y = queue.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    other = (x + dx, y + dy)
                    if other in left:
                        left.remove(other)
                        group.add(other)
                        queue.append(other)
        groups.append(group)
    return groups


def _wing_axes(group):
    """A wing's own two directions: along the span, root to tip, and
    across the chord. Read off the spread of its tiles, so the panel lines
    follow the wing however it is swept."""
    pts = [(x * TILE + TILE / 2, y * TILE + TILE / 2) for x, y in group]
    mx = sum(p[0] for p in pts) / len(pts)
    my = sum(p[1] for p in pts) / len(pts)
    sxx = sum((p[0] - mx) ** 2 for p in pts) / len(pts)
    syy = sum((p[1] - my) ** 2 for p in pts) / len(pts)
    sxy = sum((p[0] - mx) * (p[1] - my) for p in pts) / len(pts)
    angle = 0.5 * math.atan2(2 * sxy, sxx - syy)
    span = (math.cos(angle), math.sin(angle))
    chord = (-span[1], span[0])
    return (mx, my), span, chord


def _inset(hull, amount):
    """The same shape, pulled in from its edges, so the soot laid under it
    shows as a rim instead of the panel butting against the roof."""
    mx = sum(x for x, _ in hull) / len(hull)
    my = sum(y for _, y in hull) / len(hull)
    out = []
    for x, y in hull:
        dx, dy = x - mx, y - my
        length = math.hypot(dx, dy) or 1
        scale = max(0.0, (length - amount)) / length
        out.append((mx + dx * scale, my + dy * scale))
    return out


def _wing_line(d, group, start, end, colour, thick=1):
    """A panel line down a wing, kept to the wing: the hull is not a
    rectangle, so a line drawn across its extent would run out over the
    roofs at the corners."""
    steps = int(max(abs(end[0] - start[0]), abs(end[1] - start[1]))) + 1
    for i in range(steps):
        t = i / max(1, steps - 1)
        px = round(start[0] + (end[0] - start[0]) * t)
        py = round(start[1] + (end[1] - start[1]) * t)
        if (px // TILE, py // TILE) in group:
            rect(d, px, py, thick, thick, colour)


def paint_airliner_wings(d, rng, level, tail):
    """The wings and the tailplanes, swept back off the body and drawn
    from the hull of their tiles so they come out as the straight-edged
    panels they are. `tail` lays down the shadow they throw, which goes
    on before the fuselage does so the body is not drawn over its own
    wings' shade."""
    body = airliner_body(level)
    if not body:
        return
    centre = (sum(body) / len(body) * TILE,
              sum((t + b) / 2 for t, b in body.values()) / len(body) * TILE)
    for group in _wing_groups(level):
        hull = _hull([(x * TILE + cx, y * TILE + cy)
                      for x, y in group
                      for cx in (0, TILE) for cy in (0, TILE)])
        if len(hull) < 3:
            continue
        panel = _inset(hull, 3)
        if tail:
            d.polygon([(x, y + 5) for x, y in panel], fill=HULL_SHADOW)
            continue
        d.polygon(panel, fill=WING_DARK)
        d.polygon(_inset(panel, 2), fill=WING)
        (mx, my), span, chord = _wing_axes(group)
        along = [(p[0] - mx) * span[0] + (p[1] - my) * span[1] for p in panel]
        across = [(p[0] - mx) * chord[0] + (p[1] - my) * chord[1] for p in panel]
        reach, width = max(along) - min(along), max(across) - min(across)

        def at(a, c):
            return (mx + span[0] * a + chord[0] * c,
                    my + span[1] * a + chord[1] * c)

        # the spar and the panel joints spanwise down the wing, the
        # leading edge bright, the flaps hinged off the back
        for share, colour, thick in ((-0.42, shade(WING, 50), 2),
                                     (-0.2, shade(WING, -32), 1),
                                     (0.06, shade(WING, 24), 1),
                                     (0.28, shade(WING, -26), 1),
                                     (0.42, shade(WING, -48), 1)):
            _wing_line(d, group,
                       at(min(along), width * share),
                       at(max(along), width * share), colour, thick)
        for _ in range(len(group) // 2):  # the dirt of the days since
            x, y = rng.choice(sorted(group))
            rect(d, x * TILE + rng.randrange(10), y * TILE + rng.randrange(12),
                 rng.randint(3, 6), 1, shade(WING, -40))
        if len(group) >= 15:
            paint_airliner_engine(d, group, centre, (mx, my), reach, span)


def paint_airliner_engine(d, group, centre, mid, reach, span):
    """The engine slung under a wing, half a span out from the body: the
    one thing that says aeroplane from any distance."""
    tip = max(group, key=lambda t: (t[0] * TILE - centre[0]) ** 2
              + (t[1] * TILE - centre[1]) ** 2)
    out = 1 if ((tip[0] * TILE - mid[0]) * span[0]
                + (tip[1] * TILE - mid[1]) * span[1]) > 0 else -1
    ex = round(mid[0] + span[0] * out * reach * 0.3)
    ey = round(mid[1] + span[1] * out * reach * 0.3)
    rect(d, ex - 13, ey - 7, 26, 14, SCORCH)
    rect(d, ex - 12, ey - 6, 24, 12, NACELLE_DARK)
    rect(d, ex - 12, ey - 6, 24, 3, NACELLE)
    rect(d, ex - 12, ey + 4, 24, 2, SCORCH)
    rect(d, ex - 12, ey - 6, 4, 12, CABIN_WINDOW)  # the intake
    rect(d, ex - 11, ey - 4, 2, 8, NACELLE)
    rect(d, ex + 9, ey - 3, 4, 6, SCORCH)  # and the cold jet pipe


def paint_airliner_tear(d, level, x, y):
    """The skin peeled back off the belly: the way into the cabin."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, HULL_DARK)
    rect(d, px, py + 2, TILE, 13, (18, 18, 22))
    for dx, w in ((0, 3), (6, 2), (11, 4)):
        rect(d, px + dx, py, w, 4, HULL_LIGHT)
    if level.at(x - 1, y) != "[":
        rect(d, px, py + 2, 2, 12, HULL_SHADE)
    if level.at(x + 1, y) != "[":
        rect(d, px + TILE - 2, py + 2, 2, 12, HULL_SHADE)
    rect(d, px, py + TILE - 1, TILE, 1, SCORCH)


def paint_airliner_scorch(d, rng, level, x, y):
    """The ground around the wreck, burnt and scraped where it came down."""
    px, py = x * TILE, y * TILE
    for _ in range(5):
        rect(d, px + rng.randrange(13), py + rng.randrange(13),
             rng.randint(2, 4), rng.randint(1, 2), SCORCH)


def paint_airliner_wreckage(d, rng, px, py):
    """Skin panels, seat cushions and cabin baggage thrown clear of it."""
    for _ in range(4):
        rect(d, px + rng.randrange(12), py + rng.randrange(12),
             rng.randint(3, 5), rng.randint(1, 3),
             shade(WING, rng.randrange(-40, 20)))
    rect(d, px + rng.randrange(11), py + rng.randrange(11), 4, 3,
         rng.choice(((92, 66, 46), (46, 62, 84), (120, 40, 36))))
    rect(d, px + rng.randrange(14), py + rng.randrange(14), 2, 1, SCORCH)


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


def paint_moored_boat(d, px, py, w, h):
    """A wooden rowboat tied to the pier, bow to the west, afloat and whole
    enough to step aboard: thwarts across it, oars shipped inside."""
    hull, hull_dark, inside = (120, 70, 44), (80, 46, 30), (154, 116, 78)
    gunwale = (170, 130, 90)
    rows = h - 4
    for r in range(rows):  # the bow narrows to a point, the stern is square
        edge = abs(r - (rows - 1) / 2) / ((rows - 1) / 2)
        indent = int(10 * edge * edge)
        rect(d, px + 3 + indent, py + 3 + r, w - 6 - indent, 1, hull_dark)
        rect(d, px + 2 + indent, py + 2 + r, w - 6 - indent, 1,
             gunwale if r in (0, rows - 1) else hull)
        if 2 <= r < rows - 2:
            rect(d, px + 5 + indent, py + 2 + r, w - 12 - indent, 1, inside)
    for tx in range(px + 20, px + w - 10, 18):  # thwarts
        rect(d, tx, py + 4, 3, rows - 4, hull_dark)
    rect(d, px + 10, py + h // 2 - 1, w - 22, 2, (190, 170, 120))  # an oar
    rect(d, px + w - 3, py + h // 2 - 2, 2, 4, (60, 60, 64))  # the rope's cleat
    rect(d, px + w - 1, py + h // 2 - 1, 3, 1, (170, 160, 130))  # the rope


def paint_bar_doorway(d, px, py):
    """The Bar Arcobaleno's door kicked in: light from the alley falls on
    the step, the dark of the bar behind."""
    rect(d, px + 2, py, 12, 4, (60, 52, 46))
    rect(d, px + 3, py + 4, 10, 10, (150, 142, 124))  # the step, lit
    rect(d, px + 3, py + 4, 10, 1, (110, 102, 90))
    rect(d, px + 5, py + 8, 3, 2, BLOOD_DARK)


def paint_palm(d, rng, px, py):
    """Palm in a stone planter on the promenade; its dusty fronds hang over
    the tile above."""
    rect(d, px + 2, py + 13, 13, 2, (30, 30, 34))
    rect(d, px + 2, py + 7, 12, 7, (150, 142, 126))
    rect(d, px + 3, py + 8, 10, 3, (62, 48, 36))
    rect(d, px + 2, py + 12, 12, 2, (118, 110, 98))
    trunk, ring = (112, 88, 60), (84, 64, 44)
    for i in range(20):  # slightly leaning trunk
        rect(d, px + 7 + (i * i) // 90, py + 9 - i, 3, 1, ring if i % 3 == 0 else trunk)
    top_x, top_y = px + 10, py - 11
    fronds = ((-12, 5), (-10, -4), (-3, -9), (4, -9), (11, -4), (13, 5), (0, 8), (-7, 9), (7, 9))
    for i, (fx, fy) in enumerate(fronds):
        colour = (70, 96, 50) if i % 2 else (92, 116, 60)
        if i in (2, 7):
            colour = (120, 110, 60)  # a dead, yellowed frond
        steps = max(abs(fx), abs(fy))
        for s in range(steps + 1):
            sx = top_x + fx * s // steps
            sy = top_y + fy * s // steps + (s * s) // (steps * 2 + 1)
            rect(d, sx, sy, 2, 2 if s < steps - 2 else 1, colour)
    rect(d, top_x - 1, top_y, 4, 3, (96, 70, 44))  # the crown


def paint_boat(d, px, py, hands):
    """Half-sunk rowboat over two tiles, seen from above: a white hull with
    a blue band, flooded, its stern already under the scum. From some, two
    green hands reach up out of the water inside."""
    hull, rim, stripe = (190, 186, 172), (120, 116, 104), (40, 70, 130)
    d.ellipse([px + 1, py + 4, px + 31, py + 15], fill=SEA_DARK)  # shadow
    d.ellipse([px, py + 2, px + 30, py + 13], fill=hull, outline=rim)
    d.ellipse([px + 2, py + 11, px + 28, py + 14], fill=stripe)
    d.ellipse([px, py + 2, px + 30, py + 12], fill=hull, outline=rim)
    d.ellipse([px + 3, py + 4, px + 27, py + 11], fill=(30, 40, 38))  # flooded
    for bx in (px + 10, px + 18):  # benches
        rect(d, bx, py + 4, 3, 8, (110, 84, 56))
        rect(d, bx, py + 4, 3, 1, (136, 104, 70))
    # the stern sinking: the sea laps over the last third
    d.polygon([(px + 23, py + 15), (px + 31, py + 1), (px + 32, py + 16)], fill=SEA)
    rect(d, px + 22, py + 12, 8, 1, SEA_WAVE)
    rect(d, px + 6, py + 7, 2, 1, (58, 70, 50))
    if hands:
        for hx in (px + 7, px + 15):
            rect(d, hx, py - 1, 2, 8, (96, 130, 80))
            rect(d, hx - 1, py - 3, 1, 3, (96, 130, 80))
            rect(d, hx + 1, py - 4, 1, 3, (96, 130, 80))
            rect(d, hx + 2, py - 3, 1, 3, (96, 130, 80))
            rect(d, hx, py + 3, 2, 1, (70, 30, 26))  # torn sleeve
