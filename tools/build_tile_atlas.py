#!/usr/bin/env python3
"""Bake the tile atlas the game paints converted places from.

A place used to exist twice: as the ASCII rows the simulation reads and as
a PNG painted from those rows by a baker. A converted place has no PNG:
the renderer paints it at runtime from the same rows, one tile per glyph,
out of assets/tiles/atlas.png.

This is where the bakers' *art* goes on living once their *composition*
dies. A baker knew two things: how to paint a bench, and where the benches
are. The second is in the ASCII rows and belongs to the game; only the
first is here. The rows are never read by this script: it paints tiles,
not places.

    python tools/build_tile_atlas.py            repaint the atlas
    python tools/build_tile_atlas.py --check    fail if it is out of date
    python tools/build_tile_atlas.py --preview  draw the places for the eye

What the manifest says, per place, is a list of ordered rules: for the
glyphs of this rule, on this layer, take a tile out of this bucket. The
bucket is chosen by a handful of boolean keys (the parity of the cell, the
row, a neighbour), and the tile inside it by a hash of the position, so
the grit falls the same way at every start and nothing has to be saved.
Objects too big for a cell -- the railcar, a two-tile door -- are their
own images, anchored to the glyph that names them.
"""
from __future__ import annotations

import argparse
import json
import os
import random
import sys
import tempfile

from PIL import Image, ImageChops, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_duomo import (  # noqa: E402
    GOLD,
    STONE,
    STONE_LIGHT,
    WOOD,
    WOOD_LIGHT,
    paint_floor as duomo_floor,
    paint_wall as duomo_wall,
)
from build_street_level import TILE, rect, shade  # noqa: E402
import build_station as station  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILES = os.path.join("assets", "tiles")
ATLAS = os.path.join(TILES, "atlas.png")
MANIFEST = os.path.join(TILES, "atlas_manifest.json")
OBJECTS = os.path.join(TILES, "objects")

# How many times the same kind of tile is painted with fresh grit. The
# renderer picks between them with a hash of the tile's position: enough
# that no eye finds the repeat, few enough that the atlas stays small.
VARIANTS = 12

# One seed for the whole atlas: the tiles are art, and art that changes
# every time it is baked cannot be reviewed in a diff.
SEED = 20260925

TRANSPARENT = (0, 0, 0, 0)


