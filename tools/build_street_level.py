#!/usr/bin/env python3
"""Bake the backgrounds of the tutorial street, the north district and the
harbour.

Reads the ASCII rows from the place files in lib/core/levels/tutorial
(between the `level-rows-start` / `level-rows-end`, `north-rows-start` /
`north-rows-end` and `harbour-rows-start` / `harbour-rows-end` markers)
and paints one 16x16 tile per glyph in 3/4 view: roofs, south-facing
facades and shops, sidewalks with curbs, roads with centre lines and zebra
crossings, a paved square with its fountain, a parking lot and the
hypermarket, the seafront with its parapet, palms and murky water, wrecked
cars, traffic lights, bins and corpses. Fires, the barracks flag,
backpacks and characters are NOT baked: the game draws and animates them
on top. Only scorch marks and the objects that burn are painted.

Run from the repository root:  python tools/build_street_level.py
"""
from __future__ import annotations

import math
import os
import random
import re

from PIL import Image, ImageDraw

TILE = 16
LEVELS_DIR = os.path.join("lib", "core", "levels", "tutorial")
OUTPUT = os.path.join("assets", "levels", "first_street.png")
NORTH_OUTPUT = os.path.join("assets", "levels", "north_district.png")
HARBOUR_OUTPUT = os.path.join("assets", "levels", "harbour.png")

ROAD_GLYPHS = set(".-|ZV")
WALK_GLYPHS = set("=")
BUILDING_GLYPHS = set("BHfKMG")
FACADE_GLYPHS = set("Hf")

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
HARBOUR_STOREFRONTS = {
    9: [
        (7, 6, "pescheria"),
        (44, 6, "gelateria"),
    ],
}

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
    def __init__(self, rows: list[str], storefronts=None, old_town=False):
        self.rows = rows
        self.storefronts = storefronts or {}
        # Old town: white palazzi with green shutters, pale terraces.
        self.old_town = old_town
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

    def surface(self, x: int, y: int) -> str:
        """Floor under a prop or actor: the most common floor around it
        (`=` sidewalk, `.` road, `P` paving, `L` parking, `Y` stairs)."""
        glyph = self.at(x, y)
        if glyph in WALK_GLYPHS:
            return "="
        if glyph in ROAD_GLYPHS:
            return "."
        if glyph in "PLY":
            return glyph
        votes = {"=": 0, ".": 0, "P": 0, "L": 0, "Y": 0}
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                g = self.at(x + dx, y + dy)
                if g in WALK_GLYPHS:
                    votes["="] += 1 + (dy == 0)
                elif g in ROAD_GLYPHS:
                    votes["."] += 1 + (dy == 0)
                elif g in "PLY":
                    votes[g] += 1 + (dy == 0)
        return max(votes, key=votes.get)


def column_runs(level: Level, glyphs: set[str]):
    """Vertical runs of `glyphs`, grouped into bands of adjacent columns
    sharing the same top and bottom row. Yields (x0, width, top, bottom)."""
    runs: dict[tuple[int, int], list[int]] = {}
    for x in range(level.width):
        y = 0
        while y < level.height:
            if level.at(x, y) in glyphs:
                top = y
                while y < level.height and level.at(x, y) in glyphs:
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


def segments(x0: int, width: int, rng: random.Random) -> list[tuple[int, int]]:
    """Split a band into building widths of 3 to 6 tiles."""
    out, x, end = [], x0, x0 + width
    while x < end:
        w = min(rng.choice((3, 4, 4, 5, 6)), end - x)
        if end - (x + w) in (1, 2):
            w = end - x
        out.append((x, w))
        x += w
    return out


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


def paint_roofs(d, rng, level):
    """Roof areas split into a patchwork of buildings, each with its own
    colour, a parapet all around and a few rooftop units."""
    for x0, width, top, bottom in column_runs(level, {"B"}):
        for sx, sw in segments(x0, width, rng):
            for sy, sh in segments(top, bottom - top + 1, rng):
                paint_roof_block(d, rng, level, sx, sy, sw, sh)


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


