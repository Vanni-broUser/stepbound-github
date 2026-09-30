"""The crashed airliner in the tile atlas: its cabin, and the terraces
its tail came down on (lib/core/levels/hometown/airliner.dart).

A module of its own, the way docs/level_pipeline.md wants the interiors
to go: build_tile_atlas.py only lists it. The painters stay in
tools/build_airliner.py; here is what is made of them.
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_airliner as airliner  # noqa: E402
from tile_atlas_core import (  # noqa: E402
    Atlas,
    Neighbourhood,
    cell,
    first_row_key,
    neighbour_key,
    parity_key,
    pattern_key,
    row_has_key,
    rule,
    tile_of,
)

# ------------------------------------------------ the airliner cabin's art
# Painted by tools/build_airliner.py, which keeps the painters and lost the
# composition that baked this place; the roofs it opens on are still baked.

class Strip:
    """Three rows of a place, for a painter that asks whether the rows
    beside its own have a seat in them: what tells an aisle where the
    seats begin."""

    height = 3

    def __init__(self, above: bool, below: bool) -> None:
        self.rows = ["T" if above else ".", ".", "T" if below else "."]


def airliner_cabin(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.airlinerCabin: the hull seen from above,
    two banks of seats either side of the aisles, and the light that falls
    in at the two breaks."""
    floor = [
        atlas.bucket(lambda p=parity: cell(
            lambda d, gx, gy: airliner.cabin_floor(d, rng, gx, gy), p, 0))
        for parity in (0, 1)
    ]
    # A row with no seat in it is an aisle: the runner is laid down it, and
    # edged on whichever side the next row has seats. Bits, in key order:
    # this row has a seat, the row above has, the row below has.
    aisle = []
    for index in range(8):
        seated, above, below = (bool(index & 1), bool(index & 2),
                                bool(index & 4))
        aisle.append([] if seated else atlas.bucket(
            lambda a=above, b=below: cell(
                lambda d, gx, gy: airliner.cabin_aisle(
                    d, rng, Strip(a, b), gx, gy), 0, 1)))

    def hull(glyph):
        """The lockers are ribbed every third column: a pattern on x."""
        return [
            atlas.bucket(lambda g=gx: cell(
                lambda d, x, y: airliner.cabin_hull(
                    d, Neighbourhood(glyph, lambda *_: ".", (x, y)), x, y),
                g, 0), 1)
            for gx in (1, 0)
        ]

    def seat():
        out = []
        for below in (False, True):
            for above in (False, True):
                out.append(atlas.bucket(lambda a=above, b=below: tile_of(
                    lambda d: airliner.cabin_seat(d, Neighbourhood(
                        "T", lambda x, y, a=a, b=b: "T"
                        if (y == -1 and a) or (y == 1 and b) else "."),
                        0, 0)), 1))
        return out

    floored = ".:b*+ZM9KTr"
    rules = [
        rule("ground", floored, floor, [parity_key()]),
        rule("ground", floored, aisle,
             [row_has_key(0, "T"), row_has_key(-1, "T"),
              row_has_key(1, "T")]),
    ]
    for glyph in "Ww":
        rules.append(rule("structures", glyph, hull(glyph),
                          [pattern_key(1, 0, 3)]))
    rules += [
        rule("structures", "I",
             [atlas.bucket(lambda: tile_of(lambda d: airliner.cabin_hull(
                 d, Neighbourhood("I", lambda *_: "."), 0, 0)), 1)]),
        rule("structures", "E", [atlas.bucket(lambda: tile_of(
            lambda d: airliner.cabin_break(d, 0, 0, roof=False)), 1)]),
        rule("structures", "O", [atlas.bucket(lambda: tile_of(
            lambda d: airliner.cabin_break(d, 0, 0, roof=False)), 1)]),
        rule("structures", "T", seat(),
             [neighbour_key(0, -1, "T"), neighbour_key(0, 1, "T")]),
        rule("structures", "K", [atlas.bucket(lambda: tile_of(
            lambda d: airliner.cabin_trolley(d, 0, 0)), 1)]),
        rule("structures", "r", [atlas.bucket(lambda: tile_of(
            lambda d: airliner.cabin_broken_seat(d, 0, 0)), 1)]),
        rule("structures", ":", [atlas.bucket(lambda: tile_of(
            lambda d: airliner.cabin_litter(d, rng, 0, 0)))]),
        rule("structures", "b", [atlas.bucket(lambda: tile_of(
            lambda d: airliner.cabin_blood(d, rng, 0, 0)))]),
    ]
    for glyph, steady in (("*", True), ("+", False)):
        rules.append(rule("structures", glyph, [atlas.bucket(
            lambda s=steady: tile_of(
                lambda d: airliner.cabin_lamp(d, 0, 0, s)), 1)]))
    return {"void": "#000000", "voidGlyph": "x", "rules": rules,
            "objects": []}


