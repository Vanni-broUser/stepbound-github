"""The Duomo of Molfetta in the tile atlas: the nave with its saints and
great columns, the community's floor above it, Don Angelo's own room, the
bell tower with its flights and bells, the roof of the tower and the view
from it over the old town (lib/core/levels/hometown/duomo*.dart).

A module of its own, the way docs/level_pipeline.md wants the interiors
to go: build_tile_atlas.py only lists it. The art came from
tools/build_duomo.py and tools/build_duomo_upper.py, which the atlas
replaced.
"""
from __future__ import annotations

import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_airliner as airliner  # noqa: E402
from street_paint import (  # noqa: E402
    ASPHALT,
    ASPHALT_SPECKLE,
    LANE,
    TILE,
    rect,
    shade,
)
from tile_atlas_core import (  # noqa: E402
    Atlas,
    TRANSPARENT,
    cell,
    neighbour_key,
    paint_side_edge,
    parity_key,
    rule,
    spread,
    tile_of,
)
from tile_atlas_bar import (  # noqa: E402
    paint_backroom_crate,
)

# --------------------------------------------------- the upper Duomo's art
# Moved here from tools/build_duomo_upper.py, which this atlas replaces:
# the dining hall and dormitory above the Duomo, where the community lives.

LINEN = (174, 164, 146)
LINEN_LIGHT = (208, 198, 178)


def paint_table(d, px, py):
    rect(d, px, py + 3, TILE, 9, WOOD)
    rect(d, px, py + 3, TILE, 2, WOOD_LIGHT)
    rect(d, px + 2, py + 12, 3, 3, shade(WOOD, -22))
    rect(d, px + 11, py + 12, 3, 3, shade(WOOD, -22))


def paint_refectory_chair(d, px, py):
    rect(d, px + 3, py + 4, 10, 7, WOOD)
    rect(d, px + 4, py + 5, 8, 2, WOOD_LIGHT)
    rect(d, px + 4, py + 11, 2, 4, shade(WOOD, -20))
    rect(d, px + 10, py + 11, 2, 4, shade(WOOD, -20))


def paint_bed(d, px, py):
    rect(d, px + 1, py + 2, 14, 13, WOOD)
    rect(d, px + 2, py + 3, 12, 10, LINEN)
    rect(d, px + 2, py + 3, 12, 3, LINEN_LIGHT)
    rect(d, px + 3, py + 4, 10, 2, (222, 214, 196))
    rect(d, px + 2, py + 12, 12, 2, shade(LINEN, -24))


def paint_cupboard(d, px, py):
    rect(d, px + 2, py, 12, 16, shade(WOOD, -16))
    rect(d, px + 3, py + 1, 10, 14, WOOD)
    rect(d, px + 8, py + 1, 1, 14, shade(WOOD, -28))
    rect(d, px + 6, py + 8, 1, 1, GOLD)
    rect(d, px + 10, py + 8, 1, 1, GOLD)


def paint_stairs_down(d, px, py):
    rect(d, px, py, TILE, TILE, (34, 32, 34))
    for step in range(4):
        inset = step * 2
        rect(d, px + inset, py + 2 + step * 3, TILE - inset, 2,
             shade(STONE, -step * 14))


def paint_locked_door(d, px, py):
    """A shut door of planks with its iron lock. It stands two tiles high,
    so it is an object, not a tile. Nothing is painted on it to say it can
    be used: the game's white glint does that, as everywhere else."""
    top = py - TILE
    rect(d, px + 1, top, TILE - 2, TILE * 2, (24, 22, 22))
    rect(d, px + 3, top + 2, TILE - 6, TILE * 2 - 3, (72, 48, 34))
    rect(d, px + 4, top + 3, TILE - 8, 2, (108, 76, 50))
    for x in (6, 9):
        rect(d, px + x, top + 5, 1, TILE * 2 - 7, (56, 38, 28))
    rect(d, px + 3, top + 9, TILE - 6, 2, (54, 50, 50))
    rect(d, px + 3, py + 6, TILE - 6, 2, (54, 50, 50))
    rect(d, px + 4, py + 2, TILE - 8, 1, (44, 30, 24))
    rect(d, px + 10, py - 1, 3, 4, (60, 56, 56))
    rect(d, px + 11, py + 0, 1, 2, (20, 18, 18))


# ------------------------------------------------------- the Duomo's art
# Moved here from tools/build_duomo.py, which this atlas replaces: the
# three-nave interior of the harbour Duomo, and the masonry vocabulary the
# floor above shares with it.

DUOMO_FLOOR = (116, 106, 94)
DUOMO_FLOOR_ALT = (130, 120, 106)
DUOMO_JOINT = (76, 70, 66)
STONE = (178, 168, 148)
STONE_LIGHT = (210, 198, 170)
STONE_DARK = (112, 104, 94)
WOOD = (86, 56, 36)
WOOD_LIGHT = (128, 86, 52)
GOLD = (184, 146, 54)


