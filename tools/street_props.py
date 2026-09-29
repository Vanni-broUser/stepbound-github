"""What stands in the city's streets: cars, bins, signs, benches, trees,
rubbish, the fountain, the playground, the bodies and the debris.
tools/tile_atlas_city.py cuts them into tiles or anchors them to a glyph.
"""
from __future__ import annotations

import math
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from street_paint import (  # noqa: E402
    BLOOD,
    BLOOD_DARK,
    CLOTHES,
    DEBRIS,
    SCORCH,
    SKIN,
    TILE,
    rect,
)

# ------------------------------------------------------------------ props


def paint_ambulance(d, px, py):
    """Ambulance crashed and abandoned, side-on over two tiles."""
    x, y = px - 1, py + 15
    rect(d, x + 2, y - 1, 32, 2, (24, 24, 28))
    rect(d, x + 2, y - 15, 30, 13, (230, 230, 224))
    rect(d, x + 24, y - 12, 7, 5, (40, 60, 70))  # windscreen
    rect(d, x + 2, y - 8, 30, 2, (200, 36, 32))  # stripe
    rect(d, x + 9, y - 14, 2, 6, (200, 36, 32))  # cross
    rect(d, x + 7, y - 12, 6, 2, (200, 36, 32))
    rect(d, x + 16, y - 17, 5, 2, (40, 80, 200))  # beacon
    rect(d, x + 2, y - 3, 30, 1, (150, 150, 146))
    for wx in (x + 5, x + 23):
        rect(d, wx, y - 3, 6, 4, (18, 18, 20))
        rect(d, wx + 2, y - 2, 2, 2, (70, 70, 74))
    rect(d, x + 3, y - 14, 5, 8, (20, 20, 24))  # back doors hanging open
    rect(d, x + 14, y - 6, 6, 3, BLOOD)


def paint_cafe_table(d, px, py):
    """Round café table, dirty, with a knocked-over glass."""
    rect(d, px + 3, py + 14, 11, 2, (30, 30, 34))
    rect(d, px + 7, py + 8, 2, 7, (60, 60, 64))
    rect(d, px + 2, py + 5, 12, 4, (190, 186, 176))
    rect(d, px + 3, py + 4, 10, 1, (216, 212, 200))
    rect(d, px + 4, py + 6, 3, 1, (100, 70, 40))  # spilled drink
    rect(d, px + 10, py + 5, 2, 1, (180, 200, 210))


def paint_chair(d, px, py, toppled):
    """Plastic café chair, most of them knocked over."""
    colour, dark = (226, 222, 210), (160, 156, 146)
    rect(d, px + 3, py + 14, 10, 1, (30, 30, 34))
    if toppled:
        rect(d, px + 2, py + 9, 12, 3, colour)
        rect(d, px + 2, py + 12, 2, 2, dark)
        rect(d, px + 11, py + 5, 2, 5, dark)
        rect(d, px + 7, py + 6, 2, 3, dark)
        return
    rect(d, px + 4, py + 3, 8, 5, colour)
    rect(d, px + 4, py + 8, 8, 2, dark)
    rect(d, px + 4, py + 10, 1, 4, dark)
    rect(d, px + 11, py + 10, 1, 4, dark)


