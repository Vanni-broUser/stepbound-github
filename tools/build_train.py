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
COT_FRAME = (70, 76, 60)
COT_CANVAS = (112, 118, 86)
# Mario's army blanket, folded square; Luigi's checked one, kicked about.
MARIO_BLANKET = (78, 92, 70)
LUIGI_BLANKET = (150, 52, 44)
LUIGI_CHECK = (206, 186, 160)
PILLOW = (214, 208, 190)
BAG = (28, 30, 32)
BAG_LIGHT = (70, 74, 78)
GLASS_GREEN = (58, 118, 70)
GLASS_BROWN = (122, 76, 30)
CAN_RED = (178, 40, 38)
CAN_SILVER = (184, 186, 190)
PAPER = (226, 220, 200)
PAPER_SHADE = (178, 170, 150)
INK = (62, 58, 60)
CRATE = (118, 84, 48)
CRATE_DARK = (78, 54, 30)
BOOK_COVERS = ((122, 38, 34), (40, 64, 104), (58, 86, 52))


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


def paint_map_table(d, room):
    """The table in the middle of the locomotive, the whole block of `P`
    tiles, with the yellowed map of Europe spread over it: a coastline, a
    few borders, and the route drawn on it in red."""
    tiles = [(x, y) for y in range(room.height) for x in range(room.width)
             if room.at(x, y) == "P"]
    left = min(x for x, _ in tiles) * TILE
    top = min(y for _, y in tiles) * TILE
    right = (max(x for x, _ in tiles) + 1) * TILE
    bottom = (max(y for _, y in tiles) + 1) * TILE
    width, height = right - left, bottom - top
    # The table: a dark edge, the top, and its legs at the corners.
    rect(d, left + 1, top + 3, width - 2, height - 3, shade(WOOD, -34))
    rect(d, left + 1, top + 1, width - 2, height - 4, WOOD)
    rect(d, left + 2, top + 2, width - 4, 1, WOOD_LIGHT)
    for leg_x in (left + 2, right - 5):
        rect(d, leg_x, bottom - 3, 3, 3, METAL_DARK)
    # The map, a little askew of the table's edges, its corners curling.
    mx, my, mw, mh = left + 5, top + 4, width - 10, height - 11
    rect(d, mx + 1, my + 1, mw, mh, shade(MAP, -60))
    rect(d, mx, my, mw, mh, MAP)
    sea = shade(MAP, -26)
    rect(d, mx + 2, my + 2, 10, mh - 4, sea)
    rect(d, mx + 12, my + mh - 8, 18, 6, sea)
    rect(d, mx + mw - 12, my + 2, 10, 7, sea)
    for bx, by, bw, bh in ((mx + 6, my + 4, 4, 5), (mx + 18, my + 6, 9, 1),
                           (mx + 30, my + 3, 1, 9), (mx + 24, my + 12, 12, 1),
                           (mx + 40, my + 9, 1, 8)):
        rect(d, bx, by, bw, bh, MAP_DARK)
    for cx, cy in ((mx, my), (mx + mw - 3, my + mh - 3)):
        rect(d, cx, cy, 3, 3, shade(MAP, 36))
    # The route: from the heel of Italy north, a red line and its stops.
    route = ((mx + 30, my + mh - 5), (mx + 26, my + 14), (mx + 34, my + 9),
             (mx + 36, my + 3))
    d.line(route, fill=(172, 34, 30), width=1)
    for sx, sy in (route[0], route[-1]):
        rect(d, sx - 1, sy - 1, 3, 3, (172, 34, 30))


def paint_driver_seat(d, px, py):
    """One of the two drivers' chairs, its back to the room, facing the
    controls."""
    rect(d, px + 5, py + 12, 6, 3, METAL_DARK)
    rect(d, px + 3, py + 3, 11, 10, SEAT_DARK)
    rect(d, px + 5, py + 4, 8, 8, SEAT)
    rect(d, px + 2, py + 2, 4, 12, SEAT_DARK)
    rect(d, px + 3, py + 3, 2, 10, shade(SEAT, 30))


