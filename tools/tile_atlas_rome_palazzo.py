"""The palazzo beside the bank on Via Marsala, in Rome, in the tile atlas:
its entrance hall, its two floors of flats and its roof, with the bank's
across the drop (lib/core/levels/rome/rome_palazzo.dart).

Its floors are built by the rules of Molfetta's palazzo
(tile_atlas_palazzo.palazzo_floor), with this module's painters: a Roman
block of flats, not a Molfetta one. Graniglia underfoot in the rooms, red
cotto hexagons in the kitchens, black and white in the bathrooms,
travertine on the landings; walls in Roman yellow over a Pompeian red
dado; walnut furniture, mustard velvet, brass bedsteads, marble-topped
tables, bentwood chairs. All of it wrecked, like everything else.

Its roof is a terrace paved in cotto behind a travertine parapet, and past
the parapet the tiled roofs of Rome, curved tiles in their rows as far as
can be seen; across the drop, the bank's flat roof, its felt and gravel.
"""
from __future__ import annotations

import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import street_props as props  # noqa: E402
import tile_atlas_palazzo as molfetta  # noqa: E402
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

RP_WALL_TOP = (54, 36, 34)
RP_WALL_TOP_LIGHT = (92, 62, 54)
RP_OCHRE = (218, 174, 98)
RP_OCHRE_DARK = (186, 142, 74)
RP_DADO = (146, 50, 40)
RP_DADO_LINE = (214, 178, 96)
RP_DAMP = (160, 122, 70)
RP_GRANIGLIA = (214, 204, 184)
RP_GRANIGLIA_JOINT = (184, 172, 150)
RP_CHIPS = ((150, 128, 104), (96, 94, 92), (176, 84, 62), (240, 236, 226),
            (120, 136, 120))
RP_COTTO = (184, 94, 60)
RP_COTTO_LIGHT = (204, 118, 78)
RP_COTTO_JOINT = (124, 62, 42)
RP_CHECK_A = (236, 234, 226)
RP_CHECK_B = (36, 36, 40)
RP_TRAVERTINE = (224, 210, 176)
RP_TRAVERTINE_HOLE = (184, 166, 128)
RP_TRAVERTINE_JOINT = (170, 154, 120)
RP_WALNUT = (92, 56, 36)
RP_WALNUT_LIGHT = (124, 80, 50)
RP_WALNUT_DARK = (62, 36, 24)
RP_MUSTARD = (196, 150, 52)
RP_MUSTARD_LIGHT = (224, 180, 76)
RP_LEATHER = (116, 66, 40)
RP_BRASS = (204, 172, 84)
RP_QUILT = (62, 84, 140)
RP_QUILT_LIGHT = (90, 116, 170)
RP_MARBLE = (232, 230, 224)
RP_MARBLE_VEIN = (176, 176, 182)
RP_MINT = (150, 198, 176)
RP_MINT_DARK = (110, 158, 138)
RP_CREAM = (236, 226, 196)
RP_IRON = (40, 38, 40)
RP_GREEN_DOOR = (44, 82, 64)
RP_GREEN_DOOR_LIGHT = (66, 108, 86)
RP_WHITE = (234, 234, 228)
RP_WHITE_SHADE = (196, 196, 192)
RP_STEEL = (156, 160, 166)
RP_GLASS = (120, 150, 170)
RP_SHEET = (222, 214, 196)
RP_DAYLIGHT = (238, 214, 150)

PZ_WALLS = "xWwIL"
STAIRS_IMAGE = "romePalazzo_stairs_up.png"


# ------------------------------------------------------------ the floors


def paint_graniglia(d, rng, px, py):
    """Graniglia: pale cement tiles set with chips of marble in every
    colour, in squares of eight, worn and dusty."""
    rect(d, px, py, TILE, TILE, RP_GRANIGLIA)
    for _ in range(14):
        rect(d, px + rng.randrange(TILE), py + rng.randrange(TILE), 1, 1,
             rng.choice(RP_CHIPS))
    for g in (0, 8):
        rect(d, px + g, py, 1, TILE, RP_GRANIGLIA_JOINT)
        rect(d, px, py + g, TILE, 1, RP_GRANIGLIA_JOINT)
    if rng.random() < 0.15:  # a tile cracked across
        cx, cy = px + rng.randrange(2, 12), py + rng.randrange(2, 12)
        for step in range(5):
            rect(d, cx + step, cy + (step * 2) % 3, 1, 1, (120, 110, 96))


