#!/usr/bin/env python3
"""Bake the inside of San Nicola, the small church of the old town.

Reads the `church-rows` block of lib/core/levels/tutorial/church.dart and
paints it in the barracks' and the bar's style, a room floating on black:
a nave of worn flagstones between two ranks of pews shoved out of line, the
apse wall behind the altar with its fresco flaked away to plaster, the
columns down, plaster and glass over everything. Where the roof has fallen
in, `^`, daylight comes down on the stones; the game draws the light itself
(the place's `daylight` glyphs), this only paints what it falls on.

Run from the repository root:  python tools/build_church.py
"""
from __future__ import annotations

import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_mall import Room, paint_blood, paint_side_edges  # noqa: E402
from build_street_level import (  # noqa: E402
    DOOR_GREEN,
    OUTLINE,
    TILE,
    read_rows,
    rect,
    shade,
)

OUTPUT = os.path.join("assets", "levels", "church.png")

VOID = (6, 6, 8)
SLAB = (132, 124, 110)
SLAB_ALT = (120, 113, 100)
SLAB_JOINT = (92, 86, 78)
PLASTER = (196, 186, 166)
PLASTER_DARK = (150, 140, 124)
STONE = (168, 160, 144)
STONE_DARK = (120, 114, 102)
WALL_TOP = (44, 40, 38)
PEW = (96, 68, 42)
PEW_TOP = (132, 96, 60)
PEW_DARK = (64, 44, 28)
GOLD = (168, 138, 62)
# Faded almost into the plaster: what a fresco looks like after a fire and
# a winter of rain through the roof.
FRESCO = [(168, 146, 128), (150, 152, 158), (178, 160, 126), (146, 154, 140)]
RUBBLE = [(150, 142, 128), (122, 116, 104), (176, 168, 152), (96, 92, 86)]
SKY = (176, 186, 198)


def paint_floor(d, rng, x, y):
    """Big worn flagstones, two to a cell, gritty and cracked."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, SLAB if (x + y // 2) % 2 else SLAB_ALT)
    rect(d, px, py, TILE, 1, SLAB_JOINT)
    rect(d, px, py, 1, TILE, SLAB_JOINT)
    for _ in range(4):
        rect(d, px + rng.randrange(16), py + rng.randrange(16), 1, 1,
             SLAB_JOINT)
    if rng.random() < 0.18:
        cx, cy = px + rng.randrange(2, 12), py + rng.randrange(2, 12)
        for i in range(5):
            rect(d, cx + i, cy + (i % 3), 1, 1, (78, 72, 66))


def paint_plaster(d, rng, px, py):
    """Plaster, roof tiles and window glass down off the roof, underfoot:
    a few sherds big enough to see, and the dust of the rest."""
    for _ in range(3):
        rect(d, px + rng.randrange(11), py + rng.randrange(11),
             rng.randint(3, 5), rng.randint(2, 3), rng.choice(RUBBLE))
    for _ in range(8):
        rect(d, px + rng.randrange(15), py + rng.randrange(15),
             rng.randint(1, 3), 1, rng.choice(RUBBLE))
    if rng.random() < 0.4:  # a shard of window glass among it
        rect(d, px + rng.randrange(12), py + rng.randrange(12), 3, 1,
             (156, 176, 170))


def paint_apse(d, room, rng):
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
    rect(d, px, py, w, h, PLASTER)
    rect(d, px, py, w, 5, WALL_TOP)
    rect(d, px, py + 5, w, 2, shade(PLASTER, 26))  # the cornice
    for bx in range(px + 3, px + w - 6, 11):  # the blind arcade behind it
        d.ellipse([bx, py + 9, bx + 6, py + 15], fill=PLASTER_DARK)
        rect(d, bx, py + 12, 7, h - 18, PLASTER_DARK)
        rect(d, bx + 1, py + 13, 5, h - 19, shade(PLASTER, -8))
    for _ in range(w // 12):  # what is left of the fresco over it: two or
        # three overlapping blotches apiece, so no edge comes out square
        bx, by = px + rng.randrange(w - 16), py + 9 + rng.randrange(h - 21)
        colour = rng.choice(FRESCO)
        for _ in range(3):
            rect(d, bx + rng.randrange(-2, 5), by + rng.randrange(-2, 4),
                 rng.randint(5, 11), rng.randint(3, 7), colour)
    for _ in range(w // 9):  # and the plaster gone in patches
        bx, by = px + rng.randrange(w - 10), py + 8 + rng.randrange(h - 16)
        rect(d, bx, by, rng.randint(5, 10), rng.randint(3, 6), STONE_DARK)
    # the round-arched window over the altar, boarded from the far side
    cx, wy = px + w // 2, py + 9
    frame, hole = shade(PLASTER, 32), (24, 22, 24)
    d.ellipse([cx - 10, wy, cx + 10, wy + 20], fill=frame)
    d.ellipse([cx - 7, wy + 3, cx + 7, wy + 17], fill=hole)
    rect(d, cx - 10, wy + 10, 21, h - (wy - py) - 10, frame)
    rect(d, cx - 7, wy + 10, 15, h - (wy - py) - 10, hole)
    for i, by in enumerate((wy + 6, wy + 15)):  # the boards across it
        rect(d, cx - 9, by, 19, 3, (110, 84, 54) if i else (88, 66, 44))


def paint_side_wall(d, rng, room, x, y):
    """One cell of the aisle walls, `I`: ashlar with a niche here and
    there, its statue long gone."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, STONE)
    rect(d, px, py, TILE, 2, STONE_DARK)
    for _ in range(3):
        rect(d, px + rng.randrange(14), py + rng.randrange(14), 2, 1,
             STONE_DARK)
    if (x * 7 + y * 5) % 6 == 0:
        rect(d, px + 4, py + 3, 8, 11, (58, 54, 52))
        rect(d, px + 5, py + 4, 6, 9, (34, 32, 32))


