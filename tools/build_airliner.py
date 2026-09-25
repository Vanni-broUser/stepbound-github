#!/usr/bin/env python3
"""The painters of the crashed airliner: the cabin, and the roofs its tail
came down on.

Neither is baked any more: the game paints both from their rows out of the
tile atlas (tools/build_tile_atlas.py), which uses the painters below.
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_street_level import TILE, rect, shade  # noqa: E402

VOID = (6, 6, 8)

# ------------------------------------------------------------------ cabin

CARPET = (58, 62, 74)
CARPET_ALT = (52, 56, 68)
RUNNER = (74, 78, 90)
LINING = (206, 204, 196)
LINING_LIGHT = (232, 230, 222)
LINING_DARK = (128, 128, 128)
BIN = (176, 176, 172)
BIN_EDGE = (108, 110, 114)
SEAT = (46, 62, 84)
SEAT_LIGHT = (72, 94, 122)
SEAT_DARK = (28, 38, 54)
HEADREST = (196, 192, 180)
TROLLEY = (150, 154, 158)
TROLLEY_DARK = (76, 80, 86)
PANEL = (178, 178, 172)
PANEL_DARK = (104, 104, 102)
BAG = (92, 66, 46)
BLOOD = (92, 14, 14)
BLOOD_DARK = (58, 10, 10)
LAMP = (242, 232, 190)
DAYLIGHT = (188, 198, 206)
SOOT = (26, 22, 22)


def cabin_floor(d, rng, x, y):
    """Cabin carpet, worn to the weave down the aisle."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, CARPET if (x + y) % 2 else CARPET_ALT)
    rect(d, px, py, TILE, 1, shade(CARPET, -14))
    for _ in range(3):
        rect(d, px + rng.randrange(15), py + rng.randrange(15), 1, 1,
             shade(CARPET, rng.randrange(-18, 20)))


