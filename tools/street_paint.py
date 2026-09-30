"""The city painters' brushes: the palette, the glyphs the rows are
written in, the storefront tables, the pixel font and the text it writes,
`rect` and `shade`, the level rows and the `Level` that reads them. Every
painter of the city (street_ground, street_buildings, street_props,
street_airliner) and every place of the atlas paints with these.

Everything is 16x16 tiles in 3/4 view.
"""
from __future__ import annotations

import glob
import os
import re

from PIL import ImageDraw


TILE = 16
LEVELS_DIR = os.path.join("lib", "core", "levels")

ROAD_GLYPHS = set(".-|ZVcɔ▔▏")
WALK_GLYPHS = set("=")
BUILDING_GLYPHS = set("BHfKMGW#%0\u00a7\u00c6")
FACADE_GLYPHS = set("Hf")
# Street furniture: it stands on the footway, not in the road, so it
# looks for its floor up and down its column as well as sideways.
FOOTWAY_GLYPHS = set("T/F¤")

ASPHALT = (44, 46, 52)
ASPHALT_SPECKLE = (52, 54, 60)
CRACK = (30, 31, 36)
OIL = (34, 34, 40)
WALK = (98, 96, 92)
WALK_ALT = (86, 84, 82)
WALK_JOINT = (72, 70, 68)
CURB = (132, 128, 120)
CURB_SHADOW = (60, 58, 58)
LANE = (190, 170, 90)
ZEBRA = (170, 166, 150)
RED = (170, 30, 30)
CREAM = (206, 196, 176)
SHOP_DARK = (30, 26, 26)
PANE = (34, 40, 56)
PANE_LIT = (230, 150, 60)
PANE_BROKEN = (14, 12, 14)
PAVING = (120, 112, 100)
PAVING_ALT = (108, 102, 92)
PAVING_JOINT = (84, 78, 72)
WOOD = (122, 92, 60)
WOOD_DARK = (86, 62, 40)
NAIL = (40, 36, 34)
SCORCH = (20, 16, 16)
BLOOD = (92, 14, 14)
BLOOD_DARK = (60, 10, 10)
DEBRIS = [(70, 66, 60), (90, 80, 66), (60, 56, 54), (110, 96, 76)]
# The airliner down on the crossroads behind the hypermarket: bare skin,
# the livery along its side, and what the fire left of both.
HULL = (206, 204, 198)
HULL_LIGHT = (234, 232, 226)
HULL_SHADE = (148, 148, 146)
HULL_DARK = (86, 86, 88)
HULL_SEAM = (172, 172, 170)
LIVERY = (46, 70, 108)
LIVERY_LIGHT = (72, 104, 150)
CABIN_WINDOW = (26, 30, 38)
WING = (160, 160, 160)
WING_DARK = (92, 92, 94)
NACELLE = (150, 152, 156)
NACELLE_DARK = (86, 88, 94)
HULL_SHADOW = (28, 26, 28)
FACADES = [
    ((116, 58, 48), (80, 38, 34)),
    ((96, 98, 104), (68, 70, 76)),
    ((150, 132, 104), (110, 94, 72)),
    ((70, 84, 96), (50, 60, 70)),
]
# The old town by the harbour: whitewashed limestone, green shutters, flat
# pale terraces instead of dark roofs.
OLD_TOWN_STONE = [(214, 208, 192), (202, 196, 180), (222, 218, 204), (194, 188, 172)]
OLD_TOWN_ROOFS = [(170, 164, 150), (160, 154, 142), (180, 174, 160), (152, 148, 138)]
SHUTTERS = [(44, 142, 104), (52, 150, 78), (40, 126, 96)]
DOOR_GREEN = (40, 66, 52)
SEA = (28, 38, 38)
SEA_DARK = (22, 30, 32)
SEA_SPECKLE = (36, 48, 46)
SEA_WAVE = (54, 68, 64)
ALGAE = [(38, 52, 34), (52, 70, 38), (68, 88, 42)]
ROOFS = [(66, 60, 58), (74, 70, 72), (60, 64, 70), (80, 72, 64)]
CLOTHES = [(70, 80, 110), (110, 60, 50), (80, 90, 70), (60, 60, 66), (130, 120, 96)]
SKIN = [(200, 160, 130), (150, 110, 84), (180, 190, 150)]
HAIR = [(40, 30, 26), (90, 70, 40), (20, 20, 22)]
OUTLINE = (16, 12, 14)

