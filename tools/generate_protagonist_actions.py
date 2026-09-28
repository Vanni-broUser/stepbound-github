#!/usr/bin/env python3
"""Build Mario's action sheets from the real outfit idle frames.

The walk/idle atlas (assets/characters/mario/sprites/base.png) is hand-detailed pixel
art; action frames drawn from scratch looked blocky next to it. This script
starts from the idle frames themselves and only adds what each action needs,
so every frame shares the same head, jacket, backpack and proportions:

  <outfit>_gun.png        aim_0 (raising), aim_1/aim_2 (hold, breathing),
                          fire_0 (flash + recoil), fire_1 (fading flash),
                          fire_2 (smoke): the empty-handed moveset
  pistol_held.png         the pistol alone on the same grid, drawn over any
  pistol_gold_held.png    outfit's gun pose at runtime; the golden one is
                          Luigi's (see SecretMission.unarmedToLuigi)
  base_pickup.png         pick_0 bend, pick_1 crouch, pick_2 reach,
                          pick_3 grab, pick_4 rise with the bag, pick_5 stand
  <outfit>_throwable.png  aim_0/aim_1/aim_2 (hold), throw_0 (wind-up),
                          throw_1 (release), throw_2 (recover)
  backpack.png            16x16 backpack lying on the ground
  molotov_held.png        shared 8x8 weapon layer, composed over every outfit

Rows: south, west, east, north (see assets/characters/atlas_manifest.json).
Run from the repository root:  python tools/generate_protagonist_actions.py
"""

from __future__ import annotations

import os
from collections import Counter

from PIL import Image

W, H = 16, 24
SPRITES = os.path.join("assets", "characters", "mario", "sprites")
OBJECTS = os.path.join("assets", "objects")
ROWS = ("south", "west", "east", "north")
OUTFITS = ("base", "cultist")

OUTLINE = (14, 10, 12, 255)
METAL_DARK = (38, 40, 46, 255)
METAL = (74, 78, 88, 255)
METAL_LIGHT = (136, 142, 152, 255)
# A pistol's metal: dark, mid, light.
STEEL = (METAL_DARK, METAL, METAL_LIGHT)
GOLD = ((140, 100, 20, 255), (212, 162, 44, 255), (251, 227, 138, 255))
FLASH_CORE = (255, 248, 214, 255)
FLASH = (255, 206, 90, 255)
FLASH_EDGE = (238, 120, 40, 255)
SMOKE = (150, 150, 150, 170)
GLASS_DARK = (42, 76, 42, 255)
GLASS = (70, 122, 62, 255)
GLASS_LIGHT = (142, 188, 112, 255)
RAG = (216, 198, 160, 255)
FLAME = (255, 142, 28, 255)
FLAME_CORE = (255, 222, 70, 255)


def load_idle(outfit: str = "base") -> dict[str, list[Image.Image]]:
    sheet = Image.open(os.path.join(SPRITES, f"{outfit}.png")).convert("RGBA")
    return {
        name: [sheet.crop((c * W, r * H, c * W + W, r * H + H)) for c in (0, 1)]
        for r, name in enumerate(ROWS)
    }


def palette(
    frames: dict[str, list[Image.Image]],
    outfit: str = "base",
) -> dict[str, tuple]:
    """Pick Mario's own colours out of his frames."""
    colours = Counter()
    for pair in frames.values():
        for frame in pair:
            for pixel in frame.get_flattened_data():
                if pixel[3] > 200:
                    colours[pixel[:3]] += 1

    def best(test):
        found = [c for c, _ in colours.most_common() if test(*c)]
        return found[0] + (255,) if found else None

    skin = best(lambda r, g, b: r > 200 and g > 110 and b > 45 and r > g > b)
    jacket = best(lambda r, g, b: r > 110 and g < 70 and b < 70)
    jacket_dark = best(lambda r, g, b: 60 < r < 110 and g < 45 and b < 45)
    trousers = best(lambda r, g, b: b > r and b > 70)
    olive = best(lambda r, g, b: g > r > b and g > 80)
    olive_dark = best(lambda r, g, b: g >= r > b and 45 < g <= 80)
    result = {
        "skin": skin,
        "jacket": jacket,
        "jacket_dark": jacket_dark or jacket,
        "trousers": trousers,
        "olive": olive,
        "olive_dark": olive_dark or olive,
    }
    return result


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


def arm_east(
    frame, pal, gun, metal=STEEL, lift: int = 0, raised: bool = True
) -> tuple[int, int]:
    """Arm stretched towards the east, the pistol drawn on [gun]; returns
    the muzzle position."""
    dark, mid, light = metal
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
            put(gun, x, y - 1, OUTLINE)
            put(gun, x, y, mid)
            put(gun, x, y + 1, dark)
        put(gun, 13, y, light)
        put(gun, 12, y + 2, dark)
        put(gun, 12, y + 3, OUTLINE)
        return 15, y
    # half-raised: arm angled down, pistol pointing at the ground ahead
    put(frame, 8, 14, pal["jacket"])
    put(frame, 9, 15, pal["jacket"])
    put(frame, 10, 16, pal["skin"])
    for x, yy in ((11, 16), (12, 17)):
        put(gun, x, yy, mid)
        put(gun, x, yy + 1, dark)
    return 13, 18


