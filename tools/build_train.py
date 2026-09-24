#!/usr/bin/env python3
"""Bake the two passenger coaches and locomotive interior.

Reads the `train-interior-rows` block in train.dart. Run from the
repository root with: python tools/build_train.py
"""
from __future__ import annotations

import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_mall import Room  # noqa: E402
from build_street_level import TILE, read_rows, rect, shade  # noqa: E402

OUTPUT = os.path.join("assets", "levels", "train_interior.png")

VOID = (6, 6, 8)
FLOOR_A = (92, 88, 82)
FLOOR_B = (82, 78, 74)
FLOOR_LINE = (60, 58, 58)
SHELL = (198, 194, 182)
SHELL_DARK = (116, 118, 122)
SHELL_LIGHT = (226, 220, 204)
METAL = (112, 116, 124)
METAL_DARK = (48, 52, 60)
METAL_LIGHT = (174, 178, 184)
GLASS = (34, 50, 66)
GLASS_LIGHT = (76, 106, 126)
SEAT = (62, 88, 124)
SEAT_DARK = (38, 54, 78)
WOOD = (128, 90, 54)
WOOD_LIGHT = (166, 124, 76)
LUGGAGE = (94, 64, 42)
CONTROL = (50, 58, 62)
CONTROL_LIGHT = (100, 116, 112)
MAP = (196, 166, 72)
MAP_DARK = (112, 86, 34)
LAMP = (242, 232, 190)
SAFETY = (214, 178, 48)


def paint_floor(d, rng, x, y):
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, FLOOR_A if (x + y) % 2 else FLOOR_B)
    rect(d, px, py, TILE, 1, FLOOR_LINE)
    rect(d, px, py, 1, TILE, FLOOR_LINE)
    for _ in range(2):
        rect(d, px + rng.randrange(15), py + rng.randrange(15), 1, 1,
             shade(FLOOR_A, rng.randrange(-22, 14)))


def paint_shell(d, room, x, y):
    px, py = x * TILE, y * TILE
    glyph = room.at(x, y)
    rect(d, px, py, TILE, TILE, METAL_DARK)
    if glyph == "W":
        rect(d, px, py + 3, TILE, 12, SHELL)
        rect(d, px, py + 3, TILE, 2, SHELL_LIGHT)
        if x % 4 in (1, 2):
            rect(d, px + 2, py + 6, 12, 7, METAL_DARK)
            rect(d, px + 3, py + 7, 10, 5, GLASS)
            rect(d, px + 4, py + 7, 5, 1, GLASS_LIGHT)
    elif glyph == "w":
        rect(d, px, py, TILE, 12, SHELL)
        rect(d, px, py, TILE, 2, SHELL_LIGHT)
        rect(d, px, py + 11, TILE, 4, SHELL_DARK)
    else:
        rect(d, px + 3, py, 10, TILE, SHELL_DARK)
        rect(d, px + 5, py, 6, TILE, METAL)
        rect(d, px + 6, py, 2, TILE, METAL_LIGHT)


def paint_exit(d, px, py):
    rect(d, px, py, TILE, TILE, (24, 28, 32))
    rect(d, px, py, TILE, 2, LAMP)
    rect(d, px, py + 12, TILE, 4, METAL_DARK)
    rect(d, px + 2, py + 13, 12, 1, METAL_LIGHT)
    for rail_x in (px + 1, px + 13):
        rect(d, rail_x, py + 2, 2, 11, SAFETY)


def paint_seat(d, room, x, y):
    px, py = x * TILE, y * TILE
    rect(d, px + 2, py + 2, 12, 12, SEAT_DARK)
    rect(d, px + 3, py + 3, 10, 6, SEAT)
    rect(d, px + 3, py + 10, 10, 3, shade(SEAT, -18))
    rect(d, px + 3, py + 3, 10, 1, shade(SEAT, 34))
    if room.at(x - 1, y) != "S":
        rect(d, px + 1, py + 4, 2, 9, METAL_LIGHT)
    if room.at(x + 1, y) != "S":
        rect(d, px + 13, py + 4, 2, 9, METAL_LIGHT)


