#!/usr/bin/env python3
"""Bake the background of the tutorial street level.

Reads the ASCII rows from lib/core/levels/street_level.dart (between the
`level-rows-start` / `level-rows-end` markers) and paints one 16x16 tile per
glyph in 3/4 view: roofs, south-facing facades, sidewalks with curbs, roads
with centre lines and zebra crossings, wrecked cars, traffic lights, bins and
corpses. Fires, backpacks and characters are NOT baked: the game draws and
animates them on top. Only scorch marks and the objects that burn are painted.

Run from the repository root:  python tools/build_street_level.py
"""
from __future__ import annotations

import os
import random
import re

from PIL import Image, ImageDraw

TILE = 16
LEVEL_DART = os.path.join("lib", "core", "levels", "street_level.dart")
OUTPUT = os.path.join("assets", "levels", "street_01.png")

ROAD_GLYPHS = set(".-|ZV")
WALK_GLYPHS = set("=")
BUILDING_GLYPHS = set("BHfK")
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
ROOFS = [(66, 60, 58), (74, 70, 72), (60, 64, 70), (80, 72, 64)]
CLOTHES = [(70, 80, 110), (110, 60, 50), (80, 90, 70), (60, 60, 66), (130, 120, 96)]
SKIN = [(200, 160, 130), (150, 110, 84), (180, 190, 150)]
HAIR = [(40, 30, 26), (90, 70, 40), (20, 20, 22)]
OUTLINE = (16, 12, 14)

# Shops along the first street, by band top row: (first column, width, kind).
# They are decorations: every one is wrecked and shut.
STOREFRONTS = {
    38: [
        (4, 5, "kebab"),
        (9, 4, "alimentari"),
        (20, 5, "pizzeria"),
        (25, 4, "bar"),
        (29, 5, "abbigliamento"),
        (34, 6, "burger"),
    ],
}

# 3x5 pixel font for shop signs.
FONT = {
    "A": ("010", "101", "111", "101", "101"),
    "B": ("110", "101", "110", "101", "110"),
    "C": ("011", "100", "100", "100", "011"),
    "E": ("111", "100", "110", "100", "111"),
    "G": ("011", "100", "101", "101", "011"),
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
    "Z": ("111", "001", "010", "100", "111"),
    " ": ("000", "000", "000", "000", "000"),
}


def text_width(text: str) -> int:
    return len(text) * 4 - 1


def paint_text(d, x, y, text, colour, missing=()):
    """Draws `text` with the 3x5 font; letters whose index is in `missing`
    have fallen off the sign."""
    for i, letter in enumerate(text):
        if i in missing:
            continue
        for row, bits in enumerate(FONT[letter]):
            for col, bit in enumerate(bits):
                if bit == "1":
                    rect(d, x + i * 4 + col, y + row, 1, 1, colour)


def read_rows(marker: str = "level-rows") -> list[str]:
    with open(LEVEL_DART, encoding="utf-8") as source:
        text = source.read()
    block = text.split(f"// {marker}-start", 1)[1].split(f"// {marker}-end", 1)[0]
    return re.findall(r"'([^']+)'", block)


def rect(d: ImageDraw.ImageDraw, x, y, w, h, c) -> None:
    if w > 0 and h > 0:
        d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)


