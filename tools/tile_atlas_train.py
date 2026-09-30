"""The inside of the train in the tile atlas: the two coaches and the
locomotive, the map of Europe on its table, the cots, the wardrobe, the
food and the weapons on their tables, the books and the papers
(lib/core/levels/train/train_interior.dart).

A module of its own, the way docs/level_pipeline.md wants the interiors
to go: build_tile_atlas.py only lists it. The art came from
tools/build_train.py, which the atlas replaced.
"""
from __future__ import annotations

import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from street_paint import TILE, rect, shade  # noqa: E402
from build_mall import Room  # noqa: E402
from tile_atlas_core import (  # noqa: E402
    Atlas,
    Neighbourhood,
    TRANSPARENT,
    before_run_key,
    cell,
    neighbour_key,
    parity_key,
    pattern_key,
    rule,
    tile_of,
)

# --------------------------------------------------------- the train's art
# Moved here from tools/build_train.py, which this atlas replaces: two
# passenger coaches and the locomotive Mario and Luigi live in, seen from
# above. Two pieces are objects: the table with the map of Europe spread on
# it, and the nose of the locomotive, whose shape is worked out from the
# rows (the one place where this script reads them, because the picture is
# only right for one arrangement of them; the test that holds the rows to
# the manifest is what makes that safe).

TR_VOID = (6, 6, 8)
TR_FLOOR_A = (92, 88, 82)
TR_FLOOR_B = (82, 78, 74)
TR_FLOOR_LINE = (60, 58, 58)
TR_SHELL = (198, 194, 182)
TR_SHELL_DARK = (116, 118, 122)
TR_SHELL_LIGHT = (226, 220, 204)
TR_METAL = (112, 116, 124)
TR_METAL_DARK = (48, 52, 60)
TR_METAL_LIGHT = (174, 178, 184)
TR_GLASS = (34, 50, 66)
TR_GLASS_LIGHT = (76, 106, 126)
TR_SEAT = (62, 88, 124)
TR_SEAT_DARK = (38, 54, 78)
TR_WOOD = (128, 90, 54)
TR_WOOD_LIGHT = (166, 124, 76)
TR_LUGGAGE = (94, 64, 42)
TR_CONTROL = (50, 58, 62)
TR_CONTROL_LIGHT = (100, 116, 112)
TR_MAP = (196, 166, 72)
TR_MAP_DARK = (112, 86, 34)
TR_LAMP = (242, 232, 190)
TR_SAFETY = (214, 178, 48)
TR_COT_FRAME = (70, 76, 60)
TR_COT_CANVAS = (112, 118, 86)
# Mario's red wool blanket, folded square; Luigi's green checked one,
# kicked about.
TR_MARIO_BLANKET = (160, 40, 36)
TR_LUIGI_BLANKET = (58, 104, 58)
TR_LUIGI_CHECK = (170, 196, 150)
TR_PILLOW = (214, 208, 190)
TR_BAG = (22, 24, 26)
TR_BAG_MID = (40, 43, 47)
TR_BAG_LIGHT = (96, 102, 110)
TR_BAG_TIE = (214, 176, 40)
TR_OUTLINE = (20, 18, 20)
TR_GLASS_GREEN = (40, 110, 58)
TR_GLASS_BROWN = (120, 68, 22)
TR_GLASS_CLEAR = (178, 204, 206)
TR_LABEL_RED = (182, 40, 40)
TR_LABEL_CREAM = (232, 220, 180)
TR_STAIN = (72, 58, 48)
TR_CAN_RED = (178, 40, 38)
TR_CAN_SILVER = (184, 186, 190)
TR_PAPER = (226, 220, 200)
TR_PAPER_SHADE = (178, 170, 150)
TR_INK = (62, 58, 60)
TR_CRATE = (118, 84, 48)
TR_CRATE_DARK = (78, 54, 30)
TR_AMMO_BOX = (70, 86, 52)
TR_BRASS = (206, 164, 70)
TR_BOOK_COVERS = ((122, 38, 34), (40, 64, 104), (58, 86, 52),
                  (108, 76, 40), (70, 44, 78))
TR_GILT = (214, 180, 86)
TR_PAGES = (236, 228, 204)
TR_PAGE_EDGE = (196, 186, 160)
TR_WINDSCREEN_FRAME = (36, 40, 46)
TR_ROWS = "train-interior-rows"
TR_MAP_TABLE_TILES = (4, 3)
TR_WEAPON_TABLE_TILES = (3, 1)
TR_FOOD_TABLE_TILES = (3, 1)
TR_CLOTH = (234, 226, 206)
TR_CLOTH_SHADE = (206, 196, 172)
TR_CLOTH_STRIPE = (178, 44, 40)
TR_HAM_RIND = (150, 84, 44)
TR_HAM_DARK = (168, 58, 62)
TR_BONE = (238, 232, 214)
TR_TWINE = (214, 200, 160)
TR_BOARD = (176, 128, 74)
TR_HAM = (214, 110, 112)
TR_HAM_FAT = (246, 226, 214)
TR_SALAMI = (140, 40, 44)
TR_SALAMI_FAT = (238, 214, 206)
TR_SALAMI_SKIN = (196, 190, 176)
TR_CHEESE = (240, 204, 96)
TR_CHEESE_RIND = (176, 124, 46)
TR_BREAD = (196, 138, 66)
TR_BREAD_CRUST = (138, 84, 34)
TR_CRUMB = (240, 220, 170)
TR_WINE = (96, 20, 34)
# The map of Europe: parchment land, faded blue sea, ink coasts.
TR_MAP_LAND = (222, 196, 120)
TR_MAP_SEA = (138, 166, 170)
TR_MAP_COAST = (150, 114, 58)
TR_NEEDLE = (186, 30, 28)
TR_GUN = (58, 60, 66)
TR_GUN_LIGHT = (128, 132, 140)
TR_SHELL_RED = (176, 36, 32)
TR_TABLE_DARK = (92, 62, 36)
# What a camp bed's pillow lies against.
TR_COT_WALLS = "xWwIiV"


def paint_train_floor(d, rng, x, y):
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, TR_FLOOR_A if (x + y) % 2 else TR_FLOOR_B)
    rect(d, px, py, TILE, 1, TR_FLOOR_LINE)
    rect(d, px, py, 1, TILE, TR_FLOOR_LINE)
    for _ in range(2):
        rect(d, px + rng.randrange(15), py + rng.randrange(15), 1, 1,
             shade(TR_FLOOR_A, rng.randrange(-22, 14)))


