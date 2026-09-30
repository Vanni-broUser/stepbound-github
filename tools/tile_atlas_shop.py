"""The Elettronica in the tile atlas: the one shop in Molfetta still open,
on the road east of the monument's square
(lib/core/levels/hometown/electronics_shop.dart).

A module of its own, the way docs/level_pipeline.md wants the interiors to
go: build_tile_atlas.py only lists it. A high-street electronics shop seen
from above like the company's offices, whose walls, partitions and doors it
borrows: pale ceramic tiles, televisions on their stands along the back
wall with their screens still on, white goods, the displays of phones and
laptops, the till by the door; behind a partition the storeroom, its steel
shelving and its piles of boxes, and at the bottom of it the back door.
What stands taller than its cell leans out over the row above (`leaning`).
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import street_props as props  # noqa: E402
import tile_atlas_company as company  # noqa: E402
import tile_atlas_palazzo as palazzo  # noqa: E402
from street_paint import TILE, rect, shade  # noqa: E402
from tile_atlas_core import (  # noqa: E402
    Atlas,
    ground_config,
    leaning,
    neighbour_key,
    rule,
    spread,
    tile_of,
)

EL_TILE = (212, 212, 206)
EL_TILE_ALT = (200, 202, 198)
EL_GROUT = (170, 172, 168)
EL_WALL = (222, 224, 220)
EL_BAND = (26, 46, 96)
EL_BAND_LIGHT = (120, 220, 240)
EL_BLACK = (24, 24, 28)
EL_PLASTIC = (48, 50, 58)
EL_SCREEN = (70, 170, 210)
EL_SCREEN_GLOW = (200, 240, 250)
EL_WHITE = (232, 232, 226)
EL_WHITE_SHADE = (184, 186, 182)
EL_STEEL = (150, 154, 160)
EL_STEEL_DARK = (92, 96, 104)
EL_CARDBOARD = (176, 136, 88)
EL_CARDBOARD_DARK = (132, 98, 60)
EL_TAPE = (210, 190, 140)
EL_NIGHT = (22, 26, 36)
EL_WALLS = "xWwID"


# ------------------------------------------------------------ the floor


def paint_floor(d, rng, px, py):
    """Pale ceramic tiles, four to a cell, a crack or a scuff here and
    there."""
    for i in (0, 8):
        for j in (0, 8):
            colour = EL_TILE if (i + j) // 8 % 2 == 0 else EL_TILE_ALT
            rect(d, px + i, py + j, 8, 8, colour)
    rect(d, px, py, TILE, 1, EL_GROUT)
    rect(d, px, py + 8, TILE, 1, EL_GROUT)
    rect(d, px, py, 1, TILE, EL_GROUT)
    rect(d, px + 8, py, 1, TILE, EL_GROUT)
    if rng.random() < 0.15:  # a crack across a tile
        x, y = px + rng.randrange(2, 10), py + rng.randrange(2, 10)
        for k in range(4):
            rect(d, x + k, y + k // 2, 1, 1, shade(EL_GROUT, -30))
    if rng.random() < 0.15:  # a black scuff of a sole
        rect(d, px + rng.randrange(2, 10), py + rng.randrange(3, 12), 5, 1,
             shade(EL_TILE, -60))


# -------------------------------------------------------------- the walls


def paint_wall(d, rng, px, py, upper):
    """The back wall face on, two tiles tall: the ceiling's edge and the
    white plaster, and on the lower course the shop's blue band, with a
    poster of the offers now and then."""
    if upper:
        rect(d, px, py, TILE, 5, company.CO_WALL_TOP)
        rect(d, px, py + 5, TILE, 11, EL_WALL)
        rect(d, px, py + 5, TILE, 1, company.CO_WALL_TOP_LIGHT)
        if rng.random() < 0.15:  # a poster: SOTTOCOSTO, a price in red
            rect(d, px + 3, py + 7, 10, 8, (240, 210, 60))
            rect(d, px + 4, py + 8, 8, 2, (200, 40, 36))
            rect(d, px + 5, py + 11, 6, 3, (200, 40, 36))
        return
    rect(d, px, py, TILE, 10, EL_WALL)
    rect(d, px, py + 10, TILE, 3, EL_BAND)
    rect(d, px, py + 11, TILE, 1, EL_BAND_LIGHT)
    rect(d, px, py + 13, TILE, 3, shade(EL_BAND, -12))
    if rng.random() < 0.08:  # blood smeared along the band
        sx = px + rng.randrange(2, 10)
        rect(d, sx, py + 6, 5, 3, props.BLOOD)
        rect(d, sx + 2, py + 9, 1, 4, props.BLOOD_DARK)


def paint_back_door(d, px, py):
    """The back door open, as the background has it: the steel frame, and
    the street behind the barracks dark beyond it. The leaf, while it is
    still bolted, is drawn over it by the game."""
    rect(d, px, py, TILE, 7, company.CO_WALL_TOP)
    rect(d, px, py, TILE, 1, company.CO_WALL_TOP_LIGHT)
    rect(d, px + 1, py + 2, TILE - 2, 14, EL_NIGHT)
    rect(d, px + 1, py + 2, 2, 14, EL_STEEL)
    rect(d, px + TILE - 3, py + 2, 2, 14, EL_STEEL_DARK)
    rect(d, px + 4, py + 12, 8, 1, (60, 64, 74))  # the step outside


# ------------------------------------------------------------ the shop


def paint_television(d, rng, px, py):
    """A television on its black stand, bigger than its cell, still on:
    the test card or the blue of no signal."""
    rect(d, px + 3, py + 11, 10, 4, EL_PLASTIC)  # the stand
    rect(d, px + 3, py + 11, 10, 1, shade(EL_PLASTIC, 30))
    rect(d, px + 7, py + 8, 2, 3, EL_BLACK)
    rect(d, px, py - 6, TILE, 14, EL_BLACK)  # the set
    if rng.random() < 0.5:
        rect(d, px + 1, py - 5, TILE - 2, 11, EL_SCREEN)
        rect(d, px + 2, py - 4, 5, 1, EL_SCREEN_GLOW)
    else:
        for i, colour in enumerate(((220, 220, 220), (220, 210, 60),
                                    (60, 200, 210), (60, 190, 70),
                                    (200, 60, 190), (200, 50, 50),
                                    (50, 60, 200))):
            rect(d, px + 1 + i * 2, py - 5, 2, 11, colour)
    if rng.random() < 0.3:  # the screen cracked by a fist
        rect(d, px + 5, py - 3, 1, 5, EL_BLACK)
        rect(d, px + 6, py - 1, 3, 1, EL_BLACK)


def paint_appliance(d, rng, px, py):
    """A white fridge or a washing machine, leaning up into the row
    above, its price tag still stuck on."""
    rect(d, px + 1, py - 7, 14, 22, EL_WHITE)
    rect(d, px + 1, py - 7, 14, 2, (248, 248, 244))
    rect(d, px + 12, py - 7, 3, 22, EL_WHITE_SHADE)
    if rng.random() < 0.5:  # the fridge: its two doors and handle
        rect(d, px + 1, py + 1, 11, 1, EL_WHITE_SHADE)
        rect(d, px + 3, py - 4, 1, 4, EL_STEEL_DARK)
        rect(d, px + 3, py + 3, 1, 6, EL_STEEL_DARK)
    else:  # the washing machine: its porthole
        rect(d, px + 2, py - 5, 9, 2, EL_WHITE_SHADE)
        rect(d, px + 3, py, 8, 8, EL_STEEL)
        rect(d, px + 4, py + 1, 6, 6, (70, 90, 110))
        rect(d, px + 5, py + 2, 2, 1, (170, 200, 220))
    rect(d, px + 6, py - 3, 4, 2, (240, 210, 60))  # the price
    rect(d, px + 1, py + 14, 14, 1, EL_BLACK)


def paint_display(d, rng, px, py):
    """A display table of phones and laptops, the devices on their
    security cables, the ones the looters left."""
    rect(d, px, py + 1, TILE, 13, (236, 236, 232))
    rect(d, px, py + 13, TILE, 3, EL_STEEL_DARK)
    rect(d, px, py + 1, TILE, 1, (250, 250, 248))
    if rng.random() < 0.5:  # a laptop, open, its screen still lit
        rect(d, px + 2, py + 3, 12, 5, EL_PLASTIC)
        rect(d, px + 3, py + 4, 10, 3, EL_SCREEN)
        rect(d, px + 2, py + 8, 12, 4, (150, 152, 160))
    else:  # phones on their stands, a gap where one was torn off
        for i in range(3):
            if i == 1 and rng.random() < 0.5:
                rect(d, px + 2 + i * 5, py + 8, 1, 4, EL_BLACK)  # the cable
                continue
            rect(d, px + 2 + i * 5, py + 4, 3, 6, EL_BLACK)
            rect(d, px + 3 + i * 5, py + 5, 1, 3, EL_SCREEN)
    rect(d, px + rng.randrange(2, 12), py + 11, 3, 1, (240, 210, 60))


def paint_shelving(d, rng, px, py):
    """The storeroom's steel shelving, boxes on every shelf."""
    rect(d, px + 1, py - 6, 14, 21, EL_STEEL_DARK)
    for sy in (py - 5, py + 2, py + 9):
        rect(d, px + 1, sy + 5, 14, 1, EL_STEEL)
        x = px + 2
        while x < px + 14:
            bw = rng.randint(3, 6)
            bw = min(bw, px + 14 - x)
            rect(d, x, sy + 1, bw, 4, rng.choice((EL_CARDBOARD, EL_WHITE,
                                                  EL_CARDBOARD_DARK)))
            x += bw + 1
    rect(d, px + 1, py - 6, 1, 21, EL_STEEL)
    rect(d, px + 14, py - 6, 1, 21, EL_STEEL)