def duomo_floor(d, rng, x, y):
    """Worn flagstones, two tones on the parity of x + y, gritty."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, DUOMO_FLOOR if (x + y) % 2 else DUOMO_FLOOR_ALT)
    rect(d, px, py, TILE, 1, DUOMO_JOINT)
    rect(d, px, py, 1, TILE, DUOMO_JOINT)
    for _ in range(3):
        rect(d, px + rng.randrange(15), py + rng.randrange(15), 1, 1,
             DUOMO_JOINT)


def duomo_wall(d, px, py, front=False):
    rect(d, px, py, TILE, TILE, STONE_DARK if front else STONE)
    rect(d, px, py, TILE, 2, shade(STONE, 24))
    rect(d, px, py + 8, TILE, 1, STONE_DARK)


def paint_altar(d, px, py):
    rect(d, px, py + 3, TILE, 12, STONE)
    rect(d, px, py + 3, TILE, 3, STONE_LIGHT)
    rect(d, px + 2, py + 6, TILE - 4, 6, (188, 176, 150))
    rect(d, px + 7, py, 2, 5, GOLD)


def paint_column(d, px, py):
    d.ellipse([px + 2, py, px + 13, py + 15], fill=STONE_DARK)
    d.ellipse([px + 3, py + 1, px + 12, py + 13], fill=STONE)
    rect(d, px + 5, py + 2, 3, 11, STONE_LIGHT)
    rect(d, px + 1, py + 13, 14, 3, STONE_DARK)


def paint_pew(d, px, py):
    rect(d, px, py + 4, TILE, 8, WOOD)
    rect(d, px, py + 4, TILE, 2, WOOD_LIGHT)
    rect(d, px + 1, py + 12, 3, 3, shade(WOOD, -20))
    rect(d, px + 12, py + 12, 3, 3, shade(WOOD, -20))


def paint_statue(d, px, py):
    rect(d, px + 3, py + 12, 10, 4, STONE_DARK)
    rect(d, px + 5, py + 5, 6, 8, STONE)
    d.ellipse([px + 5, py + 1, px + 10, py + 6], fill=STONE_LIGHT)
    rect(d, px + 3, py + 7, 3, 5, STONE)
    rect(d, px + 10, py + 7, 3, 5, STONE)


def paint_portal(d, px, py):
    rect(d, px, py, TILE, TILE, (26, 24, 26))
    rect(d, px + 3, py + 1, 10, TILE - 1, (186, 178, 160))
    rect(d, px + 5, py + 2, 6, TILE - 2, (220, 210, 188))
    rect(d, px, py, 3, TILE, WOOD)
    rect(d, px + 13, py, 3, TILE, WOOD)


# ------------------------------------------------ the nave's great pieces
# The columns and the statues of the nave stand on two tiles by two and
# rise one tile over the row behind them: each is one picture, painted
# whole from the top-left cell of its block and cut into the cells it
# covers (`spread`). The row behind is drawn over whoever stands in it.

MARBLE = (206, 198, 182)
MARBLE_LIGHT = (234, 228, 214)
MARBLE_SHADE = (164, 154, 138)
MARBLE_DARK = (116, 106, 94)
INK = (36, 30, 28)
SKIN = (222, 184, 150)
SKIN_SHADE = (184, 142, 112)
HALO = (222, 186, 84)


def outlined(paint, width, height):
    """A figure painted on its own layer with a one-pixel dark outline
    round it, so it reads against the stone behind."""
    from PIL import ImageFilter  # noqa: PLC0415

    layer = Image.new("RGBA", (width, height), TRANSPARENT)
    paint(ImageDraw.Draw(layer))
    alpha = layer.getchannel("A").filter(ImageFilter.MaxFilter(3))
    edge = Image.new("RGBA", (width, height), INK + (255,))
    edge.putalpha(alpha)
    edge.alpha_composite(layer)
    return edge


def paint_great_column(d, px, py):
    """A column two tiles wide: a square plinth on the two cells of its
    block, a fluted shaft rising out of it one tile over the row behind,
    and its capital."""
    def column(c):
        top = 0
        # The plinth: its top face, then its front.
        rect(c, 1, 36, 30, 4, MARBLE_LIGHT)
        rect(c, 1, 40, 30, 7, MARBLE_SHADE)
        rect(c, 1, 46, 30, 1, MARBLE_DARK)
        rect(c, 27, 36, 4, 11, MARBLE_DARK)
        # The base mouldings.
        rect(c, 4, 32, 24, 4, MARBLE)
        rect(c, 4, 32, 24, 1, MARBLE_LIGHT)
        rect(c, 5, 35, 22, 1, MARBLE_SHADE)
        # The shaft, lit from the left: flutes every third pixel.
        tones = [MARBLE_SHADE, MARBLE, MARBLE_LIGHT, MARBLE_LIGHT, MARBLE,
                 MARBLE, MARBLE, MARBLE, MARBLE, MARBLE_SHADE, MARBLE_SHADE,
                 MARBLE_SHADE, MARBLE_SHADE, MARBLE_DARK, MARBLE_SHADE,
                 MARBLE_DARK, MARBLE_DARK, MARBLE_DARK]
        for i, tone in enumerate(tones):
            if i % 3 == 2:
                tone = shade(tone, -18)
            rect(c, 7 + i, top + 10, 1, 22, tone)
        # The capital: necking, bell with its volutes, abacus.
        rect(c, 6, top + 8, 20, 2, MARBLE_DARK)
        rect(c, 4, top + 4, 24, 4, MARBLE)
        rect(c, 4, top + 4, 24, 1, MARBLE_LIGHT)
        for vx in (2, 25):
            rect(c, vx, top + 4, 5, 5, MARBLE_SHADE)
            rect(c, vx + 1, top + 5, 3, 3, MARBLE_LIGHT)
            rect(c, vx + 2, top + 6, 1, 1, MARBLE_DARK)
        rect(c, 1, top, 30, 4, MARBLE_LIGHT)
        rect(c, 1, top + 3, 30, 1, MARBLE_SHADE)
    image = outlined(column, 32, 48)
    d._image.alpha_composite(image, (px, py - TILE))


# The six saints of the nave, each painted in the colours churches give
# them, so they are told apart at a glance.

def _head(c, cx, y, hair=None, beard=None):
    rect(c, cx - 3, y, 6, 6, SKIN)
    rect(c, cx + 1, y + 1, 2, 5, SKIN_SHADE)
    rect(c, cx - 2, y + 2, 1, 1, INK)
    rect(c, cx + 1, y + 2, 1, 1, INK)
    if hair:
        rect(c, cx - 3, y - 1, 6, 2, hair)
        rect(c, cx - 4, y, 1, 4, hair)
        rect(c, cx + 3, y, 1, 4, hair)
    if beard:
        rect(c, cx - 3, y + 4, 6, 3, beard)
        rect(c, cx - 2, y + 7, 4, 1, beard)


def _halo(c, cx, y):
    c.ellipse([cx - 6, y - 4, cx + 5, y + 7], outline=HALO, width=1)


def _robe(c, cx, top, bottom, top_half, bottom_half, colour, dark):
    for y in range(top, bottom):
        half = top_half + (bottom_half - top_half) * (y - top) // max(
            1, bottom - top - 1)
        rect(c, cx - half, y, 2 * half, 1, colour)
        rect(c, cx + half - 2, y, 2, 1, dark)


def saint_madonna(c, cx):
    _halo(c, cx, 3)
    # The blue mantle over her head and down to her feet, the white of her
    # dress down the front, her hands joined.
    _robe(c, cx, 2, 31, 5, 10, (44, 72, 152), (30, 48, 108))
    _robe(c, cx, 12, 31, 2, 4, (232, 224, 208), (200, 190, 172))
    _head(c, cx, 4)
    rect(c, cx - 4, 3, 8, 1, (232, 224, 208))
    rect(c, cx - 2, 14, 4, 3, SKIN)
    rect(c, cx - 6, 29, 12, 2, (196, 170, 80))


def saint_peter(c, cx):
    _halo(c, cx, 3)
    _robe(c, cx, 10, 31, 5, 8, (54, 108, 70), (36, 76, 48))
    # The ochre mantle across him, the two keys held up in front.
    for y in range(12, 28):
        rect(c, cx - 7 + (y - 12) // 2, y, 7, 1, (198, 142, 52))
    _head(c, cx, 4, hair=(170, 168, 162), beard=(190, 188, 182))
    rect(c, cx + 2, 12, 2, 10, HALO)
    rect(c, cx + 1, 12, 4, 3, HALO)
    rect(c, cx + 4, 19, 2, 1, HALO)
    rect(c, cx - 1, 14, 2, 9, (196, 200, 208))
    rect(c, cx - 2, 14, 4, 3, (196, 200, 208))
    rect(c, cx - 3, 20, 2, 1, (196, 200, 208))


def saint_francis(c, cx):
    # The brown habit with its hood, the white cord, the arms held open
    # and a bird come to rest on one hand.
    _robe(c, cx, 10, 31, 5, 8, (112, 78, 48), (80, 54, 34))
    rect(c, cx - 5, 3, 10, 9, (96, 66, 40))
    _head(c, cx, 5, hair=(78, 56, 38))
    rect(c, cx - 1, 11, 2, 12, (230, 224, 208))
    rect(c, cx - 1, 19, 4, 1, (230, 224, 208))
    rect(c, cx - 12, 13, 7, 3, (112, 78, 48))
    rect(c, cx + 5, 13, 7, 3, (112, 78, 48))
    rect(c, cx - 14, 13, 2, 3, SKIN)
    rect(c, cx + 12, 13, 2, 3, SKIN)
    rect(c, cx + 11, 10, 4, 3, (96, 112, 132))
    rect(c, cx + 14, 11, 2, 1, (220, 160, 60))


def saint_conrad(c, cx):
    """Saint Conrad, the bishop Molfetta keeps in its cathedral: mitre,
    red cope with its gold band, the crozier."""
    _robe(c, cx, 12, 31, 3, 5, (234, 230, 220), (200, 196, 186))
    _robe(c, cx, 11, 29, 5, 10, (168, 30, 36), (120, 20, 26))
    rect(c, cx - 1, 11, 2, 18, HALO)
    _head(c, cx, 6, beard=(120, 110, 100))
    for y in range(0, 6):
        half = 1 + y // 2
        rect(c, cx - half - 1, y, 2 * half + 2, 1, (236, 232, 222))
    rect(c, cx - 3, 4, 6, 1, HALO)
    rect(c, cx, 0, 1, 6, HALO)
    rect(c, cx + 9, 2, 1, 29, HALO)
    rect(c, cx + 7, 1, 4, 1, HALO)
    rect(c, cx + 6, 2, 1, 3, HALO)
    rect(c, cx + 7, 4, 1, 1, HALO)


def saint_michael(c, cx):
    """Saint Michael: the wings spread, the armour, the red cloak, the
    sword raised and the devil under his feet."""
    wing = (228, 228, 222)
    for i in range(10):
        rect(c, cx - 5 - i, 3 + i // 2, 1, 14 - i, wing)
        rect(c, cx + 4 + i, 3 + i // 2, 1, 14 - i, wing)
    rect(c, cx - 14, 8, 2, 2, (180, 180, 176))
    rect(c, cx + 12, 8, 2, 2, (180, 180, 176))
    _robe(c, cx, 10, 27, 6, 9, (176, 36, 34), (126, 24, 24))
    rect(c, cx - 4, 10, 8, 8, (194, 200, 210))
    rect(c, cx - 4, 10, 8, 1, (232, 236, 242))
    rect(c, cx - 4, 17, 8, 1, (140, 146, 156))
    _head(c, cx, 4, hair=(214, 176, 90))
    rect(c, cx + 6, 0, 2, 11, (214, 220, 230))
    rect(c, cx + 4, 10, 6, 1, HALO)
    # The devil, flattened under him.
    rect(c, cx - 8, 27, 16, 4, (40, 26, 26))
    rect(c, cx - 8, 26, 2, 1, (150, 30, 24))
    rect(c, cx + 6, 26, 2, 1, (150, 30, 24))
    rect(c, cx - 6, 28, 1, 1, (230, 180, 60))


def saint_joseph(c, cx):
    """Saint Joseph, old and bearded, in purple and ochre, with his
    flowering lily."""
    _halo(c, cx, 3)
    _robe(c, cx, 10, 31, 5, 8, (96, 58, 118), (68, 40, 86))
    for y in range(10, 30):
        rect(c, cx + 1, y, 5 + (y - 10) // 5, 1, (176, 126, 58))
    _head(c, cx, 4, hair=(150, 146, 140), beard=(170, 166, 160))
    rect(c, cx - 6, 3, 1, 20, (62, 118, 52))
    for fx, fy in ((-8, 2), (-5, 3), (-7, 6), (-5, 8)):
        rect(c, cx + fx, fy, 3, 2, (244, 242, 232))
    rect(c, cx - 5, 15, 3, 3, SKIN)


SAINTS = {
    "M": saint_madonna, "K": saint_peter, "F": saint_francis,
    "V": saint_conrad, "Y": saint_michael, "G": saint_joseph,
}


def carved(figure):
    """The saint in bare grey stone: the colours they were painted in
    survive only as how light or dark each part of the stone is, stepped
    onto a few greys so the pixel art stays crisp."""
    greys = [(70, 70, 72), (104, 104, 106), (138, 138, 140), (170, 170, 170),
             (198, 198, 196), (226, 226, 222)]
    stone = figure.copy()
    pixels = stone.load()
    for y in range(stone.height):
        for x in range(stone.width):
            r, g, b, a = pixels[x, y]
            if a:
                light = (r * 299 + g * 587 + b * 114) // 1000
                pixels[x, y] = greys[min(len(greys) - 1,
                                         light * len(greys) // 240)] + (a,)
    return stone


def paint_saint(d, px, py, saint):
    """A statue two tiles by two: the saint, carved in grey stone, on a
    pedestal that fills the lower half of its block, the figure rising a
    tile over the row behind."""
    def statue(c):
        rect(c, 2, 30, 28, 4, MARBLE_LIGHT)
        rect(c, 2, 34, 28, 13, MARBLE_SHADE)
        rect(c, 26, 30, 4, 17, MARBLE_DARK)
        rect(c, 2, 46, 28, 1, MARBLE_DARK)
        rect(c, 9, 38, 14, 5, MARBLE_DARK)
        rect(c, 10, 39, 12, 3, MARBLE)
        figure = Image.new("RGBA", (32, 32), TRANSPARENT)
        saint(ImageDraw.Draw(figure), 16)
        c._image.alpha_composite(carved(figure), (0, 0))
    image = outlined(statue, 32, 48)
    d._image.alpha_composite(image, (px, py - TILE))


# --------------------------------------------------- the nave's masonry

WALL_CAP = (192, 182, 160)
WALL_CAP_LIGHT = (214, 204, 182)
WALL_JOINT = (160, 150, 130)
WALL_DROP = (70, 64, 58)


def paint_front_wall(d, px, py):
    """The top of the front wall, the same coping running east to west."""
    rect(d, px, py, TILE, TILE, WALL_CAP)
    rect(d, px, py + 5, TILE, 5, WALL_CAP_LIGHT)
    rect(d, px, py, TILE, 3, WALL_DROP)
    rect(d, px, py + TILE - 2, TILE, 2, STONE_DARK)
    rect(d, px + 11, py + 3, 1, TILE - 5, WALL_JOINT)


def paint_back_wall(d, px, py, upper):
    """The back wall's face, two courses of ashlar to a tile, joints
    staggered; a cornice along its top and a plinth along its foot."""
    rect(d, px, py, TILE, TILE, STONE)
    for course, joint in ((0, 0), (8, 8)):
        rect(d, px, py + course, TILE, 1, STONE_DARK)
        rect(d, px + joint, py + course, 1, 8, STONE_DARK)
        rect(d, px + joint + 1, py + course + 1, 6, 1, shade(STONE, 16))
    if upper:
        rect(d, px, py, TILE, 3, STONE_LIGHT)
        rect(d, px, py + 3, TILE, 1, STONE_DARK)
    else:
        rect(d, px, py + TILE - 3, TILE, 3, shade(STONE_DARK, -20))
        rect(d, px, py + TILE - 3, TILE, 1, STONE_DARK)


def paint_wall_shadow(d, px, py, side):
    """The shadow a wall throws on the floor at its foot."""
    shadow = (0, 0, 0, 70)
    if side == "left":
        rect(d, px, py, 3, TILE, shadow)
    elif side == "right":
        rect(d, px + TILE - 3, py, 3, TILE, shadow)
    else:
        rect(d, px, py, TILE, 4, shadow)


def duomo(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.duomo. The altar stands on no floor:
    the baker skips it, and so do we."""
    # `9`, `c` and `d` are where the mass ends: plain floor until then.
    floored = ".*:p123PTE9cd" + "".join(SAINTS)
    rules = duomo_masonry_rules(atlas, rng, floored,
                                unshaded="P" + "".join(SAINTS))
    for glyph, paint in {"T": paint_pew, "E": paint_portal,
                         "A": paint_altar}.items():
        rules.append(rule("structures", glyph, [atlas.bucket(
            lambda p=paint: tile_of(lambda d: p(d, 0, 0)), 1)]))
    # Each great piece is painted from the top-left cell of its block: the
    # one with none of its own glyph to the left or above.
    for glyph, paint in [("P", paint_great_column)] + [
            (g, lambda d, px, py, s=s: paint_saint(d, px, py, s))
            for g, s in SAINTS.items()]:
        keys = [neighbour_key(-1, 0, glyph), neighbour_key(0, -1, glyph)]
        buckets, pieces = spread(
            atlas,
            lambda i, p=paint: p if i == 0 else (lambda d, px, py: None),
            keys, reach=(0, 1, 1, 1), count=1)
        rules.append(rule("structures", glyph, buckets, keys, pieces))
    for right in (False, True):
        edge = atlas.bucket(lambda r=right: tile_of(
            lambda d: paint_side_edge(d, 0, 0, r)), 1)
        rules.append(rule("foreground", floored + "A", [[], edge],
                          [neighbour_key(1 if right else -1, 0, "x")]))
    # The door upstairs stands open: the cultist in front of it is what
    # keeps Mario out.
    return {"void": "#000000", "voidGlyph": "x", "rules": rules,
            "objects": [{"glyph": "U", "image": "duomo_nave_door.png",
                         "offsetY": -1, "sprite": stair_door(leaf=True)}]}


