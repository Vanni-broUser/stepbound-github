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


def build_grappling_hook(path: str) -> None:
    image = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    dark = (92, 98, 110, 255)
    steel = (176, 184, 196, 255)
    shine = (240, 244, 248, 255)
    rope_dark = (120, 74, 30, 255)
    rope = (222, 164, 84, 255)
    rope_light = (250, 214, 150, 255)
    # The hook, down the left: the eye, the shank and three prongs
    # curling up from the crown.
    d.rectangle([3, 0, 5, 2], outline=dark)
    d.rectangle([4, 2, 5, 12], fill=steel)
    d.line([(3, 3), (3, 12)], fill=dark)
    d.line([(6, 3), (6, 11)], fill=dark)
    d.line([(4, 3), (4, 10)], fill=shine)
    d.line([(3, 12), (1, 12), (0, 11), (0, 8)], fill=steel)
    d.line([(3, 13), (1, 13)], fill=dark)
    d.point((0, 7), fill=shine)
    d.point((1, 6), fill=steel)
    d.line([(6, 12), (8, 12), (9, 11), (9, 8)], fill=steel)
    d.line([(6, 13), (8, 13)], fill=dark)
    d.point((9, 7), fill=shine)
    d.point((8, 6), fill=steel)
    d.rectangle([4, 13, 5, 14], fill=steel)
    d.line([(3, 15), (6, 15)], fill=dark)
    # A thick coil of rope hung on the right, above the right prong, tied
    # to the eye.
    d.ellipse([9, 0, 15, 7], fill=rope_dark)
    d.ellipse([10, 1, 14, 6], fill=rope)
    d.rectangle([11, 3, 12, 4], fill=(0, 0, 0, 0))
    for point in ((11, 1), (14, 3), (10, 5), (13, 6)):
        d.point(point, fill=rope_light)
    d.line([(6, 1), (9, 2)], fill=rope)
    d.point((7, 2), fill=rope_dark)
    # The loose end, hanging down beside the prong.
    d.line([(14, 7), (14, 14)], fill=rope)
    d.line([(15, 7), (15, 13)], fill=rope_dark)
    d.point((14, 10), fill=rope_light)
    d.point((14, 13), fill=rope_light)
    d.point((14, 15), fill=rope_dark)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, optimize=True)


if __name__ == "__main__":
    build_episcopal_ring(os.path.join("assets", "objects", "episcopal_ring.png"))
    build_grappling_hook(os.path.join("assets", "objects", "grappling_hook.png"))