def paint_cot(d, room, x, y, glyph):
    """One tile of a camp bed three tiles long: canvas stretched on a metal
    frame, a pillow at the end by the wall, a blanket over the rest."""
    px, py = x * TILE, y * TILE
    left = room.at(x - 1, y) != glyph
    right = room.at(x + 1, y) != glyph
    # The pillow goes at the end that is up against a wall.
    start = x
    while room.at(start - 1, y) == glyph:
        start -= 1
    pillow_left = room.at(start - 1, y) in "xWwIiV"
    rect(d, px, py + 2, TILE, 12, COT_FRAME)
    rect(d, px + (2 if left else 0), py + 3,
         TILE - (2 if left else 0) - (2 if right else 0), 10, COT_CANVAS)
    for leg_x in ((px + 1,) if left else ()) + ((px + 13,) if right else ()):
        rect(d, leg_x, py + 13, 2, 2, METAL_DARK)
    if (left and pillow_left) or (right and not pillow_left):
        rect(d, px + (3 if left else 5), py + 4, 8, 8, PILLOW)
        rect(d, px + (3 if left else 5), py + 10, 8, 2, shade(PILLOW, -30))
        return
    if glyph == "B":
        # Tucked in tight, the edge turned down neatly.
        end = 3 if (right and pillow_left) or (left and not pillow_left) else 0
        start_x = px + (end if left else 0)
        rect(d, start_x, py + 4, TILE - end, 8, MARIO_BLANKET)
        rect(d, start_x, py + 4, TILE - end, 1, shade(MARIO_BLANKET, 30))
        if room.at(x - 1, y) == glyph and room.at(x + 1, y) == glyph:
            # The turned-down edge, next to the pillow.
            edge = px + (1 if pillow_left else 12)
            rect(d, edge, py + 4, 3, 8, shade(MARIO_BLANKET, 22))
    else:
        # Half off the bed, in a heap.
        rect(d, px, py + 3, TILE, 11, LUIGI_BLANKET)
        for cx in range(px, px + TILE, 4):
            rect(d, cx, py + 3, 2, 11, shade(LUIGI_BLANKET, -24))
        for cy in range(py + 5, py + 14, 4):
            rect(d, px, cy, TILE, 1, LUIGI_CHECK)
        if right:
            rect(d, px + 10, py + 13, 6, 3, LUIGI_BLANKET)


def paint_bag(d, px, py):
    """A black bin bag knotted at the top."""
    rect(d, px + 3, py + 5, 10, 10, BAG)
    rect(d, px + 2, py + 8, 12, 6, BAG)
    rect(d, px + 6, py + 2, 4, 4, BAG)
    rect(d, px + 7, py + 1, 2, 2, BAG_LIGHT)
    rect(d, px + 4, py + 7, 2, 4, BAG_LIGHT)
    rect(d, px + 3, py + 15, 10, 1, shade(FLOOR_A, -30))


def paint_litter(d, rng, px, py):
    """An empty bottle and a crushed can left on the floor."""
    bottle = rng.choice((GLASS_GREEN, GLASS_BROWN))
    bx, by = px + rng.randrange(1, 5), py + rng.randrange(2, 6)
    rect(d, bx, by + 2, 8, 3, bottle)
    rect(d, bx + 8, by + 3, 3, 1, bottle)
    rect(d, bx + 1, by + 2, 6, 1, shade(bottle, 50))
    cx, cy = px + rng.randrange(7, 12), py + rng.randrange(9, 12)
    rect(d, cx, cy, 4, 3, CAN_RED)
    rect(d, cx, cy, 1, 3, CAN_SILVER)
    rect(d, cx + 1, cy + 1, 2, 1, shade(CAN_RED, 40))


def paint_papers(d, rng, px, py):
    """Loose sheets with a few lines written on them."""
    for _ in range(2):
        sx, sy = px + rng.randrange(0, 7), py + rng.randrange(0, 7)
        rect(d, sx + 1, sy + 1, 8, 9, PAPER_SHADE)
        rect(d, sx, sy, 8, 9, PAPER)
        for line in range(sy + 2, sy + 8, 2):
            rect(d, sx + 1, line, rng.randrange(3, 7), 1, INK)


def paint_books(d, room, x, y):
    """A crate for a desk, with books open on it and a stack beside."""
    px, py = x * TILE, y * TILE
    first = room.at(x - 1, y) != "k"
    rect(d, px, py + 3, TILE, 12, CRATE_DARK)
    rect(d, px, py + 3, TILE, 10, CRATE)
    rect(d, px, py + 7, TILE, 1, CRATE_DARK)
    if first:
        # An open book, its pages spread.
        rect(d, px + 2, py + 1, 12, 8, BOOK_COVERS[0])
        rect(d, px + 3, py + 2, 5, 6, PAPER)
        rect(d, px + 8, py + 2, 5, 6, shade(PAPER, -12))
        for line in range(py + 3, py + 8, 2):
            rect(d, px + 4, line, 3, 1, INK)
            rect(d, px + 9, line, 3, 1, INK)
        return
    # Another open face down, and a stack.
    rect(d, px + 1, py + 2, 7, 6, BOOK_COVERS[1])
    rect(d, px + 4, py + 2, 1, 6, shade(BOOK_COVERS[1], -30))
    for i, colour in enumerate(BOOK_COVERS):
        rect(d, px + 9, py + 7 - 2 * i, 6, 2, colour)
        rect(d, px + 9, py + 7 - 2 * i, 6, 1, shade(colour, 30))
    rect(d, px + 2, py + 10, 6, 3, PAPER)


