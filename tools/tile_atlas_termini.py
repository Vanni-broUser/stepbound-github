"""Roma Termini in the tile atlas: the overpass over the tracks, the far
platform and the concourse (lib/core/levels/rome/termini*.dart). Its
name boards and stairs are the station's, from tile_atlas_station.py.

A module of its own, the way docs/level_pipeline.md wants the interiors
to go: build_tile_atlas.py only lists it. The painters stay in
tools/build_termini.py; here is what is made of them.
"""
from __future__ import annotations

import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_station as station  # noqa: E402
import build_termini as termini  # noqa: E402
from street_paint import TILE, read_rows, rect  # noqa: E402
from build_mall import paint_blood  # noqa: E402
from tile_atlas_core import (  # noqa: E402
    Atlas,
    Neighbourhood,
    TRANSPARENT,
    cell,
    first_row_key,
    neighbour_key,
    parity_key,
    pattern_key,
    placed,
    rule,
    spread,
    tile_of,
)
from tile_atlas_station import (  # noqa: E402
    flight,
    side_walls,
)

# ------------------------------------------------- the rest of Roma Termini
# Painted by tools/build_termini.py: the overpass over the tracks, the far
# platform and the concourse (lib/core/levels/rome/termini_station.dart).


def blocks(rows: list[str], glyphs: str) -> list[tuple[int, int, int, int]]:
    """The rectangles the cells of `glyphs` make, each (x, y, width,
    height), west to east and north to south: every timetable, shop or
    flight in a row gets a picture of its own."""
    seen = set()
    out = []
    for y, row in enumerate(rows):
        for x, glyph in enumerate(row):
            if glyph not in glyphs or (x, y) in seen:
                continue
            w = 1
            while x + w < len(row) and row[x + w] == glyph:
                w += 1
            h = 1
            while y + h < len(rows) and rows[y + h][x:x + w] == glyph * w:
                h += 1
            for yy in range(y, y + h):
                for xx in range(x, x + w):
                    seen.add((xx, yy))
            out.append((x, y, w, h))
    return out


def termini_ends(atlas: Atlas, paint, glyph):
    """Four tiles: the two ends of a run, its middle, and a run of one."""
    out = []
    for right in (False, True):
        for left in (False, True):
            out.append(atlas.bucket(lambda l=left, r=right: tile_of(
                lambda d: paint(d, Neighbourhood(
                    glyph, lambda x, y, l=l, r=r: glyph
                    if (x == -1 and l) or (x == 1 and r) else "."),
                    0, 0)), 1))
    return out


def standing(atlas: Atlas, glyph: str, paint) -> dict:
    """The rule for something stood on the floor and taller than its cell,
    a machine or a pillar: drawn in the foreground, so what walks behind
    it goes behind it."""
    buckets, pieces = spread(atlas, lambda i: paint, None, (0, 1, 0, 0))
    return rule("foreground", glyph, buckets, None, pieces)


def rubble_rules(atlas: Atlas, rng) -> list[dict]:
    """The fallen roof, `#`: a heap with a girder in it now and then, and
    a dark lip on each side that meets what can be walked on."""
    rules = [rule("structures", "#",
                  [atlas.bucket(lambda g=girder: cell(
                      lambda d, gx, gy: station.paint_rubble_heap(
                          d, rng, gx, gy), *((0, 0) if g else (1, 0))))
                   for girder in (False, True)],
                  [pattern_key(5, 3, 7, 0)])]
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        lip = atlas.bucket(lambda o=(dx, dy): tile_of(
            lambda d: station.paint_rubble_lip(d, Neighbourhood(
                "#", lambda x, y, o=o: "." if (x, y) == o else "#"), 0, 0)),
            1)
        rules.append(rule("structures", "#", [lip, []],
                          [neighbour_key(dx, dy, "#xWw|")]))
    return rules