def paint_front_wall(d, x, y):
    """The facade seen from inside: ashlar, with the odd window high up."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, WALL_TOP)
    rect(d, px, py + 3, TILE, 10, STONE)
    rect(d, px, py + 3, TILE, 1, STONE_DARK)
    if (x * 5) % 7 == 0:
        rect(d, px + 5, py + 4, 6, 8, (26, 28, 34))
        rect(d, px + 5, py + 4, 6, 1, STONE_DARK)


def paint_portal(d, px, py):
    """The way out, the leaves folded back and the square beyond them."""
    rect(d, px, py, TILE, TILE, (58, 54, 50))
    rect(d, px + 4, py + 2, 8, TILE - 2, (152, 146, 130))  # the daylight
    for leaf in (px, px + TILE - 4):
        rect(d, leaf, py, 4, TILE, DOOR_GREEN)
        rect(d, leaf + 1, py + 1, 2, TILE - 2, shade(DOOR_GREEN, 18))


def paint_altar(d, room, rng, x, y):
    """The altar, `A`: a stone table up two steps, the cloth dragged half
    off it and the candlesticks knocked over."""
    px, py = x * TILE, y * TILE
    first, last = room.at(x - 1, y) != "A", room.at(x + 1, y) != "A"
    if room.at(x, y - 1) != "A":  # the table top, and what is on it
        rect(d, px, py, TILE, 4, shade(STONE, 30))
        rect(d, px, py + 4, TILE, 6, (196, 186, 162))  # the altar cloth
        rect(d, px, py + 9, TILE, 2, (148, 138, 118))
        rect(d, px, py + 11, TILE, 5, STONE)
        if (x * 3) % 4 == 1:  # a candlestick knocked over on it
            rect(d, px + 2, py + 1, 11, 2, GOLD)
            rect(d, px + 2, py, 3, 3, shade(GOLD, 30))
        if (x * 5) % 4 == 2:  # the cloth hanging off the front
            rect(d, px + 4, py + 11, 8, 5, (196, 186, 162))
    else:  # the steps up to it, chipped
        rect(d, px, py, TILE, TILE, shade(STONE, -12))
        rect(d, px, py, TILE, 3, STONE)
        rect(d, px, py + 8, TILE, 3, shade(STONE, -22))
        for _ in range(3):
            rect(d, px + rng.randrange(13), py + rng.randrange(13), 2, 1,
                 STONE_DARK)
    if first:
        rect(d, px, py, 2, TILE, STONE_DARK)
    if last:
        rect(d, px + TILE - 2, py, 2, TILE, STONE_DARK)


def paint_pew(d, room, x, y):
    """A pew, `T`: the bench with its back to the altar, shoved out of
    line with the rank it belongs to."""
    px, py = x * TILE, y * TILE
    skew = (x * 5 + y * 3) % 3 - 1
    rect(d, px, py + 11 + skew, TILE, 3, PEW_DARK)  # its shadow
    rect(d, px, py + 3 + skew, TILE, 8, PEW)
    rect(d, px, py + 3 + skew, TILE, 2, PEW_TOP)
    rect(d, px, py + 9 + skew, TILE, 1, PEW_DARK)
    if room.at(x - 1, y) != "T":
        rect(d, px, py + 3 + skew, 2, 11, PEW_DARK)
    if room.at(x + 1, y) != "T":
        rect(d, px + TILE - 2, py + 3 + skew, 2, 11, PEW_DARK)


def paint_drum(d, px, py):
    """A column drum on its side, `K`: the shaft of one of the nave's
    columns, rolled off its base, the plaster burst away from the stone."""
    rect(d, px, py + 1, TILE, 14, OUTLINE)
    rect(d, px + 1, py + 2, 14, 12, STONE)
    rect(d, px + 1, py + 2, 14, 4, shade(STONE, 34))
    rect(d, px + 1, py + 11, 14, 3, shade(STONE, -26))
    for i in range(3):  # the fluting down the shaft
        rect(d, px + 3 + i * 4, py + 3, 1, 10, shade(STONE, -16))
    rect(d, px + 1, py + 5, 4, 7, PLASTER)  # plaster still clinging to it


def paint_roof_hole(d, rng, px, py):
    """Under a hole in the roof, `^`: daylight lies square on the slabs,
    and the tiles and laths that came down with it are heaped round the
    edges of it."""
    rect(d, px, py, TILE, TILE, shade(SLAB, 28))
    rect(d, px + 2, py + 2, 12, 12, shade(SLAB, 52))
    rect(d, px + 4, py + 3, 8, 9, SKY)
    rect(d, px + 5, py + 4, 6, 3, shade(SKY, 24))
    for _ in range(10):  # the dust of it, all round
        rect(d, px + rng.randrange(15), py + rng.randrange(15),
             rng.randint(1, 3), 1, rng.choice(RUBBLE))
    rect(d, px, py + 12, 6, 3, (108, 82, 54))  # a lath down with the tiles
    rect(d, px + 10, py, 5, 2, (96, 74, 48))


def bake(room: Room, rng, output):
    image = Image.new("RGB", (room.width * TILE, room.height * TILE), VOID)
    d = ImageDraw.Draw(image)
    for y in range(room.height):
        for x in range(room.width):
            if not room.is_wall(x, y) and room.at(x, y) != "x":
                paint_floor(d, rng, x, y)
    paint_apse(d, room, rng)
    for y in range(room.height):
        for x in range(room.width):
            glyph = room.at(x, y)
            px, py = x * TILE, y * TILE
            if glyph == "I":
                paint_side_wall(d, rng, room, x, y)
            elif glyph == "w":
                paint_front_wall(d, x, y)
            elif glyph == "E":
                paint_portal(d, px, py)
            elif glyph == ":":
                paint_plaster(d, rng, px, py)
            elif glyph == "b":
                paint_blood(d, rng, px, py)
            elif glyph == "^":
                paint_roof_hole(d, rng, px, py)
    paint_side_edges(d, room)
    for y in range(room.height):
        for x in range(room.width):
            glyph = room.at(x, y)
            px, py = x * TILE, y * TILE
            if glyph == "A":
                paint_altar(d, room, rng, x, y)
            elif glyph == "T":
                paint_pew(d, room, x, y)
            elif glyph == "K":
                paint_drum(d, px, py)
    os.makedirs(os.path.dirname(output), exist_ok=True)
    image.save(output, optimize=True)
    print(f"{output}: {image.size[0]}x{image.size[1]}")


def main() -> None:
    bake(Room(read_rows("church-rows")), random.Random(1497), OUTPUT)


if __name__ == "__main__":
    main()