def cabin_aisle(d, rng, room, x, y):
    """The runner down an aisle, edged where the seats begin."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, RUNNER)
    for side in (-1, 1):
        if "T" in room.rows[max(0, min(room.height - 1, y + side))]:
            rect(d, px, py if side < 0 else py + TILE - 1, TILE, 1,
                 shade(RUNNER, -26))
    for _ in range(2):
        rect(d, px + rng.randrange(15), py + 2 + rng.randrange(12), 1, 1,
             shade(RUNNER, -22))


def cabin_hull(d, room, x, y):
    """The hull seen from above: the lining, and under it the overhead
    lockers along both sides of the cabin."""
    px, py = x * TILE, y * TILE
    glyph = room.at(x, y)
    rect(d, px, py, TILE, TILE, LINING_DARK)
    if glyph == "W":  # the roof side, lockers hanging into the cabin
        rect(d, px, py + 2, TILE, 14, LINING)
        rect(d, px, py + 2, TILE, 2, LINING_LIGHT)
        rect(d, px, py + 10, TILE, 6, BIN)
        rect(d, px, py + 10, TILE, 1, BIN_EDGE)
        rect(d, px, py + 15, TILE, 1, BIN_EDGE)
        if x % 3 == 0:
            rect(d, px, py + 10, 1, 6, BIN_EDGE)
    elif glyph == "w":  # the belly side
        rect(d, px, py, TILE, 14, LINING)
        rect(d, px, py + 12, TILE, 2, LINING_LIGHT)
        rect(d, px, py, TILE, 6, BIN)
        rect(d, px, py + 5, TILE, 1, BIN_EDGE)
        if x % 3 == 0:
            rect(d, px, py, 1, 6, BIN_EDGE)
    else:  # `I`, the bulkheads closing the two ends of the map
        rect(d, px + 2, py, 12, TILE, LINING)
        rect(d, px + 5, py, 6, TILE, LINING_DARK)
        rect(d, px + 6, py, 1, TILE, LINING_LIGHT)


def cabin_break(d, px, py, roof):
    """A break in the hull, daylight and torn skin: the tear in the belly
    and, at the other end, the tail break."""
    rect(d, px, py, TILE, TILE, DAYLIGHT)
    top = py if roof else py + 9
    rect(d, px, top, TILE, 7, shade(DAYLIGHT, -46))
    for dx, w in ((0, 3), (5, 2), (9, 4), (14, 2)):
        rect(d, px + dx, py + (11 if roof else 0), w, 5, LINING_LIGHT)
    rect(d, px, py + (0 if roof else 15), TILE, 1, SOOT)


def cabin_seat(d, room, x, y):
    """One seat of a block, its headrest towards the front of the cabin
    (west), an armrest wherever the block ends."""
    px, py = x * TILE, y * TILE
    rect(d, px + 1, py + 1, 14, 14, SEAT_DARK)
    rect(d, px + 2, py + 2, 12, 12, SEAT)
    rect(d, px + 2, py + 2, 12, 1, SEAT_LIGHT)
    rect(d, px + 2, py + 3, 4, 10, HEADREST)
    rect(d, px + 2, py + 3, 1, 10, shade(HEADREST, -34))
    if room.at(x, y - 1) != "T":
        rect(d, px + 6, py + 1, 8, 2, shade(SEAT, 28))
    if room.at(x, y + 1) != "T":
        rect(d, px + 6, py + 13, 8, 2, SEAT_DARK)


def cabin_trolley(d, px, py):
    """A galley trolley on its side across the vestibule."""
    rect(d, px + 1, py + 3, 14, 10, TROLLEY_DARK)
    rect(d, px + 2, py + 4, 12, 7, TROLLEY)
    for sx in range(px + 3, px + 14, 4):
        rect(d, sx, py + 4, 1, 7, TROLLEY_DARK)
    rect(d, px + 2, py + 12, 3, 3, TROLLEY_DARK)
    rect(d, px + 11, py + 12, 3, 3, TROLLEY_DARK)


def cabin_litter(d, rng, px, py):
    """Panelling off the ceiling, and what came out of the lockers."""
    for _ in range(3):
        rect(d, px + rng.randrange(11), py + rng.randrange(11),
             rng.randint(3, 5), rng.randint(2, 4),
             shade(PANEL, rng.randrange(-30, 18)))
    rect(d, px + rng.randrange(9), py + rng.randrange(9), 4, 3, BAG)
    rect(d, px + rng.randrange(13), py + rng.randrange(13), 2, 1, PANEL_DARK)


def cabin_blood(d, rng, px, py):
    rect(d, px + 2, py + 3, 11, 9, BLOOD_DARK)
    rect(d, px + 4, py + 4, 8, 6, BLOOD)
    for _ in range(3):
        rect(d, px + rng.randrange(14), py + rng.randrange(14), 2, 1, BLOOD)


def cabin_lamp(d, px, py, steady):
    """An emergency light in the ceiling, and the pool it throws."""
    glow = LAMP if steady else shade(LAMP, -58)
    rect(d, px + 3, py + 4, 10, 7, shade(glow, -70))
    rect(d, px + 4, py + 5, 8, 5, glow)
    rect(d, px + 5, py + 6, 6, 3, shade(glow, 20))


# ------------------------------------------------------------------ roofs

TAR = (62, 60, 62)
TAR_ALT = (59, 57, 59)
TAR_LOW = (51, 50, 53)
TAR_LOW_ALT = (48, 47, 50)
GRAVEL = [(96, 92, 84), (78, 76, 72), (112, 106, 94), (68, 66, 64)]
COPING = (146, 140, 128)
COPING_DARK = (86, 82, 76)
COPING_SHADOW = (34, 33, 36)
BRICK = (118, 78, 62)
BRICK_DARK = (78, 50, 40)
STACK = (126, 96, 78)
STACK_DARK = (76, 56, 46)
POT = (66, 62, 60)
MAST = (150, 152, 156)
MAST_DARK = (72, 74, 80)
FAR_ROOF = (44, 44, 48)
FAR_ROOF_ALT = (40, 40, 44)
DROP = (16, 16, 20)
SCORCH = (28, 22, 20)
SCORCH_ASH = (58, 50, 46)
SCORCH_EMBER = (150, 52, 24)
DROP_LIGHT = (28, 28, 34)
HULL = (206, 204, 198)
HULL_LIGHT = (232, 230, 224)
HULL_SHADE = (148, 148, 146)
HULL_DARK = (86, 86, 88)
LIVERY = (46, 70, 108)


def lower(room, y):
    """True below the parapet that steps the terrace down."""
    step = next(i for i, row in enumerate(room.rows) if row.count("^") > 4)
    return y > step


def roof_deck(d, rng, room, x, y):
    px, py = x * TILE, y * TILE
    down = lower(room, y)
    base = (TAR_LOW, TAR_LOW_ALT) if down else (TAR, TAR_ALT)
    rect(d, px, py, TILE, TILE, base[y % 2])
    for _ in range(6):
        rect(d, px + rng.randrange(15), py + rng.randrange(15), 1, 1,
             shade(rng.choice(GRAVEL), -34))
    # the felt is laid in strips, their seams running east to west
    if y % 2 == 0:
        rect(d, px, py, TILE, 1, shade(base[0], -10))


def roof_rubble(d, rng, px, py):
    for _ in range(6):
        rect(d, px + rng.randrange(13), py + rng.randrange(13),
             rng.randint(2, 4), rng.randint(1, 3), rng.choice(GRAVEL))
    rect(d, px + rng.randrange(11), py + rng.randrange(11), 5, 2, COPING_DARK)


def roof_scorch(d, px, py):
    """Felt burnt down to the boards where the fuel is still alight; the
    flames themselves are drawn by the game."""
    rect(d, px, py, TILE, TILE, SCORCH)
    rect(d, px + 2, py + 3, 5, 2, SCORCH_ASH)
    rect(d, px + 9, py + 10, 4, 2, SCORCH_ASH)
    rect(d, px + 11, py + 4, 2, 1, SCORCH_EMBER)


def roof_blood(d, rng, px, py):
    rect(d, px + 3, py + 4, 10, 8, BLOOD_DARK)
    rect(d, px + 5, py + 5, 6, 5, BLOOD)
    for _ in range(3):
        rect(d, px + rng.randrange(14), py + rng.randrange(14), 2, 1, BLOOD)


def roof_wall(d, room, x, y):
    """A party wall between two blocks, too high to climb. A wall running
    east to west shows its face to the camera, so it gets the coping along
    its top and its shadow below; one running north to south, down the
    side of the map, shows only the top of it, so it is a single band of
    slabs with the light on the roof side -- otherwise every tile of it
    repeats a face nobody could see from here."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, BRICK_DARK)
    if room.at(x - 1, y) == "W" or room.at(x + 1, y) == "W":
        for sy in range(py + 1, py + TILE, 4):
            rect(d, px + 1, sy, 14, 3, BRICK)
        rect(d, px, py, TILE, 2, COPING)
        rect(d, px, py + TILE - 2, TILE, 2, COPING_SHADOW)
        return
    stone = shade(COPING, -34)
    roof_side = 1 if room.at(x + 1, y) not in "xW" else -1
    inner, outer = (px + 12, px) if roof_side > 0 else (px + 1, px + 13)
    rect(d, px + 1, py, 14, TILE, stone)
    for sy in range(py, py + TILE, 8):  # the joints between the slabs
        rect(d, px + 1, sy, 14, 1, shade(stone, -26))
    rect(d, inner, py, 3, TILE, shade(stone, 26))
    rect(d, outer, py, 2, TILE, COPING_SHADOW)
    # and the shadow it lays along the roof beside it
    rect(d, px + (15 if roof_side > 0 else 0), py, 1, TILE, COPING_SHADOW)