def flash_east(frame, mx: int, my: int, big: bool) -> None:
    put(frame, mx, my, FLASH_CORE)
    put(frame, mx, my + 1, FLASH)
    if big:
        put(frame, mx, my - 1, FLASH)
        put(frame, mx, my + 2, FLASH_EDGE)
        put(frame, mx - 1, my - 2, FLASH_EDGE)
        put(frame, mx - 1, my + 3, FLASH_EDGE)


def gun_south(
    frame, pal, gun, metal=STEEL, lift: int = 0, raised: bool = True
) -> tuple[int, int]:
    dark, mid, light = metal
    y = 14 - lift
    for x in (4, 5, 10, 11):
        put(frame, x, y, pal["jacket"])
    put(frame, 6, y + 1, pal["skin"])
    put(frame, 9, y + 1, pal["skin"])
    if not raised:
        put(gun, 7, y + 2, mid)
        put(gun, 8, y + 2, mid)
        return 7, y + 2
    for x in (6, 7, 8, 9):
        put(gun, x, y - 1, OUTLINE)
    put(gun, 7, y, light)
    put(gun, 8, y, mid)
    put(gun, 7, y + 1, dark)
    put(gun, 8, y + 1, OUTLINE)  # the muzzle, seen head-on
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


def gun_frames(
    idle, pal, direction: str, metal=STEEL
) -> tuple[list[Image.Image], list[Image.Image]]:
    """aim_0, aim_1, aim_2, fire_0, fire_1, fire_2 for one direction: the
    empty-handed poses, and the pistol alone, frame by frame, to be drawn
    over them."""
    base_name = "east" if direction == "west" else direction
    frames = []
    guns = []
    for index in range(6):
        breathe = 1 if index == 2 else 0
        frame = idle[base_name][breathe].copy()
        gun = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        hide_hanging_hands(frame, pal)
        raised = index != 0
        recoil = 1 if index == 3 else 0
        if base_name == "east":
            mx, my = arm_east(frame, pal, gun, metal, lift=recoil, raised=raised)
            if index in (3, 4):
                flash_east(frame, mx, my, big=index == 3)
        elif base_name == "south":
            mx, my = gun_south(frame, pal, gun, metal, lift=recoil, raised=raised)
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
            gun = gun.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        frames.append(frame)
        guns.append(gun)
    return frames, guns


# ------------------------------------------------------------ throwable


def cultist_throw_palette(frame: Image.Image, direction: str, pal) -> dict[str, tuple]:
    """Reuse only brown sleeve and skin colours from Mario's cultist skin."""
    if direction == "east":
        jacket_at, dark_at = (8, 14), (8, 15)
        hand_box = (9, 14, 12, 17)
    elif direction == "south":
        jacket_at, dark_at = (3, 14), (4, 14)
        hand_box = (3, 15, 5, 17)
    else:
        jacket_at, dark_at = (10, 13), (11, 13)
        hand_box = (12, 13, 14, 15)

    skin_candidates = []
    for y in range(hand_box[1], hand_box[3]):
        for x in range(hand_box[0], hand_box[2]):
            pixel = frame.getpixel((x, y))
            r, g, b, a = pixel
            if a > 200 and r > 180 and r > g > b:
                skin_candidates.append(pixel)

    result = dict(pal)
    result.update(
        jacket=frame.getpixel(jacket_at),
        jacket_dark=frame.getpixel(dark_at),
        skin=max(
            skin_candidates,
            key=lambda colour: sum(colour[:3]),
            default=pal["skin"],
        ),
    )
    return result


def clear_cultist_throwing_hand(
    frame: Image.Image,
    direction: str,
    index: int,
) -> None:
    """Remove only the old hand, never the brown robe or lowered hood."""
    boxes = {
        "east": [(9, 14, 12, 17)],
        "south": [(3, 15, 5, 17)],
        "north": [(12, 13, 14, 15)],
    }[direction]
    if direction == "south" and index == 4:
        boxes.append((11, 15, 13, 17))

    for x0, y0, x1, y1 in boxes:
        for y in range(y0, y1):
            for x in range(x0, x1):
                r, g, b, a = frame.getpixel((x, y))
                if a > 200 and r > 180 and r > g > b:
                    frame.putpixel((x, y), (0, 0, 0, 0))


def throwable_frames(
    idle,
    pal,
    direction: str,
    outfit: str = "base",
) -> list[Image.Image]:
    """Empty-hand throwable family; the held weapon is a separate layer."""
    base_name = "east" if direction == "west" else direction
    frames = []
    for index in range(6):
        breathe = 1 if index == 2 else 0
        source_name = direction if outfit == "cultist" else base_name
        frame = idle[source_name][breathe].copy()
        if direction == "west" and outfit == "cultist":
            frame = frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        if index < 5:
            pose_pal = pal
            if outfit == "cultist":
                pose_pal = cultist_throw_palette(frame, base_name, pal)
                clear_cultist_throwing_hand(frame, base_name, index)
            else:
                hide_hanging_hands(frame, pal)
            paint_throw_pose(frame, pose_pal, base_name, index)
        if direction == "west":
            frame = frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        frames.append(frame)
    return frames


