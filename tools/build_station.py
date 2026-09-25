#!/usr/bin/env python3
"""Bake the three places of the station.

Reads the `station-rows`, `underpass-rows` and `far-platform-rows` blocks
of lib/core/levels/tutorial/station.dart and paints them in the barracks'
style, rooms floating on black: the booking hall and its platform, the
tiled underpass under the tracks, and the far platform with the one train
still in one piece. Over the platforms the roof is gone, so the game lights
those two throughout and only darkens the underpass.

The two railcars are painted as one piece over the whole run of their
glyph rather than tile by tile: `M` the one standing on the rails, `m` the
coach that went over on its side.

Run from the repository root:  python tools/build_station.py
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
    TILE,
    read_rows,
    rect,
    shade,
)

STATION_OUTPUT = os.path.join("assets", "levels", "station.png")
UNDERPASS_OUTPUT = os.path.join("assets", "levels", "station_underpass.png")

VOID = (6, 6, 8)
HALL_A = (172, 162, 146)
HALL_B = (160, 150, 136)
HALL_JOINT = (128, 120, 110)
PLATFORM = (150, 146, 138)
PLATFORM_ALT = (140, 136, 128)
PLATFORM_JOINT = (112, 108, 102)
SAFETY = (198, 168, 62)
BALLAST = [(104, 100, 94), (88, 84, 80), (120, 114, 106), (74, 72, 70)]
SLEEPER = (82, 66, 48)
SLEEPER_DARK = (58, 46, 34)
RAIL = (150, 148, 150)
RAIL_RUST = (128, 88, 58)
WALL_TOP = (44, 44, 48)
WALL_FACE = (206, 196, 176)
WALL_DARK = (166, 158, 142)
TRIM = (230, 222, 202)
METAL = (120, 124, 132)
METAL_DARK = (70, 74, 82)
METAL_LIGHT = (176, 180, 188)
GLASS = (46, 58, 72)
GLASS_BROKEN = (16, 16, 20)
RUBBLE = [(146, 140, 128), (118, 112, 104), (170, 162, 148), (92, 88, 84)]
GRIME = (96, 92, 78)
WEED = [(74, 94, 52), (92, 112, 60), (58, 78, 46)]
# The regional livery of the picture: green and white with a blue band and
# a red front, filthy either way.
LIVERY_GREEN = (86, 132, 92)
LIVERY_WHITE = (206, 202, 192)
LIVERY_BLUE = (52, 76, 128)
LIVERY_RED = (150, 52, 46)
TILE_WALL = (198, 198, 190)
TILE_WALL_DARK = (156, 156, 150)
TILE_GROUT = (120, 122, 120)


def block(room, glyph):
    """The rectangle the run of `glyph` fills, in pixels, or None."""
    cells = [(x, y) for y in range(room.height) for x in range(room.width)
             if room.at(x, y) == glyph]
    if not cells:
        return None
    x0 = min(x for x, _ in cells)
    x1 = max(x for x, _ in cells)
    y0 = min(y for _, y in cells)
    y1 = max(y for _, y in cells)
    return x0 * TILE, y0 * TILE, (x1 - x0 + 1) * TILE, (y1 - y0 + 1) * TILE


# ------------------------------------------------------------------ ground


def paint_hall(d, rng, x, y):
    """The booking hall's terrazzo, laid in big squares, grimy."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, HALL_A if (x + y) % 2 else HALL_B)
    rect(d, px, py, TILE, 1, HALL_JOINT)
    rect(d, px, py, 1, TILE, HALL_JOINT)
    for _ in range(5):  # the chips of marble in it
        rect(d, px + rng.randrange(15), py + rng.randrange(15), 2, 1,
             rng.choice(((190, 182, 168), (126, 120, 112), (150, 136, 112))))
    if rng.random() < 0.2:
        rect(d, px + rng.randrange(2, 11), py + rng.randrange(2, 11),
             rng.randint(3, 5), 1, (110, 104, 96))