def paint_boxes(d, rng, px, py):
    """Cardboard boxes piled up, televisions still in them."""
    rect(d, px + 1, py + 2, 14, 12, EL_CARDBOARD)
    rect(d, px + 1, py + 2, 14, 2, shade(EL_CARDBOARD, 24))
    rect(d, px + 7, py + 2, 2, 12, EL_TAPE)
    rect(d, px + 3, py - 6, 10, 9, EL_CARDBOARD_DARK)
    rect(d, px + 3, py - 6, 10, 2, EL_CARDBOARD)
    rect(d, px + 5, py - 3, 6, 2, EL_BLACK)  # the picture of a television
    rect(d, px + 1, py + 13, 14, 1, EL_BLACK)
    if rng.random() < 0.5:
        rect(d, px + 11, py + 5, 3, 3, (60, 90, 170))


def paint_litter(d, rng, px, py):
    """Smashed boxes, polystyrene and cables all over the floor."""
    for _ in range(3):
        rect(d, px + rng.randrange(1, 11), py + rng.randrange(1, 11),
             rng.randint(3, 5), rng.randint(2, 3), EL_CARDBOARD)
    for _ in range(3):
        rect(d, px + rng.randrange(1, 13), py + rng.randrange(1, 13), 2, 2,
             (240, 240, 236))
    x, y = px + rng.randrange(2, 8), py + rng.randrange(3, 12)
    rect(d, x, y, 6, 1, EL_BLACK)
    rect(d, x + 5, y + 1, 1, 2, EL_BLACK)


