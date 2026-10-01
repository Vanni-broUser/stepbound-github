"""The palazzo past the airliner in the tile atlas: its entrance hall and
the three floors of flats above it (lib/core/levels/hometown/palazzo.dart).

A module of its own, the way docs/level_pipeline.md wants the interiors to
go: build_tile_atlas.py only lists it. The rooms are drawn like the
hospital's, a Pokemon-Emerald room on a dark background, in the colours of
a Molfetta block of flats: oak parquet in the living rooms and bedrooms,
white and terracotta tiles in the kitchens, sky-blue tiles in the
bathrooms, and on the landings the pale marble of the stairwell. All of
it wrecked: plaster down off the ceilings, furniture smashed, blood, the
dead. What stands taller than its cell leans out over the row above
(`leaning`).
"""
from __future__ import annotations

import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import street_props as props  # noqa: E402
from street_paint import (  # noqa: E402
    BLOOD,
    BLOOD_DARK,
    OUTLINE,
    TILE,
    rect,
    shade,
)
from tile_atlas_core import (  # noqa: E402
    TRANSPARENT,
    Atlas,
    ground_config,
    leaning,
    neighbour_key,
    rule,
    spread,
    tile_of,
)

PZ_WALL_TOP = (58, 50, 46)
PZ_WALL_TOP_LIGHT = (86, 76, 70)
PZ_PLASTER = (226, 212, 180)
PZ_PLASTER_DARK = (192, 176, 144)
PZ_DAMP = (168, 150, 118)
PZ_SKIRTING = (96, 70, 50)
PZ_OAK = (150, 104, 62)
PZ_OAK_LIGHT = (170, 122, 76)
PZ_OAK_JOINT = (112, 76, 44)
PZ_KITCHEN_A = (226, 222, 210)
PZ_KITCHEN_B = (176, 96, 64)
PZ_BATH = (156, 196, 214)
PZ_BATH_JOINT = (120, 160, 180)
PZ_MARBLE = (214, 206, 190)
PZ_MARBLE_VEIN = (180, 172, 158)
PZ_MARBLE_BAND = (132, 120, 108)
PZ_WOOD = (112, 72, 42)
PZ_WOOD_LIGHT = (140, 94, 56)
PZ_WOOD_DARK = (76, 48, 28)
PZ_FABRIC = (120, 46, 40)
PZ_FABRIC_LIGHT = (150, 66, 56)
PZ_GREEN_FABRIC = (70, 96, 70)
PZ_WHITE = (232, 232, 226)
PZ_WHITE_SHADE = (194, 196, 192)
PZ_STEEL = (150, 154, 160)
PZ_STEEL_DARK = (86, 90, 98)
PZ_BLACK = (22, 22, 26)
PZ_GLASS = (120, 150, 170)
PZ_PAPER = (226, 222, 208)
PZ_SHEET = (220, 214, 200)
PZ_RUBBLE = ((196, 184, 160), (160, 148, 128), (124, 112, 98), (210, 200,
                                                                 180))
PZ_DAYLIGHT = (238, 214, 150)
PZ_WALLS = "xWwIL"

# The picture of the way up, one per palazzo.
STAIRS_IMAGE = "palazzo_stairs_up.png"

# What furnishes a flat, every piece of it an obstacle.
FURNITURE = "SaVThBnAlKOFHQRMpr"


def image_of(d) -> Image.Image:
    """The picture an ImageDraw draws on: the bodies are pasted sprites."""
    return d._image  # noqa: SLF001 - Pillow keeps it there


# ------------------------------------------------------------ the floors


def paint_parquet(d, rng, px, py):
    """Oak strips laid east to west, scuffed, a plank missing here and
    there."""
    for i, sy in enumerate(range(py, py + TILE, 4)):
        rect(d, px, sy, TILE, 4, PZ_OAK if i % 2 else PZ_OAK_LIGHT)
        rect(d, px, sy + 3, TILE, 1, PZ_OAK_JOINT)
        joint = px + (3 + i * 7) % TILE
        rect(d, joint, sy, 1, 3, PZ_OAK_JOINT)
    for _ in range(3):
        rect(d, px + rng.randrange(TILE), py + rng.randrange(TILE), 1, 1,
             shade(PZ_OAK, -30))
    if rng.random() < 0.15:  # a plank prised up
        sy = py + 4 * rng.randrange(4)
        rect(d, px + rng.randrange(2, 8), sy, 7, 3, (48, 34, 24))