class Level:
    def __init__(self, rows: list[str]):
        self.rows = rows
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
        """Floor under a prop or actor: the most common floor around it."""
        glyph = self.at(x, y)
        if glyph in WALK_GLYPHS:
            return "="
        if glyph in ROAD_GLYPHS:
            return "."
        votes = {"=": 0, ".": 0}
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                g = self.at(x + dx, y + dy)
                if g in WALK_GLYPHS:
                    votes["="] += 1 + (dy == 0)
                elif g in ROAD_GLYPHS:
                    votes["."] += 1 + (dy == 0)
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
    c = ROOFS[rng.randrange(len(ROOFS))]
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
        shops = [s for s in STOREFRONTS.get(top, []) if x0 <= s[0] < x0 + width]
        if shops:
            for sx, sw, kind in shops:
                paint_storefront(d, rng, sx * TILE, py0, sw * TILE, h, kind)
            continue
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
            else:  # short facade: a plain door at the bottom
                rect(d, px + w // 2 - 6, py0 + h - 14, 12, 14, (50, 36, 30))
                rect(d, px + w // 2 - 4, py0 + h - 12, 8, 1, (80, 60, 50))
    # burning windows: scorched frame, the flame itself is animated in game
    for y in range(level.height):
        for x in range(level.width):
            if level.at(x, y) == "f":
                px, py = x * TILE, y * TILE
                rect(d, px + 2, py - 2, 12, 16, SCORCH)
                rect(d, px + 4, py + 4, 8, 9, (60, 20, 14))
                rect(d, px + 3, py + 13, 10, 2, (40, 36, 36))


SHOPS = {
    # kind: (wall, trim, board, letters, sign text, missing letters)
    "kebab": ((150, 132, 104), (110, 94, 72), (150, 34, 26), (246, 206, 70), "KEBAB", ()),
    "alimentari": ((96, 98, 104), (68, 70, 76), (40, 96, 52), (232, 232, 220), "ALIMENTARI", (6,)),
    "pizzeria": ((116, 58, 48), (80, 38, 34), (226, 220, 200), (150, 34, 26), "PIZZERIA", ()),
    "bar": ((70, 84, 96), (50, 60, 70), (70, 44, 30), (236, 214, 160), "BAR", ()),
    "abbigliamento": ((120, 104, 120), (84, 70, 86), (60, 40, 90), (236, 226, 240), "ABBIGLIAMENTO", (3, 9)),
    "burger": ((140, 126, 96), (100, 88, 64), (170, 30, 28), (250, 200, 50), "BURGER", ()),
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
    if kind == "kebab":
        rect(d, x + 3, y, 1, 8, (170, 170, 170))
        for i, wdt in enumerate((2, 4, 5, 5, 4, 3)):
            rect(d, x + 4 - wdt // 2, y + 1 + i, wdt, 1, (150, 90, 40) if i % 2 else (190, 120, 60))
    elif kind == "pizzeria":
        rect(d, x + 1, y + 1, 6, 6, (230, 190, 90))
        rect(d, x + 2, y + 2, 4, 4, (200, 60, 40))
        rect(d, x + 3, y + 3, 1, 1, (250, 240, 220))
        rect(d, x + 5, y + 4, 1, 1, (70, 120, 50))
    elif kind == "bar":
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
        if kind in ("kebab", "bar", "burger"):
            paint_boards(d, wx, shop_top + 2, window_w, 12)
        else:
            paint_shutter(d, wx, shop_top + 2, window_w, 12, 8 + rng.randrange(4))
    # scorch marks licking up from the shop
    for _ in range(3):
        sx = px + rng.randrange(3, w - 6)
        rect(d, sx, shop_top - 2, 4, 3, (36, 30, 30))
        rect(d, sx + 1, shop_top - 5, 2, 3, (36, 30, 30))


def paint_barracks(d, level):
    """Carabinieri barracks: cream facade, dark blue sign with the flaming
    grenade, barred windows and a wide-open front door spilling light."""
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
    # Italian flag on a pole
    fx = px + w - 18
    rect(d, fx, py + 6, 1, 16, (60, 60, 60))
    for i, colour in enumerate(((40, 130, 60), (240, 240, 236), (200, 40, 40))):
        rect(d, fx + 1 + i * 3, py + 6, 3, 7, colour)
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


# ------------------------------------------------------------------ props


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


def main() -> None:
    level = Level(read_rows())
    rng = random.Random(20260921)
    image = Image.new("RGB", (level.width * TILE, level.height * TILE), ASPHALT)
    d = ImageDraw.Draw(image)

    for y in range(level.height):
        for x in range(level.width):
            if level.is_building(x, y):
                continue
            if level.surface(x, y) == "=":
                paint_sidewalk(d, rng, level, x, y)
            else:
                paint_road(d, rng, level, x, y)

    paint_roofs(d, rng, level)
    paint_facades(d, rng, level)
    paint_barracks(d, level)
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

    # scattered small debris over the walkable area
    for _ in range(level.width * level.height // 3):
        x = rng.randrange(level.width * TILE)
        y = rng.randrange(level.height * TILE)
        if level.at(x // TILE, y // TILE) in ROAD_GLYPHS | WALK_GLYPHS | {":"}:
            rect(d, x, y, rng.randint(1, 3), 1, rng.choice(DEBRIS))

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    image.save(OUTPUT, optimize=True)
    print(f"{OUTPUT}: {image.size[0]}x{image.size[1]}")


if __name__ == "__main__":
    main()
