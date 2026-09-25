#!/usr/bin/env python3
"""Build Mario's action sheets from his real idle frames.

The walk/idle atlas (assets/sprites/protagonist.png) is hand-detailed pixel
art; action frames drawn from scratch looked blocky next to it. This script
starts from the idle frames themselves and only adds what each action needs,
so every frame shares the same head, jacket, backpack and proportions:

  protagonist_gun.png     aim_0 (raising), aim_1/aim_2 (hold, breathing),
                          fire_0 (flash + recoil), fire_1 (fading flash),
                          fire_2 (smoke)
  protagonist_pickup.png  pick_0 bend, pick_1 crouch, pick_2 reach,
                          pick_3 grab, pick_4 rise with the bag, pick_5 stand
  backpack.png            16x16 backpack lying on the ground

Rows: south, west, east, north (see assets/sprites/atlas_manifest.json).
Run from the repository root:  python tools/generate_protagonist_actions.py
"""
from __future__ import annotations

import os
from collections import Counter

from PIL import Image

W, H = 16, 24
SPRITES = os.path.join("assets", "sprites")
ROWS = ("south", "west", "east", "north")

OUTLINE = (14, 10, 12, 255)
METAL_DARK = (38, 40, 46, 255)
METAL = (74, 78, 88, 255)
METAL_LIGHT = (136, 142, 152, 255)
FLASH_CORE = (255, 248, 214, 255)
FLASH = (255, 206, 90, 255)
FLASH_EDGE = (238, 120, 40, 255)
SMOKE = (150, 150, 150, 170)


def load_idle() -> dict[str, list[Image.Image]]:
    sheet = Image.open(os.path.join(SPRITES, "protagonist.png")).convert("RGBA")
    return {
        name: [sheet.crop((c * W, r * H, c * W + W, r * H + H)) for c in (0, 1)]
        for r, name in enumerate(ROWS)
    }


def palette(frames: dict[str, list[Image.Image]]) -> dict[str, tuple]:
    """Pick Mario's own colours out of his frames."""
    colours = Counter()
    for pair in frames.values():
        for frame in pair:
            for pixel in frame.getdata():
                if pixel[3] > 200:
                    colours[pixel[:3]] += 1

    def best(test):
        found = [c for c, _ in colours.most_common() if test(*c)]
        return found[0] + (255,) if found else None

    skin = best(lambda r, g, b: r > 200 and g > 140 and b > 90 and r > g > b)
    jacket = best(lambda r, g, b: r > 110 and g < 70 and b < 70)
    jacket_dark = best(lambda r, g, b: 60 < r < 110 and g < 45 and b < 45)
    trousers = best(lambda r, g, b: b > r and b > 70)
    olive = best(lambda r, g, b: g > r > b and g > 80)
    olive_dark = best(lambda r, g, b: g >= r > b and 45 < g <= 80)
    return {
        "skin": skin,
        "jacket": jacket,
        "jacket_dark": jacket_dark or jacket,
        "trousers": trousers,
        "olive": olive,
        "olive_dark": olive_dark or olive,
    }


def put(frame: Image.Image, x: int, y: int, colour) -> None:
    if 0 <= x < W and 0 <= y < H:
        frame.putpixel((x, y), colour)


def is_skin(pixel, pal) -> bool:
    r, g, b, a = pixel
    sr, sg, sb, _ = pal["skin"]
    return a > 200 and abs(r - sr) < 40 and abs(g - sg) < 45 and abs(b - sb) < 50


def hide_hanging_hands(frame: Image.Image, pal, from_row: int = 15) -> None:
    """The idle hands hang by the hips; raised arms take them away."""
    for y in range(from_row, 20):
        for x in range(W):
            if is_skin(frame.getpixel((x, y)), pal):
                frame.putpixel((x, y), pal["jacket_dark"])


# ------------------------------------------------------------------- gun


def arm_east(frame, pal, lift: int = 0, raised: bool = True) -> tuple[int, int]:
    """Arm stretched towards the east; returns the muzzle position."""
    if raised:
        y = 13 - lift
        for x in range(8, 11):
            put(frame, x, y, pal["jacket"])
            put(frame, x, y + 1, pal["jacket_dark"])
            put(frame, x, y - 1, OUTLINE)
            put(frame, x, y + 2, OUTLINE)
        put(frame, 11, y, pal["skin"])
        put(frame, 11, y + 1, pal["skin"])
        put(frame, 11, y - 1, OUTLINE)
        put(frame, 11, y + 2, OUTLINE)
        # pistol: slide, barrel and grip under the hand
        for x in (12, 13, 14):
            put(frame, x, y - 1, OUTLINE)
            put(frame, x, y, METAL)
            put(frame, x, y + 1, METAL_DARK)
        put(frame, 13, y, METAL_LIGHT)
        put(frame, 12, y + 2, METAL_DARK)
        put(frame, 12, y + 3, OUTLINE)
        return 15, y
    # half-raised: arm angled down, pistol pointing at the ground ahead
    put(frame, 8, 14, pal["jacket"])
    put(frame, 9, 15, pal["jacket"])
    put(frame, 10, 16, pal["skin"])
    for x, yy in ((11, 16), (12, 17)):
        put(frame, x, yy, METAL)
        put(frame, x, yy + 1, METAL_DARK)
    return 13, 18


