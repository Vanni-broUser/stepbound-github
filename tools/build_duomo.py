#!/usr/bin/env python3
"""Bake the three-nave interior of the harbour Duomo."""

from __future__ import annotations

import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_mall import Room, paint_side_edges  # noqa: E402
from build_street_level import TILE, read_rows, rect, shade  # noqa: E402

OUTPUT = os.path.join("assets", "levels", "duomo.png")
VOID = (6, 6, 8)
FLOOR = (116, 106, 94)
FLOOR_ALT = (130, 120, 106)
JOINT = (76, 70, 66)
STONE = (178, 168, 148)
STONE_LIGHT = (210, 198, 170)
STONE_DARK = (112, 104, 94)
WOOD = (86, 56, 36)
WOOD_LIGHT = (128, 86, 52)
GOLD = (184, 146, 54)


def paint_floor(d, rng, x, y):
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, FLOOR if (x + y) % 2 else FLOOR_ALT)
    rect(d, px, py, TILE, 1, JOINT)
    rect(d, px, py, 1, TILE, JOINT)
    for _ in range(3):
        rect(d, px + rng.randrange(15), py + rng.randrange(15), 1, 1, JOINT)


def paint_wall(d, px, py, front=False):
    rect(d, px, py, TILE, TILE, STONE_DARK if front else STONE)
    rect(d, px, py, TILE, 2, shade(STONE, 24))
    rect(d, px, py + 8, TILE, 1, STONE_DARK)


def paint_altar(d, px, py):
    rect(d, px, py + 3, TILE, 12, STONE)
    rect(d, px, py + 3, TILE, 3, STONE_LIGHT)
    rect(d, px + 2, py + 6, TILE - 4, 6, (188, 176, 150))
    rect(d, px + 7, py, 2, 5, GOLD)


def paint_column(d, px, py):
    d.ellipse([px + 2, py, px + 13, py + 15], fill=STONE_DARK)
    d.ellipse([px + 3, py + 1, px + 12, py + 13], fill=STONE)
    rect(d, px + 5, py + 2, 3, 11, STONE_LIGHT)
    rect(d, px + 1, py + 13, 14, 3, STONE_DARK)


def paint_pew(d, px, py):
    rect(d, px, py + 4, TILE, 8, WOOD)
    rect(d, px, py + 4, TILE, 2, WOOD_LIGHT)
    rect(d, px + 1, py + 12, 3, 3, shade(WOOD, -20))
    rect(d, px + 12, py + 12, 3, 3, shade(WOOD, -20))


def paint_statue(d, px, py):
    rect(d, px + 3, py + 12, 10, 4, STONE_DARK)
    rect(d, px + 5, py + 5, 6, 8, STONE)
    d.ellipse([px + 5, py + 1, px + 10, py + 6], fill=STONE_LIGHT)
    rect(d, px + 3, py + 7, 3, 5, STONE)
    rect(d, px + 10, py + 7, 3, 5, STONE)


def paint_stairs(d, px, py):
    rect(d, px, py, TILE, TILE, (42, 40, 42))
    for step in range(4):
        inset = step * 2
        rect(
            d, px + inset, py + 3 + step * 3, TILE - inset, 2, shade(STONE, -step * 14)
        )


def paint_portal(d, px, py):
    rect(d, px, py, TILE, TILE, (26, 24, 26))
    rect(d, px + 3, py + 1, 10, TILE - 1, (186, 178, 160))
    rect(d, px + 5, py + 2, 6, TILE - 2, (220, 210, 188))
    rect(d, px, py, 3, TILE, WOOD)
    rect(d, px + 13, py, 3, TILE, WOOD)


def bake(room, rng, output):
    image = Image.new("RGB", (room.width * TILE, room.height * TILE), VOID)
    d = ImageDraw.Draw(image)
    for y in range(room.height):
        for x in range(room.width):
            glyph = room.at(x, y)
            if glyph not in "xWwIA":
                paint_floor(d, rng, x, y)
    for y in range(room.height):
        for x in range(room.width):
            glyph = room.at(x, y)
            px, py = x * TILE, y * TILE
            if glyph in "WI":
                paint_wall(d, px, py)
            elif glyph == "w":
                paint_wall(d, px, py, front=True)
            elif glyph == "A":
                paint_altar(d, px, py)
            elif glyph == "P":
                paint_column(d, px, py)
            elif glyph == "T":
                paint_pew(d, px, py)
            elif glyph == "S":
                paint_statue(d, px, py)
            elif glyph == "U":
                paint_stairs(d, px, py)
            elif glyph == "E":
                paint_portal(d, px, py)
    paint_side_edges(d, room)
    os.makedirs(os.path.dirname(output), exist_ok=True)
    image.save(output, optimize=True)
    print(f"{output}: {image.size[0]}x{image.size[1]}")


if __name__ == "__main__":
    bake(Room(read_rows("duomo-rows")), random.Random(1247), OUTPUT)
