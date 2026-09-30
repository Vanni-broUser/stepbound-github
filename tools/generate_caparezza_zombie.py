#!/usr/bin/env python3
"""Generate the sprite sheets of the Caparezza wanderer.

A tribute to Caparezza, Molfetta's own: one wanderer by the fountain of
the north district wears his great mop of dark curls, a black T-shirt and
black trousers. He is a wanderer in everything but his look, so his
sheets are the wanderer's, repainted: the clothes turned black, the hair
grown into a wide, curly mop that falls past the ears, the face left
clear. No portrait: he is not among the known zombies.

Reads the wanderer's walk sheet (hand-drawn) and the hit, bite and death
sheets generate_action_sprites.py writes, so it runs after it. Sheets use
the project's 4x6 grid of 16x24 cells (south, west, east, north).
"""

from __future__ import annotations

import os

from PIL import Image

SPRITES = os.path.abspath(
    os.path.join(
        os.path.dirname(__file__),
        "..", "assets", "characters", "zombies", "sprites",
    )
)

CELL_W, CELL_H = 16, 24
OUTLINE = (0, 0, 0, 255)

# The curls: a near-black base, a brown mid tone and the grey of his
# salt-and-pepper frizz, laid out as small hooks so the mop reads as
# ringlets rather than a helmet.
CURL_BASE = (32, 27, 27, 255)
CURL_MID = (56, 48, 46, 255)
CURL_HI = (104, 98, 94, 255)
CURL_TILE = (
    "hm..",
    "m..m",
    "..h.",
    ".m..",
)
# The grey goatee.
BEARD = (124, 118, 112, 255)
BEARD_SHADE = (88, 82, 78, 255)

# How far the mop grows past the wanderer's own hair: up, down past the
# ears, and sideways -- behind the head more than in front of it, so it is
# big without falling over the eyes.
GROW_UP = 2
GROW_DOWN = 3
GROW_BEHIND = 3
GROW_FRONT = 1
GROW_SIDES = 3
# Where the mop may reach, so its outline stays inside the frame the
# runtime centres (columns 1 to 14, row 0 up).
MOP_LEFT, MOP_RIGHT, MOP_TOP = 2, CELL_W - 3, 1
DIRECTIONS = ("south", "west", "east", "north")
# The rows of the walk sheet the wanderer's backpack takes.
PACK_TOP, PACK_BOTTOM = 12, 18


def is_outline(pixel) -> bool:
    return max(pixel[:3]) < 34


def is_skin(pixel) -> bool:
    red, green, blue, _ = pixel
    # The face's olive shadows too, which a grey cloth never is.
    return green >= red - 4 and green > blue + 15 and green >= 70


def is_hair(pixel) -> bool:
    red, green, blue, _ = pixel
    # Reddish brown, which the wanderer's boots are not quite.
    return (red > green + 6 and red > blue + 8 and green < red * 0.85
            and max(red, green, blue) < 140)


def is_pack(pixel) -> bool:
    """The olive canvas of the wanderer's backpack and its straps."""
    red, green, blue, _ = pixel
    return green >= red - 6 and green > blue + 12 and 36 <= green < 150


def remove_backpack(pixels, direction: str) -> None:
    """The hand-drawn wanderer carries a backpack; Caparezza does not. In
    profile it is a hump behind the line of the back, which goes, the
    line becoming the outline; from behind, a patch on the back, which
    turns to shirt like the rest."""
    rows = range(PACK_TOP, PACK_BOTTOM + 1)
    if direction in ("west", "east"):
        west = direction == "west"
        for y in rows:
            behind = [x for x in range(CELL_W)
                      if pixels[x, y][3] and is_pack(pixels[x, y])
                      and (x >= 10 if west else x <= 5)]
            if not behind:
                continue
            start = min(behind) if west else max(behind)
            gone = range(start, CELL_W) if west else range(0, start + 1)
            for x in gone:
                pixels[x, y] = (0, 0, 0, 0)
            edge = start - 1 if west else start + 1
            pixels[edge, y] = OUTLINE
    elif direction == "north":
        shirt = [pixels[x, y] for y in rows for x in range(CELL_W)
                 if pixels[x, y][3] and not is_outline(pixels[x, y])
                 and not is_pack(pixels[x, y]) and not is_skin(pixels[x, y])]
        if not shirt:
            return
        cloth = max(set(shirt), key=shirt.count)
        for y in rows:
            patch = [x for x in range(CELL_W)
                     if pixels[x, y][3] and is_pack(pixels[x, y])
                     and 4 <= x <= 11]
            if not patch:
                continue
            for x in range(min(patch), max(patch) + 1):
                pixels[x, y] = cloth

def black_cloth(pixel):
    """The clothes, whatever their colour, in black cotton that keeps the
    folds of the original: its brightness sets the shade."""
    red, green, blue, alpha = pixel
    value = (red * 3 + green * 6 + blue) / 10
    shade = 26 + int(value * 0.22)
    return (shade, shade, shade + 4, alpha)


