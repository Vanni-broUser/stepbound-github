#!/usr/bin/env python3
"""The hypermarket's painters: the two floors of the mall, and the tables
of shopfronts along their walls.

The mall used to be baked here, one picture per floor. It is not any more:
the game paints both floors from their rows out of the tile atlas
(tools/build_tile_atlas.py), which uses the painters below. What the atlas
cannot say by glyph -- which shop stands where -- is the two tables of
shopfronts, and the pieces of wall that stand taller than one cell.
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_street_level import (  # noqa: E402
    BLOOD,
    BLOOD_DARK,
    OUTLINE,
    TILE,
    paint_boards,
    paint_smashed_display,
    paint_text,
    rect,
    text_width,
)

VOID = (6, 6, 8)
FLOOR_A = (178, 174, 164)
FLOOR_B = (166, 162, 152)
FLOOR_JOINT = (140, 136, 128)
FLOOR_SHINE = (198, 196, 188)
SHOP_FLOOR = (128, 112, 90)
SHOP_FLOOR_JOINT = (104, 90, 72)
SERVICE_A = (84, 84, 88)
SERVICE_B = (76, 76, 80)
WALL_TOP = (46, 48, 56)
WALL_FACE = (196, 190, 176)
WALL_FACE_DARK = (160, 154, 142)
METAL = (120, 124, 132)
METAL_LIGHT = (170, 174, 182)
METAL_DARK = (72, 76, 84)
GLASS = (46, 60, 76)
GLASS_SHINE = (104, 128, 150)

WALLS = set("xWwISQ")

# Shopfronts along a back wall, by (first column, top row of that wall):
# (width, sign, board, letters, front). Front is "glass", "shutter",
# "smashed" or "boards". The ground floor has two back walls, one per area.
GROUND_SHOPS = {
    # The upper area's own row, wall to wall but for the fire exit.
    (1, 1): (6, "TABACCHI", (150, 130, 40), (250, 240, 190), "boards"),
    (7, 1): (6, "OTTICA", (30, 80, 110), (220, 240, 250), "smashed"),
    (13, 1): (6, "GIOCATTOLI", (170, 50, 60), (250, 230, 120), "shutter"),
    (19, 1): (6, "LIBRERIA", (60, 90, 50), (236, 240, 220), "smashed"),
    (25, 1): (6, "FERRAMENTA", (70, 70, 80), (230, 230, 236), "boards"),
    (31, 1): (6, "SPORT", (20, 90, 130), (235, 245, 250), "glass"),
    (37, 1): (6, "CARTOLERIA", (190, 120, 40), (255, 240, 210), "smashed"),
    # The hall's, below it, three on either side of the central stairs.
    (4, 15): (6, "ELETTRONICA", (26, 46, 96), (120, 220, 240), "smashed"),
    (10, 15): (6, "SCARPE", (60, 60, 64), (240, 200, 90), "shutter"),
    (16, 15): (6, "PROFUMERIA", (120, 60, 110), (246, 226, 240), "glass"),
    (25, 15): (6, "BAR", (70, 44, 30), (236, 214, 160), "boards"),
    (31, 15): (6, "GIOIELLERIA", (90, 70, 110), (240, 225, 160), "shutter"),
    (37, 15): (6, "CASALINGHI", (40, 100, 100), (230, 245, 240), "smashed"),
}
FIRST_SHOPS = {
    (5, 3): (6, "FARMACIA", (30, 120, 70), (236, 250, 236), "shutter"),
    (18, 3): (6, "ABBIGLIAMENTO", (60, 40, 90), (236, 226, 240), "smashed"),
    (24, 3): (3, "PANIFICIO", (150, 100, 50), (250, 236, 200), "boards"),
}



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


# ------------------------------------------------------------------ floors


def paint_floor(d, rng, x, y):
    """Big glossy tiles, a streak of reflected light, grime."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, FLOOR_A if (x + y) % 2 else FLOOR_B)
    rect(d, px, py, TILE, 1, FLOOR_JOINT)
    rect(d, px, py, 1, TILE, FLOOR_JOINT)
    rect(d, px + 3, py + 3, 5, 1, FLOOR_SHINE)
    rect(d, px + 3, py + 4, 2, 1, FLOOR_SHINE)
    for _ in range(3):
        rect(d, px + rng.randrange(16), py + rng.randrange(16), 1, 1, (130, 126, 118))
    if rng.random() < 0.12:
        cx, cy = px + rng.randrange(2, 12), py + rng.randrange(2, 12)
        for i in range(5):
            rect(d, cx + i, cy + (i % 3), 1, 1, FLOOR_JOINT)