def flash_east(frame, mx: int, my: int, big: bool) -> None:
    put(frame, mx, my, FLASH_CORE)
    put(frame, mx, my + 1, FLASH)
    if big:
        put(frame, mx, my - 1, FLASH)
        put(frame, mx, my + 2, FLASH_EDGE)
        put(frame, mx - 1, my - 2, FLASH_EDGE)
        put(frame, mx - 1, my + 3, FLASH_EDGE)


def gun_south(frame, pal, lift: int = 0, raised: bool = True) -> tuple[int, int]:
    y = 14 - lift
    for x in (4, 5, 10, 11):
        put(frame, x, y, pal["jacket"])
    put(frame, 6, y + 1, pal["skin"])
    put(frame, 9, y + 1, pal["skin"])
    if not raised:
        put(frame, 7, y + 2, METAL)
        put(frame, 8, y + 2, METAL)
        return 7, y + 2
    for x in (6, 7, 8, 9):
        put(frame, x, y - 1, OUTLINE)
    put(frame, 7, y, METAL_LIGHT)
    put(frame, 8, y, METAL)
    put(frame, 7, y + 1, METAL_DARK)
    put(frame, 8, y + 1, OUTLINE)  # the muzzle, seen head-on
    return 8, y + 1


def flash_south(frame, mx: int, my: int, big: bool) -> None:
    put(frame, mx, my, FLASH_CORE)
    put(frame, mx - 1, my, FLASH)
    put(frame, mx, my - 1, FLASH)
    if big:
        put(frame, mx + 1, my, FLASH)
        put(frame, mx, my + 1, FLASH)
        put(frame, mx - 2, my, FLASH_EDGE)
        put(frame, mx + 2, my, FLASH_EDGE)
        put(frame, mx, my - 2, FLASH_EDGE)
        put(frame, mx, my + 2, FLASH_EDGE)


def arms_north(frame, pal, lift: int = 0) -> tuple[int, int]:
    """Seen from behind: elbows out, the pistol hidden by the head."""
    y = 13 - lift
    for x in (2, 3):
        put(frame, x, y, pal["jacket"])
        put(frame, x, y - 1, OUTLINE)
    for x in (12, 13):
        put(frame, x, y, pal["jacket"])
        put(frame, x, y - 1, OUTLINE)
    return 8, 2


def flash_north(frame, mx: int, my: int, big: bool) -> None:
    put(frame, mx, my, FLASH_CORE)
    put(frame, mx - 1, my, FLASH)
    if big:
        put(frame, mx, my - 1, FLASH)
        put(frame, mx - 1, my - 1, FLASH_EDGE)
        put(frame, mx - 2, my, FLASH_EDGE)
        put(frame, mx + 1, my, FLASH_EDGE)


def gun_frames(idle, pal, direction: str) -> list[Image.Image]:
    """aim_0, aim_1, aim_2, fire_0, fire_1, fire_2 for one direction."""
    base_name = "east" if direction == "west" else direction
    frames = []
    for index in range(6):
        breathe = 1 if index == 2 else 0
        frame = idle[base_name][breathe].copy()
        hide_hanging_hands(frame, pal)
        raised = index != 0
        recoil = 1 if index == 3 else 0
        if base_name == "east":
            mx, my = arm_east(frame, pal, lift=recoil, raised=raised)
            if index in (3, 4):
                flash_east(frame, mx, my, big=index == 3)
        elif base_name == "south":
            mx, my = gun_south(frame, pal, lift=recoil, raised=raised)
            if index in (3, 4):
                flash_south(frame, mx, my, big=index == 3)
        else:
            mx, my = arms_north(frame, pal, lift=recoil if raised else -1)
            if index in (3, 4):
                flash_north(frame, mx, my, big=index == 3)
        if index == 5:  # a wisp of smoke from the muzzle
            sx, sy = {"east": (14, 10), "south": (8, 10), "north": (8, 1)}[base_name]
            put(frame, sx, sy, SMOKE)
            put(frame, sx - 1, sy - 1, SMOKE)
        if direction == "west":
            frame = frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        frames.append(frame)
    return frames


# ---------------------------------------------------------------- pickup


def crouch(frame: Image.Image, depth: int) -> Image.Image:
    """Lower the upper body by `depth` px onto bent legs."""
    if depth == 0:
        return frame.copy()
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    upper = frame.crop((0, 0, W, 18))
    legs = frame.crop((0, 18 + depth, W, H))
    out.alpha_composite(legs, (0, 18 + depth))
    out.alpha_composite(upper, (0, depth))
    return out