def paint_platform(d, rng, x, y, edge):
    """The platform: cast slabs, and along the row `edge`, the one over the
    track, the drop to the ballast, the yellow line and the tactile studs
    inside it."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, PLATFORM if (x + y) % 2 else PLATFORM_ALT)
    rect(d, px, py, TILE, 1, PLATFORM_JOINT)
    rect(d, px, py, 1, TILE, PLATFORM_JOINT)
    for _ in range(3):
        rect(d, px + rng.randrange(15), py + rng.randrange(15), 1, 1, GRIME)
    if y != edge:
        return
    rect(d, px, py, TILE, 3, shade(PLATFORM, -34))
    rect(d, px, py + 3, TILE, 2, SAFETY)
    for sx in range(px + 1, px + TILE, 5):
        rect(d, sx, py + 7, 2, 2, shade(PLATFORM, -18))
    for _ in range(2):  # the paint worn off it
        rect(d, px + rng.randrange(13), py + 3, rng.randint(2, 4), 2,
             shade(PLATFORM, -10))


def paint_ballast(d, rng, px, py):
    """Track bed: stone chippings, oil and the weeds coming up through."""
    rect(d, px, py, TILE, TILE, BALLAST[1])
    for _ in range(26):
        rect(d, px + rng.randrange(15), py + rng.randrange(15),
             rng.randint(1, 2), rng.randint(1, 2), rng.choice(BALLAST))
    if rng.random() < 0.3:
        wx, wy = px + rng.randrange(3, 12), py + rng.randrange(4, 12)
        colour = rng.choice(WEED)
        for i in range(4):
            rect(d, wx + i - 1, wy - abs(i - 2), 1, 3 + (i % 2), colour)


def paint_rails(d, rng, room, x, y):
    """A length of track: sleepers across the ballast and the two rails on
    them, the heads of them still bright, everything else rusted."""
    px, py = x * TILE, y * TILE
    paint_ballast(d, rng, px, py)
    for sx in range(px, px + TILE, 8):  # the sleepers
        rect(d, sx, py + 1, 6, 14, SLEEPER)
        rect(d, sx, py + 1, 6, 2, shade(SLEEPER, 20))
        rect(d, sx, py + 13, 6, 2, SLEEPER_DARK)
    for ry in (py + 3, py + 10):  # the two rails
        rect(d, px, ry, TILE, 3, RAIL_RUST)
        rect(d, px, ry, TILE, 1, RAIL)
        rect(d, px, ry + 3, TILE, 1, shade(RAIL_RUST, -30))
    if room.at(x - 1, y) not in "-":  # rusted through where the run ends
        rect(d, px, py + 3, 4, 3, shade(RAIL_RUST, -20))


def paint_litter(d, rng, px, py):
    """Ticket stubs, smashed departure screens, bottles."""
    for _ in range(3):
        rect(d, px + rng.randrange(11), py + rng.randrange(11),
             rng.randint(3, 5), rng.randint(1, 2), rng.choice(RUBBLE))
    for _ in range(6):
        rect(d, px + rng.randrange(15), py + rng.randrange(15),
             rng.randint(1, 3), 1, rng.choice(RUBBLE))


def paint_rubble(d, rng, room, x, y):
    """Where the hall's roof and the canopy over it came down, `#`: a heap
    of slab, girder and tile too deep to climb, lit by nothing."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, (58, 56, 54))
    for _ in range(14):
        rect(d, px + rng.randrange(14), py + rng.randrange(14),
             rng.randint(2, 5), rng.randint(2, 4), rng.choice(RUBBLE))
    for _ in range(4):  # the reinforcement out of the broken slab
        bx, by = px + rng.randrange(12), py + rng.randrange(12)
        rect(d, bx, by, rng.randint(4, 6), 1, (112, 78, 52))
    if (x * 5 + y * 3) % 7 == 0:  # a girder out of the heap
        rect(d, px + 1, py + 4, 14, 3, METAL_DARK)
        rect(d, px + 1, py + 4, 14, 1, METAL)
    # a dark lip where the heap meets what can still be walked on
    for dx, dy, ex, ey, w, h in ((-1, 0, 0, 0, 2, TILE), (1, 0, 14, 0, 2, TILE),
                                 (0, -1, 0, 0, TILE, 2), (0, 1, 0, 14, TILE, 2)):
        if room.at(x + dx, y + dy) not in "#x":
            rect(d, px + ex, py + ey, w, h, (34, 32, 32))


# ------------------------------------------------------------------- walls


