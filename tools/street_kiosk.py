"""The newsstand on the promenade across from the harbour's crossroads: a
glazed kiosk in a dark green frame under a flat roof, its name on the
cream fascia, the striped awning torn to rags, the panes smashed, one
shutter jammed half down and the magazines blown all over the paving.
tools/tile_atlas_city.py places it over the run of its glyph.
"""
from __future__ import annotations

import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from street_paint import TILE, paint_text, rect, shade  # noqa: E402

FRAME = (34, 64, 46)
FRAME_DARK = (22, 40, 30)
ROOF = (112, 116, 110)
FASCIA = (214, 206, 186)
GLASS = (70, 92, 100)
HOLE = (16, 16, 18)
SHARD = (190, 214, 222)
STRIPE = (40, 110, 60)
RUST = (130, 72, 40)
MAGAZINES = [(204, 60, 50), (240, 200, 70), (70, 130, 200), (236, 236, 226),
             (220, 120, 170), (90, 170, 100)]


def _magazines(d, rng, x0, y0, x1, y1, count):
    """Magazines and papers scattered over a stretch of ground."""
    for _ in range(count):
        x = rng.randrange(x0, x1)
        y = rng.randrange(y0, y1)
        colour = rng.choice(MAGAZINES)
        if rng.random() < 0.5:
            rect(d, x, y, 3, 2, colour)
        else:
            rect(d, x, y, 2, 3, colour)
        rect(d, x, y, 1, 1, shade(colour, 40))


def paint_kiosk(d, px, py, tiles_w=3, tiles_h=2):
    """The kiosk over `tiles_w` by `tiles_h` cells from (px, py), its flat
    roof seen from above rising about a cell over its footprint. Its own
    stream of numbers, so the place's is left as it was."""
    rng = random.Random("stepbound/harbour/kiosk")
    w = tiles_w * TILE
    bottom = py + tiles_h * TILE
    d.ellipse([px - 3, bottom - 8, px + w + 3, bottom + 2], fill=(38, 36, 38))
    # The front, towards the viewer: a green frame, three panes.
    front_top = bottom - 26
    rect(d, px, front_top, w, 24, FRAME)
    rect(d, px + 1, bottom - 5, w - 2, 3, FRAME_DARK)  # the kick plate
    panes = [(px + 3 + i * 15, 12) for i in range(3)]
    for i, (x, pw) in enumerate(panes):
        top = front_top + 3
        rect(d, x, top, pw, 16, GLASS)
        # the racks behind the glass, still half full of magazines
        for row in range(3):
            for col in range(0, pw - 2, 3):
                if rng.random() < 0.6:
                    rect(d, x + 1 + col, top + 2 + row * 5, 2, 3,
                         shade(rng.choice(MAGAZINES), -40))
        if i == 0:  # smashed: a black hole ringed with shards
            d.polygon([(x + 2, top + 3), (x + 7, top + 1), (x + 11, top + 5),
                       (x + 9, top + 13), (x + 3, top + 14), (x + 1, top + 8)],
                      fill=HOLE)
            for sx, sy in ((x + 1, top + 2), (x + 8, top + 1),
                           (x + 10, top + 12), (x + 2, top + 13)):
                rect(d, sx, sy, 1, 2, SHARD)
        elif i == 1:  # the shutter jammed half down, dented and tagged
            rect(d, x, top, pw, 9, (150, 150, 146))
            for sy in range(top + 1, top + 9, 2):
                rect(d, x, sy, pw, 1, (120, 120, 118))
            rect(d, x + 2, top + 3, 7, 2, (200, 50, 140))  # the tag
            rect(d, x + 4, top + 5, 1, 2, (200, 50, 140))
            rect(d, x + 1, top + 9, pw - 2, 1, RUST)
        else:  # cracked right across, a slant of light on what is left
            d.line([(x + 1, top + 12), (x + 6, top + 6), (x + 11, top + 2)],
                   fill=SHARD)
            d.line([(x + 6, top + 6), (x + 9, top + 14)], fill=SHARD)
        rect(d, x - 1, top, 1, 16, FRAME_DARK)
    # The counter under the panes, a heap of papers slid off it.
    rect(d, px + 2, bottom - 7, w - 4, 2, (96, 100, 98))
    # The fascia with the name, letters gone, and the torn awning.
    rect(d, px - 1, front_top - 7, w + 2, 7, FASCIA)
    rect(d, px - 1, front_top - 1, w + 2, 1, shade(FASCIA, -50))
    paint_text(d, px + (w - 27) // 2, front_top - 6, "EDICOLA",
               (40, 60, 50), missing=(3,))
    rect(d, px + w - 9, front_top - 6, 6, 3, (60, 54, 48))  # soot
    for i in range(0, w, 3):
        colour = STRIPE if (i // 3) % 2 else (224, 220, 204)
        if rng.random() < 0.3:
            continue  # torn off
        drop = rng.choice((2, 3, 3, 5, 8))
        rect(d, px + i, front_top, 3, drop, colour)
    # The roof, flat, seen from above: its rim, dented, rust at a corner.
    roof_top = front_top - 7 - 12
    rect(d, px - 2, roof_top, w + 4, 12, ROOF)
    rect(d, px - 2, roof_top, w + 4, 2, FRAME)
    rect(d, px - 2, roof_top, 2, 12, FRAME)
    rect(d, px + w, roof_top, 2, 12, FRAME_DARK)
    d.ellipse([px + 10, roof_top + 3, px + 22, roof_top + 9],
              fill=shade(ROOF, -24))  # the dent
    rect(d, px + w - 12, roof_top + 2, 8, 4, RUST)
    rect(d, px + 4, roof_top + 8, 5, 2, (70, 72, 68))
    # A rack knocked over at the corner, and the papers everywhere.
    rect(d, px + w - 2, bottom - 4, 8, 3, FRAME_DARK)
    _magazines(d, rng, px - 6, bottom - 4, px + w + 6, bottom + 6, 18)
