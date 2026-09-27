#!/usr/bin/env python3
"""Generate Mario's four Halloween wardrobe atlases.

The source sheets are Mario's production walk, gun and pickup atlases.  Every
variant keeps their 16x24 frame grid and foot anchors while applying a compact,
direction-aware pixel treatment:

* ghost: sheet, eye holes, visible hands and backpack over the costume;
* vampire: black-and-burgundy clothes, cape, raised collar and fangs;
* jack_o_lantern: medieval traveller clothes and a carved pumpkin helmet;
* zombie: green skin, tired eyes and torn, weathered clothes.

Run from the repository root:

    python tools/generate_halloween_skins.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

from clean_halloween_edges import build_preview, clean_image

W, H = 16, 24
ROOT = Path("assets/characters/mario/sprites")
PREVIEW = Path("docs/previews/mario_halloween_skins.png")
ROWS = ("south", "west", "east", "north")
SOURCES = {
    "": "base.png",
    "_gun": "base_gun.png",
    "_pickup": "base_pickup.png",
    "_throwable": "base_throwable.png",
}

TRANSPARENT = (0, 0, 0, 0)
OUTLINE = (20, 15, 19, 255)
GHOST_LIGHT = (244, 239, 220, 255)
GHOST_MID = (211, 215, 211, 255)
GHOST_SHADE = (160, 169, 171, 255)
STRAP = (92, 67, 39, 255)
PACK = (104, 110, 62, 255)
PACK_LIGHT = (137, 139, 76, 255)
VAMPIRE_BLACK = (37, 31, 42, 255)
VAMPIRE_SHADE = (21, 17, 25, 255)
VAMPIRE_RED = (116, 22, 42, 255)
VAMPIRE_LIGHT = (164, 35, 57, 255)
VAMPIRE_FANG = (214, 196, 168, 255)
PUMPKIN = (224, 91, 20, 255)
PUMPKIN_LIGHT = (255, 139, 27, 255)
PUMPKIN_DARK = (139, 47, 16, 255)
PUMPKIN_GLOW = (255, 223, 99, 255)
MEDIEVAL_GREEN = (83, 101, 56, 255)
MEDIEVAL_GREEN_DARK = (52, 67, 39, 255)
MEDIEVAL_BROWN = (91, 60, 43, 255)
MEDIEVAL_BROWN_DARK = (55, 38, 33, 255)
ZOMBIE_SKIN = (165, 187, 91, 255)
ZOMBIE_SKIN_DARK = (91, 119, 57, 255)
ZOMBIE_EYE = (241, 218, 116, 255)
ZOMBIE_RED = (139, 45, 45, 255)
ZOMBIE_BLUE = (67, 91, 116, 255)

PREVIEW_HIGHLIGHTS = (
    (244, 239, 220, 255),
    (232, 216, 194, 255),
    (240, 215, 164, 255),
    (221, 207, 145, 255),
)

ACTION_COLOURS = {
    (38, 40, 46),
    (74, 78, 88),
    (136, 142, 152),
    (255, 248, 214),
    (255, 206, 90),
    (238, 120, 40),
}


def visible(pixel: tuple[int, int, int, int]) -> bool:
    return pixel[3] > 20


def is_action(pixel: tuple[int, int, int, int]) -> bool:
    return pixel[:3] in ACTION_COLOURS or 0 < pixel[3] < 220


def is_skin(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    return a > 200 and r > 145 and g > 80 and b > 45 and r > g > b


def is_red_cloth(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    return a > 200 and r > 70 and r > g * 1.45 and r > b * 1.25


def is_blue_cloth(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    return a > 200 and b > 55 and b > r * 1.18 and b >= g


def is_pack(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    return a > 200 and g >= r * 0.92 and g > b * 1.22 and 40 < g < 155


def shade(pixel, light, dark):
    brightness = sum(pixel[:3]) / 3
    return light if brightness > 105 else dark


def transform_pixels(frame: Image.Image, outfit: str) -> Image.Image:
    out = frame.copy().convert("RGBA")
    px = out.load()
    for y in range(H):
        for x in range(W):
            pixel = px[x, y]
            if not visible(pixel) or is_action(pixel):
                continue
            if outfit == "vampire":
                if is_red_cloth(pixel):
                    px[x, y] = shade(pixel, VAMPIRE_LIGHT, VAMPIRE_RED)
                elif is_blue_cloth(pixel):
                    px[x, y] = shade(pixel, VAMPIRE_BLACK, VAMPIRE_SHADE)
            elif outfit == "jack_o_lantern":
                if is_red_cloth(pixel):
                    px[x, y] = shade(pixel, MEDIEVAL_GREEN, MEDIEVAL_GREEN_DARK)
                elif is_blue_cloth(pixel):
                    px[x, y] = shade(pixel, MEDIEVAL_BROWN, MEDIEVAL_BROWN_DARK)
            elif outfit == "zombie":
                if is_skin(pixel):
                    px[x, y] = shade(pixel, ZOMBIE_SKIN, ZOMBIE_SKIN_DARK)
                elif is_red_cloth(pixel):
                    px[x, y] = ZOMBIE_RED
                elif is_blue_cloth(pixel):
                    px[x, y] = ZOMBIE_BLUE
    return out


def draw_ghost(frame: Image.Image, source: Image.Image, row: int) -> None:
    px = frame.load()
    source_px = source.load()
    for y in range(H):
        for x in range(W):
            pixel = px[x, y]
            if not visible(pixel) or is_action(pixel):
                continue
            if y >= 20 or (y >= 10 and is_skin(source_px[x, y])) or is_pack(pixel):
                continue
            brightness = sum(pixel[:3]) / 3
            px[x, y] = (
                GHOST_LIGHT
                if brightness > 115
                else GHOST_MID
                if brightness > 55
                else GHOST_SHADE
            )

    draw = ImageDraw.Draw(frame)
    # The skirt joins the legs into a readable draped sheet.
    draw.polygon(
        [
            (4, 13),
            (11, 13),
            (12, 19),
            (11, 21),
            (9, 19),
            (8, 21),
            (6, 19),
            (4, 21),
            (3, 19),
        ],
        fill=GHOST_LIGHT,
        outline=OUTLINE,
    )
    # The sheet hood covers Mario's hair and face.
    draw.polygon(
        [(5, 2), (10, 2), (12, 5), (12, 10), (10, 12), (5, 12), (3, 10), (3, 5)],
        fill=GHOST_LIGHT,
        outline=OUTLINE,
    )
    draw.line([(5, 3), (4, 7), (5, 11)], fill=GHOST_MID)
    draw.line([(10, 3), (11, 7), (10, 11)], fill=GHOST_SHADE)
    if row == 0:
        draw.rectangle((5, 6, 6, 8), fill=VAMPIRE_SHADE)
        draw.rectangle((9, 6, 10, 8), fill=VAMPIRE_SHADE)
    elif row == 1:
        draw.rectangle((4, 6, 5, 8), fill=VAMPIRE_SHADE)
    elif row == 2:
        draw.rectangle((10, 6, 11, 8), fill=VAMPIRE_SHADE)

    # Repaint the original hands outside the sleeves.
    for y in range(10, H):
        for x in range(W):
            if is_skin(source_px[x, y]):
                px[x, y] = source_px[x, y]

    # The hiking backpack and straps sit visibly over the sheet.
    if row == 0:
        for x in (4, 11):
            draw.line((x, 10, x, 16), fill=STRAP)
        draw.point((4, 12), fill=PACK_LIGHT)
        draw.point((11, 12), fill=PACK_LIGHT)
    elif row == 1:
        draw.rectangle((10, 10, 13, 17), fill=PACK, outline=OUTLINE)
        draw.line((9, 10, 9, 16), fill=STRAP)
    elif row == 2:
        draw.rectangle((2, 10, 5, 17), fill=PACK, outline=OUTLINE)
        draw.line((6, 10, 6, 16), fill=STRAP)
    else:
        draw.rectangle((4, 9, 11, 17), fill=PACK, outline=OUTLINE)
        draw.line((5, 10, 5, 16), fill=PACK_LIGHT)
        draw.line((10, 10, 10, 16), fill=STRAP)


def cape_layer(row: int) -> Image.Image:
    layer = Image.new("RGBA", (W, H), TRANSPARENT)
    draw = ImageDraw.Draw(layer)
    if row == 0:
        points = [(3, 8), (12, 8), (14, 20), (11, 18), (8, 21), (5, 18), (1, 20)]
    elif row == 1:
        points = [(5, 8), (12, 9), (14, 20), (10, 18), (6, 20)]
    elif row == 2:
        points = [(3, 9), (10, 8), (9, 20), (5, 18), (1, 20)]
    else:
        points = [(3, 8), (12, 8), (13, 20), (10, 18), (8, 21), (5, 18), (2, 20)]
    draw.polygon(points, fill=VAMPIRE_SHADE, outline=OUTLINE)
    draw.line(points[1:4], fill=VAMPIRE_RED)
    return layer


def draw_vampire(frame: Image.Image, row: int) -> Image.Image:
    composed = cape_layer(row)
    composed.alpha_composite(frame)
    draw = ImageDraw.Draw(composed)
    draw.line((4, 10, 7, 12), fill=VAMPIRE_BLACK)
    draw.line((11, 10, 8, 12), fill=VAMPIRE_RED)
    if row == 0:
        draw.point((6, 9), fill=VAMPIRE_FANG)
        draw.point((9, 9), fill=VAMPIRE_FANG)
    elif row == 1:
        draw.point((4, 9), fill=VAMPIRE_FANG)
    elif row == 2:
        draw.point((11, 9), fill=VAMPIRE_FANG)
    return composed


def draw_pumpkin(frame: Image.Image, row: int) -> None:
    draw = ImageDraw.Draw(frame)
    draw.rectangle((2, 1, 13, 11), fill=TRANSPARENT)
    shift = -1 if row == 1 else 1 if row == 2 else 0
    outer = [
        (4 + shift, 3),
        (6 + shift, 1),
        (10 + shift, 1),
        (12 + shift, 3),
        (13 + shift, 6),
        (12 + shift, 10),
        (10 + shift, 12),
        (5 + shift, 11),
        (3 + shift, 8),
        (3 + shift, 5),
    ]
    draw.polygon(outer, fill=PUMPKIN_DARK, outline=OUTLINE)
    inner = [
        (5 + shift, 3),
        (7 + shift, 2),
        (10 + shift, 3),
        (11 + shift, 5),
        (11 + shift, 9),
        (9 + shift, 10),
        (5 + shift, 9),
        (4 + shift, 6),
    ]
    draw.polygon(inner, fill=PUMPKIN, outline=PUMPKIN_LIGHT)
    draw.line((7 + shift, 2, 7 + shift, 10), fill=PUMPKIN_LIGHT)
    draw.line((9 + shift, 2, 10 + shift, 10), fill=PUMPKIN_DARK)
    draw.rectangle((7 + shift, 0, 8 + shift, 2), fill=MEDIEVAL_GREEN_DARK)
    if row == 0:
        draw.polygon([(5, 5), (7, 6), (5, 7)], fill=PUMPKIN_GLOW)
        draw.polygon([(11, 5), (9, 6), (11, 7)], fill=PUMPKIN_GLOW)
        draw.line((6, 9, 10, 9), fill=PUMPKIN_GLOW)
        draw.point((7, 10), fill=PUMPKIN_GLOW)
        draw.point((9, 10), fill=PUMPKIN_GLOW)
    elif row == 1:
        draw.polygon([(3, 5), (6, 6), (4, 7)], fill=PUMPKIN_GLOW)
        draw.line((4, 9, 7, 9), fill=PUMPKIN_GLOW)
    elif row == 2:
        draw.polygon([(13, 5), (10, 6), (12, 7)], fill=PUMPKIN_GLOW)
        draw.line((9, 9, 12, 9), fill=PUMPKIN_GLOW)


def draw_zombie(frame: Image.Image, row: int, column: int) -> None:
    draw = ImageDraw.Draw(frame)
    if row == 0:
        draw.point((6, 7), fill=ZOMBIE_EYE)
        draw.point((9, 7), fill=ZOMBIE_EYE)
    elif row == 1:
        draw.point((4, 7), fill=ZOMBIE_EYE)
    elif row == 2:
        draw.point((11, 7), fill=ZOMBIE_EYE)
    # A few stable tears and stitches; vary one pixel across walk frames.
    tear = 1 if column % 2 else 0
    draw.line((6 + tear, 13, 7 + tear, 14), fill=OUTLINE)
    draw.point((8 - tear, 18), fill=OUTLINE)
    draw.point((9 - tear, 19), fill=OUTLINE)


def make_frame(source: Image.Image, outfit: str, row: int, column: int) -> Image.Image:
    if outfit == "ghost":
        frame = source.copy().convert("RGBA")
        draw_ghost(frame, source, row)
        return frame
    frame = transform_pixels(source, outfit)
    if outfit == "vampire":
        return draw_vampire(frame, row)
    if outfit == "jack_o_lantern":
        draw_pumpkin(frame, row)
    else:
        draw_zombie(frame, row, column)
    return frame


def generate(outfit: str, suffix: str, source_name: str) -> None:
    source_sheet = Image.open(ROOT / source_name).convert("RGBA")
    output = Image.new("RGBA", source_sheet.size, TRANSPARENT)
    for row in range(4):
        for column in range(6):
            box = (column * W, row * H, (column + 1) * W, (row + 1) * H)
            source = source_sheet.crop(box)
            output.alpha_composite(
                make_frame(source, outfit, row, column),
                (column * W, row * H),
            )
    path = ROOT / f"{outfit}{suffix}.png"
    output.save(path)
    print(f"wrote {path}")


def clean_preview_highlights() -> None:
    """Keeps the review sheet from reintroducing glaring white specks."""
    if not PREVIEW.exists():
        return
    image = Image.open(PREVIEW).convert("RGBA")
    px = image.load()
    for y in range(80, min(670, image.height)):
        for x in range(image.width):
            if px[x, y][:3] == (255, 255, 255):
                px[x, y] = PREVIEW_HIGHLIGHTS[min(x // 320, 3)]
            elif px[x, y][:3] == (250, 240, 218):
                px[x, y] = VAMPIRE_FANG
    image.save(PREVIEW)
    print(f"wrote {PREVIEW}")


def main() -> None:
    for outfit in ("ghost", "vampire", "jack_o_lantern", "zombie"):
        for suffix, source in SOURCES.items():
            generate(outfit, suffix, source)
            path = ROOT / f"{outfit}{suffix}.png"
            cleaned, _ = clean_image(path, portrait=False)
            cleaned.save(path)
    clean_preview_highlights()
    build_preview().save(PREVIEW)


if __name__ == "__main__":
    main()