def paint_duomo_side(d, px, py, room_left, room_right, window=False,
                     end=False):
    """The top of a wall that runs north to south, seen from above: one
    long coping, its slabs butted end to end. On a side with the room below
    it the coping drops into the room; on a side with the dark outside it
    ends in a hard edge. A partition has the room on both sides. `end` is
    the south end of a stretch of partition, over a doorway: its face shows.
    `window` is a slit window cut through it, the daylight in the glass."""
    rect(d, px, py, TILE, TILE, WALL_CAP)
    rect(d, px + 5, py, 6, TILE, WALL_CAP_LIGHT)
    for room, x in ((room_left, px), (room_right, px + TILE - 3)):
        if room:
            rect(d, x, py, 3, TILE, WALL_DROP)
        else:
            rect(d, x + (0 if x == px else 1), py, 2, TILE, STONE_DARK)
    rect(d, px + 3, py + 11, TILE - 6, 1, WALL_JOINT)
    if window:
        rect(d, px + 5, py + 1, 6, 14, STONE_DARK)
        rect(d, px + 6, py + 2, 4, 12, (164, 184, 200))
        rect(d, px + 6, py + 2, 2, 12, (206, 220, 230))
    if end:
        rect(d, px, py + 9, TILE, 7, STONE)
        rect(d, px, py + 9, TILE, 1, STONE_LIGHT)
        rect(d, px + 7, py + 10, 1, 6, STONE_DARK)
        rect(d, px, py + 15, TILE, 1, STONE_DARK)


def paint_wall_crucifix(d, px, py):
    paint_back_wall(d, px, py, False)
    rect(d, px + 7, py + 1, 2, 12, shade(WOOD, -10))
    rect(d, px + 4, py + 4, 8, 2, shade(WOOD, -10))
    rect(d, px + 7, py + 5, 2, 5, (206, 188, 160))
    rect(d, px + 7, py + 1, 2, 1, GOLD)


def duomo_masonry_rules(atlas: Atlas, rng, floored: str,
                        unshaded: str = "") -> list[dict]:
    """The flagstones under `floored` and the walls round them, as every
    floor of the Duomo has them: the back wall's face, cornice on top and
    plinth at its foot; the side walls and partitions as one long coping
    seen from above, dropping into the room on the side it is on; the front
    wall's coping; and the shadow each throws on the floor at its foot,
    except under `unshaded`, the pieces painted whole from one cell."""
    floor = [
        atlas.bucket(lambda p=parity: cell(
            lambda dd, gx, gy: duomo_floor(dd, rng, gx, gy), p, 0))
        for parity in (0, 1)
    ]
    side_keys = [neighbour_key(-1, 0, "x"), neighbour_key(1, 0, "x"),
                 neighbour_key(0, 1, "d")]

    def sides(window):
        return [atlas.bucket(lambda i=index: tile_of(
            lambda d: paint_duomo_side(d, 0, 0, not i & 1, not i & 2,
                                       window, bool(i & 4))), 1)
                for index in range(8)]
    rules = [
        rule("ground", floored, floor, [parity_key()]),
        rule("structures", "W", [atlas.bucket(
            lambda u=upper: tile_of(lambda d: paint_back_wall(d, 0, 0, u)), 1)
            for upper in (False, True)], [neighbour_key(0, -1, "x")]),
        rule("structures", "X", [atlas.bucket(
            lambda: tile_of(lambda d: paint_wall_crucifix(d, 0, 0)), 1)]),
        rule("structures", "I", sides(False), side_keys),
        rule("structures", "o", sides(True), side_keys),
        rule("structures", "w", [atlas.bucket(
            lambda: tile_of(lambda d: paint_front_wall(d, 0, 0)), 1)]),
        rule("structures", "D", [atlas.bucket(
            lambda: tile_of(lambda d: paint_stairs_down(d, 0, 0)), 1)]),
    ]
    shaded = "".join(g for g in floored if g not in unshaded)
    for side, key in (("left", neighbour_key(-1, 0, "Io")),
                      ("right", neighbour_key(1, 0, "Io")),
                      ("top", neighbour_key(0, -1, "WXUL"))):
        rules.append(rule("structures", shaded, [[], atlas.bucket(
            lambda s=side: tile_of(
                lambda d: paint_wall_shadow(d, 0, 0, s)), 1)], [key]))
    return rules


