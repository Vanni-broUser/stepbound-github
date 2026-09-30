"""The children's carousel on the quay at the end of Molfetta's harbour
road: an eight-sided glass pavilion on a cream plinth, the horses and
the little cars standing still behind the panes, a white scalloped
valance over them and, round the crown, painted panels in gilded frames
with a lantern on every pilaster; over it all a white tent roof with a
pink cupola on its point. tools/tile_atlas_city.py places it over the
run of its glyph.
"""
from __future__ import annotations

import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from street_paint import TILE, rect, shade  # noqa: E402

CREAM = (234, 222, 198)
CREAM_DARK = (192, 176, 146)
GOLD = (210, 168, 76)
GOLD_DARK = (146, 108, 46)
WHITE = (242, 240, 234)
GLASS = (84, 110, 122)
GLASS_LIGHT = (150, 178, 188)
PINK = (226, 150, 162)
PINK_DARK = (176, 100, 116)
LAMP = (255, 222, 132)
# The rides behind the glass, and the colours of the painted panels.
RIDES = [(204, 52, 46), (232, 142, 42), (62, 112, 192), (240, 212, 84),
         (126, 64, 146), (62, 152, 92)]
SCENES = [(238, 122, 62), (72, 152, 204), (232, 202, 72), (204, 72, 92),
          (92, 172, 112)]


def _face(d, rng, x0, x1, base, dark):
    """One face of the pavilion, from its plinth at `base` up to the top of
    its crown, darker by `dark`; returns that top and the pilasters'
    columns."""
    w = x1 - x0

    def c(colour):
        return shade(colour, dark)
    # The plinth, its top lit.
    rect(d, x0, base - 5, w, 5, c(CREAM_DARK))
    rect(d, x0, base - 5, w, 1, c(CREAM))
    # The glass, the rides standing still behind it.
    top = base - 33
    rect(d, x0, top, w, 28, c(GLASS))
    panes = max(1, round(w / 12))
    edges = [x0 + round(i * w / panes) for i in range(panes + 1)]
    for left, right in zip(edges, edges[1:]):
        mid = (left + right) // 2
        colour = c(rng.choice(RIDES))
        ride_y = base - 17 + rng.randrange(-3, 3)
        rect(d, mid, top + 1, 1, ride_y - top - 1, c(GOLD))  # its pole
        if rng.random() < 0.6:  # a horse: body, neck and head, legs
            rect(d, mid - 4, ride_y, 8, 3, colour)
            rect(d, mid + 3, ride_y - 3, 2, 4, colour)
            rect(d, mid + 4, ride_y - 4, 3, 2, colour)
            rect(d, mid - 3, ride_y + 3, 1, 3, colour)
            rect(d, mid + 2, ride_y + 3, 1, 3, colour)
        else:  # a little car
            rect(d, mid - 4, ride_y + 1, 9, 4, colour)
            rect(d, mid - 2, ride_y - 1, 4, 2, c(GLASS_LIGHT))
            rect(d, mid - 3, ride_y + 5, 2, 2, (30, 30, 34))
            rect(d, mid + 2, ride_y + 5, 2, 2, (30, 30, 34))
        # the light on the pane, a slant across its top corner
        for i in range(4):
            rect(d, left + 3 + i, top + 2 + i * 2, 1, 2, c(GLASS_LIGHT))
    rect(d, x0, top + 10, w, 1, c(CREAM_DARK))  # the transom
    for x in edges:  # the pilasters, gold down the middle
        px = min(max(x - 1, x0), x1 - 3)
        rect(d, px, top, 3, 28, c(CREAM))
        rect(d, px + 1, top + 2, 1, 24, c(GOLD))
    # The valance: a white band and its scallops over the glass.
    rect(d, x0, top - 4, w, 4, c(WHITE))
    for sx in range(x0, x1 - 1, 4):
        d.ellipse([sx, top - 2, sx + 4, top + 2], fill=c(WHITE))
        rect(d, sx + 2, top - 3, 1, 1, c(GOLD))
    # The crown: a cream frieze, a painted panel in a gold frame between
    # every two pilasters, the frame's crest over it.
    crown = top - 17
    rect(d, x0, crown, w, 13, c(CREAM))
    rect(d, x0, crown + 12, w, 1, c(GOLD_DARK))
    # A wide face has one panel over every two panes.
    panels = edges[::2] if panes >= 4 else edges
    for left, right in zip(panels, panels[1:]):
        if right - left < 7:
            continue
        ml, mr = left + 2, right - 2
        mid = (ml + mr) // 2
        # the crest: a scrolled gable over the frame
        d.polygon([(ml, crown + 2), (ml + 3, crown - 3), (mid, crown - 6),
                   (mr - 3, crown - 3), (mr, crown + 2)],
                  fill=c(GOLD), outline=c(GOLD_DARK))
        rect(d, mid - 1, crown - 8, 3, 3, c(PINK))
        d.rounded_rectangle([ml, crown, mr, crown + 11], radius=3,
                            fill=c(GOLD), outline=c(GOLD_DARK))
        # the picture in it: sky, a meadow, a figure in bright clothes
        rect(d, ml + 2, crown + 2, mr - ml - 3, 8, c((150, 198, 224)))
        rect(d, ml + 2, crown + 7, mr - ml - 3, 3, c((110, 170, 96)))
        for fx in range(ml + 4, mr - 3, 7):
            rect(d, fx, crown + 3, 3, 2, c((236, 196, 160)))  # a head
            rect(d, fx - 1, crown + 5, 5, 4, c(rng.choice(SCENES)))
        for sx in (ml - 1, mr - 1):  # the curls either side
            rect(d, sx, crown + 4, 2, 4, c(GOLD_DARK))
    for x in edges:  # a lantern on every pilaster
        lx = min(max(x - 1, x0), x1 - 3)
        rect(d, lx, crown - 3, 3, 4, c(LAMP))
        rect(d, lx, crown - 4, 3, 1, c(GOLD_DARK))
    return crown - 4, edges


