#!/usr/bin/env python3
"""Bake the Bar Arcobaleno's cramped storeroom."""

from __future__ import annotations

import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_mall import Room, paint_side_edges  # noqa: E402
from build_street_level import TILE, read_rows, rect, shade  # noqa: E402

OUTPUT = os.path.join("assets", "levels", "bar_backroom.png")
VOID = (6, 6, 8)
FLOOR = (80, 74, 68)
FLOOR_ALT = (96, 88, 78)
WALL = (112, 96, 82)
WALL_DARK = (54, 46, 42)
WOOD = (94, 62, 38)


def bake(room, rng, output):
    image = Image.new("RGB", (room.width * TILE, room.height * TILE), VOID)
    d = ImageDraw.Draw(image)
    for y in range(room.height):
        for x in range(room.width):
            glyph = room.at(x, y)
            px, py = x * TILE, y * TILE
            if glyph not in "xWwI":
                rect(d, px, py, TILE, TILE, FLOOR if (x + y) % 2 else FLOOR_ALT)
                rect(d, px, py, TILE, 1, WALL_DARK)
            if glyph in "WIw":
                rect(d, px, py, TILE, TILE, WALL_DARK if glyph == "w" else WALL)
                rect(d, px, py, TILE, 2, shade(WALL, 20))
            elif glyph == "K":
                rect(d, px, py + 4, TILE, 11, WOOD)
                rect(d, px, py + 4, TILE, 2, shade(WOOD, 30))
            elif glyph == "B":
                rect(d, px + 1, py + 2, 14, 13, WOOD)
                rect(d, px + 2, py + 3, 12, 2, shade(WOOD, 28))
                rect(d, px + 7, py + 3, 2, 11, shade(WOOD, -24))
            elif glyph == ":":
                for _ in range(8):
                    rect(
                        d,
                        px + rng.randrange(15),
                        py + rng.randrange(15),
                        rng.randint(1, 3),
                        1,
                        (52, 48, 46),
                    )
            elif glyph == "E":
                rect(d, px, py, TILE, TILE, (28, 26, 28))
                rect(d, px + 4, py + 2, 8, TILE - 2, (176, 164, 144))
    paint_side_edges(d, room)
    os.makedirs(os.path.dirname(output), exist_ok=True)
    image.save(output, optimize=True)
    print(f"{output}: {image.size[0]}x{image.size[1]}")


if __name__ == "__main__":
    bake(Room(read_rows("bar-backroom-rows")), random.Random(418), OUTPUT)
