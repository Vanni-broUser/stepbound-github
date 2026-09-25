#!/usr/bin/env python3
"""Generate the crucified-zombie sprite and its documentation previews.

Runtime contract (do not change):

* ``assets/sprites/crucified_zombie.png``
* RGBA, transparent, 128x40
* four 32x40 frames: hang_0, hang_1, twitch_0, twitch_1

The two GIFs written to ``docs/previews`` are enlarged nearest-neighbour
previews only; the game consumes the PNG sheet.  Run from the repository root:

    python tools/generate_crucified_zombie.py
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw


FRAME_W = 32
FRAME_H = 40
FRAME_NAMES = ("hang_0", "hang_1", "twitch_0", "twitch_1")
OUTPUT = Path("assets/sprites/crucified_zombie.png")
PREVIEW_DIR = Path("docs/previews")
TRANSPARENT = (0, 0, 0, 0)

# Thirteen opaque colours, plus transparency.  Brown and burgundy replace a
# hard black outline, preserving detail under the church's warm torch light.
WOOD_DARK = (45, 30, 24, 255)
WOOD = (78, 49, 32, 255)
WOOD_LIGHT = (112, 72, 42, 255)
SKIN_DARK = (47, 65, 37, 255)
SKIN = (88, 105, 51, 255)
SKIN_LIGHT = (137, 145, 76, 255)
RAG_DARK = (105, 98, 82, 255)
RAG = (188, 176, 142, 255)
BLOOD_DARK = (83, 21, 27, 255)
BLOOD = (151, 31, 38, 255)
EYE = (239, 51, 43, 255)
GOLD_DARK = (143, 93, 27, 255)
GOLD = (226, 175, 57, 255)


@dataclass(frozen=True)
class Pose:
    body_y: int = 0
    shoulder_y: int = 0
    head_y: int = 0
    head_tilt: int = 0
    mouth_open: bool = False


POSES = (
    Pose(),
    Pose(body_y=1, shoulder_y=1, head_y=1),
    Pose(shoulder_y=-1, head_y=-1, head_tilt=-1, mouth_open=True),
    Pose(body_y=1, shoulder_y=1, head_y=1, head_tilt=1, mouth_open=True),
)


def draw_cross() -> Image.Image:
    """Return the immutable cross/background layer shared by every frame."""
    image = Image.new("RGBA", (FRAME_W, FRAME_H), TRANSPARENT)
    draw = ImageDraw.Draw(image)

    # Vertical post: irregular top cap, dark rim and a narrow lit wood grain.
    draw.polygon(
        [(14, 0), (18, 0), (19, 2), (19, 39), (13, 39), (13, 2)], fill=WOOD_DARK
    )
    draw.rectangle((14, 1, 17, 39), fill=WOOD)
    draw.line((15, 2, 15, 38), fill=WOOD_LIGHT)
    draw.point((17, 6), fill=WOOD_DARK)
    draw.line((17, 18, 17, 27), fill=WOOD_DARK)
    draw.point((14, 31), fill=WOOD_LIGHT)

    # Beam at roughly one quarter of the frame height, almost edge to edge.
    draw.polygon(
        [(1, 8), (30, 8), (30, 12), (28, 13), (3, 13), (1, 12)], fill=WOOD_DARK
    )
    draw.rectangle((2, 9, 29, 11), fill=WOOD)
    draw.line((3, 9, 28, 9), fill=WOOD_LIGHT)
    draw.point((7, 10), fill=WOOD_DARK)
    draw.line((22, 11, 27, 11), fill=WOOD_DARK)

    # Fixed iron nails and the trails already soaked into the beam.
    for x in (4, 27):
        draw.rectangle((x - 1, 9, x + 1, 11), fill=RAG_DARK)
        draw.point((x, 10), fill=WOOD_LIGHT)
        draw.line((x, 12, x, 16), fill=BLOOD_DARK)
        draw.line(
            (x + (1 if x == 4 else -1), 13, x + (1 if x == 4 else -1), 15), fill=BLOOD
        )
        draw.point((x, 18), fill=BLOOD)

    return image


def draw_arm(draw: ImageDraw.ImageDraw, *, left: bool, shoulder_y: int) -> None:
    """Draw one arm while keeping its nailed hand fixed to the beam."""
    if left:
        dark = [
            (3, 9),
            (5, 9),
            (11, 11 + shoulder_y),
            (11, 15 + shoulder_y),
            (8, 13 + shoulder_y),
            (4, 12),
        ]
        mid = [(5, 10), (10, 12 + shoulder_y), (9, 13 + shoulder_y), (5, 11)]
        light = [(6, 10), (9, 11 + shoulder_y), (8, 12 + shoulder_y)]
        hand = (3, 9, 5, 12)
    else:
        dark = [
            (28, 9),
            (26, 9),
            (21, 11 + shoulder_y),
            (21, 15 + shoulder_y),
            (24, 13 + shoulder_y),
            (28, 12),
        ]
        mid = [(26, 10), (22, 12 + shoulder_y), (23, 13 + shoulder_y), (27, 11)]
        light = [(25, 10), (23, 11 + shoulder_y), (24, 12 + shoulder_y)]
        hand = (26, 9, 28, 12)
    draw.polygon(dark, fill=SKIN_DARK)
    draw.polygon(mid, fill=SKIN)
    draw.line(light, fill=SKIN_LIGHT, width=1)
    draw.rectangle(hand, fill=SKIN)


def draw_rags(draw: ImageDraw.ImageDraw, pose: Pose) -> None:
    y = pose.body_y
    sy = pose.shoulder_y
    left = [
        (9, 12 + sy),
        (12, 14 + y),
        (11, 22 + y),
        (9, 25 + y),
        (9, 21 + y),
        (7, 23 + y),
        (8, 16 + y),
    ]
    right = [
        (23, 12 + sy),
        (20, 14 + y),
        (21, 22 + y),
        (23, 25 + y),
        (23, 21 + y),
        (25, 23 + y),
        (24, 16 + y),
    ]
    for points in (left, right):
        draw.polygon(points, fill=RAG_DARK)
    draw.polygon(
        [(10, 13 + sy), (12, 15 + y), (10, 22 + y), (9, 20 + y), (9, 15 + y)], fill=RAG
    )
    draw.polygon(
        [(22, 13 + sy), (20, 15 + y), (22, 22 + y), (23, 20 + y), (23, 15 + y)],
        fill=RAG,
    )
    draw.point((8, 24 + y), fill=RAG)
    draw.point((24, 24 + y), fill=RAG)


def draw_torso(draw: ImageDraw.ImageDraw, pose: Pose) -> None:
    y = pose.body_y
    sy = pose.shoulder_y
    draw.polygon(
        [
            (11, 12 + sy),
            (15, 12 + y),
            (17, 12 + y),
            (21, 12 + sy),
            (22, 18 + y),
            (20, 27 + y),
            (12, 27 + y),
            (10, 18 + y),
        ],
        fill=SKIN_DARK,
    )
    draw.polygon(
        [
            (13, 13 + y),
            (19, 13 + y),
            (20, 18 + y),
            (19, 25 + y),
            (13, 25 + y),
            (12, 18 + y),
        ],
        fill=SKIN,
    )
    draw.line((14, 14 + y, 13, 20 + y), fill=SKIN_LIGHT)
    draw.line((18, 15 + y, 19, 20 + y), fill=SKIN_DARK)
    draw.line((14, 22 + y, 18, 22 + y), fill=SKIN_DARK)
    draw.point((13, 18 + y), fill=SKIN_LIGHT)
    draw.point((18, 24 + y), fill=SKIN_LIGHT)

    # Tiny pendant: dark chain and a two-tone cross that remains readable.
    draw.line((15, 14 + y, 16, 18 + y, 17, 14 + y), fill=GOLD_DARK)
    draw.line((16, 18 + y, 16, 22 + y), fill=GOLD)
    draw.line((14, 20 + y, 18, 20 + y), fill=GOLD)
    draw.point((16, 22 + y), fill=GOLD_DARK)


def draw_head(draw: ImageDraw.ImageDraw, pose: Pose) -> None:
    y = 2 + pose.head_y
    top_dx = pose.head_tilt
    lower_dx = 0

    draw.polygon(
        [
            (13 + top_dx, y),
            (18 + top_dx, y),
            (20 + top_dx, y + 2),
            (21 + lower_dx, y + 6),
            (19 + lower_dx, y + 10),
            (14 + lower_dx, y + 10),
            (11 + lower_dx, y + 6),
            (12 + top_dx, y + 2),
        ],
        fill=SKIN_DARK,
    )
    draw.polygon(
        [
            (14 + top_dx, y + 1),
            (18 + top_dx, y + 1),
            (19, y + 3),
            (19, y + 7),
            (17, y + 9),
            (13, y + 7),
            (13, y + 3),
        ],
        fill=SKIN,
    )
    draw.line((14 + top_dx, y + 1, 17 + top_dx, y + 1), fill=SKIN_LIGHT)
    draw.point((13 + top_dx, y + 4), fill=SKIN_LIGHT)
    draw.point((18, y + 5), fill=SKIN_DARK)

    eye_shift = pose.head_tilt
    draw.point((14 + eye_shift, y + 4), fill=EYE)
    draw.point((18 + eye_shift, y + 4), fill=EYE)

    if pose.mouth_open:
        draw.rectangle((14 + eye_shift, y + 6, 18 + eye_shift, y + 9), fill=BLOOD_DARK)
        draw.point((15 + eye_shift, y + 6), fill=RAG)
        draw.point((17 + eye_shift, y + 6), fill=RAG)
        draw.line((15 + eye_shift, y + 9, 17 + eye_shift, y + 9), fill=BLOOD)
    else:
        draw.rectangle((15 + eye_shift, y + 7, 17 + eye_shift, y + 9), fill=BLOOD_DARK)
        draw.point((16 + eye_shift, y + 9), fill=BLOOD)


def draw_waist_and_blood(draw: ImageDraw.ImageDraw, pose: Pose) -> None:
    y = pose.body_y
    # A blunt, ragged horizontal cut makes the missing lower half unambiguous.
    draw.polygon(
        [
            (11, 26 + y),
            (13, 25 + y),
            (15, 27 + y),
            (17, 25 + y),
            (19, 27 + y),
            (21, 26 + y),
            (20, 29 + y),
            (12, 29 + y),
        ],
        fill=BLOOD_DARK,
    )
    draw.line((13, 27 + y, 19, 27 + y), fill=BLOOD)
    draw.point((11, 27 + y), fill=BLOOD)
    draw.point((20, 28 + y), fill=BLOOD)

    # Taper the wound into separate runs; the wood remains visible between
    # them, so nothing below the waist can read as a leg.
    draw.line((16, 28 + y, 16, 39), fill=BLOOD_DARK)
    draw.line((15, 29 + y, 15, 34 + y), fill=BLOOD)
    draw.line((17, 29 + y, 17, 32 + y), fill=BLOOD)
    draw.line((16, 34 + y, 16, 37), fill=BLOOD)
    draw.point((14, 33 + y), fill=BLOOD)
    draw.point((14, 35 + y), fill=BLOOD_DARK)
    draw.point((18, 31 + y), fill=BLOOD)
    draw.point((18, 34 + y), fill=BLOOD_DARK)
    draw.point((16, 39), fill=BLOOD)


def frame(cross: Image.Image, pose: Pose) -> Image.Image:
    image = cross.copy()
    draw = ImageDraw.Draw(image)
    draw_arm(draw, left=True, shoulder_y=pose.shoulder_y)
    draw_arm(draw, left=False, shoulder_y=pose.shoulder_y)
    draw_rags(draw, pose)
    draw_torso(draw, pose)
    draw_head(draw, pose)
    draw_waist_and_blood(draw, pose)
    return image


def build_sheet(frames: list[Image.Image]) -> Image.Image:
    sheet = Image.new("RGBA", (FRAME_W * len(frames), FRAME_H), TRANSPARENT)
    for index, image in enumerate(frames):
        sheet.alpha_composite(image, (index * FRAME_W, 0))
    return sheet


def save_preview(
    frames: list[Image.Image], indices: tuple[int, ...], name: str, duration: int
) -> None:
    """Write a large transparent GIF without filtering or tween frames."""
    scale = 8
    enlarged = [
        frames[index].resize(
            (FRAME_W * scale, FRAME_H * scale), Image.Resampling.NEAREST
        )
        for index in indices
    ]
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    enlarged[0].save(
        PREVIEW_DIR / name,
        save_all=True,
        append_images=enlarged[1:],
        duration=duration,
        loop=0,
        disposal=2,
        transparency=0,
        optimize=False,
    )


def validate(sheet: Image.Image) -> None:
    if sheet.mode != "RGBA" or sheet.size != (128, 40):
        raise ValueError(f"invalid runtime contract: {sheet.mode=} {sheet.size=}")
    alphas = set(sheet.getchannel("A").get_flattened_data())
    if not alphas.issubset({0, 255}) or 0 not in alphas or 255 not in alphas:
        raise ValueError(
            f"sprite must use binary transparency, got alpha values {sorted(alphas)}"
        )
    opaque_colours = {pixel for pixel in sheet.get_flattened_data() if pixel[3]}
    if not 12 <= len(opaque_colours) <= 14:
        raise ValueError(f"expected a 12-14 colour palette, got {len(opaque_colours)}")


def main() -> None:
    cross = draw_cross()
    frames = [frame(cross, pose) for pose in POSES]
    sheet = build_sheet(frames)
    validate(sheet)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUTPUT, format="PNG", optimize=True)
    save_preview(frames, (0, 1), "crucified_zombie_hang.gif", duration=520)
    save_preview(frames, (2, 3), "crucified_zombie_twitch.gif", duration=190)

    print(f"wrote {OUTPUT} ({sheet.width}x{sheet.height}, {sheet.mode})")
    for name in ("crucified_zombie_hang.gif", "crucified_zombie_twitch.gif"):
        print(f"wrote {PREVIEW_DIR / name}")


if __name__ == "__main__":
    main()
