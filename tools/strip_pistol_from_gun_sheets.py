#!/usr/bin/env python3
"""Take the pistol out of the gun sheets that were drawn with it in hand.

A weapon is a layer of its own (assets/objects/pistol_held.png, and the
golden one), drawn at runtime over whichever outfit's gun pose Mario is in:
the outfit only gives the moveset. tools/generate_protagonist_actions.py
builds base_gun.png and cultist_gun.png that way; the other outfits' gun
sheets were made over the old base one, pistol included. Every pixel the
pistol layer covers is given back what lies under it in that outfit's own
idle frame (the east one mirrored for the west, as the poses are made), so
running it again changes nothing.

Run from the repository root:  python tools/strip_pistol_from_gun_sheets.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

W, H = 16, 24
SPRITES = Path("assets/characters/mario/sprites")
PISTOL = Path("assets/objects/pistol_held.png")
OUTFITS = ("ghost", "vampire", "jack_o_lantern", "zombie", "roma", "lazio")
EAST, WEST = 2, 1


def idle_cell(idle: Image.Image, row: int, column: int) -> Image.Image:
    """The idle frame a gun pose was made from: the breathing one for the
    third aiming frame, and the east one mirrored for the west."""
    breathe = 1 if column == 2 else 0
    source = EAST if row == WEST else row
    cell = idle.crop((breathe * W, source * H, breathe * W + W, source * H + H))
    if row == WEST:
        cell = cell.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return cell


def strip(outfit: str, pistol: Image.Image) -> None:
    path = SPRITES / f"{outfit}_gun.png"
    sheet = Image.open(path).convert("RGBA")
    idle = Image.open(SPRITES / f"{outfit}.png").convert("RGBA")
    for row in range(4):
        for column in range(6):
            under = idle_cell(idle, row, column)
            for y in range(H):
                for x in range(W):
                    at = (column * W + x, row * H + y)
                    if pistol.getpixel(at)[3] > 0:
                        sheet.putpixel(at, under.getpixel((x, y)))
    sheet.save(path)


def main() -> None:
    pistol = Image.open(PISTOL).convert("RGBA")
    for outfit in OUTFITS:
        strip(outfit, pistol)
    print(f"stripped the pistol from {len(OUTFITS)} gun sheets")


if __name__ == "__main__":
    main()