# ---------------------------------------------------------- the roofs' art
# The terraces the airliner's tail came down on, in the 3/4 view of the
# streets. The painters stay in tools/build_airliner.py; this is the
# composition that baked them. Nothing in it stands taller than its cell,
# so it is all tiles: the tar laid in strips on the parity of the row and
# stepped down at the first parapet, the coping and the party walls keyed
# on their neighbours, and the gap between the blocks, which is dark only
# where there is roof both above and below it in the column.

class Rows:
    """Just the rows of a place: what `build_airliner.lower` reads to find
    where the terrace steps down."""

    def __init__(self, rows: list[str]) -> None:
        self.rows = rows


def airliner_roofs(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.airlinerRoofs."""
    def deck(row: int, step: int):
        """The tar of row `row` on a terrace whose step is at row `step`:
        it is the lower terrace if the row is below the step, and laid in
        strips on the parity of the row."""
        rows = Rows(["." * 6] * step + ["^" * 6] + ["." * 6] * 3)
        return atlas.bucket(lambda: cell(
            lambda d, gx, gy: airliner.roof_deck(d, rng, rows, gx, gy),
            0, row))

    def one(paint):
        return [atlas.bucket(lambda: tile_of(lambda d: paint(d, 0, 0)), 1)]

    def randomly(paint):
        return [atlas.bucket(lambda: tile_of(
            lambda d: paint(d, rng, 0, 0)))]

    def near(glyph, at=(0, 0), **shown):
        """The neighbourhood of the cell `at` of `glyph`, in which the
        named neighbours (`l`, `r`, `u` for left, right, up) show what is
        given and the rest is bare."""
        offsets = {"l": (-1, 0), "r": (1, 0), "u": (0, -1), "d": (0, 1)}
        cells = {(at[0] + offsets[k][0], at[1] + offsets[k][1]): v
                 for k, v in shown.items()}
        return Neighbourhood(glyph, lambda x, y: cells.get((x, y), "."), at)

    decked = ".:b&TnY9"
    # Bits, in key order: the row is no lower than the step, and the row
    # is odd. Without the first (index 0 and 2) the terrace is the lower.
    rules = [rule(
        "ground", decked,
        [deck(2, 0), deck(0, 0), deck(1, 0), deck(1, 1)],
        [first_row_key("^", 0, "le"), pattern_key(0, 1, 2, 1)])]

    # A party wall between two blocks: bits are a wall to the left, a wall
    # to the right, and darkness or wall to the right (which side the roof
    # is on, for the walls that run north to south).
    walls = []
    for index in range(8):
        left, right, beyond = (bool(index & 1), bool(index & 2),
                               bool(index & 4))
        room = near("W", l="W" if left else ".",
                    r="W" if right else ("x" if beyond else "."))
        walls.append(atlas.bucket(lambda rm=room: tile_of(
            lambda d: airliner.roof_wall(d, rm, 0, 0)), 1))
    rules.append(rule("structures", "W", walls,
                      [neighbour_key(-1, 0, "W"), neighbour_key(1, 0, "W"),
                       neighbour_key(1, 0, "xW")]))
    rules.append(rule("structures", "^", [atlas.bucket(
        lambda c=corner: tile_of(lambda d: airliner.roof_parapet(
            d, near("^", u="W" if c else "."), 0, 0, False)), 1)
        for corner in (False, True)], [neighbour_key(0, -1, "W")]))
    rules.append(rule(
        "structures", ">",
        [atlas.bucket(lambda i=i: tile_of(
            lambda d: airliner.roof_parapet(
                d, near(">", l=">" if i & 1 else ".",
                        r=">" if i & 2 else "."), 0, 0, True)), 1)
         for i in range(4)],
        [neighbour_key(-1, 0, ">"), neighbour_key(1, 0, ">")]))
    rules.append(rule("structures", ":", randomly(airliner.roof_rubble)))
    rules.append(rule("structures", "b", randomly(airliner.roof_blood)))
    rules.append(rule(
        "structures", "&",
        [atlas.bucket(lambda a=a: tile_of(
            lambda d: airliner.roof_scorch(d, 0, 0, a)), 1)
         for a in (False, True)],
        [pattern_key(0, 1, 2, 1)]))
    rules.append(rule("structures", "T", randomly(airliner.roof_stack)))
    rules.append(rule("structures", "n", one(airliner.roof_mast)))

    # The roof of the next block across the gap, felted like the lower
    # terrace and walled like it (its walls and parapet are the rules
    # above), and what stands on it.
    rules.append(rule(
        "ground", airliner.FAR_DECK, [deck(2, 0), deck(1, 0)],
        [pattern_key(0, 1, 2, 1)]))
    rules.append(rule("structures", "k", randomly(airliner.roof_stack)))
    rules.append(rule("structures", ";", randomly(airliner.roof_rubble)))
    rules.append(rule(
        "structures", "S",
        [atlas.bucket(lambda i=i: tile_of(
            lambda d: airliner.roof_stairs_across(
                d, near("S", l="S" if i & 1 else ".",
                        r="S" if i & 2 else ".",
                        u="S" if i & 4 else ".",
                        d="S" if i & 8 else "."), 0, 0)), 1)
         for i in range(16)],
        [neighbour_key(-1, 0, "S"), neighbour_key(1, 0, "S"),
         neighbour_key(0, -1, "S"), neighbour_key(0, 1, "S")]))
    rules.append(rule("structures", "<", [atlas.bucket(lambda: tile_of(
        lambda d: airliner.roof_wall_breach(
            d, near("<", l="W", r="W"), 0, 0)), 1)]))

    # The tail of the airliner, in the roofline: two rows deep, so the
    # tube is shaded over both at once, seamed every fourth column and
    # closed at the ends. `D` is the break torn in it.
    def tail(glyph, index):
        above, seam, left, right = (bool(index & 1), bool(index & 2),
                                    bool(index & 4), bool(index & 8))
        gx = 0 if seam else 1
        room = near(glyph, (gx, 0), u="#" if above else ".",
                    l="#" if left else ".", r="#" if right else ".")
        paint = airliner.roof_tail if glyph == "#" else airliner.roof_break
        return atlas.bucket(lambda: cell(
            lambda d, x, y: paint(d, room, x, y), gx, 0), 1)
    tail_keys = [neighbour_key(0, -1, "#D"), pattern_key(1, 0, 4, 0),
                 neighbour_key(-1, 0, "#D"), neighbour_key(1, 0, "#D")]
    for glyph in "#D":
        rules.append(rule("structures", glyph,
                          [tail(glyph, i) for i in range(16)], tail_keys))
    return {"void": "#000000", "voidGlyph": "x", "rules": rules,
            "objects": []}