def paint_table(d, px, py):
    rect(d, px + 1, py + 5, 14, 7, shade(WOOD, -24))
    rect(d, px + 1, py + 3, 14, 7, WOOD)
    rect(d, px + 2, py + 4, 12, 1, WOOD_LIGHT)
    rect(d, px + 4, py + 10, 2, 5, METAL_DARK)
    rect(d, px + 11, py + 10, 2, 5, METAL_DARK)


def paint_luggage(d, rng, px, py):
    rect(d, px + 2, py + 4, 12, 10, LUGGAGE)
    rect(d, px + 3, py + 5, 10, 2, shade(LUGGAGE, 28))
    rect(d, px + 6, py + 1, 5, 4, METAL_DARK)
    rect(d, px + 7, py + 2, 3, 3, FLOOR_B)
    rect(d, px + rng.randrange(3, 11), py + 7, 2, 5,
         shade(LUGGAGE, -28))


def paint_control(d, rng, px, py):
    rect(d, px + 1, py + 2, 14, 12, CONTROL)
    rect(d, px + 2, py + 3, 12, 4, CONTROL_LIGHT)
    for _ in range(4):
        colour = rng.choice(((178, 52, 42), (68, 146, 82), (214, 176, 54)))
        rect(d, px + rng.randrange(3, 13), py + rng.randrange(8, 12), 2, 2,
             colour)


def paint_engine(d, px, py):
    rect(d, px, py + 1, TILE, 14, METAL_DARK)
    for sy in range(py + 3, py + 13, 3):
        rect(d, px + 2, sy, 12, 1, METAL)
    rect(d, px + 2, py + 1, 12, 2, METAL_LIGHT)


def paint_map(d, px, py):
    """A yellowed paper map fixed to the driver's command console."""
    rect(d, px + 1, py + 2, 14, 12, METAL_DARK)
    rect(d, px + 3, py + 3, 10, 9, MAP)
    rect(d, px + 4, py + 5, 4, 1, MAP_DARK)
    rect(d, px + 7, py + 6, 5, 1, MAP_DARK)
    rect(d, px + 5, py + 8, 3, 1, MAP_DARK)
    rect(d, px + 9, py + 9, 3, 1, MAP_DARK)
    rect(d, px + 12, py + 3, 1, 9, shade(MAP, -28))


def paint_lamp(d, px, py):
    rect(d, px + 3, py + 5, 10, 5, METAL_DARK)
    rect(d, px + 4, py + 6, 8, 3, LAMP)
    rect(d, px + 6, py + 10, 4, 1, shade(LAMP, -52))


def bake():
    room = Room(read_rows("train-interior-rows"))
    if any(len(row) != room.width for row in room.rows):
        raise ValueError("train interior rows have different widths")
    rng = random.Random(1974)
    image = Image.new("RGB", (room.width * TILE, room.height * TILE), VOID)
    d = ImageDraw.Draw(image)

    for y in range(room.height):
        for x in range(room.width):
            glyph = room.at(x, y)
            if glyph not in "xWwIi":
                paint_floor(d, rng, x, y)

    for y in range(room.height):
        for x in range(room.width):
            glyph = room.at(x, y)
            px, py = x * TILE, y * TILE
            if glyph in "WwIi":
                paint_shell(d, room, x, y)
            elif glyph == "E":
                paint_exit(d, px, py)
            elif glyph == "S":
                paint_seat(d, room, x, y)
            elif glyph == "T":
                paint_table(d, px, py)
            elif glyph == "L":
                paint_luggage(d, rng, px, py)
            elif glyph == "C":
                paint_control(d, rng, px, py)
            elif glyph == "G":
                paint_engine(d, px, py)
            elif glyph == "P":
                paint_map(d, px, py)
            elif glyph == "*":
                paint_lamp(d, px, py)

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    image.save(OUTPUT, optimize=True)
    print(f"{OUTPUT}: {image.size[0]}x{image.size[1]}")


if __name__ == "__main__":
    bake()
