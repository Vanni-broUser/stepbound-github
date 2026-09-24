#!/usr/bin/env python3
"""Bake the dining hall and communal dormitory above the Duomo."""

from __future__ import annotations

import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_duomo import (  # noqa: E402
    GOLD,
    STONE,
    STONE_LIGHT,
    WOOD,
    WOOD_LIGHT,
    paint_floor,
    paint_wall,
)
from build_mall import Room, paint_side_edges  # noqa: E402
from build_street_level import TILE, read_rows, rect, shade  # noqa: E402

OUTPUT = os.path.join("assets", "levels", "duomo_upper.png")
VOID = (6, 6, 8)
LINEN = (174, 164, 146)
LINEN_LIGHT = (208, 198, 178)


def paint_table(d, px, py):
    rect(d, px, py + 3, TILE, 9, WOOD)
    rect(d, px, py + 3, TILE, 2, WOOD_LIGHT)
    rect(d, px + 2, py + 12, 3, 3, shade(WOOD, -22))
    rect(d, px + 11, py + 12, 3, 3, shade(WOOD, -22))


def paint_chair(d, px, py):
    rect(d, px + 3, py + 4, 10, 7, WOOD)
    rect(d, px + 4, py + 5, 8, 2, WOOD_LIGHT)
    rect(d, px + 4, py + 11, 2, 4, shade(WOOD, -20))
    rect(d, px + 10, py + 11, 2, 4, shade(WOOD, -20))


def paint_bed(d, px, py):
    rect(d, px + 1, py + 2, 14, 13, WOOD)
    rect(d, px + 2, py + 3, 12, 10, LINEN)
    rect(d, px + 2, py + 3, 12, 3, LINEN_LIGHT)
    rect(d, px + 3, py + 4, 10, 2, (222, 214, 196))
    rect(d, px + 2, py + 12, 12, 2, shade(LINEN, -24))


def paint_cupboard(d, px, py):
    rect(d, px + 2, py, 12, 16, shade(WOOD, -16))
    rect(d, px + 3, py + 1, 10, 14, WOOD)
    rect(d, px + 8, py + 1, 1, 14, shade(WOOD, -28))
    rect(d, px + 6, py + 8, 1, 1, GOLD)
    rect(d, px + 10, py + 8, 1, 1, GOLD)


def paint_stairs_down(d, px, py):
    rect(d, px, py, TILE, TILE, (34, 32, 34))
    for step in range(4):
        inset = step * 2
        rect(
            d, px + inset, py + 2 + step * 3, TILE - inset, 2, shade(STONE, -step * 14)
        )


def paint_locked_door(d, px, py):
    """A shut door with the same white interaction hand as the bar."""
    top = py - TILE
    rect(d, px + 1, top, TILE - 2, TILE * 2, (24, 22, 22))
    rect(d, px + 3, top + 2, TILE - 6, TILE * 2 - 3, (72, 48, 34))
    rect(d, px + 4, top + 3, TILE - 8, 2, (108, 76, 50))
    rect(d, px + 4, py + 2, TILE - 8, 1, (44, 30, 24))
    rect(d, px + 11, py + 7, 2, 2, (188, 158, 82))
    for ox, oy, width, height in ((7, 8, 2, 8), (5, 12, 6, 5), (4, 13, 2, 3)):
        rect(d, px + ox + 1, top + oy + 1, width, height, (24, 22, 22))
        rect(d, px + ox, top + oy, width, height, (244, 240, 228))


def bake(room, rng, output):
    image = Image.new("RGB", (room.width * TILE, room.height * TILE), VOID)
    d = ImageDraw.Draw(image)
    for y in range(room.height):
        for x in range(room.width):
            glyph = room.at(x, y)
            if glyph not in "xWwIL":
                paint_floor(d, rng, x, y)
    for y in range(room.height):
        for x in range(room.width):
            glyph = room.at(x, y)
            px, py = x * TILE, y * TILE
            if glyph in "WI":
                paint_wall(d, px, py)
            elif glyph == "w":
                paint_wall(d, px, py, front=True)
            elif glyph == "T":
                paint_table(d, px, py)
            elif glyph == "C":
                paint_chair(d, px, py)
            elif glyph == "B":
                paint_bed(d, px, py)
            elif glyph == "K":
                paint_cupboard(d, px, py)
            elif glyph == "D":
                paint_stairs_down(d, px, py)
            elif glyph == "L":
                paint_locked_door(d, px, py)
            elif glyph == "d":
                rect(d, px + 1, py, TILE - 2, 2, STONE_LIGHT)
    paint_side_edges(d, room)
    os.makedirs(os.path.dirname(output), exist_ok=True)
    image.save(output, optimize=True)
    print(f"{output}: {image.size[0]}x{image.size[1]}")


if __name__ == "__main__":
    bake(Room(read_rows("duomo-upper-rows")), random.Random(1527), OUTPUT)
