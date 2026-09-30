#!/usr/bin/env python3
"""Remove matte fringes from Mario's Halloween art and rebuild its preview.

The generated portraits sometimes contain a neutral grey antialiasing ring
outside their dark outline.  The source Mario atlases also use partial alpha,
which turns into a pale seam when a recoloured outfit is filtered on a dark
background.  Halloween art is deliberately pixel-sharp, so its alpha is
binary and neutral matte pixels reachable from transparency stop at the dark
outline.

Run from the repository root:

    python tools/clean_halloween_edges.py
    python tools/clean_halloween_edges.py --check
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path("assets/characters/mario")
PREVIEW = Path("docs/previews/mario_halloween_skins.png")
OUTFITS = ("ghost", "vampire", "jack_o_lantern", "zombie")
SUFFIXES = ("", "_gun", "_pickup", "_throwable")
ALPHA_CUTOFF = 128
MATTE_MIN = 45
MATTE_SPREAD = 6
MIN_PORTRAIT_COMPONENT = 64


def neighbours4(x: int, y: int, width: int, height: int):
    for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
        if 0 <= nx < width and 0 <= ny < height:
            yield nx, ny


def neighbours8(x: int, y: int, width: int, height: int):
    for ny in range(max(0, y - 1), min(height, y + 2)):
        for nx in range(max(0, x - 1), min(width, x + 2)):
            if (nx, ny) != (x, y):
                yield nx, ny


def harden_alpha(image: Image.Image) -> int:
    """Make every pixel either fully transparent or fully opaque."""
    pixels = image.load()
    changed = 0
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            replacement = (
                (red, green, blue, 255)
                if alpha >= ALPHA_CUTOFF
                else (0, 0, 0, 0)
            )
            if replacement != pixels[x, y]:
                pixels[x, y] = replacement
                changed += 1
    return changed


def remove_neutral_matte(image: Image.Image) -> int:
    """Remove the one-pixel neutral matte outside the dark outline."""
    pixels = image.load()
    width, height = image.size
    fringe = []
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                continue
            if min(red, green, blue) < MATTE_MIN:
                continue
            if max(red, green, blue) - min(red, green, blue) > MATTE_SPREAD:
                continue
            if not any(
                pixels[nx, ny][3] == 0
                for nx, ny in neighbours4(x, y, width, height)
            ):
                continue
            if not any(
                pixels[nx, ny][3] > 0
                and max(pixels[nx, ny][:3]) < MATTE_MIN
                for nx, ny in neighbours8(x, y, width, height)
            ):
                continue
            fringe.append((x, y))
    for point in fringe:
        pixels[point] = (0, 0, 0, 0)
    return len(fringe)


def remove_specks(image: Image.Image) -> int:
    """Remove tiny disconnected remnants without touching character parts."""
    pixels = image.load()
    width, height = image.size
    seen: set[tuple[int, int]] = set()
    changed = 0
    for y in range(height):
        for x in range(width):
            if (x, y) in seen or pixels[x, y][3] == 0:
                continue
            component = []
            queue = deque([(x, y)])
            seen.add((x, y))
            while queue:
                point = queue.popleft()
                component.append(point)
                for neighbour in neighbours8(*point, width, height):
                    if neighbour in seen or pixels[neighbour][3] == 0:
                        continue
                    seen.add(neighbour)
                    queue.append(neighbour)
            if len(component) >= MIN_PORTRAIT_COMPONENT:
                continue
            for point in component:
                pixels[point] = (0, 0, 0, 0)
            changed += len(component)
    return changed


def clean_image(path: Path, *, portrait: bool) -> tuple[Image.Image, int]:
    image = Image.open(path).convert("RGBA")
    changed = harden_alpha(image)
    if portrait:
        changed += remove_neutral_matte(image)
        changed += remove_specks(image)
    return image, changed


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = (
        Path("C:/Windows/Fonts/arialbd.ttf"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"),
    )
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def _centered_text(
    draw: ImageDraw.ImageDraw,
    center_x: int,
    y: int,
    text: str,
    font: ImageFont.ImageFont,
    fill: tuple[int, int, int],
) -> None:
    box = draw.textbbox((0, 0), text, font=font)
    draw.text((center_x - (box[2] - box[0]) / 2, y), text, font=font, fill=fill)


def _portrait_on_black(path: Path, max_width: int, max_height: int) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    box = image.getbbox()
    if box is None:
        raise ValueError(f"empty portrait: {path}")
    image = image.crop(box)
    black = Image.new("RGB", image.size, "black")
    black.paste(image.convert("RGB"), mask=image.getchannel("A"))
    black.thumbnail((max_width, max_height), Image.Resampling.LANCZOS)
    return black


def build_preview() -> Image.Image:
    canvas = Image.new("RGB", (1280, 720), "black")
    draw = ImageDraw.Draw(canvas)
    panel = (24, 22, 27)
    cream = (239, 228, 207)
    draw.rectangle((0, 0, 1279, 71), fill=panel)
    draw.rectangle((0, 670, 1279, 719), fill=panel)
    _centered_text(draw, 640, 10, "MARIO — HALLOWEEN SKINS", _font(38), cream)

    labels = ("FANTASMA", "VAMPIRO", "JACK-O-LANTERN", "ZOMBI")
    for index, (outfit, label) in enumerate(zip(OUTFITS, labels)):
        center_x = 160 + index * 320
        portrait = _portrait_on_black(
            ROOT / "portraits" / f"{outfit}.png", 280, 335
        )
        canvas.paste(
            portrait,
            (center_x - portrait.width // 2, 130 + (335 - portrait.height)),
        )
        sheet = Image.open(ROOT / "sprites" / f"{outfit}.png").convert("RGBA")
        sheet = sheet.resize((192, 192), Image.Resampling.NEAREST)
        canvas.paste(sheet, (center_x - 96, 475), mask=sheet.getchannel("A"))
        _centered_text(draw, center_x, 680, label, _font(24), cream)
    return canvas


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    dirty = []
    for outfit in OUTFITS:
        portrait_path = ROOT / "portraits" / f"{outfit}.png"
        portrait, changed = clean_image(portrait_path, portrait=True)
        if changed:
            dirty.append((portrait_path, changed))
            if not args.check:
                portrait.save(portrait_path)
        for suffix in SUFFIXES:
            sprite_path = ROOT / "sprites" / f"{outfit}{suffix}.png"
            sprite, changed = clean_image(sprite_path, portrait=False)
            if changed:
                dirty.append((sprite_path, changed))
                if not args.check:
                    sprite.save(sprite_path)

    preview = build_preview()
    preview_changed = not PREVIEW.exists() or preview.tobytes() != Image.open(
        PREVIEW
    ).convert("RGB").tobytes()
    if preview_changed:
        dirty.append((PREVIEW, -1))
        if not args.check:
            preview.save(PREVIEW)

    for path, changed in dirty:
        detail = "preview" if changed < 0 else f"{changed} pixels"
        print(f"{path}: {detail}")
    return 1 if args.check and dirty else 0


if __name__ == "__main__":
    raise SystemExit(main())
