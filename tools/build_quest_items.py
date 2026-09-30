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


def build_rocket_launcher(path: str) -> None:
    image = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    olive_dark = (54, 66, 34, 255)
    olive = (98, 116, 58, 255)
    olive_light = (146, 164, 92, 255)
    black = (34, 34, 38, 255)
    red = (190, 44, 34, 255)
    red_light = (238, 104, 80, 255)
    # The tube, lying along the badge and tipped up a little at the muzzle.
    d.polygon([(1, 9), (13, 6), (14, 9), (2, 12)], fill=olive_dark)
    d.polygon([(1, 9), (13, 6), (13, 8), (1, 11)], fill=olive)
    d.line([(2, 9), (12, 7)], fill=olive_light)
    # The flared back end, and the rocket's red warhead out of the muzzle.
    d.rectangle([0, 9, 1, 12], fill=black)
    d.polygon([(13, 6), (15, 5), (15, 9), (14, 9)], fill=red)
    d.point((14, 6), fill=red_light)
    # The sight on top and the grip and trigger underneath.
    d.rectangle([6, 5, 7, 7], fill=black)
    d.point((6, 5), fill=olive_light)
    d.rectangle([7, 11, 8, 14], fill=black)
    d.rectangle([4, 11, 5, 13], fill=olive_dark)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, optimize=True)


def build_grappling_hook_held(path: str) -> None:
    # The hook in Mario's hand as he winds up the throw: 8x8, like
    # molotov_held.png, drawn at the same attachment points.
    image = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    dark = (92, 98, 110, 255)
    steel = (196, 204, 214, 255)
    rope = (222, 164, 84, 255)
    d.point((4, 0), fill=rope)
    d.point((5, 0), fill=rope)
    d.rectangle([3, 0, 3, 5], fill=steel)
    d.point((4, 1), fill=dark)
    d.line([(3, 6), (1, 6), (0, 5), (0, 4)], fill=steel)
    d.line([(3, 6), (5, 6), (6, 5), (6, 4)], fill=steel)
    d.line([(1, 7), (5, 7)], fill=dark)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, optimize=True)


def build_gold_ingot(path: str) -> None:
    image = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    dark = (138, 94, 20, 255)
    gold = (214, 162, 44, 255)
    light = (246, 208, 96, 255)
    shine = (255, 244, 196, 255)
    # A bar of gold seen from above and in front: its sloping top face,
    # lighter, over its front, the stamp pressed into the top.
    d.polygon([(1, 11), (3, 5), (13, 5), (15, 11)], fill=gold)
    d.polygon([(3, 6), (4, 5), (12, 5), (13, 6), (12, 9), (4, 9)], fill=light)
    d.rectangle([1, 11, 15, 13], fill=dark)
    d.line([(1, 11), (15, 11)], fill=gold)
    d.line([(4, 5), (12, 5)], fill=shine)
    d.point((5, 6), fill=shine)
    d.point((6, 6), fill=shine)
    d.rectangle([7, 7, 9, 8], fill=gold)
    d.point((8, 7), fill=dark)
    d.line([(2, 14), (14, 14)], fill=(60, 40, 10, 160))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, optimize=True)


def build_colosseum_ticket(path: str) -> None:
    image = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    edge = (110, 86, 50, 255)
    paper = (240, 230, 198, 255)
    paper_dark = (208, 192, 150, 255)
    red = (176, 36, 40, 255)
    stone = (214, 180, 120, 255)
    stone_dark = (168, 132, 82, 255)
    arch = (96, 64, 40, 255)
    # A museum ticket: a cream card with the red band of the entrance
    # along its top, the tear-off stub on the right behind its dotted line,
    # and the Colosseum printed on it, two tiers of arches, the one end
    # broken down.
    d.rectangle([0, 3, 15, 12], fill=paper, outline=edge)
    d.rectangle([1, 4, 10, 5], fill=red)
    for y in range(4, 12, 2):
        d.point((11, y), fill=edge)
    d.rectangle([12, 4, 14, 11], fill=paper_dark)
    d.line([(13, 5), (13, 7)], fill=red)
    d.line([(13, 9), (13, 10)], fill=red)
    d.rectangle([2, 7, 9, 11], fill=stone)
    d.line([(2, 7), (7, 7)], fill=stone_dark)
    d.point((8, 7), fill=paper)
    d.point((9, 7), fill=paper)
    d.point((9, 8), fill=paper)
    for x in (3, 5, 7):
        d.point((x, 8), fill=arch)
    for x in (3, 5, 7, 9):
        d.line([(x, 10), (x, 11)], fill=arch)
    d.line([(1, 13), (15, 13)], fill=(60, 44, 24, 140))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, optimize=True)

if __name__ == "__main__":
    build_episcopal_ring(os.path.join("assets", "objects", "episcopal_ring.png"))
    build_grappling_hook(os.path.join("assets", "objects", "grappling_hook.png"))
    build_grappling_hook_held(
        os.path.join("assets", "objects", "grappling_hook_held.png"))
    build_rocket_launcher(os.path.join("assets", "objects", "rocket_launcher.png"))
    build_gold_ingot(os.path.join("assets", "objects", "gold_ingot.png"))
    build_colosseum_ticket(
        os.path.join("assets", "objects", "colosseum_ticket.png"))