def paint_cotto_hexagons(d, rng, px, py):
    """The kitchen's floor: little red cotto hexagons, rows offset half a
    tile, the joints dark with grease."""
    rect(d, px, py, TILE, TILE, RP_COTTO_JOINT)
    for row, sy in enumerate(range(py, py + TILE, 4)):
        off = 2 if row % 2 else 0
        for sx in range(px - 2 + off, px + TILE, 4):
            colour = RP_COTTO if (sx // 4 + row) % 3 else RP_COTTO_LIGHT
            x0, x1 = max(sx, px), min(sx + 3, px + TILE)
            if x1 > x0:
                rect(d, x0, sy + 1, x1 - x0, 2, colour)
            if x1 - 1 > x0 + 1:
                rect(d, x0 + 1, sy, x1 - x0 - 2, 3, colour)
    if rng.random() < 0.25:
        rect(d, px + rng.randrange(2, 12), py + rng.randrange(2, 12), 3, 2,
             (90, 50, 36))


def paint_bath_check(d, rng, px, py):
    """Black and white squares, a hand's breadth each, the white gone
    yellow."""
    for i in range(0, TILE, 4):
        for j in range(0, TILE, 4):
            rect(d, px + i, py + j, 4, 4,
                 RP_CHECK_A if (i + j) // 4 % 2 == 0 else RP_CHECK_B)
    if rng.random() < 0.3:  # water from the burst pipes
        rect(d, px + rng.randrange(1, 8), py + rng.randrange(2, 10), 7, 3,
             (120, 140, 150))


def paint_travertine(d, rng, px, py):
    """The landing's travertine: warm slabs full of little holes."""
    rect(d, px, py, TILE, TILE, RP_TRAVERTINE)
    rect(d, px, py, TILE, 1, RP_TRAVERTINE_JOINT)
    rect(d, px, py, 1, TILE, RP_TRAVERTINE_JOINT)
    for _ in range(6):
        rect(d, px + rng.randrange(1, 14), py + rng.randrange(1, 15),
             rng.randint(1, 3), 1, RP_TRAVERTINE_HOLE)


def paint_edge(d, px, py, right):
    rect(d, px + (12 if right else 0), py, 4, TILE, RP_WALL_TOP)
    rect(d, px + (12 if right else 3), py, 1, TILE, RP_WALL_TOP_LIGHT)


FLOORS = (
    (".", paint_graniglia),
    (",", paint_cotto_hexagons),
    ("_", paint_bath_check),
    ("=", paint_travertine),
)


# -------------------------------------------------------------- the walls


def paint_wall(d, rng, px, py, upper):
    """The back wall, two tiles tall: the ceiling's dark edge and the
    Roman yellow of the plaster; on the lower course the Pompeian red
    dado under a thin line of ochre."""
    if upper:
        rect(d, px, py, TILE, 5, RP_WALL_TOP)
        rect(d, px, py + 5, TILE, 11, RP_OCHRE)
        rect(d, px, py + 5, TILE, 1, RP_WALL_TOP_LIGHT)
        rect(d, px, py + 7, TILE, 1, RP_OCHRE_DARK)  # a painted cornice
        if rng.random() < 0.3:
            cx = px + rng.randrange(2, 14)
            for cy in range(py + 8, py + 16, 2):
                rect(d, cx, cy, 1, 2, RP_DAMP)
                cx += rng.choice((-1, 0, 1))
        return
    rect(d, px, py, TILE, 7, RP_OCHRE)
    rect(d, px, py + 7, TILE, 1, RP_DADO_LINE)
    rect(d, px, py + 8, TILE, 8, RP_DADO)
    rect(d, px, py + 15, TILE, 1, shade(RP_DADO, -40))
    roll = rng.random()
    if roll < 0.08:  # a holy picture, crooked
        rect(d, px + 5, py, 6, 6, RP_BRASS)
        rect(d, px + 6, py + 1, 4, 4, (70, 90, 150))
        rect(d, px + 7, py + 2, 2, 2, RP_CREAM)
    elif roll < 0.14:  # blood thrown up the dado
        sx = px + rng.randrange(2, 12)
        rect(d, sx, py + 6, 3, 4, BLOOD)
        rect(d, sx + 1, py + 10, 1, rng.randint(2, 5), BLOOD_DARK)
    elif roll < 0.2:  # plaster off, the tufa behind
        rect(d, px + 3, py + 1, 8, 5, (190, 168, 120))
        rect(d, px + 4, py + 3, 2, 1, (160, 140, 100))


def paint_partition(d, px, py, wall_below):
    if wall_below:
        rect(d, px, py, TILE, TILE, RP_WALL_TOP)
        rect(d, px + 1, py, TILE - 2, TILE, RP_WALL_TOP_LIGHT)
        rect(d, px + 3, py, TILE - 6, TILE, RP_WALL_TOP)
        return
    rect(d, px, py, TILE, 6, RP_WALL_TOP)
    rect(d, px, py, TILE, 1, RP_WALL_TOP_LIGHT)
    rect(d, px, py + 6, TILE, 4, RP_OCHRE)
    rect(d, px, py + 10, TILE, 1, RP_DADO_LINE)
    rect(d, px, py + 11, TILE, 5, RP_DADO)


def paint_front_wall(d, px, py):
    rect(d, px, py, TILE, 7, RP_WALL_TOP)
    rect(d, px, py, TILE, 1, RP_WALL_TOP_LIGHT)
    rect(d, px, py + 7, TILE, 9, (6, 6, 8))


def paint_doorway(d, px, py):
    """A doorway between two rooms: its travertine sill, and the white
    lacquered door off its hinges across it."""
    rect(d, px + 1, py, TILE - 2, 2, RP_TRAVERTINE_JOINT)
    rect(d, px, py, 2, 10, RP_WALL_TOP_LIGHT)
    rect(d, px + 3, py + 9, 11, 4, RP_WHITE)
    rect(d, px + 4, py + 10, 9, 2, RP_WHITE_SHADE)
    rect(d, px + 3, py + 12, 11, 1, (140, 140, 136))
    rect(d, px + 11, py + 10, 1, 1, RP_BRASS)


def paint_flat_door(d, px, py):
    """A flat's door onto the landing, lacquered bottle green with its
    brass knocker, kicked in and hanging into the dark of the flat."""
    rect(d, px, py, TILE, TILE, RP_WALL_TOP)
    rect(d, px + 2, py, TILE - 4, TILE, (24, 20, 20))
    rect(d, px + 2, py + 2, 5, 13, RP_GREEN_DOOR)
    rect(d, px + 3, py + 3, 3, 5, RP_GREEN_DOOR_LIGHT)
    rect(d, px + 3, py + 9, 3, 5, RP_GREEN_DOOR_LIGHT)
    rect(d, px + 6, py + 7, 1, 2, RP_BRASS)
    rect(d, px + 8, py + 12, 6, 3, BLOOD)
    rect(d, px + 2, py + 15, TILE - 4, 1, RP_TRAVERTINE_JOINT)


def paint_locked_door(d, px, py):
    rect(d, px, py, TILE, TILE, RP_WALL_TOP)
    rect(d, px + 1, py, TILE - 2, TILE, RP_GREEN_DOOR)
    rect(d, px + 7, py + 7, 2, 2, RP_BRASS)


def paint_side_doorway(d, px, py):
    """paint_doorway's door in a side wall (see
    tile_atlas_palazzo.paint_side_door): the white door along the sill."""
    molfetta.paint_side_door(d, px, py, RP_WALL_TOP, RP_WALL_TOP_LIGHT,
                             RP_WHITE_SHADE, RP_WHITE, (140, 140, 136),
                             RP_BRASS, RP_TRAVERTINE, RP_TRAVERTINE_JOINT, "down")


def paint_side_flat_door(d, px, py):
    """paint_flat_door's door in a side wall: the green leaf kicked in and
    swung back, the blood dragged over the sill."""
    molfetta.paint_side_door(d, px, py, RP_WALL_TOP, RP_WALL_TOP_LIGHT,
                             RP_GREEN_DOOR, RP_GREEN_DOOR_LIGHT,
                             shade(RP_GREEN_DOOR, -20), RP_BRASS,
                             RP_TRAVERTINE, RP_TRAVERTINE_JOINT, "open",
                             blood=True)


def paint_side_locked_door(d, px, py):
    """paint_locked_door's door in a side wall: the green leaf, shut."""
    molfetta.paint_side_door(d, px, py, RP_WALL_TOP, RP_WALL_TOP_LIGHT,
                             RP_GREEN_DOOR, RP_GREEN_DOOR_LIGHT,
                             shade(RP_GREEN_DOOR, -20), RP_BRASS,
                             RP_TRAVERTINE, RP_TRAVERTINE_JOINT, "shut")


def paint_stairs_down(d, px, py):
    """The top of the flight down: travertine treads going down into the
    dark, the wrought-iron banister down the side."""
    rect(d, px, py, TILE, TILE, (16, 14, 14))
    for step in range(4):
        inset = step * 2
        rect(d, px + inset, py + 2 + step * 3, TILE - inset, 2,
             shade(RP_TRAVERTINE, -step * 34))
    rect(d, px + 14, py, 2, TILE, RP_IRON)
    for sy in range(py + 2, py + TILE, 4):
        rect(d, px + 13, sy, 1, 2, RP_IRON)


def stair_door() -> Image.Image:
    """The way up, two tiles high in the back wall: travertine steps
    climbing into the dark, the wrought-iron banister curling at its foot."""
    image = Image.new("RGBA", (TILE, TILE * 2), TRANSPARENT)
    d = ImageDraw.Draw(image)
    height = TILE * 2
    rect(d, 0, 0, TILE, height, RP_WALL_TOP)
    rect(d, 1, 5, TILE - 2, height - 5, (16, 14, 14))
    for step in range(6):
        y = height - 3 - step * 4
        rect(d, 1, y, TILE - 2, 3, shade(RP_TRAVERTINE, -step * 28))
        rect(d, 1, y + 3, TILE - 2, 1, shade(RP_TRAVERTINE, -step * 28 - 70))
    for x in (1, TILE - 3):
        rect(d, x, 6, 2, height - 7, RP_IRON)
    rect(d, 1, height - 9, 4, 3, RP_IRON)  # the scroll at its foot
    rect(d, 11, height - 9, 4, 3, RP_IRON)
    return image


def paint_portone(d, px, py):
    """The portone from inside: studded walnut, one leaf standing open on
    the daylight of Via Marsala, the fanlight's iron grille over it."""
    rect(d, px, py, TILE, TILE, RP_WALL_TOP)
    rect(d, px + 1, py + 1, TILE - 2, TILE - 1, RP_DAYLIGHT)
    rect(d, px + 1, py + 1, TILE - 2, 3, RP_IRON)
    for gx in range(px + 2, px + TILE - 2, 3):
        rect(d, gx, py + 2, 1, 1, RP_DAYLIGHT)
    rect(d, px + 1, py + 4, 6, TILE - 4, RP_WALNUT)
    for sy in (py + 6, py + 10, py + 14):
        for sx in (px + 2, px + 5):
            rect(d, sx, sy, 1, 1, RP_BRASS)
    rect(d, px + 9, py + 11, 5, 2, (200, 186, 140))


def paint_mailboxes(d, rng, px, py):
    """The letterboxes in brass, their little doors forced, the post of
    another life still in them."""
    rect(d, px + 1, py - 6, 14, 14, RP_WALNUT_DARK)
    for sy in (py - 5, py - 1, py + 3):
        for sx in (px + 2, px + 9):
            rect(d, sx, sy, 6, 3, RP_BRASS)
            rect(d, sx + 1, sy + 1, 4, 1, (60, 50, 30))
            if rng.random() < 0.35:
                rect(d, sx, sy + 2, 6, 3, shade(RP_BRASS, -40))
                rect(d, sx + 1, sy + 1, 3, 2, RP_SHEET)
    rect(d, px + 3, py + 10, 5, 2, RP_SHEET)


def paint_plant(d, rng, px, py):
    """A ficus in a glazed blue pot, dropped every leaf."""
    rect(d, px + 4, py + 8, 8, 7, (50, 90, 150))
    rect(d, px + 4, py + 8, 8, 1, (90, 130, 190))
    rect(d, px + 7, py - 4, 2, 13, (100, 80, 56))
    for lx, ly in ((3, -2), (10, 0), (5, 3), (11, -4)):
        rect(d, px + lx, py + ly, 3, 2, (96, 112, 64))
    rect(d, px + 2, py + 14, 4, 1, (96, 112, 64))  # leaves on the floor


# ---------------------------------------------------------------- mess


def paint_rubble(d, rng, px, py):
    for _ in range(7):
        rect(d, px + rng.randrange(1, 13), py + rng.randrange(2, 13),
             rng.randint(2, 4), rng.randint(1, 3),
             rng.choice(((214, 184, 130), (184, 150, 100), (150, 120, 84))))


def paint_rubble_heap(d, rng, px, py):
    """Where the ceiling came down: tufa blocks, plaster and the beams of
    an old ceiling, reeds sticking out of the lath."""
    rect(d, px + 1, py + 6, 14, 9, (150, 124, 90))
    rect(d, px + 3, py + 2, 10, 6, (190, 162, 116))
    for _ in range(8):
        rect(d, px + rng.randrange(1, 12), py + rng.randrange(1, 12),
             rng.randint(2, 5), rng.randint(2, 3),
             rng.choice(((214, 184, 130), (170, 140, 96), (120, 96, 70))))
    rect(d, px + 2, py - 2, 3, 12, RP_WALNUT)
    for rx in range(px + 8, px + 14, 2):
        rect(d, rx, py, 1, 6, (200, 180, 120))


def paint_blood(d, rng, px, py):
    molfetta.paint_blood(d, rng, px, py)


# ----------------------------------------------------------- furniture


def paint_sofa(d, rng, px, py, first, last):
    """A mustard velvet sofa on a walnut frame, its buttons torn out."""
    rect(d, px, py - 3, TILE, 7, RP_MUSTARD)
    rect(d, px, py - 3, TILE, 1, RP_MUSTARD_LIGHT)
    for bx in range(px + 3, px + TILE, 6):
        rect(d, bx, py - 1, 1, 1, shade(RP_MUSTARD, -50))
    rect(d, px, py + 4, TILE, 7, RP_MUSTARD_LIGHT)
    rect(d, px, py + 11, TILE, 3, RP_WALNUT)
    if first:
        rect(d, px, py - 2, 3, 13, RP_WALNUT_LIGHT)
        rect(d, px, py - 2, 1, 13, OUTLINE)
    if last:
        rect(d, px + 13, py - 2, 3, 13, RP_WALNUT_LIGHT)
        rect(d, px + 15, py - 2, 1, 13, OUTLINE)
    if rng.random() < 0.4:
        rect(d, px + rng.randrange(3, 9), py + 5, 5, 4, BLOOD)


def paint_armchair(d, px, py):
    """A brown leather club armchair, cracked all over."""
    rect(d, px + 1, py - 3, 14, 7, RP_LEATHER)
    rect(d, px + 1, py - 3, 14, 1, shade(RP_LEATHER, 30))
    rect(d, px + 1, py + 4, 14, 9, shade(RP_LEATHER, 14))
    rect(d, px, py - 1, 4, 13, shade(RP_LEATHER, -20))
    rect(d, px + 12, py - 1, 4, 13, shade(RP_LEATHER, -20))
    for cx, cy in ((5, 6), (9, 8), (7, 10)):
        rect(d, px + cx, py + cy, 2, 1, shade(RP_LEATHER, -40))


def paint_tv_stand(d, rng, px, py):
    """A walnut sideboard over two cells, a valve radio on it, its doors
    open on broken glasses."""
    rect(d, px, py + 2, 32, 12, RP_WALNUT)
    rect(d, px, py + 2, 32, 1, RP_WALNUT_LIGHT)
    rect(d, px + 15, py + 3, 1, 11, RP_WALNUT_DARK)
    rect(d, px + 2, py + 5, 11, 7, RP_WALNUT_DARK)
    rect(d, px + 3, py + 8, 3, 3, RP_GLASS)
    rect(d, px + 1, py + 14, 30, 1, OUTLINE)
    rect(d, px + 18, py - 6, 12, 9, RP_WALNUT_LIGHT)  # the radio
    rect(d, px + 19, py - 5, 6, 6, (200, 180, 130))
    rect(d, px + 26, py - 4, 2, 2, RP_BRASS)
    rect(d, px + 26, py - 1, 2, 2, RP_BRASS)


def paint_table(d, rng, px, py):
    """A table over two cells, a white marble top on turned walnut legs, a
    lace runner down it and a fruit bowl gone to rot."""
    rect(d, px + 1, py + 13, 30, 2, (50, 38, 30))
    rect(d, px, py + 1, 32, 10, RP_MARBLE)
    for vx in (5, 14, 25):
        rect(d, px + vx, py + 2, 1, 4, RP_MARBLE_VEIN)
        rect(d, px + vx + 1, py + 6, 1, 3, RP_MARBLE_VEIN)
    rect(d, px, py + 11, 32, 2, RP_WALNUT_DARK)
    for lx in (px + 2, px + 28):
        rect(d, lx, py + 11, 2, 4, RP_WALNUT)
    rect(d, px + 8, py + 3, 16, 5, RP_SHEET)
    rect(d, px + 13, py + 3, 6, 4, (120, 100, 60))
    rect(d, px + 14, py + 3, 2, 2, (110, 90, 40))
    if rng.random() < 0.5:
        rect(d, px + rng.randrange(4, 24), py + 5, 5, 3, BLOOD)


def paint_chair(d, px, py, toppled):
    """A black bentwood chair, standing or thrown down."""
    if toppled:
        rect(d, px + 2, py + 9, 12, 2, RP_IRON)
        d.ellipse([px + 3, py + 6, px + 9, py + 12], outline=RP_IRON)
        rect(d, px + 10, py + 11, 1, 4, RP_IRON)
        return
    d.ellipse([px + 4, py - 3, px + 11, py + 5], outline=RP_IRON)
    rect(d, px + 3, py + 6, 10, 3, (70, 60, 56))
    rect(d, px + 4, py + 9, 1, 6, RP_IRON)
    rect(d, px + 11, py + 9, 1, 6, RP_IRON)


def paint_bed(d, rng, px, py, foot):
    """A brass bedstead over two cells, head to the north, a blue quilt
    pulled half off."""
    if not foot:
        rect(d, px + 1, py - 5, 14, 2, RP_BRASS)
        for bx in range(px + 2, px + 15, 3):
            rect(d, bx, py - 4, 1, 6, RP_BRASS)
        rect(d, px + 1, py + 2, 14, 14, RP_SHEET)
        rect(d, px + 3, py + 3, 10, 4, RP_WHITE)
        rect(d, px + 1, py + 9, 14, 7, RP_QUILT)
        rect(d, px + 1, py + 9, 14, 1, RP_QUILT_LIGHT)
        if rng.random() < 0.6:
            rect(d, px + 4, py + 7, 7, 5, BLOOD)
        return
    rect(d, px + 1, py, 14, 12, RP_QUILT)
    for qx in range(px + 1, px + 15, 4):
        rect(d, qx, py, 1, 12, RP_QUILT_LIGHT)
    rect(d, px + 1, py + 12, 14, 2, RP_BRASS)
    rect(d, px + 1, py + 12, 1, 3, RP_BRASS)
    rect(d, px + 14, py + 12, 1, 3, RP_BRASS)


def paint_nightstand(d, rng, px, py):
    """A walnut bedside table with a marble top, a rosary spilled on it."""
    rect(d, px + 3, py + 4, 10, 10, RP_WALNUT)
    rect(d, px + 2, py + 3, 12, 2, RP_MARBLE)
    rect(d, px + 4, py + 8, 8, 3, RP_WALNUT_DARK)
    rect(d, px + 6, py + 1, 4, 2, (200, 60, 60))
    for i in range(4):
        rect(d, px + 4 + i * 2, py + 4, 1, 1, (240, 230, 200))


def paint_wardrobe(d, rng, px, py):
    """A tall walnut wardrobe, the mirror in its door starred."""
    rect(d, px + 1, py - 10, 14, 25, RP_WALNUT)
    rect(d, px + 1, py - 11, 14, 2, RP_WALNUT_DARK)
    rect(d, px + 3, py - 7, 6, 18, (150, 170, 180))
    for i in range(4):
        rect(d, px + 5 + i % 2, py - 2 + i, 1, 1, RP_WHITE)
    rect(d, px + 10, py - 7, 4, 18, RP_WALNUT_LIGHT)
    rect(d, px + 10, py + 1, 1, 2, RP_BRASS)
    rect(d, px + 1, py + 14, 14, 1, OUTLINE)


def paint_bookcase(d, rng, px, py):
    """A glass-fronted cabinet for the good china, the glass smashed and
    the plates broken."""
    rect(d, px + 1, py - 10, 14, 25, RP_WALNUT_DARK)
    for sy in (py - 8, py - 2, py + 4):
        rect(d, px + 2, sy, 12, 5, (40, 34, 30))
        for plate in range(px + 3, px + 13, 4):
            if rng.random() < 0.6:
                d.ellipse([plate, sy + 1, plate + 3, sy + 4],
                          fill=RP_WHITE, outline=(60, 90, 150))
    rect(d, px + 3, py + 12, 8, 2, RP_WHITE_SHADE)


def paint_counter(d, rng, px, py, first, last):
    """A run of kitchen units in mint formica under a grey marble top."""
    rect(d, px, py - 2, TILE, 6, (170, 170, 172))
    rect(d, px, py - 2, TILE, 1, (200, 200, 204))
    rect(d, px, py + 4, TILE, 10, RP_MINT)
    rect(d, px, py + 4, TILE, 1, RP_MINT_DARK)
    rect(d, px + 7, py + 5, 1, 9, RP_MINT_DARK)
    rect(d, px + 5, py + 8, 1, 2, RP_STEEL)
    rect(d, px + 9, py + 8, 1, 2, RP_STEEL)
    rect(d, px, py + 14, TILE, 1, OUTLINE)
    roll = rng.random()
    if roll < 0.3:  # the moka on the top, and its cups
        rect(d, px + 4, py - 5, 3, 5, (150, 150, 156))
        rect(d, px + 9, py - 1, 2, 2, RP_WHITE)
    elif roll < 0.55:
        rect(d, px + 3, py - 1, 10, 3, (120, 120, 126))
    if first:
        rect(d, px, py - 2, 1, 17, OUTLINE)
    if last:
        rect(d, px + 15, py - 2, 1, 17, OUTLINE)


def paint_stove(d, px, py):
    """The old iron range, its brass rail and the oven door hanging."""
    rect(d, px, py - 2, TILE, 6, RP_IRON)
    for cx in (px + 3, px + 10):
        d.ellipse([cx, py - 1, cx + 3, py + 2], outline=(90, 86, 84))
    rect(d, px, py + 4, TILE, 11, (54, 52, 54))
    rect(d, px, py + 5, TILE, 1, RP_BRASS)
    rect(d, px + 2, py + 8, 12, 6, (18, 18, 20))
    rect(d, px + 3, py + 13, 10, 2, (80, 76, 72))


def paint_fridge(d, rng, px, py):
    """A rounded cream fridge of the fifties, its chrome handle, its door
    open on what went off inside."""
    rect(d, px + 1, py - 10, 14, 25, RP_CREAM)
    rect(d, px + 2, py - 11, 12, 1, RP_CREAM)
    rect(d, px + 1, py - 10, 14, 2, shade(RP_CREAM, 14))
    rect(d, px + 11, py - 5, 2, 5, RP_STEEL)
    rect(d, px + 3, py - 7, 7, 1, RP_STEEL)
    if rng.random() < 0.6:
        rect(d, px + 3, py + 1, 10, 12, (44, 48, 40))
        rect(d, px + 4, py + 4, 3, 2, (120, 130, 60))
    rect(d, px + 1, py + 14, 14, 1, OUTLINE)


def paint_basin(d, px, py):
    """A pink porcelain basin on its column, the mirror over it gone."""
    rect(d, px + 3, py - 7, 10, 7, RP_BRASS)
    rect(d, px + 4, py - 6, 8, 5, (40, 40, 44))
    rect(d, px + 2, py + 1, 12, 5, (232, 196, 196))
    rect(d, px + 4, py + 2, 8, 2, (206, 168, 168))
    rect(d, px + 6, py + 6, 4, 8, (232, 196, 196))


def paint_toilet(d, px, py):
    """The toilet, its cistern high on the wall and the chain."""
    rect(d, px + 4, py - 9, 8, 4, RP_WHITE)
    rect(d, px + 11, py - 5, 1, 7, RP_STEEL)
    rect(d, px + 4, py + 2, 8, 9, RP_WHITE)
    rect(d, px + 5, py + 3, 6, 6, RP_WHITE_SHADE)
    rect(d, px + 6, py + 4, 4, 4, (120, 140, 140))
    rect(d, px + 6, py + 11, 4, 3, RP_WHITE_SHADE)


def paint_bathtub(d, rng, px, py):
    """A bathtub on lion's feet over two cells, full of dark water."""
    rect(d, px + 1, py + 1, 30, 11, RP_WHITE)
    rect(d, px + 1, py + 1, 30, 1, (250, 250, 246))
    rect(d, px + 3, py + 3, 26, 6, (60, 44, 40))
    for fx in (px + 3, px + 26):
        rect(d, fx, py + 12, 3, 3, RP_BRASS)
    rect(d, px + 27, py + 2, 2, 3, RP_BRASS)
    rect(d, px + 14, py + 8, 4, 2, BLOOD)


# --------------------------------------------------------------- the floors


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

_STYLE = sys.modules[__name__]


def rome_palazzo_ground(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.romePalazzoGround."""
    return molfetta.palazzo_floor(atlas, rng, "EMpcUTAa" + "r", _STYLE)


def rome_palazzo_first(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.romePalazzoFirst."""
    return molfetta.palazzo_floor(atlas, rng, "PpcU" + molfetta.FURNITURE,
                                  _STYLE)


def rome_palazzo_second(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.romePalazzoSecond."""
    return molfetta.palazzo_floor(atlas, rng, "PpcU" + molfetta.FURNITURE,
                                  _STYLE)


# ------------------------------------------------------------------ roof

TILE_RED = (176, 84, 54)
TILE_RED_LIGHT = (206, 112, 72)
TILE_RED_DARK = (120, 54, 36)
MOSS = (104, 116, 70)
PARAPET = (226, 212, 180)
PARAPET_SHADE = (182, 166, 132)
PARAPET_WALL = (196, 150, 96)
FELT = (70, 70, 74)
FELT_LIGHT = (92, 92, 96)


def paint_terrace(d, rng, px, py):
    """The terrace's floor: big square cotto pavers, faded by the sun,
    weeds in the joints."""
    for i in (0, 8):
        for j in (0, 8):
            colour = RP_COTTO_LIGHT if (i + j) // 8 % 2 else (196, 108, 72)
            rect(d, px + i, py + j, 8, 8, colour)
    for g in (0, 8):
        rect(d, px + g, py, 1, TILE, (150, 84, 58))
        rect(d, px, py + g, TILE, 1, (150, 84, 58))
    if rng.random() < 0.2:
        rect(d, px + rng.choice((0, 8)), py + rng.randrange(1, 14), 1, 2,
             MOSS)


def paint_felt(d, rng, px, py):
    """The bank's flat roof: bitumen felt under a scatter of gravel."""
    rect(d, px, py, TILE, TILE, FELT)
    for _ in range(12):
        rect(d, px + rng.randrange(TILE), py + rng.randrange(TILE), 1, 1,
             rng.choice(((150, 146, 140), (120, 118, 112), FELT_LIGHT)))
    if rng.random() < 0.2:
        rect(d, px, py + rng.randrange(TILE), TILE, 1, (56, 56, 60))


def paint_roof_tiles(d, rng, px, py, eave):
    """The roofs of Rome beyond the parapet: curved tiles in rows running
    down the slope, each row's tiles lapped over the next, moss and a
    broken one here and there; at the eaves the gutter's edge."""
    rect(d, px, py, TILE, TILE, TILE_RED_DARK)
    for cx in range(px, px + TILE, 4):
        for cy in range(py - 2 + (cx // 4 % 2) * 3, py + TILE, 6):
            y0 = max(cy, py)
            h = min(cy + 6, py + TILE) - y0
            if h <= 0:
                continue
            rect(d, cx, y0, 3, h, TILE_RED)
            rect(d, cx + 1, y0, 1, h, TILE_RED_LIGHT)
            if cy + 5 < py + TILE and cy + 5 >= py:
                rect(d, cx, cy + 5, 3, 1, TILE_RED_DARK)
    if rng.random() < 0.25:
        rect(d, px + rng.randrange(0, 12), py + rng.randrange(0, 12), 3, 2,
             MOSS)
    if rng.random() < 0.1:  # a tile gone, the boards under it
        rect(d, px + 4 * rng.randrange(4), py + rng.randrange(0, 10), 3, 5,
             (70, 50, 36))
    if eave:
        rect(d, px, py + 13, TILE, 3, (96, 96, 100))
        rect(d, px, py + 13, TILE, 1, (140, 140, 146))


def paint_parapet(d, px, py, west, east, north, south):
    """The terrace's parapet: a low wall of Roman yellow capped with
    travertine, running whichever way its neighbours go."""
    across = west or east
    along = north or south
    if across or not along:
        rect(d, px, py + 4, TILE, 10, PARAPET_WALL)
        rect(d, px, py + 2, TILE, 4, PARAPET)
        rect(d, px, py + 5, TILE, 1, PARAPET_SHADE)
        rect(d, px, py + 14, TILE, 2, (60, 44, 34))
    if along:
        rect(d, px + 4, py, 8, TILE, PARAPET)
        rect(d, px + 4, py, 1, TILE, PARAPET_SHADE)
        rect(d, px + 11, py, 1, TILE, PARAPET_SHADE)


def paint_parapet_breach(d, rng, px, py):
    """A stretch of parapet knocked down to its last course, the coping
    fallen and broken on the roof: where Mario can look across."""
    rect(d, px + 4, py, 8, TILE, PARAPET_WALL)
    for sy in range(py + 1, py + TILE, 4):
        rect(d, px + 4, sy, 8, 1, (160, 118, 70))
    for _ in range(4):
        rect(d, px + rng.randrange(0, 12), py + rng.randrange(0, 13), 4, 3,
             PARAPET)


def paint_stair_house(d, px, py, top):
    """The stairwell's little house on the terrace: its walls of Roman
    yellow, its own little roof of curved tiles."""
    if top:
        rect(d, px, py, TILE, TILE, TILE_RED)
        for cx in range(px, px + TILE, 4):
            rect(d, cx + 1, py, 1, TILE, TILE_RED_LIGHT)
        rect(d, px, py + TILE - 2, TILE, 2, TILE_RED_DARK)
        return
    rect(d, px, py, TILE, TILE, RP_OCHRE)
    rect(d, px, py, TILE, 2, TILE_RED_DARK)
    rect(d, px, py + TILE - 2, TILE, 2, RP_OCHRE_DARK)


def paint_terrace_door(d, px, py):
    """The stairwell's door onto the terrace, open on the dark of the
    stairs."""
    rect(d, px, py, TILE, TILE, RP_OCHRE)
    rect(d, px, py, TILE, 2, TILE_RED_DARK)
    rect(d, px + 2, py + 3, 12, 13, (16, 14, 14))
    for step in range(3):
        rect(d, px + 3, py + 8 + step * 3, 10, 1,
             shade(RP_TRAVERTINE, -60 - step * 30))
    rect(d, px + 11, py + 3, 3, 13, RP_GREEN_DOOR)


def paint_bank_stairs(d, px, py, head):
    """The stairs going down into the bank from its roof: grey treads into
    the dark between steel rails, lower and darker cell by cell."""
    rect(d, px, py, TILE, TILE, (14, 14, 16))
    for i, sy in enumerate(range(py + (4 if head else 0), py + TILE, 4)):
        tread = shade((150, 150, 150), -30 * i - (0 if head else 60))
        rect(d, px + 1, sy, TILE - 2, 3, tread)
    rect(d, px, py, 1, TILE, RP_STEEL)
    rect(d, px + TILE - 1, py, 1, TILE, RP_STEEL)
    if head:
        rect(d, px, py, TILE, 2, RP_STEEL)


def paint_water_tank(d, px, py):
    """A black plastic water tank on its stand."""
    rect(d, px + 1, py + 13, 14, 2, (40, 40, 40))
    rect(d, px + 2, py - 6, 12, 19, (34, 34, 38))
    rect(d, px + 3, py - 7, 10, 2, (60, 60, 66))
    rect(d, px + 3, py - 3, 1, 14, (70, 70, 76))
    rect(d, px + 2, py + 3, 12, 1, (22, 22, 24))


def paint_aerial(d, px, py):
    """A television aerial on its mast, bent in a storm."""
    rect(d, px + 7, py - 10, 2, 24, RP_STEEL)
    for i, ay in enumerate(range(py - 9, py - 1, 3)):
        rect(d, px + 2 + i, ay, 12 - 2 * i, 1, RP_STEEL)
    rect(d, px + 5, py + 13, 6, 2, (60, 60, 64))


def paint_washing_line(d, rng, px, py):
    """A post of the washing lines, sheets and shirts still pegged out on
    the lines to the next one."""
    rect(d, px + 7, py - 8, 2, 22, (110, 110, 116))
    rect(d, px, py - 7, TILE, 1, (200, 200, 200))
    rect(d, px, py - 3, TILE, 1, (200, 200, 200))
    for cx, colour in ((1, RP_SHEET), (10, (150, 60, 60)), (12, (70, 90, 150))):
        rect(d, px + cx, py - 7, 4, 7, colour)


def paint_deck_chair(d, px, py):
    """A deck chair, its striped canvas torn."""
    rect(d, px + 2, py - 2, 12, 14, (40, 110, 150))
    for sy in range(py - 2, py + 12, 4):
        rect(d, px + 2, sy, 12, 2, RP_CREAM)
    rect(d, px + 1, py - 3, 1, 17, RP_WALNUT)
    rect(d, px + 14, py - 3, 1, 17, RP_WALNUT)
    rect(d, px + 6, py + 4, 4, 5, (30, 30, 34))


def paint_lemon(d, px, py):
    """A lemon tree in a terracotta pot, the fruit gone black."""
    rect(d, px + 3, py + 7, 10, 8, (178, 92, 58))
    rect(d, px + 3, py + 7, 10, 1, (206, 118, 78))
    rect(d, px + 7, py + 2, 2, 6, RP_WALNUT)
    d.ellipse([px + 1, py - 9, px + 14, py + 4], fill=(70, 100, 54))
    for lx, ly in ((4, -4), (9, -6), (6, 0), (11, -1)):
        rect(d, px + lx, py + ly, 2, 2, (120, 110, 40))


def paint_dish(d, px, py):
    """A satellite dish on the terrace, pointing at nothing now."""
    d.ellipse([px + 1, py - 6, px + 13, py + 6], fill=(200, 200, 204),
              outline=(140, 140, 146))
    rect(d, px + 7, py, 1, 13, RP_STEEL)
    rect(d, px + 4, py + 13, 8, 2, (60, 60, 64))


def paint_air_conditioner(d, px, py):
    """An air conditioner on the bank's roof, its grille rusting."""
    rect(d, px + 1, py - 2, 14, 15, (206, 206, 200))
    rect(d, px + 1, py - 2, 14, 1, (230, 230, 226))
    d.ellipse([px + 3, py + 1, px + 12, py + 10], fill=(80, 80, 84))
    for i in range(3):
        rect(d, px + 4, py + 3 + i * 3, 8, 1, (150, 150, 150))
    rect(d, px + 1, py + 13, 14, 2, (60, 60, 64))


def paint_skylight(d, px, py, right):
    """The bank's skylight over two cells, its wired glass cracked."""
    x0 = px - (TILE if right else 0)
    rect(d, x0 + 2, py + 1, 28, 13, (150, 150, 150))
    rect(d, x0 + 4, py + 3, 24, 9, (90, 120, 140))
    for gx in range(x0 + 4, x0 + 28, 4):
        rect(d, gx, py + 3, 1, 9, (160, 170, 176))
    rect(d, x0 + 10, py + 5, 6, 1, (230, 236, 240))
    rect(d, x0 + 11, py + 6, 1, 4, (230, 236, 240))


ROOF_FLOORS = ((".", paint_terrace), (",", paint_felt))

ROOF_GROUND = ground_config(
    buildings="xRH",
    roads="",
    walks="",
    floors=".,",
    footway="",
    keep="",
    lawn="",
    lawnProps="",
)


def rome_palazzo_roof(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.romePalazzoRoof."""
    rules = []
    for glyph, paint in ROOF_FLOORS:
        rules.append(rule("ground", glyph, [atlas.bucket(
            lambda p=paint: tile_of(lambda d: p(d, rng, 0, 0)))]))

    def one(paint):
        return [atlas.bucket(lambda: tile_of(lambda d: paint(d, 0, 0)), 1)]

    def randomly(paint):
        return [atlas.bucket(lambda: tile_of(lambda d: paint(d, rng, 0, 0)))]

    rules.append(rule("structures", "R", [atlas.bucket(
        lambda e=eave: tile_of(lambda d: paint_roof_tiles(d, rng, 0, 0, e)))
        for eave in (False, True)], [neighbour_key(0, 1, "x^<>.,Hvkoaps")]))
    wall = "^"
    keys = [neighbour_key(-1, 0, wall), neighbour_key(1, 0, wall),
            neighbour_key(0, -1, wall), neighbour_key(0, 1, wall)]
    rules.append(rule("structures", "^", [atlas.bucket(
        lambda i=index: tile_of(lambda d: paint_parapet(
            d, 0, 0, bool(i & 1), bool(i & 2), bool(i & 4), bool(i & 8))), 1)
        for index in range(16)], keys))
    rules.append(rule("structures", "<>", randomly(paint_parapet_breach)))
    rules.append(rule("structures", "H", [atlas.bucket(
        lambda t=top: tile_of(lambda d: paint_stair_house(d, 0, 0, t)), 1)
        for top in (False, True)], [neighbour_key(0, 1, "HD")]))
    rules.append(rule("structures", "D", one(paint_terrace_door)))
    rules.append(rule("structures", "v", [atlas.bucket(
        lambda h=head: tile_of(lambda d: paint_bank_stairs(d, 0, 0, h)), 1)
        for head in (True, False)], [neighbour_key(0, -1, "v")]))
    rules.append(rule("structures", ":", randomly(paint_rubble)))
    rules.append(rule("structures", "b", randomly(paint_blood)))
    buckets, pieces = spread(atlas, lambda i: lambda d, px, py:
                             props.paint_corpse(molfetta.image_of(d), rng,
                                                px, py),
                             None, (1, 0, 1, 1), 4)
    rules.append(rule("structures", "c", buckets, None, pieces))
    for glyph, paint in (("T", paint_water_tank), ("n", paint_aerial),
                         ("a", paint_deck_chair), ("p", paint_lemon),
                         ("s", paint_dish), ("k", paint_air_conditioner)):
        buckets, up = leaning(atlas, lambda i, p=paint: p, None, 1)
        rules.append(rule("structures", glyph, buckets, pieces=up))
    buckets, up = leaning(atlas, lambda i: lambda d, px, py:
                          paint_washing_line(d, rng, px, py), None, 2)
    rules.append(rule("structures", "l", buckets, pieces=up))
    rules.append(rule("structures", "o", [atlas.bucket(
        lambda r=right: tile_of(lambda d: paint_skylight(d, 0, 0, r)), 1)
        for right in (False, True)], [neighbour_key(-1, 0, "o")]))
    return {"void": "#000000", "voidGlyph": "x", "rules": rules,
            "objects": [], "ground": ROOF_GROUND}


PLACES = {
    "romePalazzoGround": rome_palazzo_ground,
    "romePalazzoFirst": rome_palazzo_first,
    "romePalazzoSecond": rome_palazzo_second,
    "romePalazzoRoof": rome_palazzo_roof,
}

PREVIEW_ROWS = {
    "romePalazzoGround": "rome-palazzo-ground-rows",
    "romePalazzoFirst": "rome-palazzo-first-rows",
    "romePalazzoSecond": "rome-palazzo-second-rows",
    "romePalazzoRoof": "rome-palazzo-roof-rows",
}
