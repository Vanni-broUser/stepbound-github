#!/usr/bin/env python3
"""Bake the inside of the carabinieri barracks.

Reads the `barracks-rows` block of lib/core/levels/tutorial/barracks.dart and
paints a Pokemon-Emerald-style interior: the room floats on a black
background, the back wall shows its face with the emblem, notice boards and
shelves, and the floor is cluttered with desks, counters, cabinets and
toppled chairs. Everything is wrecked. Light and shadow are NOT baked: the
game darkens the room and draws the lamps on top.

Run from the repository root:  python tools/build_barracks.py
"""
from __future__ import annotations

import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_street_level import (  # noqa: E402
    BLOOD,
    BLOOD_DARK,
    OUTLINE,
    TILE,
    paint_emblem,
    read_rows,
    rect,
)

OUTPUT = os.path.join("assets", "levels", "barracks.png")

VOID = (6, 6, 8)
WALL_TOP = (46, 48, 56)
WALL_TOP_LIGHT = (70, 72, 82)
WALL_FACE = (150, 162, 150)
WALL_FACE_DARK = (118, 130, 120)
WAINSCOT = (84, 70, 58)
FLOOR_A = (170, 168, 156)
FLOOR_B = (156, 154, 144)
FLOOR_JOINT = (134, 132, 124)
WOOD = (132, 92, 58)
WOOD_LIGHT = (164, 120, 78)
WOOD_DARK = (92, 62, 40)
METAL = (120, 124, 132)
METAL_LIGHT = (160, 164, 172)
METAL_DARK = (78, 82, 90)
NAVY = (34, 44, 84)
PAPER = (226, 222, 206)

WALLS = set("xWQNSIw")


class Room:
    def __init__(self, rows):
        self.rows = rows
        self.height = len(rows)
        self.width = len(rows[0])

    def at(self, x, y):
        if 0 <= x < self.width and 0 <= y < self.height:
            return self.rows[y][x]
        return "x"

    def is_wall(self, x, y):
        return self.at(x, y) in WALLS


def paint_floor(d, rng, x, y):
    px, py = x * TILE, y * TILE
    for i in (0, 8):
        for j in (0, 8):
            rect(d, px + i, py + j, 8, 8, FLOOR_A if (i + j) // 8 % 2 == 0 else FLOOR_B)
    rect(d, px, py, TILE, 1, FLOOR_JOINT)
    rect(d, px, py, 1, TILE, FLOOR_JOINT)
    for _ in range(4):  # grime
        rect(d, px + rng.randrange(16), py + rng.randrange(16), 1, 1, (120, 118, 110))
    if rng.random() < 0.15:  # cracked tile
        cx, cy = px + rng.randrange(2, 12), py + rng.randrange(2, 12)
        for i in range(5):
            rect(d, cx + i, cy + (i % 3) - 1, 1, 1, (100, 98, 92))


def paint_back_wall(d, rng, room, x, y):
    """Two-tile tall wall seen face on: dark top, pale face, wood skirting."""
    px, py = x * TILE, y * TILE
    upper = room.at(x, y + 1) in WALLS and room.at(x, y + 1) != "I"
    if upper:  # top row of the wall: ceiling edge and upper face
        rect(d, px, py, TILE, 5, WALL_TOP)
        rect(d, px, py + 5, TILE, 11, WALL_FACE)
        rect(d, px, py + 5, TILE, 1, WALL_TOP_LIGHT)
    else:
        rect(d, px, py, TILE, TILE, WALL_FACE)
        rect(d, px, py + 10, TILE, 6, WAINSCOT)
        rect(d, px, py + 10, TILE, 1, WOOD_LIGHT)
        rect(d, px, py + 15, TILE, 1, WOOD_DARK)
    if rng.random() < 0.3:  # bullet holes and cracks
        hx, hy = px + rng.randrange(2, 14), py + rng.randrange(6, 10)
        rect(d, hx, hy, 1, 1, (40, 40, 40))
        rect(d, hx + 1, hy + 1, 1, 1, (100, 108, 100))


def paint_partition(d, room, x, y):
    """Interior wall: dark top, and a short face where the floor is below."""
    px, py = x * TILE, y * TILE
    if room.at(x, y + 1) in WALLS:
        rect(d, px, py, TILE, TILE, WALL_TOP)
        rect(d, px + 1, py, TILE - 2, TILE, WALL_TOP_LIGHT)
        rect(d, px + 3, py, TILE - 6, TILE, WALL_TOP)
        return
    rect(d, px, py, TILE, 6, WALL_TOP)
    rect(d, px, py, TILE, 1, WALL_TOP_LIGHT)
    rect(d, px, py + 6, TILE, 10, WALL_FACE_DARK)
    rect(d, px, py + 12, TILE, 4, WAINSCOT)


def paint_front_wall(d, x, y):
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, 7, WALL_TOP)
    rect(d, px, py, TILE, 1, WALL_TOP_LIGHT)
    rect(d, px, py + 7, TILE, 9, VOID)


