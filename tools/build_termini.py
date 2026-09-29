#!/usr/bin/env python3
"""The painters of Roma Termini past its first platform: the overpass over
the tracks, the far platform, the concourse and the station's front on
Piazza dei Cinquecento. The tile atlas (build_tile_atlas.py and
tile_atlas_city.py) cuts them into tiles and objects; the places' layout
is only in their ASCII rows (lib/core/levels/rome/).

Termini is a modern station, not a provincial one like Molfetta's: stone
floors, steel and glass, the red self-service ticket machines, the black
timetables with their orange lettering -- all of it smashed, looted and
left to rot."""
from __future__ import annotations

import math

from PIL import Image, ImageDraw

from build_street_level import OUTLINE, TILE, paint_text, rect, shade, \
    text_width
import build_station as station

TRANSPARENT = (0, 0, 0, 0)

# The overpass: grey granite underfoot, steel cladding on the walls.
GRANITE = (148, 148, 144)
GRANITE_ALT = (138, 138, 135)
GRANITE_JOINT = (108, 108, 106)
CLADDING = (116, 126, 134)
CLADDING_DARK = (84, 92, 100)
CLADDING_LIGHT = (150, 160, 168)
COPING = (38, 40, 46)
COPING_LIGHT = (70, 74, 82)
GLASS_DARK = (26, 34, 44)
GLASS_SKY = (70, 92, 112)

# The concourse: polished travertine.
TRAVERTINE = (198, 188, 166)
TRAVERTINE_ALT = (188, 178, 156)
TRAVERTINE_JOINT = (152, 142, 124)
TRAVERTINE_DARK = (160, 150, 130)

# The railway's red, and the black of its timetables.
RAIL_RED = (186, 34, 42)
RAIL_RED_DARK = (128, 22, 30)
RAIL_RED_LIGHT = (220, 70, 72)
BOARD = (18, 18, 22)
BOARD_FRAME = (58, 60, 66)
LED = (236, 150, 40)
LED_DIM = (120, 74, 26)
SIGN_BLUE = (22, 68, 142)
SIGN_WHITE = (238, 241, 236)
SITE_RED = (206, 40, 36)
SITE_WHITE = (236, 232, 222)

# Rubbish.
BAGS = [(24, 24, 26), (36, 38, 40), (44, 70, 44), (40, 58, 96),
        (70, 72, 74), (108, 96, 70)]


def speckle(d, rng, px, py, w, h, colours, count):
    for _ in range(count):
        rect(d, px + rng.randrange(w), py + rng.randrange(h), 1, 1,
             rng.choice(colours))


# ------------------------------------------------------------ the overpass


def paint_granite_floor(d, rng, x, y):
    """The overpass floor, `.`: big granite slabs, a joint round each,
    grit trodden into them and the odd crack."""
    px, py = x * TILE, y * TILE
    base = GRANITE if (x + y) % 2 == 0 else GRANITE_ALT
    rect(d, px, py, TILE, TILE, base)
    rect(d, px, py, TILE, 1, GRANITE_JOINT)
    rect(d, px, py, 1, TILE, GRANITE_JOINT)
    speckle(d, rng, px + 1, py + 1, TILE - 1, TILE - 1,
            (shade(base, 16), shade(base, -18), shade(base, -30)), 14)
    if rng.random() < 0.25:
        cx, cy = px + rng.randrange(3, 12), py + rng.randrange(3, 12)
        for i in range(rng.randint(3, 6)):
            rect(d, cx + i, cy + (i * 3) % 4 - 1, 1, 1, GRANITE_JOINT)
    if rng.random() < 0.3:
        rect(d, px + rng.randrange(8), py + rng.randrange(8),
             rng.randint(4, 8), rng.randint(3, 6), shade(base, -14))