# ------------------------------------------- the community's first floor
# The kitchen and the refectory west of the partition, the dormitory east
# of it.

def paint_long_table(d, rng, px, py, left, right, up, down):
    """One cell of a table that spans several: the planks run on from the
    cells beside it, and only its outer edges show a rim; along its front
    the apron and, at the corners, the legs. Bowls and bread lie about."""
    rect(d, px, py, TILE, TILE, WOOD)
    for sy in range(2, TILE, 4):
        rect(d, px, py + sy, TILE, 1, shade(WOOD, -12))
    if not up:
        rect(d, px, py, TILE, 2, WOOD_LIGHT)
    if not left:
        rect(d, px, py, 1, TILE, shade(WOOD, -30))
    if not right:
        rect(d, px + TILE - 1, py, 1, TILE, shade(WOOD, -30))
    if not down:
        rect(d, px, py + 10, TILE, 3, shade(WOOD, -26))
        rect(d, px, py + 13, TILE, 3, TRANSPARENT)
        if not left:
            rect(d, px + 1, py + 13, 2, 3, shade(WOOD, -34))
        if not right:
            rect(d, px + TILE - 3, py + 13, 2, 3, shade(WOOD, -34))
    what = rng.randrange(4)
    if what == 1:
        d.ellipse([px + 4, py + 3, px + 10, py + 8], fill=(214, 206, 188))
        d.ellipse([px + 5, py + 4, px + 9, py + 7], fill=(150, 96, 60))
    elif what == 2:
        rect(d, px + 5, py + 3, 6, 4, (196, 150, 92))
        rect(d, px + 6, py + 3, 4, 1, (220, 180, 120))
    elif what == 3:
        rect(d, px + 9, py + 2, 3, 5, (140, 150, 160))
        rect(d, px + 9, py + 2, 3, 1, (190, 198, 206))


def paint_chair_facing(d, px, py, facing):
    """A chair drawn up to a table from the side it stands on."""
    seat, back, leg = WOOD_LIGHT, shade(WOOD, -8), shade(WOOD, -28)
    if facing == "down":
        rect(d, px + 3, py + 1, 10, 5, back)
        rect(d, px + 4, py + 2, 8, 1, WOOD_LIGHT)
        rect(d, px + 3, py + 6, 10, 5, seat)
        rect(d, px + 3, py + 11, 2, 4, leg)
        rect(d, px + 11, py + 11, 2, 4, leg)
    elif facing == "up":
        rect(d, px + 3, py + 2, 10, 5, seat)
        rect(d, px + 3, py + 7, 10, 6, back)
        rect(d, px + 4, py + 8, 8, 1, WOOD_LIGHT)
        rect(d, px + 3, py + 13, 2, 2, leg)
        rect(d, px + 11, py + 13, 2, 2, leg)
    else:
        right = facing == "right"
        bx = px + 2 if right else px + 11
        rect(d, px + 3, py + 7, 10, 3, seat)
        rect(d, bx, py + 1, 3, 11, back)
        rect(d, bx + (1 if right else 1), py + 2, 1, 9, WOOD_LIGHT)
        rect(d, px + 3, py + 10, 2, 5, leg)
        rect(d, px + 11, py + 10, 2, 5, leg)


def paint_kitchen_counter(d, rng, px, py):
    """The kitchen counter: a stone top over wooden cupboards, with what
    is being cooked left on it."""
    rect(d, px, py, TILE, TILE, shade(WOOD, -10))
    rect(d, px, py, TILE, 6, STONE_LIGHT)
    rect(d, px, py + 6, TILE, 1, STONE_DARK)
    rect(d, px + 7, py + 7, 1, 8, shade(WOOD, -34))
    rect(d, px + 5, py + 10, 1, 1, GOLD)
    rect(d, px + 9, py + 10, 1, 1, GOLD)
    rect(d, px, py + 15, TILE, 1, (40, 30, 26))
    what = rng.randrange(4)
    if what == 1:
        rect(d, px + 3, py + 1, 5, 3, (120, 116, 112))
        rect(d, px + 4, py + 1, 3, 1, (170, 166, 160))
    elif what == 2:
        rect(d, px + 8, py + 1, 3, 4, (178, 120, 70))
    elif what == 3:
        rect(d, px + 2, py + 2, 7, 2, (196, 150, 92))


def paint_hearth(d, px, py, right):
    """The kitchen hearth, two cells wide: stone, the fire in it, the pot
    over the fire on the left and a pan on the right."""
    rect(d, px, py, TILE, TILE, STONE)
    rect(d, px, py, TILE, 2, STONE_LIGHT)
    rect(d, px, py + 15, TILE, 1, STONE_DARK)
    inner = px if right else px + 2
    rect(d, inner, py + 4, TILE - 2, 9, (30, 24, 22))
    for fx, colour in ((3, (200, 80, 30)), (7, (240, 160, 60)),
                       (11, (200, 80, 30))):
        rect(d, px + fx, py + 10, 3, 3, colour)
    if right:
        rect(d, px + 2, py + 6, 9, 2, (60, 60, 64))
        rect(d, px + 10, py + 6, 5, 1, (60, 60, 64))
    else:
        rect(d, px + 5, py + 4, 9, 6, (54, 52, 54))
        rect(d, px + 5, py + 4, 9, 1, (110, 108, 108))


def paint_sink(d, px, py):
    rect(d, px, py, TILE, TILE, shade(WOOD, -10))
    rect(d, px, py, TILE, 6, STONE_LIGHT)
    rect(d, px + 2, py + 1, 12, 4, STONE_DARK)
    rect(d, px + 3, py + 2, 10, 2, (110, 134, 150))
    rect(d, px + 7, py, 2, 2, (120, 120, 126))
    rect(d, px, py + 6, TILE, 1, STONE_DARK)
    rect(d, px + 7, py + 7, 1, 8, shade(WOOD, -34))
    rect(d, px, py + 15, TILE, 1, (40, 30, 26))


def paint_night_table(d, px, py):
    rect(d, px + 3, py + 5, 10, 10, shade(WOOD, -6))
    rect(d, px + 3, py + 5, 10, 2, WOOD_LIGHT)
    rect(d, px + 4, py + 9, 8, 1, shade(WOOD, -30))
    rect(d, px + 7, py + 11, 2, 1, GOLD)
    rect(d, px + 5, py + 2, 2, 4, (232, 226, 208))
    rect(d, px + 5, py + 1, 2, 1, (240, 190, 90))


def paint_dorm_bed(d, px, py, foot):
    """A bed of the dormitory, one cell wide and two long: the head with
    its pillow against the wall, the foot under a grey wool blanket."""
    blanket, fold = (112, 118, 126), (140, 146, 154)
    rect(d, px + 1, py, 14, TILE, WOOD)
    if foot:
        rect(d, px + 2, py, 12, 13, blanket)
        rect(d, px + 2, py + 11, 12, 1, shade(blanket, -20))
        rect(d, px + 1, py + 13, 14, 3, shade(WOOD, -18))
    else:
        rect(d, px + 1, py, 14, 2, shade(WOOD, -18))
        rect(d, px + 2, py + 2, 12, 14, LINEN)
        rect(d, px + 3, py + 3, 10, 5, (222, 214, 196))
        rect(d, px + 2, py + 11, 12, 5, blanket)
        rect(d, px + 2, py + 11, 12, 1, fold)


def paint_wardrobe(d, px, py):
    """A wardrobe, a cell wide and taller than a man: it rises a cell over
    the row behind it."""
    top = py - TILE
    rect(d, px + 1, top + 1, 14, 30, shade(WOOD, -10))
    rect(d, px + 1, top + 1, 14, 3, WOOD_LIGHT)
    rect(d, px + 2, top + 5, 5, 24, WOOD)
    rect(d, px + 9, top + 5, 5, 24, WOOD)
    rect(d, px + 7, top + 5, 2, 24, shade(WOOD, -34))
    rect(d, px + 6, top + 16, 1, 2, GOLD)
    rect(d, px + 9, top + 16, 1, 2, GOLD)
    rect(d, px + 1, top + 29, 14, 2, (40, 30, 26))