def bag_pixels(frame, pal, x: int, y: int) -> None:
    """A 4x3 backpack held in the hand, top-left at (x, y)."""
    for dx in range(4):
        put(frame, x + dx, y - 1, OUTLINE)
        put(frame, x + dx, y + 3, OUTLINE)
        for dy in range(3):
            put(frame, x + dx, y + dy, pal["olive"] if dy < 2 else pal["olive_dark"])
    put(frame, x + 1, y, pal["olive_dark"])


def pickup_frames(idle, pal, direction: str) -> list[Image.Image]:
    base_name = "east" if direction == "west" else direction
    base = idle[base_name][0]
    frames = []
    for index, depth in enumerate((2, 4, 4, 4, 2, 0)):
        frame = crouch(base, depth)
        if 1 <= index <= 4:
            hide_hanging_hands(frame, pal, from_row=15 + depth)
        if base_name == "east":
            if depth:
                put(frame, 11, 19 + depth // 2, pal["trousers"])  # knee
            if index in (2, 3):
                put(frame, 10, 18 + depth, pal["jacket"])
                put(frame, 11, 19 + depth, pal["jacket"])
                put(frame, 12, 20 + depth - 1, pal["skin"])
                if index == 3:
                    bag_pixels(frame, pal, 11, 21)
            elif index == 4:
                put(frame, 10, 16, pal["jacket"])
                put(frame, 11, 17, pal["skin"])
                bag_pixels(frame, pal, 10, 18)
        elif base_name == "south":
            if index in (2, 3):
                for x in (4, 11):
                    put(frame, x, 19 + depth // 2, pal["jacket"])
                put(frame, 5, 21, pal["skin"])
                put(frame, 10, 21, pal["skin"])
                if index == 3:
                    bag_pixels(frame, pal, 6, 20)
            elif index == 4:
                put(frame, 6, 17, pal["skin"])
                put(frame, 9, 17, pal["skin"])
                bag_pixels(frame, pal, 6, 16)
        else:  # north: the reach is hidden, the elbows show the effort
            if index in (2, 3):
                put(frame, 2, 17 + depth // 2, pal["jacket"])
                put(frame, 13, 17 + depth // 2, pal["jacket"])
            elif index == 4:
                put(frame, 2, 16, pal["jacket"])
                put(frame, 13, 16, pal["jacket"])
        if direction == "west":
            frame = frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        frames.append(frame)
    return frames


# -------------------------------------------------------------- backpack


def backpack(pal) -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    olive, dark = pal["olive"], pal["olive_dark"]
    light = tuple(min(255, v + 36) for v in olive[:3]) + (255,)
    strap = (58, 44, 30, 255)
    # ground shadow
    for x in range(3, 14):
        put_any(img, x, 15, (0, 0, 0, 90))
    # body
    for y in range(4, 15):
        for x in range(3, 13):
            put_any(img, x, y, olive)
    for x in range(3, 13):
        put_any(img, x, 3, OUTLINE)
        put_any(img, x, 14, dark)
    for y in range(4, 15):
        put_any(img, 2, y, OUTLINE)
        put_any(img, 13, y, OUTLINE)
    for x in range(3, 13):
        put_any(img, x, 15, OUTLINE)
    # flap and highlight
    for y in range(4, 8):
        for x in range(3, 13):
            put_any(img, x, y, dark if y == 7 else olive)
    for x in range(4, 12):
        put_any(img, x, 4, light)
    # buckle straps and pocket
    for y in range(7, 11):
        put_any(img, 5, y, strap)
        put_any(img, 10, y, strap)
    put_any(img, 5, 10, METAL_LIGHT)
    put_any(img, 10, 10, METAL_LIGHT)
    for x in range(6, 10):
        put_any(img, x, 11, dark)
        put_any(img, x, 13, dark)
    put_any(img, 6, 12, dark)
    put_any(img, 9, 12, dark)
    # carry handle
    for x in range(6, 10):
        put_any(img, x, 1, OUTLINE)
    put_any(img, 5, 2, OUTLINE)
    put_any(img, 10, 2, OUTLINE)
    return img


def put_any(img: Image.Image, x: int, y: int, colour) -> None:
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), colour)


def sheet(rows: list[list[Image.Image]]) -> Image.Image:
    out = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    for r, frames in enumerate(rows):
        for c, frame in enumerate(frames):
            out.alpha_composite(frame, (c * W, r * H))
    return out


def main() -> None:
    idle = load_idle()
    pal = palette(idle)
    missing = [name for name, colour in pal.items() if colour is None]
    if missing:
        raise SystemExit(f"could not find colours: {missing}")
    sheet([gun_frames(idle, pal, d) for d in ROWS]).save(
        os.path.join(SPRITES, "protagonist_gun.png")
    )
    sheet([pickup_frames(idle, pal, d) for d in ROWS]).save(
        os.path.join(SPRITES, "protagonist_pickup.png")
    )
    backpack(pal).save(os.path.join(SPRITES, "backpack.png"))
    print("wrote protagonist_gun.png, protagonist_pickup.png, backpack.png")


if __name__ == "__main__":
    main()