# Shops along a street, by band top row: (first column, width, kind).
# They are decorations: every one is wrecked and shut. The rest of a band
# with shops gets ordinary houses.
STREET_STOREFRONTS = {
    # The dead-end street off the road north: the burning window at column
    # 33 is left to the houses.
    14: [
        (20, 6, "pizzeria"),
        (28, 4, "bar"),
        (34, 6, "burger"),
    ],
    38: [
        (4, 5, "kebab"),
        (9, 4, "alimentari"),
        (29, 5, "abbigliamento"),
    ],
}
NORTH_STOREFRONTS = {
    27: [(38, 7, "barsport")],
    30: [
        (70, 5, "kebab2"),
        # By the camp: the same shop as the one on the monument's square,
        # its door at column 82.
        (79, 6, "elettronica_aperta"),
    ],
}
# On the road east of the monument's square, the Elettronica, its door
# `h` at column 46: the one shop in town still open.
# On the road west of it, the chemist's, shut like the rest.
MONUMENT_SQUARE_STOREFRONTS = {
    9: [(5, 6, "farmacia"), (44, 5, "elettronica_aperta")],
}
MALL_NORTH_STOREFRONTS = {
    3: [
        (4, 5, "pizzeria"),
        (9, 6, "alimentari"),
        (17, 6, "barsport"),
        (25, 7, "elettronica"),
        (34, 5, "abbigliamento"),
        (39, 7, "gelateria"),
    ],
}
# On Piazza dei Cinquecento, in the palazzi west of Termini.
ROME_PIAZZA_STOREFRONTS = {
    # On the road west to the Baths of Diocletian, three little shops, all
    # shut; by the station, the souvenir shop.
    1: [(19, 6, "tabacchi"), (30, 4, "forno"), (40, 5, "ferramenta"),
        (49, 6, "souvenir")],
    # On Piazza di Santa Maria Maggiore, east of Via Cavour, each shop to
    # whole palazzi and a palazzo with none between them: the bar, the
    # trattoria across the ground floor of two, the accountants in one.
    35: [(85, 5, "barroma"), (94, 11, "trattoria"), (109, 6, "studio")],
}
HARBOUR_STOREFRONTS = {
    7: [(123, 5, "arcobaleno")],  # up the alley, its door `h` at column 125
    15: [
        (54, 6, "gelateria"),
        (78, 6, "pescheria"),  # past the alley, with the palazzi east of it
    ],
}
RAINBOW = [(220, 60, 50), (240, 150, 50), (240, 220, 70), (90, 190, 80),
           (70, 150, 220), (130, 90, 200)]