def repaint_cell(
    cell: Image.Image, head_rows: int | None, direction: str,
) -> Image.Image:
    """Black clothes and the mop of curls on one 16x24 frame.

    [head_rows]: on the hand-drawn walk sheet the hair is told apart from
    the clothes by being in the top rows of the cell; the generated sheets
    paint hair in one colour only, so there it is found wherever it is
    (the dead lie with their heads low in the cell)."""
    pixels = cell.load()
    if head_rows is not None:
        remove_backpack(pixels, direction)
    hair: set[tuple[int, int]] = set()
    skin: set[tuple[int, int]] = set()
    for y in range(CELL_H):
        for x in range(CELL_W):
            pixel = pixels[x, y]
            if not pixel[3] or is_outline(pixel):
                continue
            if is_skin(pixel):
                # Olive rags on the legs pass for skin by hue: the skin
                # showing through the clothes is the bright one.
                if head_rows is None or y <= head_rows or pixel[1] >= 160:
                    skin.add((x, y))
                    continue
            elif is_hair(pixel) and (head_rows is None or y <= head_rows):
                hair.add((x, y))
                continue
            pixels[x, y] = black_cloth(pixel)
    keepout = clear_profile(pixels, hair, skin, direction)
    if not hair:
        return cell

    def empty(x: int, y: int) -> bool:
        return not (0 <= x < CELL_W and 0 <= y < CELL_H) or not pixels[x, y][3]

    # The mop only grows outwards: over the empty cell and the outline
    # round the figure, never over the face, its eyes or the clothes.
    rim = {
        (x, y)
        for y in range(CELL_H) for x in range(CELL_W)
        if pixels[x, y][3] and is_outline(pixels[x, y])
        and any(empty(x + dx, y + dy)
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)))
    }

    def free(x: int, y: int) -> bool:
        return (MOP_LEFT <= x <= MOP_RIGHT and MOP_TOP <= y < CELL_H
                and (x, y) not in keepout
                and (empty(x, y) or (x, y) in rim))

    def grow(mop: set, dx: int, dy: int, times: int, limit=None) -> set:
        for _ in range(times):
            mop = mop | {
                (x + dx, y + dy) for x, y in mop
                if free(x + dx, y + dy) and (limit is None or y + dy <= limit)
            }
        return mop

    top, bottom = min(y for _, y in hair), max(y for _, y in hair)
    mop = set(hair)
    if top > CELL_H // 2:
        # Lying dead, the head low in the cell: the curls spread round it.
        for dx, dy in ((-1, 0), (1, 0), (0, -1)):
            mop = grow(mop, dx, dy, 1)
    else:
        # West-facing he looks left: the mop swells behind, to the right.
        left = GROW_FRONT if direction == "west" else (
            GROW_BEHIND if direction == "east" else GROW_SIDES)
        right = GROW_FRONT if direction == "east" else (
            GROW_BEHIND if direction == "west" else GROW_SIDES)
        mop = grow(mop, 0, -1, GROW_UP)
        mop = grow(mop, -1, 0, left)
        mop = grow(mop, 1, 0, right)
        # The curls fall past the ears, not below the shoulders.
        mop = grow(mop, 0, 1, GROW_DOWN, limit=bottom + GROW_DOWN)
        # Rounded, not square: the corners of the crown go.
        crown = min(y for _, y in mop)
        for row, cut in ((crown, 2), (crown + 1, 1)):
            xs = sorted(x for x, y in mop if y == row)
            if len(xs) > 2 * cut + 2:
                for x in xs[:cut] + xs[-cut:]:
                    mop.discard((x, row))
    # A lone pixel sticking out reads as dirt, not as a curl.
    for x, y in list(mop):
        if (x, y) not in hair and sum(
            (x + dx, y + dy) in mop
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))
        ) <= 1:
            mop.discard((x, y))

    for x, y in mop:
        mark = CURL_TILE[y % 4][(x + y // 4) % 4]
        exposed = (x, y - 1) not in mop
        color = CURL_HI if mark == "h" or (exposed and x % 2) else (
            CURL_MID if mark == "m" else CURL_BASE)
        pixels[x, y] = color
    for x, y in mop:
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if (0 <= nx < CELL_W and 0 <= ny < CELL_H
                    and (nx, ny) not in mop and not pixels[nx, ny][3]):
                pixels[nx, ny] = OUTLINE
    if top <= CELL_H // 2 and direction != "north":
        paint_goatee(pixels, skin, bottom + GROW_DOWN, direction)
    return cell


def clear_profile(pixels, hair: set, skin: set, direction: str) -> set:
    """In profile, no curl in front of the face: from the brow down, the
    wanderer's fringe over the face turns to skin and what hangs in front
    of it goes, and the mop is kept behind the back of the face. Returns
    the tiles the mop must not grow into."""
    if direction not in ("west", "east") or not hair:
        return set()
    if min(y for _, y in hair) > CELL_H // 2:
        return set()  # lying dead
    head = [(x, y) for x, y in skin if y <= max(y for _, y in hair) + 1]
    if not head:
        return set()
    brow = min(y for _, y in head)
    chin = min(max(y for _, y in head), brow + 4)
    xs = [x for x, y in head]
    colours = [pixels[point] for point in head]
    # The face's light tone, not one of its shadows.
    light = [colour for colour in colours if colour[1] >= 170] or colours
    face_colour = max(set(light), key=lambda colour: (light.count(colour), colour))
    west = direction == "west"
    front = min(xs) if west else max(xs)
    back = max(xs) if west else min(xs)

    def in_front_of_back(x: int) -> bool:
        return x <= back if west else x >= back

    def in_front_of_face(x: int) -> bool:
        return x < front - 1 if west else x > front + 1

    keepout = set()
    for y in range(brow, chin + 1):
        for x in range(CELL_W):
            if not in_front_of_back(x):
                continue
            keepout.add((x, y))
            if (x, y) not in hair:
                continue
            hair.discard((x, y))
            if in_front_of_face(x):
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = face_colour
                skin.add((x, y))
    # The lines that parted fringe from face go, and one eye is left,
    # just behind the brow; the outline follows the face round.
    left, right = min(front, back), max(front, back)
    for y in range(brow, chin + 1):
        for x in range(left, right + 1):
            if pixels[x, y][3] and (x, y) not in skin:
                pixels[x, y] = face_colour
                skin.add((x, y))
    pixels[front + 1 if west else front - 1, brow + 1] = OUTLINE
    # A few curls in the corner behind the brow, over the ear, so the mop
    # meets the face in a curve rather than a right angle.
    step = -1 if west else 1
    for x, y in ((back, brow), (back, brow + 1), (back + step, brow)):
        pixels[x, y] = CURL_MID
        skin.discard((x, y))
        hair.add((x, y))
        keepout.discard((x, y))
    for x, y in list(skin):
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1)):
            if 0 <= nx < CELL_W and 0 <= ny < CELL_H and not pixels[nx, ny][3]:
                pixels[nx, ny] = OUTLINE
    # Whatever hung in front of the face was outlined as hair: an outline
    # left there with nothing behind it goes too.
    for y in range(brow, chin + 1):
        for x in range(CELL_W):
            if (in_front_of_face(x) and pixels[x, y][3]
                    and is_outline(pixels[x, y])
                    and not any((x + dx, y + dy) in skin
                                for dx, dy in ((-1, 0), (1, 0),
                                               (0, -1), (0, 1)))):
                pixels[x, y] = (0, 0, 0, 0)
    return keepout

