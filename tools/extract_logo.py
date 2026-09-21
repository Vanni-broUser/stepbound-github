#!/usr/bin/env python3
"""Cut the "Stepbound" sign out of the title card for the main menu.

The sign (metal plate, black "Step", bloody "bound") is cropped from
assets/story/title_loading.jpg and its edges are feathered to transparent,
so it sits on any menu background.

Run from the repository root:  python tools/extract_logo.py
"""
from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFilter

SOURCE = os.path.join("assets", "story", "title_loading.jpg")
OUTPUT = os.path.join("assets", "story", "logo.png")
BOX = (300, 28, 1082, 240)
FEATHER = 10


def main() -> None:
    logo = Image.open(SOURCE).convert("RGBA").crop(BOX)
    mask = Image.new("L", logo.size, 0)
    ImageDraw.Draw(mask).rectangle(
        [FEATHER, FEATHER, logo.width - FEATHER, logo.height - FEATHER],
        fill=255,
    )
    logo.putalpha(mask.filter(ImageFilter.GaussianBlur(FEATHER / 2)))
    logo.save(OUTPUT, optimize=True)
    print(f"{OUTPUT}: {logo.size[0]}x{logo.size[1]}")


if __name__ == "__main__":
    main()