def paint_back_wall(d, rng, room, x, y):
    """The station's walls seen from inside, `W`: rendered brick with a
    dado rail, blistered and tagged."""
    px, py = x * TILE, y * TILE
    top = room.at(x, y - 1) != "W"
    rect(d, px, py, TILE, TILE, WALL_FACE)
    if top:
        rect(d, px, py, TILE, 5, WALL_TOP)
        rect(d, px, py + 5, TILE, 2, TRIM)
    for _ in range(4):
        rect(d, px + rng.randrange(13), py + rng.randrange(8, 16),
             rng.randint(2, 5), rng.randint(1, 3), WALL_DARK)
    if not top:
        rect(d, px, py + 9, TILE, 1, WALL_DARK)  # the dado rail
    if (x * 7 + y * 5) % 9 == 0 and not top:
        rect(d, px + 2, py + 11, 11, 3, rng.choice(
            ((140, 60, 70), (60, 90, 130), (150, 130, 60))))


def paint_front_wall(d, rng, x, y):
    """The facade seen from inside, `w`: the same render, with the arched
    windows of the front in it, their glass gone."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, WALL_TOP)
    rect(d, px, py + 3, TILE, 11, WALL_FACE)
    rect(d, px, py + 3, TILE, 1, TRIM)
    if (x * 5) % 6 == 0:
        rect(d, px + 3, py + 5, 10, 8, GLASS_BROKEN)
        rect(d, px + 3, py + 5, 10, 1, TRIM)
        rect(d, px + 4, py + 6, 3, 3, GLASS)
        if rng.random() < 0.5:
            rect(d, px + 3, py + 8, 10, 2, (116, 88, 56))  # boarded


def paint_doorway(d, px, py, first):
    """One cell of a doorway onto the forecourt, the daylight coming in;
    the leaf of the door is folded back against the jamb it hangs on."""
    rect(d, px, py, TILE, TILE, (48, 46, 44))
    rect(d, px + 2, py + 2, 12, TILE - 2, (186, 180, 164))
    rect(d, px + 2, py + 2, 12, 3, (216, 210, 196))
    rect(d, px, py, 2, TILE, METAL_DARK)
    rect(d, px + 14, py, 2, TILE, METAL_DARK)
    if first:
        rect(d, px + 2, py + 2, 3, TILE - 4, METAL)
        rect(d, px + 3, py + 3, 1, TILE - 6, METAL_LIGHT)


def paint_stairs(d, room, x, y):
    """The head of a flight, `U` or `D`: a dark well behind its handrails,
    the top steps catching what light there is, and the green plate with
    the arrow down that every station in the country has over it."""
    px, py = x * TILE, y * TILE
    glyph = room.at(x, y)
    first = room.at(x - 1, y) != glyph
    last = room.at(x + 1, y) != glyph
    rect(d, px, py, TILE, TILE, (26, 26, 30))
    for i, sy in enumerate(range(py + 5, py + 14, 4)):  # the top few steps
        step = shade((150, 146, 138), -22 * i)
        rect(d, px, sy, TILE, 3, step)
        rect(d, px, sy + 3, TILE, 1, (38, 38, 42))
    rect(d, px, py, TILE, 4, (40, 62, 48))  # the sign over the well
    rect(d, px, py, TILE, 1, (78, 106, 84))
    if first:  # the arrow down, one half of it per cell
        for i in range(4):
            rect(d, px + 9 + i, py + 1, 1, 1 + i, (232, 232, 220))
    elif last:
        for i in range(4):
            rect(d, px + 3 - i, py + 1, 1, 1 + (3 - i), (232, 232, 220))
    for side, there in ((0, first), (TILE - 2, last)):
        if there:
            rect(d, px + side, py + 4, 2, TILE - 4, METAL_DARK)
            rect(d, px + side, py + 4, 2, 2, METAL_LIGHT)


# -------------------------------------------------------------------- props


def paint_bench(d, room, x, y):
    """A platform bench, `T`: slatted, its back to the building."""
    px, py = x * TILE, y * TILE
    rect(d, px, py + 12, TILE, 2, (40, 40, 44))  # its shadow
    rect(d, px, py + 3, TILE, 3, METAL_DARK)  # the back
    rect(d, px, py + 7, TILE, 5, (128, 96, 58))  # the slats
    rect(d, px, py + 9, TILE, 1, (92, 68, 42))
    rect(d, px, py + 7, TILE, 1, (154, 118, 74))
    for edge, there in ((0, room.at(x - 1, y) != "T"),
                        (TILE - 2, room.at(x + 1, y) != "T")):
        if there:
            rect(d, px + edge, py + 3, 2, 10, METAL_DARK)


def paint_ticket_window(d, px, py):
    """A ticket window, `K`: the counter under its grille, the glass
    starred where someone went at it."""
    rect(d, px, py + 1, TILE, 13, METAL_DARK)
    rect(d, px + 1, py + 2, 14, 7, GLASS)
    for bx in range(px + 2, px + 15, 3):  # the grille over it
        rect(d, bx, py + 2, 1, 7, METAL)
    rect(d, px + 5, py + 4, 5, 4, GLASS_BROKEN)
    rect(d, px + 1, py + 10, 14, 4, (140, 132, 118))  # the counter shelf
    rect(d, px + 1, py + 10, 14, 1, (180, 172, 156))


def paint_post(d, room, x, y):
    """A post of the platform canopy, `n`, with the rusted stub of the
    beam it used to carry."""
    px, py = x * TILE, y * TILE
    rect(d, px + 4, py + 13, 8, 2, (40, 40, 44))
    rect(d, px + 5, py, 6, 14, METAL)
    rect(d, px + 5, py, 2, 14, METAL_LIGHT)
    rect(d, px + 10, py, 1, 14, METAL_DARK)
    rect(d, px + 3, py, 10, 3, METAL_DARK)
    if room.at(x + 1, y) == "n":  # what is left of the beam between two
        rect(d, px + 10, py, TILE, 3, METAL_DARK)
    for i in range(3):
        rect(d, px + 5, py + 3 + i * 5, 6, 1, RAIL_RUST)


# ------------------------------------------------------------------- trains


def _grime(d, rng, px, py, w, h, amount):
    """Years of rain down a train's flank: streaks of soot and iron dust,
    heavier towards the bottom of it."""
    for _ in range(amount):
        gx = px + rng.randrange(max(1, w - 4))
        gy = py + rng.randrange(max(1, h - 6))
        rect(d, gx, gy, rng.randint(1, 2), rng.randint(3, 9),
             rng.choice(((166, 160, 146), (146, 140, 126), (176, 170, 156),
                         (154, 144, 124))))
    for _ in range(amount // 2):  # and the worst of it along the skirt
        gx = px + rng.randrange(max(1, w - 6))
        rect(d, gx, py + h - rng.randint(4, 9), rng.randint(3, 7),
             rng.randint(2, 5), rng.choice(((136, 128, 112), (118, 112, 100))))


def paint_railcar(d, rng, area, wrecked, door_x=None, open_door=False):
    """The railcar on the rails, `M`, side on: the roof with its vents, the
    body in the regional livery under years of grime, the windows, the
    skirt and the bogies, its cab at the west end where it is met. Derailed
    it is stove in and burnt out; whole it is only filthy."""
    px, py, w, h = area
    body, cab = py + 9, 22
    rect(d, px, py + h - 5, w, 5, (30, 30, 34))  # its shadow on the ballast
    rect(d, px, py, w, 10, shade(LIVERY_GREEN, -38))  # the roof
    rect(d, px, py, w, 2, shade(LIVERY_GREEN, -14))
    for vx in range(px + cab + 8, px + w - 12, 38):  # the roof vents
        rect(d, vx, py + 3, 14, 5, METAL_DARK)
        rect(d, vx + 1, py + 4, 12, 2, METAL)
    rect(d, px, body, w, h - 21, LIVERY_WHITE)  # the body
    rect(d, px, body, w, 7, LIVERY_GREEN)
    rect(d, px, py + h - 17, w, 5, LIVERY_BLUE)
    for wx in range(px + cab + 4, px + w - 14, 24):  # the windows
        rect(d, wx, body + 8, 17, 12, METAL_DARK)
        rect(d, wx + 1, body + 9, 15, 10,
             GLASS_BROKEN if rng.random() < (0.75 if wrecked else 0.3)
             else GLASS)
        rect(d, wx + 1, body + 9, 15, 2, shade(GLASS, 26))
    rect(d, px, py + h - 12, w, 6, shade(LIVERY_WHITE, -64))  # the skirt
    for bx in (px + cab + 4, px + w - 48):  # the bogies under it
        rect(d, bx, py + h - 9, 38, 7, METAL_DARK)
        for ox in (bx + 3, bx + 26):
            rect(d, ox, py + h - 11, 10, 10, (26, 26, 28))
            rect(d, ox + 3, py + h - 8, 4, 4, (86, 86, 90))
    # the cab, at the west end: the red front, the windscreen over it
    rect(d, px, py, cab, 10, shade(LIVERY_RED, -46))
    rect(d, px, body, cab, h - 21, LIVERY_RED)
    rect(d, px + 3, body + 6, 15, 11, METAL_DARK)
    rect(d, px + 4, body + 7, 13, 9, GLASS_BROKEN if wrecked else GLASS)
    rect(d, px, py + h - 12, cab, 6, shade(LIVERY_RED, -60))
    _grime(d, rng, px, body, w, h - 21, w // 3)
    if not wrecked:
        if door_x is not None:
            paint_passenger_door(
                d, door_x, body + 3, py + h - 5, open_door)
        return
    # Derailed: the cab end slewed off the rails and burnt out, the body
    # buckled behind it and split along the waist.
    rect(d, px, py, cab + 12, h - 12, (54, 44, 40))
    for _ in range(10):  # what the fire left of the cab
        sx, sy = px + rng.randrange(cab + 8), py + rng.randrange(h - 16)
        rect(d, sx, sy, rng.randint(4, 9), rng.randint(3, 6),
             rng.choice(((38, 34, 34), (68, 58, 52), (26, 24, 24))))
    for i in range(0, 26, 3):  # the split along the waist, torn open
        rect(d, px + cab + 10 + i, body + 4 + (i % 6), 4, 5, (32, 30, 30))
    for _ in range(w // 8):  # scorch running back down the whole flank
        sx, sy = px + rng.randrange(w - 10), py + rng.randrange(h - 14)
        rect(d, sx, sy, rng.randint(5, 10), rng.randint(3, 7), (56, 50, 46))


def paint_toppled_coach(d, rng, area):
    """The coach behind it, `m`: it went over on its side across the far
    track and lies flank up, so its whole side -- roof edge, livery band,
    the row of windows -- is what shows, with the underframe and the
    bogies heeled over towards the near track and the end torn open where
    it parted from the railcar."""
    px, py, w, h = area
    rect(d, px, py + h - 3, w, 3, (30, 30, 34))
    rect(d, px, py, w, 6, shade(LIVERY_GREEN, -52))  # the roof, edge on
    rect(d, px, py + 6, w, 6, shade(LIVERY_GREEN, -24))  # the livery band
    rect(d, px, py + 12, w, h - 26, shade(LIVERY_WHITE, -34))
    rect(d, px, py + h - 18, w, 4, shade(LIVERY_BLUE, -26))
    for wx in range(px + 8, px + w - 14, 24):  # the windows, all of them out
        rect(d, wx, py + 15, 17, 12, METAL_DARK)
        rect(d, wx + 1, py + 16, 15, 10, GLASS_BROKEN)
        rect(d, wx + 4, py + 18, 6, 3, (58, 56, 54))
    # the underframe it has rolled up on, its bogies clear of the ground
    rect(d, px, py + h - 14, w, 14, shade(LIVERY_WHITE, -92))
    rect(d, px, py + h - 14, w, 2, METAL_DARK)
    for cx in range(px + 4, px + w - 4, 11):  # the ribs of the floor pan
        rect(d, cx, py + h - 12, 3, 12, (54, 52, 50))
    for bx in (px + 10, px + w - 46):  # the bogies, wheels out sideways
        rect(d, bx, py + h - 12, 34, 10, METAL_DARK)
        for ox in (bx + 2, bx + 24):
            rect(d, ox, py + h - 13, 9, 12, (26, 26, 28))
            rect(d, ox + 2, py + h - 9, 5, 4, (92, 92, 96))
    for i in range(0, h - 6, 5):  # the end torn open on the dark inside
        rect(d, px, py + 2 + i, rng.randint(3, 9), 5, (30, 28, 28))
    _grime(d, rng, px, py + 6, w, h - 20, w // 2)
    for _ in range(w // 4):  # rust breaking out all over the wreck
        gx, gy = px + rng.randrange(w - 4), py + 4 + rng.randrange(h - 12)
        rect(d, gx, gy, rng.randint(2, 5), rng.randint(1, 3),
             rng.choice((RAIL_RUST, shade(RAIL_RUST, -30), (72, 68, 64))))


def paint_passenger_door(d, px, top, bottom, opened):
    """The usable passenger door, unmistakably shut or open.

    Open, the lit vestibule, yellow grab rails and steps projecting onto the
    platform make the entrance readable even at the game's native scale.
    """
    width = 18
    rect(d, px - 2, top - 2, width + 4, bottom - top + 5, METAL_DARK)
    if not opened:
        rect(d, px, top, width, bottom - top, shade(LIVERY_WHITE, -8))
        rect(d, px, top, width, 5, LIVERY_GREEN)
        rect(d, px + 3, top + 6, width - 6, 10, METAL_DARK)
        rect(d, px + 4, top + 7, width - 8, 8, GLASS)
        rect(d, px + width - 4, top + 18, 2, 6, METAL_LIGHT)
        rect(d, px, bottom - 6, width, 5, LIVERY_BLUE)
        return

    rect(d, px, top, width, bottom - top, (16, 18, 22))
    rect(d, px + 2, top + 2, width - 4, 4, (232, 218, 154))
    rect(d, px + 3, top + 7, width - 6, bottom - top - 9, (54, 58, 62))
    # High-contrast yellow handrails frame the black opening.
    for rail_x in (px + 1, px + width - 3):
        rect(d, rail_x, top + 5, 2, bottom - top - 3, SAFETY)
        rect(d, rail_x, top + 5, 3, 2, shade(SAFETY, 34))
    # Three bright-edged steps project onto the platform.
    for i, (inset, step_width) in enumerate(((1, 16), (3, 12), (5, 8))):
        y = bottom + i * 3
        rect(d, px + inset, y, step_width, 3, METAL_DARK)
        rect(d, px + inset + 1, y, step_width - 2, 1, METAL_LIGHT)


# ---------------------------------------------------------------- underpass


def paint_underpass_floor(d, rng, x, y):
    """Small floor tiles, most of them still down, wet."""
    px, py = x * TILE, y * TILE
    for i in range(2):
        for j in range(2):
            shade_of = (172, 170, 162) if (x * 2 + i + y * 2 + j) % 2 else (
                150, 148, 142)
            rect(d, px + i * 8, py + j * 8, 8, 8, shade_of)
            rect(d, px + i * 8, py + j * 8, 8, 1, TILE_GROUT)
            rect(d, px + i * 8, py + j * 8, 1, 8, TILE_GROUT)
    for _ in range(4):
        rect(d, px + rng.randrange(15), py + rng.randrange(15), 1, 1, GRIME)
    if rng.random() < 0.18:  # a tile lifted, the screed under it
        rect(d, px + (rng.randrange(2)) * 8, py + (rng.randrange(2)) * 8,
             8, 8, (104, 100, 94))


def paint_underpass_wall(d, rng, room, x, y):
    """The corridor's walls: glazed tile to head height over a dark plinth,
    the tiling cracked off in patches, pipes running the length of it."""
    px, py = x * TILE, y * TILE
    top = room.at(x, y - 1) != room.at(x, y)
    rect(d, px, py, TILE, TILE, TILE_WALL)
    if top:
        rect(d, px, py, TILE, 6, WALL_TOP)
        rect(d, px, py + 6, TILE, 2, TILE_WALL_DARK)
    for bx in range(px, px + TILE, 4):  # the courses of tile
        rect(d, bx, py + 8, 1, 8, TILE_GROUT)
    rect(d, px, py + 11, TILE, 1, TILE_GROUT)
    for _ in range(2):
        rect(d, px + rng.randrange(12), py + 8 + rng.randrange(7),
             rng.randint(3, 5), rng.randint(2, 4), TILE_WALL_DARK)
    if not top:
        rect(d, px, py + 9, TILE, 2, METAL_DARK)  # the pipe along it
        rect(d, px, py + 9, TILE, 1, METAL)


def paint_underpass_front(d, x, y):
    """The other wall of the corridor, `w`, seen over: plinth and tile."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, WALL_TOP)
    rect(d, px, py + 2, TILE, 10, TILE_WALL)
    rect(d, px, py + 2, TILE, 1, TILE_WALL_DARK)
    for bx in range(px, px + TILE, 4):
        rect(d, bx, py + 3, 1, 9, TILE_GROUT)
    rect(d, px, py + 12, TILE, 3, (52, 52, 56))