def paint_side_edges(d, room):
    """Thin wall edges where the floor meets the darkness at the sides."""
    for y in range(room.height):
        for x in range(room.width):
            if room.is_wall(x, y):
                continue
            px, py = x * TILE, y * TILE
            if room.at(x - 1, y) == "x":
                rect(d, px, py, 4, TILE, WALL_TOP)
                rect(d, px + 3, py, 1, TILE, WALL_TOP_LIGHT)
            if room.at(x + 1, y) == "x":
                rect(d, px + 12, py, 4, TILE, WALL_TOP)
                rect(d, px + 12, py, 1, TILE, WALL_TOP_LIGHT)


def paint_wall_emblem(d, x, y):
    px, py = x * TILE, y * TILE
    rect(d, px + 1, py + 1, 14, 9, NAVY)
    paint_emblem(d, px + 3, py - 3)


def paint_notice_board(d, rng, x, y):
    px, py = x * TILE, y * TILE
    rect(d, px + 1, py + 1, 14, 8, WOOD_DARK)
    rect(d, px + 2, py + 2, 12, 6, (170, 130, 80))
    for _ in range(4):
        rect(d, px + rng.randrange(3, 11), py + rng.randrange(2, 6), 3, 2, PAPER)
    rect(d, px + 5, py + 8, 3, 2, PAPER)  # a sheet hanging loose


def paint_shelves(d, rng, x, y):
    px, py = x * TILE, y * TILE
    rect(d, px + 1, py - 6, 14, 16, WOOD_DARK)
    for sy in (py - 5, py + 1):
        rect(d, px + 2, sy + 5, 12, 1, WOOD_LIGHT)
        for bx in range(px + 2, px + 14, 2):
            if rng.random() < 0.7:
                colour = rng.choice(((40, 70, 120), (150, 40, 40), (60, 110, 60), (200, 180, 90)))
                rect(d, bx, sy + 1, 2, 4, colour)


def paint_exit_door(d, x, y):
    """Door in the back wall, ajar, grey daylight behind, green EXIT sign."""
    px, py = x * TILE, y * TILE
    rect(d, px, py - 14, TILE, 30, WALL_TOP)
    rect(d, px + 2, py - 12, 12, 28, (70, 90, 110))
    rect(d, px + 4, py - 8, 8, 24, (150, 170, 186))
    rect(d, px + 5, py - 4, 6, 20, (190, 204, 214))
    rect(d, px + 2, py - 12, 3, 28, WOOD)  # open leaf
    rect(d, px + 3, py + 2, 1, 2, (220, 190, 90))
    rect(d, px + 3, py - 19, 10, 5, (30, 120, 60))  # exit sign
    rect(d, px + 5, py - 18, 6, 3, (200, 250, 210))
    rect(d, px + 6, py - 17, 3, 1, (30, 120, 60))


