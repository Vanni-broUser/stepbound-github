#!/usr/bin/env python3
"""Build the special-zombie atlases.

The mutilated, burning and drunk archetypes share the wanderer's anatomy and
animation timing. The cultist uses the brute's larger build. Their gameplay
identity is carried by a strong, readable silhouette:

* mutilated: only the upper body remains, lying on the ground;
* burning: scorched clothes and a compact, animated crown of flame;
* drunk: burgundy bar clothes and an alternating off-balance posture.
* cultist: the brute's build under a torn cult robe, with a lowered hood and
  sulfur-yellow veins across its exposed arms.

All outputs keep Stepbound's 96x96, four-row-by-six-column atlas contract.
Run from the repository root:  python tools/generate_special_zombies.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

CELL_W = 16
CELL_H = 24
ROWS = ("south", "west", "east", "north")
SPRITES = Path("assets/sprites")
TRANSPARENT = (0, 0, 0, 0)

OUTLINE = (16, 12, 12, 255)
BLOOD = (126, 40, 34, 255)
BURGUNDY = (116, 42, 50, 255)
BURGUNDY_LIGHT = (150, 58, 64, 255)
BURGUNDY_DARK = (72, 27, 34, 255)
CULTIST = (91, 78, 70, 255)
CULTIST_LIGHT = (126, 108, 93, 255)
CULTIST_DARK = (48, 42, 40, 255)
VEIN = (222, 211, 72, 255)
VEIN_SHADOW = (151, 145, 43, 255)
CHARCOAL = (43, 42, 40, 255)
ASH = (72, 68, 63, 255)
EMBER = (174, 54, 25, 255)
FLAME = (244, 121, 24, 255)
FLAME_CORE = (255, 220, 79, 255)


def frames(name: str) -> list[list[Image.Image]]:
    sheet = Image.open(SPRITES / name).convert("RGBA")
    return [
        [
            sheet.crop(
                (
                    column * CELL_W,
                    row * CELL_H,
                    (column + 1) * CELL_W,
                    (row + 1) * CELL_H,
                )
            )
            for column in range(6)
        ]
        for row in range(4)
    ]


def sheet(rows: list[list[Image.Image]]) -> Image.Image:
    output = Image.new("RGBA", (96, 96), TRANSPARENT)
    for row, row_frames in enumerate(rows):
        for column, frame in enumerate(row_frames):
            output.alpha_composite(frame, (column * CELL_W, row * CELL_H))
    return output


def visible(pixel: tuple[int, int, int, int]) -> bool:
    return pixel[3] > 64


def zombie_skin(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    return a > 64 and g > 65 and g > r * 1.06 and g > b * 1.06


def recolour_clothes(
    frame: Image.Image,
    dark: tuple[int, int, int, int],
    mid: tuple[int, int, int, int],
    light: tuple[int, int, int, int],
) -> Image.Image:
    output = frame.copy()
    for y in range(CELL_H):
        for x in range(CELL_W):
            pixel = frame.getpixel((x, y))
            if not visible(pixel) or zombie_skin(pixel):
                continue
            r, g, b, _ = pixel
            # Keep the dark hair and inked outline.  Below the face, map the
            # wanderer's neutral clothes to the new archetype's compact ramp.
            if max(r, g, b) < 30 or y < 9:
                continue
            luminance = (r * 3 + g * 5 + b * 2) / 10
            output.putpixel(
                (x, y), light if luminance > 95 else mid if luminance > 55 else dark
            )
    return output


def ensure_frame_contract(frame: Image.Image) -> Image.Image:
    """Keep every frame inside x=1..14 and pinned to the y=23 foot line."""
    alpha = frame.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("generated an empty special-zombie frame")
    shift_x = 0
    if bbox[0] < 1:
        shift_x = 1 - bbox[0]
    elif bbox[2] - 1 > 14:
        shift_x = 14 - (bbox[2] - 1)
    output = Image.new("RGBA", frame.size, TRANSPARENT)
    output.alpha_composite(frame, (shift_x, 0))
    bbox = output.getchannel("A").getbbox()
    assert bbox is not None
    if bbox[3] < CELL_H:
        # A two-pixel ground contact reads as a shadow or torn hem and keeps
        # the runtime's bottom-centre anchor stable.
        output.putpixel((7, 23), OUTLINE)
        output.putpixel((8, 23), OUTLINE)
    return output


def mutilated(frame: Image.Image, *, prone: bool = False) -> Image.Image:
    if prone:
        output = frame.copy()
        # The final collapse is already horizontal; a dark, torn end avoids
        # suggesting intact boots without adding graphic detail.
        for y in range(19, 24):
            for x in range(12, 15):
                if visible(output.getpixel((x, y))):
                    output.putpixel((x, y), BLOOD if (x + y) % 4 == 0 else OUTLINE)
        return ensure_frame_contract(output)

    # Drop the upper eighteen pixels to ground level and discard the legs.
    output = Image.new("RGBA", frame.size, TRANSPARENT)
    upper = frame.crop((0, 0, CELL_W, 18))
    output.alpha_composite(upper, (0, 6))
    for x in (6, 9):
        if visible(output.getpixel((x, 23))):
            output.putpixel((x, 23), BLOOD)
    return ensure_frame_contract(output)


def put(frame: Image.Image, x: int, y: int, colour: tuple[int, int, int, int]) -> None:
    if 1 <= x <= 14 and 0 <= y < CELL_H:
        frame.putpixel((x, y), colour)


def flame(frame: Image.Image, x: int, y: int, phase: int) -> None:
    """A three-colour, four-pixel-wide flame readable at native size."""
    sway = (-1, 0, 1, 0)[phase % 4]
    for dx, dy, colour in (
        (0, 0, EMBER),
        (1, 0, EMBER),
        (0, -1, FLAME),
        (1, -1, FLAME),
        (sway, -2, FLAME),
        (sway, -3, FLAME_CORE),
    ):
        put(frame, x + dx, y + dy, colour)


def burning(
    frame: Image.Image,
    row: int,
    column: int,
    suffix: str,
) -> Image.Image:
    output = recolour_clothes(frame, CHARCOAL, ASH, EMBER)
    phase = column + row
    if suffix == "_death" and column >= 3:
        # Once the body is prone, fire hugs it instead of floating where the
        # standing shoulders used to be.
        flame(output, 4, 22, phase)
        flame(output, 10, 23, phase + 2)
        return ensure_frame_contract(output)
    # Flames sit on both shoulders and the crown.  Their small alternating
    # sway animates even in the two-frame idle loop.
    flame(output, 4, 12, phase)
    flame(output, 11, 11, phase + 2)
    flame(output, 7, 5, phase + 1)
    return ensure_frame_contract(output)


def shift_upper(frame: Image.Image, amount: int) -> Image.Image:
    output = Image.new("RGBA", frame.size, TRANSPARENT)
    legs = frame.crop((0, 18, CELL_W, CELL_H))
    upper = frame.crop((0, 0, CELL_W, 18))
    output.alpha_composite(legs, (0, 18))
    output.alpha_composite(upper, (amount, abs(amount)))
    return output


def drunk(frame: Image.Image, row: int, column: int) -> Image.Image:
    output = recolour_clothes(frame, BURGUNDY_DARK, BURGUNDY, BURGUNDY_LIGHT)
    # A held frame must still look unsteady; walk frames alternate the lean.
    lean = (-1, 1, -1, 0, 1, 0)[column]
    if row == 2:  # east mirrors west semantically
        lean = -lean
    return ensure_frame_contract(shift_upper(output, lean))


def lowered_hood(frame: Image.Image, *, prone: bool) -> None:
    """Bunch the hood behind the neck without covering the zombie's face."""
    if prone:
        return
    for x, y, colour in (
        (4, 8, CULTIST_DARK),
        (5, 9, CULTIST),
        (4, 10, CULTIST_LIGHT),
        (11, 8, CULTIST_DARK),
        (10, 9, CULTIST),
        (11, 10, CULTIST_LIGHT),
    ):
        neighbours = (
            frame.getpixel((nx, ny))
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
            if 0 <= nx < CELL_W and 0 <= ny < CELL_H
        )
        if visible(frame.getpixel((x, y))) or any(
            visible(pixel) for pixel in neighbours
        ):
            put(frame, x, y, colour)