class Atlas:
    """The tiles, packed into one image, identical ones stored once."""

    def __init__(self) -> None:
        self.tiles: list[Image.Image] = []
        self._index: dict[bytes, int] = {}

    def add(self, tile: Image.Image) -> int:
        key = tile.tobytes()
        if key not in self._index:
            self._index[key] = len(self.tiles)
            self.tiles.append(tile)
        return self._index[key]

    def bucket(self, make, count: int = VARIANTS) -> list[int]:
        """`count` paintings of the same tile, deduplicated: a tile with no
        randomness in it collapses back to one. `make` returns a tile."""
        indices = []
        for _ in range(count):
            index = self.add(make())
            if index not in indices:
                indices.append(index)
        return indices

    def image(self, columns: int = 16) -> Image.Image:
        rows = (len(self.tiles) + columns - 1) // columns
        sheet = Image.new("RGBA", (columns * TILE, rows * TILE), TRANSPARENT)
        for i, tile in enumerate(self.tiles):
            sheet.paste(tile, ((i % columns) * TILE, (i // columns) * TILE))
        return sheet


def parity_key() -> dict:
    return {"kind": "parity"}


def row_key(y: int) -> dict:
    return {"kind": "row", "y": y}


def neighbour_key(dx: int, dy: int, glyphs: str) -> dict:
    return {"kind": "neighbour", "dx": dx, "dy": dy, "glyphs": glyphs}


def rule(layer: str, glyphs: str, buckets: list[list[int]],
         keys: list[dict] | None = None) -> dict:
    keys = keys or []
    assert len(buckets) == 2 ** len(keys), (layer, glyphs, len(buckets))
    return {"layer": layer, "glyphs": glyphs, "keys": keys,
            "buckets": buckets}


def tile_of(paint) -> Image.Image:
    """A tile painted by a painter that draws at (0, 0)."""
    tile = Image.new("RGBA", (TILE, TILE), TRANSPARENT)
    paint(ImageDraw.Draw(tile))
    return tile


def cell(paint, gx: int = 0, gy: int = 0) -> Image.Image:
    """A tile painted by a painter that takes coordinates in tiles and
    works out the pixels itself: paint on a canvas big enough and cut out
    the cell asked for. Which cell matters: the floors alternate on the
    parity of x + y."""
    wide = Image.new("RGBA", ((gx + 1) * TILE, (gy + 1) * TILE), TRANSPARENT)
    paint(ImageDraw.Draw(wide), gx, gy)
    return wide.crop((gx * TILE, gy * TILE, (gx + 1) * TILE, (gy + 1) * TILE))


class Neighbourhood:
    """What a painter that looks at its neighbours is shown while its tile
    is being painted: one cell of its own and whatever we want around it."""

    def __init__(self, glyph: str, around) -> None:
        self.glyph = glyph
        self.around = around
        self.width = 1
        self.height = 1

    def at(self, x: int, y: int) -> str:
        return self.glyph if (x, y) == (0, 0) else self.around(x, y)

    def is_wall(self, x: int, y: int) -> bool:
        return self.at(x, y) in station.WALLS


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


def paint_chair(d, px, py):
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
    """A shut door with the same white interaction hand as the bar. It
    stands two tiles high, so it is an object, not a tile."""
    top = py - TILE
    rect(d, px + 1, top, TILE - 2, TILE * 2, (24, 22, 22))
    rect(d, px + 3, top + 2, TILE - 6, TILE * 2 - 3, (72, 48, 34))
    rect(d, px + 4, top + 3, TILE - 8, 2, (108, 76, 50))
    rect(d, px + 4, py + 2, TILE - 8, 1, (44, 30, 24))
    rect(d, px + 11, py + 7, 2, 2, (188, 158, 82))
    for ox, oy, width, height in ((7, 8, 2, 8), (5, 12, 6, 5), (4, 13, 2, 3)):
        rect(d, px + ox + 1, top + oy + 1, width, height, (24, 22, 22))
        rect(d, px + ox, top + oy, width, height, (244, 240, 228))


def paint_side_edge(d, px, py, right):
    """The dark line where a floor meets the darkness outside the room."""
    rect(d, px + (14 if right else 0), py, 2, TILE, (40, 40, 46))


def duomo_upper(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.duomoUpper, and its door object."""
    # The floor goes under everything that is not wall, void or the door.
    floor = [
        atlas.bucket(lambda p=parity: cell(
            lambda dd, gx, gy: duomo_floor(dd, rng, gx, gy), p, 0))
        for parity in (0, 1)
    ]
    walls = atlas.bucket(lambda: tile_of(lambda d: duomo_wall(d, 0, 0)), 1)
    front = atlas.bucket(
        lambda: tile_of(lambda d: duomo_wall(d, 0, 0, front=True)), 1)
    props = {
        "T": paint_table, "C": paint_chair, "B": paint_bed,
        "K": paint_cupboard, "D": paint_stairs_down,
        "d": lambda d, px, py: rect(d, px + 1, py, TILE - 2, 2, STONE_LIGHT),
    }
    rules = [
        rule("ground", ".*RTCBKDd", floor, [parity_key()]),
        rule("structures", "WI", [walls]),
        rule("structures", "w", [front]),
    ]
    for glyph, paint in props.items():
        rules.append(rule("structures", glyph, [atlas.bucket(
            lambda p=paint: tile_of(lambda d: p(d, 0, 0)), 1)]))
    for right in (False, True):
        dx = 1 if right else -1
        edge = atlas.bucket(lambda r=right: tile_of(
            lambda d: paint_side_edge(d, 0, 0, r)), 1)
        rules.append(rule("foreground", ".*RTCBKDd",
                          [[], edge], [neighbour_key(dx, 0, "x")]))
    door = Image.new("RGBA", (TILE, TILE * 2), TRANSPARENT)
    paint_locked_door(ImageDraw.Draw(door), 0, TILE)
    return {
        "void": "#060608",
        "voidGlyph": "x",
        "rules": rules,
        "objects": [{"glyph": "L", "image": "duomo_upper_door.png",
                     "offsetY": -1, "sprite": door}],
    }


# ------------------------------------------- the Bar Arcobaleno's storeroom
# Moved here from tools/build_bar_backroom.py, which this atlas replaces:
# the cramped room behind the bar, shelves and crates on a bare screed.

BACKROOM_FLOOR = (80, 74, 68)
BACKROOM_FLOOR_ALT = (96, 88, 78)
BACKROOM_WALL = (112, 96, 82)
BACKROOM_WALL_DARK = (54, 46, 42)
BACKROOM_WOOD = (94, 62, 38)


def paint_backroom_floor(d, px, py, alternate):
    """Bare screed, laid in two tones, with the shadow of the course above."""
    rect(d, px, py, TILE, TILE,
         BACKROOM_FLOOR_ALT if alternate else BACKROOM_FLOOR)
    rect(d, px, py, TILE, 1, BACKROOM_WALL_DARK)


def paint_backroom_wall(d, px, py, front):
    rect(d, px, py, TILE, TILE,
         BACKROOM_WALL_DARK if front else BACKROOM_WALL)
    rect(d, px, py, TILE, 2, shade(BACKROOM_WALL, 20))


def paint_backroom_shelf(d, px, py):
    rect(d, px, py + 4, TILE, 11, BACKROOM_WOOD)
    rect(d, px, py + 4, TILE, 2, shade(BACKROOM_WOOD, 30))


def paint_backroom_crate(d, px, py):
    rect(d, px + 1, py + 2, 14, 13, BACKROOM_WOOD)
    rect(d, px + 2, py + 3, 12, 2, shade(BACKROOM_WOOD, 28))
    rect(d, px + 7, py + 3, 2, 11, shade(BACKROOM_WOOD, -24))


def paint_backroom_litter(d, rng, px, py):
    for _ in range(8):
        rect(d, px + rng.randrange(15), py + rng.randrange(15),
             rng.randint(1, 3), 1, (52, 48, 46))


def paint_backroom_door(d, px, py):
    rect(d, px, py, TILE, TILE, (28, 26, 28))
    rect(d, px + 4, py + 2, 8, TILE - 2, (176, 164, 144))


def bar_backroom(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.barBackroom."""
    floor = [
        atlas.bucket(lambda a=alternate: tile_of(
            lambda d: paint_backroom_floor(d, 0, 0, a)), 1)
        for alternate in (True, False)
    ]
    props = {
        "K": paint_backroom_shelf,
        "B": paint_backroom_crate,
        "E": paint_backroom_door,
    }
    # The floor goes under every glyph that is not wall or void; the door
    # covers its cell whole, the rest let it show.
    floored = ".*8KB:E"
    rules = [
        rule("ground", floored, floor, [parity_key()]),
        rule("structures", "WI",
             [atlas.bucket(lambda: tile_of(
                 lambda d: paint_backroom_wall(d, 0, 0, False)), 1)]),
        rule("structures", "w",
             [atlas.bucket(lambda: tile_of(
                 lambda d: paint_backroom_wall(d, 0, 0, True)), 1)]),
        rule("structures", ":", [atlas.bucket(
            lambda: tile_of(lambda d: paint_backroom_litter(d, rng, 0, 0)))]),
    ]
    for glyph, paint in props.items():
        rules.append(rule("structures", glyph, [atlas.bucket(
            lambda p=paint: tile_of(lambda d: p(d, 0, 0)), 1)]))
    for right in (False, True):
        edge = atlas.bucket(lambda r=right: tile_of(
            lambda d: paint_side_edge(d, 0, 0, r)), 1)
        rules.append(rule("foreground", floored, [[], edge],
                          [neighbour_key(1 if right else -1, 0, "x")]))
    return {"void": "#060608", "voidGlyph": "x", "rules": rules,
            "objects": []}




def pattern_key(a: int, b: int, mod: int, equals: int = 0) -> dict:
    """The bakers dot a wall with graffiti on (x * a + y * b) % mod: a
    pattern, not a throw of the dice, so the renderer works it out too."""
    return {"kind": "pattern", "a": a, "b": b, "mod": mod, "equals": equals}


def first_row_key(glyph: str, offset: int, compare: str) -> dict:
    """Against the first row of the place that holds `glyph`: the platform
    edge is the first row with a slab on it, and the baker paints that row
    differently. The row is read off the place's own ASCII, so it stays
    the one source of truth."""
    return {"kind": "firstRow", "glyph": glyph, "offset": offset,
            "compare": compare}


# The railcar is one object, not tiles: its grime runs across the grid. It
# is painted at the size of the run of `M` in the far platform's rows;
# test/levels/tile_atlas_test.dart fails if the rows stop agreeing.
RAILCAR_TILES = (27, 3)
RAILCAR_DOOR_TILE = 23


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
        rule("ground", "=Tn",
             [platform(0, False), platform(1, False),
              platform(0, True), platform(1, True)],
             [parity_key(), first_row_key("=", 0, "eq")]),
        # Litter lies on the platform if it is near it, on the hall floor
        # if it is not: the baker drew the line two rows below the edge.
        rule("ground", ":",
             [hall(0), hall(1), platform(0, False), platform(1, False)],
             [parity_key(), first_row_key("=", 2, "le")]),
        rule("ground", "DP", [hall(0), hall(1)], [parity_key()]),
        rule("structures", "W", wall,
             [neighbour_key(0, -1, "W"), pattern_key(7, 5, 9)]),
        rule("structures", ":", [litter]),
        rule("structures", "D", ends(station.paint_stairs, "D"),
             [neighbour_key(-1, 0, "D"), neighbour_key(1, 0, "D")]),
    ]
    for right in (False, True):
        edge = atlas.bucket(lambda r=right: tile_of(
            lambda d: paint_side_edge(d, 0, 0, r)), 1)
        rules.append(rule("foreground", "-,M=TnD:P",
                          [[], edge], [neighbour_key(1 if right else -1,
                                                     0, "x")]))
    rules.append(rule("foreground", "T", ends(station.paint_bench, "T"),
                      [neighbour_key(-1, 0, "T"), neighbour_key(1, 0, "T")]))
    rules.append(rule("foreground", "n",
                      [atlas.bucket(lambda b=beam: tile_of(
                          lambda d: station.paint_post(d, Neighbourhood(
                              "n", lambda x, y, b=b: "n"
                              if (x == 1 and b) else "."), 0, 0)), 1)
                       for beam in (False, True)],
                      [neighbour_key(1, 0, "n")]))

    def railcar(open_door: bool) -> Image.Image:
        width, height = (n * TILE for n in RAILCAR_TILES)
        sprite = Image.new("RGBA", (width, height), TRANSPARENT)
        station.paint_railcar(
            ImageDraw.Draw(sprite), random.Random(SEED + 1),
            (0, 0, width, height), wrecked=False,
            door_x=RAILCAR_DOOR_TILE * TILE, open_door=open_door,
        )
        return sprite

    return {
        "void": "#060608",
        "voidGlyph": "x",
        "rules": rules,
        "objects": [
            {"glyph": "M", "image": "station_railcar.png",
             "tiles": list(RAILCAR_TILES), "sprite": railcar(False),
             "whenOpen": "station_railcar_open.png",
             "openSprite": railcar(True)},
        ],
    }


# ------------------------------------------------------ the reference draw
# What the renderer in lib/game/render/tile_place_component.dart has to do,
# written out once here so the manifest can be checked against the baked
# PNGs while they still exist, and so --preview can show a converted place
# without a device.

def variant(tiles: list[int], x: int, y: int) -> int:
    """Which of a bucket's tiles falls on this cell: a hash of the place
    in the grid, so the grit is the same at every start and there is no
    seed to save. lib/game/render/tile_place_component.dart repeats it."""
    return tiles[((x * 73856093) ^ (y * 19349663)) % len(tiles)]


def compose(rows: list[str], place: dict, tiles: list[Image.Image],
            opened: bool = False) -> Image.Image:
    width, height = len(rows[0]), len(rows)

    def at(x: int, y: int) -> str:
        if 0 <= x < width and 0 <= y < height:
            return rows[y][x]
        return "x"

    def first_row(glyph: str) -> int:
        return next((y for y in range(height) if glyph in rows[y]), 0)

    def truth(key: dict, x: int, y: int) -> bool:
        kind = key["kind"]
        if kind == "parity":
            return (x + y) % 2 == 1
        if kind == "neighbour":
            return at(x + key["dx"], y + key["dy"]) in key["glyphs"]
        if kind == "pattern":
            return (x * key["a"] + y * key["b"]) % key["mod"] == key["equals"]
        if kind == "firstRow":
            edge = first_row(key["glyph"]) + key["offset"]
            return y <= edge if key["compare"] == "le" else y == edge
        raise ValueError(kind)

    colour = place["void"].lstrip("#")
    void = tuple(int(colour[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
    out = Image.new("RGBA", (width * TILE, height * TILE), void)
    for layer in ("ground", "structures", "objects", "foreground"):
        if layer == "objects":
            for obj in place["objects"]:
                sprite = obj["openSprite"] if opened and "openSprite" in obj \
                    else obj["sprite"]
                cells = [(x, y) for y in range(height)
                         for x in range(width) if at(x, y) == obj["glyph"]]
                if not cells:
                    continue
                x0 = min(x for x, _ in cells)
                y0 = min(y for _, y in cells)
                out.alpha_composite(
                    sprite, (x0 * TILE, (y0 + obj.get("offsetY", 0)) * TILE))
            continue
        for y in range(height):
            for x in range(width):
                glyph = at(x, y)
                for spec in place["rules"]:
                    if spec["layer"] != layer or glyph not in spec["glyphs"]:
                        continue
                    index = 0
                    for bit, key in enumerate(spec["keys"]):
                        if truth(key, x, y):
                            index |= 1 << bit
                    bucket = spec["buckets"][index]
                    if not bucket:
                        continue
                    out.alpha_composite(
                        tiles[variant(bucket, x, y)], (x * TILE, y * TILE))
    return out


# ----------------------------------------------------------------- writing

PLACES = {
    "barBackroom": bar_backroom,
    "duomoUpper": duomo_upper,
    "stationFarSide": station_far_side,
}


def build() -> tuple[Atlas, dict]:
    atlas = Atlas()
    rng = random.Random(SEED)
    places = {name: make(atlas, rng) for name, make in sorted(PLACES.items())}
    manifest = {
        "format": "stepbound-tile-atlas-v1",
        "tileWidth": TILE,
        "tileHeight": TILE,
        "layers": ["ground", "structures", "foreground"],
        "palette": "assets/palette.gpl",
        "atlas": ATLAS.replace(os.sep, "/"),
        "columns": 16,
        "places": {
            name: {
                "void": place["void"],
                "voidGlyph": place["voidGlyph"],
                "rules": place["rules"],
                "objects": [
                    {k: v for k, v in obj.items()
                     if k not in ("sprite", "openSprite")}
                    for obj in place["objects"]
                ],
            }
            for name, place in places.items()
        },
    }
    return atlas, {"manifest": manifest, "places": places}


def write(root: str) -> None:
    atlas, built = build()
    os.makedirs(os.path.join(root, OBJECTS), exist_ok=True)
    atlas.image(built["manifest"]["columns"]).save(
        os.path.join(root, ATLAS), optimize=True)
    for place in built["places"].values():
        for obj in place["objects"]:
            obj["sprite"].save(
                os.path.join(root, OBJECTS, obj["image"]), optimize=True)
            if "openSprite" in obj:
                obj["openSprite"].save(
                    os.path.join(root, OBJECTS, obj["whenOpen"]),
                    optimize=True)
    with open(os.path.join(root, MANIFEST), "w", encoding="utf-8") as out:
        json.dump(built["manifest"], out, indent=2)
        out.write("\n")
    print(f"{ATLAS}: {len(atlas.tiles)} tile")
    for name in sorted(built["places"]):
        print(f"  {name}: {len(built['places'][name]['rules'])} regole, "
              f"{len(built['places'][name]['objects'])} oggetti")


# The marker of each converted place's ASCII rows, for --preview only: the
# atlas itself never reads a place.
PREVIEW_ROWS = {
    "barBackroom": "bar-backroom-rows",
    "duomoUpper": "duomo-upper-rows",
    "stationFarSide": "far-platform-rows",
}


def preview(root: str) -> None:
    from build_street_level import read_rows  # noqa: PLC0415 - preview only

    atlas, built = build()
    tiles = atlas.tiles
    for name, marker in sorted(PREVIEW_ROWS.items()):
        rows = read_rows(marker)
        place = built["places"][name]
        for opened in ([False, True] if any("openSprite" in o
                                            for o in place["objects"])
                       else [False]):
            image = compose(rows, place, tiles, opened=opened)
            out = os.path.join(
                root, f"preview_{name}{'_open' if opened else ''}.png")
            image.convert("RGB").save(out)
            print(f"{out}: {image.size[0]}x{image.size[1]}")


def check() -> None:
    """The atlas is generated art: re-make it and see that nothing moved,
    the same gate tools/build_levels.py gives the baked backgrounds."""
    with tempfile.TemporaryDirectory() as tmp:
        write(tmp)
        for name in (ATLAS, MANIFEST):
            fresh = os.path.join(tmp, name)
            committed = os.path.join(ROOT, name)
            if not os.path.exists(committed):
                raise SystemExit(f"{name} is missing: run "
                                 f"python tools/build_tile_atlas.py")
            if name.endswith(".png"):
                with Image.open(committed) as a, Image.open(fresh) as b:
                    old, new = a.convert("RGBA"), b.convert("RGBA")
                    same = old.size == new.size and \
                        old.tobytes() == new.tobytes()
                    where = "" if same else (
                        f" (differisce in {ImageChops.difference(old, new).getbbox()})"
                        if old.size == new.size else
                        f" ({old.size} contro {new.size})")
            else:
                with open(committed, encoding="utf-8") as a, \
                        open(fresh, encoding="utf-8") as b:
                    same, where = a.read() == b.read(), ""
            if not same:
                raise SystemExit(
                    f"{name} is out of date{where}.\nRe-run it and commit "
                    f"the result:\n    python tools/build_tile_atlas.py")
            print(f"{name}: up to date")
        for entry in sorted(os.listdir(os.path.join(tmp, OBJECTS))):
            committed = os.path.join(ROOT, OBJECTS, entry)
            with Image.open(os.path.join(tmp, OBJECTS, entry)) as fresh:
                new = fresh.convert("RGBA")
            if not os.path.exists(committed):
                raise SystemExit(f"{OBJECTS}/{entry} is missing")
            with Image.open(committed) as a:
                if a.convert("RGBA").tobytes() != new.tobytes():
                    raise SystemExit(
                        f"{OBJECTS}/{entry} is out of date.\nRe-run it and "
                        f"commit the result:\n"
                        f"    python tools/build_tile_atlas.py")
            print(f"{OBJECTS}/{entry}: up to date")
    print("the tile atlas matches its painters")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true",
                        help="do not write anything: fail if the committed "
                             "atlas is not what the painters make today")
    parser.add_argument("--preview", metavar="DIR",
                        help="draw the converted places into DIR, the way "
                             "the game will draw them")
    args = parser.parse_args()
    if args.check:
        check()
    elif args.preview:
        os.makedirs(args.preview, exist_ok=True)
        preview(args.preview)
    else:
        write(ROOT)


if __name__ == "__main__":
    main()