# 3x5 pixel font for shop signs.
FONT = {
    "A": ("010", "101", "111", "101", "101"),
    "B": ("110", "101", "110", "101", "110"),
    "C": ("011", "100", "100", "100", "011"),
    "D": ("110", "101", "101", "101", "110"),
    "E": ("111", "100", "110", "100", "111"),
    "F": ("111", "100", "110", "100", "100"),
    "G": ("011", "100", "101", "101", "011"),
    "H": ("101", "101", "111", "101", "101"),
    "I": ("111", "010", "010", "010", "111"),
    "K": ("101", "101", "110", "101", "101"),
    "L": ("100", "100", "100", "100", "111"),
    "M": ("101", "111", "111", "101", "101"),
    "N": ("110", "101", "101", "101", "101"),
    "O": ("010", "101", "101", "101", "010"),
    "P": ("110", "101", "110", "100", "100"),
    "R": ("110", "101", "110", "101", "101"),
    "S": ("011", "100", "010", "001", "110"),
    "T": ("111", "010", "010", "010", "010"),
    "U": ("101", "101", "101", "101", "111"),
    "V": ("101", "101", "101", "101", "010"),
    "Z": ("111", "001", "010", "100", "111"),
    " ": ("000", "000", "000", "000", "000"),
    "0": ("010", "101", "101", "101", "010"),
    "5": ("111", "100", "110", "001", "110"),
    # The platform numbers at Termini.
    "1": ("010", "110", "010", "010", "111"),
    "2": ("110", "001", "010", "100", "111"),
    "3": ("110", "001", "010", "001", "110"),
    "4": ("101", "101", "111", "001", "001"),
    "6": ("011", "100", "110", "101", "010"),
    "7": ("111", "001", "010", "010", "010"),
    "8": ("010", "101", "010", "101", "010"),
    "9": ("010", "101", "011", "001", "110"),
    "%": ("101", "001", "010", "100", "101"),
    "-": ("000", "000", "111", "000", "000"),
    "!": ("010", "010", "010", "000", "010"),
}


def text_width(text: str) -> int:
    return len(text) * 4 - 1


def paint_text(d, x, y, text, colour, missing=(), scale=1, tilted=()):
    """Draws `text` with the 3x5 font, `scale` pixels per dot; letters whose
    index is in `missing` have fallen off the sign, the ones in `tilted`
    hang crooked from a single screw."""
    for i, letter in enumerate(text):
        if i in missing:
            continue
        for row, bits in enumerate(FONT[letter]):
            for col, bit in enumerate(bits):
                if bit == "1":
                    drop = (col * scale) // 2 if i in tilted else 0
                    rect(d, x + (i * 4 + col) * scale, y + row * scale + drop,
                         scale, scale, colour)


def read_rows(marker: str = "level-rows") -> list[str]:
    """The ASCII rows between `// <marker>-start` and `// <marker>-end`, in
    whichever place file under lib/core/levels holds them."""
    for path in sorted(glob.glob(os.path.join(LEVELS_DIR, "**", "*.dart"), recursive=True)):
        with open(path, encoding="utf-8") as source:
            text = source.read()
        if f"// {marker}-start" in text:
            block = text.split(f"// {marker}-start", 1)[1].split(f"// {marker}-end", 1)[0]
            return re.findall(r"'([^']+)'", block)
    raise ValueError(f"no rows marked {marker} in {LEVELS_DIR}")


def rect(d: ImageDraw.ImageDraw, x, y, w, h, c) -> None:
    if w > 0 and h > 0:
        d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)


def shade(c, amount):
    return tuple(max(0, min(255, v + amount)) for v in c)