def termini_overpass(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.terminiOverpass: granite underfoot,
    steel and glass on the walls, eight flights down in the back wall and
    only two of them open."""
    rows = read_rows("termini-overpass-rows")
    floor = atlas.bucket(lambda: cell(
        lambda d, gx, gy: termini.paint_granite_floor(d, rng, gx, gy)))
    floor_alt = atlas.bucket(lambda: cell(
        lambda d, gx, gy: termini.paint_granite_floor(d, rng, gx, gy), 1, 0))
    wall = [atlas.bucket(lambda t=top: tile_of(
        lambda d: termini.paint_overpass_wall(d, rng, 0, 0, t)))
        for top in (True, False)]
    floored = ".:b*+KTIE#"
    rules = [
        rule("ground", floored, [floor, floor_alt], [parity_key()]),
        # Under a flight, the dark of the well; the painters cover it.
        rule("ground", "DUH", [atlas.bucket(lambda: tile_of(
            lambda d: rect(d, 0, 0, TILE, TILE, (20, 20, 22))), 1)]),
        rule("structures", "WQ", wall, [neighbour_key(0, -1, "WQ")]),
        rule("structures", "w", [atlas.bucket(lambda: tile_of(
            lambda d: termini.paint_overpass_front(d, 0, 0)), 1)]),
        rule("structures", "E", [atlas.bucket(lambda: tile_of(
            lambda d: termini.paint_opening(d, 0, 0)), 1)]),
        rule("structures", ":", [atlas.bucket(lambda: tile_of(
            lambda d: station.paint_litter(d, rng, 0, 0)))]),
        rule("structures", "b", [atlas.bucket(lambda: tile_of(
            lambda d: paint_blood(d, rng, 0, 0)))]),
        rule("structures", "*", [atlas.bucket(lambda: tile_of(
            lambda d: station.paint_lamp(d, 0, 0, False)), 1)]),
        rule("structures", "+", [atlas.bucket(lambda: tile_of(
            lambda d: station.paint_lamp(d, 0, 0, True)), 1)]),
        rule("structures", "H", [
            atlas.bucket(lambda l=left, r=right: tile_of(
                lambda d: termini.paint_barred_flight(d, 0, 0, l, r)), 1)
            for right in (False, True) for left in (False, True)],
            [neighbour_key(-1, 0, "H"), neighbour_key(1, 0, "H")]),
    ]
    # A flight choked with rubble is the heap filling the well; the heaps
    # spilt on the floor are the station's.
    choked = atlas.bucket(lambda: tile_of(
        lambda d: termini.paint_rubble_flight(d, rng, 0, 0)))
    heaps = rubble_rules(atlas, rng)
    rules.append(rule("structures", "#", [[], choked],
                      [neighbour_key(0, -1, "W")]))
    # Heaps only where the cell above is not the wall.
    for spec in heaps:
        spec["keys"] = spec["keys"] + [neighbour_key(0, -1, "W")]
        spec["buckets"] = spec["buckets"] + [[] for _ in spec["buckets"]]
    rules += heaps
    for glyph in "DU":
        rules.append(rule("structures", glyph,
                          termini_ends(atlas, station.paint_stairs, glyph),
                          [neighbour_key(-1, 0, glyph),
                           neighbour_key(1, 0, glyph)]))
    rules += side_walls(atlas)
    rules.append(rule("foreground", "T", termini_ends(
        atlas, station.paint_bench, "T"),
        [neighbour_key(-1, 0, "T"), neighbour_key(1, 0, "T")]))
    rules.append(standing(atlas, "K", lambda d, px, py:
                          termini.paint_ticket_machine(d, rng, px, py)))
    rules.append(standing(atlas, "I", termini.paint_pillar))

    objects = []
    for index, (x, y, w, h) in enumerate(blocks(rows, "Q")):
        objects.append({
            "image": f"termini_overpass_timetable_{index}.png",
            "sprite": termini.timetable(w, h, ("PARTENZE", "ARRIVI")[index % 2],
                                        rng),
            **placed(rows, x, y, w, h)})
    # The plates over the flights, numbered in order down the overpass.
    flights = []
    for x, glyph in enumerate(rows[2]):
        if glyph in "#HDU" and rows[2][x - 1] != glyph:
            flights.append((x, 2))
    for index, (x, y) in enumerate(flights):
        objects.append({
            "image": f"termini_overpass_plate_{index}.png",
            "sprite": termini.platform_plate(13 + index),
            **placed(rows, x, y - 1, 2, 1)})
    return {"void": "#000000", "voidGlyph": "x", "rules": rules,
            "objects": objects}


def termini_far_platform(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.terminiFarPlatform: the far side's
    track, ballast and platform, the train left on the far track, the
    rubbish over the line west and the derailed train east, the breach in
    the wall and the stairs up."""
    rows = read_rows("termini-far-platform-rows")

    def platform(parity: int, edge: bool):
        return atlas.bucket(lambda p=parity, e=edge: cell(
            lambda d, gx, gy: station.paint_platform(
                d, rng, gx, gy, 0 if e else -1), p, 0))

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
        rule("ground", "-", rails, [neighbour_key(-1, 0, "-;")]),
        rule("ground", ",m;VJ", [ballast]),
        # Litter on the platform lies on its paving, off it on the ballast.
        rule("ground", ":", [ballast, platform(0, False)],
             [neighbour_key(-1, 0, "=")]),
        rule("ground", "=Tn",
             [platform(0, False), platform(1, False),
              platform(0, True), platform(1, True)],
             [parity_key(), first_row_key("=", 0, "eq")]),
        rule("ground", "D", [atlas.bucket(lambda: cell(
            lambda d, gx, gy: station.paint_hall(d, rng, gx, gy)))]),
        rule("structures", "Ww", wall,
             [neighbour_key(0, -1, "Ww"), pattern_key(7, 5, 9)]),
        # Over the breach the wall is torn open to the coping.
        rule("structures", "W", [[], atlas.bucket(lambda: tile_of(
            lambda d: termini.paint_breach_top(d, rng, 0, 0, True)))],
            [neighbour_key(0, 1, "J")]),
        rule("structures", "J", [
            atlas.bucket(lambda f=first: tile_of(
                lambda d: termini.paint_breach(d, rng, 0, 0, f)))
            for first in (False, True)], [neighbour_key(-1, 0, "W")]),
        rule("structures", ":", [atlas.bucket(lambda: tile_of(
            lambda d: station.paint_litter(d, rng, 0, 0)))]),
    ] + flight(atlas, "D", up=True)
    # The rubbish tumbles off the heap wherever it is open.
    for side, (dx, dy) in (("e", (1, 0)), ("s", (0, 1)), ("n", (0, -1))):
        rules.append(rule("structures", ",-:", [[], atlas.bucket(
            lambda s=side: tile_of(
                lambda d: termini.paint_rubbish_edge(d, rng, 0, 0, s)))],
            [neighbour_key(-dx, -dy, ";")]))
    # The platform ends in a step down onto the ballast.
    for right in (False, True):
        rules.append(rule("foreground", "=Tn", [[], atlas.bucket(
            lambda r=right: tile_of(lambda d: rect(
                d, TILE - 3 if r else 0, 0, 3, TILE, (70, 68, 64))), 1)],
            [neighbour_key(1 if right else -1, 0, ",-")]))
    rules.append(rule("foreground", "T", termini_ends(
        atlas, station.paint_bench, "T"),
        [neighbour_key(-1, 0, "T"), neighbour_key(1, 0, "T")]))
    rules.append(rule("foreground", "n",
                      [atlas.bucket(lambda b=beam: tile_of(
                          lambda d: station.paint_post(d, Neighbourhood(
                              "n", lambda x, y, b=b: "n"
                              if (x == 1 and b) else "."), 0, 0)), 1)
                       for beam in (False, True)],
                      [neighbour_key(1, 0, "n")]))

    (cx, cy, cw, ch), = blocks(rows, "m")
    coach = Image.new("RGBA", (cw * TILE, ch * TILE), TRANSPARENT)
    station.paint_railcar(ImageDraw.Draw(coach), rng,
                          (0, 0, coach.width, coach.height),
                          wrecked=False, with_cab=False)
    footprint = [(x, y) for y, row in enumerate(rows)
                 for x, glyph in enumerate(row) if glyph == "V"]
    vx = min(x for x, _ in footprint)
    vy = min(y for _, y in footprint)
    vw = max(x for x, _ in footprint) - vx + 1
    vh = max(y for _, y in footprint) - vy + 1
    heap = [(x, y) for y, row in enumerate(rows)
            for x, glyph in enumerate(row) if glyph == ";"]
    hx = min(x for x, _ in heap)
    hy = min(y for _, y in heap)
    hw = max(x for x, _ in heap) - hx + 1
    hh = max(y for _, y in heap) - hy + 1
    return {
        "void": "#000000",
        "voidGlyph": "x",
        "rules": rules,
        "objects": [
            {"image": "termini_rubbish.png",
             "sprite": termini.rubbish_mountain(
                 [(x - hx, y - hy) for x, y in heap], rng),
             **placed(rows, hx, hy, hw, hh)},
            {"image": "termini_far_coach.png", "sprite": coach,
             **placed(rows, cx, cy, cw, ch)},
            {"image": "termini_derailed_train.png",
             "sprite": termini.derailed_train(
                 [(x - vx, y - vy) for x, y in footprint], rng),
             **placed(rows, vx, vy, vw, vh)},
        ],
    }