def paint_lamp(d, px, py, dead):
    """A strip light on the corridor's ceiling; the light itself is the
    game's, this is only the fitting."""
    rect(d, px + 2, py + 4, 12, 5, METAL_DARK)
    rect(d, px + 3, py + 5, 10, 3, (60, 60, 64) if dead else (236, 232, 200))
    rect(d, px + 2, py + 9, 12, 1, (40, 40, 44))


# --------------------------------------------------------------------- bake


def bake_platform(room: Room, rng, output, wrecked, open_door=False):
    """The station itself or its far side: hall, platform, track, trains.
    With `wrecked` the railcar is the derailed one."""
    image = Image.new("RGB", (room.width * TILE, room.height * TILE), VOID)
    d = ImageDraw.Draw(image)
    # The platform edge is its top row, whatever is scattered along it.
    edge = next(y for y in range(room.height)
                if any(room.at(x, y) == "=" for x in range(room.width)))
    for y in range(room.height):
        for x in range(room.width):
            glyph = room.at(x, y)
            px, py = x * TILE, y * TILE
            if glyph == "x":
                continue
            if glyph == "-":
                paint_rails(d, rng, room, x, y)
            elif glyph in ",Mm9":
                paint_ballast(d, rng, px, py)
            elif glyph in "=TKn" or (glyph == ":" and y <= edge + 2):
                paint_platform(d, rng, x, y, edge)
            elif glyph != "#" and not room.is_wall(x, y):
                paint_hall(d, rng, x, y)
    for y in range(room.height):
        for x in range(room.width):
            glyph = room.at(x, y)
            px, py = x * TILE, y * TILE
            if glyph == "W":
                paint_back_wall(d, rng, room, x, y)
            elif glyph == "w":
                paint_front_wall(d, rng, x, y)
            elif glyph == "#":
                paint_rubble(d, rng, room, x, y)
            elif glyph in "EO":
                paint_doorway(d, px, py, room.at(x - 1, y) != glyph)
            elif glyph in "UD":
                paint_stairs(d, room, x, y)
            elif glyph == ":":
                paint_litter(d, rng, px, py)
            elif glyph == "b":
                paint_blood(d, rng, px, py)
    coach = block(room, "m")
    if coach is not None:
        paint_toppled_coach(d, rng, coach)
    railcar = block(room, "M")
    if railcar is not None:
        door = block(room, "P")
        paint_railcar(
            d,
            rng,
            railcar,
            wrecked=wrecked,
            door_x=None if door is None else door[0],
            open_door=open_door,
        )
    paint_side_edges(d, room)
    for y in range(room.height):
        for x in range(room.width):
            glyph = room.at(x, y)
            px, py = x * TILE, y * TILE
            if glyph == "T":
                paint_bench(d, room, x, y)
            elif glyph == "K":
                paint_ticket_window(d, px, py)
            elif glyph == "n":
                paint_post(d, room, x, y)
    save(image, output)


