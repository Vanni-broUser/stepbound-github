"""The company past the palazzo in the tile atlas: the ground floor of the
call centre in the shed on the street out of the palazzo
(lib/core/levels/hometown/company.dart).

A module of its own, the way docs/level_pipeline.md wants the interiors to
go: build_tile_atlas.py only lists it. An open-plan office seen from above
like the palazzo's rooms: blue-grey carpet tiles under the workstations,
grey vinyl at the gate, along the corridor and in the break corner, pale
walls with a blue skirting, and down the middle the glass wall between the
two wings. Rows of cubicles, their fabric panels, beige computers with
their screens still lit, office chairs; in the corridor the heap the staff
built out of all of it. What stands taller than its cell leans out over
the row above (`leaning`).
"""
from __future__ import annotations

import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import street_props as props  # noqa: E402
import tile_atlas_palazzo as palazzo  # noqa: E402
from street_paint import (  # noqa: E402
    BLOOD,
    BLOOD_DARK,
    TILE,
    read_rows,
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

CO_WALL_TOP = (46, 50, 58)
CO_WALL_TOP_LIGHT = (74, 80, 92)
CO_WALL = (206, 208, 200)
CO_WALL_DARK = (176, 180, 174)
CO_SKIRTING = (58, 78, 112)
CO_CARPET = (70, 82, 100)
CO_CARPET_ALT = (64, 76, 93)
CO_CARPET_SEAM = (56, 66, 82)
CO_VINYL = (162, 164, 160)
CO_VINYL_SPECK = (138, 140, 138)
CO_VINYL_SEAM = (128, 130, 128)
CO_LAMINATE = (196, 190, 174)
CO_LAMINATE_EDGE = (140, 134, 120)
CO_BEIGE = (206, 200, 178)
CO_BEIGE_SHADE = (160, 154, 134)
CO_SCREEN = (60, 150, 130)
CO_SCREEN_GLOW = (140, 220, 190)
CO_FABRIC = (82, 96, 124)
CO_FABRIC_SHADE = (62, 74, 98)
CO_RAIL = (156, 160, 166)
CO_BLACK = (26, 26, 30)
CO_CHAIR = (40, 42, 48)
CO_CHAIR_LIGHT = (70, 72, 80)
CO_STEEL = (150, 154, 160)
CO_STEEL_DARK = (92, 96, 104)
CO_GLASS = (150, 206, 222, 110)
CO_GLASS_SHINE = (220, 244, 250, 170)
CO_WOOD = (132, 92, 56)
CO_WOOD_LIGHT = (160, 116, 74)
CO_PAPER = (232, 230, 220)
CO_DAYLIGHT = (238, 222, 170)
CO_YELLOW = (220, 180, 40)
CO_WALLS = "xWwIG"


def image_of(d) -> Image.Image:
    """The picture an ImageDraw draws on: the bodies are pasted sprites."""
    return d._image  # noqa: SLF001 - Pillow keeps it there


# ------------------------------------------------------------ the floors


def paint_carpet(d, rng, px, py):
    """Carpet tiles, two to a cell each way, laid in alternate directions,
    worn and stained."""
    for i in (0, 8):
        for j in (0, 8):
            colour = CO_CARPET if (i + j) // 8 % 2 == 0 else CO_CARPET_ALT
            rect(d, px + i, py + j, 8, 8, colour)
            for k in range(1, 8, 2):  # the pile's direction
                if (i + j) // 8 % 2 == 0:
                    rect(d, px + i + k, py + j + 1, 1, 6, shade(colour, 6))
                else:
                    rect(d, px + i + 1, py + j + k, 6, 1, shade(colour, 6))
    rect(d, px, py, TILE, 1, CO_CARPET_SEAM)
    rect(d, px, py, 1, TILE, CO_CARPET_SEAM)
    if rng.random() < 0.2:  # a coffee stain
        rect(d, px + rng.randrange(2, 10), py + rng.randrange(2, 10), 4, 3,
             (84, 74, 70))


def paint_vinyl(d, rng, px, py):
    """Grey speckled vinyl in wide sheets, a seam across now and then."""
    rect(d, px, py, TILE, TILE, CO_VINYL)
    for _ in range(9):
        rect(d, px + rng.randrange(TILE), py + rng.randrange(TILE), 1, 1,
             CO_VINYL_SPECK)
    if rng.random() < 0.3:
        rect(d, px, py + rng.randrange(2, 14), TILE, 1, CO_VINYL_SEAM)
    if rng.random() < 0.15:  # a scuff from the trolleys
        rect(d, px + rng.randrange(1, 8), py + rng.randrange(3, 12), 7, 1,
             shade(CO_VINYL, -34))


def paint_edge(d, px, py, right):
    """Thin wall edge where the floor meets the darkness at the side."""
    rect(d, px + (12 if right else 0), py, 4, TILE, CO_WALL_TOP)
    rect(d, px + (12 if right else 3), py, 1, TILE, CO_WALL_TOP_LIGHT)


# -------------------------------------------------------------- the walls


def paint_wall(d, rng, px, py, upper):
    """The back wall seen face on, two tiles tall: the suspended ceiling's
    edge and the pale plaster, and on the lower course the blue skirting,
    with what hangs on an office wall."""
    if upper:
        rect(d, px, py, TILE, 5, CO_WALL_TOP)
        rect(d, px, py + 5, TILE, 11, CO_WALL)
        rect(d, px, py + 5, TILE, 1, CO_WALL_TOP_LIGHT)
        roll = rng.random()
        if roll < 0.12:  # a high window of the shed, the night outside
            rect(d, px + 2, py + 8, 12, 6, CO_STEEL_DARK)
            rect(d, px + 3, py + 9, 10, 4, (24, 30, 44))
            rect(d, px + 3, py + 9, 3, 1, (70, 84, 110))
        elif roll < 0.15:  # the clock, stopped
            rect(d, px + 5, py + 8, 6, 6, CO_BLACK)
            rect(d, px + 6, py + 9, 4, 4, CO_PAPER)
            rect(d, px + 8, py + 10, 1, 2, CO_BLACK)
        return
    rect(d, px, py, TILE, 13, CO_WALL)
    rect(d, px, py + 13, TILE, 3, CO_SKIRTING)
    roll = rng.random()
    if roll < 0.06:  # a whiteboard, the targets of the week on it
        rect(d, px + 1, py + 1, 14, 9, CO_STEEL)
        rect(d, px + 2, py + 2, 12, 7, (240, 242, 238))
        for ly in (py + 3, py + 5, py + 7):
            rect(d, px + 3, ly, rng.randint(5, 10), 1, (60, 90, 170))
        rect(d, px + 9, py + 3, 3, 3, (200, 50, 50))
    elif roll < 0.1:  # a poster: SORRIDI, IL CLIENTE TI SENTE
        rect(d, px + 3, py + 1, 10, 10, (60, 120, 190))
        rect(d, px + 5, py + 3, 6, 3, CO_YELLOW)
        rect(d, px + 4, py + 7, 8, 1, CO_PAPER)
        rect(d, px + 4, py + 9, 6, 1, CO_PAPER)
    elif roll < 0.12:  # a smear of blood down it
        sx = px + rng.randrange(2, 12)
        rect(d, sx, py + 1, 3, 5, BLOOD)
        rect(d, sx + 1, py + 6, 1, rng.randint(3, 6), BLOOD_DARK)
    elif roll < 0.14:  # the fire extinguisher on its bracket
        rect(d, px + 5, py + 2, 6, 1, CO_STEEL_DARK)
        rect(d, px + 6, py + 3, 4, 9, (200, 36, 36))
        rect(d, px + 7, py + 4, 1, 6, (236, 110, 100))
        rect(d, px + 6, py + 5, 4, 2, CO_PAPER)
        rect(d, px + 9, py + 2, 3, 1, CO_BLACK)


def paint_partition(d, px, py, wall_below):
    """An inner wall: its top seen from above, and its painted face where
    the floor is below it."""
    if wall_below:
        rect(d, px, py, TILE, TILE, CO_WALL_TOP)
        rect(d, px + 1, py, TILE - 2, TILE, CO_WALL_TOP_LIGHT)
        rect(d, px + 3, py, TILE - 6, TILE, CO_WALL_TOP)
        return
    rect(d, px, py, TILE, 6, CO_WALL_TOP)
    rect(d, px, py, TILE, 1, CO_WALL_TOP_LIGHT)
    rect(d, px, py + 6, TILE, 7, CO_WALL)
    rect(d, px, py + 13, TILE, 3, CO_SKIRTING)


def paint_glass(d, rng, px, py, upright):
    """A glass wall on its aluminium frame. Running up and down the room,
    `upright`, it is seen edge on: the carpet either side of it through
    the glass, the frame's rail down the middle. Running across, it is seen
    face on: the carpet behind it, tinted, the frame round it."""
    paint_carpet(d, rng, px, py)
    if upright:
        rect(d, px + 3, py, 10, TILE, CO_GLASS)
        rect(d, px + 3, py, 1, TILE, CO_STEEL)
        rect(d, px + 12, py, 1, TILE, CO_STEEL_DARK)
        rect(d, px + 7, py, 2, TILE, CO_STEEL)
        rect(d, px + 7, py, 1, TILE, (200, 204, 210))
        rect(d, px + 4, py + 2, 1, 6, CO_GLASS_SHINE)
        rect(d, px + 10, py + 9, 1, 4, CO_GLASS_SHINE)
        return
    rect(d, px, py + 1, TILE, 13, CO_GLASS)
    rect(d, px, py, TILE, 2, CO_STEEL)
    rect(d, px, py + 13, TILE, 3, CO_STEEL_DARK)
    for sx, sy in ((3, 3), (4, 4), (5, 5), (10, 3), (11, 4)):
        rect(d, px + sx, py + sy, 2, 1, CO_GLASS_SHINE)


def paint_front_wall(d, px, py):
    rect(d, px, py, TILE, 7, CO_WALL_TOP)
    rect(d, px, py, TILE, 1, CO_WALL_TOP_LIGHT)
    rect(d, px, py + 7, TILE, 9, (6, 6, 8))


def paint_gate(d, px, py):
    """The gate in from the street, seen from inside: the steel shutter
    rolled up into its drum overhead, and the grey light of the street
    through the opening."""
    rect(d, px, py, TILE, TILE, CO_DAYLIGHT)
    rect(d, px, py, TILE, 4, CO_STEEL_DARK)
    rect(d, px, py + 1, TILE, 1, CO_STEEL)
    rect(d, px, py + 4, TILE, 1, CO_BLACK)
    for sx in range(px + 1, px + TILE, 4):  # the grooves on the floor
        rect(d, sx, py + 13, 2, 1, (190, 176, 130))


def paint_doorway(d, px, py):
    """A doorway into an office: its aluminium frame on the floor, the door
    long gone."""
    rect(d, px, py, TILE, 2, CO_STEEL_DARK)
    rect(d, px, py, 2, 12, CO_STEEL)
    rect(d, px + TILE - 2, py, 2, 12, CO_STEEL)


def paint_side_doorway(d, px, py):
    """paint_doorway's frame in a side wall (see
    tile_atlas_palazzo.paint_side_door): the door long gone."""
    palazzo.paint_side_door(d, px, py, CO_WALL_TOP, CO_WALL_TOP_LIGHT,
                            CO_STEEL, CO_STEEL, CO_STEEL_DARK, CO_STEEL,
                            CO_VINYL, CO_VINYL_SEAM, "gone")


def stair_door() -> Image.Image:
    """The way up, two tiles high in the back wall: a concrete flight with
    yellow nosings climbing into the dark behind the wall, its steel
    railing either side."""
    image = Image.new("RGBA", (TILE, TILE * 2), TRANSPARENT)
    d = ImageDraw.Draw(image)
    height = TILE * 2
    rect(d, 0, 0, TILE, height, CO_WALL_TOP)
    rect(d, 1, 5, TILE - 2, height - 5, (16, 16, 18))
    for step in range(6):
        y = height - 3 - step * 4
        rect(d, 1, y, TILE - 2, 3, shade((150, 150, 146), -step * 22))
        rect(d, 1, y, TILE - 2, 1, shade(CO_YELLOW, -step * 26))
    for x in (1, TILE - 3):
        rect(d, x, 6, 2, height - 7, CO_STEEL_DARK)
        rect(d, x, 6, 2, 1, CO_STEEL)
    return image


# ---------------------------------------------------------- the offices


def paint_workstation(d, rng, px, py, facing_in):
    """A cubicle's desk with its computer, the way the operators left it:
    `facing_in`, the screen towards the room, still lit, the keyboard and
    the headset before it; otherwise the back of the monitor, its cables
    hanging. It leans up into the row above: the screen stands taller than
    the desk."""
    rect(d, px, py + 2, TILE, 9, CO_LAMINATE)
    rect(d, px, py + 10, TILE, 2, CO_LAMINATE_EDGE)
    rect(d, px + 2, py + 12, 2, 3, CO_STEEL_DARK)  # its legs
    rect(d, px + 12, py + 12, 2, 3, CO_STEEL_DARK)
    lit = rng.random() < 0.7
    if facing_in:
        rect(d, px + 3, py - 7, 10, 10, CO_BEIGE)
        rect(d, px + 3, py + 2, 10, 1, CO_BEIGE_SHADE)
        rect(d, px + 4, py - 6, 8, 7, CO_SCREEN if lit else (30, 34, 36))
        if lit:
            rect(d, px + 5, py - 5, 4, 1, CO_SCREEN_GLOW)
            rect(d, px + 5, py - 3, 5, 1, CO_SCREEN_GLOW)
        rect(d, px + 6, py + 3, 4, 1, CO_BEIGE_SHADE)  # the stand
        rect(d, px + 3, py + 6, 9, 3, (220, 216, 200))  # the keyboard
        for kx in range(px + 4, px + 11, 2):
            rect(d, kx, py + 7, 1, 1, CO_BEIGE_SHADE)
        if rng.random() < 0.5:  # the headset left on the desk
            rect(d, px + 12, py + 5, 3, 1, CO_BLACK)
            rect(d, px + 12, py + 6, 1, 2, CO_BLACK)
        return
    rect(d, px + 3, py - 5, 10, 10, CO_BEIGE_SHADE)
    rect(d, px + 4, py - 4, 8, 8, CO_BEIGE)
    for vy in (py - 2, py, py + 2):  # its vents
        rect(d, px + 5, vy, 6, 1, CO_BEIGE_SHADE)
    rect(d, px + 7, py + 5, 1, 5, CO_BLACK)  # the cables
    if rng.random() < 0.5:
        rect(d, px + 1, py + 4, 4, 5, CO_PAPER)


def paint_panel_across(d, px, py):
    """A cubicle's back panel, seen face on: grey-blue fabric on a steel
    rail, standing across the row."""
    rect(d, px, py + 5, TILE, 1, CO_RAIL)
    rect(d, px, py + 6, TILE, 8, CO_FABRIC)
    for fx in range(px + 1, px + TILE, 3):
        rect(d, fx, py + 7, 1, 6, CO_FABRIC_SHADE)
    rect(d, px, py + 14, TILE, 1, CO_FABRIC_SHADE)
    rect(d, px, py + 15, TILE, 1, (40, 46, 58))


def paint_panel_upright(d, px, py, desk):
    """The panel between two cubicles, seen edge on down the middle of the
    cell; with a `desk` either side, the desk runs under it."""
    if desk:
        rect(d, px, py + 2, TILE, 9, CO_LAMINATE)
        rect(d, px, py + 10, TILE, 2, CO_LAMINATE_EDGE)
    rect(d, px + 6, py - 4, 4, TILE + 3, CO_FABRIC)
    rect(d, px + 6, py - 4, 4, 1, CO_RAIL)
    rect(d, px + 9, py - 3, 1, TILE + 2, CO_FABRIC_SHADE)


def paint_chair(d, px, py, facing_out):
    """An office chair on its five castors. `facing_out`, the operator sat
    looking towards the room, the backrest behind; otherwise towards the
    desk to the north, the backrest towards us."""
    rect(d, px + 7, py + 11, 2, 2, CO_STEEL_DARK)  # the column
    for dx in (3, 7, 11):  # the castors
        rect(d, px + dx, py + 13, 2, 2, CO_BLACK)
    rect(d, px + 3, py + 6, 10, 5, CO_CHAIR)  # the seat
    rect(d, px + 4, py + 6, 8, 1, CO_CHAIR_LIGHT)
    if facing_out:
        rect(d, px + 4, py, 8, 6, CO_CHAIR)
        rect(d, px + 5, py + 1, 6, 1, CO_CHAIR_LIGHT)
    else:
        rect(d, px + 4, py + 5, 8, 7, CO_CHAIR)
        rect(d, px + 5, py + 6, 6, 1, CO_CHAIR_LIGHT)


def paint_counter(d, rng, px, py, first, last):
    """The reception counter, in a run: a wooden front with the company's
    stripe, a pale top, a bell and a pile of forms."""
    rect(d, px, py - 2, TILE, 5, CO_LAMINATE)
    rect(d, px, py + 3, TILE, 11, CO_WOOD)
    rect(d, px, py + 6, TILE, 2, (60, 120, 190))
    rect(d, px, py + 14, TILE, 2, shade(CO_WOOD, -40))
    if first:
        rect(d, px, py - 2, 2, 16, shade(CO_WOOD, -24))
    if last:
        rect(d, px + TILE - 2, py - 2, 2, 16, shade(CO_WOOD, -24))
    if rng.random() < 0.4:
        rect(d, px + 3, py - 3, 5, 3, CO_PAPER)
    if rng.random() < 0.3:
        rect(d, px + 10, py - 3, 3, 2, (200, 180, 90))


def paint_table(d, px, py, edges):
    """The meeting table in the manager's office, cell by cell: wood, a
    darker edge where the table ends. `edges` = (left, up, right, down)."""
    rect(d, px, py, TILE, TILE, CO_WOOD_LIGHT)
    for gx in range(px + 2, px + TILE, 5):
        rect(d, gx, py, 1, TILE, CO_WOOD)
    left, up, right, down = edges
    if left:
        rect(d, px, py, 2, TILE, shade(CO_WOOD, -30))
    if up:
        rect(d, px, py, TILE, 2, shade(CO_WOOD, -10))
    if right:
        rect(d, px + TILE - 2, py, 2, TILE, shade(CO_WOOD, -30))
    if down:
        rect(d, px, py + TILE - 3, TILE, 3, shade(CO_WOOD, -40))


def paint_cabinet(d, rng, px, py):
    """A grey filing cabinet, four drawers, one of them pulled out."""
    rect(d, px + 2, py - 6, 12, 21, CO_STEEL)
    rect(d, px + 2, py - 6, 12, 1, (190, 194, 200))
    open_drawer = rng.randrange(4)
    for i, sy in enumerate(range(py - 4, py + 14, 5)):
        rect(d, px + 3, sy, 10, 4, CO_STEEL_DARK if i == open_drawer
             else shade(CO_STEEL, -12))
        rect(d, px + 7, sy + 1, 2, 1, CO_BLACK)
    rect(d, px + 3, py + 15, 10, 1, (40, 42, 46))


def paint_copier(d, rng, px, py):
    """The photocopier, its lid up, jammed paper hanging out of it."""
    rect(d, px + 1, py - 2, 14, 16, (216, 214, 206))
    rect(d, px + 1, py - 2, 14, 3, (150, 152, 150))
    rect(d, px + 3, py - 6, 10, 4, (60, 64, 70))  # the lid, up
    rect(d, px + 2, py + 4, 12, 1, (170, 170, 164))
    rect(d, px + 11, py + 1, 2, 2, (80, 200, 80))
    rect(d, px + 4, py + 8, 7, 4, CO_PAPER)
    rect(d, px + 1, py + 14, 14, 1, (40, 42, 46))


def paint_vending(d, rng, px, py):
    """A vending machine, its glass smashed in and emptied."""
    rect(d, px + 1, py - 10, 14, 25, (170, 30, 36))
    rect(d, px + 2, py - 8, 9, 18, (30, 34, 40))
    for sy in range(py - 7, py + 9, 4):
        rect(d, px + 2, sy, 9, 1, CO_STEEL_DARK)
        if rng.random() < 0.4:
            rect(d, px + 3 + rng.randrange(6), sy - 2, 2, 2,
                 rng.choice(((230, 200, 60), (60, 160, 220), (220, 60, 60))))
    rect(d, px + 12, py - 6, 2, 6, (60, 60, 64))  # the coin slot
    for gx, gy in ((4, -5), (7, 0), (5, 4)):  # the broken glass
        rect(d, px + gx, py + gy, 2, 1, CO_GLASS_SHINE)
    rect(d, px + 1, py + 15, 14, 1, (40, 42, 46))


def paint_cooler(d, rng, px, py):
    """The water cooler, its big blue bottle still half full."""
    rect(d, px + 4, py + 1, 8, 14, (220, 222, 218))
    rect(d, px + 5, py + 5, 2, 2, (80, 120, 200))
    rect(d, px + 9, py + 5, 2, 2, (200, 60, 60))
    rect(d, px + 5, py - 7, 6, 8, (120, 180, 230))
    rect(d, px + 5, py - 3, 6, 4, (80, 140, 210))
    rect(d, px + 6, py - 6, 1, 4, (200, 230, 250))
    rect(d, px + 4, py + 15, 8, 1, (40, 42, 46))


def paint_heap(d, rng, px, py):
    """The heap across the corridor: desks on their sides, monitors,
    keyboards, chairs with their castors in the air, cables through all
    of it, piled higher than a man."""
    rect(d, px, py - 4, TILE, TILE + 4, (58, 60, 66))
    for _ in range(3):  # a desk top on its edge
        x, y = px + rng.randrange(-2, 8), py + rng.randrange(-6, 8)
        rect(d, x, y, rng.randint(8, 12), 3, CO_LAMINATE)
        rect(d, x, y + 3, rng.randint(6, 10), 1, CO_LAMINATE_EDGE)
    for _ in range(2):  # a monitor
        x, y = px + rng.randrange(0, 9), py + rng.randrange(-4, 8)
        rect(d, x, y, 7, 6, CO_BEIGE)
        rect(d, x + 1, y + 1, 5, 4, (30, 34, 36)
             if rng.random() < 0.6 else CO_SCREEN)
    if rng.random() < 0.6:  # a chair upside down
        x, y = px + rng.randrange(0, 8), py + rng.randrange(-5, 5)
        rect(d, x, y + 3, 8, 3, CO_CHAIR)
        for cx in (0, 3, 6):
            rect(d, x + cx, y, 2, 2, CO_BLACK)
    for _ in range(3):  # the cables
        x, y = px + rng.randrange(TILE), py + rng.randrange(-4, TILE)
        for step in range(5):
            rect(d, x + step, y + (step * 2) % 3, 1, 1, CO_BLACK)
    if rng.random() < 0.4:
        rect(d, px + rng.randrange(2, 12), py + rng.randrange(0, 10), 3, 2,
             BLOOD)
    rect(d, px, py + TILE - 1, TILE, 1, (30, 30, 34))


def paint_litter(d, rng, px, py):
    """Paper all over the floor, a snapped headset, a smashed keyboard."""
    for _ in range(4):
        rect(d, px + rng.randrange(1, 12), py + rng.randrange(1, 12),
             rng.randint(3, 4), rng.randint(2, 3), CO_PAPER)
    if rng.random() < 0.5:
        x, y = px + rng.randrange(2, 8), py + rng.randrange(3, 11)
        rect(d, x, y, 7, 3, (210, 206, 190))
        rect(d, x + 2, y + 1, 1, 1, CO_BEIGE_SHADE)
    else:
        rect(d, px + rng.randrange(3, 10), py + rng.randrange(3, 10), 4, 1,
             CO_BLACK)


# --------------------------------------------------------------- rules


FLOORS = (
    (".", paint_carpet),
    ("=", paint_vinyl),
)


def paint_stairs_down(d, px, py):
    """The top of a flight down, in the front wall: concrete treads with
    their yellow nosings going down into the dark, the steel railing down
    the side."""
    rect(d, px, py, TILE, TILE, (16, 16, 18))
    for step in range(4):
        inset = step * 2
        y = py + 2 + step * 3
        rect(d, px + inset, y, TILE - inset, 2,
             shade((150, 150, 146), -step * 30))
        rect(d, px + inset, y, TILE - inset, 1, shade(CO_YELLOW, -step * 34))
    rect(d, px + 14, py, 2, TILE, CO_STEEL_DARK)
    rect(d, px + 14, py, 2, 1, CO_STEEL)


def company_floor(atlas: Atlas, rng, marker: str, images: str) -> dict:
    """The rules that paint one of the company's floors, whose rows are
    between the `marker` lines; its flights up are drawn as `images`_west
    and _east."""
    rules = []
    for glyph, paint in FLOORS:
        rules.append(rule("ground", glyph, [atlas.bucket(
            lambda p=paint: tile_of(lambda d: p(d, rng, 0, 0)))]))
    everything = "".join(glyph for glyph, _ in FLOORS)
    for right in (False, True):
        rules.append(rule(
            "ground", everything,
            [[], atlas.bucket(lambda r=right: tile_of(
                lambda d: paint_edge(d, 0, 0, r)), 1)],
            [neighbour_key(1 if right else -1, 0, "x")]))

    def one(paint):
        return [atlas.bucket(lambda: tile_of(lambda d: paint(d, 0, 0)), 1)]

    def randomly(paint):
        return [atlas.bucket(lambda: tile_of(lambda d: paint(d, rng, 0, 0)))]

    # The back wall is two courses: the top one has wall below it. What
    # hangs on it is there now and then: the bare wall keeps its odds.
    rules.append(rule(
        "structures", "W",
        [atlas.odds(lambda u=upper: tile_of(
            lambda d: paint_wall(d, rng, 0, 0, u)), 24)
         for upper in (False, True)],
        [neighbour_key(0, 1, "xWw")]))
    rules.append(rule(
        "structures", "I",
        [atlas.bucket(lambda b=below: tile_of(
            lambda d: paint_partition(d, 0, 0, b)), 1)
         for below in (False, True)],
        # A door below a wall is in that wall: it runs on down into it.
        [neighbour_key(0, 1, CO_WALLS + "d")]))
    # Glass up and down the room where there is glass above or below it.
    rules.append(rule(
        "structures", "G",
        [atlas.bucket(lambda u=upright: tile_of(
            lambda d: paint_glass(d, rng, 0, 0, u)))
         for upright in (False, True)],
        [neighbour_key(0, 1, "G")]))
    rules.append(rule("structures", "w", one(paint_front_wall)))
    rules.append(rule("structures", "E", one(paint_gate)))
    # In a side wall -- one with a wall above the door -- the frame runs
    # along the wall (see tile_atlas_palazzo.paint_side_door).
    rules.append(rule("structures", "d", [one(paint_doorway)[0],
                                          one(paint_side_doorway)[0]],
                      [neighbour_key(0, -1, CO_WALLS)]))
    rules.append(rule("structures", "v", one(paint_stairs_down)))
    rules.append(rule("structures", ":", randomly(paint_litter)))
    rules.append(rule("structures", "b", randomly(palazzo.paint_blood)))
    buckets, pieces = spread(atlas, lambda i: lambda d, px, py:
                             props.paint_corpse(image_of(d), rng, px, py),
                             None, (1, 0, 1, 1), 12)
    rules.append(rule("structures", "c", buckets, None, pieces))

    # The workstations, their panels and chairs.
    for glyph, facing_in in (("D", True), ("B", False)):
        buckets, up = leaning(atlas, lambda i, f=facing_in: lambda d, px, py:
                              paint_workstation(d, rng, px, py, f))
        rules.append(rule("structures", glyph, buckets, pieces=up))
    rules.append(rule("structures", "-", one(paint_panel_across)))
    desk_beside = [neighbour_key(-1, 0, "DB")]
    buckets, up = leaning(atlas, lambda i: lambda d, px, py:
                          paint_panel_upright(d, px, py, bool(i & 1)),
                          desk_beside, 1)
    rules.append(rule("structures", "|", buckets, desk_beside, up))
    rules.append(rule("structures", "h", [atlas.bucket(
        lambda o=out: tile_of(lambda d: paint_chair(d, 0, 0, o)), 1)
        for out in (False, True)], [neighbour_key(0, 1, "B")]))

    # The runs: the keys say whether the run goes on either side.
    keys = [neighbour_key(-1, 0, "R"), neighbour_key(1, 0, "R")]
    buckets, up = leaning(atlas, lambda i: lambda d, px, py: paint_counter(
        d, rng, px, py, not i & 1, not i & 2), keys)
    rules.append(rule("structures", "R", buckets, keys, up))
    sides = [neighbour_key(-1, 0, "T"), neighbour_key(0, -1, "T"),
             neighbour_key(1, 0, "T"), neighbour_key(0, 1, "T")]
    rules.append(rule("structures", "T", [atlas.bucket(
        lambda i=index: tile_of(lambda d: paint_table(
            d, 0, 0, tuple(not i & (1 << bit) for bit in range(4)))), 1)
        for index in range(16)], sides))

    for glyph, paint in (("A", paint_cabinet), ("K", paint_copier),
                         ("V", paint_vending), ("F", paint_cooler),
                         ("p", palazzo.paint_plant), ("r", paint_heap)):
        buckets, up = leaning(atlas, lambda i, p=paint: lambda d, px, py: p(
            d, rng, px, py))
        rules.append(rule("structures", glyph, buckets, pieces=up))

    # One flight in each wing: each its own object, where it stands.
    rows = read_rows(marker)
    flights = [(x, y) for y, row in enumerate(rows)
               for x, glyph in enumerate(row) if glyph == "U"]
    objects = [{"glyph": "U", "image": f"{images}_{side}.png",
                "at": [x, y], "under": [rows[y][x]], "offsetY": -1,
                "sprite": stair_door()}
               for side, (x, y) in zip(("west", "east"), flights)]
    return {"void": "#000000", "voidGlyph": "x", "rules": rules,
            "objects": objects, "ground": GROUND}


# The floor under the furniture, the dead and the doors: the nearest one
# along the row, never through a wall, so a desk stands on the carpet and
# the vending machine on the vinyl of the break corner.
GROUND = ground_config(
    buildings=CO_WALLS,
    roads="",
    walks="",
    floors="".join(glyph for glyph, _ in FLOORS),
    footway="",
    keep="",
    lawn="",
    lawnProps="",
)


def company_ground(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.companyGround."""
    return company_floor(atlas, rng, "company-rows", "company_stairs_up")


def company_first(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.companyFirst."""
    return company_floor(atlas, rng, "company-first-rows",
                         "company_first_stairs_up")


def company_second(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.companySecond: no flight up."""
    return company_floor(atlas, rng, "company-second-rows",
                         "company_second_stairs_up")


PLACES = {
    "companyGround": company_ground,
    "companyFirst": company_first,
    "companySecond": company_second,
}

PREVIEW_ROWS = {
    "companyGround": "company-rows",
    "companyFirst": "company-first-rows",
    "companySecond": "company-second-rows",
}
