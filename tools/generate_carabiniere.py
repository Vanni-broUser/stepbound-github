#!/usr/bin/env python3
"""Build the carabiniere zombie sheets from the wanderer's frames.

Same body, walk cycle and green skin as the wanderer, dressed in the
uniform: dark navy jacket and trousers with the red stripe, white cross
belt, black cap with the red band, and a baton in the hand.

  zombie_carabiniere.png        idle/walk (4x6, like every character)
  zombie_carabiniere_bite.png   baton swing: wind-up, swing, strike, recover
                                (the game uses the "bite" slot for attacks)
  zombie_carabiniere_hit.png    flinch
  zombie_carabiniere_death.png  collapse

Run from the repository root:  python tools/generate_carabiniere.py
"""
from __future__ import annotations

import os

from PIL import Image

W, H = 16, 24
SPRITES = os.path.join("assets", "sprites")
ROWS = ("south", "west", "east", "north")

NAVY = (26, 32, 58, 255)
NAVY_LIGHT = (44, 54, 92, 255)
RED = (176, 30, 30, 255)
WHITE = (232, 232, 222, 255)
CAP = (16, 16, 22, 255)
SILVER = (200, 200, 190, 255)
BATON = (22, 22, 26, 255)
BATON_LIGHT = (90, 90, 96, 255)
SWOOSH = (240, 240, 240, 200)
FLASH = (255, 255, 255, 255)


def is_skin(p) -> bool:
    r, g, b, a = p
    return a > 100 and g > r + 8 and g > b


def is_outline(p) -> bool:
    return p[3] > 100 and max(p[:3]) < 22


def dress(frame: Image.Image, direction: str) -> Image.Image:
    out = frame.copy()
    skin_rows = [y for y in range(H) for x in range(W) if is_skin(frame.getpixel((x, y)))]
    face_top = min(skin_rows) if skin_rows else 6
    for y in range(H):
        for x in range(W):
            p = frame.getpixel((x, y))
            if p[3] < 100 or is_skin(p) or is_outline(p):
                continue
            if y < face_top + 2:  # hair -> cap
                out.putpixel((x, y), CAP)
            else:
                lum = sum(p[:3]) / 3
                out.putpixel((x, y), NAVY_LIGHT if lum > 70 else NAVY)
    # red band at the bottom of the cap, silver badge in front
    for x in range(W):
        column = [y for y in range(face_top + 2) if out.getpixel((x, y)) == CAP]
        if column:
            out.putpixel((x, max(column)), RED)
    if direction == "south":
        out.putpixel((7, face_top), SILVER)
        out.putpixel((8, face_top), SILVER)
    # red stripe down the outer side of each trouser leg
    for y in range(18, 23):
        clothes = [x for x in range(W) if out.getpixel((x, y)) in (NAVY, NAVY_LIGHT)]
        if clothes:
            out.putpixel((min(clothes), y), RED)
            out.putpixel((max(clothes), y), RED)
    # white cross belt
    if direction in ("south", "north"):
        for i in range(6):
            x, y = 4 + i + (0 if direction == "south" else 1), 12 + i
            if out.getpixel((x, y)) in (NAVY, NAVY_LIGHT):
                out.putpixel((x, y), WHITE)
    else:
        for y in range(12, 17):
            x = 7 if direction == "east" else 8
            if out.getpixel((x, y)) in (NAVY, NAVY_LIGHT):
                out.putpixel((x, y), WHITE)
    return out


