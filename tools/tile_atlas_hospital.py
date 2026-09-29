"""The hospital's three floors in the tile atlas: the emergency department
with its waiting room, reception and first consulting rooms, and the two
wards above it (lib/core/levels/hometown/hospital.dart).

A module of its own, the way docs/level_pipeline.md wants the interiors to
go: build_tile_atlas.py only lists it. The rooms are a Pokemon-Emerald
room on a dark background like the barracks, in the hospital's colours:
pale green linoleum, walls white above and tiled in sea green below, a
teal stripe between. What stands taller than its cell leans out over the
row above (`leaning`).
"""
from __future__ import annotations

import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_airliner as airliner  # noqa: E402
from build_street_level import (  # noqa: E402
    BLOOD,
    BLOOD_DARK,
    OUTLINE,
    TILE,
    paint_campfire,
    rect,
    shade,
)
from tile_atlas_core import (  # noqa: E402
    TRANSPARENT,
    Atlas,
    Neighbourhood,
    leaning,
    neighbour_key,
    pattern_key,
    rule,
    tile_of,
)

HS_WALL_TOP = (52, 60, 66)
HS_WALL_TOP_LIGHT = (80, 90, 96)
HS_WALL_FACE = (222, 226, 218)
HS_WALL_FACE_DARK = (190, 196, 188)
HS_TILE = (170, 204, 196)
HS_TILE_DARK = (144, 178, 170)
HS_STRIPE = (46, 128, 132)
HS_SKIRTING = (70, 86, 88)
HS_FLOOR_A = (178, 194, 180)
HS_FLOOR_B = (168, 184, 170)
HS_FLOOR_JOINT = (150, 166, 152)
HS_WHITE = (232, 234, 228)
HS_WHITE_SHADE = (196, 200, 196)
HS_METAL = (150, 156, 164)
HS_METAL_LIGHT = (196, 202, 208)
HS_METAL_DARK = (88, 94, 104)
HS_TEAL = (58, 140, 144)
HS_TEAL_DARK = (36, 98, 104)
HS_BLUE = (62, 96, 150)
HS_BLUE_DARK = (40, 64, 110)
HS_SHEET = (236, 238, 232)
HS_SHEET_SHADE = (200, 206, 204)
HS_PAPER = (228, 226, 214)
HS_GLASS = (150, 190, 204)
HS_GLASS_DARK = (70, 96, 110)
HS_RED = (196, 36, 34)
HS_GREEN = (70, 200, 110)
HS_STAIRWELL = (22, 24, 28)
HS_WALLS = "xWwIN"


# ------------------------------------------------------------ the room