def paint_throw_pose(frame, pal, direction: str, index: int) -> None:
    """Paint aim, wind-up and release arms without embedding an object."""
    jacket = pal["jacket"]
    dark = pal["jacket_dark"]
    skin = pal["skin"]

    if direction == "east":
        if index < 3:
            lift = 1 if index == 2 else 0
            for x, y in ((8, 14), (9, 13), (10, 12 - lift)):
                put(frame, x, y, jacket)
                put(frame, x, y + 1, dark)
            put(frame, 11, 12 - lift, skin)
            put(frame, 12, 12 - lift, skin)
        elif index == 3:
            for x, y in ((8, 13), (7, 11), (6, 9)):
                put(frame, x, y, jacket)
                put(frame, x, y + 1, dark)
            put(frame, 6, 8, skin)
        else:
            for x in range(8, 13):
                put(frame, x, 11, jacket)
                put(frame, x, 12, dark)
            put(frame, 13, 11, skin)
            put(frame, 14, 11, skin)
        return

    if direction == "south":
        if index < 3:
            lift = 1 if index == 1 else 0
            put(frame, 4, 14, jacket)
            put(frame, 5, 13 - lift, jacket)
            put(frame, 5, 12 - lift, skin)
            put(frame, 6, 14, dark)
        elif index == 3:
            for x, y in ((4, 14), (4, 12), (5, 10)):
                put(frame, x, y, jacket)
                put(frame, x + 1, y, dark)
            put(frame, 5, 8, skin)
            put(frame, 5, 9, skin)
        else:
            for x in (5, 6, 9, 10):
                put(frame, x, 13, jacket)
            put(frame, 7, 14, skin)
            put(frame, 8, 14, skin)
        return

    # North: the arm crosses behind the hood and rises beside it.
    if index < 3:
        lift = 1 if index > 0 else 0
        put(frame, 11, 13 - lift, jacket)
        put(frame, 12, 12 - lift, jacket)
        put(frame, 12, 11 - lift, skin)
    elif index == 3:
        for x, y in ((11, 12), (11, 10), (11, 8)):
            put(frame, x, y, jacket)
            put(frame, x + 1, y, dark)
        put(frame, 11, 6, skin)
        put(frame, 11, 7, skin)
    else:
        for x, y in ((10, 10), (9, 8), (8, 6)):
            put(frame, x, y, jacket)
        put(frame, 8, 5, skin)


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


def held_molotov() -> Image.Image:
    """One shared upright molotov, attached to any throwable pose at runtime."""
    img = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    # Flame and burning rag.
    put_any(img, 3, 0, FLAME)
    put_any(img, 4, 0, FLAME_CORE)
    put_any(img, 3, 1, FLAME_CORE)
    put_any(img, 4, 1, FLAME)
    put_any(img, 3, 2, RAG)
    put_any(img, 4, 2, RAG)
    # Neck and green glass body.
    put_any(img, 3, 3, GLASS_LIGHT)
    put_any(img, 4, 3, GLASS_DARK)
    for y in range(4, 7):
        put_any(img, 2, y, OUTLINE)
        put_any(img, 3, y, GLASS_LIGHT if y == 4 else GLASS)
        put_any(img, 4, y, GLASS)
        put_any(img, 5, y, OUTLINE)
    put_any(img, 3, 7, OUTLINE)
    put_any(img, 4, 7, OUTLINE)
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
    for outfit in OUTFITS:
        outfit_idle = load_idle(outfit)
        outfit_pal = palette(outfit_idle, outfit)
        sheet([gun_frames(outfit_idle, outfit_pal, d)[0] for d in ROWS]).save(
            os.path.join(SPRITES, f"{outfit}_gun.png")
        )
    os.makedirs(OBJECTS, exist_ok=True)
    for name, metal in (("pistol_held", STEEL), ("pistol_gold_held", GOLD)):
        sheet([gun_frames(idle, pal, d, metal)[1] for d in ROWS]).save(
            os.path.join(OBJECTS, f"{name}.png")
        )
    sheet([pickup_frames(idle, pal, d) for d in ROWS]).save(
        os.path.join(SPRITES, "base_pickup.png")
    )
    for outfit in OUTFITS:
        outfit_idle = load_idle(outfit)
        outfit_pal = palette(outfit_idle, outfit)
        sheet(
            [throwable_frames(outfit_idle, outfit_pal, d, outfit) for d in ROWS]
        ).save(
            os.path.join(SPRITES, f"{outfit}_throwable.png")
        )
    os.makedirs(OBJECTS, exist_ok=True)
    backpack(pal).save(os.path.join(OBJECTS, "backpack.png"))
    held_molotov().save(os.path.join(OBJECTS, "molotov_held.png"))
    print(
        "wrote the gun and throwable outfit sheets, base_pickup.png, "
        "assets/objects/backpack.png, molotov_held.png, pistol_held.png "
        "and pistol_gold_held.png"
    )


if __name__ == "__main__":
    main()