def paint_facades(d, rng, level):
    for x0, width, top, bottom in column_runs(level, FACADE_GLYPHS):
        py0, h = top * TILE, (bottom - top + 1) * TILE
        shops = [s for s in level.storefronts.get(top, []) if x0 <= s[0] < x0 + width]
        houses = []
        x = x0
        for sx, sw, kind in sorted(shops):
            paint_storefront(d, rng, sx * TILE, py0, sw * TILE, h, kind)
            if sx > x:
                houses.append((x, sx - x))
            x = sx + sw
        if not shops or x < x0 + width:
            houses.append((x, x0 + width - x))
        for hx, hw in houses:
            if level.old_town:
                paint_old_town_houses(d, rng, hx, hw, py0, h)
            else:
                paint_houses(d, rng, hx, hw, py0, h)
    # burning windows: scorched frame, the flame itself is animated in game
    for y in range(level.height):
        for x in range(level.width):
            if level.at(x, y) == "f":
                px, py = x * TILE, y * TILE
                rect(d, px + 2, py - 2, 12, 16, SCORCH)
                rect(d, px + 4, py + 4, 8, 9, (60, 20, 14))
                rect(d, px + 3, py + 13, 10, 2, (40, 36, 36))


def paint_houses(d, rng, x0, width, py0, h):
    """Ordinary buildings along a band: windows upstairs; tall ones have a
    shut shop downstairs, short ones a street door, often boarded up."""
    for sx, sw in segments(x0, width, rng):
        px, w = sx * TILE, sw * TILE
        wall, trim = FACADES[rng.randrange(len(FACADES))]
        rect(d, px, py0, w, h, wall)
        rect(d, px, py0, w, 3, trim)
        rect(d, px + w - 1, py0, 1, h, trim)
        shop_h = 14 if h >= 64 else 0
        for wy in range(py0 + 8, py0 + h - shop_h - 12, 14):
            for wx in range(px + 5, px + w - 8, 12):
                roll = rng.random()
                pane = PANE if roll > 0.25 else (PANE_LIT if roll > 0.12 else PANE_BROKEN)
                rect(d, wx - 1, wy - 1, 8, 10, trim)
                rect(d, wx, wy, 6, 8, pane)
                if pane == PANE_BROKEN:
                    rect(d, wx + 1, wy + 1, 2, 3, PANE)
        if shop_h:
            shop_top = py0 + h - shop_h
            rect(d, px + 3, shop_top, w - 6, shop_h, SHOP_DARK)
            rect(d, px + 3, shop_top + 4, w - 6, 1, (48, 40, 40))
            for i in range(0, w - 6, 4):
                torn = (i * 7 + sx) % 5 == 0
                rect(d, px + 3 + i, shop_top - 4, 4, 2 if torn else 4 + (i * 5 % 3),
                     RED if (i // 4) % 2 else CREAM)
        else:  # short facade: a street door at the bottom
            door_x, door_y = px + w // 2 - 6, py0 + h - 14
            rect(d, door_x - 1, door_y - 1, 14, 15, trim)
            rect(d, door_x, door_y, 12, 14, (50, 36, 30))
            rect(d, door_x + 2, door_y + 2, 8, 1, (80, 60, 50))
            roll = rng.random()
            if roll < 0.65:
                paint_boarded_door(d, rng, door_x, door_y, 12, 14)
            elif roll < 0.8:  # kicked in: dark hall and a bloody hand
                rect(d, door_x + 1, door_y + 1, 10, 13, (16, 12, 14))
                rect(d, door_x + 9, door_y + 1, 3, 13, (70, 50, 40))
                rect(d, door_x - 3, door_y + 5, 3, 3, BLOOD)
                rect(d, door_x - 4, door_y + 4, 1, 2, BLOOD)
            if w >= 64 and rng.random() < 0.5:  # a boarded window too
                paint_boards(d, px + 5, py0 + 8, 6, 8)
            detail = rng.random()
            if detail < 0.3:  # air conditioner hanging off the wall
                ax = px + w - 14
                rect(d, ax, py0 + 18, 9, 6, (180, 180, 174))
                rect(d, ax + 1, py0 + 19, 5, 4, (120, 120, 116))
                rect(d, ax + 4, py0 + 24, 1, 5, (60, 60, 62))
            elif detail < 0.55:  # graffiti along the ground floor
                gx = px + 3
                for i in range(0, min(w - 20, 18), 2):
                    rect(d, gx + i, py0 + h - 8 + (i % 4) // 2, 2, 1, (60, 150, 170))
                rect(d, gx + 1, py0 + h - 5, min(w - 22, 14), 1, (190, 60, 150))
            elif detail < 0.75:  # a balcony with its railing
                bx = px + 4
                rect(d, bx, py0 + 17, 14, 1, (60, 60, 62))
                for i in range(0, 14, 3):
                    rect(d, bx + i, py0 + 14, 1, 4, (60, 60, 62))
                rect(d, bx, py0 + 14, 14, 1, (60, 60, 62))


def shade(c, amount):
    return tuple(max(0, min(255, v + amount)) for v in c)


def paint_old_town_houses(d, rng, x0, width, py0, h):
    """Palazzi of the old town: whitewashed limestone laid in courses, a
    cornice along the top, tall windows with green louvred shutters (open,
    shut, or hanging off a hinge), small iron balconies, and arched
    doorways with dark green doors at street level. Soot and grime climb
    the lower courses; the odd door has been forced."""
    for sx, sw in segments(x0, width, rng):
        px, w = sx * TILE, sw * TILE
        stone = OLD_TOWN_STONE[rng.randrange(len(OLD_TOWN_STONE))]
        joint = shade(stone, -26)
        rect(d, px, py0, w, h, stone)
        # courses of ashlar, staggered joints
        for row, cy in enumerate(range(py0 + 4, py0 + h, 5)):
            rect(d, px, cy, w, 1, joint)
            for jx in range(px + (0 if row % 2 else 5), px + w, 10):
                rect(d, jx, cy - 4, 1, 4, joint)
        for _ in range(sw * 6):  # weathered blocks
            bx = px + rng.randrange(w - 8)
            by = py0 + 4 + 5 * rng.randrange(max(1, (h - 8) // 5))
            rect(d, bx + 1, by + 1, rng.randint(4, 8), 4, shade(stone, -rng.randint(8, 18)))
        # cornice and the building's edge
        rect(d, px, py0, w, 3, shade(stone, 14))
        rect(d, px, py0 + 3, w, 1, shade(stone, -44))
        rect(d, px + w - 1, py0, 1, h, shade(stone, -40))
        # drainpipe down one side
        pipe_x = px + (2 if rng.random() < 0.5 else w - 4)
        rect(d, pipe_x, py0 + 3, 1, h - 3, (130, 130, 128))
        # windows, floor by floor, above the ground floor
        ground = py0 + h - 18
        for wy in range(py0 + 7, ground - 11, 15):
            for wx in range(px + 6, px + w - 9, 13):
                rect(d, wx - 1, wy - 1, 8, 12, shade(stone, 18))  # stone frame
                rect(d, wx, wy, 6, 10, PANE if rng.random() > 0.2 else PANE_BROKEN)
                green = SHUTTERS[rng.randrange(len(SHUTTERS))]
                slat = shade(green, -30)
                roll = rng.random()
                if roll < 0.4:  # shut: louvres over the whole window
                    rect(d, wx, wy, 6, 10, green)
                    for ly in range(wy + 1, wy + 10, 2):
                        rect(d, wx, ly, 6, 1, slat)
                    rect(d, wx + 3, wy, 1, 10, slat)
                elif roll < 0.8:  # open against the wall
                    for sx2 in (wx - 4, wx + 7):
                        rect(d, sx2, wy, 3, 10, green)
                        for ly in range(wy + 1, wy + 10, 2):
                            rect(d, sx2, ly, 3, 1, slat)
                elif roll < 0.92:  # one shutter torn off, hanging askew
                    rect(d, wx - 4, wy, 3, 10, green)
                    for i in range(8):
                        rect(d, wx + 7 + i // 3, wy + 3 + i, 3, 1, green if i % 2 else slat)
                if rng.random() < 0.3:  # iron balcony
                    rect(d, wx - 3, wy + 10, 12, 1, (50, 50, 52))
                    rect(d, wx - 3, wy + 7, 12, 1, (50, 50, 52))
                    for i in range(0, 12, 2):
                        rect(d, wx - 3 + i, wy + 7, 1, 4, (50, 50, 52))
        # arched doorway with a dark green door
        door_w = 10
        door_x = px + w // 2 - door_w // 2 + rng.choice((-6, 0, 6)) * (w >= 64)
        door_y = ground + 3
        surround = shade(stone, 16)
        rect(d, door_x - 2, door_y + 1, door_w + 4, h - (door_y - py0) - 1, surround)
        rect(d, door_x - 1, door_y - 1, door_w + 2, 2, surround)
        rect(d, door_x + 1, door_y - 2, door_w - 2, 1, surround)
        rect(d, door_x, door_y + 1, door_w, py0 + h - door_y - 1, DOOR_GREEN)
        rect(d, door_x + 1, door_y, door_w - 2, 1, DOOR_GREEN)
        rect(d, door_x + door_w // 2, door_y + 1, 1, py0 + h - door_y - 1, shade(DOOR_GREEN, -18))
        rect(d, door_x + 1, door_y + 1, door_w - 2, 3, (70, 70, 70))  # iron fanlight
        for i in range(1, door_w - 1, 2):
            rect(d, door_x + i, door_y + 2, 1, 1, (30, 30, 30))
        roll = rng.random()
        if roll < 0.2:  # forced: the dark hall and a smear of blood
            rect(d, door_x + 1, door_y + 5, door_w - 2, py0 + h - door_y - 5, (16, 12, 14))
            rect(d, door_x - 4, door_y + 7, 3, 3, BLOOD)
        elif roll < 0.4:
            paint_boards(d, door_x, door_y + 5, door_w, 8)
        # a small barred window beside the door
        if w >= 48:
            gx = px + 4 if door_x - px > 16 else px + w - 11
            rect(d, gx, ground + 5, 6, 6, (30, 30, 34))
            for i in range(0, 6, 2):
                rect(d, gx + i, ground + 5, 1, 6, (80, 80, 80))
        # grime and soot rising from the street
        for _ in range(w // 3):
            gx = px + rng.randrange(w)
            gh = rng.randint(2, 7)
            rect(d, gx, py0 + h - gh, 1, gh, shade(stone, -rng.randint(30, 60)))
        if rng.random() < 0.35:  # scorch licking up from a window
            sx2 = px + rng.randrange(4, w - 10)
            for i in range(6):
                rect(d, sx2 + i % 3, py0 + 6 + i * 2, 6 - i // 2, 2, (60, 52, 46))


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
    paint_text(d, lx, sign_top + 3, text, letters, missing)
    rect(d, px + w - 6, sign_top + 1, 1, 9, OUTLINE)  # crack at the edge
    rect(d, px + w - 5, sign_top + 5, 1, 5, OUTLINE)
    rect(d, px + 3, sign_top + 7, 6, 3, (40, 30, 30))  # soot
    # ground floor: wrecked and shut
    rect(d, px + 2, shop_top, w - 4, 17, trim)
    door_w = 12
    door_x = px + (w - door_w) // 2
    window_w = (w - 8 - door_w) // 2
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


def paint_back_passage(d, level):
    """Covered passage through the back of the barracks."""
    for y in range(level.height):
        for x in range(level.width):
            if level.at(x, y) != "e":
                continue
            px, py = x * TILE, y * TILE
            rect(d, px - 2, py, 20, 16, (150, 136, 104))
            rect(d, px, py + 2, 16, 14, (26, 24, 26))
            rect(d, px + 2, py + 4, 12, 12, (44, 40, 40))
            rect(d, px + 3, py + 13, 10, 3, (80, 76, 70))  # steps
            rect(d, px + 3, py + 10, 10, 2, (66, 62, 58))


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


def paint_algae(image, rng, level):
    """Greenish slicks of scum drifting on the water: ragged, dithered
    blobs spanning tiles, clipped to the sea."""
    d = ImageDraw.Draw(image)
    sea = [(x, y) for y in range(level.height) for x in range(level.width)
           if level.at(x, y) == "~"]
    for _ in range(len(sea) // 16):
        cx, cy = rng.choice(sea)
        cx, cy = cx * TILE + rng.randrange(TILE), cy * TILE + rng.randrange(TILE)
        rx, ry = rng.randint(6, 18), rng.randint(3, 7)
        for py in range(cy - ry, cy + ry + 1):
            for px in range(cx - rx, cx + rx + 1):
                if level.at(px // TILE, py // TILE) != "~":
                    continue
                inside = ((px - cx) / rx) ** 2 + ((py - cy) / ry) ** 2
                wobble = 0.15 * math.sin(px * 0.7 + cy) + 0.1 * math.cos(py * 1.3 + cx)
                if inside + wobble > 1:
                    continue
                if inside > 0.55 and (px + py) % 2:  # dithered edge
                    continue
                colour = ALGAE[0] if inside > 0.55 else ALGAE[1 + (rng.random() < 0.25)]
                rect(d, px, py, 1, 1, colour)


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


def main() -> None:
    bake(Level(read_rows(), STREET_STOREFRONTS), random.Random(20260921), OUTPUT)
    bake(Level(read_rows("north-rows"), NORTH_STOREFRONTS), random.Random(1861),
         NORTH_OUTPUT)
    bake(Level(read_rows("harbour-rows"), HARBOUR_STOREFRONTS, old_town=True),
         random.Random(1071), HARBOUR_OUTPUT)


def bake(level: Level, rng: random.Random, output: str) -> None:
    image = Image.new("RGB", (level.width * TILE, level.height * TILE), ASPHALT)
    d = ImageDraw.Draw(image)

    for y in range(level.height):
        for x in range(level.width):
            if level.is_building(x, y):
                continue
            if level.at(x, y) in "~b":
                paint_water(d, rng, x, y)
                continue
            if level.at(x, y) == "R":
                paint_parapet(d, rng, x, y)
                continue
            surface = level.surface(x, y)
            if surface == "Y":
                paint_stairs(d, level, x, y)
            elif surface == "=":
                paint_sidewalk(d, rng, level, x, y)
            elif surface == "P":
                paint_paving(d, rng, x, y)
            elif surface == "L":
                paint_parking(d, rng, level, x, y)
            else:
                paint_road(d, rng, level, x, y)

    paint_algae(image, rng, level)
    paint_roofs(d, rng, level)
    paint_facades(d, rng, level)
    paint_barracks(d, level)
    paint_hypermarket(d, rng, level)
    paint_hospital(d, rng, level)
    paint_back_passage(d, level)

    car_colors = [(140, 40, 36), (70, 96, 130), (180, 170, 150), (60, 110, 80)]
    color_index = 0
    for y in range(level.height):
        for x in range(level.width):
            glyph = level.at(x, y)
            px, py = x * TILE, y * TILE
            if glyph == ":":
                paint_debris(d, rng, px, py)
            elif glyph == "d":
                paint_corpse(image, rng, px, py)
            elif glyph == "D":
                paint_corpse_pile(image, rng, px, py)
            elif glyph == "F":
                paint_bin(d, px, py)
            elif glyph == "S":
                paint_campfire(d, px, py)
            elif glyph == "O" and level.at(x - 1, y) != "O" and level.at(x, y - 1) != "O":
                size = 1
                while level.at(x + size, y) == "O":
                    size += 1
                paint_fountain(image, rng, px, py, size)
            elif glyph == "n" and level.at(x - 1, y) != "n":
                paint_bench(d, px, py)
            elif glyph == "y":
                paint_trolley(d, px, py, tipped=(x + y) % 2 == 0)
            elif glyph == "J":
                paint_road_block(d, px, py)
            elif glyph == "a" and level.at(x - 1, y) != "a":
                paint_ambulance(d, px, py)
            elif glyph == "Q":
                paint_cafe_table(d, px, py)
            elif glyph == "b" and level.at(x - 1, y) != "b":
                paint_boat(d, px, py, hands=(x + y) % 3 == 1)
            elif glyph == "q":
                paint_chair(d, px, py, toppled=(x + y) % 3 != 0)
                for _ in range(3):  # litter around the terrace
                    rect(d, px + rng.randrange(14), py + rng.randrange(14), 2, 1,
                         rng.choice(DEBRIS))
            elif glyph in "CXU" and level.at(x - 1, y) != glyph:
                color = car_colors[color_index % len(car_colors)]
                color_index += 1
                paint_car(d, px, py, color, burnt=glyph == "X", flipped=glyph == "U")
            elif glyph in "vk" and level.at(x, y - 1) != glyph:
                color = car_colors[color_index % len(car_colors)]
                color_index += 1
                paint_car_vertical(d, px, py, color, burnt=glyph == "k")
    # traffic lights last: their heads overlap the tile above
    for y in range(level.height):
        for x in range(level.width):
            if level.at(x, y) == "T":
                paint_traffic_light(d, x * TILE, y * TILE)
            elif level.at(x, y) == "A":
                paint_tree(d, rng, x * TILE, y * TILE)
            elif level.at(x, y) == "N":
                paint_palm(d, rng, x * TILE, y * TILE)

    # scattered small debris over the walkable area
    for _ in range(level.width * level.height // 3):
        x = rng.randrange(level.width * TILE)
        y = rng.randrange(level.height * TILE)
        if level.at(x // TILE, y // TILE) in ROAD_GLYPHS | WALK_GLYPHS | set(":PL"):
            rect(d, x, y, rng.randint(1, 3), 1, rng.choice(DEBRIS))

    os.makedirs(os.path.dirname(output), exist_ok=True)
    image.save(output, optimize=True)
    print(f"{output}: {image.size[0]}x{image.size[1]}")


if __name__ == "__main__":
    main()
