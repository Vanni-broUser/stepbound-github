"""The block east of the hospital's roof in the tile atlas: the two floors
the open stairwell on its roof goes down into
(lib/core/levels/hometown/east_block.dart).

Its floors are built by the rules of Molfetta's palazzo
(tile_atlas_palazzo.palazzo_floor), with the palazzo's own painters: the
same block of flats, the same oak parquet, kitchen and bathroom tiles,
the same marble on the stairwell, which here runs on along a corridor
across the whole floor. What the palazzo has not got is the offices on
the other side of that corridor: their carpet tiles and their cubicles
are the call centre's (tile_atlas_company), under glyphs of this
module's own so they can share a floor with the flats' furniture.
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tile_atlas_company as company  # noqa: E402
import tile_atlas_palazzo as palazzo  # noqa: E402
from tile_atlas_core import (  # noqa: E402
    Atlas,
    ground_config,
    leaning,
    neighbour_key,
    rule,
    tile_of,
)

# The palazzo's floors, and the offices' carpet.
FLOORS = palazzo.FLOORS + (("~", company.paint_carpet),)

# The glass of the manager's office is a wall like the partitions.
PZ_WALLS = "xWwIG"

# The offices' furniture, every piece of it an obstacle: workstations
# facing the room `o` and away `y`, the panels `|` and `-` between the
# cubicles, the chairs `g`, the meeting table `t`, a filing cabinet `C`,
# the photocopier `j`, a vending machine `m` and the water cooler `u`.
OFFICE = "oy|-gCjmut"

# The picture of the way up: the palazzo's.
STAIRS_IMAGE = palazzo.STAIRS_IMAGE

# The floor under the furniture, the dead and the doors: the nearest one
# along the row, never through a wall, so a desk stands on the carpet and
# a sofa on the parquet.
GROUND = ground_config(
    buildings=PZ_WALLS,
    roads="",
    walks="",
    floors="".join(glyph for glyph, _ in FLOORS),
    footway="",
    keep="",
    lawn="",
    lawnProps="",
)


def __getattr__(name: str):
    """Every painter the palazzo's rules ask a style for is the palazzo's
    own: only the floors, the walls and the ground above are this
    module's."""
    return getattr(palazzo, name)


_STYLE = sys.modules[__name__]


def office_rules(atlas: Atlas, rng) -> list[dict]:
    """The rules that paint the offices' furniture, the call centre's
    painters under this module's glyphs."""
    rules = []

    def one(paint):
        return [atlas.bucket(lambda: tile_of(lambda d: paint(d, 0, 0)), 1)]

    # Glass up and down the room where there is glass below it.
    rules.append(rule(
        "structures", "G",
        [atlas.bucket(lambda u=upright: tile_of(
            lambda d: company.paint_glass(d, rng, 0, 0, u)))
         for upright in (False, True)],
        [neighbour_key(0, 1, "G")]))
    # The workstations, their panels and chairs.
    for glyph, facing_in in (("o", True), ("y", False)):
        buckets, up = leaning(atlas, lambda i, f=facing_in: lambda d, px, py:
                              company.paint_workstation(d, rng, px, py, f))
        rules.append(rule("structures", glyph, buckets, pieces=up))
    rules.append(rule("structures", "-", one(company.paint_panel_across)))
    desk_beside = [neighbour_key(-1, 0, "oy")]
    buckets, up = leaning(atlas, lambda i: lambda d, px, py:
                          company.paint_panel_upright(d, px, py, bool(i & 1)),
                          desk_beside, 1)
    rules.append(rule("structures", "|", buckets, desk_beside, up))
    rules.append(rule("structures", "g", [atlas.bucket(
        lambda o=out: tile_of(lambda d: company.paint_chair(d, 0, 0, o)), 1)
        for out in (False, True)], [neighbour_key(0, 1, "y")]))
    sides = [neighbour_key(-1, 0, "t"), neighbour_key(0, -1, "t"),
             neighbour_key(1, 0, "t"), neighbour_key(0, 1, "t")]
    rules.append(rule("structures", "t", [atlas.bucket(
        lambda i=index: tile_of(lambda d: company.paint_table(
            d, 0, 0, tuple(not i & (1 << bit) for bit in range(4)))), 1)
        for index in range(16)], sides))
    for glyph, paint in (("C", company.paint_cabinet),
                         ("j", company.paint_copier),
                         ("m", company.paint_vending),
                         ("u", company.paint_cooler)):
        buckets, up = leaning(atlas, lambda i, p=paint: lambda d, px, py: p(
            d, rng, px, py))
        rules.append(rule("structures", glyph, buckets, pieces=up))
    return rules


def east_block_floor(atlas: Atlas, rng) -> dict:
    """The rules that paint one of the block's floors: the palazzo's rooms
    and furniture, then the offices'."""
    place = palazzo.palazzo_floor(atlas, rng, "PpcU" + palazzo.FURNITURE,
                                  _STYLE)
    place["rules"].extend(office_rules(atlas, rng))
    return place


def east_block_top_floor(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.eastBlockTopFloor."""
    return east_block_floor(atlas, rng)


def east_block_lower_floor(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.eastBlockLowerFloor."""
    return east_block_floor(atlas, rng)


PLACES = {
    "eastBlockTopFloor": east_block_top_floor,
    "eastBlockLowerFloor": east_block_lower_floor,
}

PREVIEW_ROWS = {
    "eastBlockTopFloor": "east-block-top-rows",
    "eastBlockLowerFloor": "east-block-lower-rows",
}