def paint_entrance(d, x, y):
    """Front doorway: gap in the front wall with daylight and a mat."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, (238, 196, 110))
    rect(d, px + 2, py + 4, 12, 12, (252, 222, 150))
    rect(d, px, py, 2, 8, WOOD)
    rect(d, px + 14, py, 2, 8, WOOD)
    rect(d, px + 2, py - 4, 12, 3, (130, 40, 36))  # mat inside


def paint_desk(d, rng, px, py):
    """Office desk over two tiles: top, front panel, broken monitor, papers."""
    rect(d, px + 1, py + 15, 30, 1, (90, 88, 82))  # shadow
    rect(d, px, py + 2, 32, 9, WOOD_LIGHT)
    rect(d, px, py + 2, 32, 1, (190, 150, 100))
    rect(d, px, py + 11, 32, 4, WOOD_DARK)
    rect(d, px + 2, py + 11, 1, 4, OUTLINE)
    rect(d, px + 29, py + 11, 1, 4, OUTLINE)
    mx = px + 4 + rng.randrange(8)
    rect(d, mx, py - 3, 10, 7, (40, 42, 48))  # monitor
    rect(d, mx + 1, py - 2, 8, 5, (70, 90, 110))
    rect(d, mx + 3, py - 1, 1, 3, (220, 230, 240))  # cracked screen
    rect(d, mx + 4, py, 2, 1, (220, 230, 240))
    for _ in range(3):
        rect(d, px + 16 + rng.randrange(12), py + 3 + rng.randrange(5), 4, 3, PAPER)
    if rng.random() < 0.5:  # coffee spill
        rect(d, px + 20, py + 6, 5, 2, (90, 60, 40))


def paint_counter(d, px, py, first, last):
    """Reception counter segment."""
    rect(d, px, py + 3, TILE, 8, WOOD_LIGHT)
    rect(d, px, py + 3, TILE, 1, (190, 150, 100))
    rect(d, px, py + 11, TILE, 5, NAVY)
    rect(d, px, py + 12, TILE, 1, (200, 40, 40))
    rect(d, px, py - 6, TILE, 9, (150, 190, 200))  # glass screen
    rect(d, px + 5, py - 6, 3, 9, (60, 70, 80))  # shattered
    rect(d, px + 4, py - 2, 5, 1, (200, 230, 240))
    if first:
        rect(d, px, py - 6, 1, 22, OUTLINE)
    if last:
        rect(d, px + 15, py - 6, 1, 22, OUTLINE)


def paint_cabinet(d, px, py):
    rect(d, px + 2, py - 6, 12, 22, METAL_DARK)
    rect(d, px + 3, py - 5, 10, 20, METAL)
    for dy in (-3, 3, 9):
        rect(d, px + 4, py + dy, 8, 4, METAL_LIGHT)
        rect(d, px + 7, py + dy + 1, 2, 1, METAL_DARK)
    rect(d, px + 3, py + 9, 11, 5, METAL_LIGHT)  # drawer pulled out
    rect(d, px + 4, py + 9, 8, 2, PAPER)


def paint_chair(d, px, py):
    """Office chair lying on its side."""
    rect(d, px + 2, py + 10, 12, 3, (40, 40, 44))
    rect(d, px + 3, py + 6, 5, 4, (60, 70, 110))
    rect(d, px + 8, py + 8, 6, 3, (60, 70, 110))
    rect(d, px + 12, py + 13, 2, 2, (30, 30, 30))
    rect(d, px + 3, py + 13, 2, 2, (30, 30, 30))


def paint_papers(d, rng, px, py):
    for _ in range(6):
        rect(d, px + rng.randrange(1, 12), py + rng.randrange(2, 13), 4, 3, PAPER)
        rect(d, px + rng.randrange(1, 13), py + rng.randrange(2, 14), 3, 1, (180, 176, 164))


def paint_blood(d, rng, px, py):
    rect(d, px + 3, py + 5, 10, 6, BLOOD)
    rect(d, px + 5, py + 4, 5, 8, BLOOD)
    rect(d, px + 6, py + 7, 4, 3, BLOOD_DARK)
    rect(d, px + 12, py + 11, 2, 2, BLOOD)


def main() -> None:
    room = Room(read_rows("barracks-rows"))
    rng = random.Random(1814)  # the year the Arma was founded
    image = Image.new("RGB", (room.width * TILE, room.height * TILE), VOID)
    d = ImageDraw.Draw(image)

    for y in range(room.height):
        for x in range(room.width):
            if not room.is_wall(x, y):
                paint_floor(d, rng, x, y)
    for y in range(room.height):
        for x in range(room.width):
            glyph = room.at(x, y)
            if glyph in "WQNS":
                paint_back_wall(d, rng, room, x, y)
            elif glyph == "I":
                paint_partition(d, room, x, y)
            elif glyph == "w":
                paint_front_wall(d, x, y)
    paint_side_edges(d, room)
    for y in range(room.height):
        for x in range(room.width):
            glyph = room.at(x, y)
            px, py = x * TILE, y * TILE
            if glyph == "Q":
                paint_wall_emblem(d, x, y)
            elif glyph == "N":
                paint_notice_board(d, rng, x, y)
            elif glyph == "S":
                paint_shelves(d, rng, x, y)
            elif glyph == "O":
                paint_exit_door(d, x, y)
            elif glyph == "E":
                paint_entrance(d, x, y)
            elif glyph == ":":
                paint_papers(d, rng, px, py)
            elif glyph == "b":
                paint_blood(d, rng, px, py)
    # furniture, top to bottom so lower pieces overlap the ones behind
    for y in range(room.height):
        for x in range(room.width):
            glyph = room.at(x, y)
            px, py = x * TILE, y * TILE
            if glyph == "T" and room.at(x - 1, y) != "T":
                paint_desk(d, rng, px, py)
            elif glyph == "C":
                paint_counter(d, px, py, room.at(x - 1, y) != "C", room.at(x + 1, y) != "C")
            elif glyph == "A":
                paint_cabinet(d, px, py)
            elif glyph == "h":
                paint_chair(d, px, py)
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    image.save(OUTPUT, optimize=True)
    print(f"{OUTPUT}: {image.size[0]}x{image.size[1]}")


if __name__ == "__main__":
    main()