def duomo_upper(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.duomoUpper, and its door object."""
    rules = duomo_masonry_rules(atlas, rng, ".*RTCBKDdkFHnA")
    rules.append(rule(
        "structures", "T",
        [atlas.bucket(lambda i=index: tile_of(lambda d: paint_long_table(
            d, rng, 0, 0, bool(i & 1), bool(i & 2), bool(i & 4),
            bool(i & 8)))) for index in range(16)],
        [neighbour_key(-1, 0, "T"), neighbour_key(1, 0, "T"),
         neighbour_key(0, -1, "T"), neighbour_key(0, 1, "T")]))

    def facing(index):
        for bit, way in ((1, "down"), (2, "up"), (4, "right"), (8, "left")):
            if index & bit:
                return way
        return "down"
    rules.append(rule(
        "structures", "C",
        [atlas.bucket(lambda f=facing(index): tile_of(
            lambda d: paint_chair_facing(d, 0, 0, f)), 1)
         for index in range(16)],
        [neighbour_key(0, 1, "T"), neighbour_key(0, -1, "T"),
         neighbour_key(1, 0, "T"), neighbour_key(-1, 0, "T")]))
    rules.append(rule("structures", "k", [atlas.bucket(lambda: tile_of(
        lambda d: paint_kitchen_counter(d, rng, 0, 0)))]))
    rules.append(rule("structures", "F", [atlas.bucket(
        lambda r=right: tile_of(lambda d: paint_hearth(d, 0, 0, r)), 1)
        for right in (False, True)], [neighbour_key(-1, 0, "F")]))
    for glyph, paint in {"H": paint_sink, "K": paint_cupboard,
                         "n": paint_night_table,
                         "d": lambda d, px, py: rect(
                             d, px + 1, py, TILE - 2, 2, STONE_LIGHT)
                         }.items():
        rules.append(rule("structures", glyph, [atlas.bucket(
            lambda p=paint: tile_of(lambda d: p(d, 0, 0)), 1)]))
    rules.append(rule("structures", "B", [atlas.bucket(
        lambda f=foot: tile_of(lambda d: paint_dorm_bed(d, 0, 0, f)), 1)
        for foot in (False, True)], [neighbour_key(0, -1, "B")]))
    buckets, pieces = spread(atlas, lambda i: paint_wardrobe,
                             reach=(0, 1, 0, 0), count=1)
    rules.append(rule("structures", "A", buckets, pieces=pieces))
    door = Image.new("RGBA", (TILE, TILE * 2), TRANSPARENT)
    paint_locked_door(ImageDraw.Draw(door), 0, TILE)
    # Once the key has opened it, the stairs to the second floor show.
    return {
        "void": "#000000",
        "voidGlyph": "x",
        "rules": rules,
        "objects": [{"glyph": "L", "image": "duomo_upper_door.png",
                     "offsetY": -1, "sprite": door,
                     "whenOpen": "duomo_upper_door_open.png",
                     "openSprite": stair_door(leaf=True)}],
    }


# ------------------------------------------- the Duomo's doors and stairs
# Every way up inside the Duomo is a doorway in the back wall of the floor
# it leaves, two tiles high: the wall's lower course and the cell of the
# doorway itself, so they are objects. Inside it, in the dark, the stairs
# climb away. The ones Mario comes up by are the stairs `D` in the front
# wall of the next floor (`paint_stairs_down`).

STAIRWELL = (20, 18, 20)


def paint_stair_door(d, px, py, leaf=False):
    """A doorway two tiles high, (px, py) its top-left: an arch in a stone
    frame, and the steps going up into the dark behind it. With `leaf`, a
    wooden door stands open against its left jamb."""
    height = TILE * 2
    rect(d, px, py, TILE, height, STONE)
    rect(d, px, py, TILE, 2, shade(STONE, 24))
    rect(d, px + 1, py + 3, TILE - 2, height - 3, STONE_LIGHT)
    rect(d, px + 3, py + 7, TILE - 6, height - 7, STAIRWELL)
    rect(d, px + 4, py + 5, TILE - 8, 2, STAIRWELL)
    rect(d, px + 6, py + 4, TILE - 12, 1, STAIRWELL)
    # The steps: the lowest in the light from the room, the rest going
    # darker as they climb.
    for step in range(5):
        y = py + height - 3 - step * 4
        rect(d, px + 3, y, TILE - 6, 2, shade(STONE, -20 - step * 22))
        rect(d, px + 3, y + 2, TILE - 6, 1, shade(STAIRWELL, 6))
    if leaf:
        rect(d, px + 3, py + 8, 3, height - 9, WOOD)
        rect(d, px + 3, py + 8, 1, height - 9, WOOD_LIGHT)
        rect(d, px + 5, py + 18, 1, 2, GOLD)


def stair_door(leaf=False) -> Image.Image:
    door = Image.new("RGBA", (TILE, TILE * 2), TRANSPARENT)
    paint_stair_door(ImageDraw.Draw(door), 0, 0, leaf)
    return door


def paint_wall_window(d, px, py):
    """A narrow window in a side wall, the daylight through it."""
    duomo_wall(d, px, py)
    rect(d, px + 5, py + 2, 6, 12, STONE_DARK)
    rect(d, px + 6, py + 3, 4, 10, (164, 184, 200))
    rect(d, px + 6, py + 3, 4, 2, (206, 220, 230))


def paint_papers(d, rng, px, py):
    """Loose sheets on the flagstones."""
    for _ in range(3):
        x, y = px + rng.randrange(10), py + rng.randrange(11)
        rect(d, x, y, 5, 4, (214, 208, 190))
        rect(d, x + 1, y + 1, 3, 1, (140, 132, 120))


# ------------------------------------------------ Don Angelo's own room

PRIEST_RED = (112, 30, 34)
PRIEST_RED_LIGHT = (146, 48, 50)
BOOKS = [(116, 38, 36), (44, 64, 96), (58, 86, 52), (150, 120, 60),
         (90, 58, 40), (68, 40, 72)]


def paint_bookcase(d, rng, px, py):
    rect(d, px, py, TILE, TILE - 1, shade(WOOD, -24))
    for shelf in (1, 6, 11):
        x = px + 1
        while x < px + TILE - 2:
            width = rng.choice((1, 2, 2))
            tall = rng.randint(3, 4)
            rect(d, x, py + shelf + 4 - tall, width, tall, rng.choice(BOOKS))
            x += width + rng.choice((0, 0, 1))
        rect(d, px, py + shelf + 4, TILE, 1, WOOD_LIGHT)
    rect(d, px, py + TILE - 1, TILE, 1, (40, 30, 26))


def paint_kneeler(d, px, py):
    rect(d, px + 2, py + 2, 12, 4, WOOD)
    rect(d, px + 2, py + 2, 12, 1, WOOD_LIGHT)
    rect(d, px + 3, py + 6, 2, 7, shade(WOOD, -20))
    rect(d, px + 11, py + 6, 2, 7, shade(WOOD, -20))
    rect(d, px + 2, py + 11, 12, 3, PRIEST_RED)
    rect(d, px + 2, py + 11, 12, 1, PRIEST_RED_LIGHT)


def paint_priest_bed(d, px, py, foot):
    """His bed, one tile wide and two long: the head with its pillow, the
    foot under a red blanket."""
    rect(d, px + 1, py, 14, TILE, WOOD)
    if foot:
        rect(d, px + 2, py, 12, 13, PRIEST_RED)
        rect(d, px + 2, py + 10, 12, 1, shade(PRIEST_RED, -20))
        rect(d, px + 1, py + 13, 14, 3, shade(WOOD, -18))
    else:
        rect(d, px + 1, py, 14, 2, shade(WOOD, -18))
        rect(d, px + 2, py + 2, 12, 14, LINEN)
        rect(d, px + 3, py + 3, 10, 5, (222, 214, 196))
        rect(d, px + 2, py + 11, 12, 5, PRIEST_RED)
        rect(d, px + 2, py + 11, 12, 1, PRIEST_RED_LIGHT)


def paint_desk(d, px, py):
    paint_table(d, px, py)
    rect(d, px + 3, py + 4, 6, 4, (214, 208, 190))
    rect(d, px + 4, py + 5, 4, 1, (120, 112, 104))
    rect(d, px + 11, py + 3, 2, 4, (230, 224, 206))
    rect(d, px + 11, py + 2, 2, 1, (240, 200, 110))


def paint_rug(d, px, py, left, right, up, down):
    """The rug, gold-bordered on every side where it ends."""
    rect(d, px, py, TILE, TILE, PRIEST_RED)
    for x in range(px + (0 if left else 1), px + TILE, 4):
        rect(d, x + 1, py + 7, 2, 2, PRIEST_RED_LIGHT)
    if not left:
        rect(d, px, py, 2, TILE, GOLD)
    if not right:
        rect(d, px + TILE - 2, py, 2, TILE, GOLD)
    if not up:
        rect(d, px, py, TILE, 2, GOLD)
    if not down:
        rect(d, px, py + TILE - 2, TILE, 2, GOLD)


def duomo_second_floor(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.duomoSecondFloor: Don Angelo's room
    and the landing, and the doorway up the tower."""
    rules = duomo_masonry_rules(atlas, rng, ".*:rdDQNKBTCS")
    props = {
        "Q": None, "N": paint_kneeler, "K": paint_cupboard,
        "T": paint_desk, "C": paint_refectory_chair, "S": paint_statue,
        "d": lambda d, px, py: rect(d, px + 1, py, TILE - 2, 2, STONE_LIGHT),
    }
    rules.append(rule("structures", "Q", [atlas.bucket(lambda: tile_of(
        lambda d: paint_bookcase(d, rng, 0, 0)))]))
    for glyph, paint in props.items():
        if paint is not None:
            rules.append(rule("structures", glyph, [atlas.bucket(
                lambda p=paint: tile_of(lambda d: p(d, 0, 0)), 1)]))
    rules.append(rule("structures", "B", [atlas.bucket(
        lambda f=foot: tile_of(lambda d: paint_priest_bed(d, 0, 0, f)), 1)
        for foot in (False, True)], [neighbour_key(0, -1, "B")]))
    rules.append(rule(
        "structures", "r",
        [atlas.bucket(lambda i=index: tile_of(lambda d: paint_rug(
            d, 0, 0, bool(i & 1), bool(i & 2), bool(i & 4), bool(i & 8))), 1)
         for index in range(16)],
        [neighbour_key(-1, 0, "r"), neighbour_key(1, 0, "r"),
         neighbour_key(0, -1, "r"), neighbour_key(0, 1, "r")]))
    return {"void": "#000000", "voidGlyph": "x", "rules": rules,
            "objects": [{"glyph": "U", "image": "duomo_stair_arch.png",
                         "offsetY": -1, "sprite": stair_door()}]}


# ------------------------------------------------------ the bell tower

BRONZE = (150, 108, 52)
BRONZE_LIGHT = (196, 156, 84)
BRONZE_DARK = (92, 62, 30)


# The treads of a flight, from its foot (dimmest) to its head (lightest):
# the higher a step, the nearer the light of the doorway it climbs to.
FLIGHT_TREADS = [(150, 142, 128), (166, 158, 142), (182, 174, 158),
                 (198, 190, 174)]
FLIGHT_RISER = (70, 64, 60)
FLIGHT_KERB = (120, 112, 102)


# How many steps climb through one cell of a flight.
STEPS_PER_CELL = 4


def paint_flight_step(d, px, py, level, foot, head, left, right):
    """One cell of a broad stone flight climbing north, seen from above and
    a little in front: several narrow steps across it, each a pale tread
    with its nosing catching the light over a thin riser in shadow.
    `level` (0 for the cell at the foot, 3 at the head) and the place of a
    step within its cell lighten the treads as the flight climbs. A kerb
    runs down the flight's own sides only (`left`, `right`), so the cells
    of a row read as one wide flight; the foot is set off from the floor by
    a darker edge, and the head runs into the landing of the doorway."""
    pitch = TILE // STEPS_PER_CELL
    rect(d, px, py, TILE, TILE, FLIGHT_RISER)
    for step in range(STEPS_PER_CELL):
        climb = level * STEPS_PER_CELL + (STEPS_PER_CELL - 1 - step)
        lift = climb * 3
        tread = shade(FLIGHT_TREADS[0], lift - 6)
        sy = py + step * pitch
        rect(d, px, sy, TILE, pitch - 1, tread)
        rect(d, px, sy, TILE, 1, shade(tread, 24))
        rect(d, px, sy + pitch - 1, TILE, 1, shade(FLIGHT_RISER, -10))
    if left:
        rect(d, px, py, 3, TILE, FLIGHT_KERB)
        rect(d, px + 2, py, 1, TILE, shade(FLIGHT_KERB, -30))
    if right:
        rect(d, px + TILE - 3, py, 3, TILE, shade(FLIGHT_KERB, 18))
        rect(d, px + TILE - 3, py, 1, TILE, shade(FLIGHT_KERB, -20))
    if head:
        rect(d, px, py, TILE, 2, shade(FLIGHT_TREADS[3], 16))
    if foot:
        rect(d, px, py + TILE - 1, TILE, 1, (40, 36, 34))


def paint_railing(d, px, py, top, bottom):
    """The railing along a flight, seen from above: a wooden handrail on
    turned balusters, a newel post at either end, and the shadow it throws
    across the steps beside it."""
    shadow = (0, 0, 0, 60)
    rect(d, px + 11, py, 4, TILE, shadow)
    for by in (2, 6, 10, 14):
        rect(d, px + 8, py + by, 2, 2, shade(WOOD, -30))
        rect(d, px + 8, py + by, 1, 1, shade(WOOD, 10))
    rect(d, px + 5, py, 4, TILE, shade(WOOD, -12))
    rect(d, px + 5, py, 1, TILE, WOOD_LIGHT)
    rect(d, px + 8, py, 1, TILE, shade(WOOD, -34))
    for end, y in ((top, py + 1), (bottom, py + TILE - 7)):
        if end:
            rect(d, px + 3, y, 8, 6, shade(WOOD, -20))
            rect(d, px + 4, y + 1, 6, 4, WOOD)
            rect(d, px + 4, y + 1, 6, 1, WOOD_LIGHT)
            rect(d, px + 6, y + 2, 2, 2, GOLD)


def bell() -> Image.Image:
    """The bell, two tiles by two, hung from its beam."""
    size = TILE * 2
    image = Image.new("RGBA", (size, size), TRANSPARENT)
    d = ImageDraw.Draw(image)
    rect(d, 0, 2, size, 4, WOOD)
    rect(d, 0, 2, size, 1, WOOD_LIGHT)
    rect(d, 14, 5, 4, 3, shade(WOOD, -20))
    for y in range(8, 27):
        half = 5 + (y - 8) * 9 // 18
        rect(d, 16 - half, y, 2 * half, 1, BRONZE)
        rect(d, 16 - half, y, 2, 1, BRONZE_DARK)
        rect(d, 16 - half + 3, y, 2, 1, BRONZE_LIGHT)
        rect(d, 16 + half - 3, y, 3, 1, BRONZE_DARK)
    rect(d, 1, 26, size - 2, 3, BRONZE_DARK)
    rect(d, 2, 26, size - 4, 1, BRONZE_LIGHT)
    rect(d, 14, 29, 4, 3, (58, 50, 44))
    return image


def duomo_tower(atlas: Atlas, rng) -> dict:
    """The rules that paint either flight of the bell tower."""
    rules = duomo_masonry_rules(atlas, rng, ".*:s|KO")
    rules += [
        # How far a step is from the foot of its flight, from the steps
        # below it; whether it is the first or the last; and whether it is
        # at the left or the right end of its row of steps.
        rule("structures", "s", [atlas.bucket(
            lambda i=index: tile_of(lambda d: paint_flight_step(
                d, 0, 0, 3 - min(3, (i & 1) + (i >> 1 & 1) + (i >> 2 & 1)),
                not i & 1, not i & 8, not i & 16, not i & 32)), 1)
            for index in range(64)],
            [neighbour_key(0, 1, "s"), neighbour_key(0, 2, "s"),
             neighbour_key(0, 3, "s"), neighbour_key(0, -1, "s"),
             neighbour_key(-1, 0, "s"), neighbour_key(1, 0, "s")]),
        rule("structures", "|", [atlas.bucket(
            lambda i=index: tile_of(lambda d: paint_railing(
                d, 0, 0, not i & 1, not i & 2)), 1) for index in range(4)],
            [neighbour_key(0, -1, "|"), neighbour_key(0, 1, "|")]),
        rule("structures", "K", [atlas.bucket(
            lambda: tile_of(lambda d: paint_backroom_crate(d, 0, 0)), 1)]),
    ]
    return {"void": "#000000", "voidGlyph": "x", "rules": rules,
            "objects": [{"glyph": "U", "image": "duomo_stair_arch.png",
                         "offsetY": -1, "sprite": stair_door()}]}


def duomo_bells(atlas: Atlas, rng) -> dict:
    """The rules that paint the bell chamber, and its bell."""
    place = duomo_tower(atlas, rng)
    place["objects"].append({"glyph": "O", "image": "duomo_bell.png",
                             "tiles": [2, 2], "sprite": bell()})
    return place


# ------------------------------------------------ the top of the tower

TOWER_SLAB = (190, 180, 158)
TOWER_SLAB_ALT = (178, 168, 146)
TOWER_JOINT = (140, 130, 112)
NAVE_TILE = (86, 50, 38)
NAVE_TILE_LIGHT = (104, 62, 46)
NAVE_TILE_DARK = (56, 32, 26)


def paint_tower_slab(d, rng, x, y):
    """The stone the tower is roofed with, two tones on the parity of
    x + y, weathered."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, TOWER_SLAB if (x + y) % 2 else TOWER_SLAB_ALT)
    rect(d, px, py, TILE, 1, TOWER_JOINT)
    rect(d, px, py, 1, TILE, TOWER_JOINT)
    for _ in range(3):
        rect(d, px + rng.randrange(15), py + rng.randrange(15), 1, 1,
             TOWER_JOINT)


def paint_tower_parapet(d, px, py, low=False):
    """The parapet round the top, a block of stone seen from above; `low`
    is the stretch knocked down to a course, where Mario leans over."""
    rect(d, px, py, TILE, TILE, STONE_DARK)
    top = 5 if low else 1
    rect(d, px + 1, py + top, TILE - 2, TILE - top - 4, STONE)
    rect(d, px + 1, py + top, TILE - 2, 2, STONE_LIGHT)
    rect(d, px, py + TILE - 3, TILE, 3, (58, 54, 50))
    if low:
        rect(d, px + 1, py + 1, TILE - 2, 4, TOWER_SLAB_ALT)
        for dx in (2, 7, 12):
            rect(d, px + dx, py + top - 1, 2, 1, STONE_DARK)


def paint_lightning_rod(d, px, py):
    rect(d, px + 4, py + 12, 8, 3, STONE_DARK)
    rect(d, px + 7, py + 2, 2, 11, (84, 86, 92))
    rect(d, px + 7, py + 2, 1, 11, (150, 152, 158))
    rect(d, px + 6, py, 4, 3, (150, 152, 158))


def paint_hatch(d, px, py):
    """The hatch the stairs come up through, its lid thrown back north."""
    rect(d, px + 1, py, 14, 5, WOOD)
    rect(d, px + 1, py, 14, 1, WOOD_LIGHT)
    rect(d, px + 5, py + 1, 1, 4, shade(WOOD, -20))
    rect(d, px + 10, py + 1, 1, 4, shade(WOOD, -20))
    rect(d, px + 1, py + 5, 14, 11, STONE_DARK)
    rect(d, px + 3, py + 6, 10, 9, STAIRWELL)
    for step in range(3):
        rect(d, px + 3, py + 13 - step * 3, 10, 1,
             shade(STONE, -30 - step * 24))


def paint_nave_roof(d, x, y):
    """The roof of the nave, a long way below the tower: rows of clay
    tiles, dim with the distance."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, NAVE_TILE)
    for row in range(4):
        sy = py + row * 4
        rect(d, px, sy, TILE, 1, NAVE_TILE_DARK)
        for sx in range(px + (2 if (y * 4 + row) % 2 else 0), px + TILE, 4):
            rect(d, sx, sy + 1, 1, 3, NAVE_TILE_DARK)
            rect(d, sx + 1, sy + 1, 1, 2, NAVE_TILE_LIGHT)


def duomo_tower_roof(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.duomoTowerRoof."""
    slab = [atlas.bucket(lambda p=parity: cell(
        lambda d, gx, gy: paint_tower_slab(d, rng, gx, gy), p, 0))
        for parity in (0, 1)]
    nave = atlas.bucket(lambda: cell(
        lambda d, gx, gy: paint_nave_roof(d, gx, gy)), 1)
    rules = [
        rule("ground", ".:9Dn", slab, [parity_key()]),
        rule("structures", "=", [nave]),
        rule("structures", "^", [atlas.bucket(
            lambda: tile_of(lambda d: paint_tower_parapet(d, 0, 0)), 1)]),
        rule("structures", ">", [atlas.bucket(lambda: tile_of(
            lambda d: paint_tower_parapet(d, 0, 0, low=True)), 1)]),
        rule("structures", "n", [atlas.bucket(
            lambda: tile_of(lambda d: paint_lightning_rod(d, 0, 0)), 1)]),
        rule("structures", "D", [atlas.bucket(
            lambda: tile_of(lambda d: paint_hatch(d, 0, 0)), 1)]),
        rule("structures", ":", [atlas.bucket(lambda: tile_of(
            lambda d: airliner.roof_rubble(d, rng, 0, 0)))]),
    ]
    return {"void": "#000000", "voidGlyph": "x", "rules": rules,
            "objects": [duomo_tower_roof_view(rng)]}

# ------------------------------------------- the view from the bell tower
# Everything round the two tower tops is one picture: the Duomo of Molfetta
# seen from its own bell tower. After the real church (San Corrado, on the
# harbour): the central nave roofed by three pyramid domes in a row on
# hexagonal drums, the middle one the tallest, their stone slabs laid in
# diamonds that close on the apex; the aisles under single slopes of grey
# limestone slabs (chiancarelle); the two square towers of pale limestone
# at the east end, either side of the apse, over the seafront; and round it
# the white flat roofs of the old town.

SLAB = (176, 170, 158)
SLAB_LIGHT = (206, 200, 186)
SLAB_DARK = (124, 118, 108)
LIMESTONE = (216, 206, 184)
LIMESTONE_DARK = (168, 156, 134)
WHITEWASH = (238, 234, 224)
WHITEWASH_SHADE = (196, 190, 178)
ALLEY = (86, 82, 78)
PAVING = (198, 192, 178)
SEA = (40, 84, 112)
SEA_LIGHT = (84, 136, 160)


def _shadow(image, polygon, alpha=70):
    layer = Image.new("RGBA", image.size, TRANSPARENT)
    ImageDraw.Draw(layer).polygon(polygon, fill=(20, 18, 24, alpha))
    image.alpha_composite(layer)


def _slab_roof(d, rng, x0, y0, x1, y1, base, vertical):
    """A roof of limestone slabs in courses, lit by how `base` is set."""
    rect(d, x0, y0, x1 - x0, y1 - y0, base)
    if vertical:
        for x in range(x0, x1, 5):
            rect(d, x, y0, 1, y1 - y0, shade(base, -18))
            for y in range(y0 + rng.randrange(4), y1, 7):
                rect(d, x + 1, y, 4, 1, shade(base, -10))
    else:
        for y in range(y0, y1, 4):
            rect(d, x0, y, x1 - x0, 1, shade(base, -16))
            for x in range(x0 + (y // 4 % 2) * 3, x1, 6):
                rect(d, x, y + 1, 1, 3, shade(base, -10))


def _dome(image, cx, cy, radius, height):
    """A pyramid dome on its hexagonal drum, lit from the north-west."""
    import math  # noqa: PLC0415

    d = ImageDraw.Draw(image)
    drum = [(cx + (radius + 4) * math.cos(math.radians(a)),
             cy + (radius + 4) * math.sin(math.radians(a)) * 0.8)
            for a in range(0, 360, 60)]
    _shadow(image, [(x + height * 0.8, y + height * 0.5) for x, y in drum],
            80)
    front = [(x, y + 7) for x, y in drum]
    d.polygon(front, fill=LIMESTONE_DARK)
    d.polygon(drum, fill=LIMESTONE)
    base = [(cx + radius * math.cos(math.radians(a)),
             cy + radius * math.sin(math.radians(a)) * 0.8)
            for a in range(0, 360, 60)]
    apex = (cx, cy - height)
    for i in range(6):
        a, b = base[i], base[(i + 1) % 6]
        mid = math.radians(i * 60 + 30)
        light = 0.5 + 0.5 * math.cos(mid - math.radians(225))
        tone = tuple(int(SLAB_DARK[k] + (SLAB_LIGHT[k] - SLAB_DARK[k]) * light)
                     for k in range(3))
        d.polygon([a, b, apex], fill=tone)
        # The slabs, in courses that close on the apex.
        for t in (0.25, 0.5, 0.75):
            pa = (a[0] + (apex[0] - a[0]) * t, a[1] + (apex[1] - a[1]) * t)
            pb = (b[0] + (apex[0] - b[0]) * t, b[1] + (apex[1] - b[1]) * t)
            d.line([pa, pb], fill=shade(tone, -22), width=1)
        d.line([a, apex], fill=shade(tone, -40), width=1)
    d.ellipse([cx - 2, cy - height - 3, cx + 2, cy - height + 1],
              fill=SLAB_DARK)


def _old_town(d, rng, x0, y0, x1, y1):
    """Blocks of white houses with flat terraces, alleys between them."""
    y = y0
    while y < y1:
        depth = rng.randint(34, 58)
        x = x0
        while x < x1:
            width = rng.randint(30, 56)
            right = min(x + width, x1)
            bottom = min(y + depth, y1)
            if right - x > 10 and bottom - y > 12:
                white = shade(WHITEWASH, -rng.randrange(0, 14))
                rect(d, x, y, right - x, bottom - y - 6, white)
                rect(d, x, bottom - 6, right - x, 6, WHITEWASH_SHADE)
                for wx in range(x + 4, right - 4, 9):
                    rect(d, wx, bottom - 5, 3, 3, (70, 96, 70))
                rect(d, x, y, right - x, 2, shade(white, 10))
                rect(d, x, y, 2, bottom - y - 6, shade(white, 6))
                rect(d, right - 2, y, 2, bottom - y - 6, shade(white, -16))
                what = rng.randrange(5)
                tx = rng.randint(x + 4, max(x + 4, right - 12))
                ty = rng.randint(y + 4, max(y + 4, bottom - 18))
                if what == 0:
                    d.ellipse([tx, ty, tx + 8, ty + 8], fill=(150, 150, 154))
                    d.ellipse([tx + 1, ty + 1, tx + 7, ty + 5],
                              fill=(186, 186, 190))
                elif what == 1:
                    rect(d, tx, ty, 10, 8, WHITEWASH_SHADE)
                    rect(d, tx, ty, 10, 2, shade(WHITEWASH, 6))
                    rect(d, tx + 3, ty + 4, 4, 4, (90, 70, 56))
                elif what == 2:
                    for lx in range(tx, min(tx + 20, right - 2), 3):
                        rect(d, lx, ty + 2, 2, 3, rng.choice(
                            [(190, 60, 60), (70, 110, 170), (240, 240, 236),
                             (220, 190, 80)]))
                    rect(d, tx, ty + 1, min(20, right - 2 - tx), 1,
                         (120, 120, 120))
                elif what == 3:
                    rect(d, tx, ty, 4, 6, (170, 160, 150))
                    rect(d, tx, ty, 4, 2, (90, 84, 80))
            x = right + rng.randint(3, 5)
        y += depth + rng.randint(3, 5)


def paint_tower_view(rows, rng) -> Image.Image:
    width, height = len(rows[0]) * TILE, len(rows) * TILE
    image = Image.new("RGBA", (width, height), ALLEY + (255,))
    d = ImageDraw.Draw(image)
    towers = []
    for left in range(len(rows[0])):
        for top in range(len(rows)):
            if rows[top][left] == "^" and (left == 0 or rows[top][left - 1]
                                           != "^") and (
                    top == 0 or rows[top - 1][left] != "^"):
                right = left
                while right + 1 < len(rows[0]) and rows[top][right + 1] in \
                        "^>":
                    right += 1
                bottom = top
                while bottom + 1 < len(rows) and rows[bottom + 1][left] == "^":
                    bottom += 1
                if right - left > 2 and bottom - top > 2:
                    towers.append((left * TILE, top * TILE,
                                   (right + 1) * TILE, (bottom + 1) * TILE))
    towers.sort()
    (ax0, ay0, ax1, ay1), (bx0, _, bx1, by1) = towers[0], towers[-1]
    # South of the church it is the harbour map, as it runs there: the
    # sagrato in front of the towers, a row of palazzi with the alley and
    # its gate, the seafront road between its two sidewalks, the promenade
    # and its palms, the parapet, and only then the sea.
    front = ay1 + 30         # where the sagrato begins
    church_x0, church_x1 = ax0, bx1
    ridge = (bx0 + ax1) // 2
    palazzi = front + 36     # the row of palazzi across the sagrato
    kerb = palazzi + 54      # the sidewalk of the seafront road
    road = kerb + 12         # the road itself
    promenade = road + 60    # the far sidewalk, then the promenade
    quay = promenade + 40    # the parapet, and the sea past it

    rect(d, 0, quay, width, height - quay, SEA)
    for _ in range(40):
        wx, wy = rng.randrange(width), rng.randrange(quay + 6, height)
        rect(d, wx, wy, rng.randint(3, 8), 1, SEA_LIGHT)
    for bx, hull in ((70, (236, 236, 230)), (width - 120, (70, 110, 170))):
        by = quay + 14
        d.polygon([(bx, by), (bx + 26, by), (bx + 22, by + 8),
                   (bx + 4, by + 8)], fill=hull)
        rect(d, bx + 8, by - 5, 9, 5, (200, 180, 140))
        rect(d, bx + 2, by + 8, 22, 1, (30, 60, 80))
    rect(d, 0, quay - 5, width, 5, LIMESTONE_DARK)  # the parapet
    rect(d, 0, quay - 5, width, 1, LIMESTONE)
    for top_, bottom_ in ((kerb, road), (promenade, quay - 5)):
        rect(d, 0, top_, width, bottom_ - top_, PAVING)
        for x in range(0, width, 12):
            rect(d, x, top_, 1, bottom_ - top_, shade(PAVING, -14))
        for y in range(top_ + 8, bottom_, 8):
            rect(d, 0, y, width, 1, shade(PAVING, -10))
        rect(d, 0, bottom_ - 2, width, 2, shade(PAVING, -30))  # the kerb
    rect(d, 0, road, width, promenade - road, ASPHALT)
    for _ in range(width // 3):
        rect(d, rng.randrange(width), rng.randrange(road, promenade), 1, 1,
             ASPHALT_SPECKLE)
    middle = (road + promenade) // 2
    for x in range(4, width, 24):  # the dashed line down its middle
        rect(d, x, middle - 1, 12, 2, LANE)
    for px in range(40, width - 20, 96):  # palms along the promenade
        rect(d, px, promenade + 8, 3, 14, (110, 84, 56))
        d.ellipse([px - 9, promenade + 1, px + 12, promenade + 13],
                  fill=(60, 96, 52))
        d.ellipse([px - 5, promenade + 3, px + 8, promenade + 10],
                  fill=(84, 124, 66))

    # The old town either side of the church and north of it, down to the
    # seafront road; the sagrato in front of the towers, and across it the
    # palazzi, split by the alley with the churchyard gate at its top.
    _old_town(d, rng, 0, 0, church_x0 - 10, kerb - 4)
    _old_town(d, rng, church_x1 + 10, 0, width, kerb - 4)
    rect(d, church_x0 - 10, 0, church_x1 - church_x0 + 20, 26, PAVING)
    rect(d, church_x0 - 10, front, church_x1 - church_x0 + 20,
         palazzi - front, PAVING)
    for x in range(church_x0 - 10, church_x1 + 10, 12):
        rect(d, x, front, 1, palazzi - front, shade(PAVING, -14))
    _old_town(d, rng, church_x0 - 10, palazzi, ridge - 12, kerb - 4)
    _old_town(d, rng, ridge + 12, palazzi, church_x1 + 10, kerb - 4)
    rect(d, ridge - 12, palazzi - 2, 24, kerb - palazzi + 2, PAVING)
    for y in range(palazzi + 4, kerb, 8):
        rect(d, ridge - 12, y, 24, 1, shade(PAVING, -12))
    for x in range(ridge - 12, ridge + 12, 4):  # the gate's railings
        rect(d, x, palazzi - 2, 1, 7, (40, 34, 30))
    rect(d, ridge - 12, palazzi - 2, 24, 1, (40, 34, 30))

    # The church: the aisles under their single slopes, the nave between
    # the towers under its ridge, the east end between the towers.
    top = 26
    nave_x0, nave_x1 = ax1, bx0
    _slab_roof(d, rng, church_x0, top, nave_x0, ay0, SLAB_LIGHT, False)
    _slab_roof(d, rng, nave_x1, top, church_x1, by1 - (ay1 - ay0),
               SLAB, False)
    rect(d, church_x0, top, 3, ay0 - top, SLAB_DARK)
    rect(d, church_x1 - 3, top, 3, ay0 - top, SLAB_DARK)
    _slab_roof(d, rng, nave_x0, top, ridge, ay1 - 20, SLAB_LIGHT, True)
    _slab_roof(d, rng, ridge, top, nave_x1, ay1 - 20, SLAB_DARK, True)
    rect(d, ridge - 1, top, 3, ay1 - 20 - top, LIMESTONE)
    rect(d, church_x0, top - 6, church_x1 - church_x0, 6, LIMESTONE_DARK)
    rect(d, church_x0, top - 6, church_x1 - church_x0, 2, LIMESTONE)
    # The apse, its half round of slabs and its wall down to the seafront.
    apse_y = ay1 - 20
    d.pieslice([nave_x0 + 6, apse_y - 28, nave_x1 - 6, apse_y + 28], 0, 180,
               fill=SLAB)
    for r in range(8, 34, 6):
        d.arc([ridge - r * 1.5, apse_y - r, ridge + r * 1.5, apse_y + r],
              0, 180, fill=SLAB_DARK)
    rect(d, nave_x0 + 6, apse_y + 28, nave_x1 - nave_x0 - 12, front - apse_y
         - 28, LIMESTONE)
    rect(d, ridge - 2, apse_y + 34, 4, 10, (40, 34, 30))

    # The domes, east to west, the middle one the tallest.
    span = (ay0 - top) // 3
    for i, (radius, lift) in enumerate(((24, 20), (32, 30), (24, 20))):
        cy = top + span * i + span // 2 + 6
        _dome(image, ridge, cy, radius, lift)

    # The two towers: their tops are the tiles, cut out of the picture;
    # below each, its south face falling to the seafront, and its shadow
    # thrown south-east over what is beside it.
    for x0, y0, x1, y1 in ((ax0, ay0, ax1, ay1), (bx0, ay0, bx1, by1)):
        _shadow(image, [(x1, y0 + 10), (x1 + 44, y0 + 34), (x1 + 44, y1 + 30),
                        (x1, y1)], 60)
        rect(d, x0, y1, x1 - x0, front + 18 - y1, LIMESTONE)
        for y in range(y1 + 5, front + 18, 6):
            rect(d, x0, y, x1 - x0, 1, LIMESTONE_DARK)
        rect(d, x1 - 10, y1, 10, front + 18 - y1, LIMESTONE_DARK)
        cx = (x0 + x1) // 2
        rect(d, cx - 2, y1 + 8, 4, 12, (40, 34, 30))
        rect(d, x0, front + 16, x1 - x0, 2, (70, 64, 58))
        rect(d, x0 - 2, y0 - 2, x1 - x0 + 4, y1 - y0 + 4, (40, 34, 30))
    pixels = image.load()
    for x0, y0, x1, y1 in towers:
        for y in range(y0, y1):
            for x in range(x0, x1):
                pixels[x, y] = TRANSPARENT
    return image


def duomo_tower_roof_view(rng) -> dict:
    """The picture round the tower tops, as a placed object over the rows
    it was painted for."""
    from street_paint import read_rows  # noqa: PLC0415

    rows = read_rows("duomo-roof-rows")
    return {"at": [0, 0], "image": "duomo_tower_view.png",
            "sprite": paint_tower_view(rows, rng), "under": rows}