def paint_fountain(image, rng, px, py, size):
    """Round fountain filling a size x size block: stone rim, murky water
    stained with blood, a headless statue on its pedestal."""
    d = ImageDraw.Draw(image)
    r = size * TILE // 2 - 1
    cx, cy = px + size * TILE // 2, py + size * TILE // 2
    d.ellipse([cx - r, cy - r + 4, cx + r, cy + r], fill=(40, 38, 40))  # shadow
    d.ellipse([cx - r, cy - r, cx + r, cy + r - 3], fill=(168, 160, 146))
    d.ellipse([cx - r + 4, cy - r + 3, cx + r - 4, cy + r - 6], fill=(126, 118, 108))
    d.ellipse([cx - r + 7, cy - r + 6, cx + r - 7, cy + r - 9], fill=(42, 62, 58))
    d.ellipse([cx - r + 14, cy - r + 12, cx - 2, cy + 2], fill=(52, 76, 70))
    d.ellipse([cx + 6, cy + 3, cx + r - 12, cy + r - 16], fill=(90, 20, 20))  # blood
    rect(d, cx + 10, cy + 6, 7, 3, (120, 26, 24))
    for i in range(0, 360, 30):  # rim blocks
        bx = cx + int((r - 2) * math.cos(math.radians(i)))
        by = cy - 1 + int((r - 3) * math.sin(math.radians(i)))
        rect(d, bx, by, 1, 2, (120, 114, 104))
    rect(d, cx - r + 1, cy - 4, 5, 4, (70, 66, 60))  # chipped rim
    rect(d, cx + r - 8, cy - r + 8, 4, 5, (70, 66, 60))
    # basin in the middle, pedestal and a statue with its head knocked off
    d.ellipse([cx - 12, cy - 6, cx + 12, cy + 8], fill=(150, 144, 132))
    d.ellipse([cx - 9, cy - 4, cx + 9, cy + 5], fill=(42, 62, 58))
    rect(d, cx - 4, cy - 10, 9, 12, (150, 144, 132))
    rect(d, cx - 4, cy, 9, 2, (100, 96, 88))
    rect(d, cx - 3, cy - 26, 7, 16, (180, 174, 160))
    rect(d, cx - 5, cy - 23, 2, 8, (160, 154, 140))  # arms
    rect(d, cx + 4, cy - 25, 2, 5, (160, 154, 140))
    rect(d, cx - 2, cy - 27, 5, 1, (120, 114, 104))  # broken neck
    rect(d, cx - 1, cy - 20, 3, 6, (140, 134, 122))
    rect(d, cx + 16, cy - 12, 5, 4, (180, 174, 160))  # the head, in the water
    rect(d, cx + 17, cy - 11, 1, 1, (60, 56, 52))
    rect(d, cx - 3, cy - 22, 2, 3, BLOOD)  # handprint on the statue
    for _ in range(10):  # floating rubbish
        rect(d, cx + rng.randrange(-r + 10, r - 12), cy + rng.randrange(-r + 10, r - 14),
             2, 1, rng.choice(DEBRIS))