def tear_robe(frame: Image.Image, row: int, column: int) -> None:
    """Open two small shoulder tears next to already exposed green muscle."""
    skin = [
        frame.getpixel((x, y))
        for y in range(8, 16)
        for x in range(1, 15)
        if zombie_skin(frame.getpixel((x, y)))
    ]
    if not skin:
        return
    exposed = max(skin, key=lambda pixel: pixel[1])
    candidates = []
    for y in range(9, 15):
        for x in range(2, 14):
            pixel = frame.getpixel((x, y))
            if not visible(pixel) or zombie_skin(pixel):
                continue
            beside_skin = any(
                zombie_skin(frame.getpixel((nx, ny)))
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
                if 0 <= nx < CELL_W and 0 <= ny < CELL_H
            )
            if beside_skin:
                candidates.append((x, y))
    for x, y in candidates[(row + column) % 2 :: 3][:2]:
        frame.putpixel((x, y), exposed)


def yellow_veins(frame: Image.Image, row: int, column: int) -> None:
    """Mark each visible muscular arm with a two-pixel unnatural vein."""
    target_y = 13 + (row + column) % 4
    for side in (range(1, 7), range(9, 15)):
        skin = [
            (x, y)
            for y in range(10, 23)
            for x in side
            if zombie_skin(frame.getpixel((x, y)))
        ]
        if not skin:
            continue
        x, y = min(skin, key=lambda point: abs(point[1] - target_y))
        frame.putpixel((x, y), VEIN)
        for nx, ny in ((x, y + 1), (x + (1 if x < 8 else -1), y - 1)):
            if (
                0 <= nx < CELL_W
                and 0 <= ny < CELL_H
                and zombie_skin(frame.getpixel((nx, ny)))
            ):
                frame.putpixel((nx, ny), VEIN_SHADOW)
                break