def roof_parapet(d, room, x, y, low):
    """The coping along a roof edge: full height along the step and the
    street front, knocked down to a course or two where `>` marks the
    stretch Mario looks over."""
    px, py = x * TILE, y * TILE
    top = py + (9 if low else 2)
    rect(d, px, py, TILE, TILE, TAR_LOW)
    rect(d, px, top, TILE, py + TILE - top - 2, BRICK)
    for sy in range(top + 1, py + TILE - 2, 4):
        rect(d, px, sy, TILE, 1, BRICK_DARK)
    rect(d, px, top, TILE, 2, COPING)
    rect(d, px, top + 2, TILE, 1, COPING_DARK)
    rect(d, px, py + TILE - 2, TILE, 2, COPING_SHADOW)
    if low:
        # What is left of the coping: a course of broken brick, the rubble
        # of the rest fallen back on the roof, and the ends of the courses
        # either side standing over it.
        for dx in range(0, TILE, 5):
            rect(d, px + dx, top - 2, 3, 2, BRICK_DARK)
        rect(d, px + 2, py + 3, 5, 3, COPING_DARK)
        rect(d, px + 9, py + 5, 5, 2, COPING_DARK)
        rect(d, px + 5, py + 7, 3, 2, COPING_DARK)
        for dx, side in ((0, room.at(x - 1, y)), (13, room.at(x + 1, y))):
            if side != ">":
                rect(d, px + dx, py + 1, 3, 9, COPING)
                rect(d, px + dx, py + 1, 3, 1, shade(COPING, 26))
                rect(d, px + dx, py + 9, 3, 1, COPING_SHADOW)