# --------------------------------------------------------------- rules


def electronics_shop(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.electronicsShop."""
    rules = [rule("ground", ".", [atlas.bucket(
        lambda: tile_of(lambda d: paint_floor(d, rng, 0, 0)))])]
    for right in (False, True):
        rules.append(rule(
            "ground", ".",
            [[], atlas.bucket(lambda r=right: tile_of(
                lambda d: company.paint_edge(d, 0, 0, r)), 1)],
            [neighbour_key(1 if right else -1, 0, "x")]))

    def one(paint):
        return [atlas.bucket(lambda: tile_of(lambda d: paint(d, 0, 0)), 1)]

    def randomly(paint):
        return [atlas.bucket(lambda: tile_of(lambda d: paint(d, rng, 0, 0)))]

    rules.append(rule(
        "structures", "W",
        [atlas.odds(lambda u=upper: tile_of(
            lambda d: paint_wall(d, rng, 0, 0, u)), 24)
         for upper in (False, True)],
        [neighbour_key(0, 1, "xWw")]))
    rules.append(rule(
        "structures", "I",
        [atlas.bucket(lambda b=below: tile_of(
            lambda d: company.paint_partition(d, 0, 0, b)), 1)
         for below in (False, True)],
        [neighbour_key(0, 1, EL_WALLS)]))
    rules.append(rule("structures", "w", one(company.paint_front_wall)))
    rules.append(rule("structures", "E", one(company.paint_gate)))
    rules.append(rule("structures", "d", one(company.paint_doorway)))
    rules.append(rule("structures", "D", one(paint_back_door)))
    rules.append(rule("structures", ":", randomly(paint_litter)))
    rules.append(rule("structures", "b", randomly(palazzo.paint_blood)))
    buckets, pieces = spread(atlas, lambda i: lambda d, px, py:
                             props.paint_corpse(company.image_of(d), rng,
                                                px, py),
                             None, (1, 0, 1, 1), 12)
    rules.append(rule("structures", "c", buckets, None, pieces))

    keys = [neighbour_key(-1, 0, "R"), neighbour_key(1, 0, "R")]
    buckets, up = leaning(atlas, lambda i: lambda d, px, py:
                          company.paint_counter(d, rng, px, py, not i & 1,
                                                not i & 2), keys)
    rules.append(rule("structures", "R", buckets, keys, up))
    for glyph, paint in (("V", paint_television), ("F", paint_appliance),
                         ("T", paint_display), ("S", paint_shelving),
                         ("k", paint_boxes)):
        buckets, up = leaning(atlas, lambda i, p=paint: lambda d, px, py: p(
            d, rng, px, py))
        rules.append(rule("structures", glyph, buckets, pieces=up))
    return {"void": "#000000", "voidGlyph": "x", "rules": rules,
            "objects": [], "ground": GROUND}


# The floor under the furniture, the dead and the doors: the shop has the
# one.
GROUND = ground_config(
    buildings=EL_WALLS,
    roads="",
    walks="",
    floors=".",
    footway="",
    keep="",
    lawn="",
    lawnProps="",
)


PLACES = {
    "electronicsShop": electronics_shop,
}

PREVIEW_ROWS = {
    "electronicsShop": "electronics-shop-rows",
}