def paint_lamp(d, px, py):
    rect(d, px + 3, py + 5, 10, 5, METAL_DARK)
    rect(d, px + 4, py + 6, 8, 3, LAMP)
    rect(d, px + 6, py + 10, 4, 1, shade(LAMP, -52))


WINDSCREEN_FRAME = (36, 40, 46)


def nose_edge(room):
    """The outer edge of the locomotive's nose, in pixels, for every pixel
    row: through the outer side of each windscreen tile `V`, smoothed, and
    closed at the top and bottom where the shell's straight walls end."""
    anchors = []
    for y in range(room.height):
        vs = [x for x in range(room.width) if room.at(x, y) == "V"]
        if vs:
            anchors.append((y * TILE + TILE / 2, (vs[0] + 1) * TILE))
        else:
            walls = [x for x in range(room.width) if room.at(x, y) in "Ww"]
            anchors.append((y * TILE + TILE / 2, (walls[-1] + 1) * TILE))
    edge = []
    for py in range(room.height * TILE):
        # Interpolate between the anchors around this row, then average a
        # little either side so the steps of the tiles melt into a curve.
        def at(yy):
            yy = min(max(yy, anchors[0][0]), anchors[-1][0])
            for (y0, x0), (y1, x1) in zip(anchors, anchors[1:]):
                if y0 <= yy <= y1:
                    return x0 + (x1 - x0) * (yy - y0) / (y1 - y0)
            return anchors[-1][1]
        samples = [at(py + k) for k in range(-10, 11)]
        edge.append(sum(samples) / len(samples))
    return edge


def paint_nose(image, room):
    """Clears everything past the nose's edge and draws the shell round it,
    with the windscreen just inside: glass along the front, a frame line,
    and the pillars at the two corners."""
    edge = nose_edge(room)
    nose_left = min(x for y in range(room.height) for x in range(room.width)
                    if room.at(x, y) == "V") * TILE - TILE
    pixels = image.load()
    glass_top = min(y for y in range(room.height)
                    if "V" in room.rows[y]) * TILE
    glass_bottom = (max(y for y in range(room.height)
                        if "V" in room.rows[y]) + 1) * TILE
    for py in range(room.height * TILE):
        x_edge = int(round(edge[py]))
        if x_edge < nose_left:
            continue
        for px in range(nose_left, room.width * TILE):
            depth = x_edge - px
            if depth <= 0:
                pixels[px, py] = VOID
            elif depth <= 2:
                pixels[px, py] = SHELL_DARK
            elif depth <= 4:
                pixels[px, py] = SHELL
            elif depth <= 10 and glass_top + 4 <= py < glass_bottom - 4:
                light = 7 <= depth <= 8 and (py // 6) % 3 == 0
                pixels[px, py] = GLASS_LIGHT if light else GLASS
            elif depth == 11 and glass_top + 4 <= py < glass_bottom - 4:
                pixels[px, py] = WINDSCREEN_FRAME
    # The pillars where the windscreen meets the roof and the floor.
    d = ImageDraw.Draw(image)
    for py in (glass_top + 3, glass_bottom - 6):
        x_edge = int(round(edge[py]))
        rect(d, x_edge - 12, py, 9, 3, SHELL_DARK)


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
    paint_map_table(d, room)

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
            elif glyph == "h":
                paint_driver_seat(d, px, py)
            elif glyph == "*":
                paint_lamp(d, px, py)
            elif glyph in "bB":
                paint_cot(d, room, x, y, glyph)
            elif glyph == "u":
                paint_bag(d, px, py)
            elif glyph == "o":
                paint_litter(d, rng, px, py)
            elif glyph == "f":
                paint_papers(d, rng, px, py)
            elif glyph == "k":
                paint_books(d, room, x, y)

    paint_nose(image, room)

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    image.save(OUTPUT, optimize=True)
    print(f"{OUTPUT}: {image.size[0]}x{image.size[1]}")


if __name__ == "__main__":
    bake()