def roof_stack(d, rng, px, py):
    """A chimney stack with its pots."""
    rect(d, px + 2, py + 2, 12, 13, STACK_DARK)
    rect(d, px + 3, py + 3, 10, 10, STACK)
    for sy in range(py + 4, py + 13, 3):
        rect(d, px + 3, sy, 10, 1, STACK_DARK)
    for dx in (4, 9):
        rect(d, px + dx, py, 3, 4, POT)
        rect(d, px + dx, py, 3, 1, shade(POT, 30))
    rect(d, px + 2, py + 14, 12, 2, COPING_SHADOW)
    for _ in range(2):
        rect(d, px + 3 + rng.randrange(9), py + 4 + rng.randrange(8), 1, 1,
             SOOT)


def roof_mast(d, px, py):
    """A television aerial, leaning."""
    rect(d, px + 6, py + 1, 2, 14, MAST_DARK)
    rect(d, px + 7, py + 1, 1, 14, MAST)
    for sy in (py + 3, py + 6, py + 9):
        rect(d, px + 3, sy, 9, 1, MAST)
    rect(d, px + 4, py + 13, 7, 2, MAST_DARK)


def roof_drop(d, rng, x, y):
    """The street far below, between the two blocks: nothing to see but a
    long way down."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, DROP)
    for _ in range(2):
        rect(d, px + rng.randrange(14), py + rng.randrange(14),
             rng.randint(1, 3), 1, DROP_LIGHT)


def roof_far(d, rng, room, x, y):
    """The roof of the next block, across the gap: the same tar, flattened
    by the distance, with its own coping along the near edge."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, FAR_ROOF if (x + y) % 2 else FAR_ROOF_ALT)
    for _ in range(3):
        rect(d, px + rng.randrange(15), py + rng.randrange(15), 1, 1,
             shade(FAR_ROOF, rng.randrange(-8, 26)))
    if room.at(x, y - 1) != "%":
        rect(d, px, py, TILE, 3, shade(COPING, -54))
        rect(d, px, py, TILE, 1, shade(COPING, -20))


def roof_tail(d, room, x, y):
    """The tail of the airliner, come to rest in the roofline. It is two
    tiles deep, so the tube is shaded over both at once: the crown of it
    along the top row, the cabin windows, the livery and the shadow it
    throws on the roof along the bottom one."""
    px, py = x * TILE, y * TILE
    crown = room.at(x, y - 1) not in "#D"
    rect(d, px, py, TILE, TILE, HULL if crown else HULL_SHADE)
    if crown:
        rect(d, px, py, TILE, 5, HULL_LIGHT)
        rect(d, px, py + 5, TILE, 3, HULL)
        for dx in range(2, TILE, 6):
            rect(d, px + dx, py + 11, 3, 3, (28, 32, 40))
    else:
        rect(d, px, py, TILE, 6, HULL)
        rect(d, px, py + 6, TILE, 2, LIVERY)
        rect(d, px, py + 8, TILE, TILE - 10, HULL_SHADE)
        rect(d, px, py + TILE - 2, TILE, 2, HULL_DARK)
    # the seams between one barrel of the fuselage and the next
    if x % 4 == 0:
        rect(d, px, py, 1, TILE, shade(HULL_SHADE, -18))
    if room.at(x - 1, y) not in "#D":
        rect(d, px, py, 1, TILE, HULL_DARK)
    if room.at(x + 1, y) not in "#D":
        rect(d, px + TILE - 1, py, 1, TILE, HULL_DARK)


def roof_break(d, room, x, y):
    """Where the tail tore open: the way down into the cabin."""
    px, py = x * TILE, y * TILE
    if room.at(x, y - 1) in "#D":
        rect(d, px, py, TILE, TILE, HULL_SHADE)
        rect(d, px, py + 1, TILE, 13, (18, 18, 22))
        for dx, w in ((0, 3), (6, 2), (11, 4)):
            rect(d, px + dx, py, w, 4, HULL_LIGHT)
        rect(d, px, py + 14, TILE, 2, SOOT)
    else:
        roof_tail(d, room, x, y)
        rect(d, px, py + 9, TILE, 7, (18, 18, 22))
        for dx, w in ((2, 3), (8, 3)):
            rect(d, px + dx, py + 9, w, 3, HULL_LIGHT)
