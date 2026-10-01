"""The bank on Via Marsala, in Rome, in the tile atlas: its offices under
the roof and the open vault under them (lib/core/levels/rome/bank.dart).

A module of its own, the way docs/level_pipeline.md wants the interiors to
go. A bank of the nineties gone to ruin: grey carpet, pale walls with the
bank's blue band, glass walls round the manager's office, desks with their
monitors, and downstairs polished granite, the safe-deposit boxes in their
brass rows and the vault's steel, its great round door swung open on
stripped shelves and banknotes all over the floor.
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

BK_TOP = (44, 46, 54)
BK_TOP_LIGHT = (78, 82, 94)
BK_WALL = (214, 214, 206)
BK_WALL_DARK = (176, 178, 172)
BK_BAND = (36, 70, 128)
BK_BAND_LIGHT = (70, 104, 160)
BK_CARPET = (96, 100, 108)
BK_CARPET_DOT = (80, 84, 92)
BK_GRANITE = (70, 72, 78)
BK_GRANITE_FLECK = ((120, 120, 126), (40, 40, 44), (150, 140, 130))
BK_STEEL = (128, 132, 138)
BK_STEEL_LIGHT = (170, 174, 180)
BK_STEEL_DARK = (78, 82, 88)
BK_BRASS = (196, 164, 84)
BK_BRASS_DARK = (140, 112, 50)
BK_DESK = (168, 150, 120)
BK_DESK_DARK = (120, 104, 80)
BK_BLACK = (24, 24, 28)
BK_SCREEN = (40, 54, 66)
BK_GLASS = (150, 186, 206)
BK_PAPER = (232, 230, 220)
BK_NOTE = (116, 152, 110)
BK_NOTE_DARK = (80, 112, 78)
BK_WALLS = "xWwIQB"


def image_of(d) -> Image.Image:
    return d._image  # noqa: SLF001 - Pillow keeps it there


# ------------------------------------------------------------ the floors


def paint_carpet(d, rng, px, py):
    """Grey office carpet in squares, a pattern of darker dots, stained."""
    rect(d, px, py, TILE, TILE, BK_CARPET)
    for i in range(0, TILE, 4):
        for j in range(0, TILE, 4):
            rect(d, px + i + 1, py + j + 1, 1, 1, BK_CARPET_DOT)
    rect(d, px, py, TILE, 1, shade(BK_CARPET, -12))
    rect(d, px, py, 1, TILE, shade(BK_CARPET, -12))
    if rng.random() < 0.2:
        rect(d, px + rng.randrange(1, 9), py + rng.randrange(1, 10), 6, 4,
             shade(BK_CARPET, -22))


def paint_granite(d, rng, px, py):
    """Polished dark granite in big slabs, flecked, the shine gone."""
    rect(d, px, py, TILE, TILE, BK_GRANITE)
    for _ in range(12):
        rect(d, px + rng.randrange(TILE), py + rng.randrange(TILE), 1, 1,
             rng.choice(BK_GRANITE_FLECK))
    rect(d, px, py, TILE, 1, (54, 56, 60))
    rect(d, px, py, 1, TILE, (54, 56, 60))
    rect(d, px + 3, py + 3, 5, 1, (96, 98, 106))  # what shine is left


def paint_steel_floor(d, rng, px, py):
    """The vault's floor: steel plate with its raised diamonds."""
    rect(d, px, py, TILE, TILE, BK_STEEL_DARK)
    for i in range(0, TILE, 4):
        for j in range(0, TILE, 4):
            off = 2 if (j // 4) % 2 else 0
            rect(d, px + (i + off) % TILE, py + j + 1, 2, 1, BK_STEEL)
    rect(d, px, py, TILE, 1, (60, 62, 68))


def paint_edge(d, px, py, right):
    rect(d, px + (12 if right else 0), py, 4, TILE, BK_TOP)
    rect(d, px + (12 if right else 3), py, 1, TILE, BK_TOP_LIGHT)


FLOORS = ((".", paint_carpet), ("=", paint_granite), (",", paint_steel_floor))


# -------------------------------------------------------------- the walls


def paint_wall(d, rng, px, py, upper):
    """The back wall, two tiles tall: the suspended ceiling's edge, the
    pale wall, and on the lower course the bank's blue band."""
    if upper:
        rect(d, px, py, TILE, 5, BK_TOP)
        rect(d, px, py + 5, TILE, 11, BK_WALL)
        rect(d, px, py + 5, TILE, 1, BK_TOP_LIGHT)
        if rng.random() < 0.2:  # a ceiling tile hanging down
            rect(d, px + rng.randrange(0, 8), py + 3, 8, 3, (190, 190, 184))
        return
    rect(d, px, py, TILE, 6, BK_WALL)
    rect(d, px, py + 6, TILE, 3, BK_BAND)
    rect(d, px, py + 6, TILE, 1, BK_BAND_LIGHT)
    rect(d, px, py + 9, TILE, 5, BK_WALL_DARK)
    rect(d, px, py + 14, TILE, 2, BK_TOP)
    roll = rng.random()
    if roll < 0.08:  # BANCA on a brass plate
        rect(d, px + 2, py + 1, 12, 4, BK_BRASS)
        rect(d, px + 3, py + 2, 10, 1, BK_BRASS_DARK)
    elif roll < 0.16:
        sx = px + rng.randrange(2, 12)
        rect(d, sx, py + 1, 3, 5, BLOOD)
        rect(d, sx + 1, py + 6, 1, rng.randint(3, 7), BLOOD_DARK)
    elif roll < 0.19:  # a clock stopped
        d.ellipse([px + 4, py, px + 11, py + 5], fill=BK_PAPER,
                  outline=BK_BLACK)
        rect(d, px + 7, py + 1, 1, 2, BK_BLACK)


def paint_partition(d, px, py, wall_below):
    if wall_below:
        rect(d, px, py, TILE, TILE, BK_TOP)
        rect(d, px + 1, py, TILE - 2, TILE, BK_TOP_LIGHT)
        rect(d, px + 3, py, TILE - 6, TILE, BK_TOP)
        return
    rect(d, px, py, TILE, 6, BK_TOP)
    rect(d, px, py, TILE, 1, BK_TOP_LIGHT)
    rect(d, px, py + 6, TILE, 4, BK_WALL)
    rect(d, px, py + 10, TILE, 2, BK_BAND)
    rect(d, px, py + 12, TILE, 4, BK_WALL_DARK)


def paint_front_wall(d, px, py):
    rect(d, px, py, TILE, 7, BK_TOP)
    rect(d, px, py, TILE, 1, BK_TOP_LIGHT)
    rect(d, px, py + 7, TILE, 9, (6, 6, 8))


def paint_vault_wall(d, px, py, wall_below):
    """The vault's walls: steel over concrete a metre thick, riveted."""
    if wall_below:
        rect(d, px, py, TILE, TILE, BK_STEEL_DARK)
        rect(d, px + 2, py, TILE - 4, TILE, BK_STEEL)
        rect(d, px + 7, py, 2, TILE, BK_STEEL_DARK)
        return
    rect(d, px, py, TILE, 6, BK_STEEL_DARK)
    rect(d, px, py + 6, TILE, 10, BK_STEEL)
    for rx in (px + 2, px + 7, px + 12):
        rect(d, rx, py + 8, 1, 1, BK_STEEL_LIGHT)
        rect(d, rx, py + 13, 1, 1, BK_STEEL_LIGHT)


def paint_deposit_boxes(d, rng, px, py, wall_below):
    """The safe-deposit boxes in their rows, brass doors with their two
    keyholes, some of them forced and hanging open."""
    if wall_below:
        rect(d, px, py, TILE, TILE, BK_TOP)
        rect(d, px + 1, py, TILE - 2, TILE, BK_TOP_LIGHT)
        return
    rect(d, px, py, TILE, TILE, BK_BRASS_DARK)
    for row, sy in enumerate(range(py + 1, py + TILE - 1, 5)):
        for sx in (px + 1, px + 8):
            if rng.random() < 0.25:  # forced
                rect(d, sx, sy, 7, 4, BK_BLACK)
                rect(d, sx, sy + 3, 7, 2, BK_BRASS)
            else:
                rect(d, sx, sy, 7, 4, BK_BRASS)
                rect(d, sx + 2, sy + 1, 1, 2, BK_BLACK)
                rect(d, sx + 4, sy + 1, 1, 2, BK_BLACK)


def paint_glass(d, px, py, west, east, north, south):
    """A glass wall on a steel frame, running whichever way its
    neighbours go, starred where something hit it."""
    across = west or east or not (north or south)
    if across:
        rect(d, px, py + 2, TILE, 12, BK_GLASS)
        rect(d, px, py + 2, TILE, 1, BK_STEEL)
        rect(d, px, py + 13, TILE, 2, BK_STEEL_DARK)
        rect(d, px + 3, py + 4, 1, 7, (220, 236, 244))
    if north or south:
        rect(d, px + 5, py, 6, TILE, BK_GLASS)
        rect(d, px + 5, py, 1, TILE, BK_STEEL)
        rect(d, px + 10, py, 1, TILE, BK_STEEL_DARK)
        rect(d, px + 7, py + 3, 1, 8, (220, 236, 244))


def paint_glass_door(d, px, py):
    """A doorway in the glass: the frame, shards on the floor."""
    rect(d, px, py, 2, TILE, BK_STEEL)
    rect(d, px + 14, py, 2, TILE, BK_STEEL)
    for sx, sy in ((4, 5), (9, 9), (6, 12), (11, 4)):
        rect(d, px + sx, py + sy, 2, 1, (210, 230, 240))


def paint_vault_doorway(d, px, py, lower):
    """The vault's doorway, two cells tall, the way through the steel wall:
    the vault's own floor plate runs out through it, darker than the wall
    either side, so it reads as the gap it is, with the brass sill the door
    shut against across it. Over the upper cell the shadow of the wall's
    cut end, under the lower one the holes the bolts went into."""
    rect(d, px, py, TILE, TILE, BK_STEEL_DARK)
    for i in range(0, TILE, 4):
        for j in range(0, TILE, 4):
            off = 2 if (j // 4) % 2 else 0
            rect(d, px + (i + off) % TILE, py + j + 1, 2, 1, BK_STEEL)
    rect(d, px + 6, py, 4, TILE, BK_BRASS_DARK)
    rect(d, px + 7, py, 2, TILE, BK_BRASS)
    if lower:
        for bx in (px + 2, px + 12):
            rect(d, bx, py + 13, 2, 2, BK_BLACK)
    else:
        rect(d, px, py, TILE, 3, BK_BLACK)
        rect(d, px, py + 3, TILE, 1, (40, 42, 48))


def paint_vault_door(d, px, py, lower):
    """The vault's great round door, swung open against the hall's wall:
    painted over two cells, the upper and the lower half of the disc."""
    y0 = py - (TILE if lower else 0)
    d.ellipse([px - 6, y0 + 1, px + 21, y0 + 31], fill=BK_STEEL,
              outline=BK_STEEL_DARK)
    d.ellipse([px - 1, y0 + 7, px + 16, y0 + 25], outline=BK_STEEL_LIGHT)
    for i in range(6):  # the bolts round its rim
        bx = px + 7 + [-10, 10, -10, 10, 0, 0][i]
        by = y0 + [8, 8, 23, 23, 2, 29][i]
        rect(d, bx, by, 2, 2, BK_BRASS)
    rect(d, px + 5, y0 + 14, 6, 4, BK_STEEL_DARK)  # the wheel's hub
    rect(d, px + 7, y0 + 10, 2, 12, BK_STEEL_DARK)
    rect(d, px + 3, y0 + 15, 10, 2, BK_STEEL_DARK)


def paint_stairs_down(d, px, py):
    """The top of the flight down: grey stone treads into the dark, a steel
    handrail."""
    rect(d, px, py, TILE, TILE, (16, 16, 18))
    for step in range(4):
        rect(d, px + 1, py + 2 + step * 3, TILE - 2, 2,
             shade((150, 150, 150), -step * 34))
    rect(d, px, py, 1, TILE, BK_STEEL)
    rect(d, px + TILE - 1, py, 1, TILE, BK_STEEL)


def stair_door() -> Image.Image:
    """The way up, two tiles high in the back wall: grey treads climbing to
    the light from the roof, steel handrails either side."""
    image = Image.new("RGBA", (TILE, TILE * 2), TRANSPARENT)
    d = ImageDraw.Draw(image)
    height = TILE * 2
    rect(d, 0, 0, TILE, height, BK_TOP)
    rect(d, 1, 5, TILE - 2, height - 5, (30, 30, 34))
    for step in range(6):
        y = height - 3 - step * 4
        rect(d, 1, y, TILE - 2, 3, shade((130, 130, 130), step * 18))
        rect(d, 1, y + 3, TILE - 2, 1, (40, 40, 44))
    rect(d, 1, 5, TILE - 2, 3, (220, 214, 180))  # daylight at the top
    for x in (0, TILE - 1):
        rect(d, x, 6, 1, height - 7, BK_STEEL)
    return image


# ----------------------------------------------------------- furniture


def paint_desk(d, rng, px, py):
    """An office desk over two cells, a monitor on it smashed, papers and
    a keyboard; drawers pulled out."""
    rect(d, px, py + 2, 32, 10, BK_DESK)
    rect(d, px, py + 2, 32, 1, shade(BK_DESK, 20))
    rect(d, px, py + 12, 32, 3, BK_DESK_DARK)
    rect(d, px + 22, py + 12, 8, 3, (90, 76, 58))
    rect(d, px + 5, py - 7, 12, 10, BK_BLACK)
    rect(d, px + 6, py - 6, 10, 7, BK_SCREEN)
    rect(d, px + 9, py - 4, 1, 3, BK_GLASS)
    rect(d, px + 10, py - 3, 3, 1, BK_GLASS)
    rect(d, px + 9, py + 3, 3, 2, (60, 60, 64))
    rect(d, px + 6, py + 6, 11, 3, (200, 200, 196))  # the keyboard
    for _ in range(3):
        rect(d, px + rng.randrange(18, 28), py + rng.randrange(3, 9), 4, 3,
             BK_PAPER)
    if rng.random() < 0.4:
        rect(d, px + rng.randrange(2, 24), py + 4, 5, 4, BLOOD)


def paint_office_chair(d, px, py, toppled):
    """An office chair on its five wheels, or knocked on its side."""
    if toppled:
        rect(d, px + 2, py + 8, 12, 4, BK_BLACK)
        rect(d, px + 3, py + 9, 10, 2, (60, 60, 66))
        rect(d, px + 12, py + 4, 2, 5, (80, 80, 86))
        return
    rect(d, px + 4, py - 3, 8, 7, BK_BLACK)
    rect(d, px + 5, py - 2, 6, 5, (60, 60, 66))
    rect(d, px + 3, py + 4, 10, 5, (60, 60, 66))
    rect(d, px + 7, py + 9, 2, 3, (90, 90, 96))
    for wx in (px + 3, px + 7, px + 11):
        rect(d, wx, py + 12, 2, 2, BK_BLACK)


def paint_filing_cabinet(d, rng, px, py):
    """A grey steel filing cabinet, a drawer pulled out, files spilled."""
    rect(d, px + 2, py - 8, 12, 22, BK_STEEL)
    rect(d, px + 2, py - 8, 12, 1, BK_STEEL_LIGHT)
    for dy in (-6, 0, 6):
        rect(d, px + 3, py + dy, 10, 5, BK_STEEL_LIGHT)
        rect(d, px + 6, py + dy + 2, 4, 1, BK_STEEL_DARK)
    if rng.random() < 0.6:
        rect(d, px + 2, py + 5, 12, 4, BK_STEEL_DARK)
        rect(d, px + 3, py + 13, 9, 2, BK_PAPER)
    rect(d, px + 2, py + 14, 12, 1, OUTLINE)


def paint_bookcase(d, rng, px, py):
    """A bookcase of binders, the year on every spine, half of them on the
    floor."""
    rect(d, px + 1, py - 10, 14, 25, BK_DESK_DARK)
    for sy in (py - 8, py - 2, py + 4):
        rect(d, px + 2, sy + 5, 12, 1, BK_DESK)
        x = px + 2
        while x < px + 13:
            if rng.random() < 0.6:
                rect(d, x, sy + 1, 2, 4, rng.choice(
                    ((40, 70, 128), (150, 40, 40), (200, 190, 150))))
            x += 2
    rect(d, px + 2, py + 12, 10, 2, (40, 70, 128))


def paint_client_chair(d, px, py):
    """A client's armchair in blue leatherette, slashed."""
    rect(d, px + 2, py - 2, 12, 6, BK_BAND)
    rect(d, px + 2, py + 4, 12, 8, BK_BAND_LIGHT)
    rect(d, px + 1, py, 3, 11, shade(BK_BAND, -20))
    rect(d, px + 12, py, 3, 11, shade(BK_BAND, -20))
    rect(d, px + 6, py + 6, 5, 2, (230, 220, 190))
    rect(d, px + 3, py + 12, 2, 3, BK_STEEL)
    rect(d, px + 11, py + 12, 2, 3, BK_STEEL)


def paint_water_cooler(d, px, py):
    """The water cooler, its bottle cracked and empty."""
    rect(d, px + 4, py - 10, 8, 9, (150, 196, 226))
    rect(d, px + 5, py - 9, 2, 6, (200, 230, 246))
    rect(d, px + 3, py - 1, 10, 15, BK_WALL)
    rect(d, px + 3, py - 1, 10, 1, BK_WALL_DARK)
    rect(d, px + 5, py + 3, 2, 2, BK_BAND)
    rect(d, px + 9, py + 3, 2, 2, (190, 40, 40))
    rect(d, px + 3, py + 14, 10, 1, OUTLINE)


def paint_copier(d, px, py):
    """The copier, its lid up, jammed forever."""
    rect(d, px + 1, py - 2, 14, 16, (200, 200, 192))
    rect(d, px + 1, py - 6, 14, 4, (170, 170, 164))
    rect(d, px + 3, py - 5, 10, 2, BK_BLACK)
    rect(d, px + 2, py + 4, 12, 2, (150, 150, 146))
    rect(d, px + 2, py + 8, 12, 2, (150, 150, 146))
    rect(d, px + 10, py - 1, 3, 2, (60, 200, 90))
    rect(d, px + 1, py + 14, 14, 1, OUTLINE)


def paint_office_plant(d, rng, px, py):
    """A dead yucca in a white pot."""
    rect(d, px + 4, py + 7, 8, 8, (230, 230, 226))
    rect(d, px + 4, py + 7, 8, 1, (250, 250, 246))
    rect(d, px + 7, py - 2, 2, 10, (110, 90, 60))
    for lx, ly, w in ((2, -6, 6), (8, -8, 6), (4, -2, 8)):
        rect(d, px + lx, py + ly, w, 2, (120, 120, 70))


def paint_shelves(d, rng, px, py):
    """The vault's steel shelves, stripped: a bar or two of gold missed on
    them, cash boxes thrown open."""
    rect(d, px + 1, py - 10, 14, 25, BK_STEEL_DARK)
    for sy in (py - 8, py - 2, py + 4):
        rect(d, px + 1, sy + 5, 14, 1, BK_STEEL_LIGHT)
        if rng.random() < 0.3:
            rect(d, px + 3, sy + 1, 10, 4, (40, 40, 44))
            rect(d, px + 3, sy + 1, 10, 1, BK_STEEL)
    rect(d, px + 1, py + 14, 14, 1, OUTLINE)


def paint_ceiling_heap(d, rng, px, py):
    """Where the suspended ceiling came down: its tiles, the rails and the
    lamp in a heap."""
    rect(d, px + 1, py + 6, 14, 9, (170, 170, 164))
    for _ in range(6):
        rect(d, px + rng.randrange(1, 11), py + rng.randrange(2, 12),
             rng.randint(3, 5), rng.randint(2, 3),
             rng.choice(((214, 212, 204), (190, 190, 184), (150, 150, 146))))
    rect(d, px + 2, py + 4, 12, 1, BK_STEEL)
    rect(d, px + 6, py + 1, 6, 3, (230, 230, 220))


def paint_papers(d, rng, px, py):
    """Papers, files and ceiling tiles all over the floor."""
    for _ in range(5):
        rect(d, px + rng.randrange(1, 11), py + rng.randrange(1, 12),
             rng.randint(3, 5), rng.randint(2, 4), BK_PAPER)
    if rng.random() < 0.4:
        rect(d, px + rng.randrange(2, 9), py + rng.randrange(3, 10), 6, 4,
             (200, 200, 194))


def paint_banknotes(d, rng, px, py):
    """Banknotes scattered on the floor, green and brown, some of them in
    their bands still."""
    for _ in range(6):
        colour = rng.choice((BK_NOTE, (170, 130, 90), (150, 110, 150)))
        x, y = px + rng.randrange(1, 11), py + rng.randrange(2, 12)
        rect(d, x, y, 5, 3, colour)
        rect(d, x + 2, y + 1, 1, 1, shade(colour, -40))
    if rng.random() < 0.5:
        x, y = px + rng.randrange(3, 9), py + rng.randrange(3, 9)
        rect(d, x, y, 6, 4, BK_NOTE)
        rect(d, x + 2, y, 1, 4, (220, 200, 120))  # its band


# --------------------------------------------------------------- rules

GROUND = ground_config(
    buildings=BK_WALLS,
    roads="",
    walks="",
    floors="".join(glyph for glyph, _ in FLOORS),
    footway="",
    keep="",
    lawn="",
    lawnProps="",
)


def bank_floor(atlas: Atlas, rng, glyphs: str) -> dict:
    """The rules of one of the bank's floors, only for the `glyphs` it
    has."""
    rules = []
    for glyph, paint in FLOORS:
        rules.append(rule("ground", glyph, [atlas.bucket(
            lambda p=paint: tile_of(lambda d: p(d, rng, 0, 0)))]))
    everything = "".join(glyph for glyph, _ in FLOORS)
    for right in (False, True):
        rules.append(rule("ground", everything, [[], atlas.bucket(
            lambda r=right: tile_of(lambda d: paint_edge(d, 0, 0, r)), 1)],
            [neighbour_key(1 if right else -1, 0, "x")]))

    def one(paint):
        return [atlas.bucket(lambda: tile_of(lambda d: paint(d, 0, 0)), 1)]

    def randomly(paint):
        return [atlas.bucket(lambda: tile_of(lambda d: paint(d, rng, 0, 0)))]

    rules.append(rule("structures", "W", [atlas.bucket(
        lambda u=upper: tile_of(lambda d: paint_wall(d, rng, 0, 0, u)))
        for upper in (False, True)], [neighbour_key(0, 1, "xWwB")]))
    rules.append(rule("structures", "I", [atlas.bucket(
        lambda b=below: tile_of(lambda d: paint_partition(d, 0, 0, b)), 1)
        for below in (False, True)], [neighbour_key(0, 1, BK_WALLS)]))
    rules.append(rule("structures", "w", one(paint_front_wall)))
    rules.append(rule("structures", "D", one(paint_stairs_down)))
    rules.append(rule("structures", ":", randomly(paint_papers)))
    rules.append(rule("structures", "b", randomly(palazzo.paint_blood)))
    if "c" in glyphs:
        buckets, pieces = spread(atlas, lambda i: lambda d, px, py:
                                 props.paint_corpse(image_of(d), rng, px, py),
                                 None, (1, 0, 1, 1), 4)
        rules.append(rule("structures", "c", buckets, None, pieces))
    if "Q" in glyphs:
        rules.append(rule("structures", "Q", [atlas.bucket(
            lambda b=below: tile_of(lambda d: paint_vault_wall(d, 0, 0, b)),
            1) for below in (False, True)],
            [neighbour_key(0, 1, "Q")]))
    if "B" in glyphs:
        rules.append(rule("structures", "B", [atlas.bucket(
            lambda b=below: tile_of(
                lambda d: paint_deposit_boxes(d, rng, 0, 0, b)))
            for below in (False, True)], [neighbour_key(0, 1, "B")]))
    if "G" in glyphs:
        glass = "Gd"
        keys = [neighbour_key(-1, 0, glass), neighbour_key(1, 0, glass),
                neighbour_key(0, -1, glass), neighbour_key(0, 1, glass)]
        rules.append(rule("structures", "G", [atlas.bucket(
            lambda i=index: tile_of(lambda d: paint_glass(
                d, 0, 0, bool(i & 1), bool(i & 2), bool(i & 4),
                bool(i & 8))), 1) for index in range(16)], keys))
        rules.append(rule("structures", "d", one(paint_glass_door)))
    if "O" in glyphs:
        rules.append(rule("structures", "O", [atlas.bucket(
            lambda lo=lower: tile_of(
                lambda d: paint_vault_doorway(d, 0, 0, lo)), 1)
            for lower in (False, True)], [neighbour_key(0, -1, "O")]))
    if "o" in glyphs:
        buckets, up = leaning(atlas, lambda i: lambda d, px, py:
                              paint_vault_door(d, px, py, bool(i)),
                              [neighbour_key(0, -1, "o")], 1)
        rules.append(rule("structures", "o", buckets,
                          [neighbour_key(0, -1, "o")], up))
    if "z" in glyphs:
        rules.append(rule("structures", "z", randomly(paint_banknotes)))
    if "T" in glyphs:
        pair = [neighbour_key(-1, 0, "T")]
        buckets, up = leaning(atlas, lambda i: lambda d, px, py: paint_desk(
            d, rng, px - TILE * i, py), pair)
        rules.append(rule("structures", "T", buckets, pair, up))
    if "h" in glyphs:
        rules.append(rule("structures", "h", [atlas.bucket(
            lambda t=toppled: tile_of(
                lambda d: paint_office_chair(d, 0, 0, t)), 1)
            for toppled in (False, True)], [neighbour_key(0, -1, "IWx")]))
    for glyph, paint in (("S", paint_client_chair), ("C", paint_water_cooler),
                         ("P", paint_copier)):
        if glyph in glyphs:
            buckets, up = leaning(atlas, lambda i, p=paint: p, None, 1)
            rules.append(rule("structures", glyph, buckets, pieces=up))
    for glyph, paint in (("K", paint_filing_cabinet), ("l", paint_bookcase),
                         ("p", paint_office_plant), ("L", paint_shelves),
                         ("r", paint_ceiling_heap)):
        if glyph in glyphs:
            buckets, up = leaning(atlas, lambda i, p=paint: lambda d, px, py:
                                  p(d, rng, px, py))
            rules.append(rule("structures", glyph, buckets, pieces=up))
    objects = []
    if "U" in glyphs:
        objects.append({"glyph": "U", "image": "bank_stairs_up.png",
                        "offsetY": -1, "sprite": stair_door()})
    return {"void": "#000000", "voidGlyph": "x", "rules": rules,
            "objects": objects, "ground": GROUND}


def bank_offices(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.bankOffices."""
    return bank_floor(atlas, rng, "UDGdTKhlSCPprcb")


def bank_vault(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.bankVault."""
    return bank_floor(atlas, rng, "UQBOoLTzhprcb")


PLACES = {
    "bankOffices": bank_offices,
    "bankVault": bank_vault,
}

PREVIEW_ROWS = {
    "bankOffices": "bank-offices-rows",
    "bankVault": "bank-vault-rows",
}