def hand(frame: Image.Image, direction: str) -> tuple[int, int]:
    """Lowest skin pixel on the baton side: the hand."""
    side = range(W // 2, W) if direction in ("south", "east") else range(0, W // 2)
    best = None
    for y in range(12, H):
        for x in side:
            if is_skin(frame.getpixel((x, y))):
                best = (x, y)
    return best or ((12, 17) if direction != "west" else (3, 17))


def put(img, x, y, colour):
    if 0 <= x < W and 0 <= y < H:
        img.putpixel((x, y), colour)


def baton_down(img, hx, hy):
    for i in range(1, 6):
        put(img, hx, hy + i, BATON)
    put(img, hx, hy + 1, BATON_LIGHT)


def load(name):
    sheet = Image.open(os.path.join(SPRITES, name)).convert("RGBA")
    return {
        d: [sheet.crop((c * W, r * H, c * W + W, r * H + H)) for c in range(6)]
        for r, d in enumerate(ROWS)
    }


def base_sheet(frames) -> dict[str, list[Image.Image]]:
    rows = {}
    for d in ROWS:
        dressed = []
        for frame in frames[d]:
            f = dress(frame, d)
            if d != "north":  # the baton hides behind the body from behind
                baton_down(f, *hand(frame, d))
            dressed.append(f)
        rows[d] = dressed
    return rows


def swing_frames(idle: Image.Image, d: str) -> list[Image.Image]:
    """Wind-up, swing, strike (with a swoosh), recover."""
    frames = []
    forward = {"east": 1, "west": -1}.get(d, 0)
    for index in range(4):
        f = idle.copy()
        # hide the hanging baton hand
        for y in range(14, H):
            for x in range(W):
                if f.getpixel((x, y)) in (BATON, BATON_LIGHT):
                    f.putpixel((x, y), (0, 0, 0, 0))
        if d in ("east", "west"):
            back_x = 7 - forward * 4
            if index == 0:  # baton raised behind the head
                for i in range(6):
                    put(f, back_x - forward * (i // 3), 2 + i, BATON)
            elif index == 1:  # overhead
                for i in range(6):
                    put(f, 6 + forward * i, 3 - i // 2, BATON)
            elif index == 2:  # strike forward at chest height
                for i in range(7):
                    put(f, 8 + forward * (2 + i), 12, BATON)
                put(f, 8 + forward * 8, 11, BATON_LIGHT)
                for i in range(4):
                    put(f, 8 + forward * (4 + i), 9 + i // 2, SWOOSH)
            else:  # recover, baton low and forward
                for i in range(4):
                    put(f, 8 + forward * (3 + i // 2), 15 + i, BATON)
        elif d == "south":
            if index == 0:
                for i in range(6):
                    put(f, 12, 1 + i, BATON)
            elif index == 1:
                for i in range(6):
                    put(f, 11 - i // 2, 2 + i // 3, BATON)
            elif index == 2:
                for i in range(6):
                    put(f, 8, 13 + i, BATON)
                for x in range(4, 12):
                    put(f, x, 20, SWOOSH)
            else:
                for i in range(4):
                    put(f, 10, 16 + i, BATON)
        else:  # north: raised above the head, then it disappears ahead
            if index in (0, 1):
                for i in range(5):
                    put(f, 7 + index * 2, 0 + i, BATON)
            elif index == 2:
                for x in range(4, 12):
                    put(f, x, 1, SWOOSH)
        frames.append(f)
    return frames


def flinch(idle: Image.Image, d: str, index: int) -> Image.Image:
    back = {"east": -1, "west": 1}.get(d, 0)
    shift = (1 if index < 2 else 0)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.alpha_composite(idle, (back * shift, -shift if d == "north" else 0))
    if index == 0:  # white flash of the impact
        for y in range(H):
            for x in range(W):
                r, g, b, a = out.getpixel((x, y))
                if a > 100:
                    out.putpixel((x, y), (min(255, r + 110), min(255, g + 110), min(255, b + 110), a))
    return out


def collapse(idle: Image.Image, d: str, index: int) -> Image.Image:
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if index <= 2:  # buckling knees
        depth = (2, 5, 8)[index]
        upper = idle.crop((0, 0, W, 18))
        legs = idle.crop((0, 18 + min(depth, 5), W, H))
        out.alpha_composite(legs, (0, 18 + min(depth, 5)))
        out.alpha_composite(upper, (0, depth))
        return out
    # on the ground: the frame turned on its side and squeezed into the cell
    turned = idle.rotate(90 if d != "east" else -90, expand=True)
    turned = turned.resize((W, 11), Image.NEAREST)
    out.alpha_composite(turned, (0, H - 11))
    if index == 5:
        for y in range(H):
            for x in range(W):
                r, g, b, a = out.getpixel((x, y))
                if a > 100:
                    out.putpixel((x, y), (int(r * 0.8), int(g * 0.8), int(b * 0.8), a))
    return out


def sheet(rows: dict[str, list[Image.Image]], columns: int) -> Image.Image:
    out = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    for r, d in enumerate(ROWS):
        for c in range(columns):
            out.alpha_composite(rows[d][c], (c * W, r * H))
    return out


def main() -> None:
    base = base_sheet(load("zombie_wanderer.png"))
    idle = {d: base[d][0] for d in ROWS}
    outputs = {
        "zombie_carabiniere.png": sheet(base, 6),
        "zombie_carabiniere_bite.png": sheet({d: swing_frames(idle[d], d) for d in ROWS}, 4),
        "zombie_carabiniere_hit.png": sheet(
            {d: [flinch(idle[d], d, i) for i in range(3)] for d in ROWS}, 3
        ),
        "zombie_carabiniere_death.png": sheet(
            {d: [collapse(idle[d], d, i) for i in range(6)] for d in ROWS}, 6
        ),
    }
    for name, image in outputs.items():
        image.save(os.path.join(SPRITES, name))
        print(f"wrote assets/sprites/{name}")


if __name__ == "__main__":
    main()