def termini_concourse(atlas: Atlas, rng) -> dict:
    """The rules that paint PlaceId.terminiConcourse: travertine, the shops
    along the back wall, the great board, the kiosk and the glass front."""
    rows = read_rows("termini-concourse-rows")
    floor = atlas.bucket(lambda: cell(
        lambda d, gx, gy: termini.paint_travertine_floor(d, rng, gx, gy)))
    floor_alt = atlas.bucket(lambda: cell(
        lambda d, gx, gy: termini.paint_travertine_floor(d, rng, gx, gy),
        1, 0))
    wall = [atlas.bucket(lambda t=top: tile_of(
        lambda d: termini.paint_concourse_wall(d, rng, 0, 0, t)))
        for top in (True, False)]
    rules = [
        rule("ground", ".:bKTIy#QiE", [floor, floor_alt], [parity_key()]),
        rule("structures", "WS", wall, [neighbour_key(0, -1, "WS")]),
        rule("structures", "w", [atlas.bucket(lambda: tile_of(
            lambda d: termini.paint_glass_front(d, rng, 0, 0)))]),
        rule("structures", "O", [atlas.bucket(lambda f=first: tile_of(
            lambda d: termini.paint_glass_door(d, 0, 0, f)), 1)
            for first in (True, False)], [neighbour_key(-1, 0, "O")]),
        rule("structures", "E", [atlas.bucket(lambda: tile_of(
            lambda d: termini.paint_opening(d, 0, 0)), 1)]),
        rule("structures", ":", [atlas.bucket(lambda: tile_of(
            lambda d: station.paint_litter(d, rng, 0, 0)))]),
        rule("structures", "b", [atlas.bucket(lambda: tile_of(
            lambda d: paint_blood(d, rng, 0, 0)))]),
        rule("structures", "y", [atlas.bucket(lambda: tile_of(
            lambda d: termini.paint_luggage_trolley(d, rng, 0, 0)))]),
    ]
    rules += rubble_rules(atlas, rng)
    rules += side_walls(atlas)
    rules.append(rule("foreground", "T", termini_ends(
        atlas, station.paint_bench, "T"),
        [neighbour_key(-1, 0, "T"), neighbour_key(1, 0, "T")]))
    rules.append(standing(atlas, "K", lambda d, px, py:
                          termini.paint_ticket_machine(d, rng, px, py)))
    rules.append(standing(atlas, "I", termini.paint_pillar))

    shops = (("BAR", "bar"), ("LIBRI", "books"), ("EDICOLA", "news"),
             ("FARMACIA", "chemist"))
    objects = []
    for index, (x, y, w, h) in enumerate(blocks(rows, "S")):
        name, kind = shops[index % len(shops)]
        objects.append({"image": f"termini_shop_{index}.png",
                        "sprite": termini.shop_front(w, name, rng, kind),
                        **placed(rows, x, y, w, h)})
    (bx, by, bw, bh), = blocks(rows, "Q")
    objects.append({"image": "termini_departures.png",
                    "sprite": termini.departures_board(bw, rng),
                    **placed(rows, bx, by, bw, bh)})
    (kx, ky, kw, kh), = blocks(rows, "i")
    objects.append({"image": "termini_kiosk.png",
                    "sprite": termini.kiosk(kw, rng),
                    **placed(rows, kx, ky, kw, kh)})
    return {"void": "#000000", "voidGlyph": "x", "rules": rules,
            "objects": objects}
