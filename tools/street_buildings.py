"""The city's buildings: the palaces' roofs and storefronts, the barracks,
the hypermarket, the Duomo and the small church, the hospital, the
station, the yard walls, gates and railings, and the harbour's boats and
gantry. tools/tile_atlas_city.py places them over the rows they were
painted for.
"""
from __future__ import annotations

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from street_paint import (  # noqa: E402
    BLOOD,
    BLOOD_DARK,
    BUILDING_GLYPHS,
    DOOR_GREEN,
    NAIL,
    OLD_TOWN_ROOFS,
    OLD_TOWN_STONE,
    OUTLINE,
    PANE,
    PANE_BROKEN,
    PANE_LIT,
    PAVING,
    RAINBOW,
    ROOFS,
    SEA,
    SEA_DARK,
    SEA_WAVE,
    SHOP_DARK,
    TILE,
    WOOD,
    WOOD_DARK,
    paint_text,
    rect,
    shade,
    text_width,
)

# -------------------------------------------------------------- buildings


def paint_roof_block(d, rng, level, sx, sy, sw, sh):
    px, py, w, h = sx * TILE, sy * TILE, sw * TILE, sh * TILE
    roofs = OLD_TOWN_ROOFS if level.old_town else ROOFS
    c = roofs[rng.randrange(len(roofs))]
    light = tuple(min(255, v + 24) for v in c)
    dark = tuple(max(0, v - 20) for v in c)
    rect(d, px, py, w, h, c)
    for _ in range(sw * sh * 4):
        rect(d, px + rng.randrange(w), py + rng.randrange(h), 1, 1, dark)
    # parapet around the building, with a thin inner shadow
    rect(d, px, py, w, 2, light)
    rect(d, px, py, 2, h, light)
    rect(d, px + w - 2, py, 2, h, light)
    rect(d, px, py + h - 2, w, 2, light)
    rect(d, px + 2, py + 2, w - 4, 1, dark)
    rect(d, px + 2, py + 2, 1, h - 4, dark)
    # the side facing the street casts a shadow on the sidewalk
    for tx in range(sx, sx + sw):
        if not level.is_building(tx, sy + sh):
            rect(d, tx * TILE, py + h - 3, TILE, 3, light)
    for ty in range(sy, sy + sh):
        if not level.is_building(sx + sw, ty):
            rect(d, px + w, ty * TILE, 2, TILE, (30, 30, 34))
    # rooftop units
    for _ in range(max(1, sw * sh // 6)):
        ax = px + rng.randrange(5, max(6, w - 15))
        ay = py + rng.randrange(5, max(6, h - 14))
        roll = rng.random()
        if roll < 0.55:
            rect(d, ax, ay, 9, 6, (120, 120, 116))
            rect(d, ax + 1, ay + 1, 7, 1, (150, 150, 144))
            rect(d, ax, ay + 6, 9, 1, dark)
        elif roll < 0.8:
            rect(d, ax, ay, 4, 4, (90, 90, 88))
            rect(d, ax + 1, ay + 1, 2, 2, (40, 40, 42))
        elif roll < 0.92 and w >= 48 and h >= 48:
            rect(d, ax, ay, 14, 12, (90, 70, 56))
            rect(d, ax, ay, 14, 3, (120, 96, 74))
            rect(d, ax, ay + 12, 14, 1, dark)
        else:  # skylight
            rect(d, ax, ay, 10, 8, (50, 62, 76))
            rect(d, ax + 1, ay + 1, 8, 1, (90, 110, 130))


def paint_boarded_door(d, rng, x, y, w, h):
    """Planks nailed across a door: three crooked boards and a brace."""
    for i, by in enumerate((y + 2, y + 6, y + 10)):
        tilt = rng.choice((-1, 0, 1))
        colour = WOOD if i % 2 == 0 else (136, 104, 70)
        for bx in range(-2, w + 2):
            rect(d, x + bx, by + (tilt * bx) // w, 1, 3, colour)
        rect(d, x - 1, by + 1, 1, 1, NAIL)
        rect(d, x + w, by + 1 + tilt, 1, 1, NAIL)
    for i in range(h - 2):
        rect(d, x + 1 + i * (w - 3) // (h - 2), y + 1 + i, 2, 1, WOOD_DARK)


SHOPS = {
    # kind: (wall, trim, board, letters, sign text, missing letters)
    "kebab": ((150, 132, 104), (110, 94, 72), (150, 34, 26), (246, 206, 70), "KEBAB", ()),
    "alimentari": ((96, 98, 104), (68, 70, 76), (40, 96, 52), (232, 232, 220), "ALIMENTARI", (6,)),
    "pizzeria": ((116, 58, 48), (80, 38, 34), (226, 220, 200), (150, 34, 26), "PIZZERIA", ()),
    "bar": ((70, 84, 96), (50, 60, 70), (70, 44, 30), (236, 214, 160), "BAR", ()),
    "abbigliamento": ((120, 104, 120), (84, 70, 86), (60, 40, 90), (236, 226, 240), "ABBIGLIAMENTO", (3, 9)),
    "burger": ((140, 126, 96), (100, 88, 64), (170, 30, 28), (250, 200, 50), "BURGER", ()),
    "elettronica": ((84, 90, 104), (58, 62, 74), (26, 46, 96), (120, 220, 240), "ELETTRONICA", (4,)),
    "kebab2": ((122, 112, 92), (88, 78, 62), (36, 92, 58), (250, 226, 120), "KEBAB", (2,)),
    "barsport": ((104, 86, 70), (70, 56, 46), (30, 60, 110), (240, 210, 90), "BAR SPORT", (5,)),
    "pescheria": ((214, 208, 192), (170, 164, 148), (34, 70, 118), (236, 236, 226), "PESCHERIA", (7,)),
    "gelateria": ((222, 218, 204), (176, 170, 156), (226, 170, 180), (120, 40, 60), "GELATERIA", ()),
    # Letters in rainbow colours (see paint_storefront), all still there.
    "arcobaleno": ((196, 186, 168), (150, 140, 124), (30, 28, 36), RAINBOW[0], "BAR ARCOBALENO", ()),
    # Rome: ochre plaster, a red sign with gold letters, the Colosseum on it.
    "souvenir": ((200, 138, 70), (232, 220, 196), (140, 28, 34), (240, 200, 90), "SOUVENIR", ()),
    # Rome, on Piazza di Santa Maria Maggiore: the bar, the trattoria of
    # Roman cooking, the accountants' office.
    "barroma": ((214, 176, 104), (236, 226, 204), (40, 40, 44), (240, 216, 150), "BAR", ()),
    "trattoria": ((170, 82, 58), (228, 214, 188), (36, 70, 44), (236, 226, 200), "TRATTORIA ROMANA", ()),
    "studio": ((222, 196, 150), (240, 232, 214), (30, 40, 70), (226, 226, 220), "COMMERCIALISTA", ()),
    # Rome, on the road from Termini to the Baths of Diocletian: the
    # tobacconist, the bakery and the ironmonger, their shutters down.
    "tabacchi": ((200, 150, 90), (234, 222, 198), (30, 44, 92), (236, 232, 222), "TABACCHI", ()),
    "forno": ((184, 98, 66), (230, 216, 192), (96, 58, 34), (240, 214, 160), "FORNO", ()),
    "ferramenta": ((212, 186, 138), (238, 228, 208), (44, 52, 58), (226, 200, 120), "FERRAMENTA", (6,)),
}
# The shops whose palazzo keeps its own Roman floors above the shop front.
ROMAN_SHOPS = ("souvenir", "barroma", "trattoria", "studio", "tabacchi",
               "forno", "ferramenta")


def paint_shutter(d, x, y, w, h, drop):
    """Roller shutter pulled down to `drop` px, dented and tagged."""
    rect(d, x, y, w, h, SHOP_DARK)
    rect(d, x, y, w, drop, (104, 106, 108))
    for sy in range(y + 1, y + drop, 2):
        rect(d, x, sy, w, 1, (84, 86, 90))
    rect(d, x + w // 3, y + drop - 3, 3, 3, (60, 62, 66))  # dent
    # graffiti tag
    for i in range(0, min(w - 4, 14), 2):
        rect(d, x + 2 + i, y + 3 + (i % 4) // 2, 2, 1, (60, 150, 170))
    rect(d, x + 3, y + 6, min(w - 6, 10), 1, (190, 60, 150))


def paint_torn_awning(d, rng, x, y, w):
    """Striped café awning, ripped and sagging, rags hanging off it."""
    for i in range(0, w, 4):
        colour = (180, 40, 36) if (i // 4) % 2 else (226, 218, 196)
        drop = 0 if rng.random() < 0.7 else rng.randint(2, 6)
        rect(d, x + i, y, 4, 5 + drop, colour)
        if rng.random() < 0.25:
            rect(d, x + i, y + 1, 4, 3, (30, 26, 26))  # a hole
    rect(d, x, y - 1, w, 1, (60, 60, 62))
    rect(d, x + w // 3, y + 4, 1, 6, (60, 60, 62))  # a broken strut


def paint_smashed_display(d, x, y, w, h):
    """Shop window with its glass smashed in: looted shelves and a couple of
    dead screens still on display."""
    rect(d, x, y, w, h, (14, 16, 22))
    rect(d, x, y + h - 3, w, 1, (60, 60, 64))  # shelf
    for i, sx in enumerate(range(x + 1, x + w - 5, 7)):
        rect(d, sx, y + h - 9, 6, 6, (40, 42, 48))
        rect(d, sx + 1, y + h - 8, 4, 4, (26, 40, 52) if i % 2 else (10, 12, 16))
        rect(d, sx + 2, y + h - 7, 1, 2, (160, 200, 220))  # crack
    for i in range(0, w, 3):  # glass teeth still in the frame
        rect(d, x + i, y, 1, 1 + (i * 7) % 4, (150, 180, 200))
        rect(d, x + i + 1, y + h - 1, 1, 1, (150, 180, 200))


def paint_boards(d, x, y, w, h):
    """Planks nailed across a smashed window."""
    rect(d, x, y, w, h, (20, 22, 28))
    for i in range(0, w, 5):
        rect(d, x + i + 1, y + (i * 3) % 4, 2, 2, (140, 170, 190))  # glass
    wood, dark = (122, 92, 60), (86, 62, 40)
    for i in range(0, max(w, h)):
        rect(d, x + i * w // max(w, h), y + i * h // max(w, h), 3, 2, wood)
        rect(d, x + w - 3 - i * w // max(w, h), y + i * h // max(w, h), 3, 2, dark)
    rect(d, x, y + h // 2 - 1, w, 3, wood)


def paint_icon(d, kind, x, y):
    """8x8 icon on the sign, top-left at (x, y)."""
    if kind.startswith("kebab"):
        rect(d, x + 3, y, 1, 8, (170, 170, 170))
        for i, wdt in enumerate((2, 4, 5, 5, 4, 3)):
            rect(d, x + 4 - wdt // 2, y + 1 + i, wdt, 1, (150, 90, 40) if i % 2 else (190, 120, 60))
    elif kind == "souvenir":  # the Colosseum: two tiers of arches
        rect(d, x, y + 1, 8, 7, (226, 204, 160))
        rect(d, x, y + 1, 8, 1, (246, 232, 200))
        for ax in range(x + 1, x + 8, 2):
            rect(d, ax, y + 3, 1, 2, (120, 90, 60))
            rect(d, ax, y + 6, 1, 2, (120, 90, 60))
        rect(d, x + 6, y, 2, 3, (140, 28, 34))  # its broken end
    elif kind == "trattoria":  # a plate of pasta and a fork
        rect(d, x + 1, y + 4, 6, 3, (236, 232, 222))
        rect(d, x + 2, y + 3, 4, 2, (224, 180, 70))
        rect(d, x + 3, y + 3, 1, 1, (170, 40, 30))
        rect(d, x + 7, y, 1, 7, (190, 190, 196))
    elif kind == "studio":  # a ledger
        rect(d, x + 1, y + 1, 6, 7, (150, 40, 40))
        rect(d, x + 2, y + 2, 4, 1, (236, 226, 200))
        rect(d, x + 2, y + 4, 4, 1, (236, 226, 200))
    elif kind == "pizzeria":
        rect(d, x + 1, y + 1, 6, 6, (230, 190, 90))
        rect(d, x + 2, y + 2, 4, 4, (200, 60, 40))
        rect(d, x + 3, y + 3, 1, 1, (250, 240, 220))
        rect(d, x + 5, y + 4, 1, 1, (70, 120, 50))
    elif kind.startswith("bar"):
        rect(d, x + 1, y + 3, 5, 4, (240, 236, 226))
        rect(d, x + 6, y + 4, 1, 2, (240, 236, 226))
        rect(d, x + 2, y + 3, 3, 1, (110, 70, 40))
        rect(d, x + 2, y, 1, 2, (200, 200, 200))
        rect(d, x + 4, y + 1, 1, 2, (200, 200, 200))
    elif kind == "burger":
        rect(d, x + 1, y + 1, 6, 2, (220, 150, 60))
        rect(d, x, y + 3, 8, 1, (90, 170, 60))
        rect(d, x + 1, y + 4, 6, 2, (110, 60, 30))
        rect(d, x + 1, y + 6, 6, 1, (220, 150, 60))
    elif kind == "alimentari":
        rect(d, x + 1, y + 3, 6, 4, (150, 110, 60))
        rect(d, x + 2, y + 1, 2, 2, (200, 50, 40))
        rect(d, x + 4, y + 2, 2, 2, (240, 200, 60))
    elif kind == "elettronica":  # an old television set
        rect(d, x, y + 1, 8, 6, (60, 64, 70))
        rect(d, x + 1, y + 2, 5, 4, (120, 220, 240))
        rect(d, x + 2, y + 3, 2, 1, (230, 250, 255))
        rect(d, x + 6, y + 2, 1, 1, (200, 60, 40))
        rect(d, x + 2, y, 1, 1, (160, 160, 160))
        rect(d, x + 5, y, 1, 1, (160, 160, 160))
        rect(d, x + 1, y + 7, 1, 1, (40, 40, 44))
        rect(d, x + 6, y + 7, 1, 1, (40, 40, 44))
    elif kind == "pescheria":  # a fish
        rect(d, x + 1, y + 3, 5, 3, (170, 190, 200))
        rect(d, x + 2, y + 2, 3, 1, (170, 190, 200))
        rect(d, x + 2, y + 6, 3, 1, (170, 190, 200))
        rect(d, x + 6, y + 2, 1, 5, (130, 150, 160))
        rect(d, x + 2, y + 3, 1, 1, (30, 30, 34))
    elif kind == "gelateria":  # a cone
        rect(d, x + 2, y, 4, 3, (240, 220, 200))
        rect(d, x + 3, y + 1, 2, 1, (170, 90, 60))
        for i in range(4):
            rect(d, x + 2 + i // 2, y + 3 + i, 4 - i, 1, (200, 150, 80))
    elif kind == "arcobaleno":  # a little rainbow
        for i, colour in enumerate(RAINBOW[:4]):
            rect(d, x + i, y + 1 + i, 8 - i * 2, 1, colour)
            rect(d, x + i, y + 1 + i, 1, 7 - i, colour)
            rect(d, x + 7 - i, y + 1 + i, 1, 7 - i, colour)
    elif kind == "abbigliamento":
        rect(d, x + 3, y, 2, 1, (200, 200, 200))
        rect(d, x + 1, y + 2, 6, 1, (200, 200, 200))
        rect(d, x + 1, y + 2, 1, 3, (200, 200, 200))
        rect(d, x + 6, y + 2, 1, 3, (200, 200, 200))
        rect(d, x + 2, y + 3, 4, 5, (170, 120, 190))


def paint_storefront(d, rng, px, py0, w, h, kind):
    wall, trim, board, letters, text, missing = SHOPS[kind]
    shop_top = py0 + h - 17
    sign_top = shop_top - 12
    # A Roman palazzo keeps its own floors above the shop: only the shop
    # front is painted, from just over its sign down.
    roman = kind in ROMAN_SHOPS
    if roman:
        rect(d, px, sign_top - 2, w, py0 + h - sign_top + 2, wall)
    else:
        rect(d, px, py0, w, h, wall)
        rect(d, px, py0, w, 3, trim)
        rect(d, px + w - 1, py0, 1, h, trim)
    # flats upstairs
    for wy in range(py0 + 8, sign_top - 10, 14) if not roman else ():
        for wx in range(px + 5, px + w - 8, 12):
            roll = rng.random()
            pane = PANE if roll > 0.3 else (PANE_LIT if roll > 0.15 else PANE_BROKEN)
            rect(d, wx - 1, wy - 1, 8, 10, trim)
            rect(d, wx, wy, 6, 8, pane)
    # sign board: text, icon, cracks and soot
    rect(d, px + 2, sign_top, w - 4, 11, OUTLINE)
    rect(d, px + 3, sign_top + 1, w - 6, 9, board)
    if kind == "pizzeria":
        rect(d, px + 3, sign_top + 1, 4, 9, (40, 120, 60))
        rect(d, px + w - 7, sign_top + 1, 4, 9, (180, 36, 30))
    label_w = text_width(text) + (10 if w - 6 >= text_width(text) + 12 else 0)
    lx = px + (w - label_w) // 2
    if label_w > text_width(text):
        paint_icon(d, kind, lx, sign_top + 2)
        lx += 10
    if kind == "arcobaleno":
        for i, letter in enumerate(text):
            paint_text(d, lx + i * 4, sign_top + 3, letter, RAINBOW[i % len(RAINBOW)])
    else:
        paint_text(d, lx, sign_top + 3, text, letters, missing)
    rect(d, px + w - 6, sign_top + 1, 1, 9, OUTLINE)  # crack at the edge
    rect(d, px + w - 5, sign_top + 5, 1, 5, OUTLINE)
    rect(d, px + 3, sign_top + 7, 6, 3, (40, 30, 30))  # soot
    # ground floor: wrecked and shut
    rect(d, px + 2, shop_top, w - 4, 17, trim)
    door_w = 12
    door_x = px + (w - door_w) // 2
    window_w = (w - 8 - door_w) // 2
    if kind == "arcobaleno":  # its door kicked in: the one you can go through
        rect(d, door_x, shop_top + 2, door_w, 15, (12, 10, 12))
        rect(d, door_x, shop_top + 2, 3, 15, (70, 50, 36))  # the door, hanging
        rect(d, door_x + 1, shop_top + 8, 1, 2, (180, 160, 90))
    elif kind in ("trattoria", "studio"):  # the door boarded up too
        rect(d, door_x, shop_top + 2, door_w, 15, (46, 32, 24))
        paint_boarded_door(d, rng, door_x, shop_top + 2, door_w, 15)
    else:
        paint_shutter(d, door_x, shop_top + 2, door_w, 15, 15)
    for wx in (px + 3, door_x + door_w + 1):
        if kind in ("kebab", "kebab2", "bar", "burger", "trattoria",
                    "studio"):
            paint_boards(d, wx, shop_top + 2, window_w, 12)
        elif kind in ("elettronica", "barsport"):
            paint_smashed_display(d, wx, shop_top + 2, window_w, 12)
        elif kind == "souvenir":
            # The window smashed, what was in it still on its shelves:
            # little Colosseums, snow globes, the giallorossi scarves.
            paint_smashed_display(d, wx, shop_top + 2, window_w, 12)
            for i in range(3):
                sx = wx + 1 + i * (window_w - 3) // 3
                rect(d, sx, shop_top + 8, 3, 3, (226, 204, 160))
                rect(d, sx + 1, shop_top + 9, 1, 1, (120, 90, 60))
            rect(d, wx + 1, shop_top + 4, window_w - 2, 2, (200, 150, 40))
            rect(d, wx + 1 + (window_w - 2) // 2, shop_top + 4,
                 (window_w - 2) // 2, 2, (150, 30, 34))
        else:
            paint_shutter(d, wx, shop_top + 2, window_w, 12, 8 + rng.randrange(4))
    if kind == "barsport":
        paint_torn_awning(d, rng, px + 2, shop_top - 3, w - 4)
        for _ in range(8):  # grime and splashes on the wall
            rect(d, px + rng.randrange(2, w - 6), py0 + rng.randrange(4, h - 6),
                 rng.randint(2, 5), rng.randint(1, 3), rng.choice(((60, 48, 40), BLOOD_DARK)))
    # scorch marks licking up from the shop
    for _ in range(0 if roman else 3):
        sx = px + rng.randrange(3, w - 6)
        rect(d, sx, shop_top - 2, 4, 3, (36, 30, 30))
        rect(d, sx + 1, shop_top - 5, 2, 3, (36, 30, 30))


def paint_barracks(d, level):
    """Carabinieri barracks: cream facade, dark blue sign with the flaming
    grenade, barred windows and a wide-open front door spilling light."""
    if not any("K" in row for row in level.rows):
        return
    cells = [(x, y) for y in range(level.height) for x in range(level.width)
             if level.at(x, y) in "KE" and level.at(x, y + 1) not in "BK"
             or level.at(x, y) == "K"]
    xs = [x for x, _ in cells]
    ys = [y for _, y in cells]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    px, py, w, h = x0 * TILE, y0 * TILE, (x1 - x0 + 1) * TILE, (y1 - y0 + 1) * TILE
    stone, stone_dark = (206, 190, 150), (160, 144, 108)
    rect(d, px, py, w, h, stone)
    rect(d, px, py, w, 4, (120, 106, 80))  # cornice
    rect(d, px, py + h - 6, w, 6, stone_dark)  # plinth
    for bx in range(px, px + w, 8):
        rect(d, bx, py + h - 6, 1, 6, (130, 116, 86))
    # sign across the top with the emblem
    sign_w = text_width("CARABINIERI") + 20
    sx = px + (w - sign_w) // 2
    rect(d, sx, py + 6, sign_w, 11, OUTLINE)
    rect(d, sx + 1, py + 7, sign_w - 2, 9, (24, 34, 72))
    paint_text(d, sx + 16, py + 9, "CARABINIERI", (240, 240, 236))
    paint_emblem(d, sx + 3, py + 4)
    # barred windows
    door_x = next(x for x in range(level.width) for y in range(level.height)
                  if level.at(x, y) == "E") * TILE
    for wx in range(px + 8, px + w - 8, 18):
        if door_x - 14 <= wx <= door_x + 16:
            continue
        rect(d, wx - 1, py + 24, 12, 16, stone_dark)
        rect(d, wx, py + 25, 10, 14, (30, 36, 48))
        for bar in range(wx + 1, wx + 10, 3):
            rect(d, bar, py + 25, 1, 14, (80, 84, 90))
        rect(d, wx, py + 31, 10, 1, (80, 84, 90))
    # the open door: stone arch, doors swung inwards, warm light inside
    dx, dy = door_x - 4, py + h - 30
    rect(d, dx, dy, 24, 30, stone_dark)
    rect(d, dx + 2, dy + 2, 20, 28, (70, 50, 30))
    rect(d, dx + 4, dy + 4, 16, 26, (238, 196, 110))
    rect(d, dx + 6, dy + 8, 12, 22, (252, 222, 150))
    rect(d, dx + 8, dy + 14, 8, 16, (255, 238, 190))
    rect(d, dx + 2, dy + 4, 3, 26, (100, 66, 36))  # door leaves
    rect(d, dx + 19, dy + 4, 3, 26, (100, 66, 36))
    rect(d, dx + 3, dy + 16, 1, 2, (220, 190, 90))  # handles
    rect(d, dx + 20, dy + 16, 1, 2, (220, 190, 90))
    rect(d, dx + 7, dy - 3, 10, 2, (230, 230, 230))  # lamp over the door
    rect(d, dx + 9, dy - 1, 6, 1, (255, 240, 180))
    # light spilling on the forecourt and a doormat
    spill = [(252, 222, 150), (220, 196, 140), (170, 156, 120)]
    for i, colour in enumerate(spill):
        rect(d, dx + 2 - i * 2, py + h + i * 3, 20 + i * 4, 3, colour)
    rect(d, dx + 6, py + h, 12, 3, (130, 40, 36))


def paint_emblem(d, x, y):
    """Flaming grenade, 11x13, top-left at (x, y)."""
    flame = [(250, 210, 80), (230, 120, 40), (200, 60, 30)]
    for i, (fx, fy, fw, fh) in enumerate(((4, 0, 3, 5), (2, 2, 2, 3), (7, 2, 2, 3), (5, 1, 1, 5))):
        rect(d, x + fx, y + fy, fw, fh, flame[i % 3])
    rect(d, x + 3, y + 5, 5, 2, (200, 170, 70))  # collar
    rect(d, x + 2, y + 7, 7, 6, (200, 170, 70))  # grenade
    rect(d, x + 1, y + 8, 9, 4, (200, 170, 70))
    rect(d, x + 3, y + 8, 2, 2, (250, 230, 150))
    rect(d, x + 4, y + 10, 3, 1, (130, 100, 40))


# ------------------------------------------------------------ hypermarket


def paint_hypermarket(d, rng, level):
    """Multi-storey hypermarket at the end of the north road: clad in grey
    panels, ribbon windows on the upper floors; on the first floor, where
    the eye falls, a giant sign missing half its letters between two
    advertising hoardings ripped to shreds; at street level its doors stand
    open on the dark hall."""
    cells = [(x, y) for y in range(level.height) for x in range(level.width)
             if level.at(x, y) == "M"]
    if not cells:
        return
    xs = [x for x, _ in cells]
    ys = [y for _, y in cells]
    px, py = min(xs) * TILE, min(ys) * TILE
    w, h = (max(xs) - min(xs) + 1) * TILE, (max(ys) - min(ys) + 1) * TILE
    panel, panel_dark, trim = (150, 150, 146), (118, 118, 116), (84, 84, 86)
    rect(d, px, py, w, h, panel)
    for bx in range(px, px + w, 8):  # cladding seams
        rect(d, bx, py, 1, h, panel_dark)
    rect(d, px, py, w, 5, trim)  # parapet
    rect(d, px, py + 5, w, 1, (60, 60, 62))
    # the entrance, where the `m` doors are
    doors = [x for y in range(level.height) for x in range(level.width)
             if level.at(x, y) == "m"]
    door_x, door_w = min(doors) * TILE, len(doors) * TILE
    ground = py + h - 26
    # upper floors: ribbon windows, panes smashed here and there
    band_top = ground - 30  # where the signs start, low enough to be seen
    for floor, wy in enumerate(range(py + 10, band_top - 12, 18)):
        rect(d, px + 4, wy - 1, w - 8, 12, trim)
        for wx in range(px + 5, px + w - 8, 8):
            roll = rng.random()
            pane = (40, 50, 64) if roll > 0.35 else (PANE_BROKEN if roll > 0.1 else PANE_LIT)
            rect(d, wx, wy, 7, 10, pane)
            if pane == PANE_BROKEN:
                rect(d, wx + 1, wy, 2, 3, (90, 110, 130))
                rect(d, wx + 4, wy + 7, 2, 3, (90, 110, 130))
            else:
                rect(d, wx + 1, wy + 1, 1, 3, (90, 110, 130))
        if floor == 0:  # soot streaks from a fire on the upper floor
            for sx in (px + w // 3, px + w // 3 + 9):
                rect(d, sx, wy - 7, 7, 7, (60, 58, 58))
                rect(d, sx + 2, wy - 11, 3, 4, (80, 78, 76))
    # the first floor carries the signs: the giant name over the entrance,
    # letters fallen off or hanging crooked, and ripped hoardings either side
    sign_text = "IPERMERCATO"
    sign_w = text_width(sign_text) * 2 + 12
    sx = door_x + door_w // 2 - sign_w // 2
    sy = band_top + 2
    rect(d, sx, sy, sign_w, 16, OUTLINE)
    rect(d, sx + 1, sy + 1, sign_w - 2, 14, (150, 26, 30))
    paint_text(d, sx + 6, sy + 3, sign_text, (250, 236, 200),
               missing=(2, 7), scale=2, tilted=(9,))
    for wire_x in (sx + 6 + 2 * 8 + 2, sx + 6 + 7 * 8 + 2):  # bare wires
        rect(d, wire_x, sy + 5, 1, 6, (40, 40, 44))
        rect(d, wire_x + 1, sy + 10, 1, 3, (40, 40, 44))
    rect(d, sx + sign_w - 20, sy + 1, 1, 14, OUTLINE)  # cracks
    rect(d, sx + 30, sy + 7, 8, 1, OUTLINE)
    for (left, right), text in (((px + 8, sx - 8), "SCONTI -50%"),
                                ((sx + sign_w + 8, px + w - 8), "OFFERTE!")):
        hw = min(right - left, 64)
        paint_hoarding(d, rng, left + (right - left - hw) // 2, sy, hw, 17, text)
    # ground floor: a canopy over the entrance, its doors stuck open
    rect(d, px, ground - 2, w, 2, trim)
    rect(d, door_x - 6, ground - 6, door_w + 12, 5, (40, 110, 70))  # canopy
    for i in range(0, door_w + 12, 6):
        rect(d, door_x - 6 + i, ground - 1, 3, 2 + (i * 5) % 4, (40, 110, 70))
    rect(d, door_x - 6, ground - 6, door_w + 12, 1, (70, 150, 100))
    paint_text(d, door_x + (door_w - text_width("ENTRATA")) // 2, ground - 6 + 0,
               "ENTRATA", (230, 240, 230))
    # through the doorway: the dark hall and its glossy floor
    rect(d, door_x, ground, door_w, 26, (14, 14, 18))
    for fy in range(ground + 12, ground + 26, 4):
        shade = 60 + (fy - ground) * 4
        rect(d, door_x, fy, door_w, 3, (shade, shade - 2, shade - 6))
    for fx in range(door_x + 4, door_x + door_w, 10):  # floor joints fanning out
        rect(d, fx, ground + 12, 1, 14, (50, 50, 54))
    rect(d, door_x + 6, ground + 4, 8, 6, (40, 40, 46))  # shelves far inside
    rect(d, door_x + door_w - 16, ground + 5, 10, 5, (46, 40, 40))
    # the sliding glass panels, pushed aside and cracked
    for gx in (door_x - 2, door_x + door_w - 6):
        rect(d, gx, ground, 8, 26, (40, 56, 70))
        rect(d, gx + 2, ground + 3, 1, 18, (150, 180, 200))
        rect(d, gx + 4, ground + 9, 3, 1, (150, 180, 200))
    rect(d, door_x - 2, ground, door_w + 4, 1, trim)
    # shop windows either side, papered over with torn special offers
    for wx in (px + 8, door_x + door_w + 12):
        ww = door_x - 12 - px - 8 if wx == px + 8 else px + w - 8 - wx
        rect(d, wx, ground + 2, ww, 20, (22, 24, 30))
        for i, ox in enumerate(range(wx, wx + ww - 15, 16)):
            rect(d, ox, ground + 2, 1, 20, trim)
            roll = rng.random()
            if roll < 0.35:
                paint_poster(d, rng, ox + 2, ground + 4, 12, 14, i)
            elif roll < 0.6:
                paint_smashed_display(d, ox + 1, ground + 3, 15, 18)
            elif roll < 0.8:
                paint_boards(d, ox + 1, ground + 3, 15, 18)
            else:
                rect(d, ox + 3, ground + 4, 2, 8, (60, 70, 86))  # reflection
    # scorch and graffiti on the plinth
    for gx in range(px + 12, px + w - 12, 34):
        rect(d, gx, py + h - 5, 10, 1, (190, 60, 150))
        rect(d, gx + 2, py + h - 4, 8, 1, (60, 150, 170))


DUOMO_STONE = (216, 198, 160)
DUOMO_LIGHT = (232, 218, 184)
DUOMO_SHADE = (184, 164, 128)
DUOMO_DARK = (140, 122, 94)
DUOMO_JOINT = (196, 178, 142)
DUOMO_ROOF = (170, 150, 118)
DUOMO_ROOF_DARK = (136, 118, 90)
DUOMO_HOLE = (34, 28, 26)


def _ashlar(d, rng, x, y, w, h, base=DUOMO_STONE):
    """Limestone blocks: courses 4 px tall, staggered joints, a few paler
    or darker blocks, salt and grime."""
    rect(d, x, y, w, h, base)
    for row, cy in enumerate(range(y, y + h, 4)):
        rect(d, x, cy, w, 1, DUOMO_JOINT)
        for jx in range(x + (row % 2) * 5, x + w, 10):
            rect(d, jx, cy, 1, 4, DUOMO_JOINT)
        for bx in range(x + (row % 2) * 5, x + w - 9, 10):
            roll = rng.random()
            if roll < 0.12:
                rect(d, bx + 1, cy + 1, 9, 3, DUOMO_LIGHT)
            elif roll < 0.2:
                rect(d, bx + 1, cy + 1, 9, 3, DUOMO_SHADE)


def _arch_window(d, x, y, w, h, frame=DUOMO_LIGHT):
    """Round-headed opening: a stone frame, dark inside."""
    r = w // 2
    rect(d, x - 1, y + r - 1, w + 2, h - r + 1, frame)
    for dy in range(r + 1):
        half = round(math.sqrt(max(0, r * r - (r - dy) ** 2)))
        rect(d, x + r - half - 1, y + dy - 1, 2 * half + 2, 1, frame)
        rect(d, x + r - half, y + dy, 2 * half, 1, DUOMO_HOLE)
    rect(d, x, y + r, w, h - r, DUOMO_HOLE)


def _bifora(d, x, y, w, h):
    """Two arched openings side by side, a slim column between them."""
    half = (w - 2) // 2
    _arch_window(d, x, y, half, h)
    _arch_window(d, x + half + 2, y, half, h)
    rect(d, x + half, y + half // 2, 2, h - half // 2, DUOMO_LIGHT)


def _blind_arcade(d, x, y, w):
    """The little blind arches running under the cornices."""
    rect(d, x, y + 5, w, 1, DUOMO_SHADE)
    for ax in range(x + 1, x + w - 4, 6):
        rect(d, ax, y + 1, 4, 1, DUOMO_SHADE)
        rect(d, ax, y + 1, 1, 4, DUOMO_SHADE)
        rect(d, ax + 4, y + 1, 1, 4, DUOMO_SHADE)


def _pyramid(d, cx, top, base, half):
    """A stone pyramid roof, lit from the west."""
    for dy in range(base - top):
        span = half * dy // max(1, base - top - 1)
        rect(d, cx - span, top + dy, span, 1, DUOMO_ROOF)
        rect(d, cx, top + dy, span + 1, 1, DUOMO_ROOF_DARK)
        if dy % 3 == 2:
            rect(d, cx - span, top + dy, 2 * span + 1, 1, DUOMO_SHADE)


def _tower(d, rng, x, y, w, h):
    """A square bell tower: courses of stone, a string course at each
    level, a bifora at each of the two belfries, a cornice at the top."""
    _ashlar(d, rng, x, y, w, h)
    rect(d, x + w - 4, y, 4, h, DUOMO_SHADE)  # its east side, in shadow
    rect(d, x - 2, y, w + 4, 4, DUOMO_LIGHT)  # the cornice
    rect(d, x - 2, y + 4, w + 4, 1, DUOMO_DARK)
    for ly, lh in ((y + 9, 16), (y + 34, 18), (y + 62, 12)):
        _bifora(d, x + w // 2 - 7, ly, 14, lh)
        rect(d, x - 1, ly + lh + 3, w + 2, 2, DUOMO_LIGHT)  # string course
        rect(d, x - 1, ly + lh + 5, w + 2, 1, DUOMO_DARK)


def paint_flower_bed(d, rng, level, x, y):
    """A bed raised behind a kerb of the same stone as the paving: dry
    earth, a shrub gone leggy and some weeds over the edge."""
    px, py = x * TILE, y * TILE
    kerb, earth = (192, 184, 166), (78, 62, 48)
    rect(d, px, py, TILE, TILE, kerb)
    rect(d, px + 2, py + 2, TILE - 4, TILE - 4, earth)
    rect(d, px, py, TILE, 2, shade(kerb, 16))
    rect(d, px, py + TILE - 2, TILE, 2, shade(kerb, -34))
    if level.at(x, y - 1) != "&":
        rect(d, px + 2, py + 2, TILE - 4, 1, shade(earth, -18))
    for _ in range(9):
        rect(d, px + 2 + rng.randrange(TILE - 5), py + 2 + rng.randrange(TILE - 5),
             2, 1, shade(earth, rng.randint(-12, 14)))
    for _ in range(7):  # what is left growing in it
        gx = px + 3 + rng.randrange(TILE - 7)
        gy = py + 4 + rng.randrange(TILE - 9)
        green = rng.choice(((74, 96, 52), (92, 112, 58), (60, 80, 46)))
        rect(d, gx, gy, 2, rng.randint(3, 6), green)
    if rng.random() < 0.4:
        rect(d, px + rng.randrange(3, 11), py + TILE - 3, 4, 3, (86, 100, 58))


def paint_street_fountain(d, px, py):
    """The drinking fountain of the piazzetta, over two cells by two: a
    low kerbed basin, green with algae, and the stone column standing in
    it with its brass spout over a scalloped bowl."""
    stone, lit, dark = (196, 186, 166), (216, 208, 190), (140, 130, 112)
    water, algae = (62, 78, 72), (78, 96, 58)
    w = h = 2 * TILE
    # the basin: a rounded kerb, the water inside it barely moving
    d.rounded_rectangle([px + 1, py + 6, px + w - 2, py + h - 2], radius=9,
                        fill=stone, outline=dark)
    d.rounded_rectangle([px + 5, py + 10, px + w - 6, py + h - 6], radius=6,
                        fill=water)
    for i in range(px + 6, px + w - 6, 5):
        rect(d, i, py + h - 9, 3, 2, algae)
    rect(d, px + 2, py + 6, w - 4, 2, lit)          # the light on the kerb
    rect(d, px + 2, py + h - 4, w - 4, 2, dark)
    # the column, standing in the middle of it
    cx = px + w // 2
    rect(d, cx - 5, py + h - 16, 10, 7, dark)       # its plinth
    rect(d, cx - 4, py + h - 17, 8, 2, lit)
    rect(d, cx - 4, py - 4, 8, h - 13, stone)       # the shaft
    rect(d, cx - 4, py - 4, 2, h - 13, lit)
    rect(d, cx + 2, py - 4, 2, h - 13, dark)
    for cy in range(py + 2, py + h - 14, 7):        # grime run down it
        rect(d, cx - 3, cy, 5, 1, shade(stone, -22))
    rect(d, cx - 6, py - 8, 12, 5, stone)           # the cap
    rect(d, cx - 6, py - 8, 12, 2, lit)
    rect(d, cx - 3, py - 11, 6, 3, dark)
    rect(d, cx - 1, py + 6, 4, 3, (132, 104, 44))   # the brass spout
    rect(d, cx - 5, py + 9, 10, 4, stone)           # the scalloped bowl
    rect(d, cx - 4, py + 10, 8, 2, dark)
    rect(d, cx - 1, py + 13, 2, 6, (118, 140, 150))  # the trickle it still runs


def paint_small_church(d, rng, level):
    """San Nicola, up in the warren of alleys: one plain gabled front in
    the same limestone as the Duomo, a small rose window over an arched
    portal, a bell gable with its bell on the west corner, and two worn
    steps down to the square."""
    cells = [(x, y) for y in range(level.height) for x in range(level.width)
             if level.at(x, y) == "#"]
    if not cells:
        return
    x0 = min(x for x, _ in cells) * TILE
    y0 = min(y for _, y in cells) * TILE
    w = (max(x for x, _ in cells) + 1) * TILE - x0
    bottom = (max(y for _, y in cells) + 1) * TILE
    cx = x0 + w // 2
    paint_roof_block(d, rng, level, x0 // TILE, y0 // TILE, w // TILE,
                     (bottom - y0) // TILE)

    # the nave, its gable rising over the front
    nave_l, nave_r = x0, x0 + w
    gable_top = y0 + 14
    front = y0 + 30
    _ashlar(d, rng, nave_l, front, nave_r - nave_l, bottom - front)
    for dy in range(front - gable_top):  # the gable, sloping both ways
        span = (nave_r - nave_l) * dy // (2 * (front - gable_top))
        _ashlar(d, rng, cx - span, gable_top + dy, 2 * span + 1, 1)
        rect(d, cx - span, gable_top + dy, 3, 1, DUOMO_LIGHT)
        rect(d, cx + span - 2, gable_top + dy, 3, 1, DUOMO_DARK)
    rect(d, nave_l, front - 1, nave_r - nave_l, 2, DUOMO_LIGHT)
    _blind_arcade(d, nave_l + 2, front + 2, nave_r - nave_l - 4)

    # the rose window, plain: a ring of stone with eight spokes, set in the
    # front wall between the cornice and the portal
    rose_y = front + 16
    d.ellipse([cx - 9, rose_y - 9, cx + 9, rose_y + 9], fill=DUOMO_LIGHT)
    d.ellipse([cx - 7, rose_y - 7, cx + 7, rose_y + 7], fill=DUOMO_HOLE)
    for i in range(8):
        a = math.pi * i / 4
        rect(d, cx + round(5 * math.cos(a)), rose_y + round(5 * math.sin(a)),
             1, 1, DUOMO_SHADE)

    # The portal, standing open on the dark of the nave: both leaves are
    # folded back against the jambs, and the dark runs right down to the
    # square, with nothing across the threshold -- the church of San Nicola
    # can be walked into, unlike the Duomo behind its gate. A frame of pale
    # stone sets it off from the front.
    door_w = 20
    door_h = 30
    dx = cx - door_w // 2
    rect(d, dx - 3, bottom - door_h - 3, door_w + 6, door_h + 3, DUOMO_LIGHT)
    rect(d, dx - 3, bottom - door_h - 3, 1, door_h + 3, DUOMO_SHADE)
    rect(d, dx + door_w + 2, bottom - door_h - 3, 1, door_h + 3, DUOMO_SHADE)
    # the round head of the opening, dark right up to the keystone
    r = door_w // 2
    spring = bottom - door_h + r  # where the arch starts
    for dy in range(r):
        half = round(math.sqrt(max(0, r * r - (r - dy) ** 2)))
        rect(d, cx - half, bottom - door_h + dy, 2 * half, 1, (12, 10, 14))
    rect(d, cx - 1, bottom - door_h - 3, 2, 3, DUOMO_SHADE)
    rect(d, dx, spring, door_w, bottom - spring, (12, 10, 14))
    for leaf in (dx, dx + door_w - 4):
        rect(d, leaf, spring + 1, 4, bottom - spring - 1, DOOR_GREEN)
        rect(d, leaf + 1, spring + 2, 2, bottom - spring - 3,
             shade(DOOR_GREEN, 24))
        rect(d, leaf, spring + 1, 4, 1, shade(DOOR_GREEN, -20))
    # the worn steps either side of the portal, not across it
    for i, sy in enumerate((bottom - 4, bottom - 2)):
        for sx, sw in ((cx - door_w - 6, door_w // 2 + 3),
                       (dx + door_w + 3, door_w // 2 + 3)):
            rect(d, sx, sy, sw, 2, shade(DUOMO_STONE, -8 * i))

    # the bell gable on the west corner, a bell hanging in its arch
    bx, by = x0, y0 + 8
    _ashlar(d, rng, bx, by, 20, front - by + 8)
    rect(d, bx, by, 20, 3, DUOMO_LIGHT)
    _arch_window(d, bx + 5, by + 7, 8, 14)
    rect(d, bx + 7, by + 13, 4, 5, (96, 82, 46))  # the bell
    rect(d, bx + 6, by + 17, 6, 2, (120, 102, 58))


def paint_yard_wall(d, rng, level, x, y):
    """Concrete panels with a capping along the top, rust running down
    them and the odd sprayed tag."""
    px, py = x * TILE, y * TILE
    slab, joint = (146, 142, 134), (110, 106, 100)
    rect(d, px, py, TILE, TILE, slab)
    for _ in range(6):
        rect(d, px + rng.randrange(TILE), py + rng.randrange(TILE), 2, 1,
             shade(slab, -rng.randint(6, 16)))
    if x % 3 == 0:  # the joint between one panel and the next
        rect(d, px, py, 1, TILE, joint)
    if not level.is_building(x, y + 1):  # the top of the wall, then shadow
        rect(d, px, py, TILE, 4, (176, 172, 164))
        rect(d, px, py + 4, TILE, 1, joint)
        rect(d, px, py + TILE - 3, TILE, 3, (40, 40, 44))
    if not level.is_building(x + 1, y):
        rect(d, px + TILE - 2, py, 2, TILE, joint)
    if rng.random() < 0.25:
        rect(d, px + rng.randrange(2, 13), py + 5, 1, rng.randint(4, 9),
             (126, 74, 46))
    if rng.random() < 0.12:
        rect(d, px + 3, py + 7, 9, 4, (70, 86, 110))


def paint_hull(d, rng, px, py, w, h):
    """A fishing boat up on the stocks, seen from above with her bow to the
    west: white topsides over a red bottom, the deck open amidships, the
    wheelhouse aft, and timber shores holding her upright."""
    white, shadow = (186, 182, 172), (120, 116, 110)
    red, deck, rail = (128, 52, 40), (146, 118, 78), (208, 204, 194)
    keel_y = py + h // 2

    def half_width(i):
        """Fine at the stem, full amidships, still broad at the transom."""
        t = i / (w - 20)
        return int((h // 2 - 6) * min(1.0, 0.18 + 1.5 * t ** 0.6))

    for i in range(w - 20):  # her shadow, cast south-east under the hull
        half = half_width(i)
        rect(d, px + 12 + i, keel_y - half + 5, 1, 2 * half, (58, 56, 56))
    for i in range(w - 20):  # the red bottom, widest at the turn of the bilge
        half = half_width(i)
        rect(d, px + 8 + i, keel_y - half, 1, 2 * half, red)
    for i in range(w - 20):  # the white topsides inside it
        half = max(1, half_width(i) - 4)
        rect(d, px + 8 + i, keel_y - half, 1, 2 * half, white)
        if i % 11 == 0:
            rect(d, px + 8 + i, keel_y - half, 1, 2 * half, shadow)
    for i in range(w - 20):  # the capping rail all the way round
        half = half_width(i) - 4
        if half > 0:
            rect(d, px + 8 + i, keel_y - half, 1, 2, rail)
            rect(d, px + 8 + i, keel_y + half - 2, 1, 2, shadow)
    rect(d, px + w - 14, keel_y - h // 2 + 8, 2, h - 16, rail)  # the transom

    hold_x = px + 8 + (w - 20) // 3
    rect(d, hold_x, keel_y - h // 4, (w - 20) // 3, h // 2, deck)  # the hold
    rect(d, hold_x, keel_y - h // 4, (w - 20) // 3, 2, shade(deck, -24))
    house_x = px + w - 44
    rect(d, house_x, keel_y - 14, 24, 28, (168, 160, 146))  # the wheelhouse
    rect(d, house_x, keel_y - 14, 24, 2, rail)
    rect(d, house_x + 2, keel_y - 10, 20, 7, PANE)
    rect(d, house_x + 9, keel_y - 22, 3, 9, (150, 146, 138))  # her mast
    for bx in range(px + 20, px + w - 24, 24):  # shores under the bilge
        for by in (keel_y - half_width(bx - px - 8) - 6, keel_y + half_width(bx - px - 8) + 2):
            rect(d, bx, by, 5, 5, (108, 84, 56))
            rect(d, bx - 1, by + 4, 7, 2, (80, 62, 42))
    for _ in range(w // 10):  # rust weeping from the fastenings
        rect(d, px + 10 + rng.randrange(w - 26), keel_y - rng.randrange(-h // 3, h // 3),
             3, 1, shade(red, -rng.randint(10, 40)))


def paint_gantry(d, px, py, w, h):
    """The gantry crane over the stocks: two legs, a jib across them and
    the hook block hanging still, all inside its cells (every one of them
    is an obstacle, so nothing of it may stand on the concrete you walk)."""
    steel, rust = (150, 134, 70), (120, 86, 48)
    for lx in (px + 3, px + w - 8):
        rect(d, lx, py + 2, 5, h - 6, steel)
        rect(d, lx + 1, py + 2, 1, h - 6, rust)
        rect(d, lx - 3, py + h - 6, 11, 4, (70, 70, 74))
    rect(d, px, py + 2, w, 6, steel)  # the jib
    rect(d, px, py + 8, w, 1, rust)
    for i in range(px + 2, px + w - 1, 8):  # its lattice
        rect(d, i, py + 3, 1, 5, rust)
    cx = px + w // 2
    rect(d, cx - 1, py + 9, 2, h // 2 - 4, (60, 60, 64))  # the fall
    rect(d, cx - 4, py + h // 2 + 5, 8, 7, (80, 78, 82))  # the hook block


def paint_duomo(d, rng, level):
    """The Duomo of Molfetta on the harbour, in pale limestone: the nave's
    gabled front with its rose window and arched portal, the aisles either
    side under sloping roofs, a pyramid-roofed dome behind the gable, and
    the two square bell towers rising above it all."""
    cells = [(x, y) for y in range(level.height) for x in range(level.width)
             if level.at(x, y) == "W"]
    if not cells:
        return
    x0 = min(x for x, _ in cells) * TILE
    y0 = min(y for _, y in cells) * TILE
    w = (max(x for x, _ in cells) + 1) * TILE - x0
    bottom = (max(y for _, y in cells) + 1) * TILE
    cx = x0 + w // 2
    # the old town's roofs behind it, where nothing of the Duomo stands
    paint_roof_block(d, rng, level, x0 // TILE, y0 // TILE, w // TILE,
                     (bottom - y0) // TILE)

    tower_w = 34
    tower_top = y0 + 2
    tower_bottom = bottom - 60
    left_tower = x0 + 18
    right_tower = x0 + w - 18 - tower_w
    _tower(d, rng, left_tower, tower_top, tower_w, tower_bottom - tower_top)
    _tower(d, rng, right_tower, tower_top + 6, tower_w, tower_bottom - tower_top - 6)

    # the dome behind the gable: a square drum under a stone pyramid
    drum_top = y0 + 44
    _ashlar(d, rng, cx - 22, drum_top, 44, 22)
    _pyramid(d, cx, y0 + 22, drum_top + 1, 26)
    _arch_window(d, cx - 3, drum_top + 7, 6, 11)

    # the aisles, their roofs sloping down away from the nave
    aisle_top = bottom - 70
    nave_l, nave_r = cx - 46, cx + 46
    for ax0, ax1, rising in ((x0, nave_l, True), (nave_r, x0 + w, False)):
        _ashlar(d, rng, ax0, aisle_top, ax1 - ax0, bottom - aisle_top)
        for i in range(ax1 - ax0):
            t = i if rising else (ax1 - ax0 - 1 - i)
            drop = 10 - t * 10 // (ax1 - ax0)
            rect(d, ax0 + i, aisle_top - 12 + drop, 1, 12 - drop, DUOMO_ROOF)
            rect(d, ax0 + i, aisle_top - 12 + drop, 1, 1, DUOMO_ROOF_DARK)
        _blind_arcade(d, ax0, aisle_top + 1, ax1 - ax0)
        _arch_window(d, (ax0 + ax1) // 2 - 3, aisle_top + 22, 6, 18)
    rect(d, x0 + w - 4, aisle_top, 4, bottom - aisle_top, DUOMO_SHADE)

    # the nave's front: gable, cornice of little arches, rose window, portal
    nave_top = bottom - 94
    _ashlar(d, rng, nave_l, nave_top, nave_r - nave_l, bottom - nave_top)
    peak = nave_top - 22
    for dy in range(22):
        span = (nave_r - nave_l) // 2 * dy // 21
        _ashlar(d, rng, cx - span, peak + dy, 2 * span, 1)
        rect(d, cx - span - 2, peak + dy, 2, 1, DUOMO_LIGHT)  # its coping
        rect(d, cx + span, peak + dy, 2, 1, DUOMO_SHADE)
    rect(d, cx, peak - 6, 1, 6, DUOMO_DARK)  # the cross on the gable
    rect(d, cx - 2, peak - 4, 5, 1, DUOMO_DARK)
    _blind_arcade(d, nave_l, nave_top + 1, nave_r - nave_l)
    _arch_window(d, cx - 3, nave_top - 12, 6, 12)
    # rose window
    ry = nave_top + 30
    for rr, colour in ((11, DUOMO_LIGHT), (9, DUOMO_SHADE), (7, DUOMO_HOLE)):
        for dy in range(-rr, rr + 1):
            half = round(math.sqrt(rr * rr - dy * dy))
            rect(d, cx - half, ry + dy, 2 * half + 1, 1, colour)
    for a in range(0, 360, 45):
        rad = math.radians(a)
        for s in range(2, 7):
            rect(d, round(cx + s * math.cos(rad)), round(ry + s * math.sin(rad)),
                 1, 1, DUOMO_SHADE)
    rect(d, cx - 1, ry - 1, 3, 3, DUOMO_LIGHT)
    # the portal: a deep round arch, both leaves folded open. The churchyard
    # gate, not this door, keeps Mario out until Don Angelo accepts him.
    pw, ph = 26, 42
    px, py = cx - pw // 2, bottom - ph
    _arch_window(d, px - 4, py - 4, pw + 8, ph + 4, DUOMO_LIGHT)
    rect(d, px - 4, py + 9, pw + 8, ph - 9, DUOMO_SHADE)
    _arch_window(d, px, py, pw, ph, DUOMO_SHADE)
    rect(d, px + 3, py + 13, pw - 6, ph - 13, (28, 24, 26))
    for leaf_x in (px, px + pw - 5):
        rect(d, leaf_x, py + 12, 5, ph - 12, (84, 44, 30))
        rect(d, leaf_x + 1, py + 13, 2, ph - 14, (118, 70, 42))
    rect(d, px + 5, bottom - 4, pw - 10, 4, (170, 156, 132))
    # grime climbing from the sidewalk, and the blood of the first night
    for _ in range(40):
        gx = x0 + rng.randrange(w)
        if nave_l <= gx < nave_r and px - 4 <= gx < px + pw + 4:
            continue
        rect(d, gx, bottom - rng.randint(2, 14), 1, rng.randint(2, 8), DUOMO_SHADE)
    rect(d, px - 10, bottom - 12, 4, 6, BLOOD_DARK)
    rect(d, px - 9, bottom - 6, 2, 6, BLOOD_DARK)


def paint_poster(d, rng, x, y, w, h, i):
    """Paper poster, half torn away."""
    colours = [(230, 200, 60), (220, 70, 50), (240, 236, 220)]
    rect(d, x, y, w, h, colours[i % 3])
    rect(d, x + 2, y + 2, w - 4, 3, (170, 30, 30) if i % 3 != 1 else (250, 240, 200))
    for tx in range(0, w, 2):  # ragged tear across the bottom
        top = y + h // 2 + rng.randrange(h // 2)
        rect(d, x + tx, top, 2, y + h - top, (22, 24, 30))


def paint_hoarding(d, rng, x, y, w, h, text):
    """Advertising panel: frame, faded poster with its slogan, strips of
    paper peeled off and hanging down, bare board showing through."""
    rect(d, x - 1, y - 1, w + 2, h + 2, OUTLINE)
    rect(d, x, y, w, h, (70, 66, 60))  # bare board
    rect(d, x, y, w, h - 4, (226, 196, 70))
    rect(d, x, y + h - 6, w, 2, (200, 60, 40))
    if text_width(text) <= w - 4:
        paint_text(d, x + (w - text_width(text)) // 2, y + 3, text, (170, 30, 30),
                   missing=(len(text) // 2,))
    for _ in range(max(2, w // 10)):  # torn away below the slogan
        tx, tw = x + rng.randrange(w - 6), rng.randint(3, 8)
        top = y + 9 + rng.randrange(max(1, h - 12))
        rect(d, tx, top, tw, y + h - top, (70, 66, 60))
        rect(d, tx + 1, y + h, 2, rng.randint(3, 7), (226, 196, 70))  # dangling strip


# --------------------------------------------------------------- hospital


def paint_hospital(d, rng, level):
    """The hospital at the end of the west road: pale plastered block, rows
    of windows (some with sheets begging for help), the emergency entrance,
    its glass doors smeared with blood, and beside it, where it is seen
    from the stairs, the OSPEDALE board with its red cross. The doors are where the `$` cells are, in the middle of the
    front: the way in (lib/core/levels/hometown/hospital.dart)."""
    cells = [(x, y) for y in range(level.height) for x in range(level.width)
             if level.at(x, y) == "G"]
    if not cells:
        return
    xs = [x for x, _ in cells]
    ys = [y for _, y in cells]
    px, py = min(xs) * TILE, min(ys) * TILE
    w, h = (max(xs) - min(xs) + 1) * TILE, (max(ys) - min(ys) + 1) * TILE
    wall, wall_dark, trim = (206, 212, 204), (170, 178, 170), (120, 130, 126)
    rect(d, px, py, w, h, wall)
    rect(d, px, py, w, 5, trim)
    rect(d, px, py + 5, w, 1, (90, 96, 94))
    for bx in range(px + 31, px + w, 32):  # structural pillars
        rect(d, bx, py + 6, 3, h - 6, wall_dark)
    # floors of windows, some shattered, some with sheets hung out
    ground = py + h - 30
    sheets = 0
    for wy in range(py + 12, ground - 12, 16):
        for wx in range(px + 6, px + w - 10, 12):
            roll = rng.random()
            pane = (60, 80, 96) if roll > 0.3 else (PANE_BROKEN if roll > 0.1 else PANE_LIT)
            rect(d, wx - 1, wy - 1, 9, 12, trim)
            rect(d, wx, wy, 7, 10, pane)
            if pane == PANE_BROKEN:
                rect(d, wx + 1, wy + 7, 5, 1, BLOOD)
            if sheets < 3 and rng.random() < 0.07:
                sheets += 1
                rect(d, wx - 1, wy + 3, 9, 16, (236, 234, 226))
                rect(d, wx, wy + 6, 7, 1, (150, 30, 30))
                rect(d, wx + 1, wy + 9, 5, 1, (150, 30, 30))
                rect(d, wx + 2, wy + 12, 3, 1, (150, 30, 30))
    # emergency entrance at the bottom centre
    door_w = 60
    dx = px + (w - door_w) // 2
    rect(d, dx - 6, ground - 8, door_w + 12, 7, (200, 36, 32))  # canopy
    paint_text(d, dx + (door_w - text_width("PRONTO SOCCORSO")) // 2, ground - 7,
               "PRONTO SOCCORSO", (250, 246, 236))
    rect(d, dx - 6, ground - 1, door_w + 12, 1, (120, 20, 20))
    rect(d, dx, ground, door_w, 30, (14, 14, 18))
    for gx in range(dx + 1, dx + door_w, 11):
        rect(d, gx, ground + 1, 10, 29, (40, 52, 62))
        rect(d, gx + 2, ground + 4, 6, 14, (14, 14, 18))  # smashed pane
        rect(d, gx + 1, ground + 18, 3, 8, BLOOD)  # smeared hands
        rect(d, gx + 5, ground + 14, 2, 10, BLOOD_DARK)
    rect(d, dx - 8, ground + 14, 6, 16, (200, 200, 196))  # a stretcher on end
    rect(d, dx - 7, ground + 16, 4, 12, (236, 236, 230))
    rect(d, dx + door_w + 3, ground + 6, 4, 24, (60, 60, 64))  # drip stand
    rect(d, dx + door_w + 1, ground + 6, 8, 1, (60, 60, 64))
    # The name, on a board beside the entrance, low enough to be read
    # from the stairs: the top of the front is out of view from down there.
    text = "OSPEDALE"
    tw = text_width(text) * 2
    bx, by = px + 6, ground - 10
    rect(d, bx, by, tw + 22, 16, trim)
    rect(d, bx + 1, by + 1, tw + 20, 14, (240, 240, 236))
    rect(d, bx + 1, by + 14, tw + 20, 1, (200, 200, 196))
    rect(d, bx + 5, by + 6, 10, 4, (200, 30, 30))  # the cross
    rect(d, bx + 8, by + 3, 4, 10, (200, 30, 30))
    paint_text(d, bx + 18, by + 3, text, (40, 70, 140), scale=2)
    rect(d, bx + 50, by + 9, 3, 6, BLOOD)  # a bloody hand dragged down it
    rect(d, bx + 51, by + 15, 1, 4, BLOOD_DARK)


def paint_stairs(d, level, x, y):
    """A step of the hospital's wide staircase, with a handrail at the ends
    and a nosing shadow on every step."""
    px, py = x * TILE, y * TILE
    rect(d, px, py, TILE, TILE, (176, 172, 162))
    rect(d, px, py + 6, TILE, 2, (136, 132, 124))  # nosing shadow
    rect(d, px, py + 8, TILE, 7, (160, 156, 146))
    rect(d, px, py + 14, TILE, 2, (126, 122, 114))
    if level.surface(x - 1, y) != "Y" or level.is_building(x - 1, y):
        rect(d, px, py, 2, TILE, (70, 72, 76))
    if level.surface(x + 1, y) != "Y" or level.is_building(x + 1, y):
        rect(d, px + 14, py, 2, TILE, (70, 72, 76))
    if (x * 7 + y * 3) % 5 == 0:
        rect(d, px + 4, py + 10, 5, 2, BLOOD)


def _station_arch(d, x, y, w, h, frame, hole):
    """Round-headed opening, `w` wide and `h` tall to the ground, in a
    raised stone frame: the arcade the station's front is made of."""
    r = w // 2
    for dy in range(r + 1):
        half = round(math.sqrt(max(0, r * r - (r - dy) ** 2)))
        rect(d, x + r - half - 2, y + dy - 2, 2 * half + 4, 1, frame)
        rect(d, x + r - half, y + dy, 2 * half, 1, hole)
    rect(d, x - 2, y + r, 2, h - r, frame)
    rect(d, x + w, y + r, 2, h - r, frame)
    rect(d, x, y + r, w, h - r, hole)


def paint_station(d, rng, level):
    """The station at the top of the block, `0`: the low provincial kind
    the south is full of, a long body of round-arched openings between
    pilasters, a cornice over them, and a raised middle bay carrying the
    clock and the name. The two openings the map marks `(` and `)` are the
    doors, standing open on the dark of the booking hall, and each one goes
    somewhere; the rest are windows, their glass mostly gone."""
    cells = [(x, y) for y in range(level.height) for x in range(level.width)
             if level.at(x, y) == "0"]
    if not cells:
        return
    x0, x1 = min(x for x, _ in cells), max(x for x, _ in cells)
    y0, y1 = min(y for _, y in cells), max(y for _, y in cells)
    px, py = x0 * TILE, y0 * TILE
    w, h = (x1 - x0 + 1) * TILE, (y1 - y0 + 1) * TILE
    wall, wall_dark = (226, 214, 184), (196, 182, 150)
    trim, plinth = (238, 230, 206), (146, 142, 132)
    roof, hole = (150, 142, 128), (26, 26, 30)
    rect(d, px, py, w, h, wall)
    rect(d, px, py, w, 9, roof)  # the flat roof, seen edge on
    rect(d, px, py + 7, w, 2, (110, 104, 96))
    rect(d, px, py + 9, w, 3, trim)  # the cornice under it
    rect(d, px, py + 12, w, 1, wall_dark)
    ground = py + h - 3
    rect(d, px, ground, w, 3, plinth)  # the plinth it stands on
    # The front is the stretch standing over the forecourt: an arcade of
    # openings two tiles wide, the rest of the building a blind end.
    front = [ax for ax in range(x0, x1, 2)
             if level.at(ax, y1 + 1) not in BUILDING_GLYPHS
             and level.at(ax + 1, y1 + 1) not in BUILDING_GLYPHS]
    if not front:
        return
    # the middle bay: raised, carrying the clock and the name, the middle
    # opening of the arcade under it
    middle = front[len(front) // 2] * TILE + TILE
    bx, bw = middle - 36, 72
    rect(d, bx, py, bw, h - 3, wall)
    rect(d, bx, py, bw, 6, roof)
    rect(d, bx, py + 5, bw, 2, (110, 104, 96))
    rect(d, bx, py + 7, bw, 3, trim)  # its own cornice
    for edge in (bx, bx + bw - 3):  # the pilasters framing it
        rect(d, edge, py + 10, 3, h - 13, wall_dark)
        rect(d, edge, py + 10, 1, h - 13, trim)
    for ax in front:
        sx = ax * TILE + 4
        rect(d, sx - 4, py + 13, 4, h - 16, wall_dark)  # the pilaster beside it
        rect(d, sx - 4, py + 13, 1, h - 16, trim)
        if level.at(ax, y1) in "()":
            _station_arch(d, sx, ground - 36, 24, 36, trim, hole)
            rect(d, sx + 2, ground - 18, 20, 18, (14, 14, 16))  # the hall
            rect(d, sx, ground - 3, 24, 3, (176, 170, 158))  # its worn step
            for leaf in (sx, sx + 20):  # the doors, folded back
                rect(d, leaf, ground - 24, 4, 22, (66, 58, 46))
                rect(d, leaf + 1, ground - 23, 2, 20, (92, 82, 66))
        else:
            _station_arch(d, sx, ground - 36, 24, 32, trim, (52, 58, 66))
            for gy in range(ground - 26, ground - 4, 7):  # the glazing bars
                rect(d, sx, gy, 24, 1, trim)
            rect(d, sx + 11, ground - 30, 2, 26, trim)
            if rng.random() < 0.7:  # panes gone, and boards over the gap
                rect(d, sx + rng.randrange(1, 13), ground - 24, 10, 9, hole)
                rect(d, sx + 1, ground - 20, 22, 3, (122, 92, 60))
            rect(d, sx, ground - 4, 24, 4, wall_dark)  # its sill
    cx, cy = bx + bw // 2, py + 24
    d.ellipse([cx - 11, cy - 11, cx + 11, cy + 11], fill=trim)  # the clock
    d.ellipse([cx - 9, cy - 9, cx + 9, cy + 9], fill=(238, 234, 220))
    for tick in range(12):
        tx = cx + round(7 * math.sin(tick * math.pi / 6))
        ty = cy - round(7 * math.cos(tick * math.pi / 6))
        rect(d, tx, ty, 1, 1, (90, 86, 80))
    rect(d, cx, cy - 6, 1, 7, (40, 38, 36))  # stopped at ten past eleven
    rect(d, cx, cy, 6, 1, (40, 38, 36))
    rect(d, cx - 1, cy - 1, 2, 2, (40, 38, 36))
    name = "STAZIONE"
    nx = cx - (text_width(name) * 2) // 2
    rect(d, nx - 5, cy + 15, text_width(name) * 2 + 10, 14, (40, 60, 46))
    rect(d, nx - 5, cy + 15, text_width(name) * 2 + 10, 1, (80, 110, 86))
    paint_text(d, nx, cy + 18, name, (236, 236, 224), missing=(5,), scale=2,
               tilted=(7,))


def paint_railing(d, level, x, y):
    """A length of the park's iron railing, `^`: uprights on a bottom rail
    with a rail across their heads, a post wherever the run ends or a gate
    breaks it. Painted low in the tile so the lawn shows behind it."""
    px, py = x * TILE, y * TILE
    iron, iron_dark, iron_light = (58, 62, 66), (36, 38, 42), (96, 100, 104)
    rect(d, px, py + 13, TILE, 2, iron_dark)  # its shadow on the ground
    for bar in range(px + 1, px + TILE, 3):
        rect(d, bar, py + 4, 1, 9, iron)
        rect(d, bar, py + 4, 1, 1, iron_light)
    rect(d, px, py + 3, TILE, 2, iron)  # the rail over their heads
    rect(d, px, py + 3, TILE, 1, iron_light)
    rect(d, px, py + 11, TILE, 1, iron_dark)
    for side, neighbour in ((0, level.at(x - 1, y)), (TILE - 3, level.at(x + 1, y))):
        if neighbour != "^":
            rect(d, px + side, py + 1, 3, 14, iron)
            rect(d, px + side, py + 1, 3, 2, iron_light)
            rect(d, px + side, py + 14, 3, 1, iron_dark)


def paint_park_gate(d, level, x, y):
    """A gate in the park railing, `<`: both leaves swung right back
    against the posts, so the path runs straight through."""
    px, py = x * TILE, y * TILE
    iron, iron_light = (58, 62, 66), (96, 100, 104)
    inside = 1 if level.at(x, y + 1) in "gP" else -1  # which way the park lies
    for side in (0, TILE - 3):  # the posts, taller than the railing
        rect(d, px + side, py - 1, 3, 17, iron)
        rect(d, px + side, py - 1, 3, 2, iron_light)
        rect(d, px + side, py - 3, 3, 2, (150, 140, 90))  # a brass finial
    for side in (1, TILE - 5):  # the leaves, folded back along the railing
        top = py + 4 if inside > 0 else py + 2
        rect(d, px + side, top, 4, 10, (40, 44, 48))
        for bar in range(px + side, px + side + 4, 2):
            rect(d, bar, top + 1, 1, 8, iron_light)


def paint_gate(d, level, px, py, x, y):
    """The open churchyard gate under its dynamic closed-gate component."""
    iron, shine = (38, 38, 42), (92, 94, 100)
    rect(d, px, py + 13, 16, 3, shade(PAVING, -30))  # the threshold slab
    left_pier = level.at(x - 1, y) != "x"
    right_pier = level.at(x + 1, y) != "x"
    if left_pier or right_pier:
        sx = px if left_pier else px + 11
        rect(d, sx, py - 1, 5, 17, OLD_TOWN_STONE[0])
        rect(d, sx, py - 1, 5, 2, shade(OLD_TOWN_STONE[0], 16))
        rect(d, sx + 4, py - 1, 1, 17, shade(OLD_TOWN_STONE[0], -40))
        rect(d, sx, py + 5, 5, 1, shade(OLD_TOWN_STONE[0], -26))
        rect(d, sx, py + 11, 5, 1, shade(OLD_TOWN_STONE[0], -26))
        # The corresponding leaf is folded flat against its pier.
        lx = px + 5 if left_pier else px + 8
        rect(d, lx, py + 1, 3, 13, iron)
        rect(d, lx, py + 1, 1, 13, shine)


def paint_moored_boat(d, px, py, w, h):
    """A wooden rowboat tied to the pier, bow to the west, afloat and whole
    enough to step aboard: thwarts across it, oars shipped inside."""
    hull, hull_dark, inside = (120, 70, 44), (80, 46, 30), (154, 116, 78)
    gunwale = (170, 130, 90)
    rows = h - 4
    for r in range(rows):  # the bow narrows to a point, the stern is square
        edge = abs(r - (rows - 1) / 2) / ((rows - 1) / 2)
        indent = int(10 * edge * edge)
        rect(d, px + 3 + indent, py + 3 + r, w - 6 - indent, 1, hull_dark)
        rect(d, px + 2 + indent, py + 2 + r, w - 6 - indent, 1,
             gunwale if r in (0, rows - 1) else hull)
        if 2 <= r < rows - 2:
            rect(d, px + 5 + indent, py + 2 + r, w - 12 - indent, 1, inside)
    for tx in range(px + 20, px + w - 10, 18):  # thwarts
        rect(d, tx, py + 4, 3, rows - 4, hull_dark)
    rect(d, px + 10, py + h // 2 - 1, w - 22, 2, (190, 170, 120))  # an oar
    rect(d, px + w - 3, py + h // 2 - 2, 2, 4, (60, 60, 64))  # the rope's cleat
    rect(d, px + w - 1, py + h // 2 - 1, 3, 1, (170, 160, 130))  # the rope


def paint_bar_doorway(d, px, py):
    """The Bar Arcobaleno's door kicked in: light from the alley falls on
    the step, the dark of the bar behind."""
    rect(d, px + 2, py, 12, 4, (60, 52, 46))
    rect(d, px + 3, py + 4, 10, 10, (150, 142, 124))  # the step, lit
    rect(d, px + 3, py + 4, 10, 1, (110, 102, 90))
    rect(d, px + 5, py + 8, 3, 2, BLOOD_DARK)


def paint_palm(d, rng, px, py):
    """Palm in a stone planter on the promenade; its dusty fronds hang over
    the tile above."""
    rect(d, px + 2, py + 13, 13, 2, (30, 30, 34))
    rect(d, px + 2, py + 7, 12, 7, (150, 142, 126))
    rect(d, px + 3, py + 8, 10, 3, (62, 48, 36))
    rect(d, px + 2, py + 12, 12, 2, (118, 110, 98))
    trunk, ring = (112, 88, 60), (84, 64, 44)
    for i in range(20):  # slightly leaning trunk
        rect(d, px + 7 + (i * i) // 90, py + 9 - i, 3, 1, ring if i % 3 == 0 else trunk)
    top_x, top_y = px + 10, py - 11
    fronds = ((-12, 5), (-10, -4), (-3, -9), (4, -9), (11, -4), (13, 5), (0, 8), (-7, 9), (7, 9))
    for i, (fx, fy) in enumerate(fronds):
        colour = (70, 96, 50) if i % 2 else (92, 116, 60)
        if i in (2, 7):
            colour = (120, 110, 60)  # a dead, yellowed frond
        steps = max(abs(fx), abs(fy))
        for s in range(steps + 1):
            sx = top_x + fx * s // steps
            sy = top_y + fy * s // steps + (s * s) // (steps * 2 + 1)
            rect(d, sx, sy, 2, 2 if s < steps - 2 else 1, colour)
    rect(d, top_x - 1, top_y, 4, 3, (96, 70, 44))  # the crown


def paint_boat(d, px, py, hands):
    """Half-sunk rowboat over two tiles, seen from above: a white hull with
    a blue band, flooded, its stern already under the scum. From some, two
    green hands reach up out of the water inside."""
    hull, rim, stripe = (190, 186, 172), (120, 116, 104), (40, 70, 130)
    d.ellipse([px + 1, py + 4, px + 31, py + 15], fill=SEA_DARK)  # shadow
    d.ellipse([px, py + 2, px + 30, py + 13], fill=hull, outline=rim)
    d.ellipse([px + 2, py + 11, px + 28, py + 14], fill=stripe)
    d.ellipse([px, py + 2, px + 30, py + 12], fill=hull, outline=rim)
    d.ellipse([px + 3, py + 4, px + 27, py + 11], fill=(30, 40, 38))  # flooded
    for bx in (px + 10, px + 18):  # benches
        rect(d, bx, py + 4, 3, 8, (110, 84, 56))
        rect(d, bx, py + 4, 3, 1, (136, 104, 70))
    # the stern sinking: the sea laps over the last third
    d.polygon([(px + 23, py + 15), (px + 31, py + 1), (px + 32, py + 16)], fill=SEA)
    rect(d, px + 22, py + 12, 8, 1, SEA_WAVE)
    rect(d, px + 6, py + 7, 2, 1, (58, 70, 50))
    if hands:
        for hx in (px + 7, px + 15):
            rect(d, hx, py - 1, 2, 8, (96, 130, 80))
            rect(d, hx - 1, py - 3, 1, 3, (96, 130, 80))
            rect(d, hx + 1, py - 4, 1, 3, (96, 130, 80))
            rect(d, hx + 2, py - 3, 1, 3, (96, 130, 80))
            rect(d, hx, py + 3, 2, 1, (70, 30, 26))  # torn sleeve


def paint_portone(d, px, py):
    """The portone of the palazzo past the airliner, where its stairwell
    comes out on the street, standing wide open: a doorway one floor high
    in a surround of pale stone, arched at the top. Both wooden leaves are
    swung right back against the jambs, and between them the hall burns
    with light, its marble floor running in. The light pours out over the
    step and down across the pavement (the cell under it)."""
    stone, stone_dark = (214, 204, 180), (150, 140, 118)
    wood, wood_light, wood_dark = (112, 70, 40), (146, 98, 60), (70, 44, 26)
    glow, glow_hot = (255, 236, 176), (255, 248, 214)
    rect(d, px, py, TILE, TILE, stone)
    rect(d, px, py, 1, TILE, stone_dark)
    rect(d, px + TILE - 1, py, 1, TILE, stone_dark)
    # the opening, arched, full of the hall's light
    rect(d, px + 2, py + 3, 12, 12, glow)
    rect(d, px + 4, py + 1, 8, 2, glow)
    for dx, dy in ((2, 2), (3, 1), (12, 1), (13, 2)):
        rect(d, px + dx, py + dy, 1, 1, stone_dark)
    # inside: the marble floor of the hall, lit
    rect(d, px + 5, py + 6, 6, 9, glow_hot)
    for fy in (py + 9, py + 12):
        rect(d, px + 5, fy, 6, 1, (216, 204, 176))
    rect(d, px + 7, py + 10, 2, 2, BLOOD)
    # the two leaves swung back against the jambs
    for side in (0, 1):
        lx = px + (2 if side == 0 else 11)
        rect(d, lx, py + 4, 3, 11, wood)
        rect(d, lx + (0 if side == 0 else 2), py + 4, 1, 11, wood_dark)
        for ly in (py + 5, py + 10):
            rect(d, lx + 1, ly, 1, 4, wood_light)
        rect(d, lx + (2 if side == 0 else 0), py + 9, 1, 1, (220, 190, 100))
    # the step, and the light poured out across the pavement below
    rect(d, px + 1, py + TILE - 1, 14, 1, stone_dark)
    for step, alpha in enumerate((190, 150, 115, 85, 60, 40, 24)):
        d.rectangle(
            [px + 2 - step, py + TILE + step * 2,
             px + 13 + step, py + TILE + 1 + step * 2],
            fill=(255, 226, 150, alpha))
    rect(d, px + 7, py + TILE + 3, 2, 1, BLOOD)
    rect(d, px + 5, py + TILE + 8, 2, 1, BLOOD_DARK)
    rect(d, px + 9, py + TILE + 11, 1, 1, BLOOD_DARK)


FACTORY_NAME = "INDUSTRIE MOLFETTESI"


def paint_factory(d, rng, level):
    """The big company east of the palazzo: a long, low shed, not a block
    of flats. Its roof seen from above, corrugated sheet in saw-tooth bays
    with a strip of skylight along each, over a front of ribbed metal
    cladding on a concrete plinth; its name on a board over the gate, the
    gate `Ø` rolled up into its drum with the dark of the offices inside
    and a screen or two still lit, the loading bays either side shut behind
    their shutters. Tagged, burnt at one end, blood thrown up against the
    cladding by whoever got in first."""
    cells = [(x, y) for y in range(level.height) for x in range(level.width)
             if level.at(x, y) in "ÆØ"]
    if not cells:
        return
    xs = [x for x, _ in cells]
    ys = [y for _, y in cells]
    px, py = min(xs) * TILE, min(ys) * TILE
    w = (max(xs) - min(xs) + 1) * TILE
    h = (max(ys) - min(ys) + 1) * TILE
    ground = py + h
    eaves = py + 2 * TILE  # the roof over the first two rows, then the front
    # The roof: saw-tooth bays of grey-green sheet, ribs across them, and
    # the skylight strip under each ridge.
    sheet, sheet_dark, sheet_light = (120, 132, 124), (92, 102, 96),         (150, 162, 152)
    rect(d, px, py, w, eaves - py, sheet)
    for by in range(py, eaves, 8):
        rect(d, px, by, w, 1, sheet_light)
        rect(d, px, by + 5, w, 2, (150, 190, 200))  # the skylight
        rect(d, px, by + 7, w, 1, sheet_dark)
        for rx in range(px + 2, px + w, 4):
            rect(d, rx, by + 1, 1, 4, sheet_dark)
    for _ in range(max(1, w // 60)):  # a sheet blown off, the dark below
        hx = px + rng.randrange(8, max(9, w - 16))
        rect(d, hx, py + 2, 10, 5, (26, 28, 30))
    rect(d, px, py, 1, eaves - py, sheet_dark)
    rect(d, px + w - 1, py, 1, eaves - py, sheet_dark)
    # the gutter along the eaves, and its shadow on the front
    rect(d, px, eaves - 2, w, 2, (70, 76, 80))
    rect(d, px, eaves, w, 2, (104, 112, 116))
    # The front: ribbed cladding, pale blue-grey, on a concrete plinth.
    clad, clad_dark = (176, 190, 196), (148, 162, 170)
    rect(d, px, eaves + 2, w, ground - eaves - 2, clad)
    for rx in range(px + 1, px + w, 3):
        rect(d, rx, eaves + 2, 1, ground - eaves - 2, clad_dark)
    rect(d, px, ground - 6, w, 6, (150, 146, 136))
    rect(d, px, ground - 6, w, 1, (120, 116, 108))
    # The gate: rolled up into its drum, the offices dark inside.
    gate = [x for x, y in cells if level.at(x, y) == "Ø"]
    gx0, gx1 = min(gate) * TILE, (max(gate) + 1) * TILE
    opening = ground - 26
    rect(d, gx0 - 3, opening - 6, gx1 - gx0 + 6, 6, (70, 76, 84))  # drum
    rect(d, gx0 - 3, opening - 6, gx1 - gx0 + 6, 1, (120, 126, 132))
    rect(d, gx0 - 3, opening, 3, 26, (70, 76, 84))  # its guides
    rect(d, gx1, opening, 3, 26, (70, 76, 84))
    rect(d, gx0, opening, gx1 - gx0, 26, (14, 16, 20))
    rect(d, gx0, opening, gx1 - gx0, 2, (100, 106, 112))  # the slat bottom
    # inside: the partitions of the cubicles, a screen or two still lit
    for cx in range(gx0 + 3, gx1 - 6, 10):
        rect(d, cx, opening + 10, 8, 3, (46, 54, 70))
        if rng.random() < 0.6:
            rect(d, cx + 2, opening + 6, 4, 3, (60, 150, 130))
    rect(d, gx0, ground - 8, gx1 - gx0, 8, (40, 42, 46))  # the vinyl
    # its name on a board over the gate
    tw = text_width(FACTORY_NAME) * 2
    tx = (gx0 + gx1) // 2 - tw // 2
    tx = max(px + 6, min(tx, px + w - tw - 6))
    rect(d, tx - 4, eaves + 1, tw + 8, 12, (40, 70, 120))
    rect(d, tx - 4, eaves + 12, tw + 8, 1, (24, 40, 70))
    paint_text(d, tx, eaves + 2, FACTORY_NAME, (240, 236, 220),
               missing=(3,), scale=2)
    # loading bays either side of the gate, their shutters down, the dock
    # bumpers and the yellow and black edge
    for bay in (gx0 - 64, gx1 + 24):
        if bay < px or bay + 40 > px + w:
            continue
        rect(d, bay - 2, ground - 26, 44, 26, (62, 66, 70))
        for sy in range(ground - 24, ground - 4, 3):
            rect(d, bay, sy, 40, 2, (132, 136, 138))
        for i, sx in enumerate(range(bay - 2, bay + 42, 4)):
            rect(d, sx, ground - 28, 4, 2,
                 (230, 190, 40) if i % 2 == 0 else (30, 30, 30))
        for sx in (bay + 2, bay + 34):
            rect(d, sx, ground - 8, 4, 6, (30, 30, 32))
    # burnt at the west end, where a car went up against it
    rect(d, px, eaves + 2, 26, ground - eaves - 2, (58, 54, 52))
    rect(d, px + 3, eaves - 4, 18, 6, (80, 76, 72))
    for rx in range(px + 1, px + 26, 3):
        rect(d, rx, eaves + 2, 1, ground - eaves - 8, (44, 40, 38))
    rect(d, gx1 + 6, ground - 22, 8, 10, BLOOD)
    rect(d, gx1 + 9, ground - 12, 2, 6, BLOOD_DARK)
    # tags
    paint_text(d, px + w - 60, ground - 14, "VIA", (200, 40, 40))