def paint_tree(d, rng, px, py):
    """Dead tree in a square stone planter, bare branches over the tile."""
    rect(d, px + 1, py + 13, 15, 2, (30, 30, 34))
    rect(d, px + 1, py + 5, 14, 9, (140, 134, 122))
    rect(d, px + 2, py + 6, 12, 6, (60, 46, 36))  # soil
    rect(d, px + 1, py + 12, 14, 2, (110, 104, 94))
    trunk = (70, 54, 42)
    rect(d, px + 7, py - 8, 2, 16, trunk)
    for bx, by, length, step in ((3, -6, 5, -1), (9, -10, 5, 1), (5, -14, 4, -1),
                                 (8, -16, 3, 1), (10, -4, 4, 1)):
        for i in range(length):
            rect(d, px + bx + i * step if step > 0 else px + bx + 4 - i,
                 py + by - i // 2, 1, 1, trunk)
    for _ in range(4):  # the last dry leaves
        rect(d, px + rng.randrange(2, 14), py - rng.randrange(4, 17), 1, 1, (120, 90, 50))


def paint_bench(d, px, py):
    """Park bench over two tiles, one slat snapped."""
    rect(d, px + 1, py + 14, 30, 2, (30, 30, 34))
    for lx in (px + 3, px + 27):
        rect(d, lx, py + 9, 2, 6, (50, 50, 54))
    wood, dark = (130, 96, 60), (92, 66, 42)
    rect(d, px + 1, py + 3, 30, 2, wood)  # backrest
    rect(d, px + 1, py + 6, 30, 2, dark)
    rect(d, px + 1, py + 9, 30, 2, wood)  # seat
    rect(d, px + 1, py + 11, 30, 1, dark)
    rect(d, px + 16, py + 9, 4, 3, (30, 30, 34))  # snapped slat
    rect(d, px + 2, py + 2, 1, 10, (50, 50, 54))
    rect(d, px + 29, py + 2, 1, 10, (50, 50, 54))


def paint_rubbish(d, rng, px, py, deep=True):
    """The rubbish heaped in the corner of the car park: split sacks, boxes
    gone soft, a bin on its side. `deep` piles them shoulder high, too deep
    to climb; the rest is the same rubbish trodden flat around the heaps,
    which you can walk over."""
    sacks = [(28, 28, 32), (40, 38, 42), (20, 22, 26), (34, 32, 30)]
    if deep:
        rect(d, px, py + 12, TILE, 4, (26, 26, 28))  # the shadow it sits in
        for _ in range(4):
            sw, sh = rng.randint(7, 10), rng.randint(6, 8)
            sx = px + rng.randrange(0, TILE - sw + 1)
            sy = py + rng.randrange(0, TILE - sh)
            rect(d, sx, sy, sw, sh, rng.choice(sacks))
            rect(d, sx + 1, sy, sw - 2, 1, (72, 70, 76))  # the light on top
            rect(d, sx + 1, sy + sh - 1, sw - 2, 1, (14, 14, 16))
            if rng.random() < 0.3:  # a split, and what is coming out of it
                rect(d, sx + 2, sy + 2, 3, 2, rng.choice(DEBRIS))
        if rng.random() < 0.5:  # a cardboard box slumped on top
            bx, by = px + rng.randrange(1, 7), py + rng.randrange(0, 7)
            rect(d, bx, by, 9, 7, (118, 88, 58))
            rect(d, bx, by, 9, 1, (146, 112, 74))
            rect(d, bx + 1, by + 3, 7, 1, (84, 62, 40))
    else:
        for _ in range(3):  # flattened sacks, low enough to step over
            sw = rng.randint(5, 9)
            sx = px + rng.randrange(0, TILE - sw + 1)
            sy = py + rng.randrange(1, TILE - 4)
            rect(d, sx, sy, sw, 3, rng.choice(sacks))
            rect(d, sx + 1, sy, sw - 2, 1, (62, 60, 66))
    for _ in range(6):  # what has spilled out of them
        rect(d, px + rng.randrange(14), py + rng.randrange(15), 2, 1,
             rng.choice(DEBRIS))


def paint_playground(d, px, py, kind):
    """Broken playground rides, rusted and left to the weeds: a swing with
    one chain snapped, a slide on its side, a merry-go-round off its pivot."""
    rust, rust_dark = (150, 80, 50), (96, 50, 34)
    paint_red, paint_blue = (170, 50, 44), (60, 90, 140)
    rect(d, px + 1, py + 14, 14, 2, (30, 34, 26))
    if kind == 0:  # swing frame, one seat hanging from a single chain
        rect(d, px + 1, py - 8, 2, 22, rust)
        rect(d, px + 13, py - 8, 2, 22, rust)
        rect(d, px + 1, py - 9, 14, 2, rust_dark)
        rect(d, px + 5, py - 7, 1, 12, (120, 120, 126))
        rect(d, px + 4, py + 5, 5, 2, paint_red)
        rect(d, px + 10, py - 7, 1, 5, (120, 120, 126))  # snapped chain
        rect(d, px + 9, py + 11, 5, 2, paint_red)  # its seat, on the ground
    elif kind == 1:  # slide knocked over
        rect(d, px + 1, py + 8, 14, 4, paint_blue)
        rect(d, px + 1, py + 7, 14, 1, (110, 140, 180))
        rect(d, px + 11, py + 2, 2, 11, rust)
        rect(d, px + 13, py + 3, 2, 10, rust_dark)
        for sy in range(py + 3, py + 12, 3):
            rect(d, px + 11, sy, 4, 1, rust_dark)
    else:  # merry-go-round tipped off its pivot
        rect(d, px + 1, py + 7, 14, 6, rust_dark)
        rect(d, px + 2, py + 6, 12, 5, paint_red)
        rect(d, px + 7, py + 3, 2, 5, rust)
        rect(d, px + 3, py + 4, 10, 1, rust)
        rect(d, px + 4, py + 8, 3, 2, (230, 200, 70))
        rect(d, px + 9, py + 8, 3, 2, (230, 200, 70))


def paint_trolley(d, px, py, tipped=False):
    """Abandoned shopping trolley."""
    wire, dark = (170, 172, 176), (96, 98, 104)
    rect(d, px + 2, py + 14, 12, 1, (24, 24, 28))
    if tipped:
        rect(d, px + 2, py + 6, 11, 8, dark)
        for i in range(3, 13, 3):
            rect(d, px + i, py + 6, 1, 8, wire)
        rect(d, px + 2, py + 6, 11, 1, wire)
        rect(d, px + 13, py + 4, 2, 2, (40, 40, 44))
        rect(d, px + 13, py + 11, 2, 2, (40, 40, 44))
        return
    rect(d, px + 3, py + 4, 10, 7, dark)
    for i in range(4, 13, 3):
        rect(d, px + i, py + 4, 1, 7, wire)
    rect(d, px + 3, py + 4, 10, 1, wire)
    rect(d, px + 3, py + 11, 10, 1, wire)
    rect(d, px + 12, py + 2, 3, 1, (200, 40, 40))  # handle
    rect(d, px + 4, py + 13, 2, 2, (30, 30, 34))
    rect(d, px + 11, py + 13, 2, 2, (30, 30, 34))


def paint_road_block(d, px, py):
    """Concrete barrier blocking the road, striped red and white."""
    rect(d, px, py + 14, 16, 2, (24, 24, 28))
    rect(d, px, py + 5, 16, 10, (150, 148, 140))
    rect(d, px, py + 5, 16, 2, (184, 182, 172))
    rect(d, px + 1, py + 12, 14, 2, (110, 108, 102))
    for i in range(0, 16, 6):
        rect(d, px + i, py + 8, 3, 3, (190, 40, 36))
    rect(d, px + 5, py + 6, 1, 4, (90, 88, 84))  # crack


def paint_car(d, px, py, body, burnt=False, flipped=False):
    """Side-on car filling two tiles, wheels on the tile bottom."""
    x, y = px - 1, py + 15
    rect(d, x + 2, y - 1, 32, 2, (24, 24, 28))  # ground shadow
    dark = tuple(max(0, v - 40) for v in body)
    if flipped:
        rect(d, x, y - 10, 34, 8, dark)
        rect(d, x + 6, y - 4, 22, 4, (30, 30, 34))
        for wx in (x + 4, x + 24):
            rect(d, wx, y - 14, 6, 4, (20, 20, 22))
            rect(d, wx + 2, y - 13, 2, 2, (70, 70, 74))
        rect(d, x + 2, y - 11, 30, 1, (26, 26, 30))
        return
    glass = (20, 20, 20) if burnt else (40, 60, 70)
    rect(d, x + 2, y - 8, 30, 6, body)
    rect(d, x + 8, y - 14, 18, 6, body)
    rect(d, x + 10, y - 13, 6, 4, glass)
    rect(d, x + 18, y - 13, 6, 4, glass)
    rect(d, x + 2, y - 3, 30, 1, dark)
    for wx in (x + 5, x + 23):
        rect(d, wx, y - 3, 6, 4, (18, 18, 20))
        rect(d, wx + 2, y - 2, 2, 2, (70, 70, 74))
    if burnt:
        for i in range(0, 30, 3):
            rect(d, x + 2 + i, y - 8 + (i % 2), 2, 2, (26, 24, 24))
        rect(d, x + 8, y - 14, 18, 2, (30, 26, 26))


def paint_car_vertical(d, px, py, body, burnt=False):
    """Car parked north-south over two stacked tiles starting at (px, py)."""
    dark = tuple(max(0, v - 40) for v in body)
    glass = (20, 20, 20) if burnt else (40, 60, 70)
    bottom = py + 30
    rect(d, px + 2, bottom, 13, 2, (24, 24, 28))
    rect(d, px + 1, bottom - 26, 14, 26, body)
    rect(d, px + 3, bottom - 22, 10, 5, glass)
    rect(d, px + 3, bottom - 15, 10, 7, dark)
    rect(d, px + 3, bottom - 7, 10, 2, glass)
    for wy in (bottom - 24, bottom - 7):
        rect(d, px, wy, 2, 5, (18, 18, 20))
        rect(d, px + 14, wy, 2, 5, (18, 18, 20))
    if burnt:
        for i in range(0, 24, 3):
            rect(d, px + 2 + (i * 5 % 10), bottom - 25 + i, 3, 2, (26, 24, 24))


def paint_campfire(d, px, py):
    """A camp's fire pit: ring of stones, crossed logs, ash. The flame is
    animated in game."""
    rect(d, px + 1, py + 13, 14, 2, (24, 24, 28))  # shadow
    for sx, sy in ((2, 9), (5, 7), (9, 7), (12, 9), (13, 12), (2, 12), (5, 14), (10, 14)):
        rect(d, px + sx, py + sy, 3, 2, (120, 116, 108))
        rect(d, px + sx, py + sy, 3, 1, (156, 152, 142))
    rect(d, px + 4, py + 10, 8, 4, (40, 36, 34))  # ash bed
    rect(d, px + 3, py + 11, 10, 2, (110, 72, 40))  # logs
    rect(d, px + 6, py + 9, 2, 5, (92, 60, 34))
    rect(d, px + 9, py + 9, 2, 5, (130, 86, 48))
    rect(d, px + 6, py + 12, 4, 1, (230, 120, 40))  # embers
    rect(d, px + 8, py + 13, 1, 1, (255, 200, 90))


def paint_bin(d, px, py):
    rect(d, px + 3, py + 15, 11, 1, (24, 24, 28))
    rect(d, px + 3, py + 6, 10, 10, (58, 64, 58))
    rect(d, px + 3, py + 6, 10, 2, (86, 92, 84))
    rect(d, px + 5, py + 9, 1, 6, (44, 48, 44))
    rect(d, px + 9, py + 9, 1, 6, (44, 48, 44))
    rect(d, px + 4, py + 5, 8, 2, SCORCH)


def paint_sign(d, px, py, kind):
    """A road sign on its post, `/`: give way at the mouth of a side
    street, no entry where a street is closed, or the blue plate that
    points the way. Like the traffic lights it stands into the tile above,
    so it reads at eye level rather than flat on the pavement."""
    white, red, blue = (236, 234, 228), (186, 40, 36), (36, 62, 118)
    rect(d, px + 7, py + 14, 4, 2, (24, 24, 28))  # its shadow
    rect(d, px + 8, py - 2, 2, 17, (146, 144, 138))  # the post
    rect(d, px + 8, py - 2, 1, 17, (184, 182, 176))
    if kind == 0:  # give way: a triangle on its point
        for i in range(7):
            rect(d, px + 2 + i, py - 10 + i, 14 - i * 2, 1, red)
            if 1 <= i < 5:
                rect(d, px + 4 + i, py - 9 + i, 10 - i * 2, 1, white)
    elif kind == 1:  # no entry
        d.ellipse([px + 2, py - 11, px + 14, py + 1], fill=red)
        d.ellipse([px + 4, py - 9, px + 12, py - 1], fill=red)
        rect(d, px + 4, py - 6, 9, 3, white)
    else:  # the way to the station
        rect(d, px, py - 10, 16, 10, blue)
        rect(d, px, py - 10, 16, 1, (76, 106, 166))
        rect(d, px, py - 1, 16, 1, (22, 38, 74))
        rect(d, px + 3, py - 6, 8, 2, white)  # the arrow, pointing on
        for i in range(3):
            rect(d, px + 9 + i, py - 7 - i, 1, 3 + i * 2, white)
        rect(d, px + 2, py - 9, 5, 1, (150, 170, 210))
        rect(d, px + 2, py - 3, 7, 1, (150, 170, 210))


def paint_traffic_light(d, px, py):
    rect(d, px + 6, py + 14, 5, 2, (24, 24, 28))
    rect(d, px + 7, py - 6, 2, 21, (50, 52, 56))
    rect(d, px + 5, py - 12, 6, 9, (30, 30, 34))
    rect(d, px + 7, py - 11, 2, 2, (200, 40, 30))
    rect(d, px + 7, py - 8, 2, 2, (70, 64, 30))
    rect(d, px + 7, py - 5, 2, 1, (30, 70, 40))


_BODY_SOURCE = os.path.join(
    "assets", "characters", "zombies", "sprites", "wanderer.png"
)
_bodies: list[Image.Image] = []


def body_sprite(rng) -> Image.Image:
    """A civilian lying on the ground: a character frame seen from above,
    turned on its side, with human skin and random clothes."""
    if not _bodies:
        sheet = Image.open(_BODY_SOURCE).convert("RGBA")
        _bodies.extend(sheet.crop((c * 16, 0, c * 16 + 16, 24)) for c in (0, 1))
    frame = rng.choice(_bodies).copy()
    skin = rng.choice(SKIN)
    clothes = rng.choice(CLOTHES)
    for y in range(frame.height):
        for x in range(frame.width):
            r, g, b, a = frame.getpixel((x, y))
            if a < 100:
                continue
            if g > r + 10 and g > b:  # zombie green -> human skin
                shade = g / 200
                frame.putpixel((x, y), tuple(int(c * min(1.2, shade + 0.35)) for c in skin) + (a,))
            elif y >= 11 and max(r, g, b) > 24:  # clothes
                lum = (r + g + b) / 3 / 70
                frame.putpixel((x, y), tuple(min(255, int(c * lum)) for c in clothes) + (a,))
    turned = frame.rotate(90 if rng.random() < 0.5 else -90, expand=True)
    return turned


def paint_body(image, rng, x, y):
    """Lying body centred on (x, y) with a pool of blood under it."""
    body = body_sprite(rng)
    d = ImageDraw.Draw(image)
    rect(d, x - 9, y - 3, 18, 7, BLOOD_DARK)
    rect(d, x - 6, y - 4, 12, 9, BLOOD)
    image.paste(body, (x - body.width // 2, y - body.height // 2), body)


def paint_corpse(image, rng, px, py):
    paint_body(image, rng, px + 8, py + 9)


def paint_corpse_pile(image, rng, px, py):
    """Two bodies, one lying across the other."""
    d = ImageDraw.Draw(image)
    rect(d, px - 6, py + 4, 28, 11, BLOOD_DARK)
    paint_body(image, rng, px + 6, py + 11)
    paint_body(image, rng, px + 11, py + 6)


def paint_debris(d, rng, px, py):
    for _ in range(7):
        rect(d, px + rng.randrange(1, 14), py + rng.randrange(2, 14),
             rng.randint(1, 3), rng.randint(1, 2), rng.choice(DEBRIS))
    rect(d, px + 5, py + 9, 1, 1, (180, 200, 210))  # glass glint
    rect(d, px + 10, py + 4, 1, 1, (180, 200, 210))