def bake_underpass(room: Room, rng, output):
    image = Image.new("RGB", (room.width * TILE, room.height * TILE), VOID)
    d = ImageDraw.Draw(image)
    for y in range(room.height):
        for x in range(room.width):
            if not room.is_wall(x, y) and room.at(x, y) != "x":
                paint_underpass_floor(d, rng, x, y)
    for y in range(room.height):
        for x in range(room.width):
            glyph = room.at(x, y)
            px, py = x * TILE, y * TILE
            if glyph == "W":
                paint_underpass_wall(d, rng, room, x, y)
            elif glyph == "w":
                paint_underpass_front(d, x, y)
            elif glyph in "UD":
                paint_stairs(d, room, x, y)
            elif glyph == ":":
                paint_litter(d, rng, px, py)
            elif glyph == "b":
                paint_blood(d, rng, px, py)
            elif glyph in "*+":
                paint_lamp(d, px, py, dead=glyph == "+")
    paint_side_edges(d, room)
    save(image, output)


def save(image, output):
    os.makedirs(os.path.dirname(output), exist_ok=True)
    image.save(output, optimize=True)
    print(f"{output}: {image.size[0]}x{image.size[1]}")


def main() -> None:
    bake_platform(Room(read_rows("station-rows")), random.Random(1906),
                  STATION_OUTPUT, wrecked=True)
    bake_underpass(Room(read_rows("underpass-rows")), random.Random(1931),
                   UNDERPASS_OUTPUT)
    # The far platform is not baked any more: the game paints it from its
    # rows out of the tile atlas (tools/build_tile_atlas.py), which still
    # uses the painters above. The rest of this file stays for the station
    # and its underpass, which are not converted yet.


if __name__ == "__main__":
    main()