def cultist(frame: Image.Image, row: int, column: int, suffix: str) -> Image.Image:
    output = recolour_clothes(
        frame,
        CULTIST_DARK,
        CULTIST,
        CULTIST_LIGHT,
    )
    prone = suffix == "_death" and column >= 3
    lowered_hood(output, prone=prone)
    tear_robe(output, row, column)
    yellow_veins(output, row, column)
    return ensure_frame_contract(output)


def build(kind: str, transform, *, source_stem: str = "zombie_wanderer") -> None:
    source_names = {
        "": f"{source_stem}.png",
        "_hit": f"{source_stem}_hit.png",
        "_bite": f"{source_stem}_bite.png",
        "_death": f"{source_stem}_death.png",
    }
    for suffix, source_name in source_names.items():
        source = frames(source_name)
        output_rows: list[list[Image.Image]] = []
        for row, row_frames in enumerate(source):
            output_row = []
            for column, frame in enumerate(row_frames):
                output_row.append(transform(frame, row, column, suffix))
            output_rows.append(output_row)
        filename = f"zombie_{kind}{suffix}.png"
        sheet(output_rows).save(SPRITES / filename)
        print(f"wrote assets/sprites/{filename}")


def main() -> None:
    build(
        "mutilated",
        lambda frame, _row, column, suffix: mutilated(
            frame,
            prone=suffix == "_death" and column >= 3,
        ),
    )
    build(
        "burning",
        lambda frame, row, column, suffix: burning(frame, row, column, suffix),
    )
    build("drunk", lambda frame, row, column, _suffix: drunk(frame, row, column))
    build("cultist", cultist, source_stem="zombie_brute")


if __name__ == "__main__":
    main()