def paint_train_shell(d, glyph, x, y):
    """The hull: the roof edge on the north side with a window every four
    tiles, the belly on the south side, the pillars between the coaches."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, TR_METAL_DARK)
    if glyph == "W":
        rect(d, px, py + 3, TILE, 12, TR_SHELL)
        rect(d, px, py + 3, TILE, 2, TR_SHELL_LIGHT)
        if x % 4 in (1, 2):
            rect(d, px + 2, py + 6, 12, 7, TR_METAL_DARK)
            rect(d, px + 3, py + 7, 10, 5, TR_GLASS)
            rect(d, px + 4, py + 7, 5, 1, TR_GLASS_LIGHT)
    elif glyph == "w":
        rect(d, px, py, TILE, 12, TR_SHELL)
        rect(d, px, py, TILE, 2, TR_SHELL_LIGHT)
        rect(d, px, py + 11, TILE, 4, TR_SHELL_DARK)
    else:
        rect(d, px + 3, py, 10, TILE, TR_SHELL_DARK)
        rect(d, px + 5, py, 6, TILE, TR_METAL)
        rect(d, px + 6, py, 2, TILE, TR_METAL_LIGHT)


def paint_train_end_wall(d, px, py, open_above=False, open_below=False):
    """An end wall of a coach, running north-south, seen from above: the
    top of the bulkhead as one band down the tile, lit on one edge and in
    shadow on the other, so that tile after tile it reads as a single
    wall. Where the aisle cuts through it the band is capped."""
    rect(d, px, py, TILE, TILE, TR_METAL_DARK)
    rect(d, px + 2, py, 12, TILE, TR_SHELL)
    rect(d, px + 2, py, 2, TILE, TR_SHELL_LIGHT)
    rect(d, px + 12, py, 2, TILE, TR_SHELL_DARK)
    if open_above:
        rect(d, px + 2, py, 12, 2, TR_SHELL_LIGHT)
    if open_below:
        rect(d, px + 2, py + 12, 12, 4, TR_SHELL_DARK)
        rect(d, px + 2, py + 11, 12, 1, TR_SHELL)


def paint_train_exit(d, px, py):
    rect(d, px, py, TILE, TILE, (24, 28, 32))
    rect(d, px, py, TILE, 2, TR_LAMP)
    rect(d, px, py + 12, TILE, 4, TR_METAL_DARK)
    rect(d, px + 2, py + 13, 12, 1, TR_METAL_LIGHT)
    for rail_x in (px + 1, px + 13):
        rect(d, rail_x, py + 2, 2, 11, TR_SAFETY)


def paint_train_seat(d, px, py, left_end, right_end):
    rect(d, px + 2, py + 2, 12, 12, TR_SEAT_DARK)
    rect(d, px + 3, py + 3, 10, 6, TR_SEAT)
    rect(d, px + 3, py + 10, 10, 3, shade(TR_SEAT, -18))
    rect(d, px + 3, py + 3, 10, 1, shade(TR_SEAT, 34))
    if left_end:
        rect(d, px + 1, py + 4, 2, 9, TR_METAL_LIGHT)
    if right_end:
        rect(d, px + 13, py + 4, 2, 9, TR_METAL_LIGHT)


def paint_train_table(d, px, py):
    rect(d, px + 1, py + 5, 14, 7, shade(TR_WOOD, -24))
    rect(d, px + 1, py + 3, 14, 7, TR_WOOD)
    rect(d, px + 2, py + 4, 12, 1, TR_WOOD_LIGHT)
    rect(d, px + 4, py + 10, 2, 5, TR_METAL_DARK)
    rect(d, px + 11, py + 10, 2, 5, TR_METAL_DARK)


def paint_train_luggage(d, rng, px, py):
    rect(d, px + 2, py + 4, 12, 10, TR_LUGGAGE)
    rect(d, px + 3, py + 5, 10, 2, shade(TR_LUGGAGE, 28))
    rect(d, px + 6, py + 1, 5, 4, TR_METAL_DARK)
    rect(d, px + 7, py + 2, 3, 3, TR_FLOOR_B)
    rect(d, px + rng.randrange(3, 11), py + 7, 2, 5,
         shade(TR_LUGGAGE, -28))


# Mario's clothes, as he wears them: a red flannel shirt and jeans.
TR_SHIRT = (156, 44, 40)
TR_SHIRT_DARK = (104, 28, 28)
TR_JEANS = (60, 86, 136)
TR_JEANS_DARK = (40, 58, 96)
# Luigi's: a white vest gone grey and olive shorts.
TR_VEST = (226, 222, 206)
TR_VEST_SHADE = (184, 178, 160)
TR_SHORTS = (96, 106, 56)
TR_SHORTS_DARK = (64, 72, 38)
TR_CASE_BLUE = (48, 64, 100)
TR_CASE_LINING = (206, 186, 150)
TR_SOCK_BLUE = (70, 96, 150)


# The clothes are drawn pixel by pixel from these: `o` the outline, then
# the colours each one names in its palette; `.` is left alone.
SHIRT = (
    "......oo......",
    "...oooooooo...",
    "..orrrRRrrro..",
    ".orrrrRRrrrro.",
    "orrorrrRrrorro",
    "oRRoRRRRRRoRRo",
    "orrorrrRrrorro",
    "oRRoRRRRRRoRRo",
    "orrorrrRrrorro",
    "oRRorrrRrroRRo",
    "oooorrrRrroooo",
    "...oRRRRRRo...",
    "...oooooooo...",
)
JEANS = (
    "....oo...",
    "...oooo..",
    "ooooooooo",
    "oBBBBBBBo",
    "obbbbbbbo",
    "obbbobbbo",
    "obcbobcbo",
    "obcbobcbo",
    "obbbobbbo",
    "obcbobcbo",
    "obbbobbbo",
    "oBBBoBBBo",
    "ooooooooo",
)
VEST = (
    "...oo.oo...",
    "...ow.wo...",
    "..oow.woo..",
    ".owwwowwwo.",
    "owwwwwwwwwo",
    "owwwwwswwwo",
    "owswwwwwwwo",
    "owwwwwwwswo",
    "owwwswwwwwo",
    "owwwwwwwwwo",
    "osssssssss o".replace(" ", ""),
    "ooooooooooo",
)
SHORTS = (
    "ooooooooooo",
    "odddddddddo",
    "ogggggggggo",
    "ogggsdgggso",
    "ogggo.ogggo",
    "ogggo.ogggo",
    "odddo.odddo",
    "ooooo.ooooo",
)
BRIEFS = (
    "ooooooooo",
    "osssssssso"[:9],
    "owwwwwwwo",
    ".owwwwwo.",
    "..owwwo..",
    "...ooo...",
)
BOXERS = (
    "ooooooooo",
    "osssssssso"[:9],
    "obwbwbwbo",
    "obwbwbwbo",
    "obwbooobo"[:9],
    "oooo.oooo",
)
SOCK = (
    "oooo..",
    "oxxo..",
    "owwo..",
    "owwo..",
    "owwooo",
    "owwwwo",
    "oooooo",
)


def _pattern(d, x, y, rows, palette, flip=False):
    """Draws `rows` with its top left corner at (x, y); `flip` mirrors it
    top to bottom, a garment dropped the other way up."""
    for dy, row in enumerate(reversed(rows) if flip else rows):
        for dx, key in enumerate(row):
            if key == ".":
                continue
            colour = TR_OUTLINE if key == "o" else palette[key]
            rect(d, x + dx, y + dy, 1, 1, colour)


def _shirt(d, x, y):
    _pattern(d, x, y, SHIRT, {"r": TR_SHIRT, "R": TR_SHIRT_DARK})


def _jeans(d, x, y):
    _pattern(d, x, y, JEANS, {"b": TR_JEANS, "B": TR_JEANS_DARK,
                              "c": shade(TR_JEANS, 26)})


def _vest(d, x, y, flip=False):
    _pattern(d, x, y, VEST, {"w": TR_VEST, "s": TR_VEST_SHADE}, flip)


def _shorts(d, x, y, flip=False):
    _pattern(d, x, y, SHORTS, {"g": TR_SHORTS, "d": TR_SHORTS_DARK,
                               "s": shade(TR_SHORTS, 24)}, flip)


def _pants(d, x, y, striped):
    if striped:
        _pattern(d, x, y, BOXERS, {"s": shade(TR_SOCK_BLUE, -30),
                                   "b": TR_SOCK_BLUE, "w": TR_VEST})
    else:
        _pattern(d, x, y, BRIEFS, {"s": TR_VEST_SHADE, "w": TR_VEST})


def _sock(d, x, y, band):
    _pattern(d, x, y, SOCK, {"x": band, "w": TR_VEST_SHADE})


def paint_train_wardrobe(d, px, py, width):
    """Mario's wardrobe, three tiles long against the wall: a bare rail on
    two uprights, and hung on it his clothes, the red flannel shirts and
    the jeans he wears."""
    w = width * TILE
    for ux in (px + 1, px + w - 3):
        rect(d, ux - 1, py + 1, 4, 14, TR_OUTLINE)
        rect(d, ux, py + 2, 2, 12, TR_METAL)
        rect(d, ux - 2, py + 13, 6, 3, TR_OUTLINE)  # its foot
        rect(d, ux - 1, py + 14, 4, 1, TR_METAL_DARK)
    rect(d, px + 1, py + 1, w - 2, 3, TR_OUTLINE)
    rect(d, px + 2, py + 2, w - 4, 1, TR_METAL_LIGHT)  # the rail
    if width == 1:
        _shirt(d, px + 1, py + 2)
        return
    _shirt(d, px + 4, py + 2)
    _jeans(d, px + 19, py + 2)
    _shirt(d, px + 29, py + 2)


def paint_train_suitcases(d, px, py, width):
    """Mario's two suitcases against the wall: a brown leather one lying
    flat, strapped shut, and beside it a blue hard case standing on its
    wheels, its handle down."""
    # the one lying flat, seen from above: lid, straps, the handle
    rect(d, px + 1, py + 3, 15, 12, TR_OUTLINE)
    rect(d, px + 2, py + 4, 13, 10, TR_LUGGAGE)
    rect(d, px + 2, py + 4, 13, 1, shade(TR_LUGGAGE, 30))
    rect(d, px + 2, py + 12, 13, 2, shade(TR_LUGGAGE, -24))  # its side
    for sx in (px + 5, px + 11):
        rect(d, sx, py + 4, 2, 10, shade(TR_LUGGAGE, -40))
        rect(d, sx, py + 8, 2, 1, TR_SAFETY)  # the buckles
    rect(d, px + 6, py + 14, 5, 2, TR_OUTLINE)  # the handle
    if width == 1:
        return
    # the one standing, taller than it is wide, ribbed
    x = px + TILE + 3
    rect(d, x - 1, py, 12, 16, TR_OUTLINE)
    rect(d, x, py + 1, 10, 13, TR_CASE_BLUE)
    for rx in range(x + 2, x + 9, 3):
        rect(d, rx, py + 3, 1, 10, shade(TR_CASE_BLUE, 26))
    rect(d, x, py + 1, 10, 1, shade(TR_CASE_BLUE, 40))
    rect(d, x + 3, py + 1, 4, 2, TR_METAL_LIGHT)  # the handle, pushed down
    rect(d, x, py + 14, 3, 2, TR_METAL_DARK)  # the wheels
    rect(d, x + 7, py + 14, 3, 2, TR_METAL_DARK)


def paint_train_open_suitcase(d, px, py, width):
    """One of Luigi's suitcases, left open on the floor: the lid thrown
    back against the wall, the lining showing, and his clothes spilling
    over the side."""
    w = width * TILE
    rect(d, px + 1, py, w - 2, 5, TR_OUTLINE)  # the lid, open
    rect(d, px + 2, py + 1, w - 4, 3, shade(TR_LUGGAGE, -20))
    rect(d, px + 3, py + 2, w - 6, 1, TR_CASE_LINING)
    rect(d, px + 1, py + 5, w - 2, 10, TR_OUTLINE)  # the case
    rect(d, px + 2, py + 6, w - 4, 8, TR_CASE_LINING)
    rect(d, px + 2, py + 13, w - 4, 1, shade(TR_CASE_LINING, -40))
    if width == 1:
        _vest(d, px + 2, py + 3)
        _sock(d, px + 9, py + 9, TR_LABEL_RED)
        return
    _vest(d, px + 2, py + 3)
    _shorts(d, px + 12, py + 6)
    _pants(d, px + 22, py + 5, striped=True)
    _sock(d, px + 24, py + 9, TR_SOCK_BLUE)  # spilling over the side


def paint_train_luigi_clothes(d, rng, px, py):
    """Luigi's clothes, thrown on the floor where he took them off: his
    vest, his shorts, or both in a heap."""
    kind = rng.randrange(3)
    flip = rng.random() < 0.5
    if kind == 0:
        _vest(d, px + rng.randrange(0, 5), py + rng.randrange(0, 4), flip)
    elif kind == 1:
        _shorts(d, px + rng.randrange(0, 5), py + rng.randrange(1, 8), flip)
    else:
        _vest(d, px, py, flip)
        _shorts(d, px + 5, py + 8)


def paint_train_underwear(d, rng, px, py):
    """Underpants and socks about the floor, never in pairs where they
    should be."""
    kind = rng.randrange(3)
    x, y = px + rng.randrange(0, 6), py + rng.randrange(1, 9)
    if kind == 0:
        _pants(d, x, y, striped=rng.random() < 0.5)
    elif kind == 1:
        _sock(d, px + rng.randrange(0, 4), py + rng.randrange(0, 3),
              rng.choice((TR_LABEL_RED, TR_SOCK_BLUE)))
        _sock(d, px + 9, py + 8, TR_LABEL_RED)
    else:
        _pants(d, px, py + 1, striped=False)
        _sock(d, px + 10, py + 8, TR_SOCK_BLUE)


def paint_train_control(d, rng, px, py):
    rect(d, px + 1, py + 2, 14, 12, TR_CONTROL)
    rect(d, px + 2, py + 3, 12, 4, TR_CONTROL_LIGHT)
    for _ in range(4):
        colour = rng.choice(((178, 52, 42), (68, 146, 82), (214, 176, 54)))
        rect(d, px + rng.randrange(3, 13), py + rng.randrange(8, 12), 2, 2,
             colour)


# Europe as the map on the table shows it, in (longitude, latitude): the
# mainland from Gibraltar round the coasts to the edge of the sheet in the
# east, and the islands big enough to show. The Black Sea is drawn over
# the land as water. Coarse on purpose: at a degree a pixel, this is all
# of the coast a map this size can hold.
EUROPE_MAINLAND = (
    (-5.6, 36.0), (-6.3, 36.8), (-7.4, 37.2), (-8.9, 37.0), (-8.8, 38.7),
    (-9.5, 39.4), (-8.7, 41.2), (-8.9, 42.9), (-9.3, 43.0), (-7.7, 43.7),
    (-5.8, 43.6), (-3.8, 43.4), (-1.8, 43.4), (-1.2, 44.7), (-1.1, 46.2),
    (-2.2, 47.2), (-4.7, 48.0), (-4.3, 48.7), (-1.6, 48.7), (-1.9, 49.7),
    (-1.1, 49.4), (0.2, 49.7), (1.6, 50.9), (3.2, 51.3), (4.0, 51.9),
    (4.7, 52.9), (6.8, 53.4), (8.5, 53.6), (8.6, 54.9), (8.1, 55.5),
    (8.6, 57.1), (10.6, 57.7), (10.3, 56.5), (10.9, 56.3), (10.0, 55.2),
    (10.9, 54.4), (12.2, 54.2), (14.2, 53.9), (16.0, 54.3), (18.7, 54.8),
    (19.9, 54.4), (21.1, 55.6), (21.0, 56.8), (22.6, 57.8), (24.2, 57.1),
    (23.5, 58.6), (24.4, 59.4), (28.0, 59.5), (30.2, 59.9), (27.0, 60.5),
    (22.9, 59.9), (21.4, 60.8), (21.5, 61.7), (21.5, 63.2), (25.4, 65.0),
    (24.2, 65.8), (22.1, 65.6), (21.0, 64.5), (19.3, 63.5), (17.9, 62.6),
    (17.2, 61.3), (17.3, 60.6), (18.8, 60.1), (18.1, 59.3), (16.7, 57.9),
    (16.4, 56.6), (15.6, 56.2), (14.3, 55.5), (12.9, 55.4), (12.6, 56.2),
    (11.9, 57.7), (11.2, 58.9), (10.6, 59.9), (9.6, 59.0), (8.0, 58.1),
    (5.6, 58.8), (5.2, 60.4), (5.0, 61.9), (6.5, 62.6), (8.0, 63.2),
    (10.4, 63.4), (11.3, 64.4), (12.6, 65.9), (14.4, 67.3), (16.0, 68.4),
    (18.9, 69.6), (23.7, 70.6), (25.8, 71.1), (28.5, 70.9), (31.0, 70.3),
    (33.0, 69.3), (36.0, 69.0), (41.0, 67.7), (46.0, 68.0), (46.0, 36.6),
    (36.2, 36.6), (34.6, 36.8), (32.5, 36.1), (30.6, 36.8), (29.1, 36.6),
    (27.3, 37.0), (26.3, 38.3), (26.6, 39.5), (26.2, 40.0), (26.1, 40.6),
    (24.4, 40.9), (22.9, 40.6), (22.6, 39.8), (23.1, 39.0), (24.0, 38.2),
    (23.0, 38.0), (22.5, 37.0), (21.7, 36.8), (21.1, 37.8), (21.3, 38.4),
    (20.2, 39.5), (19.4, 40.3), (19.5, 41.8), (18.5, 42.4), (16.4, 43.5),
    (15.2, 44.2), (14.5, 45.3), (13.7, 45.6), (12.3, 45.4), (12.3, 44.5),
    (13.6, 43.5), (14.2, 42.4), (16.2, 41.9), (15.9, 41.5), (16.9, 41.1),
    (18.5, 40.1), (18.4, 39.8), (17.1, 40.5), (16.5, 39.7), (17.1, 39.0),
    (16.1, 38.0), (15.6, 38.0), (15.8, 38.9), (15.6, 40.0), (14.3, 40.8),
    (13.0, 41.2), (12.2, 41.7), (11.1, 42.4), (10.5, 43.0), (10.2, 43.9),
    (8.9, 44.4), (7.5, 43.8), (6.0, 43.1), (4.8, 43.4), (3.2, 43.1),
    (3.2, 42.3), (2.2, 41.4), (0.9, 41.0), (-0.3, 39.5), (0.2, 38.8),
    (-0.5, 38.3), (-0.8, 37.6), (-2.1, 36.7), (-4.4, 36.7),
)
EUROPE_ISLANDS = (
    # Great Britain.
    ((-5.7, 50.1), (-3.0, 50.7), (1.4, 51.2), (1.7, 52.6), (0.3, 53.1),
     (-0.1, 54.0), (-1.4, 55.0), (-2.0, 55.8), (-2.4, 57.1), (-1.8, 57.5),
     (-3.3, 58.6), (-5.0, 58.6), (-5.7, 57.5), (-5.6, 56.3), (-4.9, 55.7),
     (-5.1, 54.8), (-3.2, 54.9), (-3.0, 53.4), (-4.6, 53.3), (-4.3, 52.3),
     (-5.2, 51.8), (-3.1, 51.4), (-4.2, 51.1)),
    # Ireland.
    ((-6.0, 52.2), (-6.2, 53.3), (-6.0, 54.1), (-5.9, 55.2), (-7.3, 55.3),
     (-8.4, 55.1), (-8.6, 54.3), (-10.0, 54.2), (-9.9, 53.0), (-9.4, 52.6),
     (-10.3, 51.9), (-9.5, 51.5), (-8.2, 51.8)),
    # Sicily, Sardinia, Corsica, Crete.
    ((12.4, 37.8), (13.4, 38.2), (15.6, 38.3), (15.1, 37.1), (14.3, 37.0),
     (12.6, 37.6)),
    ((8.4, 39.0), (9.0, 39.0), (9.7, 39.2), (9.8, 41.0), (9.3, 41.2),
     (8.2, 40.9), (8.4, 39.8)),
    ((8.6, 41.4), (9.4, 41.5), (9.5, 43.0), (8.7, 42.6)),
    ((23.5, 35.4), (26.3, 35.3), (26.1, 35.0), (24.0, 35.1)),
)
EUROPE_BLACK_SEA = (
    (28.0, 41.6), (28.7, 44.0), (29.7, 45.2), (30.7, 46.5), (32.0, 46.5),
    (33.5, 46.0), (32.5, 45.4), (33.5, 44.4), (35.3, 44.9), (36.5, 45.3),
    (37.5, 44.7), (38.5, 44.3), (39.8, 43.5), (41.6, 41.6), (41.0, 41.0),
    (39.5, 41.0), (36.0, 41.7), (35.0, 42.0), (33.0, 42.0), (31.3, 41.2),
    (29.1, 41.2),
)
EUROPE_BOUNDS = (-10.8, 35.0, 40.5, 71.8)  # west, south, east, north


# Nordkapp, as longitude and latitude.
NORTH_CAPE = (25.78, 71.17)


def paint_europe(width, height):
    """The map itself, `width` by `height` pixels: land, sea and the coast
    inked round the land, nothing drawn on it.
    Drawn four times over and brought down, so the coast is the shape of
    the real one and not of the polygon's corners."""
    scale = 4
    west, south, east, north = EUROPE_BOUNDS
    big = Image.new("RGB", (width * scale, height * scale), TR_MAP_SEA)
    draw = ImageDraw.Draw(big)

    def at(lon, lat):
        return ((lon - west) / (east - west) * width * scale,
                (north - lat) / (north - south) * height * scale)

    draw.polygon([at(*p) for p in EUROPE_MAINLAND], fill=TR_MAP_LAND)
    for island in EUROPE_ISLANDS:
        draw.polygon([at(*p) for p in island], fill=TR_MAP_LAND)
    draw.polygon([at(*p) for p in EUROPE_BLACK_SEA], fill=TR_MAP_SEA)
    small = big.resize((width, height), Image.BOX)
    sheet = Image.new("RGB", (width, height), TR_MAP_SEA)
    # Land where the pixel is more than half covered by it.
    half = (sum(TR_MAP_SEA) + sum(TR_MAP_LAND)) / 2
    land = [[sum(small.getpixel((x, y))) > half
             for x in range(width)] for y in range(height)]
    px = sheet.load()
    for y in range(height):
        for x in range(width):
            if not land[y][x]:
                continue
            coast = any(
                not (0 <= x + dx < width and 0 <= y + dy < height)
                or not land[y + dy][x + dx]
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            px[x, y] = TR_MAP_COAST if coast else TR_MAP_LAND
    return sheet


def paint_train_map_table(sprite):
    """The table in the middle of the locomotive, four tiles by three,
    with their map of Europe spread over it: the whole of it, from
    Portugal to the North Cape. Beside the map, a pencil and a compass."""
    d = ImageDraw.Draw(sprite)
    w, h = TR_MAP_TABLE_TILES[0] * TILE, TR_MAP_TABLE_TILES[1] * TILE
    # The table: a dark edge, the top, and its legs at the corners.
    rect(d, 0, h - 3, w, 3, TR_OUTLINE)
    for leg_x in (2, w - 5):
        rect(d, leg_x, h - 4, 3, 4, TR_METAL_DARK)
    rect(d, 0, 0, w, h - 3, TR_OUTLINE)
    rect(d, 1, 1, w - 2, h - 5, TR_WOOD)
    rect(d, 1, h - 5, w - 2, 1, shade(TR_WOOD, -34))
    rect(d, 2, 2, w - 4, 1, TR_WOOD_LIGHT)
    # The map, its shadow, a white margin and the sheet.
    mx, my, mw, mh = 4, 3, 44, h - 9
    rect(d, mx + 1, my + 1, mw, mh, shade(TR_WOOD, -50))
    rect(d, mx, my, mw, mh, TR_PAPER)
    sprite.paste(paint_europe(mw - 2, mh - 2), (mx + 1, my + 1))
    # A red X by the North Cape, where the two of them mean to end up,
    # drawn a little south of the tip so the coast still shows.
    west, south, east, north = EUROPE_BOUNDS
    cape_x = mx + 1 + round((NORTH_CAPE[0] - west) / (east - west)
                            * (mw - 2))
    cape_y = my + 1 + round((north - NORTH_CAPE[1]) / (north - south)
                            * (mh - 2))
    for i in range(-2, 3):
        rect(d, cape_x + i, cape_y + 2 + i, 1, 1, TR_LABEL_RED)
        rect(d, cape_x + i, cape_y + 2 - i, 1, 1, TR_LABEL_RED)
    # A pencil and a compass beside it.
    rect(d, 52, 6, 2, 12, TR_SAFETY)
    rect(d, 52, 18, 2, 2, TR_WOOD_LIGHT)
    rect(d, 52, 20, 2, 1, TR_OUTLINE)
    rect(d, 51, 26, 9, 9, TR_OUTLINE)
    rect(d, 52, 27, 7, 7, TR_METAL_LIGHT)
    rect(d, 53, 28, 5, 5, TR_PAPER)
    rect(d, 55, 28, 1, 2, TR_NEEDLE)
    rect(d, 55, 31, 1, 2, TR_OUTLINE)


def paint_train_driver_seat(d, px, py):
    """One of the two drivers' chairs, its back to the room, facing the
    controls."""
    rect(d, px + 5, py + 12, 6, 3, TR_METAL_DARK)
    rect(d, px + 3, py + 3, 11, 10, TR_SEAT_DARK)
    rect(d, px + 5, py + 4, 8, 8, TR_SEAT)
    rect(d, px + 2, py + 2, 4, 12, TR_SEAT_DARK)
    rect(d, px + 3, py + 3, 2, 10, shade(TR_SEAT, 30))


def paint_train_cot(d, room, x, y, glyph):
    """One tile of a camp bed three tiles long: canvas stretched on a metal
    frame, a pillow at the end by the wall, a blanket over the rest."""
    px, py = x * TILE, y * TILE
    left = room.at(x - 1, y) != glyph
    right = room.at(x + 1, y) != glyph
    # The pillow goes at the end that is up against a wall.
    start = x
    while room.at(start - 1, y) == glyph:
        start -= 1
    pillow_left = room.at(start - 1, y) in TR_COT_WALLS
    rect(d, px, py + 2, TILE, 12, TR_COT_FRAME)
    rect(d, px + (2 if left else 0), py + 3,
         TILE - (2 if left else 0) - (2 if right else 0), 10, TR_COT_CANVAS)
    for leg_x in ((px + 1,) if left else ()) + ((px + 13,) if right else ()):
        rect(d, leg_x, py + 13, 2, 2, TR_METAL_DARK)
    if (left and pillow_left) or (right and not pillow_left):
        rect(d, px + (3 if left else 5), py + 4, 8, 8, TR_PILLOW)
        rect(d, px + (3 if left else 5), py + 10, 8, 2, shade(TR_PILLOW, -30))
        return
    if glyph == "B":
        # Tucked in tight, the edge turned down neatly.
        end = 3 if (right and pillow_left) or (left and not pillow_left) else 0
        start_x = px + (end if left else 0)
        rect(d, start_x, py + 4, TILE - end, 8, TR_MARIO_BLANKET)
        rect(d, start_x, py + 4, TILE - end, 1, shade(TR_MARIO_BLANKET, 30))
        if room.at(x - 1, y) == glyph and room.at(x + 1, y) == glyph:
            # The turned-down edge, next to the pillow.
            edge = px + (1 if pillow_left else 12)
            rect(d, edge, py + 4, 3, 8, shade(TR_MARIO_BLANKET, 22))
    else:
        # Half off the bed, in a heap.
        rect(d, px, py + 3, TILE, 11, TR_LUIGI_BLANKET)
        for cx in range(px, px + TILE, 4):
            rect(d, cx, py + 3, 2, 11, shade(TR_LUIGI_BLANKET, -24))
        for cy in range(py + 5, py + 14, 4):
            rect(d, px, cy, TILE, 1, TR_LUIGI_CHECK)
        if right:
            rect(d, px + 10, py + 13, 6, 3, TR_LUIGI_BLANKET)


def paint_train_washing(d, rng, px, py, left_end, right_end):
    """Chiara's washing, hung out to dry on a line strung from the back of
    one seat to the other: the line across the tile, sagging, and on it,
    pegged, a blouse, a sock, a pair of trousers or a towel, dripping on
    the floor."""
    sag = (0, 1, 1, 2, 2, 2, 3, 3, 3, 3, 2, 2, 2, 1, 1, 0)
    for i in range(TILE):
        rect(d, px + i, py + 3 + sag[i] // 2, 1, 1, TR_OUTLINE)
    if left_end:
        rect(d, px, py + 1, 2, 4, TR_METAL_DARK)  # tied round the seat back
    if right_end:
        rect(d, px + TILE - 2, py + 1, 2, 4, TR_METAL_DARK)
    kind = rng.randrange(4)
    hx = px + 3
    top = py + 4
    if kind == 0:  # a blouse, navy like her polo
        rect(d, hx, top, 10, 9, TR_OUTLINE)
        rect(d, hx + 1, top + 1, 8, 7, (38, 53, 94))
        rect(d, hx - 1, top + 1, 2, 4, (38, 53, 94))
        rect(d, hx + 9, top + 1, 2, 4, (38, 53, 94))
        rect(d, hx + 4, top + 1, 2, 2, (220, 220, 214))
    elif kind == 1:  # a pair of socks
        _sock(d, hx + 1, top, TR_SOCK_BLUE)
        _sock(d, hx + 6, top + 1, (200, 60, 60))
    elif kind == 2:  # trousers, legs down
        rect(d, hx, top, 9, 10, TR_OUTLINE)
        rect(d, hx + 1, top + 1, 7, 2, (63, 58, 63))
        rect(d, hx + 1, top + 3, 3, 6, (63, 58, 63))
        rect(d, hx + 5, top + 3, 3, 6, (63, 58, 63))
    else:  # a pink towel
        rect(d, hx, top, 10, 8, TR_OUTLINE)
        rect(d, hx + 1, top + 1, 8, 6, (216, 150, 176))
        rect(d, hx + 1, top + 5, 8, 1, (190, 120, 150))
    rect(d, hx + 2, top - 1, 1, 2, (200, 180, 90))  # the pegs
    rect(d, hx + 7, top - 1, 1, 2, (200, 180, 90))
    rect(d, hx + rng.randrange(1, 8), py + 14, 1, 1, (120, 150, 190))


def paint_train_bag(d, px, py):
    """A full black bin bag, as big as the tile, knotted with its yellow
    ties: lumpy with what is in it, creased between the lumps, and shiny
    where the lamps catch the plastic."""
    rect(d, px + 1, py + 14, 15, 2, TR_OUTLINE)  # its shadow
    lumps = ((2, 4, 12, 11), (0, 7, 16, 7), (1, 5, 14, 9))
    for bx, by, w, h in lumps:
        rect(d, px + bx, py + by - 1, w, h + 2, TR_OUTLINE)
    for bx, by, w, h in lumps:
        rect(d, px + bx + 1, py + by, w - 2, h, TR_BAG)
    # The lit side of each lump, its rim and the creases.
    rect(d, px + 2, py + 6, 5, 7, TR_BAG_MID)
    rect(d, px + 9, py + 6, 4, 6, TR_BAG_MID)
    rect(d, px + 7, py + 5, 1, 9, TR_OUTLINE)
    rect(d, px + 3, py + 6, 2, 1, TR_BAG_LIGHT)
    rect(d, px + 2, py + 7, 1, 4, TR_BAG_LIGHT)
    rect(d, px + 10, py + 6, 2, 1, TR_BAG_LIGHT)
    rect(d, px + 12, py + 7, 1, 2, TR_BAG_LIGHT)
    rect(d, px + 4, py + 12, 2, 1, TR_BAG_MID)
    # The neck gathered up and the knot, its two ties sticking out.
    rect(d, px + 5, py + 1, 6, 5, TR_OUTLINE)
    rect(d, px + 6, py + 2, 4, 3, TR_BAG_MID)
    rect(d, px + 7, py + 2, 1, 1, TR_BAG_LIGHT)
    rect(d, px + 3, py, 3, 2, TR_BAG_TIE)
    rect(d, px + 10, py, 3, 2, TR_BAG_TIE)
    rect(d, px + 6, py + 4, 4, 1, TR_BAG_TIE)


def paint_train_litter(d, rng, px, py):
    """What Luigi drinks, left where it was finished: a wine bottle, a
    beer or a clear one of grappa lying on its side, another standing or
    a crushed can, and the sticky ring the last drops left."""
    rect(d, px + rng.randrange(0, 5), py + rng.randrange(10, 13), 8, 3,
         TR_STAIN)

    def bottle(bx, by, glass, body, neck, label):
        """Lying left to right, the neck to the right, outlined."""
        rect(d, bx - 1, by - 1, body + 2, 7, TR_OUTLINE)
        rect(d, bx + body, by + 1, neck + 1, 3, TR_OUTLINE)
        rect(d, bx, by, body, 5, glass)
        rect(d, bx + body - 1, by + 1, 1, 3, glass)  # the shoulder
        rect(d, bx + body, by + 2, neck, 1, glass)
        rect(d, bx + body + neck - 1, by + 1, 1, 3, shade(glass, -45))
        rect(d, bx + 1, by + 1, body - 2, 1, shade(glass, 80))  # shine
        rect(d, bx, by + 4, body, 1, shade(glass, -40))
        if label:
            rect(d, bx + 2, by, 4, 5, label)
            rect(d, bx + 3, by + 2, 2, 1, TR_LABEL_RED)

    kind = rng.randrange(3)
    top = py + rng.randrange(1, 4)
    if kind == 0:  # wine, long and dark, its label cream
        bottle(px + 1, top, TR_GLASS_GREEN, 10, 4, TR_LABEL_CREAM)
    elif kind == 1:  # beer, shorter and brown
        bottle(px + 2, top, TR_GLASS_BROWN, 8, 3, TR_LABEL_CREAM)
    else:  # grappa, clear
        bottle(px + 1, top, TR_GLASS_CLEAR, 9, 4, TR_LABEL_RED)
    if rng.random() < 0.5:
        # Another standing up, seen from above: the round shoulder and
        # the mouth of its neck.
        sx, sy = px + rng.randrange(9, 12), py + rng.randrange(8, 11)
        glass = rng.choice((TR_GLASS_GREEN, TR_GLASS_BROWN))
        rect(d, sx, sy - 1, 4, 6, TR_OUTLINE)
        rect(d, sx - 1, sy, 6, 4, TR_OUTLINE)
        rect(d, sx, sy, 4, 4, glass)
        rect(d, sx + 1, sy + 1, 2, 2, shade(glass, -60))
        rect(d, sx, sy, 1, 1, shade(glass, 80))
    else:
        cx, cy = px + rng.randrange(9, 11), py + rng.randrange(9, 12)
        rect(d, cx - 1, cy - 1, 7, 6, TR_OUTLINE)
        rect(d, cx, cy, 5, 4, TR_CAN_RED)
        rect(d, cx, cy, 1, 4, TR_CAN_SILVER)
        rect(d, cx + 4, cy + 1, 1, 2, TR_CAN_SILVER)
        rect(d, cx + 1, cy + 1, 3, 1, shade(TR_CAN_RED, 45))


def paint_book_closed(d, bx, by, w, h, cover):
    """A hardback lying shut, seen from above: its cover, a darker spine
    down the left with two gilt bands, and the pages showing at the
    other three edges."""
    rect(d, bx - 1, by - 1, w + 2, h + 2, TR_OUTLINE)
    rect(d, bx, by, w, h, TR_PAGE_EDGE)
    rect(d, bx, by, w - 1, h - 1, cover)
    rect(d, bx, by, 2, h, shade(cover, -35))
    rect(d, bx, by + 1, 2, 1, TR_GILT)
    rect(d, bx, by + h - 3, 2, 1, TR_GILT)
    rect(d, bx + 2, by, w - 3, 1, shade(cover, 30))


def paint_book_open(d, bx, by, cover, rng):
    """A book open face up: two pages bowed into the spine, lines of print
    on them, the cover showing round the edge."""
    rect(d, bx - 1, by - 1, 14, 10, TR_OUTLINE)
    rect(d, bx, by, 12, 8, cover)
    rect(d, bx + 1, by, 5, 7, TR_PAGES)
    rect(d, bx + 6, by, 5, 7, shade(TR_PAGES, -10))
    rect(d, bx + 5, by, 2, 7, TR_PAGE_EDGE)  # the gutter
    for line in range(by + 1, by + 6):
        rect(d, bx + 1 + (line == by + 1), line, rng.randrange(2, 4), 1,
             TR_INK)
        rect(d, bx + 7, line, rng.randrange(2, 4), 1, TR_INK)


def paint_notebook(d, bx, by, rng):
    """A notebook of Mario's, open on squared paper, the notes in blue and
    a pencil across it."""
    rect(d, bx - 1, by - 1, 10, 12, TR_OUTLINE)
    rect(d, bx, by, 8, 10, TR_PAPER)
    rect(d, bx, by, 1, 10, (40, 40, 44))  # the spiral
    for line in range(by + 2, by + 9, 2):
        rect(d, bx + 2, line, rng.randrange(3, 6), 1, (48, 70, 140))
    rect(d, bx + 3, by + 7, 7, 1, (214, 170, 50))  # the pencil
    rect(d, bx + 9, by + 7, 1, 1, TR_INK)


def paint_train_papers(d, rng, px, py):
    """What Mario reads and writes, on the floor round his cot: a pile of
    hardbacks, a book left open, or his notebook with a loose sheet."""
    covers = list(TR_BOOK_COVERS)
    rng.shuffle(covers)
    kind = rng.choice((0, 0, 1, 2))  # mostly books
    if kind == 0:  # a pile, each book a little askew on the one below
        for i, (dx, dy) in enumerate(((2, 6), (3, 4), (2, 2))):
            paint_book_closed(d, px + dx + rng.randrange(0, 2), py + dy,
                              10 - i, 8, covers[i])
    elif kind == 1:
        paint_book_open(d, px + 2, py + 4, covers[0], rng)
    else:
        rect(d, px + 9, py + 3, 6, 7, TR_PAPER_SHADE)  # a loose sheet
        rect(d, px + 9, py + 2, 6, 7, TR_PAPER)
        for line in range(py + 4, py + 8, 2):
            rect(d, px + 10, line, 4, 1, TR_INK)
        paint_notebook(d, px + 2, py + 4, rng)


def paint_train_books(d, px, py, first):
    """A crate for a desk, with books on it: on its left end one open
    face up beside a closed one, otherwise a pile of hardbacks and a
    row of them standing, their spines out."""
    rect(d, px, py + 3, TILE, 12, TR_CRATE_DARK)
    rect(d, px, py + 3, TILE, 10, TR_CRATE)
    rect(d, px, py + 7, TILE, 1, TR_CRATE_DARK)
    rect(d, px, py + 11, TILE, 1, TR_CRATE_DARK)
    if first:
        rng = random.Random(7)
        paint_book_open(d, px + 1, py + 2, TR_BOOK_COVERS[0], rng)
        paint_book_closed(d, px + 11, py + 8, 5, 6, TR_BOOK_COVERS[1])
        return
    # A pile of three, lying shut.
    for i, cover in enumerate(TR_BOOK_COVERS[1:4]):
        paint_book_closed(d, px + 1 + i % 2, py + 7 - 2 * i, 7, 5, cover)
    # Standing in a row: tall spines, a band of gilt on each.
    for i, cover in enumerate((TR_BOOK_COVERS[4], TR_BOOK_COVERS[0],
                               TR_BOOK_COVERS[2])):
        sx = px + 10 + 2 * i
        rect(d, sx, py + 1, 2, 11, TR_OUTLINE)
        rect(d, sx, py + 2, 2, 9, cover)
        rect(d, sx, py + 4, 2, 1, TR_GILT)
        rect(d, sx, py + 2, 1, 9, shade(cover, 25))


def _train_desk(d, px, py):
    """The crate Mario uses for a desk, seen from above."""
    rect(d, px, py + 3, TILE, 12, TR_CRATE_DARK)
    rect(d, px, py + 3, TILE, 10, TR_CRATE)
    rect(d, px, py + 7, TILE, 1, TR_CRATE_DARK)
    rect(d, px, py + 11, TILE, 1, TR_CRATE_DARK)


def paint_train_abacus(d, px, py):
    """The middle of the desk: a wooden abacus, its beads in red and
    cream on three wires, and beside it a grey pocket calculator with its
    green display and rows of keys."""
    _train_desk(d, px, py)
    # the abacus
    rect(d, px, py + 1, 9, 10, TR_OUTLINE)
    rect(d, px + 1, py + 2, 7, 8, TR_WOOD_LIGHT)
    rect(d, px + 2, py + 3, 5, 6, TR_CRATE_DARK)
    for i, wire in enumerate((py + 4, py + 6, py + 8)):
        rect(d, px + 2, wire, 5, 1, TR_METAL_LIGHT)
        for b in range(2 + i % 2):
            colour = TR_LABEL_RED if (b + i) % 2 else TR_LABEL_CREAM
            rect(d, px + 2 + b + i % 2 * 2, wire, 1, 1, colour)
    # the calculator
    rect(d, px + 9, py + 4, 7, 10, TR_OUTLINE)
    rect(d, px + 10, py + 5, 5, 8, TR_METAL)
    rect(d, px + 10, py + 5, 5, 2, (120, 170, 110))  # the display
    rect(d, px + 11, py + 6, 3, 1, (60, 90, 56))
    for ky in (py + 8, py + 10, py + 12):
        for kx in (px + 10, px + 12, px + 14):
            rect(d, kx, ky, 1, 1, TR_METAL_LIGHT)


def paint_train_mug(d, px, py):
    """The right end of the desk: Mario's tin mug and a candle stub in a
    puddle of its own wax."""
    _train_desk(d, px, py)
    rect(d, px + 2, py + 4, 6, 6, TR_OUTLINE)  # the mug, from above
    rect(d, px + 3, py + 5, 4, 4, TR_METAL_LIGHT)
    rect(d, px + 4, py + 6, 2, 2, (70, 44, 26))  # coffee
    rect(d, px + 8, py + 6, 2, 2, TR_OUTLINE)  # its handle
    rect(d, px + 10, py + 9, 5, 3, TR_LABEL_CREAM)  # wax
    rect(d, px + 11, py + 6, 3, 5, TR_PILLOW)  # the candle
    rect(d, px + 12, py + 4, 1, 2, TR_LAMP)  # its flame
    rect(d, px + 12, py + 5, 1, 1, (240, 170, 60))


def paint_train_food_table(d):
    """The narrow table the two of them eat at, three tiles long against
    the wall, seen from above: a white cloth with a red border, and on it
    a leg of prosciutto on its stand, a salame with a few slices cut, a
    wheel of cheese with a wedge out of it and a round loaf."""
    w, h = TR_FOOD_TABLE_TILES[0] * TILE, TR_FOOD_TABLE_TILES[1] * TILE
    rect(d, 1, h - 2, w - 2, 2, TR_OUTLINE)  # its shadow
    rect(d, 0, 0, w, h - 2, TR_OUTLINE)
    rect(d, 1, 0, w - 2, h - 3, TR_CLOTH)
    rect(d, 1, h - 5, w - 2, 1, TR_CLOTH_STRIPE)  # the border
    rect(d, 1, h - 4, w - 2, 1, TR_CLOTH_SHADE)

    # The prosciutto: the whole leg, lying on its side, broad and round
    # at the cut end, where the pink meat shows in its ring of white fat,
    # narrowing to the shank, with the bone and the string to hang it by.
    d.polygon([(2, 2), (8, 1), (15, 4), (15, 8), (8, 12), (2, 11)],
              fill=TR_OUTLINE)
    d.ellipse((1, 1, 11, 12), fill=TR_OUTLINE)
    d.polygon([(5, 2), (9, 2), (14, 5), (14, 7), (9, 11), (5, 11)],
              fill=TR_HAM_RIND)
    d.ellipse((2, 2, 10, 11), fill=TR_HAM_FAT)  # the fat round the cut
    d.ellipse((3, 3, 9, 10), fill=TR_HAM)
    rect(d, 4, 5, 3, 1, shade(TR_HAM, 28))
    rect(d, 5, 8, 3, 1, TR_HAM_DARK)
    rect(d, 11, 4, 3, 1, shade(TR_HAM_RIND, 30))  # the shine on the rind
    rect(d, 15, 5, 1, 3, TR_BONE)  # the bone at the shank
    rect(d, 16, 4, 1, 1, TR_TWINE)
    rect(d, 16, 8, 1, 1, TR_TWINE)

    # The salame: a long one with round ends, flecked with fat, the cut
    # end pale, and two slices off it.
    rect(d, 18, 2, 10, 6, TR_OUTLINE)
    rect(d, 17, 3, 12, 4, TR_OUTLINE)
    rect(d, 19, 3, 8, 4, TR_SALAMI)
    rect(d, 18, 4, 10, 2, TR_SALAMI)
    rect(d, 19, 3, 8, 1, shade(TR_SALAMI, 45))
    for fx, fy in ((20, 5), (22, 4), (24, 5), (26, 4)):
        rect(d, fx, fy, 1, 1, TR_SALAMI_FAT)
    rect(d, 27, 4, 1, 2, TR_SALAMI_FAT)  # the cut end
    rect(d, 17, 4, 1, 1, TR_TWINE)  # the knot
    for sx in (20, 24):
        rect(d, sx - 1, 8, 4, 5, TR_OUTLINE)
        rect(d, sx - 2, 9, 6, 3, TR_OUTLINE)
        rect(d, sx - 1, 9, 4, 3, TR_SALAMI)
        rect(d, sx, 10, 1, 1, TR_SALAMI_FAT)
        rect(d, sx + 2, 9, 1, 1, TR_SALAMI_FAT)

    # The cheese: a wheel, its rind, a wedge cut out of it.
    d.ellipse((28, 1, 39, 12), fill=TR_OUTLINE)
    d.ellipse((29, 2, 38, 11), fill=TR_CHEESE_RIND)
    d.ellipse((30, 3, 37, 10), fill=TR_CHEESE)
    d.polygon([(34, 6), (39, 1), (39, 6)], fill=TR_CLOTH)
    rect(d, 34, 6, 5, 1, TR_CHEESE_RIND)
    rect(d, 32, 7, 1, 1, TR_CHEESE_RIND)

    # The loaf, round, the cross cut into its crust.
    d.ellipse((39, 2, 47, 11), fill=TR_OUTLINE)
    d.ellipse((40, 3, 46, 10), fill=TR_BREAD)
    rect(d, 41, 4, 3, 1, shade(TR_BREAD, 34))
    rect(d, 43, 4, 1, 6, TR_BREAD_CRUST)
    rect(d, 41, 6, 5, 1, TR_BREAD_CRUST)


def paint_train_weapons(d):
    """Mario's weapons table, three tiles long against the wall, seen from
    above: the shotgun laid along it, the pistol with a magazine beside it,
    an open box of rounds standing in rows and a few red shotgun shells."""
    w, h = TR_WEAPON_TABLE_TILES[0] * TILE, TR_WEAPON_TABLE_TILES[1] * TILE
    rect(d, 1, h - 2, w - 2, 2, TR_OUTLINE)  # its shadow
    rect(d, 0, 0, w, h - 2, TR_OUTLINE)
    rect(d, 1, 0, w - 2, h - 3, TR_TABLE_DARK)
    for gx in range(1, w - 1, 8):  # the planks
        rect(d, gx, 0, 1, h - 3, shade(TR_TABLE_DARK, -22))
    rect(d, 1, h - 4, w - 2, 1, shade(TR_TABLE_DARK, -30))

    # The shotgun, all the way along: the barrel, the pump, the stock.
    rect(d, 2, 1, 34, 4, TR_OUTLINE)
    rect(d, 3, 2, 22, 1, TR_GUN_LIGHT)  # the barrel
    rect(d, 3, 3, 22, 1, TR_GUN)
    rect(d, 8, 2, 6, 2, TR_WOOD)  # the pump
    rect(d, 25, 2, 4, 2, TR_GUN)  # the receiver
    rect(d, 29, 1, 8, 4, TR_OUTLINE)
    rect(d, 29, 2, 7, 2, TR_WOOD_LIGHT)  # the stock
    rect(d, 30, 3, 6, 1, TR_WOOD)

    # The pistol, on its side: the slide with its port and sights, the
    # frame, the trigger in its guard and the grip raked back.
    rect(d, 2, 6, 13, 5, TR_OUTLINE)
    rect(d, 3, 7, 11, 2, TR_GUN_LIGHT)  # the slide
    rect(d, 3, 7, 11, 1, shade(TR_GUN_LIGHT, 40))
    rect(d, 8, 8, 2, 1, TR_OUTLINE)  # the ejection port
    rect(d, 3, 9, 11, 1, TR_GUN)  # the frame
    rect(d, 7, 10, 4, 3, TR_OUTLINE)  # the trigger guard
    rect(d, 8, 10, 2, 2, TR_TABLE_DARK)
    rect(d, 9, 10, 1, 1, TR_GUN)  # the trigger
    rect(d, 10, 10, 5, 3, TR_OUTLINE)
    rect(d, 11, 12, 5, 2, TR_OUTLINE)
    rect(d, 11, 10, 3, 2, TR_GUN)  # the grip, raked back
    rect(d, 12, 12, 3, 1, TR_GUN)
    rect(d, 12, 11, 1, 1, TR_GUN_LIGHT)
    # A magazine beside it.
    rect(d, 14, 7, 3, 7, TR_OUTLINE)
    rect(d, 15, 8, 1, 5, TR_GUN)
    rect(d, 15, 8, 1, 1, TR_BRASS)

    # The box of rounds, open: brass bases in rows, each with its primer.
    rect(d, 19, 6, 13, 8, TR_OUTLINE)
    rect(d, 20, 7, 11, 6, TR_AMMO_BOX)
    for bx in range(21, 30, 2):
        for by in (8, 10):
            rect(d, bx, by, 1, 1, TR_BRASS)
    rect(d, 20, 12, 11, 1, shade(TR_AMMO_BOX, -30))

    # Red shotgun shells lying about, their brass heads.
    for sx, sy in ((34, 7), (38, 9), (35, 11)):
        rect(d, sx - 1, sy - 1, 6, 3, TR_OUTLINE)
        rect(d, sx, sy, 3, 1, TR_SHELL_RED)
        rect(d, sx + 3, sy, 1, 1, TR_BRASS)
    rect(d, 41, 5, 4, 1, TR_GUN_LIGHT)  # a cleaning rod


def paint_train_lamp(d, px, py):
    rect(d, px + 3, py + 5, 10, 5, TR_METAL_DARK)
    rect(d, px + 4, py + 6, 8, 3, TR_LAMP)
    rect(d, px + 6, py + 10, 4, 1, shade(TR_LAMP, -52))


def train_nose_edge(room):
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


def train_nose(room):
    """Clears everything past the nose's edge and draws the shell round it,
    with the windscreen just inside: glass along the front, a frame line,
    and the pillars at the two corners. Returns the picture and the tile
    it starts from: from the column before the first windscreen tile to
    the end of the row, over every row of the place."""
    edge = train_nose_edge(room)
    first = min(x for y in range(room.height) for x in range(room.width)
                if room.at(x, y) == "V") - 1
    left = first * TILE
    sprite = Image.new("RGBA", ((room.width - first) * TILE,
                                room.height * TILE), TRANSPARENT)
    pixels = sprite.load()
    glass_top = min(y for y in range(room.height)
                    if "V" in room.rows[y]) * TILE
    glass_bottom = (max(y for y in range(room.height)
                        if "V" in room.rows[y]) + 1) * TILE
    void = TR_VOID + (255,)
    for py in range(room.height * TILE):
        x_edge = int(round(edge[py]))
        if x_edge < left:
            continue
        for px in range(left, room.width * TILE):
            depth = x_edge - px
            if depth <= 0:
                colour = void
            elif depth <= 2:
                colour = TR_SHELL_DARK
            elif depth <= 4:
                colour = TR_SHELL
            elif depth <= 10 and glass_top + 4 <= py < glass_bottom - 4:
                light = 7 <= depth <= 8 and (py // 6) % 3 == 0
                colour = TR_GLASS_LIGHT if light else TR_GLASS
            elif depth == 11 and glass_top + 4 <= py < glass_bottom - 4:
                colour = TR_WINDSCREEN_FRAME
            else:
                continue
            pixels[px - left, py] = colour + (255,) if len(colour) == 3 \
                else colour
    # The pillars where the windscreen meets the roof and the floor.
    d = ImageDraw.Draw(sprite)
    for py in (glass_top + 3, glass_bottom - 6):
        x_edge = int(round(edge[py]))
        rect(d, x_edge - 12 - left, py, 9, 3, TR_SHELL_DARK)
    return sprite, first


def train_interior(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.trainInterior."""
    from street_paint import read_rows  # noqa: PLC0415 - the nose

    rows = read_rows(TR_ROWS)
    # Not under Mario's desk (K, q, k): it stands on black, a dark edge
    # above and below it.
    floored = ".SLTCh*bBuofEPlVaGYROcm~j"
    floor = [
        atlas.bucket(lambda p=parity: cell(
            lambda d, gx, gy: paint_train_floor(d, rng, gx, gy), p, 0))
        for parity in (0, 1)
    ]

    def one(paint):
        return [atlas.bucket(lambda: tile_of(lambda d: paint(d, 0, 0)), 1)]

    def randomly(paint):
        return [atlas.bucket(lambda: tile_of(
            lambda d: paint(d, rng, 0, 0)))]

    def run_ends(paint, glyph):
        """Four tiles for a run of `glyph`: key bit 0 is a neighbour to the
        left, bit 1 one to the right; `paint(d, first, last)`."""
        return [atlas.bucket(lambda i=i: tile_of(
            lambda d: paint(d, not i & 1, not i & 2)), 1) for i in range(4)]

    rules = [rule("ground", floored, floor, [parity_key()])]

    # The hull. The north wall has a window on two tiles in every four;
    # the end walls of the coaches, running north-south, are seen from
    # above as one band down their whole length, closed off only where
    # the aisle goes through. Key bits: the two of the windows, then a
    # wall above, below, to the left and to the right.
    def hull(i):
        window = 1 if i & 3 in (1, 2) else 0
        above, below = bool(i & 4), bool(i & 8)
        across = bool(i & 16) or bool(i & 32)
        if (above or below) and not across:
            return tile_of(lambda d: paint_train_end_wall(
                d, 0, 0, open_above=not above, open_below=not below))
        return cell(lambda d, gx, gy: paint_train_shell(d, "W", gx, gy),
                    window, 0)

    rules.append(rule(
        "structures", "W",
        [atlas.bucket(lambda i=i: hull(i), 1) for i in range(64)],
        [pattern_key(1, 0, 4, 1), pattern_key(1, 0, 4, 2),
         neighbour_key(0, -1, "W"), neighbour_key(0, 1, "W"),
         neighbour_key(-1, 0, "W"), neighbour_key(1, 0, "W")]))
    rules.append(rule("structures", "w", [atlas.bucket(lambda: tile_of(
        lambda d: paint_train_shell(d, "w", 0, 0)), 1)]))
    rules.append(rule("structures", "Ii", [atlas.bucket(lambda: tile_of(
        lambda d: paint_train_shell(d, "I", 0, 0)), 1)]))
    rules.append(rule("structures", "E", one(paint_train_exit)))
    rules.append(rule(
        "structures", "S",
        run_ends(lambda d, left, right: paint_train_seat(d, 0, 0, left,
                                                         right), "S"),
        [neighbour_key(-1, 0, "S"), neighbour_key(1, 0, "S")]))
    rules.append(rule("structures", "T", one(paint_train_table)))
    rules.append(rule("structures", "L", randomly(paint_train_luggage)))

    # Mario's wardrobe and suitcases, Luigi's open ones: each painted
    # whole and cut to the tile its place in the run asks for.
    def cut(paint, glyph, width):
        def tile(first, last):
            if first and last:
                return tile_of(lambda d: paint(d, 0, 0, 1))
            index = 0 if first else (width - 1 if last else 1)
            return tile_of(lambda d: paint(d, -index * TILE, 0, width))
        return rule("structures", glyph,
                    [atlas.bucket(lambda i=i: tile(not i & 1, not i & 2), 1)
                     for i in range(4)],
                    [neighbour_key(-1, 0, glyph), neighbour_key(1, 0, glyph)])

    rules.append(cut(paint_train_wardrobe, "R", 3))
    rules.append(cut(paint_train_suitcases, "Y", 2))
    rules.append(cut(paint_train_open_suitcase, "O", 2))
    rules.append(rule("structures", "c", randomly(paint_train_luigi_clothes)))
    rules.append(rule("structures", "m", randomly(paint_train_underwear)))
    rules.append(rule("structures", "C", randomly(paint_train_control)))
    rules.append(rule("structures", "h", one(paint_train_driver_seat)))
    rules.append(rule("structures", "*", one(paint_train_lamp)))

    # A camp bed: a run of `b` or `B`, its pillow at the end that lies
    # against a wall. Bits, in key order: something of the same glyph to
    # the left, to the right, and a wall before the start of the run.
    for glyph in "bB":
        buckets = []
        for index in range(8):
            same_left, same_right, walled = (
                bool(index & 1), bool(index & 2), bool(index & 4))

            def around(x, y, l=same_left, r=same_right, w=walled, g=glyph):
                before = "W" if w else "."
                if x == -1:
                    return g if l else before
                if x == -2:
                    return before if l else "."
                if x == 1:
                    return g if r else "."
                return "."
            room = Neighbourhood(glyph, around)
            buckets.append(atlas.bucket(lambda rm=room, g=glyph: tile_of(
                lambda d: paint_train_cot(d, rm, 0, 0, g)), 1))
        rules.append(rule("structures", glyph, buckets,
                          [neighbour_key(-1, 0, glyph),
                           neighbour_key(1, 0, glyph),
                           before_run_key(TR_COT_WALLS)]))
    rules.append(rule("structures", "u", one(paint_train_bag)))
    rules.append(rule("structures", "o", randomly(paint_train_litter)))
    # The line tied round a seat back at either end of its run.
    ends = [neighbour_key(-1, 0, "~"), neighbour_key(1, 0, "~")]
    rules.append(rule("structures", "~", [atlas.bucket(
        lambda i=index: tile_of(lambda d: paint_train_washing(
            d, rng, 0, 0, not i & 1, not i & 2)))
        for index in range(4)], ends))
    rules.append(rule("structures", "f", randomly(paint_train_papers)))
    rules.append(rule("structures", "K", one(
        lambda d, px, py: paint_train_books(d, px, py, True))))
    rules.append(rule("structures", "k", one(paint_train_abacus)))
    rules.append(rule("structures", "q", one(paint_train_mug)))

    table = Image.new("RGBA", tuple(n * TILE for n in TR_MAP_TABLE_TILES),
                      TRANSPARENT)
    paint_train_map_table(table)
    weapons = Image.new("RGBA",
                        tuple(n * TILE for n in TR_WEAPON_TABLE_TILES),
                        TRANSPARENT)
    paint_train_weapons(ImageDraw.Draw(weapons))
    food = Image.new("RGBA", tuple(n * TILE for n in TR_FOOD_TABLE_TILES),
                     TRANSPARENT)
    paint_train_food_table(ImageDraw.Draw(food))
    nose, first = train_nose(Room(rows))
    return {
        "void": "#000000",
        "voidGlyph": "x",
        "rules": rules,
        "objects": [
            {"glyph": "P", "image": "train_map_table.png",
             "tiles": list(TR_MAP_TABLE_TILES), "sprite": table},
            {"glyph": "a", "image": "train_weapons_table.png",
             "tiles": list(TR_WEAPON_TABLE_TILES), "sprite": weapons},
            {"glyph": "G", "image": "train_food_table.png",
             "tiles": list(TR_FOOD_TABLE_TILES), "sprite": food},
            {"at": [first, 0], "image": "train_nose.png", "sprite": nose,
             "under": [row[first:] for row in rows]},
        ],
    }