def paint_floor(d, rng, px, py):
    """Linoleum in big pale squares, scuffed and dirty."""
    for i in (0, 8):
        for j in (0, 8):
            rect(d, px + i, py + j, 8, 8,
                 HS_FLOOR_A if (i + j) // 8 % 2 == 0 else HS_FLOOR_B)
    rect(d, px, py, TILE, 1, HS_FLOOR_JOINT)
    rect(d, px, py, 1, TILE, HS_FLOOR_JOINT)
    for _ in range(3):
        rect(d, px + rng.randrange(16), py + rng.randrange(16), 1, 1,
             (140, 150, 140))
    if rng.random() < 0.2:  # a wheel's black scuff
        sx, sy = px + rng.randrange(1, 9), py + rng.randrange(2, 14)
        rect(d, sx, sy, rng.randint(3, 6), 1, (110, 116, 110))


def paint_edge(d, px, py, right):
    """Thin wall edge where the floor meets the darkness at the side."""
    rect(d, px + (12 if right else 0), py, 4, TILE, HS_WALL_TOP)
    rect(d, px + (12 if right else 3), py, 1, TILE, HS_WALL_TOP_LIGHT)


def paint_wall(d, rng, px, py, upper):
    """The back wall seen face on, two tiles tall: the ceiling's edge and
    the white plaster on top, and on the lower course the teal stripe and
    the sea-green tiles down to the skirting."""
    if upper:
        rect(d, px, py, TILE, 5, HS_WALL_TOP)
        rect(d, px, py + 5, TILE, 11, HS_WALL_FACE)
        rect(d, px, py + 5, TILE, 1, HS_WALL_TOP_LIGHT)
        return
    rect(d, px, py, TILE, 4, HS_WALL_FACE)
    rect(d, px, py + 4, TILE, 2, HS_STRIPE)
    rect(d, px, py + 6, TILE, 9, HS_TILE)
    for ty in (py + 9, py + 12):
        rect(d, px, ty, TILE, 1, HS_TILE_DARK)
    for tx in range(px + 3, px + TILE, 4):
        rect(d, tx, py + 6, 1, 9, HS_TILE_DARK)
    rect(d, px, py + 15, TILE, 1, HS_SKIRTING)
    if rng.random() < 0.08:  # a smear of blood down the tiles
        sx = px + rng.randrange(2, 12)
        rect(d, sx, py + 2, 3, 4, BLOOD)
        rect(d, sx + 1, py + 6, 1, rng.randint(3, 8), BLOOD_DARK)


def paint_partition(d, px, py, wall_below):
    """An inner wall: its top seen from above, and a short tiled face
    where the floor is below it."""
    if wall_below:
        rect(d, px, py, TILE, TILE, HS_WALL_TOP)
        rect(d, px + 1, py, TILE - 2, TILE, HS_WALL_TOP_LIGHT)
        rect(d, px + 3, py, TILE - 6, TILE, HS_WALL_TOP)
        return
    rect(d, px, py, TILE, 6, HS_WALL_TOP)
    rect(d, px, py, TILE, 1, HS_WALL_TOP_LIGHT)
    rect(d, px, py + 6, TILE, 2, HS_STRIPE)
    rect(d, px, py + 8, TILE, 7, HS_TILE)
    rect(d, px, py + 11, TILE, 1, HS_TILE_DARK)
    rect(d, px, py + 15, TILE, 1, HS_SKIRTING)


def paint_front_wall(d, px, py):
    rect(d, px, py, TILE, 7, HS_WALL_TOP)
    rect(d, px, py, TILE, 1, HS_WALL_TOP_LIGHT)
    rect(d, px, py + 7, TILE, 9, (6, 6, 8))


def paint_notice_board(d, rng, px, py):
    """A board on the tiles: the ward's notices and a red-cross poster."""
    rect(d, px + 1, py - 4, 14, 11, HS_METAL_DARK)
    rect(d, px + 2, py - 3, 12, 9, (206, 196, 170))
    rect(d, px + 3, py - 2, 5, 6, HS_WHITE)
    rect(d, px + 5, py - 1, 1, 4, HS_RED)
    rect(d, px + 4, py, 3, 1, HS_RED)
    for _ in range(2):
        rect(d, px + rng.randrange(8, 11), py + rng.randrange(-3, 3), 3, 3,
             HS_PAPER)
    rect(d, px + 9, py + 6, 3, 3, HS_PAPER)  # a sheet hanging loose


def paint_glass_door(d, px, py, right):
    """One leaf of the glass doors out onto the stairs: the daylight
    through them, the panes starred, hands smeared in blood on the glass.
    `right` is the east leaf."""
    rect(d, px, py, TILE, TILE, (236, 214, 150))
    rect(d, px + 1, py, TILE - 2, TILE, (250, 234, 176))
    edge = px + (TILE - 2 if right else 0)
    rect(d, edge, py, 2, TILE, HS_METAL_DARK)
    rect(d, px, py, TILE, 2, HS_METAL_DARK)
    rect(d, px + (3 if right else 9), py + 5, 4, 1, (180, 190, 196))
    rect(d, px + (4 if right else 10), py + 4, 1, 3, (180, 190, 196))
    rect(d, px + 5, py + 8, 3, 5, BLOOD)
    rect(d, px + 6, py + 13, 1, 3, BLOOD_DARK)
    rect(d, px + 2, py + 14, 12, 2, (120, 40, 36))  # the mat inside


def paint_doorway(d, px, py):
    """A doorway in a partition: its metal sill, and the door swung back
    against the jamb."""
    rect(d, px + 1, py, TILE - 2, 2, HS_METAL)
    rect(d, px, py, 2, 10, HS_WHITE_SHADE)
    rect(d, px, py, 1, 10, HS_METAL_DARK)


def paint_stairs_down(d, px, py):
    """The top of the flight down, in the front wall: pale treads going
    into the dark, the handrail down the side."""
    rect(d, px, py, TILE, TILE, HS_STAIRWELL)
    for step in range(4):
        inset = step * 2
        rect(d, px + inset, py + 2 + step * 3, TILE - inset, 2,
             shade(HS_FLOOR_A, -step * 22))
    rect(d, px + 14, py, 2, TILE, HS_METAL)


def stair_door() -> Image.Image:
    """The way up, two tiles high in the back wall: the fire door propped
    open, the steps climbing into the dark behind it and the green sign
    over it."""
    image = Image.new("RGBA", (TILE, TILE * 2), TRANSPARENT)
    d = ImageDraw.Draw(image)
    height = TILE * 2
    rect(d, 0, 0, TILE, height, HS_WALL_TOP)
    rect(d, 1, 5, TILE - 2, height - 5, HS_METAL_LIGHT)
    rect(d, 3, 8, TILE - 6, height - 8, HS_STAIRWELL)
    for step in range(5):
        y = height - 3 - step * 4
        rect(d, 3, y, TILE - 6, 2, shade(HS_FLOOR_A, -20 - step * 24))
        rect(d, 3, y + 2, TILE - 6, 1, shade(HS_STAIRWELL, 6))
    rect(d, 3, 8, 3, height - 9, (170, 60, 50))  # the red fire door
    rect(d, 3, 8, 1, height - 9, (210, 100, 90))
    rect(d, 4, 0, 8, 4, (30, 120, 60))  # the running-man sign
    rect(d, 5, 1, 6, 2, (200, 250, 210))
    rect(d, 7, 1, 1, 2, (30, 120, 60))
    return image


def paint_papers(d, rng, px, py):
    """Charts and case notes scattered, a shard of glass among them."""
    for _ in range(5):
        rect(d, px + rng.randrange(1, 12), py + rng.randrange(2, 13), 4, 3,
             HS_PAPER)
        rect(d, px + rng.randrange(1, 13), py + rng.randrange(2, 14), 3, 1,
             (170, 176, 170))
    rect(d, px + rng.randrange(2, 12), py + rng.randrange(3, 12), 2, 1,
         HS_GLASS)


def paint_blood(d, rng, px, py):
    rect(d, px + 3, py + 5, 10, 6, BLOOD)
    rect(d, px + 5, py + 4, 5, 8, BLOOD)
    rect(d, px + 6, py + 7, 4, 3, BLOOD_DARK)
    if rng.random() < 0.5:  # dragged off
        rect(d, px + 12, py + 7, 4, 2, BLOOD)


# ----------------------------------------------------------- furniture


def paint_counter(d, px, py, first, last):
    """The reception counter: a white top, the teal front, the glass over
    it smashed in."""
    rect(d, px, py + 3, TILE, 7, HS_WHITE)
    rect(d, px, py + 3, TILE, 1, (250, 250, 246))
    rect(d, px, py + 10, TILE, 6, HS_TEAL)
    rect(d, px, py + 10, TILE, 1, HS_TEAL_DARK)
    rect(d, px, py - 6, TILE, 9, HS_GLASS)
    rect(d, px + 5, py - 6, 3, 9, HS_GLASS_DARK)
    rect(d, px + 4, py - 2, 5, 1, (220, 236, 240))
    if first:
        rect(d, px, py - 6, 1, 22, OUTLINE)
    if last:
        rect(d, px + 15, py - 6, 1, 22, OUTLINE)


def paint_desk(d, rng, px, py):
    """A doctor's desk over two tiles: the monitor and the keyboard on
    the left, the prescriptions and the stethoscope on the right."""
    rect(d, px + 1, py + 15, 30, 1, (120, 128, 120))
    rect(d, px, py + 2, 32, 9, HS_WHITE)
    rect(d, px, py + 2, 32, 1, (250, 250, 246))
    rect(d, px, py + 11, 32, 4, HS_METAL)
    rect(d, px + 2, py + 11, 1, 4, OUTLINE)
    rect(d, px + 29, py + 11, 1, 4, OUTLINE)
    mx = px + 2 + rng.randrange(3)
    rect(d, mx, py - 3, 10, 7, (40, 42, 48))
    rect(d, mx + 1, py - 2, 8, 5, (60, 86, 104))
    rect(d, mx + 2, py + 5, 8, 2, HS_METAL_DARK)  # keyboard
    for _ in range(3):
        rect(d, px + 16 + rng.randrange(11), py + 3 + rng.randrange(5), 4, 3,
             HS_PAPER)
    rect(d, px + 22, py + 7, 5, 1, (40, 40, 44))  # stethoscope
    rect(d, px + 26, py + 5, 2, 3, (40, 40, 44))


def paint_cupboard(d, px, py):
    """A white medicine cupboard, its glass doors open, a red cross."""
    rect(d, px + 2, py - 6, 12, 22, HS_WHITE_SHADE)
    rect(d, px + 3, py - 5, 10, 20, HS_WHITE)
    rect(d, px + 3, py - 4, 4, 11, HS_GLASS)
    rect(d, px + 9, py - 4, 4, 11, HS_GLASS)
    for shelf in (py - 1, py + 3):
        rect(d, px + 3, shelf, 10, 1, HS_METAL)
    rect(d, px + 4, py - 3, 2, 2, (200, 150, 60))  # bottles
    rect(d, px + 10, py + 1, 2, 2, (80, 130, 190))
    rect(d, px + 7, py + 9, 2, 5, HS_RED)
    rect(d, px + 5, py + 10, 6, 2, HS_RED)


def paint_waiting_chair(d, px, py, left, right):
    """A seat in a row of blue plastic chairs on one metal beam."""
    rect(d, px + (0 if left else 1), py + 12, TILE - (0 if left else 1)
         - (0 if right else 1), 2, HS_METAL_DARK)
    if not left:
        rect(d, px + 2, py + 12, 2, 4, HS_METAL_DARK)
    if not right:
        rect(d, px + 12, py + 12, 2, 4, HS_METAL_DARK)
    rect(d, px + 2, py + 2, 12, 5, HS_BLUE_DARK)  # backrest
    rect(d, px + 3, py + 3, 10, 3, HS_BLUE)
    rect(d, px + 2, py + 7, 12, 5, HS_BLUE)  # seat
    rect(d, px + 2, py + 7, 12, 1, (100, 136, 190))


def paint_couch(d, rng, px, py):
    """An examination couch over two tiles: the padded top in a roll of
    paper, the pillow end raised, steel legs."""
    rect(d, px + 1, py + 13, 30, 2, HS_METAL_DARK)
    rect(d, px + 2, py + 13, 2, 3, HS_METAL)
    rect(d, px + 28, py + 13, 2, 3, HS_METAL)
    rect(d, px, py + 3, 32, 10, HS_TEAL_DARK)
    rect(d, px + 1, py + 4, 30, 8, HS_TEAL)
    rect(d, px + 6, py + 4, 22, 8, HS_SHEET)  # the paper
    rect(d, px + 6, py + 11, 22, 1, HS_SHEET_SHADE)
    rect(d, px + 1, py + 2, 6, 10, (80, 160, 164))  # the raised end
    if rng.random() < 0.6:
        rect(d, px + 14, py + 6, 6, 4, BLOOD)
        rect(d, px + 20, py + 8, 3, 2, BLOOD_DARK)


def paint_vending_machine(d, px, py):
    """A drinks machine, its front smashed and emptied."""
    rect(d, px + 1, py - 10, 14, 26, OUTLINE)
    rect(d, px + 2, py - 9, 12, 24, (170, 40, 40))
    rect(d, px + 3, py - 8, 7, 16, HS_GLASS_DARK)
    for sy in range(py - 6, py + 7, 4):
        rect(d, px + 3, sy, 7, 1, HS_METAL)
    rect(d, px + 4, py - 5, 2, 3, (60, 150, 80))
    rect(d, px + 11, py - 7, 2, 6, (230, 220, 200))  # the buttons
    rect(d, px + 4, py + 10, 8, 3, (30, 30, 34))  # the flap
    rect(d, px + 3, py - 2, 5, 1, (220, 236, 240))  # a crack


def paint_plant(d, rng, px, py):
    """A plant in its pot, dried up and brown at the tips."""
    rect(d, px + 4, py + 8, 8, 7, (170, 110, 70))
    rect(d, px + 4, py + 8, 8, 1, (200, 140, 96))
    rect(d, px + 5, py + 15, 6, 1, (90, 60, 40))
    for _ in range(7):
        lx, ly = px + rng.randrange(2, 12), py + rng.randrange(-6, 7)
        rect(d, lx, ly, 3, 2, rng.choice(((74, 120, 60), (96, 132, 64),
                                           (140, 120, 60))))
    rect(d, px + 7, py + 2, 2, 6, (80, 100, 50))


def paint_stretcher(d, rng, px, py):
    """A stretcher on wheels over two tiles, its sheet dragged half off
    and bloody."""
    rect(d, px + 2, py + 12, 28, 1, HS_METAL_DARK)
    for wx in (px + 3, px + 27):
        rect(d, wx, py + 12, 2, 3, HS_METAL_DARK)
        rect(d, wx, py + 14, 2, 2, OUTLINE)
    rect(d, px + 1, py + 3, 30, 9, HS_METAL)
    rect(d, px + 2, py + 4, 28, 7, HS_SHEET)
    rect(d, px + 2, py + 10, 28, 1, HS_SHEET_SHADE)
    rect(d, px + 3, py + 4, 5, 4, HS_WHITE)  # the pillow
    rect(d, px + 18, py + 9, 12, 5, HS_SHEET_SHADE)  # sheet hanging off
    rect(d, px + 12 + rng.randrange(6), py + 5, 7, 4, BLOOD)
    rect(d, px + 16, py + 7, 3, 3, BLOOD_DARK)


def paint_wheelchair(d, px, py):
    """A wheelchair left on its own."""
    d.ellipse([px + 1, py + 6, px + 9, py + 14], outline=HS_METAL_DARK)
    d.ellipse([px + 7, py + 6, px + 15, py + 14], outline=HS_METAL_DARK)
    rect(d, px + 4, py + 4, 8, 5, HS_BLUE_DARK)  # seat and back
    rect(d, px + 4, py + 1, 2, 7, HS_BLUE_DARK)
    rect(d, px + 3, py + 3, 10, 1, HS_METAL)
    rect(d, px + 11, py + 12, 3, 2, HS_METAL)  # footrest


def paint_basin(d, px, py):
    """A basin against the wall, the mirror over it cracked."""
    rect(d, px + 3, py - 10, 10, 8, HS_METAL_DARK)
    rect(d, px + 4, py - 9, 8, 6, HS_GLASS)
    rect(d, px + 6, py - 9, 1, 6, (220, 236, 240))
    rect(d, px + 2, py + 1, 12, 6, HS_WHITE)
    rect(d, px + 4, py + 2, 8, 3, HS_WHITE_SHADE)
    rect(d, px + 7, py, 2, 2, HS_METAL)
    rect(d, px + 6, py + 7, 4, 5, HS_WHITE_SHADE)  # the pedestal


def paint_bed(d, rng, px, py, foot):
    """A hospital bed over two tiles, head to the north: the steel frame
    and the rails, the pillow and the sheet; the foot, `foot`, with its
    board and the chart hung on it. Some are empty, some bloody."""
    rect(d, px + 1, py, 14, TILE, HS_METAL_DARK)
    rect(d, px + 2, py, 12, TILE, HS_SHEET)
    rect(d, px + 2, py, 1, TILE, HS_METAL)
    rect(d, px + 13, py, 1, TILE, HS_METAL)
    if not foot:
        rect(d, px + 1, py, 14, 3, HS_METAL)  # headboard
        rect(d, px + 1, py, 14, 1, HS_METAL_LIGHT)
        rect(d, px + 4, py + 4, 8, 4, HS_WHITE)  # pillow
        rect(d, px + 4, py + 7, 8, 1, HS_SHEET_SHADE)
        rect(d, px + 2, py + 10, 12, 6, (190, 212, 214))  # the blanket
        rect(d, px + 2, py + 10, 12, 1, HS_SHEET_SHADE)
    else:
        rect(d, px + 2, py, 12, 11, (190, 212, 214))
        for fy in (py + 3, py + 7):
            rect(d, px + 2, fy, 12, 1, (170, 194, 198))
        rect(d, px + 1, py + 11, 14, 4, HS_METAL)  # footboard
        rect(d, px + 1, py + 11, 14, 1, HS_METAL_LIGHT)
        rect(d, px + 5, py + 12, 5, 3, HS_PAPER)  # the chart
        rect(d, px + 3, py + 15, 2, 1, OUTLINE)
        rect(d, px + 11, py + 15, 2, 1, OUTLINE)
    roll = rng.random()
    if roll < 0.35:
        rect(d, px + 5 + rng.randrange(4), py + rng.randrange(2, 8), 5, 4,
             BLOOD)
        rect(d, px + 7, py + 9, 2, 2, BLOOD_DARK)
    elif roll < 0.5 and foot:  # the blanket thrown off
        rect(d, px + 2, py, 12, 11, HS_SHEET)
        rect(d, px + 3, py + 2, 5, 6, (190, 212, 214))


def paint_bedside_table(d, px, py):
    """A bedside cabinet: a jug of water and the patient's pills."""
    rect(d, px + 3, py + 4, 10, 11, HS_WHITE_SHADE)
    rect(d, px + 3, py + 4, 10, 1, HS_WHITE)
    rect(d, px + 4, py + 9, 8, 1, HS_METAL)
    rect(d, px + 7, py + 11, 2, 1, HS_METAL_DARK)
    rect(d, px + 4, py + 1, 3, 4, HS_GLASS)
    rect(d, px + 9, py + 2, 3, 2, (220, 180, 70))


def paint_drip_stand(d, px, py):
    """A drip stand: the pole on its feet, the bag hung at the top, the
    tube trailing."""
    rect(d, px + 7, py - 9, 2, 23, HS_METAL)
    rect(d, px + 4, py + 14, 8, 1, HS_METAL_DARK)
    rect(d, px + 3, py + 15, 2, 1, OUTLINE)
    rect(d, px + 11, py + 15, 2, 1, OUTLINE)
    rect(d, px + 5, py - 11, 6, 1, HS_METAL)
    rect(d, px + 3, py - 10, 5, 7, (200, 226, 232))
    rect(d, px + 4, py - 6, 3, 2, (170, 206, 214))
    rect(d, px + 5, py - 3, 1, 8, (200, 220, 226))


def paint_monitor(d, px, py):
    """A monitor on its trolley, the line gone flat."""
    rect(d, px + 4, py + 6, 8, 8, HS_METAL)
    rect(d, px + 3, py + 14, 10, 1, HS_METAL_DARK)
    rect(d, px + 3, py + 15, 2, 1, OUTLINE)
    rect(d, px + 11, py + 15, 2, 1, OUTLINE)
    rect(d, px + 2, py - 5, 12, 11, (40, 44, 50))
    rect(d, px + 3, py - 4, 10, 8, (14, 30, 22))
    rect(d, px + 3, py, 10, 1, HS_GREEN)
    rect(d, px + 11, py - 3, 1, 1, HS_RED)


def paint_linen_shelves(d, rng, px, py):
    """Steel shelves of folded sheets and towels, some pulled down."""
    rect(d, px + 1, py - 8, 14, 23, HS_METAL_DARK)
    for sy in (py - 7, py - 1, py + 5):
        rect(d, px + 2, sy + 5, 12, 1, HS_METAL)
        x = px + 2
        while x < px + 12:
            if rng.random() < 0.75:
                rect(d, x, sy + 1, 4, 4, rng.choice(
                    (HS_SHEET, (190, 212, 214), (150, 186, 200))))
                rect(d, x, sy + 3, 4, 1, HS_SHEET_SHADE)
            x += 5


# --------------------------------------------------------------- rules


def floor_rules(atlas: Atlas, rng, floored: str) -> list[dict]:
    rules = [rule("ground", floored, [atlas.bucket(lambda: tile_of(
        lambda d: paint_floor(d, rng, 0, 0)))])]
    for right in (False, True):
        rules.append(rule(
            "ground", floored,
            [[], atlas.bucket(lambda r=right: tile_of(
                lambda d: paint_edge(d, 0, 0, r)), 1)],
            [neighbour_key(1 if right else -1, 0, "x")]))
    return rules


def hospital_floor(atlas: Atlas, rng, glyphs: str) -> dict:
    """The rules of one of the hospital's floors: the room, then only the
    furniture `glyphs` it has."""
    floored = ".:b*+ZdUDE" + "CTAhLVpsrHBnfMS"
    rules = floor_rules(atlas, rng, floored)

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
        "structures", "WN",
        [atlas.bucket(lambda u=upper: tile_of(
            lambda d: paint_wall(d, rng, 0, 0, u)))
         for upper in (False, True)],
        [neighbour_key(0, 1, "xWNw")]))
    buckets, up = lean(lambda i: lambda d, px, py:
                       paint_notice_board(d, rng, px, py))
    rules.append(rule("structures", "N", buckets, pieces=up))
    rules.append(rule(
        "structures", "I",
        [atlas.bucket(lambda b=below: tile_of(
            lambda d: paint_partition(d, 0, 0, b)), 1)
         for below in (False, True)],
        [neighbour_key(0, 1, HS_WALLS)]))
    rules.append(rule("structures", "w", one(paint_front_wall)))
    rules.append(rule("structures", "d", one(paint_doorway)))
    rules.append(rule("structures", "D", one(paint_stairs_down)))
    rules.append(rule("structures", ":", randomly(paint_papers)))
    rules.append(rule("structures", "b", randomly(paint_blood)))
    if "E" in glyphs:
        rules.append(rule("structures", "E", [atlas.bucket(
            lambda r=right: tile_of(lambda d: paint_glass_door(d, 0, 0, r)),
            1) for right in (False, True)], [neighbour_key(-1, 0, "E")]))

    if "C" in glyphs:
        keys = [neighbour_key(-1, 0, "C"), neighbour_key(1, 0, "C")]
        buckets, up = lean(lambda i: lambda d, px, py: paint_counter(
            d, px, py, not i & 1, not i & 2), keys, 1)
        rules.append(rule("structures", "C", buckets, keys, up))
    # Two-cell pieces, painted whole and cut: the key says whether the
    # cell to the left is the same, which makes this its right half.
    for glyph, paint in (("T", paint_desk), ("L", paint_couch),
                         ("s", paint_stretcher)):
        if glyph in glyphs:
            pair = [neighbour_key(-1, 0, glyph)]
            buckets, up = lean(lambda i, p=paint: lambda d, px, py: p(
                d, rng, px - TILE * i, py), pair)
            rules.append(rule("structures", glyph, buckets, pair, up))
    if "h" in glyphs:
        keys = [neighbour_key(-1, 0, "h"), neighbour_key(1, 0, "h")]
        rules.append(rule("structures", "h", [atlas.bucket(
            lambda i=index: tile_of(lambda d: paint_waiting_chair(
                d, 0, 0, bool(i & 1), bool(i & 2))), 1)
            for index in range(4)], keys))
    for glyph, paint in (("A", paint_cupboard), ("V", paint_vending_machine),
                         ("H", paint_basin), ("f", paint_drip_stand),
                         ("M", paint_monitor)):
        if glyph in glyphs:
            buckets, up = lean(lambda i, p=paint: p, None, 1)
            rules.append(rule("structures", glyph, buckets, pieces=up))
    for glyph, paint in (("p", paint_plant), ("S", paint_linen_shelves)):
        if glyph in glyphs:
            buckets, up = lean(lambda i, p=paint: lambda d, px, py: p(
                d, rng, px, py))
            rules.append(rule("structures", glyph, buckets, pieces=up))
    for glyph, paint in (("r", paint_wheelchair),
                         ("n", paint_bedside_table)):
        if glyph in glyphs:
            rules.append(rule("structures", glyph, one(paint)))
    if "B" in glyphs:
        rules.append(rule("structures", "B", [atlas.bucket(
            lambda f=foot: tile_of(lambda d: paint_bed(d, rng, 0, 0, f)))
            for foot in (False, True)], [neighbour_key(0, -1, "B")]))

    objects = []
    if "U" in glyphs:
        objects.append({"glyph": "U", "image": "hospital_stairs_up.png",
                        "offsetY": -1, "sprite": stair_door()})
    return {"void": "#000000", "voidGlyph": "x", "rules": rules,
            "objects": objects}


