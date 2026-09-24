#!/usr/bin/env python3
"""Bake the inside of the Bar Arcobaleno.

Reads the `bar-rows` block of lib/core/levels/tutorial/bar_arcobaleno.dart
and paints it in the barracks' and hypermarket's style, a room floating on
black: a chequered floor under broken glass and toppled chairs, the counter
across the back, shelves of bottles behind it under a faded rainbow mural,
tables, a dead jukebox, blood. The lamps' light is drawn by the game.

Run from the repository root:  python tools/build_bar.py
"""
from __future__ import annotations

import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_mall import Room, paint_blood, paint_side_edges  # noqa: E402
from build_street_level import (  # noqa: E402
    OUTLINE,
    RAINBOW,
    TILE,
    paint_chair,
    paint_text,
    read_rows,
    rect,
    text_width,
)

OUTPUT = os.path.join("assets", "levels", "bar_arcobaleno.png")

VOID = (6, 6, 8)
CHECK_LIGHT = (176, 168, 150)
CHECK_DARK = (70, 64, 60)
WALL_FACE = (150, 120, 96)
WALL_TOP = (46, 40, 40)
SHELF = (86, 60, 40)
COUNTER = (110, 70, 44)
COUNTER_TOP = (150, 104, 66)
BOTTLES = [(60, 110, 60), (140, 90, 40), (180, 180, 170), (110, 40, 40), (60, 80, 120)]


def paint_floor(d, rng, x, y):
    """Black and white tiles, four to a cell, grimy and cracked."""
    px, py = x * TILE, y * TILE
    for i in range(2):
        for j in range(2):
            c = CHECK_LIGHT if (x * 2 + i + y * 2 + j) % 2 else CHECK_DARK
            rect(d, px + i * 8, py + j * 8, 8, 8, c)
    for _ in range(4):
        rect(d, px + rng.randrange(16), py + rng.randrange(16), 1, 1, (100, 94, 86))
    if rng.random() < 0.15:
        cx, cy = px + rng.randrange(2, 12), py + rng.randrange(2, 12)
        for i in range(5):
            rect(d, cx + i, cy + (i % 3), 1, 1, (40, 36, 34))


def paint_glass(d, rng, px, py):
    """Broken bottles and glasses underfoot."""
    for _ in range(6):
        rect(d, px + rng.randrange(14), py + rng.randrange(14), rng.randint(1, 2), 1,
             rng.choice(((170, 200, 190), (90, 140, 90), (160, 110, 60))))


def paint_back_wall(d, room, rng):
    """Shelves of bottles, most smashed, under the bar's rainbow painted
    across the whole wall, flaking."""
    ys = [y for y in range(room.height) if room.at(1, y) == "W"]
    top, bottom = min(ys), max(ys)
    x0 = min(x for x in range(room.width) if room.at(x, top) == "W")
    x1 = max(x for x in range(room.width) if room.at(x, top) == "W")
    px, py = x0 * TILE, top * TILE
    w, h = (x1 - x0 + 1) * TILE, (bottom - top + 1) * TILE
    rect(d, px, py, w, h, WALL_FACE)
    rect(d, px, py, w, 4, WALL_TOP)
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
        paint_text(d, tx + i * 8, py + 19, letter, RAINBOW[i % len(RAINBOW)], scale=2)


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


def paint_table(d, px, py, first, last):
    rect(d, px, py + 13, TILE, 2, (30, 26, 26))
    rect(d, px, py + 4, TILE, 5, (130, 96, 60))
    rect(d, px, py + 4, TILE, 1, (160, 120, 80))
    if first:
        rect(d, px + 2, py + 9, 2, 5, (84, 60, 40))
    if last:
        rect(d, px + 12, py + 9, 2, 5, (84, 60, 40))


def paint_jukebox(d, px, py, first):
    """A jukebox, its dome smashed, only half of it lit by nothing."""
    if not first:
        return
    rect(d, px + 2, py - 6, 28, 21, OUTLINE)
    rect(d, px + 3, py - 5, 26, 19, (120, 50, 60))
    rect(d, px + 5, py - 4, 22, 6, (200, 170, 90))
    for i, colour in enumerate(RAINBOW):
        rect(d, px + 5 + i * 4, py + 3, 3, 3, colour)
    rect(d, px + 8, py + 8, 16, 4, (40, 36, 40))
    rect(d, px + 12, py - 3, 6, 2, (30, 26, 26))  # the smashed dome


def paint_front_wall(d, x, y):
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, WALL_TOP)
    rect(d, px, py + 3, TILE, 10, (60, 72, 84))
    rect(d, px + 3, py + 4, 2, 8, (110, 130, 150))
    if (x * 5) % 7 == 0:  # the window's smashed in
        rect(d, px + 6, py + 4, 6, 8, (20, 22, 26))


def paint_door(d, x, y):
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, (150, 142, 124))
    rect(d, px + 1, py, 3, TILE, (70, 50, 36))  # the door hanging off
    rect(d, px + 5, py + 6, 3, 2, (120, 30, 30))


def paint_locked_door(d, px, py):
    """The open service doorway under the dynamic locked-door component."""
    top = py - TILE
    rect(d, px + 1, top, TILE - 2, TILE * 2, OUTLINE)
    rect(d, px + 3, top + 2, TILE - 6, TILE * 2 - 3, (18, 16, 18))
    rect(d, px + 2, top + 1, 2, TILE * 2 - 2, (88, 58, 38))
    rect(d, px + 12, top + 1, 2, TILE * 2 - 2, (88, 58, 38))
    rect(d, px + 4, py + 12, TILE - 8, 4, (104, 96, 86))


def bake(room: Room, rng, output):
    image = Image.new("RGB", (room.width * TILE, room.height * TILE), VOID)
    d = ImageDraw.Draw(image)
    for y in range(room.height):
        for x in range(room.width):
            if not room.is_wall(x, y) and room.at(x, y) not in "xWw":
                paint_floor(d, rng, x, y)
    paint_back_wall(d, room, rng)
    for y in range(room.height):
        for x in range(room.width):
            glyph = room.at(x, y)
            px, py = x * TILE, y * TILE
            if glyph == "w":
                paint_front_wall(d, x, y)
            elif glyph == "E":
                paint_door(d, x, y)
            elif glyph == "D":
                paint_locked_door(d, px, py)
            elif glyph == ":":
                paint_glass(d, rng, px, py)
            elif glyph == "b":
                paint_blood(d, rng, px, py)
            elif glyph == "q":
                paint_chair(d, px, py, toppled=True)
    paint_side_edges(d, room)
    for y in range(room.height):
        for x in range(room.width):
            glyph = room.at(x, y)
            px, py = x * TILE, y * TILE
            if glyph == "K":
                paint_counter(d, room, x, y)
            elif glyph == "T":
                paint_table(d, px, py, room.at(x - 1, y) != "T", room.at(x + 1, y) != "T")
            elif glyph == "J":
                paint_jukebox(d, px, py, room.at(x - 1, y) != "J")
    os.makedirs(os.path.dirname(output), exist_ok=True)
    image.save(output, optimize=True)
    print(f"{output}: {image.size[0]}x{image.size[1]}")


def main() -> None:
    bake(Room(read_rows("bar-rows")), random.Random(1979), OUTPUT)


if __name__ == "__main__":
    main()