def paint_overpass_wall(d, rng, px, py, top):
    """The back wall of the overpass, `W`: steel cladding in tall panels
    over a dark plinth, its top a band of tinted glass under the dark
    coping, the panels dented, streaked and tagged."""
    rect(d, px, py, TILE, TILE, CLADDING)
    if top:
        rect(d, px, py, TILE, 3, COPING)
        rect(d, px, py + 3, TILE, 1, COPING_LIGHT)
        rect(d, px, py + 4, TILE, 8, GLASS_DARK)
        rect(d, px, py + 5, TILE, 2, GLASS_SKY)
        rect(d, px + 7, py + 4, 2, 8, COPING)
        rect(d, px, py + 12, TILE, 1, CLADDING_LIGHT)
        if rng.random() < 0.3:
            rect(d, px + rng.randrange(2, 12), py + 5, 3, 6, (10, 12, 16))
        return
    rect(d, px, py, 1, TILE, CLADDING_DARK)
    rect(d, px + 8, py, 1, TILE - 4, CLADDING_DARK)
    rect(d, px + 1, py, 1, TILE - 4, CLADDING_LIGHT)
    rect(d, px, py + TILE - 4, TILE, 4, COPING)
    rect(d, px, py + TILE - 4, TILE, 1, COPING_LIGHT)
    for _ in range(3):
        rect(d, px + rng.randrange(TILE), py + rng.randrange(TILE - 6),
             1, rng.randint(2, 6), shade(CLADDING, -24))
    if rng.random() < 0.2:
        colour = rng.choice(((200, 60, 150), (60, 170, 190), (230, 200, 60)))
        for i in range(0, 12, 2):
            rect(d, px + 2 + i, py + 5 + (i % 4) // 2, 2, 1, colour)


def paint_overpass_front(d, px, py):
    """The front wall, `w`, seen from inside: the dark coping over a glass
    balustrade onto the drop to the tracks."""
    rect(d, px, py, TILE, TILE, COPING)
    rect(d, px, py + 2, TILE, 1, COPING_LIGHT)
    rect(d, px, py + 4, TILE, 9, GLASS_DARK)
    rect(d, px, py + 5, TILE, 1, GLASS_SKY)
    rect(d, px + 7, py + 4, 2, 9, COPING_LIGHT)
    rect(d, px, py + 13, TILE, 1, CLADDING_DARK)


def paint_opening(d, px, py):
    """The overpass's wide opening onto the concourse, `E`: the floor goes
    on, the light of the hall beyond it on the stone."""
    rect(d, px, py, TILE, TILE, (196, 190, 172))
    rect(d, px, py, TILE, 2, (120, 118, 110))
    rect(d, px, py + 2, TILE, 3, (222, 216, 198))


def paint_barred_flight(d, px, py, first, last):
    """A flight down to a platform, shut, `H`: the dark well of the stairs
    behind a red-and-white site barrier, a CHIUSO board wired to it."""
    rect(d, px, py, TILE, TILE, (20, 20, 22))
    for i, sy in enumerate(range(py + 3, py + TILE, 3)):
        rect(d, px, sy, TILE, 2, shade((92, 92, 90), -i * 14))
    for side, there in ((0, first), (TILE - 2, last)):
        if there:
            rect(d, px + side, py, 2, TILE, station.METAL_DARK)
    by = py + 8
    rect(d, px, by, TILE, 4, SITE_WHITE)
    for sx in range(px - 2 if first else px, px + TILE, 6):
        rect(d, max(sx, px), by, min(3, px + TILE - sx), 4, SITE_RED)
    rect(d, px, by + 4, TILE, 1, (40, 36, 34))
    if first:
        rect(d, px + 2, by + 5, 2, 6, (60, 60, 64))
    if last:
        rect(d, px + 12, by + 5, 2, 6, (60, 60, 64))
        rect(d, px + 1, by - 6, 11, 6, SITE_WHITE)
        rect(d, px + 2, by - 5, 9, 1, SITE_RED)
        rect(d, px + 2, by - 3, 9, 1, SITE_RED)


def paint_rubble_flight(d, rng, px, py):
    """A flight choked with the fallen roof, `#` in the back wall: the
    rubble heaped up the stairwell to its ceiling."""
    rect(d, px, py, TILE, TILE, (26, 24, 24))
    for _ in range(18):
        w, h = rng.randint(2, 6), rng.randint(2, 4)
        rect(d, px + rng.randrange(TILE - w + 1),
             py + rng.randrange(TILE - h + 1), w, h,
             rng.choice(station.RUBBLE))
    if rng.random() < 0.5:
        gx = px + rng.randrange(2, 10)
        rect(d, gx, py + 2, 2, 12, (90, 70, 56))
        rect(d, gx, py + 2, 1, 12, (120, 94, 72))


def timetable(width_tiles, height_tiles, title, rng, broken=0.45):
    """A timetable, `Q`: a black board in its frame, hung by two rods,
    with the title across the top and rows of orange lettering, most of it
    dead now, and whole panels smashed out of it."""
    w, h = width_tiles * TILE, height_tiles * TILE
    img = Image.new("RGBA", (w, h), TRANSPARENT)
    d = ImageDraw.Draw(img)
    rect(d, 6, 0, 2, 4, (70, 70, 76))
    rect(d, w - 8, 0, 2, 4, (70, 70, 76))
    top = 3
    rect(d, 0, top, w, h - top - 2, BOARD_FRAME)
    rect(d, 2, top + 2, w - 4, h - top - 6, BOARD)
    rect(d, 2, top + 2, w - 4, 7, (30, 44, 88))
    paint_text(d, 5, top + 3, title, SIGN_WHITE)
    for row, ry in enumerate(range(top + 11, h - 6, 4)):
        x = 4
        while x < w - 8:
            n = rng.randint(3, 9)
            lit = rng.random() > broken
            for i in range(n):
                if x + i * 2 >= w - 5:
                    break
                if rng.random() < 0.8:
                    rect(d, x + i * 2, ry, 1, 2, LED if lit else LED_DIM)
            x += n * 2 + rng.randint(3, 8)
    # Smashed panels: jagged holes onto the bare frame behind.
    for _ in range(max(1, width_tiles // 3)):
        hx, hy = rng.randrange(3, w - 12), rng.randrange(top + 8,
                                                          max(top + 9, h - 10))
        hw, hh = rng.randint(6, 14), rng.randint(4, 9)
        d.polygon([(hx, hy), (hx + hw, hy + 1), (hx + hw - 2, hy + hh),
                   (hx + hw // 2, hy + hh - 2), (hx + 1, hy + hh)],
                  fill=(8, 8, 10))
        for _ in range(3):
            rect(d, hx + rng.randrange(hw), hy + rng.randrange(hh), 2, 1,
                 (120, 124, 130))
    # A panel hanging off by its corner.
    fx = rng.randrange(4, w - 20)
    d.polygon([(fx, h - 6), (fx + 14, h - 5), (fx + 12, h - 1), (fx + 1, h)],
              fill=(28, 28, 32))
    return img


def platform_plate(number: int) -> Image.Image:
    """The blue plate over a flight, with its platform's number."""
    img = Image.new("RGBA", (2 * TILE, TILE), TRANSPARENT)
    d = ImageDraw.Draw(img)
    rect(d, 7, 9, 18, 7, (12, 38, 86))
    rect(d, 8, 10, 16, 5, SIGN_BLUE)
    text = str(number)
    paint_text(d, 16 - text_width(text) // 2, 10, text, SIGN_WHITE)
    rect(d, 11, 5, 1, 4, (70, 70, 76))
    rect(d, 20, 5, 1, 4, (70, 70, 76))
    return img


def paint_ticket_machine(d, rng, px, py):
    """A self-service ticket machine, `K`, against the wall: the railway's
    red cabinet, as tall as a man, so it stands up into the cell above; its
    screen smashed, its hatch forced and hanging, tickets and coins spilt
    at its foot."""
    top = py - 9
    rect(d, px + 2, py + 12, 13, 3, (30, 30, 34))
    rect(d, px + 2, top, 12, TILE + 9 - 3, RAIL_RED)
    rect(d, px + 2, top, 12, 3, RAIL_RED_LIGHT)
    rect(d, px + 13, top, 1, TILE + 6, RAIL_RED_DARK)
    rect(d, px + 3, top + 4, 10, 7, (14, 16, 20))
    for _ in range(4):
        cx, cy = px + 3 + rng.randrange(9), top + 4 + rng.randrange(6)
        rect(d, cx, cy, 1, 1, (150, 170, 190))
    rect(d, px + 4, top + 7, 6, 1, (110, 130, 150))
    rect(d, px + 3, top + 13, 10, 5, (220, 220, 214))
    rect(d, px + 4, top + 14, 3, 1, (60, 60, 64))
    if rng.random() < 0.6:
        rect(d, px + 4, top + 19, 8, 4, (20, 20, 22))
        rect(d, px + 11, top + 19, 4, 5, RAIL_RED_DARK)
    for _ in range(3):
        rect(d, px + rng.randrange(0, 14), py + 13 + rng.randrange(3), 2, 1,
             rng.choice(((230, 226, 210), (200, 170, 70))))


def paint_pillar(d, px, py):
    """A square pillar holding the roof, `I`: rendered concrete, its lit
    face west, stood up into the cell above."""
    top = py - TILE
    rect(d, px + 10, py + 11, 5, 5, (30, 30, 34))
    rect(d, px + 2, top, 12, 2 * TILE - 2, (176, 172, 162))
    rect(d, px + 2, top, 4, 2 * TILE - 2, (204, 200, 190))
    rect(d, px + 12, top, 2, 2 * TILE - 2, (138, 134, 126))
    rect(d, px + 2, top, 12, 2, (220, 216, 206))
    rect(d, px + 2, py + TILE - 4, 12, 2, (110, 106, 100))
    rect(d, px + 3, top + 8, 10, 2, (150, 146, 138))
    rect(d, px + 5, top + 9, 6, 1, (230, 120, 40))


# -------------------------------------------------------- the far platform


def paint_rubbish_edge(d, rng, px, py, side):
    """Where the rubbish spills out onto the ballast: bags and litter
    tumbled off the side of the heap that is open."""
    for _ in range(3):
        if side == "e":
            bx, by = px + TILE - rng.randint(3, 6), py + rng.randrange(12)
        elif side == "w":
            bx, by = px + rng.randint(0, 3), py + rng.randrange(12)
        elif side == "s":
            bx, by = px + rng.randrange(12), py + TILE - rng.randint(3, 6)
        else:
            bx, by = px + rng.randrange(12), py + rng.randint(0, 3)
        rect(d, bx, by, 4, 3, rng.choice(BAGS))


def paint_breach(d, rng, px, py, first):
    """The breach in the back wall, `J`: the wall knocked out down to the
    ground, the daylight of the street beyond, the broken bricks ragged
    along its sides and heaped across its foot."""
    rect(d, px, py, TILE, TILE, (196, 196, 188))
    rect(d, px, py, TILE, 7, (226, 226, 218))
    rect(d, px, py + 7, TILE, 1, (150, 150, 144))
    for _ in range(7):
        rect(d, px + rng.randrange(TILE - 3), py + 9 + rng.randrange(5),
             rng.randint(2, 4), 2, rng.choice(station.RUBBLE))
    side = px if first else px + TILE - 4
    for i in range(0, TILE - 2, 2):
        jag = rng.randint(1, 4)
        rect(d, side if first else side + 4 - jag, py + i, jag, 2,
             station.WALL_FACE)
        rect(d, (side + jag) if first else side + 3 - jag, py + i, 1, 2,
             (150, 80, 60))


def paint_breach_top(d, rng, px, py, first):
    """The wall over the breach: the hole torn up into it, ragged, the
    brick under the render showing round it."""
    rect(d, px, py, TILE, TILE, station.WALL_FACE)
    rect(d, px, py, TILE, 5, station.WALL_TOP)
    hole_top = py + 6 + rng.randint(0, 2)
    rect(d, px + (2 if first else 0), hole_top, TILE - 2, py + TILE - hole_top,
         (226, 226, 218))
    for i in range(0, TILE, 3):
        rect(d, px + i, hole_top - 2 + (i * 7) % 3, 3, 2, (150, 80, 60))
    if first:
        rect(d, px, hole_top, 2, py + TILE - hole_top, (150, 80, 60))
    else:
        rect(d, px + TILE - 2, hole_top, 2, py + TILE - hole_top,
             (150, 80, 60))


def rubbish_mountain(footprint, rng) -> Image.Image:
    """The mountain of rubbish, `;`: bin bags by the hundred, split and
    spilling, boxes, a mattress, a fridge, tyres, heaped higher towards
    the middle, where it is darker with the depth of it, and the light
    catching its top on the side it comes from. Painted over its own cells,
    `footprint` (x, y) relative to its corner, as one heap rather than tile
    after tile."""
    xs = [x for x, _ in footprint]
    ys = [y for _, y in footprint]
    w, h = (max(xs) + 1) * TILE, (max(ys) + 1) * TILE
    img = Image.new("RGBA", (w, h), TRANSPARENT)
    d = ImageDraw.Draw(img)
    cells = set(footprint)
    for x, y in cells:
        rect(d, x * TILE, y * TILE, TILE, TILE, (36, 34, 32))
    # Bags, bigger underneath, smaller on top, each with its highlight.
    for layer, (count, size) in enumerate(((260, (7, 11)), (220, (5, 8)),
                                           (160, (3, 6)))):
        for _ in range(count * len(cells) // 100):
            x, y = rng.choice(footprint)
            bx = x * TILE + rng.randrange(-3, TILE)
            by = y * TILE + rng.randrange(-3, TILE)
            bw, bh = rng.randint(*size), max(3, rng.randint(size[0] - 2,
                                                          size[1] - 2))
            c = shade(rng.choice(BAGS), layer * 10)
            d.ellipse([bx, by, bx + bw, by + bh], fill=c)
            d.arc([bx + 1, by + 1, bx + bw - 1, by + bh - 1], 200, 300,
                  fill=shade(c, 40))
    # The big things thrown on it.
    for _ in range(max(2, len(cells) // 12)):
        x, y = rng.choice(footprint)
        bx, by = x * TILE + rng.randrange(TILE // 2), y * TILE +             rng.randrange(TILE // 2)
        roll = rng.random()
        if roll < 0.3:  # a mattress
            rect(d, bx, by, 18, 10, (196, 184, 156))
            for i in range(2, 18, 4):
                rect(d, bx + i, by + 1, 1, 8, (160, 150, 124))
            rect(d, bx + 5, by + 4, 6, 3, (140, 110, 70))
        elif roll < 0.5:  # a fridge on its back
            rect(d, bx, by, 10, 14, (214, 214, 206))
            rect(d, bx, by + 5, 10, 1, (150, 150, 146))
            rect(d, bx + 8, by + 1, 1, 3, (120, 120, 120))
        elif roll < 0.75:  # a tyre
            d.ellipse([bx, by, bx + 9, by + 9], fill=(22, 22, 24))
            d.ellipse([bx + 3, by + 3, bx + 6, by + 6], fill=(58, 58, 60))
        else:  # a split box
            rect(d, bx, by, 11, 8, (150, 118, 76))
            rect(d, bx, by, 11, 2, (178, 146, 100))
            rect(d, bx + 5, by + 2, 1, 6, (110, 84, 52))
    # Litter over it all.
    for _ in range(len(cells) * 4):
        x, y = rng.choice(footprint)
        rect(d, x * TILE + rng.randrange(TILE), y * TILE + rng.randrange(TILE),
             rng.randint(1, 3), 1,
             rng.choice(((220, 220, 210), (200, 40, 40), (230, 200, 60),
                         (90, 150, 210))))
    # Only over its own cells, but for the odd bag tumbled off its edge.
    mask = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask)
    for x, y in cells:
        md.rectangle([x * TILE, y * TILE - 2, (x + 1) * TILE + 2,
                      (y + 1) * TILE + 1], fill=255)
    out = Image.new("RGBA", (w, h), TRANSPARENT)
    out.paste(img, (0, 0), mask)
    return out


def derailed_train(footprint, rng) -> Image.Image:
    """The train that came off the rails, `V`: seen from above, its first
    car slewed across the tracks at a slant, nose buried in the ballast,
    and the car behind jack-knifed against it, over on its side. Painted
    over the cells the rows mark, `footprint` (x, y) relative to its
    corner."""
    xs = [x for x, _ in footprint]
    ys = [y for _, y in footprint]
    w, h = (max(xs) + 1) * TILE, (max(ys) + 1) * TILE
    img = Image.new("RGBA", (w, h), TRANSPARENT)
    # Under it all, the track it tore up: ballast heaped, sleepers and
    # twisted rails thrown about, over every cell it lies across.
    d = ImageDraw.Draw(img)
    for x, y in footprint:
        station.paint_rubble_heap(d, rng, x, y)
        for _ in range(2):
            sx, sy = x * TILE + rng.randrange(TILE - 8), y * TILE +                 rng.randrange(TILE - 3)
            rect(d, sx, sy, 8, 2, station.SLEEPER_DARK)
        if rng.random() < 0.4:
            rx, ry = x * TILE + rng.randrange(4), y * TILE + rng.randrange(12)
            d.line([(rx, ry), (rx + 12, ry + rng.randint(-4, 4))],
                   fill=station.RAIL_RUST, width=2)
    # The first car, side on, turned to lie across the tracks.
    car = Image.new("RGBA", (15 * TILE, 3 * TILE), TRANSPARENT)
    station.paint_railcar(ImageDraw.Draw(car), rng,
                          (0, 0, car.width, car.height), wrecked=True)
    slewed = car.rotate(38, resample=Image.NEAREST, expand=True)
    img.alpha_composite(slewed, (-TILE * 3, h - slewed.height + TILE))
    # The car behind it, over on its belly-up side along the east edge.
    belly = Image.new("RGBA", (4 * TILE, h), TRANSPARENT)
    station.paint_overturned_train(ImageDraw.Draw(belly), rng,
                                   (0, 0, belly.width, belly.height),
                                   burnt=True)
    img.alpha_composite(belly, (w - belly.width, 0))
    # Only over its own cells: what spills past them is cut away, but for
    # a ragged pixel or two, so it does not end on the grid.
    mask = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask)
    cells = set(footprint)
    for x, y in cells:
        md.rectangle([x * TILE - 2, y * TILE, (x + 1) * TILE - 1,
                      (y + 1) * TILE - 1], fill=255)
    out = Image.new("RGBA", (w, h), TRANSPARENT)
    out.paste(img, (0, 0), mask)
    # Ballast torn up round it.
    d = ImageDraw.Draw(out)
    for x, y in cells:
        if (x - 1, y) not in cells:
            for _ in range(3):
                rect(d, x * TILE + rng.randrange(0, 4),
                     y * TILE + rng.randrange(TILE - 2), 2, 2,
                     rng.choice(station.BALLAST))
    return out


# ------------------------------------------------------------ the concourse


def paint_travertine_floor(d, rng, x, y):
    """The concourse floor: polished travertine slabs, two to a cell,
    shining where the light falls and dulled where the feet went."""
    px, py = x * TILE, y * TILE
    base = TRAVERTINE if (x + y) % 2 == 0 else TRAVERTINE_ALT
    rect(d, px, py, TILE, TILE, base)
    rect(d, px, py, TILE, 1, TRAVERTINE_JOINT)
    rect(d, px, py, 1, TILE, TRAVERTINE_JOINT)
    rect(d, px + 1, py + 8, TILE - 1, 1, shade(TRAVERTINE_JOINT, 14))
    for _ in range(3):
        vx, vy = px + rng.randrange(2, 14), py + rng.randrange(2, 14)
        rect(d, vx, vy, rng.randint(2, 4), 1, shade(base, -16))
    if rng.random() < 0.4:
        rect(d, px + 3, py + 2, 5, 1, shade(base, 20))
    speckle(d, rng, px + 1, py + 1, TILE - 1, TILE - 1,
            (shade(base, -26), (120, 110, 96)), 5)


def paint_concourse_wall(d, rng, px, py, top):
    """The concourse's back wall, `W`: great blocks of travertine, the
    joints dark with dirt, a band of darker stone along the foot."""
    rect(d, px, py, TILE, TILE, TRAVERTINE)
    if top:
        rect(d, px, py, TILE, 3, (70, 66, 60))
        rect(d, px, py + 3, TILE, 1, TRAVERTINE_DARK)
        rect(d, px, py + 9, TILE, 1, TRAVERTINE_JOINT)
    else:
        rect(d, px, py + 4, TILE, 1, TRAVERTINE_JOINT)
        rect(d, px, py + TILE - 4, TILE, 4, TRAVERTINE_DARK)
        rect(d, px, py + TILE - 4, TILE, 1, TRAVERTINE_JOINT)
    rect(d, px + (8 if top else 0), py + (4 if top else 5), 1,
         5 if top else 7, TRAVERTINE_JOINT)
    for _ in range(3):
        rect(d, px + rng.randrange(TILE), py + rng.randrange(4, TILE - 4),
             1, rng.randint(1, 4), shade(TRAVERTINE, -20))


def paint_glass_front(d, rng, px, py):
    """The glass front, `w`, seen from inside: steel mullions and the day
    beyond, half the panes gone or starred."""
    rect(d, px, py, TILE, TILE, COPING)
    rect(d, px, py + 2, TILE, 12, (170, 184, 190))
    rect(d, px, py + 2, TILE, 4, (200, 212, 216))
    rect(d, px + 7, py + 2, 2, 12, COPING_LIGHT)
    rect(d, px, py + 8, TILE, 1, COPING_LIGHT)
    if rng.random() < 0.4:
        cx = px + (1 if rng.random() < 0.5 else 9)
        rect(d, cx, py + 3, 6, 5, (40, 44, 50))
    rect(d, px, py + 14, TILE, 2, COPING)


def paint_glass_door(d, px, py, first):
    """A doorway in the glass front, `O`: its leaves forced back, the
    daylight of the piazza on the step."""
    rect(d, px, py, TILE, TILE, (214, 210, 196))
    rect(d, px, py, TILE, 2, COPING)
    rect(d, px, py + 2, TILE, 4, (236, 232, 218))
    edge = px if first else px + TILE - 2
    rect(d, edge, py, 2, TILE, COPING_LIGHT)
    rect(d, px + (2 if first else TILE - 5), py + 3, 3, TILE - 5,
         (150, 170, 176))


def shop_front(width_tiles, name, rng, kind) -> Image.Image:
    """A shop along the back wall, `S`, two cells high: its sign over the
    front, and the shutter down, or half up and forced, or gone and the
    glass behind it smashed."""
    w, h = width_tiles * TILE, 2 * TILE
    img = Image.new("RGBA", (w, h), TRANSPARENT)
    d = ImageDraw.Draw(img)
    rect(d, 0, 0, w, h, TRAVERTINE_DARK)
    sign_colour = {"bar": (40, 40, 44), "books": (30, 60, 110),
                   "news": (150, 40, 40), "chemist": (30, 110, 60)}[kind]
    rect(d, 2, 1, w - 4, 9, sign_colour)
    rect(d, 2, 1, w - 4, 1, shade(sign_colour, 40))
    paint_text(d, (w - text_width(name)) // 2, 3, name, SIGN_WHITE)
    if kind == "chemist":
        rect(d, 4, 3, 5, 1, (80, 220, 110))
        rect(d, 6, 1 + 1, 1, 5, (80, 220, 110))
    body_top = 12
    rect(d, 2, body_top, w - 4, h - body_top, (30, 30, 34))
    roll = rng.random()
    if roll < 0.4:
        for sy in range(body_top, h, 2):
            rect(d, 2, sy, w - 4, 1, (130, 132, 136))
            rect(d, 2, sy + 1, w - 4, 1, (104, 106, 110))
        for i in range(0, w - 8, 3):
            rect(d, 4 + i, body_top + 6 + (i * 7) % 5, 2, 1,
                 rng.choice(((200, 60, 150), (60, 170, 190), (230, 200, 60))))
    elif roll < 0.75:
        for sy in range(body_top, body_top + 8, 2):
            rect(d, 2, sy, w - 4, 1, (130, 132, 136))
            rect(d, 2, sy + 1, w - 4, 1, (104, 106, 110))
        d.polygon([(2, body_top + 8), (w // 2, body_top + 12),
                   (w - 3, body_top + 7), (w - 3, body_top + 8)],
                  fill=(104, 106, 110))
        for _ in range(6):
            rect(d, 4 + rng.randrange(w - 10), h - 6 + rng.randrange(4),
                 3, 2, rng.choice(((180, 160, 120), (220, 220, 210),
                                   (120, 40, 40))))
    else:
        rect(d, 3, body_top + 1, w - 6, h - body_top - 2, (20, 24, 30))
        for _ in range(10):
            rect(d, 3 + rng.randrange(w - 8), body_top + 1 + rng.randrange(
                h - body_top - 3), 2, 1, (150, 170, 180))
    return img


def departures_board(width_tiles, rng) -> Image.Image:
    """The great departures board over the middle of the concourse, `Q`:
    stood on its two steel legs, the slats of its lines half fallen, the
    rest frozen on trains that never left."""
    w, h = width_tiles * TILE, 2 * TILE
    img = Image.new("RGBA", (w, h), TRANSPARENT)
    d = ImageDraw.Draw(img)
    rect(d, 10, h - 10, w - 20, 8, (30, 30, 34))  # its shadow
    for lx in (12, w - 16):
        rect(d, lx, 18, 4, h - 18, (70, 72, 78))
        rect(d, lx, 18, 1, h - 18, (110, 112, 118))
    board = timetable(width_tiles, 2, "PARTENZE  DEPARTURES", rng, broken=0.6)
    img.alpha_composite(board.crop((0, 0, w, 24)), (0, 0))
    for _ in range(5):
        sx = rng.randrange(8, w - 16)
        rect(d, sx, 21 + rng.randrange(6), rng.randint(5, 10), 2,
             (24, 24, 28))
    return img


def kiosk(width_tiles, rng) -> Image.Image:
    """The information kiosk, `i`: a glass box with the white i on blue,
    its glass starred, papers strewn inside."""
    w, h = width_tiles * TILE, 2 * TILE
    img = Image.new("RGBA", (w, h), TRANSPARENT)
    d = ImageDraw.Draw(img)
    rect(d, 2, h - 6, w - 2, 6, (30, 30, 34))
    rect(d, 0, 0, w - 2, h - 3, (70, 74, 82))
    rect(d, 2, 2, w - 6, h - 7, (140, 160, 170))
    rect(d, 2, 2, w - 6, 3, (180, 196, 204))
    for i in range(1, width_tiles):
        rect(d, i * TILE - 1, 2, 2, h - 7, (70, 74, 82))
    rect(d, w // 2 - 20, 6, 40, 9, SIGN_BLUE)
    paint_text(d, w // 2 - text_width("INFO") // 2, 8, "INFO", SIGN_WHITE)
    for _ in range(12):
        rect(d, 3 + rng.randrange(w - 10), 16 + rng.randrange(h - 22), 3, 2,
             (226, 222, 206))
    for _ in range(2):
        cx, cy = rng.randrange(8, w - 8), rng.randrange(8, h - 10)
        for a in range(0, 360, 60):
            r = math.radians(a)
            rect(d, cx + int(4 * math.cos(r)), cy + int(4 * math.sin(r)),
                 1, 1, (230, 236, 240))
    return img


def paint_luggage_trolley(d, rng, px, py):
    """A luggage trolley, `y`, left where it was dropped, a case still on
    it now and then."""
    rect(d, px + 3, py + 13, 11, 2, (30, 30, 34))
    rect(d, px + 3, py + 6, 10, 7, (140, 144, 150))
    rect(d, px + 3, py + 6, 10, 1, (190, 194, 200))
    rect(d, px + 2, py + 2, 2, 11, (110, 114, 120))
    for wx in (4, 11):
        rect(d, px + wx, py + 13, 2, 2, (30, 30, 30))
    if rng.random() < 0.5:
        c = rng.choice(((110, 40, 40), (40, 60, 110), (70, 70, 72)))
        rect(d, px + 5, py + 3, 8, 7, c)
        rect(d, px + 5, py + 3, 8, 1, shade(c, 30))
        rect(d, px + 8, py + 2, 2, 1, (40, 40, 40))


# ---------------------------------------------------------- the facade


TERMINI_STONE = (214, 204, 180)
TERMINI_STONE_DARK = (170, 160, 138)
TERMINI_CANOPY = (196, 190, 176)
TERMINI_CANOPY_UNDER = (96, 94, 90)


def paint_termini_front(d, rng, level):
    """The front of Termini on Piazza dei Cinquecento, `]`, its doorways
    `{`. Behind, the long travertine body with its ribbon of windows
    running the whole length. In front of it, what everyone knows: the
    great cantilevered roof over the glass hall, ribbed like the back of an
    animal, its edge rising and falling in waves -- the "dinosaur" -- and
    under it the glass front in its shadow, the name over the middle
    doorway. The doorways stand open onto the dark of the concourse; half
    the glass between them is gone."""
    cells = [(x, y) for y in range(level.height) for x in range(level.width)
             if level.at(x, y) in "]{"]
    if not cells:
        return
    x0, x1 = min(x for x, _ in cells), max(x for x, _ in cells)
    y0, y1 = min(y for _, y in cells), max(y for _, y in cells)
    px, py = x0 * TILE, y0 * TILE
    w, h = (x1 - x0 + 1) * TILE, (y1 - y0 + 1) * TILE
    bottom = py + h
    # The travertine body behind, with its ribbon of windows.
    rect(d, px, py, w, 16, TERMINI_STONE)
    rect(d, px, py, w, 2, (236, 228, 208))
    rect(d, px, py + 5, w, 6, (40, 50, 62))
    rect(d, px, py + 5, w, 1, (96, 116, 132))
    for mx in range(px, px + w, 4):
        rect(d, mx, py + 5, 1, 6, TERMINI_STONE_DARK)
    for _ in range(w // 32):
        rect(d, px + rng.randrange(w - 6), py + 6, 3, 5, (12, 14, 18))
    rect(d, px, py + 14, w, 2, TERMINI_STONE_DARK)

    # The glass front, deep in the shadow of the roof.
    glass_top = py + 44
    rect(d, px, glass_top, w, bottom - glass_top, (70, 84, 94))
    rect(d, px, glass_top, w, 6, (40, 48, 56))
    for mx in range(px, px + w, 8):
        rect(d, mx, glass_top, 1, bottom - glass_top, (34, 38, 44))
    rect(d, px, bottom - 3, w, 3, (60, 62, 64))
    for _ in range(w // 20):
        gx = px + rng.randrange(w - 8)
        gy = glass_top + 8 + rng.randrange(max(1, bottom - glass_top - 14))
        rect(d, gx, gy, rng.randint(4, 7), rng.randint(3, 6), (16, 18, 22))

    # The cantilevered roof, seen from above: its back straight along the
    # body, its front edge in waves; ribs run down it to every crest.
    period, amp = 48, 5

    def edge(i):
        return py + 36 + int(amp * math.sin(2 * math.pi * i / period))

    for i in range(w):
        front = edge(i)
        rect(d, px + i, py + 16, 1, front - py - 16, TERMINI_CANOPY)
        # The roof falls away towards the edge between the crests.
        phase = (i % period) / period
        if 0.25 < phase < 0.75:
            rect(d, px + i, py + 16, 1, front - py - 16,
                 shade(TERMINI_CANOPY, -10))
        rect(d, px + i, front - 3, 1, 3, (236, 232, 222))  # the lip
        rect(d, px + i, front, 1, 5, TERMINI_CANOPY_UNDER)  # its shadow
        rect(d, px + i, front + 5, 1, 3, (54, 60, 68))
    for rx in range(px + period // 4, px + w, period // 2):
        top_of = py + 17
        for y in range(top_of, edge(rx - px) - 3):
            rect(d, rx, y, 1, 1, shade(TERMINI_CANOPY, -30))
            rect(d, rx + 1, y, 1, 1, shade(TERMINI_CANOPY, 18))
    for _ in range(w // 12):
        rect(d, px + rng.randrange(w - 4), py + 18 + rng.randrange(12),
             rng.randint(2, 5), 1, shade(TERMINI_CANOPY, -24))

    # The name, on its plate hung under the roof over the middle doorway.
    name = "STAZIONE TERMINI"
    plate_w = text_width(name) * 2 + 12
    tx = px + (w - plate_w) // 2
    rect(d, tx, glass_top + 1, plate_w, 13, (26, 30, 36))
    rect(d, tx, glass_top + 1, plate_w, 1, (90, 96, 104))
    paint_text(d, tx + 6, glass_top + 3, name, (238, 238, 232), scale=2)

    # The doorways, open on the dark inside.
    for x, y in cells:
        if level.at(x, y) != "{":
            continue
        dx, dy = x * TILE, y * TILE
        rect(d, dx, dy, TILE, TILE, (14, 14, 18))
        rect(d, dx, dy, TILE, 2, (60, 66, 74))
        first = level.at(x - 1, y) != "{"
        rect(d, dx + (0 if first else TILE - 2), dy, 2, TILE, (90, 96, 104))
    # Tags along the foot of the glass.
    for _ in range(w // 30):
        gx = px + rng.randrange(w - 14)
        colour = rng.choice(((200, 60, 150), (60, 170, 190), (230, 200, 60),
                             (240, 240, 240)))
        for i in range(0, 12, 2):
            rect(d, gx + i, bottom - 9 + (i % 4) // 2, 2, 1, colour)


def paint_wall_breach(d, rng, px, py, first):
    """The breach knocked through the wall round the tracks, `}`, seen from
    the street: the concrete panels broken off down to the ground, rubble
    spilt across the pavement, the ballast beyond."""
    rect(d, px, py, TILE, TILE, station.BALLAST[0])
    speckle(d, rng, px, py, TILE, TILE, station.BALLAST, 30)
    edge = px if first else px + TILE - 4
    rect(d, edge, py, 4, TILE - 4, (168, 164, 154))
    rect(d, edge, py, 4, 2, (196, 192, 182))
    for _ in range(5):
        rect(d, px + rng.randrange(TILE - 3), py + TILE - 5 +
             rng.randrange(4), rng.randint(2, 4), 2,
             rng.choice(station.RUBBLE))


# ------------------------------------------------ Santa Maria Maggiore


SMM_STONE = (222, 210, 182)
SMM_STONE_SHADE = (184, 170, 142)
SMM_STONE_DARK = (138, 126, 104)
SMM_ROOF = (170, 84, 56)
SMM_ROOF_DARK = (130, 62, 42)
SMM_DOME = (112, 118, 122)
SMM_DOME_LIGHT = (150, 156, 160)
SMM_BRICK = (150, 84, 60)
SMM_BRICK_DARK = (112, 60, 42)
SMM_MAJOLICA = (40, 110, 140)
SMM_GOLD = (200, 164, 70)
SMM_HOLE = (20, 16, 18)
BASILICA = '"'
COLUMN = ">"


def _tiles(d, x, y, w, h, c):
    """Terracotta tiles in courses, their ridges catching the light."""
    rect(d, x, y, w, h, c)
    for cy in range(y, y + h, 4):
        shift = 2 if ((cy - y) // 4) % 2 else 0
        for cx in range(x - shift, x + w, 4):
            rect(d, max(cx, x), cy, 1, 3, shade(c, 22))
        rect(d, x, cy + 3, w, 1, shade(c, -34))


def _dome(d, cx, cy, r, broken, rng):
    """A chapel's dome, lead over its drum, a lantern on top; broken open
    if `broken`, the dark of the chapel below through the hole."""
    rect(d, cx - r, cy, 2 * r, 10, SMM_STONE_SHADE)  # the drum
    for wx in range(cx - r + 4, cx + r - 4, 8):
        rect(d, wx, cy + 3, 3, 5, SMM_HOLE)
    for dy in range(r):
        half = int(math.sqrt(r * r - (r - dy) ** 2))
        rect(d, cx - half, cy - r + dy, 2 * half, 1,
             SMM_DOME_LIGHT if dy < r // 3 else SMM_DOME)
        rect(d, cx - half, cy - r + dy, max(1, half // 3), 1, SMM_DOME_LIGHT)
    for rib in range(-r + 5, r - 4, 7):
        depth = int(math.sqrt(max(0, r * r - rib * rib)))
        rect(d, cx + rib, cy - depth + 2, 1, max(1, depth - 2),
             shade(SMM_DOME, -20))
    rect(d, cx - 3, cy - r - 8, 6, 8, SMM_STONE)  # the lantern
    rect(d, cx - 1, cy - r - 12, 2, 4, SMM_GOLD)
    if broken:
        d.polygon([(cx - 6, cy - r + 3), (cx + 9, cy - r + 6),
                   (cx + 12, cy - 4), (cx + 2, cy - 1), (cx - 8, cy - 6)],
                  fill=SMM_HOLE)
        for _ in range(8):
            rect(d, cx - 8 + rng.randrange(20), cy - r + 3 + rng.randrange(16),
                 2, 1, SMM_BRICK)


def _campanile(d, rng, x, top, w, bottom):
    """The Romanesque bell tower, the tallest in Rome: brick in storeys
    parted by white string courses, arched double windows on each and the
    blue majolica discs between them. Its spire has come down, the top of
    the tower broken off ragged."""
    rect(d, x + w, top + 8, 5, bottom - top - 8, (40, 30, 30))  # its shadow
    rect(d, x, top, w, bottom - top, SMM_BRICK)
    for _ in range((bottom - top) * w // 18):
        rect(d, x + rng.randrange(w - 2), top + rng.randrange(bottom - top),
             2, 1, SMM_BRICK_DARK)
    rect(d, x + w - 3, top, 3, bottom - top, SMM_BRICK_DARK)
    for sy in range(top + 14, bottom - 10, 22):
        rect(d, x, sy, w, 2, SMM_STONE)
        for wx in (x + 5, x + w - 12):
            rect(d, wx, sy + 5, 7, 11, SMM_STONE)
            rect(d, wx + 1, sy + 6, 2, 10, SMM_HOLE)
            rect(d, wx + 4, sy + 6, 2, 10, SMM_HOLE)
        rect(d, x + w // 2 - 2, sy + 17, 4, 4, SMM_MAJOLICA)
        rect(d, x + w // 2 - 1, sy + 18, 2, 2, (140, 200, 220))
    # The broken top: ragged brick where the spire was.
    bites = [6, 9, 4, 11, 7, 3, 10, 5]
    for i in range(w):
        rect(d, x + i, top, 1, bites[i * 8 // w], TRANSPARENT)
    for i in range(0, w, 3):
        rect(d, x + i, top + bites[i * 8 // w], 3, 1, SMM_BRICK_DARK)


def _runs(level, glyph):
    """The runs of `glyph` along the rows, each (x, y, width)."""
    out = []
    for y in range(level.height):
        x = 0
        while x < level.width:
            if level.at(x, y) == glyph:
                w = 1
                while level.at(x + w, y) == glyph:
                    w += 1
                out.append((x, y, w))
                x += w
            else:
                x += 1
    return out


def paint_santa_maria_maggiore(d, rng, level):
    """Santa Maria Maggiore, `"`, on the north side of its square, and the
    Column of Peace, `>`, in front of it: the basilica as Rome knows it,
    and as the end of the world left it. Behind, the long roof of the nave
    between the domes of its two great chapels, the one on the right
    staved in, and the Romanesque bell tower, its spire fallen. In front,
    Fuga's facade between its two palazzi: the portico of five arches
    below, the loggia of three above it, the balustrade with its saints
    along the top; and the right half of the loggia come down, its rubble
    heaped over the portico and out across the pavement (the `"` past the
    front), the saints toppled, the portal blown in, the stone scorched
    and tagged, and a bedsheet hung from the loggia with the word painted
    on it in red. The column's Madonna lies at its foot."""
    cells = [(x, y) for y in range(level.height) for x in range(level.width)
             if level.at(x, y) == BASILICA]
    if not cells:
        return
    # The basilica proper: the rows where the whole block is `"`.
    widths = {}
    for x, y in cells:
        widths.setdefault(y, []).append(x)
    full = max(len(xs) for xs in widths.values())
    rows = sorted(y for y, xs in widths.items() if len(xs) == full)
    xs = widths[rows[0]]
    X0, X1 = min(xs) * TILE, (max(xs) + 1) * TILE
    Y0, B = rows[0] * TILE, (rows[-1] + 1) * TILE
    W = X1 - X0
    cx = X0 + W // 2

    front_top = B - 78
    fx0, fx1 = cx - 92, cx + 92
    # The roofs, as a basilica's lie: the canonry's all round, low; the
    # nave's long gabled roof down the middle from the facade back to the
    # half-dome of the apse, its ridge catching the light; the aisles
    # lower either side of it; and the domes of the two great chapels
    # rising off the aisles halfway along, facing each other across the
    # nave.
    _tiles(d, X0, Y0, W, B - Y0, SMM_ROOF_DARK)
    nave_top = Y0 + 20
    for side, (ax0, ax1) in ((-1, (cx - 64, cx - 40)), (1, (cx + 40,
                                                           cx + 64))):
        _tiles(d, ax0, nave_top + 8, ax1 - ax0, front_top - nave_top - 8,
               shade(SMM_ROOF, -8))
        edge = ax0 if side < 0 else ax1 - 1
        rect(d, edge, nave_top + 8, 1, front_top - nave_top - 8,
             SMM_ROOF_DARK)
    _tiles(d, cx - 40, nave_top, 40, front_top - nave_top,
           shade(SMM_ROOF, 12))
    _tiles(d, cx, nave_top, 40, front_top - nave_top, shade(SMM_ROOF, -14))
    rect(d, cx - 1, nave_top, 3, front_top - nave_top, shade(SMM_ROOF, 46))
    rect(d, cx - 41, nave_top, 1, front_top - nave_top, SMM_ROOF_DARK)
    rect(d, cx + 40, nave_top, 1, front_top - nave_top, SMM_ROOF_DARK)
    # The apse: a half-dome of tiles closing the nave at the back.
    for dy in range(26):
        half = int(math.sqrt(max(0, 40 * 40 - (26 - dy) ** 2 * 2.4)))
        rect(d, cx - half, nave_top - 26 + dy, 2 * half, 1,
             shade(SMM_ROOF, 6 - dy // 3))
    for rib in (-24, -12, 0, 12, 24):
        rect(d, cx + rib, nave_top - 18, 1, 18, SMM_ROOF_DARK)
    dome_y = nave_top + (front_top - nave_top) // 2 + 6
    _dome(d, cx - 86, dome_y, 22, False, rng)
    _dome(d, cx + 86, dome_y, 22, True, rng)
    # The bell tower, on the side of the street, standing up above every
    # roof round it: whoever comes down the street sees it first.
    # A column of the canonry's roof still between it and the street.
    tower_x = X1 - TILE - 36
    _campanile(d, rng, tower_x, Y0 - 112, 30, front_top + 12)
    # From its top, a sheet hung down the tower: LA FINE.
    tx = tower_x + 2
    rect(d, tx, Y0 - 88, 26, 44, (226, 222, 206))
    for fold in range(tx + 4, tx + 26, 7):
        rect(d, fold, Y0 - 88, 1, 44, (196, 190, 172))
    paint_text(d, tx + 5, Y0 - 82, "LA", (150, 24, 24))
    paint_text(d, tx + 3, Y0 - 72, "FINE", (150, 24, 24))
    rect(d, tx + 8, Y0 - 66, 1, 6, (150, 24, 24))
    rect(d, tx + 17, Y0 - 66, 1, 9, (150, 24, 24))

    # The facade: the palazzi either side, the church front between them.
    for wx0, wx1 in ((X0, fx0), (fx1, X1)):
        rect(d, wx0, front_top + 10, wx1 - wx0, B - front_top - 10,
             (214, 184, 136))
        rect(d, wx0, front_top + 10, wx1 - wx0, 4, SMM_STONE)
        for wy in range(front_top + 20, B - 16, 18):
            for wx in range(wx0 + 6, wx1 - 10, 14):
                rect(d, wx - 1, wy - 1, 8, 12, SMM_STONE)
                rect(d, wx, wy, 6, 10, (34, 40, 56)
                     if rng.random() > 0.3 else SMM_HOLE)
        rect(d, wx0, B - 14, wx1 - wx0, 14, SMM_STONE_SHADE)
        for gx in range(wx0 + 8, wx1 - 8, 22):
            rect(d, gx, B - 12, 10, 12, (58, 38, 28))
    # The church front: two storeys of travertine.
    rect(d, fx0, front_top, fx1 - fx0, B - front_top, SMM_STONE)
    rect(d, fx0, front_top, fx1 - fx0, 3, (240, 232, 214))
    mid = front_top + 36
    rect(d, fx0, mid - 3, fx1 - fx0, 4, SMM_STONE_SHADE)  # the cornice
    # The pediment over the middle of the loggia.
    for dy in range(16):
        half = 30 * dy // 15
        rect(d, cx - half, front_top - 16 + dy, 2 * half, 1, SMM_STONE)
    rect(d, cx - 30, front_top - 1, 60, 2, SMM_STONE_SHADE)
    # The balustrade and its saints, most of them fallen.
    rect(d, fx0, front_top - 4, fx1 - fx0, 4, SMM_STONE_SHADE)
    for i, sx in enumerate(range(fx0 + 6, fx1 - 4, 18)):
        if i % 3 != 1:
            rect(d, sx, front_top - 12, 4, 8, SMM_STONE_DARK)
            rect(d, sx + 1, front_top - 15, 2, 3, SMM_STONE_DARK)
    # The loggia: three arches, the mosaics glinting gold in the dark.
    for ax in (cx - 66, cx - 18, cx + 30):
        rect(d, ax, mid - 30, 36, 26, SMM_STONE_SHADE)
        rect(d, ax + 3, mid - 24, 30, 20, SMM_HOLE)
        d.ellipse([ax + 3, mid - 32, ax + 32, mid - 18], fill=SMM_HOLE)
        for _ in range(10):
            rect(d, ax + 5 + rng.randrange(24), mid - 28 + rng.randrange(10),
                 2, 1, SMM_GOLD)
    # The portico: five arches, every one of them shut against whatever
    # is out on the square -- a site barrier across it and planks nailed
    # over the dark behind -- and the last on the right buried to its
    # crown in the rubble of the loggia.
    arches = list(range(fx0 + 10, fx1 - 30, 34))
    for i, ax in enumerate(arches):
        rect(d, ax, mid + 8, 28, B - mid - 8, SMM_STONE_SHADE)
        rect(d, ax + 3, mid + 14, 22, B - mid - 14, SMM_HOLE)
        d.ellipse([ax + 3, mid + 5, ax + 24, mid + 22], fill=SMM_HOLE)
        if i == len(arches) - 1:
            for _ in range(60):
                w, h = rng.randint(3, 7), rng.randint(2, 4)
                rect(d, ax + 1 + rng.randrange(24), mid + 6 +
                     rng.randrange(B - mid - 8), w, h,
                     rng.choice((SMM_STONE, SMM_STONE_SHADE, SMM_STONE_DARK,
                                 SMM_BRICK)))
            continue
        for k, by in enumerate(range(mid + 16, B - 4, 6)):  # the planks
            tilt = rng.choice((-2, -1, 1, 2))
            wood = (122, 92, 60) if k % 2 == 0 else (98, 72, 46)
            for bx in range(22):
                rect(d, ax + 3 + bx, by + tilt * bx // 22, 1, 3, wood)
            rect(d, ax + 4, by + 1, 1, 1, (40, 36, 34))
            rect(d, ax + 23, by + 1 + tilt, 1, 1, (40, 36, 34))
        by = B - 14  # the site barrier across the foot
        rect(d, ax - 2, by, 32, 5, (236, 232, 222))
        for sx in range(ax - 2, ax + 30, 8):
            rect(d, sx, by, 4, 5, (206, 40, 36))
        for leg in (ax, ax + 24):
            rect(d, leg, by + 5, 2, 9, (70, 70, 74))
    for px in range(fx0 + 6, fx1 - 4, 34):  # pilasters
        rect(d, px, mid + 4, 4, B - mid - 4, (236, 228, 208))
    # The right half of the loggia, fallen: a ragged breach through the
    # front down into the portico, the dark of the nave inside it, the
    # beams of the roof hanging broken across it, the torn edges of the
    # stone and the brick behind them, and the stone come down in a slide
    # over the portico's arches.
    hole = [(cx + 12, front_top - 2), (cx + 26, front_top - 8),
            (cx + 40, front_top + 1), (cx + 52, front_top - 6),
            (cx + 66, front_top + 4), (cx + 78, front_top + 2),
            (fx1 - 4, mid + 2), (cx + 70, mid + 14), (cx + 56, mid + 8),
            (cx + 42, mid + 18), (cx + 30, mid + 6), (cx + 18, mid + 10),
            (cx + 10, mid - 6)]
    d.polygon(hole, fill=SMM_HOLE)
    for i in range(len(hole)):  # the torn edge: stone, then brick
        a, b = hole[i], hole[(i + 1) % len(hole)]
        d.line([a, b], fill=SMM_STONE_DARK, width=3)
        d.line([(a[0], a[1] + 2), (b[0], b[1] + 2)], fill=SMM_BRICK, width=1)
    for bx0, by0, bx1, by1 in ((cx + 16, front_top + 4, cx + 54, front_top + 22),
                               (cx + 48, front_top + 2, cx + 74, front_top + 16),
                               (cx + 30, front_top + 14, cx + 62, front_top + 8)):
        d.line([(bx0, by0), (bx1, by1)], fill=(70, 46, 30), width=3)
        d.line([(bx0, by0 - 1), (bx1, by1 - 1)], fill=(104, 70, 44))
    for _ in range(40):  # the slide of stone over the portico
        w, h = rng.randint(3, 8), rng.randint(2, 5)
        sx = cx + 14 + rng.randrange(fx1 - cx - 22)
        sy = mid + 6 + rng.randrange(B - mid - 8)
        rect(d, sx, sy, w, h, rng.choice((SMM_STONE, SMM_STONE_SHADE,
                                          SMM_STONE_DARK, SMM_BRICK)))
    for _ in range(6):  # stone blocks jutting from the torn edge
        a = hole[rng.randrange(len(hole))]
        rect(d, a[0] - 2, a[1] - 2, rng.randint(4, 7), rng.randint(3, 5),
             SMM_STONE)
    # Scorch licking up from the portico, the tags on the stone.
    for _ in range(9):
        sx = fx0 + rng.randrange(fx1 - fx0 - 10)
        for k in range(4):
            rect(d, sx + k, B - 26 - k * 4, 8 - k, 4, (40, 34, 32))
    for _ in range(6):
        gx = fx0 + rng.randrange(fx1 - fx0 - 16)
        colour = rng.choice(((200, 60, 150), (60, 170, 190), (230, 200, 60),
                             (240, 240, 240)))
        for i in range(0, 14, 2):
            rect(d, gx + i, B - 8 + (i % 4) // 2, 2, 1, colour)
    # Words daubed on the two wings in red, running.
    def daub(x, y, text, scale):
        paint_text(d, x, y, text, (160, 20, 20), scale=scale)
        for i in range(0, text_width(text) * scale, 5):
            rect(d, x + i, y + 5 * scale, 1, rng.randint(2, 7),
                 (160, 20, 20))

    daub(fx1 + 8, B - 44, "PECCATORI", 2)
    daub(X0 + 10, B - 48, "LA FINE", 1)
    daub(X0 + 10, B - 38, "DEL MONDO", 1)

    # The bedsheet from the loggia: PENTITEVI.
    bx, by = cx - 64, mid - 25
    rect(d, bx, by, 46, 22, (226, 222, 206))
    for fold in range(bx + 6, bx + 44, 9):
        rect(d, fold, by, 1, 22, (196, 190, 172))
    paint_text(d, bx + 5, by + 8, "PENTITEVI", (150, 24, 24))
    rect(d, bx + 12, by + 14, 1, 5, (150, 24, 24))
    rect(d, bx + 30, by + 14, 1, 7, (150, 24, 24))

    # The rubble fallen from the loggia, heaped against the portico and
    # spilt past the front over the pavement.
    for x, y in cells:
        if y * TILE < B:
            continue
        for _ in range(12):
            w, h = rng.randint(3, 7), rng.randint(2, 4)
            rect(d, x * TILE + rng.randrange(TILE - w + 1),
                 y * TILE - 6 + rng.randrange(TILE - h + 6), w, h,
                 rng.choice((SMM_STONE, SMM_STONE_SHADE, SMM_STONE_DARK,
                             SMM_BRICK)))
        if rng.random() < 0.5:  # a saint in the heap, on his back
            sx, sy = x * TILE + 3, y * TILE + 5
            rect(d, sx, sy, 10, 4, SMM_STONE_DARK)
            rect(d, sx + 10, sy, 3, 3, SMM_STONE_DARK)

    # The placards stuck up on the square: boards on two posts.
    for x, y, w in _runs(level, "`"):
        px, py = x * TILE, y * TILE
        for post in (px + 5, px + w * TILE - 7):
            rect(d, post, py - 4, 2, 18, (92, 66, 44))
        rect(d, px + 1, py - 14, w * TILE - 2, 14, (206, 196, 170))
        rect(d, px + 1, py - 14, w * TILE - 2, 1, (230, 222, 200))
        words = "PECCATORI"
        paint_text(d, px + (w * TILE - text_width(words)) // 2, py - 10,
                   words, (150, 24, 24))
        rect(d, px + 3, py + 12, w * TILE - 4, 3, (36, 34, 34))

    # The Column of Peace, its Madonna thrown down at its foot.
    col = [(x, y) for y in range(level.height) for x in range(level.width)
           if level.at(x, y) == COLUMN]
    if col:
        (x, y), = col
        ccx, base = x * TILE + TILE // 2, (y + 1) * TILE - 2
        rect(d, ccx - 6, base - 8, 18, 8, (30, 28, 30))  # its shadow
        rect(d, ccx - 8, base - 12, 16, 12, SMM_STONE_SHADE)
        rect(d, ccx - 8, base - 12, 16, 2, SMM_STONE)
        rect(d, ccx - 4, base - 92, 8, 80, SMM_STONE)
        for fl in (ccx - 2, ccx + 1):
            rect(d, fl, base - 90, 1, 76, SMM_STONE_SHADE)
        rect(d, ccx + 3, base - 92, 1, 80, SMM_STONE_DARK)
        rect(d, ccx - 6, base - 96, 12, 5, SMM_STONE)  # the capital
        rect(d, ccx - 3, base - 99, 6, 3, (70, 60, 50))  # the empty plinth
        rect(d, ccx + 8, base - 4, 11, 4, (70, 60, 50))  # the Madonna, down
        rect(d, ccx + 18, base - 5, 3, 3, (70, 60, 50))
        rect(d, ccx + 9, base - 5, 9, 1, (110, 96, 76))


def paint_street_banner(d, px, py, w, text):
    """A sheet strung across a street between the roofs, sagging in the
    middle, the words painted on it in red: the end of the world
    announced to whoever walks under it."""
    for i in range(w):
        sag = int(4 * math.sin(math.pi * i / max(1, w - 1)))
        rect(d, px + i, py + sag, 1, 1, (60, 56, 54))  # the rope
    left, right = px + 14, px + w - 14
    for i in range(left, right):
        sag = int(4 * math.sin(math.pi * (i - px) / max(1, w - 1)))
        rect(d, i, py + 2 + sag, 1, 12, (226, 222, 206))
        if (i - left) % 9 == 0:
            rect(d, i, py + 2 + sag, 1, 12, (196, 190, 172))
    mid = int(4 * math.sin(math.pi / 2))
    tx = px + (w - text_width(text)) // 2
    paint_text(d, tx, py + 6 + mid - 1, text, (150, 24, 24))
    for i in range(0, text_width(text), 6):
        rect(d, tx + i, py + 11 + mid, 1, 3, (150, 24, 24))


# ------------------------------------------------- the Baths of Diocletian

TERME = "§"
# The portal of Santa Maria degli Angeli in their front, the way in,
# and the brown sign with their name on the pavement before them.
TERME_DOOR = "¶"
TERME_SIGN = "¤"
SIGN_BROWN = (112, 64, 36)
SIGN_BROWN_DARK = (78, 44, 26)
TERME_BRICK = (164, 96, 64)
TERME_BRICK_DARK = (124, 68, 44)
TERME_BRICK_LIGHT = (190, 124, 86)
TERME_MORTAR = (140, 104, 80)
TERME_TOP = (132, 92, 66)
TERME_MOSS = (86, 104, 58)
TERME_GRASS = (110, 128, 66)
TERME_HOLE = (22, 16, 16)


def _brickwork(d, rng, x, y, w, h, base=TERME_BRICK):
    """Roman brick in thin courses, bonded, a darker brick here and there
    and the mortar gone from the joints."""
    rect(d, x, y, w, h, base)
    for cy in range(y + 3, y + h, 4):
        rect(d, x, cy, w, 1, shade(base, -26))
        shift = 3 if (cy // 4) % 2 else 0
        for cx in range(x + shift, x + w, 7):
            rect(d, cx, cy - 3, 1, 3, shade(base, -18))
    for _ in range(w * h // 40):
        rect(d, x + rng.randrange(w), y + rng.randrange(h), rng.randint(2, 5),
             1, rng.choice((TERME_BRICK_DARK, TERME_BRICK_LIGHT, TERME_MORTAR)))


def _ruined_top(d, rng, x, y, w, h):
    """What is left over the halls: the stumps of the vaults, their brick
    rings seen end on, grass and saplings rooted in the rubble between."""
    rect(d, x, y, w, h, TERME_TOP)
    for _ in range(w * h // 30):
        rect(d, x + rng.randrange(w), y + rng.randrange(h), rng.randint(2, 6),
             rng.randint(1, 2), rng.choice((TERME_BRICK_DARK, TERME_MORTAR,
                                            shade(TERME_TOP, 14))))
    # The vaults, broken off: half-rings of brick standing in rows.
    for vx in range(x + 10, x + w - 30, 46):
        r = rng.randint(14, 19)
        cy = y + h - 4
        for dy in range(r):
            half = int(math.sqrt(r * r - dy * dy))
            inner = int(math.sqrt(max(0, (r - 5) ** 2 - dy * dy)))
            rect(d, vx + r - half, cy - dy, half - inner, 1,
                 TERME_BRICK_LIGHT if dy < r - 3 else TERME_BRICK)
            rect(d, vx + r + inner, cy - dy, half - inner, 1, TERME_BRICK)
        if rng.random() < 0.5:  # this one has lost its crown
            rect(d, vx + r - 6, cy - r, 12, 6, TERME_TOP)
    for _ in range(w * h // 60):  # the green that has taken the top
        gx, gy = x + rng.randrange(w - 4), y + rng.randrange(h - 3)
        rect(d, gx, gy, rng.randint(2, 5), 2, rng.choice((TERME_MOSS,
                                                          TERME_GRASS)))
        if rng.random() < 0.15 and gy - 8 >= y:  # a sapling
            rect(d, gx + 1, gy - 5, 1, 5, (92, 70, 48))
            rect(d, gx - 2, gy - 8, 6, 4, TERME_MOSS)


def _thermal_window(d, cx, base, r):
    """A thermal window: the half-moon of a bath hall, its arch ringed in
    brick, parted by two mullions into three lights; the dark of the empty
    hall behind."""
    for dy in range(r + 4):
        half = int(math.sqrt(max(0, (r + 4) ** 2 - dy * dy)))
        rect(d, cx - half, base - dy, 2 * half, 1, TERME_BRICK_LIGHT)
    for dy in range(r):
        half = int(math.sqrt(r * r - dy * dy))
        rect(d, cx - half, base - dy, 2 * half, 1, TERME_HOLE)
    rect(d, cx - r - 4, base, 2 * r + 8, 3, shade(TERME_BRICK_LIGHT, 12))
    for mx in (cx - r // 3, cx + r // 3):
        top = base - int(math.sqrt(max(0, r * r - (mx - cx) ** 2)))
        rect(d, mx - 1, top, 3, base - top, TERME_BRICK)


def _arch(d, x, top, w, bottom, fill):
    """A round-headed opening in the wall, `fill` inside it."""
    r = w // 2
    rect(d, x - 2, top + r - 2, w + 4, bottom - top - r + 2,
         TERME_BRICK_LIGHT)
    d.ellipse([x - 2, top - 2, x + w + 1, top + w + 1], fill=TERME_BRICK_LIGHT)
    rect(d, x, top + r, w, bottom - top - r, fill)
    d.ellipse([x, top, x + w - 1, top + w - 1], fill=fill)


def paint_terme_diocleziano(d, rng, level):
    """The Baths of Diocletian, `§`, where the road past Termini ends, west
    of Piazza dei Cinquecento: the biggest baths Rome ever built, a wall
    of Roman brick along the north side of the road, as tall as the
    station's front, and a wing of them across the end of it. Over the
    top, the stumps of the vaults and the green grown on them; down the
    front, the three great half-moon windows of the halls; at the foot,
    arches, bricked up long ago or gaping, and in the middle the plain
    portal of Santa Maria degli Angeli, the church Michelangelo made of the
    frigidarium. The end of the world has added little to a ruin: soot,
    brick fallen off the wing, the portal barred."""
    cells = [(x, y) for y in range(level.height) for x in range(level.width)
             if level.at(x, y) in TERME + TERME_DOOR]
    if not cells:
        return
    door = next(((x, y) for x, y in cells if level.at(x, y) == TERME_DOOR),
                None)
    signs = [(x, y) for y in range(level.height) for x in range(level.width)
             if level.at(x, y) == TERME_SIGN]
    widths = {}
    for x, y in cells:
        widths.setdefault(y, []).append(x)
    full = max(len(xs) for xs in widths.values())
    main = sorted(y for y, xs in widths.items() if len(xs) == full)
    X0 = min(widths[main[0]]) * TILE
    X1 = (max(widths[main[0]]) + 1) * TILE
    Y0, B = main[0] * TILE, (main[-1] + 1) * TILE
    W = X1 - X0
    wing = sorted(y for y in widths if y > main[-1])
    WX1 = (max(max(widths[y]) for y in wing) + 1) * TILE if wing else X0
    WB = (wing[-1] + 1) * TILE if wing else B

    # The wing across the end of the road: its broken top, the end wall
    # of the halls at its foot, its side facing up the road in the shade
    # and its shadow on the road.
    if wing:
        _ruined_top(d, rng, X0, B, WX1 - X0, WB - B - 26)
        _brickwork(d, rng, X0, WB - 26, WX1 - X0, 26, TERME_BRICK_DARK)
        _arch(d, X0 + (WX1 - X0) // 2 - 9, WB - 24, 18, WB, TERME_HOLE)
        rect(d, WX1 - 5, B, 5, WB - B, shade(TERME_BRICK_DARK, -18))
        for sy in range(B, WB - 4):
            rect(d, WX1, sy, 4, 1, (30, 26, 28))
        # Brick come down off its top, spilt at the foot of its side.
        for _ in range(30):
            rect(d, WX1 - 8 + rng.randrange(10), WB - 30 + rng.randrange(24),
                 rng.randint(2, 4), rng.randint(1, 3),
                 rng.choice((TERME_BRICK, TERME_BRICK_DARK, TERME_MORTAR)))

    # The front, taller than the palazzi: the ruined top, then the wall.
    front = Y0 + max(20, (B - Y0) // 3)
    _ruined_top(d, rng, X0, Y0, W, front - Y0)
    _brickwork(d, rng, X0, front, W, B - front)
    rect(d, X0, front, W, 3, TERME_BRICK_LIGHT)  # the cornice, broken
    for _ in range(6):
        gap = X0 + rng.randrange(W - 20)
        rect(d, gap, front, rng.randint(8, 18), 4, TERME_TOP)
    # The three thermal windows of the halls.
    lunette = front + (B - front) * 11 // 20
    for i in range(3):
        _thermal_window(d, X0 + W * (2 * i + 1) // 6, lunette,
                        min(22, lunette - front - 8))
    # Pilasters of brick between them, down to the arcade.
    for i in range(1, 3):
        px = X0 + W * i // 3
        rect(d, px - 3, front + 6, 6, B - front - 6, TERME_BRICK_LIGHT)
        rect(d, px + 2, front + 6, 1, B - front - 6, TERME_BRICK_DARK)
    # The arcade at the foot: arches bricked up long ago, a few gaping,
    # and the portal of the church in the middle.
    cx = door[0] * TILE + TILE // 2 if door else X0 + W // 2
    foot = lunette + 6
    for i, ax in enumerate(range(X0 + 8, X1 - 22, 34)):
        if abs(ax + 10 - cx) < 26:
            continue
        infill = TERME_HOLE if i % 3 == 1 else shade(TERME_BRICK, 16)
        _arch(d, ax, foot, 20, B, infill)
        if infill != TERME_HOLE:
            for cy in range(foot + 12, B, 4):
                rect(d, ax, cy, 20, 1, shade(TERME_BRICK, -6))
    # Santa Maria degli Angeli: the plain portal of travertine in the
    # rough brick, its little pediment, and the planks somebody nailed
    # over it torn away, the dark of the church behind: the way in.
    rect(d, cx - 16, foot - 2, 32, B - foot + 2, (206, 196, 174))
    for dy in range(9):
        half = 20 * dy // 8
        rect(d, cx - half, foot - 11 + dy, 2 * half, 1, (214, 204, 182))
    rect(d, cx - 11, foot + 4, 22, B - foot - 4, (20, 16, 16))
    rect(d, cx - 13, foot + 7, 8, 3, (126, 94, 60))  # a plank left on
    for k, (ox, oy) in enumerate(((-17, B - 5), (8, B - 3))):
        rect(d, cx + ox, oy, 12, 3, (126, 94, 60) if k else (100, 74, 48))
    # Soot run down the front in streaks, moss, cracks, and the damp at
    # the foot.
    for _ in range(7):
        sx = X0 + rng.randrange(W - 4)
        top = front + rng.randrange(4, 24)
        for k in range(B - top):
            if rng.random() < 0.85:
                rect(d, sx, top + k, 2 if k < (B - top) // 2 else 1, 1,
                     shade(TERME_BRICK, -34))
    for _ in range(W // 8):
        rect(d, X0 + rng.randrange(W - 3), front + rng.randrange(8, 30),
             rng.randint(1, 3), rng.randint(2, 6), TERME_MOSS)
    for _ in range(4):
        x, y = X0 + rng.randrange(W - 10), front + rng.randrange(6, 40)
        for k in range(rng.randint(6, 14)):
            rect(d, x + (k * 3) % 5 - 2, y + k, 1, 1, TERME_HOLE)
    rect(d, X0, B - 4, W, 4, shade(TERME_BRICK_DARK, -10))
    if door:  # the damp at the foot stops at the doorway
        rect(d, cx - 11, B - 4, 22, 4, (20, 16, 16))
    for sx, sy in signs:
        _brown_sign(d, sx * TILE, sy * TILE, ("TERME DI", "DIOCLEZIANO"))


def _brown_sign(d, px, py, lines):
    """The brown sign Italy puts up by its monuments, white lettering in
    a white border, on two posts planted in the pavement at `px`, `py` and
    standing up into the rows above, where it can be read over the heads
    of whoever walks past."""
    w = max(len(line) for line in lines) * 4 + 7
    h = len(lines) * 7 + 5
    x = px + TILE // 2 - w // 2
    top = py + TILE - 6 - 16 - h
    for post in (x + 5, x + w - 7):
        rect(d, post, top + h, 2, py + TILE - 2 - top - h, (150, 150, 146))
        rect(d, post + 1, top + h, 1, py + TILE - 2 - top - h,
             (110, 110, 106))
    rect(d, x + 3, py + TILE - 2, w - 6, 2, (30, 26, 26))  # the shadow
    rect(d, x, top, w, h, SIGN_BROWN)
    rect(d, x, top, w, 1, (238, 236, 228))
    rect(d, x, top + h - 1, w, 1, (238, 236, 228))
    rect(d, x, top, 1, h, (238, 236, 228))
    rect(d, x + w - 1, top, 1, h, (238, 236, 228))
    rect(d, x + 1, top + h - 2, w - 2, 1, SIGN_BROWN_DARK)
    for i, line in enumerate(lines):
        lx = x + (w - len(line) * 4 + 1) // 2
        paint_text(d, lx, top + 3 + i * 7, line, (238, 236, 228))