def paint_carousel(d, px, py, tiles_w=5, tiles_h=3):
    """The pavilion over `tiles_w` by `tiles_h` cells from (px, py): three
    of its eight faces towards the viewer, the two slanting ones set back
    and in shadow, the roof rising about three cells over its footprint.
    Its own stream of numbers, so the place's is left as it was."""
    rng = random.Random("stepbound/harbour/carousel")
    w = tiles_w * TILE
    bottom = py + tiles_h * TILE
    cx = px + w // 2
    side = w // 6
    d.ellipse([px - 3, bottom - 13, px + w + 2, bottom + 1], fill=(36, 34, 36))
    faces = ((px + 1, px + 1 + side, 5, -40),
             (px + w - 1 - side, px + w - 1, 5, -58),
             (px + 1 + side, px + w - 1 - side, 0, 0))
    # Where the crowns end: the roof sits on them, and the crests and the
    # lanterns stand in front of its eave.
    front_top = bottom - 2 - 50
    side_top = front_top - 5
    lx0, rx1 = faces[0][0], faces[1][1]
    fx0, fx1 = faces[2][0], faces[2][1]
    # The roof: a white tent over the three faces, each panel of it lit by
    # how it faces, ribs running up to the cupola.
    apex = front_top - 30
    eave = 2
    left = (lx0 - eave, side_top + 1)
    front_l, front_r = (fx0, front_top + 1), (fx1, front_top + 1)
    right = (rx1 + eave, side_top + 1)
    d.polygon([left, front_l, (cx, apex)], fill=shade(WHITE, -12))
    d.polygon([front_l, front_r, (cx, apex)], fill=WHITE)
    d.polygon([front_r, right, (cx, apex)], fill=shade(WHITE, -46))
    for base in (front_l, front_r):
        d.line([base, (cx, apex)], fill=shade(WHITE, -30))
    for t in (0.33, 0.66):  # the seams between the canvas panels
        for (ax, ay), (bx, by) in ((left, front_l), (front_l, front_r),
                                   (front_r, right)):
            sx = round(ax + (bx - ax) * t)
            sy = round(ay + (by - ay) * t)
            d.line([(sx, sy), (cx, apex)], fill=shade(WHITE, -22))
    # the scalloped eave along the bottom of the roof, gold-edged
    for (ax, ay), (bx, by) in ((left, front_l), (front_l, front_r),
                               (front_r, right)):
        steps = max(1, abs(bx - ax) // 4)
        for i in range(steps):
            sx = ax + (bx - ax) * i // steps
            sy = ay + (by - ay) * i // steps
            d.ellipse([sx, sy - 1, sx + 4, sy + 3], fill=shade(WHITE, -6))
            rect(d, sx + 2, sy + 3, 1, 1, GOLD)
    for x0, x1, lift, dark in faces:
        _face(d, rng, x0, x1, bottom - 2 - lift, dark)
    # The cupola on the point, its gold spire and ball.
    d.ellipse([cx - 5, apex - 7, cx + 5, apex + 3], fill=PINK,
              outline=PINK_DARK)
    rect(d, cx - 4, apex - 3, 3, 3, shade(PINK, 20))
    rect(d, cx - 5, apex + 1, 11, 2, GOLD)
    rect(d, cx - 1, apex - 14, 2, 8, GOLD)
    rect(d, cx + 1, apex - 12, 1, 6, GOLD_DARK)
    d.ellipse([cx - 2, apex - 17, cx + 2, apex - 13], fill=GOLD)