def paint_shop_floor(d, rng, x, y):
    """The floor of a shop: boards, spilled goods. The one vertical joint
    it has is not here, it falls at (x * 5) % 12 -- see paint_shop_joint --
    which is a pattern on the column, not a throw of the dice."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, SHOP_FLOOR)
    for j in range(0, 16, 4):
        rect(d, px, py + j, TILE, 1, SHOP_FLOOR_JOINT)
    if rng.random() < 0.4:  # spilled goods
        rect(d, px + rng.randrange(12), py + rng.randrange(12), 3, 2,
             rng.choice(((200, 60, 40), (230, 200, 70), (90, 150, 70))))


def paint_shop_joint(d, offset):
    """The vertical joint of a shop's boards, `offset` pixels in."""
    rect(d, offset, 0, 1, TILE, SHOP_FLOOR_JOINT)


def paint_service_floor(d, rng, x, y):
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, SERVICE_A if (x * 3 + y) % 4 else SERVICE_B)
    for _ in range(5):
        rect(d, px + rng.randrange(16), py + rng.randrange(16), 1, 1, (60, 60, 64))
    if rng.random() < 0.3:  # oil and worse
        rect(d, px + rng.randrange(8), py + rng.randrange(10), 6, 3, (50, 44, 44))
    if rng.random() < 0.15:
        rect(d, px + rng.randrange(10), py + rng.randrange(10), 4, 3, BLOOD_DARK)


def paint_litter(d, rng, px, py):
    for _ in range(4):
        rect(d, px + rng.randrange(13), py + rng.randrange(13), rng.randint(2, 4), 2,
             rng.choice(((230, 226, 210), (200, 60, 50), (70, 120, 170), (210, 180, 60))))
    rect(d, px + rng.randrange(11), py + rng.randrange(11), 3, 2, (150, 150, 156))  # a can


def paint_blood(d, rng, px, py):
    rect(d, px + 3, py + 5, 9, 6, BLOOD)
    rect(d, px + 5, py + 3, 5, 10, BLOOD)
    rect(d, px + 6, py + 6, 3, 3, BLOOD_DARK)
    for _ in range(4):
        rect(d, px + rng.randrange(16), py + rng.randrange(16), 1, 1, BLOOD)


# ------------------------------------------------------------------- walls


def paint_wall_face(d, top, skirting):
    """A cell of the back wall: the pale face, the dark ceiling edge if
    this is the top course, the skirting if it is the bottom one."""
    rect(d, 0, 0, TILE, TILE, WALL_FACE)
    if top:
        rect(d, 0, 0, TILE, 4, WALL_TOP)
        rect(d, 0, 4, TILE, 1, (90, 90, 96))
    if skirting:
        rect(d, 0, 13, TILE, 3, WALL_FACE_DARK)