def paint_goatee(pixels, skin: set, below: int, direction: str) -> None:
    """The grey goatee on the chin: the lowest row of the face, where it
    is widest, and one pixel of it under the mouth."""
    face = [(x, y) for x, y in skin if y <= below]
    if not face:
        return
    chin = max(y for _, y in face)
    row = sorted(x for x, y in face if y == chin)
    if direction == "south":
        middle = (row[0] + row[-1]) // 2
        tuft = [x for x in row if abs(x - middle) <= 1]
    elif direction == "west":
        tuft = row[:3]
    else:
        tuft = row[-3:]
    for x in tuft:
        pixels[x, chin] = BEARD
    if chin - 1 >= 0:
        centre = tuft[len(tuft) // 2]
        if (centre, chin - 1) in skin:
            pixels[centre, chin - 1] = BEARD_SHADE

def repaint_sheet(source: str, head_rows: int | None) -> Image.Image:
    sheet = Image.open(os.path.join(SPRITES, source)).convert("RGBA")
    out = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    for top in range(0, sheet.height, CELL_H):
        for left in range(0, sheet.width, CELL_W):
            cell = sheet.crop((left, top, left + CELL_W, top + CELL_H))
            direction = DIRECTIONS[top // CELL_H]
            out.paste(repaint_cell(cell, head_rows, direction), (left, top))
    return out


def main() -> None:
    outputs = {
        "caparezza.png": repaint_sheet("wanderer.png", head_rows=11),
        "caparezza_hit.png": repaint_sheet("wanderer_hit.png", head_rows=None),
        "caparezza_bite.png": repaint_sheet("wanderer_bite.png", head_rows=None),
        "caparezza_death.png": repaint_sheet("wanderer_death.png", head_rows=None),
    }
    for filename, sheet in outputs.items():
        sheet.save(os.path.join(SPRITES, filename))
        print(f"wrote assets/characters/zombies/sprites/{filename}")


if __name__ == "__main__":
    main()
