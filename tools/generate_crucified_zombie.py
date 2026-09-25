#!/usr/bin/env python3
"""Paint the crucified zombie hanging over the Duomo's altar.

The sheet is the prop the game draws once the mass is over, and it follows
the story frame `assets/story/scene_crucified_zombie.jpg`: a zombie nailed
to a dark wooden cross, cut off at the waist, the arms spread along the
beam with the hands nailed and bleeding, torn pale rags over a green torso,
a cross pendant on its chest, red eyes and an open mouth, and the blood of
the severed trunk pouring down the post.

    assets/sprites/crucified_zombie.png     128x40, four 32x40 frames

The four frames are, in order:

    hang_0    hanging still
    hang_1    the same, one pixel lower: it breathes, or the wind moves it
    twitch_0  the head thrown back, the mouth wide, the arms pulling
    twitch_1  the head fallen to the other side, the body sagging

The game hangs on `hang_*` and plays `twitch_*` now and then with a groan
(`CrucifiedZombieComponent`). Run from the repository root; Pillow only.
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw

OUTPUT = os.path.join("assets", "sprites", "crucified_zombie.png")
FRAME = (32, 40)

# The palette of the game (lib/game/render/pixel_palette.dart) and of the
# story frame: rotting green, the pale grey of the rags, dark wood, blood.
WOOD = (74, 48, 30)
WOOD_LIGHT = (108, 72, 44)
WOOD_DARK = (44, 28, 18)
SKIN = (102, 128, 91)
SKIN_DARK = (64, 84, 61)
SKIN_LIGHT = (134, 156, 112)
RAG = (170, 166, 150)
RAG_DARK = (116, 112, 100)
BLOOD = (154, 30, 30)
BLOOD_DARK = (92, 16, 18)
EYE = (214, 56, 44)
MOUTH = (32, 14, 14)
GOLD = (186, 150, 62)


def rect(d: ImageDraw.ImageDraw, x, y, w, h, colour) -> None:
    if w > 0 and h > 0:
        d.rectangle([x, y, x + w - 1, y + h - 1], fill=colour)


def cross(d: ImageDraw.ImageDraw) -> None:
    """The timbers, the same in every frame: nothing about them moves."""
    # The post, from the top of the frame down past the cut.
    rect(d, 13, 1, 6, 39, WOOD)
    rect(d, 13, 1, 1, 39, WOOD_LIGHT)
    rect(d, 18, 1, 1, 39, WOOD_DARK)
    # The beam.
    rect(d, 1, 11, 30, 5, WOOD)
    rect(d, 1, 11, 30, 1, WOOD_LIGHT)
    rect(d, 1, 15, 30, 1, WOOD_DARK)
    # The grain, and the shadow the post throws on the beam.
    for x in (4, 9, 22, 27):
        rect(d, x, 12, 1, 3, WOOD_DARK)
    rect(d, 12, 11, 1, 5, WOOD_DARK)
    rect(d, 19, 11, 1, 5, WOOD_DARK)


def arms(d: ImageDraw.ImageDraw, lift: int) -> None:
    """Spread along the beam and nailed at the ends. [lift] pulls the
    shoulders up, for the frames where the body strains."""
    for side, inner, outer in ((-1, 12, 2), (1, 19, 29)):
        step = 1 if side > 0 else -1
        # Upper arm: from the shoulder out along the top of the beam.
        for x in range(inner, outer, step):
            reach = abs(x - inner)
            y = 12 - lift + (1 if reach > 4 else 0)
            rect(d, x, y, 1, 2, SKIN)
            rect(d, x, y, 1, 1, SKIN_LIGHT)
            rect(d, x, y + 1, 1, 1, SKIN_DARK)
        # The hand, nailed flat to the timber, and what runs from the nail.
        hand = outer if side > 0 else outer - 1
        rect(d, hand - 1, 12, 3, 3, SKIN)
        rect(d, hand - 1, 12, 3, 1, SKIN_LIGHT)
        rect(d, hand, 13, 1, 1, BLOOD)
        rect(d, hand, 16, 1, 5, BLOOD_DARK)
        rect(d, hand, 16, 1, 2, BLOOD)


def torso(d: ImageDraw.ImageDraw, drop: int, sag: int) -> None:
    """The trunk under the beam, cut clean off at the waist. [drop] moves
    the whole body down, [sag] rounds the shoulders of a body giving way."""
    top = 14 + drop
    cut = 28 + drop
    # Shoulders and chest, narrowing to the cut.
    for y in range(top, cut):
        half = 5 - (y - top) // 6 - (1 if y > cut - 3 else 0)
        rect(d, 16 - half, y, half * 2, 1, SKIN)
        rect(d, 16 - half, y, 1, 1, SKIN_LIGHT)
        rect(d, 15 + half, y, 1, 1, SKIN_DARK)
    # The ribs showing through, and the shoulder line of a sagging body.
    for y in (top + 5, top + 8):
        rect(d, 13, y, 2, 1, SKIN_DARK)
        rect(d, 17, y, 2, 1, SKIN_DARK)
    if sag:
        rect(d, 11, top, 2, 1, SKIN_DARK)
        rect(d, 19, top, 2, 1, SKIN_DARK)
    # The rags hanging off it, torn away over the chest.
    rect(d, 11, top + 3, 2, 9, RAG)
    rect(d, 11, top + 3, 1, 9, RAG_DARK)
    rect(d, 19, top + 3, 2, 8, RAG)
    rect(d, 20, top + 3, 1, 8, RAG_DARK)
    rect(d, 12, top + 11, 1, 2, RAG_DARK)
    rect(d, 19, top + 10, 1, 3, RAG_DARK)
    # The little cross it was given, on its chest.
    rect(d, 16, top + 5, 1, 4, GOLD)
    rect(d, 15, top + 6, 3, 1, GOLD)


def head(d: ImageDraw.ImageDraw, tilt: int, drop: int, screaming: bool) -> None:
    """Above the beam. [tilt] leans it to one side, [screaming] opens the
    jaw wide for the frames the groan belongs to."""
    x = 13 + tilt
    y = 3 + drop
    rect(d, x, y, 6, 7, SKIN)
    rect(d, x, y, 6, 1, SKIN_LIGHT)
    rect(d, x, y + 6, 6, 1, SKIN_DARK)
    # The hollows of the face.
    rect(d, x + 1, y + 2, 1, 1, EYE)
    rect(d, x + 4, y + 2, 1, 1, EYE)
    rect(d, x + 1, y + 1, 1, 1, SKIN_DARK)
    rect(d, x + 4, y + 1, 1, 1, SKIN_DARK)
    if screaming:
        rect(d, x + 2, y + 4, 2, 3, MOUTH)
        rect(d, x + 2, y + 6, 2, 1, BLOOD_DARK)
    else:
        rect(d, x + 2, y + 5, 2, 1, MOUTH)
    # What is left of the hair, and the throat under the jaw.
    rect(d, x, y, 1, 2, SKIN_DARK)
    rect(d, x + 5, y, 1, 2, SKIN_DARK)
    rect(d, 15, y + 7, 2, 4 + drop, SKIN_DARK)


def bleeding(d: ImageDraw.ImageDraw, drop: int, spill: int) -> None:
    """What pours from the cut: the wound itself, then the post washed red
    down to the foot of the frame. [spill] lengthens the runs."""
    cut = 28 + drop
    # The wound: the width of the trunk, and no wider.
    rect(d, 12, cut, 8, 2, BLOOD)
    rect(d, 12, cut, 8, 1, BLOOD_DARK)
    # Down the post, thinning as it goes.
    rect(d, 13, cut + 2, 6, 2, BLOOD)
    rect(d, 14, cut + 4, 4, 2, BLOOD_DARK)
    rect(d, 15, cut + 2, 2, 7 + spill, BLOOD)
    rect(d, 16, cut + 9 + spill, 1, 2, BLOOD_DARK)
    # The runs either side of the post, and a drop below them.
    rect(d, 13, cut + 4, 1, 3 + spill, BLOOD_DARK)
    rect(d, 18, cut + 4, 1, 2, BLOOD_DARK)
    rect(d, 18, cut + 8, 1, 2 - spill, BLOOD_DARK)


def frame(index: int) -> Image.Image:
    image = Image.new("RGBA", FRAME, (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    cross(d)
    if index == 0:  # hang_0: still.
        arms(d, lift=0)
        torso(d, drop=0, sag=0)
        head(d, tilt=0, drop=0, screaming=False)
        bleeding(d, drop=0, spill=0)
    elif index == 1:  # hang_1: a slow breath, everything one pixel lower.
        arms(d, lift=0)
        torso(d, drop=1, sag=1)
        head(d, tilt=0, drop=1, screaming=False)
        bleeding(d, drop=1, spill=1)
    elif index == 2:  # twitch_0: pulling against the nails, jaw wide.
        arms(d, lift=1)
        torso(d, drop=0, sag=0)
        head(d, tilt=-1, drop=-1, screaming=True)
        bleeding(d, drop=0, spill=1)
    else:  # twitch_1: fallen the other way, still screaming.
        arms(d, lift=0)
        torso(d, drop=1, sag=1)
        head(d, tilt=1, drop=0, screaming=True)
        bleeding(d, drop=1, spill=0)
    return image


def main() -> None:
    sheet = Image.new("RGBA", (FRAME[0] * 4, FRAME[1]), (0, 0, 0, 0))
    for index in range(4):
        sheet.paste(frame(index), (index * FRAME[0], 0))
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    sheet.save(OUTPUT, optimize=True)
    print(f"{OUTPUT}: {sheet.size[0]}x{sheet.size[1]}")


if __name__ == "__main__":
    main()
