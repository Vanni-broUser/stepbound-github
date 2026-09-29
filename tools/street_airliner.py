"""The airliner that came down on the north district, as the street sees
it: its body, wings and engines drawn over the rows it lies on, its tears,
scorch marks and wreckage. tools/tile_atlas_city.py places it; the cabin
inside is tools/build_airliner.py's.
"""
from __future__ import annotations

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from street_paint import (  # noqa: E402
    CABIN_WINDOW,
    HULL,
    HULL_DARK,
    HULL_LIGHT,
    HULL_SEAM,
    HULL_SHADE,
    HULL_SHADOW,
    LIVERY,
    LIVERY_LIGHT,
    NACELLE,
    NACELLE_DARK,
    SCORCH,
    TILE,
    WING,
    WING_DARK,
    rect,
    shade,
)

# ------------------------------------------------------------------- main


def airliner_body(level):
    """The columns of the fuselage, each with the rows it covers. The body
    is drawn from these as one tube rather than tile by tile, so the crown,
    the livery and the windows run the length of it without stepping."""
    body = {}
    for y in range(level.height):
        for x in range(level.width):
            if level.at(x, y) in "_[":
                top, bottom = body.get(x, (y, y))
                body[x] = (min(top, y), max(bottom, y))
    return body


def _smooth(values, window, passes=2):
    """A box blur over a list of pixel heights: it turns the staircase the
    tile grid makes of a long diagonal object into a straight line."""
    out = list(values)
    half = window // 2
    for _ in range(passes):
        source = out
        out = []
        for i in range(len(source)):
            lo, hi = max(0, i - half), min(len(source), i + half + 1)
            out.append(sum(source[lo:hi]) / (hi - lo))
    return out