def paint_kitchen_tiles(d, rng, px, py):
    """The kitchen's floor: white and terracotta squares on the diagonal
    of the grid, a few of them cracked."""
    for i in (0, 8):
        for j in (0, 8):
            rect(d, px + i, py + j, 8, 8,
                 PZ_KITCHEN_A if (i + j) // 8 % 2 == 0 else PZ_KITCHEN_B)
    rect(d, px, py, TILE, 1, shade(PZ_KITCHEN_A, -40))
    rect(d, px, py, 1, TILE, shade(PZ_KITCHEN_A, -40))
    if rng.random() < 0.3:
        cx, cy = px + rng.randrange(2, 12), py + rng.randrange(2, 12)
        for step in range(4):
            rect(d, cx + step, cy + (step * 3) % 4, 1, 1, (90, 80, 70))


def paint_bath_tiles(d, rng, px, py):
    """Small sky-blue tiles, the grout gone grey."""
    rect(d, px, py, TILE, TILE, PZ_BATH)
    for g in range(0, TILE, 4):
        rect(d, px + g, py, 1, TILE, PZ_BATH_JOINT)
        rect(d, px, py + g, TILE, 1, PZ_BATH_JOINT)
    if rng.random() < 0.3:  # a puddle from the burst pipes
        rect(d, px + rng.randrange(1, 8), py + rng.randrange(2, 10), 7, 3,
             shade(PZ_BATH, 22))


def paint_marble(d, rng, px, py):
    """The stairwell's pale marble, in big slabs with grey veins, a
    darker band along each slab's edge."""
    rect(d, px, py, TILE, TILE, PZ_MARBLE)
    rect(d, px, py, TILE, 1, PZ_MARBLE_BAND)
    rect(d, px, py, 1, TILE, shade(PZ_MARBLE, -18))
    x, y = px + rng.randrange(2, 8), py + rng.randrange(2, 6)
    for _ in range(6):
        rect(d, x, y, 2, 1, PZ_MARBLE_VEIN)
        x, y = x + rng.randint(0, 2), y + rng.randint(1, 2)
        if x >= px + TILE - 2 or y >= py + TILE - 1:
            break


def paint_edge(d, px, py, right):
    """Thin wall edge where the floor meets the darkness at the side."""
    rect(d, px + (12 if right else 0), py, 4, TILE, PZ_WALL_TOP)
    rect(d, px + (12 if right else 3), py, 1, TILE, PZ_WALL_TOP_LIGHT)


# -------------------------------------------------------------- the walls


def paint_wall(d, rng, px, py, upper):
    """The back wall seen face on, two tiles tall: the ceiling's edge and
    the plaster, damp and cracked, and on the lower course the skirting."""
    if upper:
        rect(d, px, py, TILE, 5, PZ_WALL_TOP)
        rect(d, px, py + 5, TILE, 11, PZ_PLASTER)
        rect(d, px, py + 5, TILE, 1, PZ_WALL_TOP_LIGHT)
        if rng.random() < 0.3:  # a crack from the ceiling
            cx = px + rng.randrange(2, 14)
            for cy in range(py + 6, py + 16, 2):
                rect(d, cx, cy, 1, 2, PZ_DAMP)
                cx += rng.choice((-1, 0, 1))
        return
    rect(d, px, py, TILE, 13, PZ_PLASTER)
    rect(d, px, py + 13, TILE, 3, PZ_SKIRTING)
    if rng.random() < 0.3:  # the damp coming up the wall
        rect(d, px, py + 8, TILE, 5, PZ_PLASTER_DARK)
    roll = rng.random()
    if roll < 0.06:  # a smear of blood down it
        sx = px + rng.randrange(2, 12)
        rect(d, sx, py + 1, 3, 5, BLOOD)
        rect(d, sx + 1, py + 6, 1, rng.randint(3, 7), BLOOD_DARK)
    elif roll < 0.12:  # a picture hanging crooked
        rect(d, px + 4, py + 2, 8, 6, PZ_WOOD_DARK)
        rect(d, px + 5, py + 3, 6, 4, (90, 120, 140))
    elif roll < 0.16:  # plaster fallen away, the brick behind
        rect(d, px + 3, py + 3, 8, 5, (150, 90, 66))
        rect(d, px + 3, py + 5, 8, 1, (190, 176, 150))


def paint_partition(d, px, py, wall_below):
    """An inner wall: its top seen from above, and its plastered face
    where the floor is below it."""
    if wall_below:
        rect(d, px, py, TILE, TILE, PZ_WALL_TOP)
        rect(d, px + 1, py, TILE - 2, TILE, PZ_WALL_TOP_LIGHT)
        rect(d, px + 3, py, TILE - 6, TILE, PZ_WALL_TOP)
        return
    rect(d, px, py, TILE, 6, PZ_WALL_TOP)
    rect(d, px, py, TILE, 1, PZ_WALL_TOP_LIGHT)
    rect(d, px, py + 6, TILE, 7, PZ_PLASTER)
    rect(d, px, py + 13, TILE, 3, PZ_SKIRTING)


def paint_front_wall(d, px, py):
    rect(d, px, py, TILE, 7, PZ_WALL_TOP)
    rect(d, px, py, TILE, 1, PZ_WALL_TOP_LIGHT)
    rect(d, px, py + 7, TILE, 9, (6, 6, 8))


def paint_doorway(d, px, py):
    """A doorway between two rooms: the sill, and the door torn off its
    hinges and thrown down across it."""
    rect(d, px + 1, py, TILE - 2, 2, PZ_WOOD_DARK)
    rect(d, px, py, 2, 10, PZ_WALL_TOP_LIGHT)
    rect(d, px + 3, py + 9, 11, 4, PZ_WOOD_LIGHT)
    rect(d, px + 3, py + 12, 11, 1, PZ_WOOD_DARK)
    rect(d, px + 11, py + 10, 1, 1, (200, 180, 90))  # the handle


def paint_flat_door(d, px, py):
    """A flat's armoured door onto the landing, kicked in: the steel leaf
    hanging off its frame into the flat, the dark behind it."""
    rect(d, px, py, TILE, TILE, PZ_WALL_TOP)
    rect(d, px + 2, py, TILE - 4, TILE, (30, 26, 24))
    rect(d, px + 2, py + 2, 4, 13, PZ_WOOD)
    rect(d, px + 3, py + 3, 2, 11, PZ_WOOD_LIGHT)
    rect(d, px + 5, py + 8, 1, 2, (200, 180, 90))
    rect(d, px + 7, py + 12, 7, 3, BLOOD)  # dragged out over the sill
    rect(d, px + 2, py + 15, TILE - 4, 1, PZ_MARBLE_BAND)


def paint_locked_door(d, px, py):
    """The one door on the landings still shut: an armoured door, its
    brass plate and spyhole, a bolt across it and 'NON APRITE' in blood."""
    rect(d, px, py, TILE, TILE, PZ_WALL_TOP)
    rect(d, px + 1, py, TILE - 2, TILE, PZ_WOOD_DARK)
    rect(d, px + 2, py + 1, TILE - 4, TILE - 2, PZ_WOOD)
    for sy in (py + 3, py + 8):
        rect(d, px + 3, sy, TILE - 6, 3, PZ_WOOD_LIGHT)
    rect(d, px + 7, py + 2, 2, 1, (210, 190, 110))  # the name plate
    rect(d, px + 7, py + 5, 2, 2, PZ_BLACK)  # the spyhole
    rect(d, px + 11, py + 8, 2, 2, (200, 180, 90))  # the lock
    rect(d, px + 1, py + 11, TILE - 2, 2, PZ_STEEL)  # a bolt across
    rect(d, px + 3, py + 13, 10, 1, BLOOD)
    rect(d, px + 5, py + 13, 1, 3, BLOOD_DARK)


def paint_unlocked_door(d, px, py):
    """The locked door once the key has opened it: the armoured leaf swung
    back against the frame, its plate and its lock whole, and the parquet
    of the flat past the sill."""
    rect(d, px, py, TILE, TILE, PZ_WALL_TOP)
    for i, sy in enumerate(range(py, py + TILE, 4)):
        rect(d, px + 2, sy, TILE - 4, 4, PZ_OAK if i % 2 else PZ_OAK_LIGHT)
        rect(d, px + 2, sy + 3, TILE - 4, 1, PZ_OAK_JOINT)
    rect(d, px + 2, py, TILE - 4, 2, shade(PZ_OAK_JOINT, -30))
    rect(d, px + 10, py + 1, 4, TILE - 2, PZ_WOOD_DARK)  # the leaf
    rect(d, px + 11, py + 2, 2, TILE - 4, PZ_WOOD_LIGHT)
    rect(d, px + 11, py + 5, 2, 1, (210, 190, 110))  # the name plate
    rect(d, px + 10, py + 8, 1, 2, (200, 180, 90))  # the lock
    rect(d, px + 2, py + 15, TILE - 4, 1, PZ_MARBLE_BAND)


# ------------------------------------------------- doors in the side walls
#
# A door in a wall that runs north to south is seen from above like the
# wall it is cut into: the wall's top goes on over the lintel, the jambs
# run down either side, and between them the door stands in line with the
# wall (shut), is swung back across the opening against the far jamb
# (open), or lies torn off along the sill (down). The palazzo's door
# painters above are for the walls that run east to west; palazzo_floor
# picks these whenever the cell above the door is a wall.


def paint_side_door(d, px, py, wall, wall_light, leaf, leaf_light, leaf_dark,
                    metal, sill, sill_edge, state, blood=False, bolt=None):
    """A door in a side wall, in the colours of the palazzo it is in: the
    stone `sill` across the wall's thickness, `sill_edge` its joints.
    `state` is "shut", "open", "down" or "gone" (the bare frame); `blood`
    drags a smear over it,
    `bolt` (a colour) bars a shut leaf across."""
    # The lintel: the wall's top going on over the opening, as the side
    # walls are drawn (see paint_partition).
    rect(d, px, py, TILE, 4, wall)
    rect(d, px + 1, py, TILE - 2, 4, wall_light)
    rect(d, px + 3, py, TILE - 6, 4, wall)
    # The jambs, down either side of the opening.
    rect(d, px, py + 4, 2, TILE - 4, wall)
    rect(d, px + 1, py + 4, 1, TILE - 4, wall_light)
    rect(d, px + TILE - 2, py + 4, 2, TILE - 4, wall)
    rect(d, px + TILE - 2, py + 4, 1, TILE - 4, wall_light)
    # The sill between them, in slabs, the lintel's shadow across its top.
    rect(d, px + 2, py + 4, TILE - 4, TILE - 4, sill)
    rect(d, px + 2, py + 10, TILE - 4, 1, sill_edge)
    rect(d, px + 2, py + 4, TILE - 4, 1, shade(wall, -20))
    if state == "shut":
        # The leaf in line with the wall, its frame either side and the
        # handle sticking out on both faces.
        rect(d, px + 2, py + 5, TILE - 4, TILE - 5, wall)
        rect(d, px + 5, py + 4, TILE - 10, TILE - 4, leaf_dark)
        rect(d, px + 6, py + 4, TILE - 12, TILE - 4, leaf)
        rect(d, px + 7, py + 4, 2, TILE - 4, leaf_light)
        rect(d, px + 4, py + 9, 1, 2, metal)
        rect(d, px + TILE - 5, py + 9, 1, 2, metal)
        if bolt is not None:
            rect(d, px + 2, py + 7, TILE - 4, 2, bolt)
        if blood:
            rect(d, px + 6, py + 12, 4, 1, BLOOD)
            rect(d, px + 7, py + 12, 1, 3, BLOOD_DARK)
        return
    if state == "open":
        # Swung back square to the wall against the south jamb: its top
        # edge, its face below it, the handle at the far end.
        rect(d, px + 2, py + TILE - 4, TILE - 4, 4, leaf_dark)
        rect(d, px + 3, py + TILE - 4, TILE - 6, 1, leaf_light)
        rect(d, px + 3, py + TILE - 3, TILE - 6, 2, leaf)
        rect(d, px + TILE - 5, py + TILE - 3, 1, 1, metal)
    elif state == "down":
        # Torn off its hinges and thrown down along the sill.
        rect(d, px + 5, py + 5, 6, TILE - 6, leaf_dark)
        rect(d, px + 6, py + 6, 4, TILE - 8, leaf_light)
        rect(d, px + 6, py + 9, 4, 1, leaf)
        rect(d, px + 8, py + 7, 1, 1, metal)
    if blood:
        rect(d, px + 3, py + 6, 4, 4, BLOOD)
        rect(d, px + 4, py + 10, 1, 2, BLOOD_DARK)


def paint_side_doorway(d, px, py):
    """paint_doorway's door in a side wall: torn off, along the sill."""
    paint_side_door(d, px, py, PZ_WALL_TOP, PZ_WALL_TOP_LIGHT, PZ_WOOD,
                    PZ_WOOD_LIGHT, PZ_WOOD_DARK, (200, 180, 90),
                    PZ_MARBLE, PZ_MARBLE_BAND, "down")


def paint_side_flat_door(d, px, py):
    """paint_flat_door's door in a side wall: kicked in, swung back, the
    blood dragged out over the sill."""
    paint_side_door(d, px, py, PZ_WALL_TOP, PZ_WALL_TOP_LIGHT, PZ_WOOD,
                    PZ_WOOD_LIGHT, PZ_WOOD_DARK, (200, 180, 90),
                    PZ_MARBLE, PZ_MARBLE_BAND, "open",
                    blood=True)


def paint_side_locked_door(d, px, py):
    """paint_locked_door's door in a side wall: shut, barred, bloodied."""
    paint_side_door(d, px, py, PZ_WALL_TOP, PZ_WALL_TOP_LIGHT, PZ_WOOD,
                    PZ_WOOD_LIGHT, PZ_WOOD_DARK, (200, 180, 90),
                    PZ_MARBLE, PZ_MARBLE_BAND, "shut",
                    blood=True, bolt=PZ_STEEL)


def paint_side_unlocked_door(d, px, py):
    """paint_unlocked_door's door in a side wall: swung back, whole."""
    paint_side_door(d, px, py, PZ_WALL_TOP, PZ_WALL_TOP_LIGHT, PZ_WOOD,
                    PZ_WOOD_LIGHT, PZ_WOOD_DARK, (210, 190, 110),
                    PZ_MARBLE, PZ_MARBLE_BAND, "open")


def locked_door_sprites(side: bool = False
                        ) -> tuple[Image.Image, Image.Image]:
    """The third floor's locked door as an object, shut and opened: the key
    swaps one for the other. With `side` it is a door in a side wall."""
    shut = Image.new("RGBA", (TILE, TILE), TRANSPARENT)
    (paint_side_locked_door if side else paint_locked_door)(
        ImageDraw.Draw(shut), 0, 0)
    opened = Image.new("RGBA", (TILE, TILE), TRANSPARENT)
    (paint_side_unlocked_door if side else paint_unlocked_door)(
        ImageDraw.Draw(opened), 0, 0)
    return shut, opened


def paint_stairs_down(d, px, py):
    """The top of the flight down, in the front wall: marble treads going
    down into the dark, the iron banister down the side."""
    rect(d, px, py, TILE, TILE, (18, 18, 20))
    for step in range(4):
        inset = step * 2
        rect(d, px + inset, py + 2 + step * 3, TILE - inset, 2,
             shade(PZ_MARBLE, -step * 30))
    rect(d, px + 14, py, 2, TILE, (40, 36, 34))
    rect(d, px + 14, py, 2, 1, PZ_WOOD_LIGHT)


def stair_door() -> Image.Image:
    """The way up, two tiles high in the back wall: the marble flight
    climbing into the dark behind the wall, its iron banister with the
    wooden handrail."""
    image = Image.new("RGBA", (TILE, TILE * 2), TRANSPARENT)
    d = ImageDraw.Draw(image)
    height = TILE * 2
    rect(d, 0, 0, TILE, height, PZ_WALL_TOP)
    rect(d, 1, 5, TILE - 2, height - 5, (18, 18, 20))
    for step in range(6):
        y = height - 3 - step * 4
        rect(d, 1, y, TILE - 2, 3, shade(PZ_MARBLE, -step * 26))
        rect(d, 1, y + 3, TILE - 2, 1, shade(PZ_MARBLE, -step * 26 - 60))
    for x in (1, TILE - 3):
        rect(d, x, 6, 2, height - 7, (40, 36, 34))
        rect(d, x, 6, 2, 1, PZ_WOOD_LIGHT)
    rect(d, 5, height - 7, 5, 2, BLOOD)  # a hand on the bottom step
    return image


def paint_portone(d, px, py):
    """The street door from inside the hall: the big wooden portone, one
    leaf standing open on the daylight, its glass fanlight broken."""
    rect(d, px, py, TILE, TILE, PZ_WALL_TOP)
    rect(d, px + 1, py + 1, TILE - 2, TILE - 1, PZ_DAYLIGHT)
    rect(d, px + 1, py + 1, 6, TILE - 1, PZ_WOOD)
    rect(d, px + 2, py + 2, 4, 5, PZ_WOOD_LIGHT)
    rect(d, px + 2, py + 9, 4, 5, PZ_WOOD_LIGHT)
    rect(d, px + 6, py + 7, 1, 2, (200, 180, 90))
    rect(d, px + 9, py + 10, 5, 2, (200, 186, 140))


def paint_mailboxes(d, rng, px, py):
    """The residents' letterboxes on the wall of the hall, some doors hanging
    open, the post long uncollected."""
    rect(d, px + 1, py - 6, 14, 14, PZ_STEEL_DARK)
    for row, sy in enumerate((py - 5, py - 1, py + 3)):
        for col, sx in enumerate((px + 2, px + 9)):
            rect(d, sx, sy, 6, 3, PZ_STEEL)
            rect(d, sx + 1, sy + 1, 4, 1, PZ_BLACK)
            if rng.random() < 0.35:  # its little door hanging
                rect(d, sx, sy + 2, 6, 3, shade(PZ_STEEL, -30))
                rect(d, sx + 1, sy + 1, 3, 2, PZ_PAPER)
    rect(d, px + 3, py + 10, 5, 2, PZ_PAPER)  # letters on the floor


def paint_plant(d, rng, px, py):
    """A condominium's potted palm, dead in its terracotta pot."""
    rect(d, px + 4, py + 9, 8, 6, (168, 88, 56))
    rect(d, px + 4, py + 9, 8, 1, (200, 120, 80))
    rect(d, px + 5, py + 14, 6, 1, (120, 60, 40))
    for i in range(5):
        lx = px + 2 + i * 3
        rect(d, lx, py - 2 + (i % 2) * 3, 2, 11 - (i % 2) * 3, (112, 104, 60))
    rect(d, px + 7, py - 4, 2, 13, (96, 86, 50))


# ---------------------------------------------------------------- mess


def paint_rubble(d, rng, px, py):
    """Plaster down off the ceiling, in chunks and dust."""
    for _ in range(7):
        rect(d, px + rng.randrange(1, 13), py + rng.randrange(2, 13),
             rng.randint(2, 4), rng.randint(1, 3), rng.choice(PZ_RUBBLE))
    rect(d, px + rng.randrange(3, 10), py + rng.randrange(4, 10), 2, 1,
         PZ_GLASS)


def paint_rubble_heap(d, rng, px, py):
    """A heap where the ceiling came down: slabs of plaster and brick,
    laths and a length of pipe sticking out of it."""
    rect(d, px + 1, py + 6, 14, 9, (120, 110, 96))
    rect(d, px + 3, py + 2, 10, 6, (150, 138, 118))
    for _ in range(9):
        rect(d, px + rng.randrange(1, 12), py + rng.randrange(1, 12),
             rng.randint(2, 5), rng.randint(2, 3), rng.choice(PZ_RUBBLE))
    for _ in range(2):
        rect(d, px + rng.randrange(2, 12), py + rng.randrange(3, 12), 3, 2,
             (150, 84, 60))
    rect(d, px + 10, py - 1, 2, 9, PZ_WOOD_LIGHT)
    rect(d, px + 2, py + 3, 1, 8, PZ_STEEL)


def paint_blood(d, rng, px, py):
    rect(d, px + 3, py + 5, 10, 6, BLOOD)
    rect(d, px + 5, py + 4, 5, 8, BLOOD)
    rect(d, px + 6, py + 7, 4, 3, BLOOD_DARK)
    if rng.random() < 0.5:  # dragged off
        rect(d, px + 12, py + 7, 4, 2, BLOOD)
    if rng.random() < 0.3:  # a footprint in it
        rect(d, px + 2, py + 12, 2, 3, BLOOD_DARK)


# ----------------------------------------------------------- furniture


def paint_sofa(d, rng, px, py, first, last):
    """A three- or two-seat sofa, back to the north, its cushions slashed
    and pulled out, a seat to each cell."""
    rect(d, px, py - 3, TILE, 7, PZ_FABRIC)
    rect(d, px, py - 3, TILE, 1, PZ_FABRIC_LIGHT)
    rect(d, px, py + 4, TILE, 8, PZ_FABRIC_LIGHT)
    rect(d, px, py + 12, TILE, 2, shade(PZ_FABRIC, -30))
    rect(d, px + 1, py + 5, TILE - 2, 6, PZ_FABRIC)
    if first:
        rect(d, px, py - 1, 3, 13, shade(PZ_FABRIC, -20))
        rect(d, px, py - 1, 1, 13, OUTLINE)
    if last:
        rect(d, px + 13, py - 1, 3, 13, shade(PZ_FABRIC, -20))
        rect(d, px + 15, py - 1, 1, 13, OUTLINE)
    if rng.random() < 0.5:  # the stuffing out
        rect(d, px + rng.randrange(3, 9), py + 6, 4, 3, PZ_SHEET)
    if rng.random() < 0.3:
        rect(d, px + 4, py + 2, 7, 5, BLOOD)


def paint_armchair(d, px, py):
    """An armchair turned half away, in green velvet."""
    rect(d, px + 2, py - 3, 12, 7, PZ_GREEN_FABRIC)
    rect(d, px + 2, py - 3, 12, 1, shade(PZ_GREEN_FABRIC, 26))
    rect(d, px + 2, py + 4, 12, 9, shade(PZ_GREEN_FABRIC, 16))
    rect(d, px + 1, py, 3, 12, shade(PZ_GREEN_FABRIC, -20))
    rect(d, px + 12, py, 3, 12, shade(PZ_GREEN_FABRIC, -20))
    rect(d, px + 3, py + 13, 2, 2, PZ_WOOD_DARK)
    rect(d, px + 11, py + 13, 2, 2, PZ_WOOD_DARK)


def paint_tv_stand(d, rng, px, py):
    """A low cabinet over two cells, the television on it smashed in."""
    rect(d, px, py + 6, 32, 8, PZ_WOOD)
    rect(d, px, py + 6, 32, 1, PZ_WOOD_LIGHT)
    rect(d, px + 15, py + 7, 1, 7, PZ_WOOD_DARK)
    rect(d, px + 1, py + 14, 30, 1, PZ_WOOD_DARK)
    rect(d, px + 6, py - 6, 20, 13, PZ_BLACK)
    rect(d, px + 7, py - 5, 18, 10, (40, 44, 52))
    for i in range(6):  # the screen starred from its middle
        rect(d, px + 14 - i, py - 1 - i // 2, 1, 1, PZ_GLASS)
        rect(d, px + 17 + i, py - 1 + i // 2, 1, 1, PZ_GLASS)
    rect(d, px + 14, py + 7, 4, 1, (60, 60, 64))


def paint_table(d, rng, px, py):
    """A dining table over two cells, a cloth dragged half off it, plates
    broken on it and a chair's worth of wood under it."""
    rect(d, px + 1, py + 13, 30, 2, (60, 44, 32))
    rect(d, px, py + 1, 32, 10, PZ_WOOD_LIGHT)
    rect(d, px, py + 1, 32, 1, shade(PZ_WOOD_LIGHT, 20))
    rect(d, px, py + 11, 32, 2, PZ_WOOD_DARK)
    for lx in (px + 1, px + 29):
        rect(d, lx, py + 11, 2, 4, PZ_WOOD_DARK)
    rect(d, px + 4, py + 2, 18, 8, PZ_SHEET)
    rect(d, px + 4, py + 10, 10, 4, PZ_SHEET)  # hanging off the edge
    for _ in range(3):
        rect(d, px + rng.randrange(6, 26), py + rng.randrange(3, 8), 3, 2,
             PZ_WHITE)
    if rng.random() < 0.5:
        rect(d, px + rng.randrange(8, 22), py + 4, 5, 3, BLOOD)


def paint_chair(d, px, py, toppled):
    """A kitchen chair, standing or knocked over."""
    if toppled:
        rect(d, px + 2, py + 9, 12, 3, PZ_WOOD)
        rect(d, px + 2, py + 9, 12, 1, PZ_WOOD_LIGHT)
        rect(d, px + 4, py + 12, 2, 3, PZ_WOOD_DARK)
        rect(d, px + 10, py + 12, 2, 3, PZ_WOOD_DARK)
        return
    rect(d, px + 4, py - 2, 8, 8, PZ_WOOD)
    rect(d, px + 5, py - 1, 6, 1, PZ_WOOD_LIGHT)
    rect(d, px + 3, py + 6, 10, 4, PZ_WOOD_LIGHT)
    rect(d, px + 4, py + 10, 2, 5, PZ_WOOD_DARK)
    rect(d, px + 10, py + 10, 2, 5, PZ_WOOD_DARK)


def paint_bed(d, rng, px, py, foot):
    """A bed over two cells, head to the north: the headboard and the
    pillow, then the foot, the sheets soaked and torn."""
    if not foot:
        rect(d, px + 1, py - 4, 14, 6, PZ_WOOD_DARK)
        rect(d, px + 2, py - 3, 12, 2, PZ_WOOD)
        rect(d, px + 1, py + 2, 14, 14, PZ_SHEET)
        rect(d, px + 3, py + 3, 10, 5, PZ_WHITE)
        rect(d, px + 1, py + 10, 14, 6, (170, 150, 110))
        rect(d, px + 1, py + 10, 14, 1, shade(PZ_SHEET, -30))
        if rng.random() < 0.6:
            rect(d, px + 4, py + 8, 8, 6, BLOOD)
        return
    rect(d, px + 1, py, 14, 12, (170, 150, 110))
    rect(d, px + 1, py + 12, 14, 3, PZ_WOOD_DARK)
    rect(d, px + 1, py, 1, 12, shade(PZ_SHEET, -50))
    rect(d, px + 14, py, 1, 12, shade(PZ_SHEET, -50))
    if rng.random() < 0.5:
        rect(d, px + 3, py + 2, 9, 7, BLOOD)
        rect(d, px + 6, py + 9, 2, 6, BLOOD_DARK)


def paint_nightstand(d, rng, px, py):
    """A bedside table, its drawer pulled out, a lamp knocked over."""
    rect(d, px + 3, py + 4, 10, 10, PZ_WOOD)
    rect(d, px + 3, py + 4, 10, 1, PZ_WOOD_LIGHT)
    rect(d, px + 4, py + 8, 8, 3, PZ_WOOD_DARK)
    rect(d, px + 2, py + 11, 12, 3, PZ_WOOD_LIGHT)  # the drawer, out
    rect(d, px + 5, py + 1, 6, 3, (200, 170, 110))  # the lamp on its side
    rect(d, px + 11, py + 2, 2, 1, PZ_STEEL)


def paint_wardrobe(d, rng, px, py):
    """A tall wardrobe against the wall, one door hanging open on the
    clothes pulled out of it."""
    rect(d, px + 1, py - 10, 14, 25, PZ_WOOD)
    rect(d, px + 1, py - 10, 14, 2, PZ_WOOD_DARK)
    rect(d, px + 8, py - 8, 1, 22, PZ_WOOD_DARK)
    rect(d, px + 2, py - 7, 5, 20, PZ_WOOD_LIGHT)
    if rng.random() < 0.6:
        rect(d, px + 9, py - 7, 5, 20, (30, 24, 22))
        for i in range(3):
            rect(d, px + 9 + i * 2, py - 6, 2, 10,
                 rng.choice(((90, 90, 120), (150, 40, 40), (200, 190, 170))))
    rect(d, px + 6, py + 1, 1, 2, (200, 180, 90))
    rect(d, px + 1, py + 14, 14, 1, OUTLINE)


def paint_bookcase(d, rng, px, py):
    """A bookcase, most of its books thrown on the floor."""
    rect(d, px + 1, py - 10, 14, 25, PZ_WOOD_DARK)
    for sy in (py - 8, py - 2, py + 4):
        rect(d, px + 2, sy + 5, 12, 1, PZ_WOOD_LIGHT)
        x = px + 2
        while x < px + 13:
            if rng.random() < 0.5:
                rect(d, x, sy + 1, 2, 4, rng.choice(
                    ((150, 40, 40), (60, 80, 130), (70, 110, 70),
                     (200, 180, 120))))
            x += 2
    rect(d, px + 3, py + 12, 9, 2, (150, 40, 40))  # books at its foot


def paint_counter(d, rng, px, py, first, last):
    """A run of kitchen units: the worktop, the doors under it, a sink or
    a pile of dishes on top now and then."""
    rect(d, px, py - 2, TILE, 6, PZ_WHITE)
    rect(d, px, py - 2, TILE, 1, (250, 250, 246))
    rect(d, px, py + 4, TILE, 10, (190, 170, 130))
    rect(d, px, py + 4, TILE, 1, PZ_WOOD_DARK)
    rect(d, px + 7, py + 5, 1, 9, PZ_WOOD_DARK)
    rect(d, px, py + 14, TILE, 1, PZ_WOOD_DARK)
    roll = rng.random()
    if roll < 0.3:  # the sink
        rect(d, px + 3, py - 1, 10, 4, PZ_STEEL)
        rect(d, px + 4, py, 8, 2, PZ_STEEL_DARK)
    elif roll < 0.6:  # broken dishes
        for _ in range(3):
            rect(d, px + rng.randrange(2, 12), py - 1 + rng.randrange(3), 3,
                 2, PZ_WHITE_SHADE)
    if rng.random() < 0.3:  # a cupboard door off
        rect(d, px + 1, py + 5, 5, 9, (30, 26, 24))
    if first:
        rect(d, px, py - 2, 1, 17, OUTLINE)
    if last:
        rect(d, px + 15, py - 2, 1, 17, OUTLINE)


def paint_stove(d, px, py):
    """The cooker: four rings on top, the oven door fallen open."""
    rect(d, px, py - 2, TILE, 6, PZ_WHITE_SHADE)
    for cx in (px + 3, px + 10):
        for cy in (py - 1, py + 2):
            rect(d, cx, cy, 3, 1, PZ_BLACK)
    rect(d, px, py + 4, TILE, 11, PZ_WHITE)
    rect(d, px + 2, py + 6, 12, 2, PZ_STEEL_DARK)
    rect(d, px + 2, py + 9, 12, 5, PZ_BLACK)  # the oven, open
    rect(d, px + 2, py + 13, 12, 2, PZ_GLASS)


def paint_fridge(d, rng, px, py):
    """A tall fridge, its door hanging open, rotten food inside."""
    rect(d, px + 1, py - 10, 14, 25, PZ_WHITE)
    rect(d, px + 1, py - 10, 14, 1, (250, 250, 246))
    rect(d, px + 1, py - 3, 14, 1, PZ_WHITE_SHADE)
    rect(d, px + 3, py - 7, 1, 3, PZ_STEEL)
    rect(d, px + 3, py, 1, 4, PZ_STEEL)
    if rng.random() < 0.6:
        rect(d, px + 5, py - 2, 9, 15, (40, 44, 36))
        rect(d, px + 6, py + 2, 3, 2, (110, 130, 60))
        rect(d, px + 9, py + 7, 3, 2, (130, 90, 60))
    rect(d, px + 1, py + 14, 14, 1, OUTLINE)


def paint_basin(d, px, py):
    """The bathroom's washbasin on its pedestal, the mirror over it broken."""
    rect(d, px + 3, py - 7, 10, 7, (150, 170, 180))
    rect(d, px + 4, py - 6, 8, 5, PZ_GLASS)
    rect(d, px + 6, py - 6, 1, 5, PZ_WHITE)
    rect(d, px + 2, py + 1, 12, 5, PZ_WHITE)
    rect(d, px + 4, py + 2, 8, 2, PZ_WHITE_SHADE)
    rect(d, px + 6, py + 6, 4, 8, PZ_WHITE_SHADE)
    rect(d, px + 5, py + 3, 3, 3, BLOOD)


def paint_toilet(d, px, py):
    """The toilet, the cistern behind it, the lid up."""
    rect(d, px + 4, py - 3, 8, 5, PZ_WHITE)
    rect(d, px + 4, py - 3, 8, 1, (250, 250, 246))
    rect(d, px + 4, py + 2, 8, 9, PZ_WHITE)
    rect(d, px + 5, py + 3, 6, 6, PZ_WHITE_SHADE)
    rect(d, px + 6, py + 4, 4, 4, (130, 150, 150))
    rect(d, px + 6, py + 11, 4, 3, PZ_WHITE_SHADE)


def paint_bathtub(d, rng, px, py):
    """A bathtub over two cells, filled with dark water, a hand over its
    rim."""
    rect(d, px, py + 1, 32, 13, PZ_WHITE)
    rect(d, px, py + 1, 32, 1, (250, 250, 246))
    rect(d, px + 2, py + 3, 28, 8, (70, 40, 36))
    rect(d, px + 3, py + 4, 26, 2, (100, 50, 44))
    rect(d, px, py + 13, 32, 2, PZ_WHITE_SHADE)
    rect(d, px + 28, py + 3, 2, 3, PZ_STEEL)  # the taps
    rect(d, px + 12, py + 11, 4, 3, (200, 160, 130))  # the hand
    rect(d, px + 12, py + 13, 1, 2, BLOOD)


# --------------------------------------------------------------- rules


FLOORS = (
    (".", paint_parquet),
    (",", paint_kitchen_tiles),
    ("_", paint_bath_tiles),
    ("=", paint_marble),
)


def floor_rules(atlas: Atlas, rng, style=None) -> list[dict]:
    """Each room keeps its floor: what stands on it is painted over the
    floor found under it (see `GROUND`). The painters are `style`'s: this
    module's, or another palazzo's with the same names."""
    s = style or sys.modules[__name__]
    rules = []
    for glyph, paint in s.FLOORS:
        rules.append(rule("ground", glyph, [atlas.bucket(
            lambda p=paint: tile_of(lambda d: p(d, rng, 0, 0)))]))
    everything = "".join(glyph for glyph, _ in s.FLOORS)
    for right in (False, True):
        rules.append(rule(
            "ground", everything,
            [[], atlas.bucket(lambda r=right: tile_of(
                lambda d: s.paint_edge(d, 0, 0, r)), 1)],
            [neighbour_key(1 if right else -1, 0, "x")]))
    return rules


def palazzo_floor(atlas: Atlas, rng, glyphs: str, style=None) -> dict:
    """The rules of one of the palazzo's floors: the rooms, then only the
    furniture `glyphs` it has, painted by `style` (see `floor_rules`)."""
    s = style or sys.modules[__name__]
    rules = floor_rules(atlas, rng, s)

    def one(paint):
        return [atlas.bucket(lambda: tile_of(lambda d: paint(d, 0, 0)), 1)]

    def randomly(paint):
        return [atlas.bucket(lambda: tile_of(lambda d: paint(d, rng, 0, 0)))]

    def lean(paint_for, keys=None, count=None):
        if count is None:
            return leaning(atlas, paint_for, keys)
        return leaning(atlas, paint_for, keys, count)

    # The back wall is two courses: the top one has wall below it.
    rules.append(rule(
        "structures", "WM",
        [atlas.bucket(lambda u=upper: tile_of(
            lambda d: s.paint_wall(d, rng, 0, 0, u)))
         for upper in (False, True)],
        [neighbour_key(0, 1, "xWMw")]))
    rules.append(rule(
        "structures", "I",
        [atlas.bucket(lambda b=below: tile_of(
            lambda d: s.paint_partition(d, 0, 0, b)), 1)
         for below in (False, True)],
        [neighbour_key(0, 1, s.PZ_WALLS)]))
    rules.append(rule("structures", "w", one(s.paint_front_wall)))
    # A door in a wall running east to west, or -- with a wall above it --
    # in one running north to south (see paint_side_door).
    side_wall = [neighbour_key(0, -1, s.PZ_WALLS)]

    def door(front, side):
        return [one(front)[0], one(side)[0]]

    rules.append(rule("structures", "d",
                      door(s.paint_doorway, s.paint_side_doorway), side_wall))
    rules.append(rule("structures", "D", one(s.paint_stairs_down)))
    rules.append(rule("structures", ":", randomly(s.paint_rubble)))
    rules.append(rule("structures", "b", randomly(s.paint_blood)))
    if "P" in glyphs:
        rules.append(rule("structures", "P", door(
            s.paint_flat_door, s.paint_side_flat_door), side_wall))
    if "L" in glyphs:
        rules.append(rule("structures", "L", door(
            s.paint_locked_door, s.paint_side_locked_door), side_wall))
    if "Y" in glyphs:
        rules.append(rule("structures", "Y", door(
            s.paint_unlocked_door, s.paint_side_unlocked_door), side_wall))
    if "E" in glyphs:
        rules.append(rule("structures", "E", one(s.paint_portone)))
    if "M" in glyphs:
        buckets, up = lean(lambda i: lambda d, px, py:
                           s.paint_mailboxes(d, rng, px, py))
        rules.append(rule("structures", "M", buckets, pieces=up))
    if "c" in glyphs:
        buckets, pieces = spread(atlas, lambda i: lambda d, px, py:
                                 props.paint_corpse(image_of(d), rng, px, py),
                                 None, (1, 0, 1, 1), 12)
        rules.append(rule("structures", "c", buckets, None, pieces))

    # Runs of seats and units: the keys say whether the run goes on to
    # the left and to the right, which puts the arms and the ends on.
    for glyph, paint, joins in (("S", s.paint_sofa, "S"),
                                ("K", s.paint_counter, "KOF")):
        if glyph in glyphs:
            keys = [neighbour_key(-1, 0, joins), neighbour_key(1, 0, joins)]
            buckets, up = lean(lambda i, p=paint: lambda d, px, py: p(
                d, rng, px, py, not i & 1, not i & 2), keys)
            rules.append(rule("structures", glyph, buckets, keys, up))
    # Two-cell pieces, painted whole and cut: the key says whether the
    # cell to the left is the same, which makes this its right half.
    for glyph, paint in (("T", s.paint_table), ("V", s.paint_tv_stand),
                         ("R", s.paint_bathtub)):
        if glyph in glyphs:
            pair = [neighbour_key(-1, 0, glyph)]
            buckets, up = lean(lambda i, p=paint: lambda d, px, py: p(
                d, rng, px - TILE * i, py), pair)
            rules.append(rule("structures", glyph, buckets, pair, up))
    if "h" in glyphs:
        rules.append(rule("structures", "h", [atlas.bucket(
            lambda t=toppled: tile_of(lambda d: s.paint_chair(d, 0, 0, t)), 1)
            for toppled in (False, True)], [neighbour_key(0, -1, "IWx")]))
    for glyph, paint in (("a", s.paint_armchair), ("O", s.paint_stove),
                         ("H", s.paint_basin), ("Q", s.paint_toilet)):
        if glyph in glyphs:
            buckets, up = lean(lambda i, p=paint: p, None, 1)
            rules.append(rule("structures", glyph, buckets, pieces=up))
    for glyph, paint in (("A", s.paint_wardrobe), ("l", s.paint_bookcase),
                         ("F", s.paint_fridge), ("p", s.paint_plant),
                         ("n", s.paint_nightstand), ("r", s.paint_rubble_heap)):
        if glyph in glyphs:
            buckets, up = lean(lambda i, p=paint: lambda d, px, py: p(
                d, rng, px, py))
            rules.append(rule("structures", glyph, buckets, pieces=up))
    if "B" in glyphs:
        rules.append(rule("structures", "B", [atlas.bucket(
            lambda f=foot: tile_of(lambda d: s.paint_bed(d, rng, 0, 0, f)))
            for foot in (False, True)], [neighbour_key(0, -1, "B")]))

    objects = []
    if "U" in glyphs:
        objects.append({"glyph": "U", "image": s.STAIRS_IMAGE,
                        "offsetY": -1, "sprite": s.stair_door()})
    return {"void": "#000000", "voidGlyph": "x", "rules": rules,
            "objects": objects, "ground": s.GROUND}


# The floor under the furniture, the dead and the doors: the nearest one
# along the row, never through a wall, so a sofa stands on the living
# room's parquet and the cooker on the kitchen's tiles.
GROUND = ground_config(
    buildings=PZ_WALLS,
    roads="",
    walks="",
    floors="".join(glyph for glyph, _ in FLOORS),
    footway="",
    keep="",
    lawn="",
    lawnProps="",
)


def palazzo_ground_floor(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.palazzoGroundFloor."""
    return palazzo_floor(atlas, rng, "EMpcU")


def palazzo_first_floor(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.palazzoFirstFloor."""
    return palazzo_floor(atlas, rng, "PpcU" + FURNITURE)


def palazzo_second_floor(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.palazzoSecondFloor."""
    return palazzo_floor(atlas, rng, "PpcU" + FURNITURE)


def palazzo_third_floor(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.palazzoThirdFloor, and its locked door,
    which the key opens."""
    art = palazzo_floor(atlas, rng, "PLpcU" + FURNITURE)
    # The locked door is in the side wall of the landing.
    shut, opened = locked_door_sprites(side=True)
    art["objects"].append({"glyph": "L", "image": "palazzo_flat_door.png",
                           "sprite": shut,
                           "whenOpen": "palazzo_flat_door_open.png",
                           "openSprite": opened})
    return art


def palazzo_locked_flat(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.palazzoLockedFlat: the flat behind the
    third floor's locked door, and that door `Y` from inside, open."""
    return palazzo_floor(atlas, rng, "Ypc" + FURNITURE)


PLACES = {
    "palazzoGroundFloor": palazzo_ground_floor,
    "palazzoFirstFloor": palazzo_first_floor,
    "palazzoSecondFloor": palazzo_second_floor,
    "palazzoThirdFloor": palazzo_third_floor,
    "palazzoLockedFlat": palazzo_locked_flat,
}

PREVIEW_ROWS = {
    "palazzoGroundFloor": "palazzo-ground-rows",
    "palazzoFirstFloor": "palazzo-first-rows",
    "palazzoSecondFloor": "palazzo-second-rows",
    "palazzoThirdFloor": "palazzo-third-rows",
    "palazzoLockedFlat": "palazzo-locked-flat-rows",
}