def hospital_first_floor(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.hospitalFirstFloor."""
    return hospital_floor(atlas, rng, "ECTAhLVpsrHU")


def hospital_second_floor(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.hospitalSecondFloor."""
    return hospital_floor(atlas, rng, "CTAsrBnfSU")


def hospital_third_floor(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.hospitalThirdFloor."""
    return hospital_floor(atlas, rng, "AsrBnfMSU")


# ------------------------------------------------------------ the roof
# The roofs past the airliner's painters, laid out the other way round:
# the next block is east of this one, not south, and the stretch Mario
# looks over is in a wall running north to south. The next block is built
# like this one, walls, parapet and felt: only its stairwell going down
# is its own.


def near(glyph, **shown):
    """The neighbourhood of a cell of `glyph` at (0, 0), in which the named
    neighbours (`l`, `r`, `u`) show what is given and the rest is bare."""
    offsets = {"l": (-1, 0), "r": (1, 0), "u": (0, -1), "d": (0, 1)}
    cells = {offsets[k]: v for k, v in shown.items()}
    return Neighbourhood(glyph, lambda x, y: cells.get((x, y), "."))


def paint_roof_deck(d, rng, px, py, odd):
    """The felt of the hospital's roof, laid in strips east to west."""
    base = airliner.TAR_ALT if odd else airliner.TAR
    rect(d, px, py, TILE, TILE, base)
    for _ in range(6):
        rect(d, px + rng.randrange(15), py + rng.randrange(15), 1, 1,
             shade(rng.choice(airliner.GRAVEL), -34))
    if not odd:
        rect(d, px, py, TILE, 1, shade(base, -10))


def paint_side_lookout(d, px, py):
    """The east wall knocked down to its last course where Mario looks
    over at the next block: a stump of the same brick, its coping broken
    off and fallen back on the roof, the ends of the wall either side
    standing over it, and the drop beyond."""
    rect(d, px, py, TILE, TILE, airliner.TAR_LOW)
    rect(d, px + 11, py, 5, TILE, airliner.DROP)
    rect(d, px + 7, py, 4, TILE, airliner.BRICK_DARK)
    for course, sy in enumerate(range(py + 1, py + TILE, 4)):
        rect(d, px + 7, sy, 4, 3, airliner.BRICK)
    for sx, sy in ((1, 3), (3, 8), (1, 12)):
        rect(d, px + sx, py + sy, 5, 2, airliner.COPING_DARK)
    # the ends of the wall either side, brick and coping as whole
    for sy in (0, TILE - 3):
        rect(d, px + 1, py + sy, 14, 3, airliner.BRICK)
        rect(d, px + 13, py + sy, 3, 3, airliner.COPING)


def paint_roof_hatch(d, px, py):
    """The hatch the stairs come up through: a concrete kerb round the
    opening, the lid thrown back, the top of the steps in the dark."""
    rect(d, px + 1, py + 1, 14, 14, shade(airliner.COPING, -20))
    rect(d, px + 1, py + 1, 14, 1, airliner.COPING)
    rect(d, px + 3, py + 4, 10, 10, airliner.DROP)
    for step in range(3):
        rect(d, px + 3, py + 5 + step * 3, 10, 2,
             shade(airliner.COPING, -50 - step * 24))
    rect(d, px + 1, py + 14, 14, 2, airliner.COPING_SHADOW)


def hospital_roof(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.hospitalRoof."""
    def one(paint):
        return [atlas.bucket(lambda: tile_of(lambda d: paint(d, 0, 0)), 1)]

    def randomly(paint):
        return [atlas.bucket(lambda: tile_of(lambda d: paint(d, rng, 0, 0)))]

    rules = [rule("ground", ".:bTnSDv", [atlas.bucket(
        lambda o=odd: tile_of(lambda d: paint_roof_deck(d, rng, 0, 0, o)))
        for odd in (False, True)], [pattern_key(0, 1, 2, 1)])]

    walls = []
    for index in range(8):
        left, right, beyond = (bool(index & 1), bool(index & 2),
                               bool(index & 4))
        room = near("W", l="W" if left else ".",
                    r="W" if right else ("x" if beyond else "."))
        walls.append(atlas.bucket(lambda rm=room: tile_of(
            lambda d: airliner.roof_wall(d, rm, 0, 0)), 1))
    rules.append(rule("structures", "W", walls,
                      [neighbour_key(-1, 0, "W"), neighbour_key(1, 0, "W"),
                       neighbour_key(1, 0, "xW")]))
    rules.append(rule("structures", "^", [atlas.bucket(
        lambda c=corner: tile_of(lambda d: airliner.roof_parapet(
            d, near("^", u="W" if c else "."), 0, 0, False)), 1)
        for corner in (False, True)], [neighbour_key(0, -1, "W")]))
    rules.append(rule("structures", ">", one(paint_side_lookout)))
    rules.append(rule("structures", "<", [atlas.bucket(lambda: tile_of(
        lambda d: airliner.roof_wall_breach(d, near("<", r="."), 0, 0)),
        1)]))
    rules.append(rule("structures", ":", randomly(airliner.roof_rubble)))
    rules.append(rule("structures", "b", randomly(airliner.roof_blood)))
    rules.append(rule("structures", "T", randomly(airliner.roof_stack)))
    rules.append(rule("structures", "n", one(airliner.roof_mast)))
    rules.append(rule("structures", "S", one(paint_campfire)))
    rules.append(rule("structures", "D", one(paint_roof_hatch)))

    # The stairwell going down into the next block: the airliner's, which
    # knows its own glyph as `S`.
    rules.append(rule(
        "structures", "v",
        [atlas.bucket(lambda i=i: tile_of(
            lambda d: airliner.roof_stairs_down(
                d, near("S", u="S" if i & 1 else ".",
                        l="S" if i & 2 else ".",
                        r="S" if i & 4 else "."), 0, 0)), 1)
         for i in range(8)],
        [neighbour_key(0, -1, "v"), neighbour_key(-1, 0, "v"),
         neighbour_key(1, 0, "v")]))
    return {"void": "#000000", "voidGlyph": "x", "rules": rules,
            "objects": []}


PLACES = {
    "hospitalFirstFloor": hospital_first_floor,
    "hospitalSecondFloor": hospital_second_floor,
    "hospitalThirdFloor": hospital_third_floor,
    "hospitalRoof": hospital_roof,
}

PREVIEW_ROWS = {
    "hospitalFirstFloor": "hospital-first-rows",
    "hospitalSecondFloor": "hospital-second-rows",
    "hospitalThirdFloor": "hospital-third-rows",
    "hospitalRoof": "hospital-roof-rows",
}
