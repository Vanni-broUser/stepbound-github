#!/usr/bin/env python3
"""Build the small quest-item sprites used directly by the game."""

from __future__ import annotations

import os

from PIL import Image, ImageDraw


def build_episcopal_ring(path: str) -> None:
    image = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    # A heavy gold signet ring with a violet episcopal stone.
    d.ellipse([3, 5, 12, 14], fill=(92, 62, 20, 255))
    d.ellipse([5, 7, 10, 13], fill=(0, 0, 0, 0))
    d.rectangle([4, 3, 11, 8], fill=(190, 142, 42, 255))
    d.rectangle([5, 2, 10, 6], fill=(226, 184, 72, 255))
    d.rectangle([6, 3, 9, 5], fill=(104, 54, 126, 255))
    d.point((7, 3), fill=(214, 178, 232, 255))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, optimize=True)


if __name__ == "__main__":
    build_episcopal_ring(os.path.join("assets", "sprites", "episcopal_ring.png"))