class Level:
    def __init__(self, rows: list[str], storefronts=None, old_town=False,
                 one_roof=None):
        self.rows = rows
        self.storefronts = storefronts or {}
        # Old town: white palazzi with green shutters, pale terraces.
        self.old_town = old_town
        # One building, not a patchwork: (row, column) -- from that row
        # down and west of that column the roof is painted whole (the back
        # of the hypermarket, in the north street).
        self.one_roof = one_roof
        self.height = len(rows)
        self.width = len(rows[0])

    def at(self, x: int, y: int) -> str:
        if 0 <= x < self.width and 0 <= y < self.height:
            return self.rows[y][x]
        return "B"

    def is_road(self, x, y) -> bool:
        return self.at(x, y) in ROAD_GLYPHS

    def is_building(self, x, y) -> bool:
        return self.at(x, y) in BUILDING_GLYPHS

    @staticmethod
    def _floor(glyph: str) -> str | None:
        """The floor `glyph` paves, if it paves one."""
        if glyph in WALK_GLYPHS:
            return "="
        if glyph in ROAD_GLYPHS:
            return "."
        if glyph in "PLY,":
            return glyph
        return None

    def _floor_along(self, x: int, y: int, dx: int, dy: int):
        """The nearest floor from (x, y) one way, and how many tiles off it
        is, never looking through a wall: a prop is paved with the street it
        stands in, not with what lies beyond the building beside it."""
        nx, ny, away = x + dx, y + dy, 1
        while (0 <= nx < self.width and 0 <= ny < self.height
               and not self.is_building(nx, ny)):
            floor = self._floor(self.rows[ny][nx])
            if floor is not None:
                return floor, away
            nx, ny, away = nx + dx, ny + dy, away + 1
        return None, 0

    def surface(self, x: int, y: int) -> str:
        """Floor under a prop or actor (`=` sidewalk, `.` road, `P` paving,
        `L` parking, `Y` stairs): the nearest floor beside it, never through
        a wall, and where two are equally near, whichever more of them say.

        A vehicle belongs to the carriageway it stands in, which runs along
        its row: a car in the outside lane has the kerb down one whole side
        of it and only the lane it blocks at its ends, so looking all round
        used to pave it with the sidewalk. Street furniture belongs instead
        to the footway beside it, and a footway runs whichever way its
        street does, so the lights and the signs look up and down their
        column too -- otherwise the ones on a side street's pavement take
        the tarmac of the road they stand at the mouth of."""
        glyph = self.at(x, y)
        floor = self._floor(glyph)
        if floor is not None:
            return floor
        if glyph not in FOOTWAY_GLYPHS and 0 < y < self.height - 1:
            # Right between two cells of one floor, a prop is on that floor:
            # a car parked across a road that runs north-south has the
            # carriageway above and below it, whatever its row says.
            above = self._floor(self.rows[y - 1][x])
            if above is not None and above == self._floor(self.rows[y + 1][x]):
                return above
        ways = [(-1, 0), (1, 0)]
        if glyph in FOOTWAY_GLYPHS:
            ways += [(0, -1), (0, 1)]
        found = [self._floor_along(x, y, dx, dy) for dx, dy in ways]
        near = [f for f, away in found
                if f is not None and away == min(
                    (a for g, a in found if g is not None), default=0)]
        if glyph in FOOTWAY_GLYPHS and any(f != "." for f in near):
            # Nothing on a post stands in the carriageway: at a corner, with
            # the road on two sides of it and the kerb on the others, the
            # kerb wins however the neighbours happen to count up.
            near = [f for f in near if f != "."]
        if len(set(near)) == 1:
            return near[0]
        votes = {"=": 0, ".": 0, "P": 0, "L": 0, "Y": 0, ",": 0}
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                g = self.at(x + dx, y + dy)
                if g in WALK_GLYPHS:
                    votes["="] += 1 + (dy == 0)
                elif g in ROAD_GLYPHS:
                    votes["."] += 1 + (dy == 0)
                elif g in "PLY,":
                    votes[g] += 1 + (dy == 0)
        # Equally near and disagreeing: whichever more sides say, then the
        # neighbours, then the order of `votes`, so the pick never wavers.
        order = list(votes)
        return max(near or order,
                   key=lambda f: (near.count(f), votes[f], -order.index(f)))


def column_runs(level: Level, glyphs: set[str], skip=None):
    """Vertical runs of `glyphs`, grouped into bands of adjacent columns
    sharing the same top and bottom row. Yields (x0, width, top, bottom).
    Cells `skip(x, y)` accepts are left out, as if they were not there."""
    def taken(x, y):
        return level.at(x, y) in glyphs and not (skip and skip(x, y))

    runs: dict[tuple[int, int], list[int]] = {}
    for x in range(level.width):
        y = 0
        while y < level.height:
            if taken(x, y):
                top = y
                while y < level.height and taken(x, y):
                    y += 1
                runs.setdefault((top, y - 1), []).append(x)
            else:
                y += 1
    for (top, bottom), columns in runs.items():
        start = columns[0]
        previous = start
        for x in columns[1:] + [None]:
            if x is not None and x == previous + 1:
                previous = x
                continue
            yield start, previous - start + 1, top, bottom
            if x is not None:
                start = previous = x