def airliner_edges(body):
    """The top and bottom of the tube at every pixel across it: read off
    the middle of each column, drawn straight between them, then smoothed
    so the body rides up the block instead of stepping up it."""
    columns = sorted(body)
    marks = [(x * TILE + TILE // 2, body[x][0] * TILE, (body[x][1] + 1) * TILE)
             for x in columns]
    first, last = columns[0] * TILE, (columns[-1] + 1) * TILE
    tops, bottoms = [], []
    for px in range(first, last):
        if px <= marks[0][0]:
            top, bottom = marks[0][1], marks[0][2]
        elif px >= marks[-1][0]:
            top, bottom = marks[-1][1], marks[-1][2]
        else:
            i = next(i for i in range(len(marks) - 1) if marks[i + 1][0] > px)
            (ax, at, ab), (bx, bt, bb) = marks[i], marks[i + 1]
            t = (px - ax) / (bx - ax)
            top, bottom = at + (bt - at) * t, ab + (bb - ab) * t
        tops.append(top)
        bottoms.append(bottom)
    tops = _smooth(tops, 3 * TILE)
    bottoms = _smooth(bottoms, 3 * TILE)
    return {px: (round(tops[i]), round(bottoms[i]))
            for i, px in enumerate(range(first, last))}


def paint_airliner(d, rng, level):
    """The airliner across the crossroads. Everything it covers is laid
    down in soot first, so nothing of the street or the roofs shows through
    where the drawn shape and the tiles disagree; then the fuselage goes on
    as one smooth tube, lit along the crown and in shadow along the belly,
    with the livery, the cabin windows, the flight deck at the nose and the
    tear `[` where the skin is peeled back; then the wings."""
    body = airliner_body(level)
    if not body:
        return
    for y in range(level.height):
        for x in range(level.width):
            if level.at(x, y) in "_+[":
                rect(d, x * TILE, y * TILE, TILE, TILE, SCORCH)

    paint_airliner_wings(d, rng, level, tail=True)

    edges = airliner_edges(body)
    nose = min(edges)
    for px, (top, bottom) in sorted(edges.items()):
        h = bottom - top
        rect(d, px, top, 1, h, HULL)
        rect(d, px, top, 1, max(3, h // 5), HULL_LIGHT)
        rect(d, px, bottom - h // 4, 1, h // 4, HULL_SHADE)
        rect(d, px, bottom - 3, 1, 3, HULL_DARK)
        rect(d, px, top, 1, 1, HULL_DARK)
        line = top + round(h * 0.64)
        rect(d, px, line, 1, 3, LIVERY)
        rect(d, px, line, 1, 1, LIVERY_LIGHT)
        if (px - nose) % 6 < 3 and px > nose + 30:
            rect(d, px, top + round(h * 0.30), 1, 3, CABIN_WINDOW)
        if (px - nose) % 48 == 0:
            rect(d, px, top + 2, 1, h - 5, HULL_SEAM)
        if rng.random() < 0.08:  # soot, and the dirt of the days since
            rect(d, px, top + rng.randrange(2, max(3, h - 3)),
                 rng.randint(1, 3), 1, shade(HULL_SHADE, -34))
        rect(d, px, bottom, 1, 3, HULL_SHADOW)  # the shadow it throws

    paint_airliner_nose(d, edges, nose)
    paint_airliner_wings(d, rng, level, tail=False)

    for y in range(level.height):
        for x in range(level.width):
            if level.at(x, y) == "[":
                paint_airliner_tear(d, level, x, y)


def paint_airliner_nose(d, edges, nose):
    """The nose, scorched and rounded off, the flight deck glazed over."""
    top, bottom = edges[nose]
    rect(d, nose, top, 3, bottom - top, SCORCH)
    rect(d, nose + 3, top, 2, 3, HULL_DARK)
    rect(d, nose + 3, bottom - 3, 2, 3, HULL_DARK)
    rect(d, nose + 5, top + 4, 7, 4, CABIN_WINDOW)
    rect(d, nose + 5, top + 4, 7, 1, LIVERY_LIGHT)


def _hull(points):
    """The convex hull of a set of points, counter-clockwise (Andrew's
    monotone chain): a wing drawn from the hull of its tiles comes out as
    the straight-edged panel it is instead of a staircase."""
    points = sorted(set(points))
    if len(points) < 3:
        return points

    def half(source):
        out = []
        for p in source:
            while len(out) >= 2:
                (ax, ay), (bx, by) = out[-2], out[-1]
                if (bx - ax) * (p[1] - ay) - (by - ay) * (p[0] - ax) > 0:
                    break
                out.pop()
            out.append(p)
        return out[:-1]

    return half(points) + half(points[::-1])


def _wing_groups(level):
    """The `+` tiles, grouped into the pieces they make: two wings and two
    tailplanes, each of them one run of touching tiles."""
    left = {(x, y) for y in range(level.height) for x in range(level.width)
            if level.at(x, y) == "+"}
    groups = []
    while left:
        seed = left.pop()
        group, queue = {seed}, [seed]
        while queue:
            x, y = queue.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    other = (x + dx, y + dy)
                    if other in left:
                        left.remove(other)
                        group.add(other)
                        queue.append(other)
        groups.append(group)
    return groups


def _wing_axes(group):
    """A wing's own two directions: along the span, root to tip, and
    across the chord. Read off the spread of its tiles, so the panel lines
    follow the wing however it is swept."""
    pts = [(x * TILE + TILE / 2, y * TILE + TILE / 2) for x, y in group]
    mx = sum(p[0] for p in pts) / len(pts)
    my = sum(p[1] for p in pts) / len(pts)
    sxx = sum((p[0] - mx) ** 2 for p in pts) / len(pts)
    syy = sum((p[1] - my) ** 2 for p in pts) / len(pts)
    sxy = sum((p[0] - mx) * (p[1] - my) for p in pts) / len(pts)
    angle = 0.5 * math.atan2(2 * sxy, sxx - syy)
    span = (math.cos(angle), math.sin(angle))
    chord = (-span[1], span[0])
    return (mx, my), span, chord


def _inset(hull, amount):
    """The same shape, pulled in from its edges, so the soot laid under it
    shows as a rim instead of the panel butting against the roof."""
    mx = sum(x for x, _ in hull) / len(hull)
    my = sum(y for _, y in hull) / len(hull)
    out = []
    for x, y in hull:
        dx, dy = x - mx, y - my
        length = math.hypot(dx, dy) or 1
        scale = max(0.0, (length - amount)) / length
        out.append((mx + dx * scale, my + dy * scale))
    return out


def _wing_line(d, group, start, end, colour, thick=1):
    """A panel line down a wing, kept to the wing: the hull is not a
    rectangle, so a line drawn across its extent would run out over the
    roofs at the corners."""
    steps = int(max(abs(end[0] - start[0]), abs(end[1] - start[1]))) + 1
    for i in range(steps):
        t = i / max(1, steps - 1)
        px = round(start[0] + (end[0] - start[0]) * t)
        py = round(start[1] + (end[1] - start[1]) * t)
        if (px // TILE, py // TILE) in group:
            rect(d, px, py, thick, thick, colour)


def paint_airliner_wings(d, rng, level, tail):
    """The wings and the tailplanes, swept back off the body and drawn
    from the hull of their tiles so they come out as the straight-edged
    panels they are. `tail` lays down the shadow they throw, which goes
    on before the fuselage does so the body is not drawn over its own
    wings' shade."""
    body = airliner_body(level)
    if not body:
        return
    centre = (sum(body) / len(body) * TILE,
              sum((t + b) / 2 for t, b in body.values()) / len(body) * TILE)
    for group in _wing_groups(level):
        hull = _hull([(x * TILE + cx, y * TILE + cy)
                      for x, y in group
                      for cx in (0, TILE) for cy in (0, TILE)])
        if len(hull) < 3:
            continue
        panel = _inset(hull, 3)
        if tail:
            d.polygon([(x, y + 5) for x, y in panel], fill=HULL_SHADOW)
            continue
        d.polygon(panel, fill=WING_DARK)
        d.polygon(_inset(panel, 2), fill=WING)
        (mx, my), span, chord = _wing_axes(group)
        along = [(p[0] - mx) * span[0] + (p[1] - my) * span[1] for p in panel]
        across = [(p[0] - mx) * chord[0] + (p[1] - my) * chord[1] for p in panel]
        reach, width = max(along) - min(along), max(across) - min(across)

        def at(a, c):
            return (mx + span[0] * a + chord[0] * c,
                    my + span[1] * a + chord[1] * c)

        # the spar and the panel joints spanwise down the wing, the
        # leading edge bright, the flaps hinged off the back
        for share, colour, thick in ((-0.42, shade(WING, 50), 2),
                                     (-0.2, shade(WING, -32), 1),
                                     (0.06, shade(WING, 24), 1),
                                     (0.28, shade(WING, -26), 1),
                                     (0.42, shade(WING, -48), 1)):
            _wing_line(d, group,
                       at(min(along), width * share),
                       at(max(along), width * share), colour, thick)
        for _ in range(len(group) // 2):  # the dirt of the days since
            x, y = rng.choice(sorted(group))
            rect(d, x * TILE + rng.randrange(10), y * TILE + rng.randrange(12),
                 rng.randint(3, 6), 1, shade(WING, -40))
        if len(group) >= 15:
            paint_airliner_engine(d, group, centre, (mx, my), reach, span)


def paint_airliner_engine(d, group, centre, mid, reach, span):
    """The engine slung under a wing, half a span out from the body: the
    one thing that says aeroplane from any distance."""
    tip = max(group, key=lambda t: (t[0] * TILE - centre[0]) ** 2
              + (t[1] * TILE - centre[1]) ** 2)
    out = 1 if ((tip[0] * TILE - mid[0]) * span[0]
                + (tip[1] * TILE - mid[1]) * span[1]) > 0 else -1
    ex = round(mid[0] + span[0] * out * reach * 0.3)
    ey = round(mid[1] + span[1] * out * reach * 0.3)
    rect(d, ex - 13, ey - 7, 26, 14, SCORCH)
    rect(d, ex - 12, ey - 6, 24, 12, NACELLE_DARK)
    rect(d, ex - 12, ey - 6, 24, 3, NACELLE)
    rect(d, ex - 12, ey + 4, 24, 2, SCORCH)
    rect(d, ex - 12, ey - 6, 4, 12, CABIN_WINDOW)  # the intake
    rect(d, ex - 11, ey - 4, 2, 8, NACELLE)
    rect(d, ex + 9, ey - 3, 4, 6, SCORCH)  # and the cold jet pipe


def paint_airliner_tear(d, level, x, y):
    """The skin peeled back off the belly: the way into the cabin."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, HULL_DARK)
    rect(d, px, py + 2, TILE, 13, (18, 18, 22))
    for dx, w in ((0, 3), (6, 2), (11, 4)):
        rect(d, px + dx, py, w, 4, HULL_LIGHT)
    if level.at(x - 1, y) != "[":
        rect(d, px, py + 2, 2, 12, HULL_SHADE)
    if level.at(x + 1, y) != "[":
        rect(d, px + TILE - 2, py + 2, 2, 12, HULL_SHADE)
    rect(d, px, py + TILE - 1, TILE, 1, SCORCH)


def paint_airliner_scorch(d, rng, level, x, y):
    """The ground around the wreck, burnt and scraped where it came down."""
    px, py = x * TILE, y * TILE
    for _ in range(5):
        rect(d, px + rng.randrange(13), py + rng.randrange(13),
             rng.randint(2, 4), rng.randint(1, 2), SCORCH)


def paint_airliner_wreckage(d, rng, px, py):
    """Skin panels, seat cushions and cabin baggage thrown clear of it."""
    for _ in range(4):
        rect(d, px + rng.randrange(12), py + rng.randrange(12),
             rng.randint(3, 5), rng.randint(1, 3),
             shade(WING, rng.randrange(-40, 20)))
    rect(d, px + rng.randrange(11), py + rng.randrange(11), 4, 3,
         rng.choice(((92, 66, 46), (46, 62, 84), (120, 40, 36))))
    rect(d, px + rng.randrange(14), py + rng.randrange(14), 2, 1, SCORCH)
