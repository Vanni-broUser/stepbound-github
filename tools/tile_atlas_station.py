"""Molfetta's station in the tile atlas: the booking hall and its
platform, the far side of the tracks, the underpass between them, and the
railcar, coaches and name boards that are pictures of their own rather
than tiles (lib/core/levels/hometown/station*.dart). The name boards and
the stairs up are Termini's too: tile_atlas_termini.py takes them from
here.

A module of its own, the way docs/level_pipeline.md wants the interiors
to go: build_tile_atlas.py only lists it. The painters stay in
tools/build_station.py; here is what is made of them.
"""
from __future__ import annotations

import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_station as station  # noqa: E402
from street_paint import (  # noqa: E402
    TILE,
    paint_text,
    rect,
    shade,
    text_width,
)
from build_mall import paint_blood  # noqa: E402
from tile_atlas_core import (  # noqa: E402
    Atlas,
    Neighbourhood,
    SEED,
    TRANSPARENT,
    cell,
    first_row_key,
    neighbour_key,
    paint_side_edge,
    parity_key,
    pattern_key,
    rule,
    tile_of,
)

def station_underpass(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.stationUnderpass: the corridor under
    the tracks, glazed tile over a dark plinth, lit by strip lights."""
    floor = atlas.bucket(lambda: cell(
        lambda d, gx, gy: station.paint_underpass_floor(d, rng, gx, gy)))
    wall = [
        atlas.bucket(lambda a=above: tile_of(
            lambda d: station.paint_underpass_wall(
                d, rng,
                Neighbourhood("W", lambda x, y, a=a: "W" if a else "."),
                0, 0)))
        for above in (False, True)
    ]
    front = atlas.bucket(
        lambda: tile_of(lambda d: station.paint_underpass_front(d, 0, 0)), 1)
    litter = atlas.bucket(
        lambda: tile_of(lambda d: station.paint_litter(d, rng, 0, 0)))
    blood = atlas.bucket(
        lambda: tile_of(lambda d: paint_blood(d, rng, 0, 0)))
    lamps = {
        glyph: atlas.bucket(lambda dead=dead: tile_of(
            lambda d: station.paint_lamp(d, 0, 0, dead)), 1)
        for glyph, dead in (("*", False), ("+", True))
    }

    def stairs(glyph):
        """The head of a flight: its two ends carry the handrail and half
        the arrow, so the key is whether the flight goes on beside it."""
        out = []
        for right in (False, True):
            for left in (False, True):
                out.append(atlas.bucket(lambda l=left, r=right, g=glyph:
                    tile_of(lambda d: station.paint_stairs(d, Neighbourhood(
                        g, lambda x, y, l=l, r=r, g=g: g
                        if (x == -1 and l) or (x == 1 and r) else "."),
                        0, 0)), 1))
        return out

    floored = ".:b*+Z"
    rules = [
        rule("ground", floored + "UD", [floor]),
        rule("structures", "W", wall, [neighbour_key(0, -1, "W")]),
        rule("structures", "w", [front]),
        rule("structures", ":", [litter]),
        rule("structures", "b", [blood]),
        rule("structures", "*", [lamps["*"]]),
        rule("structures", "+", [lamps["+"]]),
    ]
    for glyph in "UD":
        rules.append(rule("structures", glyph, stairs(glyph),
                          [neighbour_key(-1, 0, glyph),
                           neighbour_key(1, 0, glyph)]))
    rules += side_walls(atlas)
    return {"void": "#000000", "voidGlyph": "x", "rules": rules,
            "objects": []}


# The railcar is one object, not tiles: its grime runs across the grid. It
# is painted at the size of the run of `M` in the far platform's rows;
# test/levels/tile_atlas_test.dart fails if the rows stop agreeing.
RAILCAR_TILES = (34, 3)
TERMINI_RAILCAR_TILES = (42, 3)
TERMINI_WALL_SIGN_TILES = (10, 2)
TERMINI_PLATFORM_SIGN_TILES = (3, 2)
STATION_SIGN_TILES = (8, 1)
# Counted from the west end. The train faces east, like the locomotive
# inside it: its red tail is at the west end and its door at the back,
# like the train's own way in; the east end is the locomotive's nose.
RAILCAR_DOOR_TILE = 5
TERMINI_RAILCAR_DOOR_TILE = 4
# How far back from the east end the nose starts to slope.
RAILCAR_NOSE = 46


def paint_locomotive_nose(sprite: Image.Image) -> None:
    """Shapes the east end of the railcar into a streamlined nose, side
    on: the roof curving down into a long raked windscreen and a rounded
    front, the livery bands running on into it, a headlight low down and
    the skirt tucked under. Whatever the railcar painter put there -- the
    last windows, a roof vent -- is painted over."""
    width, height = sprite.size
    px = sprite.load()
    start = width - RAILCAR_NOSE
    skirt_top, skirt_bottom = height - 12, height - 6
    band_bottom = height - 17  # where the blue band starts

    def edge(y):
        """The front's outline at pixel row `y`: an ellipse's quarter from
        the roof down to the waist, then straight, then under the skirt."""
        if y <= band_bottom + 5:
            t = y / (band_bottom + 5)
            return start + (RAILCAR_NOSE - 2) * (1 - (1 - t) ** 2) ** 0.5
        return width - 2 - max(0, y - skirt_top)

    green = station.LIVERY_GREEN
    for y in range(skirt_bottom):
        e = edge(y)
        for x in range(start, width):
            if x > e:
                px[x, y] = TRANSPARENT
                continue
            if y < 9:
                colour = shade(green, -38)
            elif y < 16:
                colour = green
            elif y < band_bottom:
                colour = station.LIVERY_WHITE
            elif y < skirt_top:
                colour = station.LIVERY_BLUE
            else:
                colour = shade(station.LIVERY_WHITE, -64)
            if x >= int(e) - 1:
                colour = station.METAL_DARK  # the outline
            px[x, y] = colour + (255,)
    # The windscreen: a band of glass following the slope, with a glint.
    for y in range(4, 22):
        e = int(edge(y))
        for x in range(max(start, e - 13), e - 2):
            px[x, y] = station.GLASS + (255,)
        if 6 <= y <= 12:
            px[max(start, e - 9), y] = shade(station.GLASS, 40) + (255,)
    # The pillar between the windscreen and the side window behind it.
    for y in range(9, 22):
        e = int(edge(y))
        px[max(start, e - 14), y] = station.METAL_DARK + (255,)
    # The same years of grime as the rest of the flank, run down the nose.
    rng = random.Random(SEED + 2)
    for _ in range(14):
        x = start + rng.randrange(RAILCAR_NOSE - 16)
        y0, length = rng.randrange(16, band_bottom - 4), rng.randint(3, 8)
        colour = rng.choice(((166, 160, 146), (146, 140, 126),
                             (176, 170, 156)))
        for y in range(y0, min(y0 + length, skirt_top)):
            if x < int(edge(y)) - 3:
                px[x, y] = colour + (255,)
    # The headlight, low on the front, and the coupler cover under it.
    for y in range(band_bottom - 3, band_bottom):
        e = int(edge(y))
        for x in range(e - 5, e - 2):
            px[x, y] = (250, 238, 180, 255)
    for y in range(skirt_top, skirt_top + 3):
        e = int(edge(y))
        for x in range(e - 4, e - 1):
            px[x, y] = station.METAL_DARK + (255,)


def station_railcar_sprite(tiles, door_tile, open_door: bool) -> Image.Image:
    """The intact train, with its red tail west and streamlined nose east."""
    width, height = (n * TILE for n in tiles)
    sprite = Image.new("RGBA", (width, height), TRANSPARENT)
    station.paint_railcar(
        ImageDraw.Draw(sprite), random.Random(SEED + 1),
        (0, 0, width, height), wrecked=False,
        door_x=door_tile * TILE, open_door=open_door,
    )
    paint_locomotive_nose(sprite)
    return sprite


# The blue of the name boards of every Italian station, and their white.
SIGN_BLUE = (22, 68, 142)
SIGN_BLUE_DARK = (12, 38, 86)
SIGN_BLUE_LIGHT = (44, 96, 172)
SIGN_WHITE = (238, 241, 236)
SIGN_POST = (92, 96, 104)


def paint_name_board(d, x, y, w, h, text, scale):
    """A station's name board: blue, a white rule inset along its edge and
    the name in white capitals in the middle, as on every platform in
    Italy, with a darker lip along the bottom."""
    rect(d, x, y, w, h, SIGN_BLUE_DARK)
    rect(d, x + 1, y + 1, w - 2, h - 2, SIGN_BLUE)
    rect(d, x + 1, y + 1, w - 2, 1, SIGN_BLUE_LIGHT)
    rect(d, x + 2, y + 2, w - 4, 1, SIGN_WHITE)
    rect(d, x + 2, y + h - 3, w - 4, 1, SIGN_WHITE)
    rect(d, x + 2, y + 2, 1, h - 4, SIGN_WHITE)
    rect(d, x + w - 3, y + 2, 1, h - 4, SIGN_WHITE)
    width = text_width(text) * scale
    paint_text(d, x + (w - width) // 2, y + (h - 5 * scale) // 2, text,
               SIGN_WHITE, scale=scale)


def termini_wall_sign() -> Image.Image:
    """ROMA TERMINI, high on the back wall over the train: a long board
    bolted to the wall on four brackets, its shadow under it."""
    width, height = (n * TILE for n in TERMINI_WALL_SIGN_TILES)
    sprite = Image.new("RGBA", (width, height), TRANSPARENT)
    d = ImageDraw.Draw(sprite)
    top, board = 3, 26
    rect(d, 2, top + board, width - 4, 2, (60, 56, 50, 140))  # its shadow
    for bx in (10, width // 3, 2 * width // 3, width - 12):
        rect(d, bx, top - 3, 2, 4, SIGN_POST)
    paint_name_board(d, 0, top, width, board, "ROMA TERMINI", 3)
    return sprite


def termini_platform_sign() -> Image.Image:
    """ROMA on its two posts at the edge of the platform: the board stands
    a tile above the cells its posts are in, in front of the train."""
    width, height = (n * TILE for n in TERMINI_PLATFORM_SIGN_TILES)
    sprite = Image.new("RGBA", (width, height), TRANSPARENT)
    d = ImageDraw.Draw(sprite)
    for post in (6, width - 8):
        rect(d, post, 10, 2, height - 12, SIGN_POST)
        rect(d, post, 10, 1, height - 12, shade(SIGN_POST, 30))
        rect(d, post - 1, height - 3, 4, 2, (40, 40, 44))  # its foot
    paint_name_board(d, 1, 0, width - 2, 19, "ROMA", 2)
    rect(d, 3, height - 2, width - 6, 2, (30, 30, 34, 110))  # its shadow
    return sprite


def paint_stairs_up(d, room, x, y):
    """The foot of a flight going up, `D` at Termini: the steps climb away
    through the front wall, each one higher and so nearer the light than the
    one before, between two handrails, under the green plate with the arrow
    up. Molfetta's go down into a dark well (build_station.paint_stairs)."""
    px, py = x * TILE, y * TILE
    glyph = room.at(x, y)
    first = room.at(x - 1, y) != glyph
    last = room.at(x + 1, y) != glyph
    rect(d, px, py, TILE, TILE, (70, 68, 64))
    for i, sy in enumerate(range(py + 4, py + TILE, 3)):
        tread = shade((118, 114, 106), 16 * i)
        rect(d, px, sy, TILE, 1, shade(tread, -46))  # the riser's edge
        rect(d, px, sy + 1, TILE, 2, tread)
    rect(d, px, py, TILE, 4, (40, 62, 48))  # the plate over the flight
    rect(d, px, py, TILE, 1, (78, 106, 84))
    if first:  # the arrow up, one half of it per cell
        for i in range(4):
            rect(d, px + 12 + i, py + 3 - i, 1, 1 + i, (232, 232, 220))
    elif last:
        for i in range(4):
            rect(d, px + i, py + i, 1, 4 - i, (232, 232, 220))
    for side, there in ((0, first), (TILE - 2, last)):
        if there:
            rect(d, px + side, py + 4, 2, TILE - 4, station.METAL_DARK)
            rect(d, px + side, py + 4, 2, 2, station.METAL_LIGHT)


def station_far_side(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.stationFarSide: the far platform, the
    track and the railcar Luigi is holed up in."""
    def platform(parity: int, edge: bool):
        return atlas.bucket(lambda p=parity, e=edge: cell(
            lambda d, gx, gy: station.paint_platform(
                d, rng, gx, gy, 0 if e else -1), p, 0))

    def hall(parity: int):
        return atlas.bucket(lambda p=parity: cell(
            lambda d, gx, gy: station.paint_hall(d, rng, gx, gy), p, 0))

    ballast = atlas.bucket(
        lambda: tile_of(lambda d: station.paint_ballast(d, rng, 0, 0)))
    rails = [
        atlas.bucket(lambda c=continuing: tile_of(
            lambda d: station.paint_rails(
                d, rng, Neighbourhood("-", lambda x, y: "-" if c else "."),
                0, 0)))
        for continuing in (False, True)
    ]
    # In key order: bit 0 is "there is another wall above", which is the
    # opposite of the painter's own `top`, and bit 1 is the tag pattern.
    wall = []
    for tagged in (False, True):
        for above in (False, True):
            wall.append(atlas.bucket(lambda a=above, g=tagged: cell(
                lambda d, gx, gy: station.paint_back_wall(
                    d, rng,
                    Neighbourhood("W", lambda x, y, a=a: "W" if a else "."),
                    gx, gy),
                0 if g else 1, 0)))
    litter = atlas.bucket(
        lambda: tile_of(lambda d: station.paint_litter(d, rng, 0, 0)))

    def ends(paint, glyph):
        """Four tiles: the two ends of a run, its middle, and a run of one.
        `paint` is given a neighbourhood that says which sides continue."""
        out = []
        for right in (False, True):
            for left in (False, True):
                out.append(atlas.bucket(lambda l=left, r=right: tile_of(
                    lambda d: paint(d, Neighbourhood(
                        glyph,
                        lambda x, y, l=l, r=r: glyph
                        if (x == -1 and l) or (x == 1 and r) else ".",
                    ), 0, 0)), 1))
        return out

    rules = [
        # The ground, in the order the baker laid it: track, ballast, the
        # platform and its edge, and the booking hall's terrazzo elsewhere.
        rule("ground", "-", rails, [neighbour_key(-1, 0, "-")]),
        rule("ground", ",M", [ballast]),
        rule("ground", "=Tno",
             [platform(0, False), platform(1, False),
              platform(0, True), platform(1, True)],
             [parity_key(), first_row_key("=", 0, "eq")]),
        # Litter lies on the platform if it is near it, on the hall floor
        # if it is not: the baker drew the line two rows below the edge.
        rule("ground", ":",
             [hall(0), hall(1), platform(0, False), platform(1, False)],
             [parity_key(), first_row_key("=", 2, "le")]),
        rule("ground", "DP", [hall(0), hall(1)], [parity_key()]),
        rule("structures", "WlrQ", wall,
             [neighbour_key(0, -1, "WlrQ"), pattern_key(7, 5, 9)]),
        rule("structures", ":", [litter]),
        rule("structures", "D", ends(station.paint_stairs, "D"),
             [neighbour_key(-1, 0, "D"), neighbour_key(1, 0, "D")]),
    ]
    # Termini paints its rows with these rules too, and has no side walls.
    for right in (False, True):
        edge = atlas.bucket(lambda r=right: tile_of(
            lambda d: paint_side_edge(d, 0, 0, r)), 1)
        rules.append(rule("foreground", "-,M=TnD:P",
                          [[], edge], [neighbour_key(1 if right else -1,
                                                     0, "x")]))
    rules += side_walls(atlas)
    rules.append(rule("foreground", "T", ends(station.paint_bench, "T"),
                      [neighbour_key(-1, 0, "T"), neighbour_key(1, 0, "T")]))
    rules.append(rule("foreground", "n",
                      [atlas.bucket(lambda b=beam: tile_of(
                          lambda d: station.paint_post(d, Neighbourhood(
                              "n", lambda x, y, b=b: "n"
                              if (x == 1 and b) else "."), 0, 0)), 1)
                       for beam in (False, True)],
                      [neighbour_key(1, 0, "n")]))

    def station_sign(text: str, broken: bool) -> Image.Image:
        """A weathered Italian railway name board.

        The two halves still identify Molfetta together: grime has hidden
        MOLF on the west board, while the east board has lost its ETTA end.
        """
        width, height = (n * TILE for n in STATION_SIGN_TILES)
        sprite = Image.new("RGBA", (width, height), TRANSPARENT)
        d = ImageDraw.Draw(sprite)
        blue = (26, 78, 151)
        blue_dark = (14, 45, 93)
        blue_light = (48, 104, 181)
        white = (235, 239, 232)

        if broken:
            # The metal tears away directly after MOLF: there is no intact
            # blue gap that could have held the missing letters.
            d.polygon(
                [(1, 1), (39, 1), (43, 4), (39, 7), (44, 10),
                 (40, 14), (1, 14)],
                fill=blue,
            )
            d.line([(1, 1), (39, 1), (43, 4)], fill=white, width=1)
            d.line([(1, 14), (40, 14)], fill=white, width=1)
            d.line([(1, 1), (1, 14)], fill=white, width=1)
            d.line([(39, 2), (36, 7), (42, 10), (38, 14)],
                   fill=blue_dark, width=2)
            d.polygon([(48, 3), (60, 2), (57, 7), (46, 8)],
                      fill=blue_dark)
            d.polygon([(52, 4), (58, 3), (56, 5)], fill=blue_light)
            d.polygon([(69, 10), (78, 8), (75, 14), (66, 14)],
                      fill=blue)
            paint_text(d, 9, 3, text, white, scale=2)
        else:
            rect(d, 0, 0, width, height, blue_dark)
            rect(d, 1, 1, width - 2, height - 2, white)
            rect(d, 2, 2, width - 4, height - 4, blue)
            paint_text(d, width - 39, 3, text, white, scale=2)

            # Thick soot, rust and rain streaks conceal the missing MOLF.
            grime = (55, 58, 52)
            soot = (31, 35, 34)
            rust = (101, 70, 43)
            d.polygon([(2, 2), (83, 2), (88, 5), (84, 8), (89, 13),
                       (2, 13)], fill=grime)
            d.polygon([(2, 2), (69, 2), (83, 6), (76, 9), (24, 7)],
                      fill=soot)
            d.line([(12, 3), (12, 13)], fill=rust, width=2)
            d.line([(55, 2), (58, 12)], fill=rust, width=1)
            d.line([(82, 4), (85, 13)], fill=soot, width=2)
            d.point([(18, 10), (63, 5), (86, 11)], fill=(142, 129, 100))

        return sprite

    return {
        "void": "#000000",
        "voidGlyph": "x",
        "rules": rules,
        "objects": [
            {"glyph": "M", "image": "station_railcar.png",
             "tiles": list(RAILCAR_TILES),
             "sprite": station_railcar_sprite(
                 RAILCAR_TILES, RAILCAR_DOOR_TILE, False),
             "whenOpen": "station_railcar_open.png",
             "openSprite": station_railcar_sprite(
                 RAILCAR_TILES, RAILCAR_DOOR_TILE, True)},
            {"glyph": "l", "image": "station_sign_etta.png",
             "tiles": list(STATION_SIGN_TILES),
             "sprite": station_sign("ETTA", broken=False)},
            {"glyph": "r", "image": "station_sign_molf.png",
             "tiles": list(STATION_SIGN_TILES),
             "sprite": station_sign("MOLF", broken=True)},
        ],
    }


# --------------------------------------------------------- the station's art
# The booking hall and its platform, the one place of the station that was
# still baked. It is the far platform's sister -- same slabs, same rails,
# same painters, which stay in tools/build_station.py -- with what the far
# platform has not: the hall, the rubble where the roof came down, the
# doorways onto the forecourt, the ticket windows, and the wrecked trains,
# which are objects: the railcar standing derailed across the near track, and
# the hijacked train -- its coach still on the far track, the car behind it
# lying wheels up across the platform and the hall.

STATION_RAILCAR_TILES = (16, 3)
STATION_COACH_TILES = (19, 3)
STATION_UPRIGHT_TILES = (17, 3)
STATION_OVERTURNED_TILES = (3, 12)
# The burning car runs on off the west edge of the map: only its east end,
# where it parted from the car still upright, is in the place.
STATION_BURNING_TILES = (4, 3)
STATION_BURNING_LENGTH = 12


def side_walls(atlas: Atlas) -> list:
    """The rule for a station room's side walls `|`: one unbroken strip of
    coping down each side, its lit edge towards the room. It is the east
    wall when the darkness outside the place is beside it on the east."""
    return [rule("structures", "|",
                 [atlas.bucket(lambda r=right: tile_of(
                     lambda d: station.paint_side_wall(d, 0, 0, r)), 1)
                  for right in (False, True)],
                 [neighbour_key(1, 0, "x")])]


def station_hall(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.station."""
    def platform(parity: int, edge: bool):
        return atlas.bucket(lambda p=parity, e=edge: cell(
            lambda d, gx, gy: station.paint_platform(
                d, rng, gx, gy, 0 if e else -1), p, 0))

    def hall(parity: int):
        return atlas.bucket(lambda p=parity: cell(
            lambda d, gx, gy: station.paint_hall(d, rng, gx, gy), p, 0))

    def randomly(paint):
        return [atlas.bucket(lambda: tile_of(
            lambda d: paint(d, rng, 0, 0)))]

    def ends(paint, glyph):
        """Four tiles: the two ends of a run, its middle, and a run of one.
        `paint` is given a neighbourhood that says which sides continue."""
        out = []
        for right in (False, True):
            for left in (False, True):
                out.append(atlas.bucket(lambda l=left, r=right: tile_of(
                    lambda d: paint(d, Neighbourhood(
                        glyph,
                        lambda x, y, l=l, r=r: glyph
                        if (x == -1 and l) or (x == 1 and r) else ".",
                    ), 0, 0)), 1))
        return out

    ballast = atlas.bucket(
        lambda: tile_of(lambda d: station.paint_ballast(d, rng, 0, 0)))
    rails = [
        atlas.bucket(lambda c=continuing: tile_of(
            lambda d: station.paint_rails(
                d, rng, Neighbourhood("-", lambda x, y: "-" if c else "."),
                0, 0)))
        for continuing in (False, True)
    ]
    wall = []
    for tagged in (False, True):
        for above in (False, True):
            wall.append(atlas.bucket(lambda a=above, g=tagged: cell(
                lambda d, gx, gy: station.paint_back_wall(
                    d, rng,
                    Neighbourhood("W", lambda x, y, a=a: "W" if a else "."),
                    gx, gy),
                0 if g else 1, 0)))

    rules = [
        # The ground, in the order the baker laid it: track, ballast, the
        # platform and its edge, and the booking hall's terrazzo elsewhere.
        # The track runs on off the west edge of the map.
        rule("ground", "-", rails, [neighbour_key(-1, 0, "-x")]),
        rule("ground", ",MmCVH", [ballast]),
        rule("ground", "?", [atlas.bucket(lambda: tile_of(
            lambda d: station.paint_scorched_ballast(d, rng, 0, 0)))]),
        rule("ground", "=TKn9",
             [platform(0, False), platform(1, False),
              platform(0, True), platform(1, True)],
             [parity_key(), first_row_key("=", 0, "eq")]),
        rule("ground", ":",
             [hall(0), hall(1), platform(0, False), platform(1, False)],
             [parity_key(), first_row_key("=", 2, "le")]),
        rule("ground", ".EObZ*+Up", [hall(0), hall(1)], [parity_key()]),
        rule("structures", "W", wall,
             [neighbour_key(0, -1, "W"), pattern_key(7, 5, 9)]),
        # The facade: an arched window on every sixth column, boarded or
        # not, its glass gone.
        rule("structures", "w",
             [atlas.bucket(lambda g=window: cell(
                 lambda d, gx, gy: station.paint_front_wall(d, rng, gx, gy),
                 0 if g else 1, 0)) for window in (False, True)],
             [pattern_key(5, 0, 6, 0)]),
        # The rubble: the heap, with a girder on a pattern of the position,
        # and a dark lip on each side that meets what can be walked on.
        rule("structures", "#",
             [atlas.bucket(lambda g=girder: cell(
                 lambda d, gx, gy: station.paint_rubble_heap(d, rng, gx, gy),
                 *((0, 0) if g else (1, 0))))
              for girder in (False, True)],
             [pattern_key(5, 3, 7, 0)]),
    ]
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        lip = atlas.bucket(lambda o=(dx, dy): tile_of(
            lambda d: station.paint_rubble_lip(d, Neighbourhood(
                "#", lambda x, y, o=o: "." if (x, y) == o else "#"), 0, 0)),
            1)
        rules.append(rule("structures", "#", [lip, []],
                          [neighbour_key(dx, dy, "#x")]))
    for glyph in "EO":
        rules.append(rule(
            "structures", glyph,
            [atlas.bucket(lambda f=first: tile_of(
                lambda d: station.paint_doorway(d, 0, 0, f)), 1)
             for first in (True, False)],
            [neighbour_key(-1, 0, glyph)]))
    rules += [
        rule("structures", ":", randomly(station.paint_litter)),
        rule("structures", "b", randomly(paint_blood)),
        rule("structures", "U", ends(station.paint_stairs, "U"),
             [neighbour_key(-1, 0, "U"), neighbour_key(1, 0, "U")]),
    ]
    tactile_keys = [
        neighbour_key(0, -1, "pOU"),
        neighbour_key(1, 0, "pOU"),
        neighbour_key(0, 1, "pOU"),
        neighbour_key(-1, 0, "pOU"),
    ]
    rules.append(rule(
        "structures", "p",
        [atlas.bucket(
            lambda connections=i: tile_of(lambda d: station.paint_tactile_path(
                d, connections, 0, 0)), 1)
         for i in range(16)],
        tactile_keys,
    ))
    rules += side_walls(atlas)
    rules.append(rule("foreground", "T", ends(station.paint_bench, "T"),
                      [neighbour_key(-1, 0, "T"), neighbour_key(1, 0, "T")]))
    rules.append(rule("foreground", "K", [atlas.bucket(lambda: tile_of(
        lambda d: station.paint_ticket_window(d, 0, 0)), 1)]))
    rules.append(rule("foreground", "n",
                      [atlas.bucket(lambda b=beam: tile_of(
                          lambda d: station.paint_post(d, Neighbourhood(
                              "n", lambda x, y, b=b: "n"
                              if (x == 1 and b) else "."), 0, 0)), 1)
                       for beam in (False, True)],
                      [neighbour_key(1, 0, "n")]))

    railcar = Image.new("RGBA", tuple(n * TILE for n in STATION_RAILCAR_TILES),
                        TRANSPARENT)
    station.paint_railcar(ImageDraw.Draw(railcar), rng,
                          (0, 0, railcar.width, railcar.height),
                          wrecked=True)
    coach = Image.new("RGBA", tuple(n * TILE for n in STATION_COACH_TILES),
                      TRANSPARENT)
    station.paint_railcar(ImageDraw.Draw(coach), rng,
                          (0, 0, coach.width, coach.height),
                          wrecked=False, with_cab=False)
    upright = Image.new("RGBA", tuple(n * TILE for n in STATION_UPRIGHT_TILES),
                        TRANSPARENT)
    station.paint_railcar(ImageDraw.Draw(upright), rng,
                          (0, 0, upright.width, upright.height),
                          wrecked=False, with_cab=False)
    overturned = Image.new(
        "RGBA", tuple(n * TILE for n in STATION_OVERTURNED_TILES),
        TRANSPARENT)
    station.paint_overturned_train(
        ImageDraw.Draw(overturned), rng,
        (0, 0, overturned.width, overturned.height))
    burning = Image.new(
        "RGBA", (STATION_BURNING_TILES[1] * TILE,
                 STATION_BURNING_LENGTH * TILE), TRANSPARENT)
    station.paint_overturned_train(
        ImageDraw.Draw(burning), rng, (0, 0, burning.width, burning.height),
        burnt=True)
    # Painted lying north-south like the other, then turned to lie along
    # the track, its shadow to the south, and cut to the end that shows:
    # the torn gangway, facing the car it parted from.
    burning = burning.transpose(Image.Transpose.ROTATE_270)
    burning = burning.crop((burning.width - STATION_BURNING_TILES[0] * TILE,
                            0, burning.width, burning.height))
    return {
        "void": "#000000",
        "voidGlyph": "x",
        "rules": rules,
        "objects": [
            {"glyph": "H", "image": "station_hall_burning.png",
             "tiles": list(STATION_BURNING_TILES), "sprite": burning},
            {"glyph": "C", "image": "station_hall_upright.png",
             "tiles": list(STATION_UPRIGHT_TILES), "sprite": upright},
            {"glyph": "M", "image": "station_hall_railcar.png",
             "tiles": list(STATION_RAILCAR_TILES), "sprite": railcar},
            {"glyph": "m", "image": "station_hall_coach.png",
             "tiles": list(STATION_COACH_TILES), "sprite": coach},
            {"glyph": "V", "image": "station_hall_overturned.png",
             "tiles": list(STATION_OVERTURNED_TILES), "sprite": overturned},
        ],
    }