def paint_shopfront(d, shop, courses, rng):
    """One shopfront over a wall of `courses` rows, at the origin of `d`:
    sign board with its name over a glass front, a pulled-down shutter,
    smashed displays or boards."""
    w, name, board, letters, front = shop
    px, py0 = 0, 5
    width, height = w * TILE, courses * TILE - 5
    rect(d, px + 1, py0, width - 2, height - 3, OUTLINE)
    rect(d, px + 2, py0 + 1, width - 4, 9, board)
    paint_text(d, px + (width - text_width(name)) // 2, py0 + 3, name, letters,
               missing=(len(name) // 3,) if front == "smashed" else ())
    fy, fh = py0 + 11, height - 15
    if front == "glass":
        rect(d, px + 2, fy, width - 4, fh, GLASS)
        for gx in range(px + 4, px + width - 6, 12):
            rect(d, gx, fy + 2, 2, fh - 6, GLASS_SHINE)
        rect(d, px + width // 2 - 1, fy, 2, fh, METAL_DARK)
    elif front == "shutter":
        rect(d, px + 2, fy, width - 4, fh, METAL)
        for sy in range(fy, fy + fh, 2):
            rect(d, px + 2, sy, width - 4, 1, METAL_DARK)
        rect(d, px + width // 3, fy + fh - 5, 6, 5, (30, 30, 34))  # forced up
    elif front == "smashed":
        paint_smashed_display(d, px + 2, fy, width - 4, fh)
    else:
        rect(d, px + 2, fy, width - 4, fh, (24, 22, 24))
        paint_boards(d, px + 3, fy + 1, width - 6, fh - 2)
    for _ in range(3):  # soot and scratches
        rect(d, px + rng.randrange(2, width - 6), py0 + rng.randrange(0, 8),
             rng.randint(3, 6), 1, (60, 56, 56))


def paint_exit(d, x, y):
    """The fire exit through the back wall of the upper area, drawn like
    the barracks' back door so it reads as open and walkable: the reveal
    cut through the wall, grey daylight from the car park beyond, the leaf
    swung back against the jamb, the green sign over it."""
    px, py = x * TILE, y * TILE
    rect(d, px, py - 14, TILE, 30, WALL_TOP)
    rect(d, px + 2, py - 12, 12, 28, (70, 90, 110))
    rect(d, px + 4, py - 8, 8, 24, (150, 170, 186))
    rect(d, px + 5, py - 4, 6, 20, (190, 204, 214))
    rect(d, px + 2, py - 12, 3, 28, (128, 96, 60))  # open leaf
    rect(d, px + 3, py + 2, 1, 2, (220, 190, 90))  # its push bar
    rect(d, px + 3, py - 19, 10, 5, (30, 120, 60))  # exit sign
    rect(d, px + 5, py - 18, 6, 3, (200, 250, 210))
    rect(d, px + 6, py - 17, 3, 1, (30, 120, 60))


def paint_partition(d, room, x, y):
    """Side wall of Luigi's shop: dark top, a pale edge facing the room."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, WALL_TOP)
    rect(d, px + 3, py, 10, TILE, (70, 72, 80))
    if room.at(x, y + 1) not in "I":
        rect(d, px, py + 6, TILE, 10, WALL_FACE)
        rect(d, px, py + 13, TILE, 3, WALL_FACE_DARK)


def paint_shelves(d, rng, x, y):
    """Back of the grocery: shelves still half full."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, (92, 74, 56))
    for sy in (py + 3, py + 8, py + 13):
        rect(d, px, sy, TILE, 1, (60, 46, 34))
        for gx in range(px + 1, px + 15, 3):
            if rng.random() < 0.6:
                rect(d, gx, sy - 3, 2, 3, rng.choice(
                    ((200, 60, 40), (230, 200, 70), (90, 150, 70), (220, 220, 210), (70, 110, 170))))


def paint_grocery_sign(d, tiles):
    """ALIMENTARI across the top of Luigi's shop, a sprite `tiles` wide and
    one tile high hung one row above the shelves."""
    w = tiles * TILE
    rect(d, 2, 1, w - 4, 10, OUTLINE)
    rect(d, 3, 2, w - 6, 8, (40, 96, 52))
    paint_text(d, (w - text_width("ALIMENTARI")) // 2, 3, "ALIMENTARI",
               (232, 232, 220), missing=(6,))


def paint_front_wall(d, room, x, y, railing):
    """The ground floor's glass front, or the first floor's balustrade over
    the atrium."""
    px, py = x * TILE, y * TILE
    if railing:
        rect(d, px, py, TILE, TILE, (20, 22, 28))  # the drop into the atrium
        rect(d, px, py + 2, TILE, 8, (70, 90, 110))  # glass panel
        rect(d, px + 2, py + 3, 2, 6, GLASS_SHINE)
        rect(d, px, py + 1, TILE, 2, METAL_LIGHT)  # handrail
        rect(d, px + (0 if x % 2 else 15), py + 1, 1, 10, METAL_DARK)
        if (x * 7) % 11 == 0:  # a cracked pane
            rect(d, px + 8, py + 3, 1, 6, (20, 22, 28))
            rect(d, px + 6, py + 6, 5, 1, (20, 22, 28))
        return
    rect(d, px, py, TILE, TILE, WALL_TOP)
    rect(d, px, py + 3, TILE, 10, (60, 80, 100))
    rect(d, px + 3, py + 4, 2, 8, GLASS_SHINE)
    rect(d, px + (0 if x % 2 else 15), py + 3, 1, 10, METAL_DARK)


def paint_entrance(d, x, y, first, last):
    """The automatic doors stuck open: daylight on a doormat, the glass
    panels slid aside."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, (196, 190, 170))
    rect(d, px, py + 4, TILE, 10, (70, 62, 56))  # doormat
    rect(d, px, py + 4, TILE, 1, (96, 86, 76))
    if first:
        rect(d, px, py, 4, TILE, (70, 90, 110))
        rect(d, px + 1, py + 2, 1, 10, GLASS_SHINE)
    if last:
        rect(d, px + 12, py, 4, TILE, (70, 90, 110))
        rect(d, px + 13, py + 2, 1, 10, GLASS_SHINE)


def paint_stairs(d, room, x, y):
    """Stairs climbing into the back wall, darker towards the top, with a
    handrail at each side of the flight."""
    px, py = x * TILE, y * TILE
    top = room.at(x, y - 1) not in "UD"
    base = (120, 118, 112) if top else (150, 148, 140)
    rect(d, px, py, TILE, TILE, base)
    for sy in range(py + 1, py + 16, 4):
        rect(d, px, sy, TILE, 1, (86, 84, 80) if top else (110, 108, 102))
        rect(d, px, sy + 1, TILE, 1, (170, 168, 160) if not top else (136, 134, 128))
    if top:
        rect(d, px, py, TILE, 3, (40, 40, 44))
    if room.at(x - 1, y) not in "UD":
        rect(d, px, py, 2, TILE, METAL_LIGHT)
    if room.at(x + 1, y) not in "UD":
        rect(d, px + 14, py, 2, TILE, METAL_LIGHT)


def paint_service_wall(d, tiles, rng):
    """Beyond the gate: bare grey wall with pipes and a stencilled notice,
    a sprite `tiles` = (columns, rows) big."""
    w, h = tiles[0] * TILE, tiles[1] * TILE
    px, py = 0, 0
    rect(d, px, py, w, h, (104, 104, 108))
    rect(d, px, py, w, 4, WALL_TOP)
    rect(d, px, py + 9, w, 2, (84, 80, 70))  # pipe
    rect(d, px, py + h - 3, w, 3, (80, 80, 84))
    paint_text(d, px + 4, py + 14, "PERSONALE", (190, 160, 50))
    for _ in range(6):
        rect(d, px + rng.randrange(w - 4), py + rng.randrange(12, h - 4), 2,
             rng.randint(3, 8), (80, 78, 76))


def paint_panel(d, x, y):
    """The anti-theft control panel: a grey box with a red lamp and keys."""
    px, py = x * TILE, y * TILE
    rect(d, px + 2, py + 1, 12, 13, OUTLINE)
    rect(d, px + 3, py + 2, 10, 11, (150, 152, 156))
    rect(d, px + 4, py + 3, 5, 4, (30, 40, 34))  # display
    rect(d, px + 5, py + 4, 3, 1, (90, 200, 110))
    rect(d, px + 10, py + 3, 2, 2, (220, 40, 30))  # alarm lamp
    for kx in range(px + 4, px + 12, 3):
        rect(d, kx, py + 9, 2, 2, (80, 82, 88))
    rect(d, px + 7, py + 14, 2, 2, (40, 40, 44))  # cable


def paint_gate(d, room, x, y):
    """The service gate, forced open: posts at the ends, the folded grille
    against them, rails across the floor in between. The floor under a
    post is the service area's, painted by whoever paints that."""
    px, py = x * TILE, y * TILE
    glyph = room.at(x, y)
    if glyph == "G":
        rect(d, px + 5, py - 8, 6, 24, METAL_DARK)
        rect(d, px + 6, py - 8, 2, 24, METAL_LIGHT)
        for i in range(0, 12, 3):  # the grille folded up against it
            rect(d, px + i + 1, py - 4, 1, 18, METAL)
    else:
        rect(d, px + 6, py, 1, TILE, (60, 60, 64))  # floor rail
        rect(d, px + 9, py, 1, TILE, (60, 60, 64))
    if y > 0 and room.at(x, y - 1) in "WQ":  # the gate's lintel
        rect(d, px, py - 16, TILE, 4, METAL_DARK)


def paint_planter(d, rng, px, py):
    rect(d, px + 1, py + 13, 15, 2, (30, 30, 34))
    rect(d, px + 1, py + 5, 14, 9, (110, 108, 104))
    rect(d, px + 2, py + 6, 12, 4, (60, 46, 36))
    rect(d, px + 1, py + 11, 14, 2, (90, 88, 84))
    for i in range(6):  # a dead ficus
        rect(d, px + 5 + (i * 3) % 7, py - 6 + i, 3, 2, (110, 100, 60) if i % 2 else (80, 96, 54))
    rect(d, px + 7, py - 2, 2, 9, (80, 60, 44))


def paint_kiosk(d, px, py, first, last):
    """A phone-accessories kiosk: counter with a coloured top."""
    rect(d, px, py + 13, TILE, 2, (30, 30, 34))
    rect(d, px, py + 4, TILE, 10, (190, 186, 176))
    rect(d, px, py + 2, TILE, 3, (200, 70, 50))
    rect(d, px, py + 9, TILE, 1, (150, 146, 138))
    if first:
        rect(d, px, py + 2, 1, 12, OUTLINE)
    if last:
        rect(d, px + 15, py + 2, 1, 12, OUTLINE)
    rect(d, px + 5, py + 5, 4, 3, (40, 40, 44))  # a smashed phone display


def paint_long_bench(d, px, py, first, last):
    wood, dark = (130, 96, 60), (92, 66, 42)
    rect(d, px, py + 14, TILE, 2, (30, 30, 34))
    rect(d, px, py + 6, TILE, 3, wood)
    rect(d, px, py + 9, TILE, 1, dark)
    if first or last:
        lx = px + 2 if first else px + 12
        rect(d, lx, py + 9, 2, 6, METAL_DARK)


def paint_side_edges(d, room):
    """A dark line where the floor meets the darkness at the sides."""
    for y in range(room.height):
        for x in range(room.width):
            if room.is_wall(x, y) or room.at(x, y) == "x":
                continue
            px, py = x * TILE, y * TILE
            if room.at(x - 1, y) == "x":
                rect(d, px, py, 2, TILE, (40, 40, 46))
            if room.at(x + 1, y) == "x":
                rect(d, px + 14, py, 2, TILE, (40, 40, 46))

