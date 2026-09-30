#!/usr/bin/env python3
"""Generate the call-center zombie's base and action sprite sheets.

The character shares the sprinter's narrow, fast silhouette, but the trapped
corded handset is part of every pose.  Sheets use the project's 4x6 grid of
16x24 cells (south, west, east, north).
"""

from __future__ import annotations

import os

from PIL import Image

from generate_action_sprites import (
    CharacterSpec,
    Frame,
    build_sheet,
    directional_rows,
    zombie_bite,
    zombie_death,
    zombie_hit,
)

CORD_DARK = (47, 38, 34, 255)
CORD = (210, 190, 142, 255)
PHONE = (224, 207, 158, 255)
PHONE_HI = (246, 229, 181, 255)

SPEC = CharacterSpec(
    name="call_center",
    hair=0x453432,
    hair_hi=0x5A4642,
    skin=0xC0D860,
    skin_shade=0x8FA84C,
    top=0x303548,
    top_shade=0x202432,
    top_hi=0x474E64,
    legs=0x354A62,
    legs_shade=0x263548,
    boots=0x59483E,
)


def draw_line(
    frame: Frame,
    start: tuple[int, int],
    end: tuple[int, int],
    color: tuple[int, int, int, int],
) -> None:
    """Draw a short nearest-pixel line without antialiasing."""
    x0, y0 = start
    x1, y1 = end
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    for step in range(steps + 1):
        x = round(x0 + (x1 - x0) * step / steps)
        y = round(y0 + (y1 - y0) * step / steps)
        frame.set(x, y, color)


def paint_vertical_handset(frame: Frame, x: int, y: int) -> None:
    """A tiny cream landline receiver with heavier earpieces."""
    frame.fill(x - 1, y, x + 1, y + 1, CORD_DARK)
    frame.fill(x, y + 2, x, y + 4, CORD_DARK)
    frame.fill(x - 1, y + 5, x + 1, y + 6, CORD_DARK)
    frame.fill(x, y, x + 1, y, PHONE)
    frame.set(x + 1, y, PHONE_HI)
    frame.fill(x, y + 1, x, y + 4, PHONE)
    frame.fill(x, y + 5, x + 1, y + 5, PHONE)
    frame.set(x + 1, y + 5, PHONE_HI)


def paint_horizontal_handset(frame: Frame, x: int, y: int) -> None:
    frame.fill(x, y, x + 3, y + 2, CORD_DARK)
    frame.fill(x + 4, y + 1, x + 4, y + 2, CORD_DARK)
    frame.fill(x, y + 3, x + 3, y + 3, CORD_DARK)
    frame.fill(x, y + 1, x + 1, y + 2, PHONE)
    frame.fill(x + 2, y + 2, x + 3, y + 2, PHONE)
    frame.set(x, y + 1, PHONE_HI)


def paint_phone(
    frame: Frame,
    direction: str,
    *,
    neck_y: int = 9,
    prone: bool = False,
) -> None:
    """Add the neck loop, taut cord, and handset without leaving the cell."""
    if prone:
        draw_line(frame, (4, 22), (11, 21), CORD_DARK)
        draw_line(frame, (4, 21), (11, 20), CORD)
        paint_horizontal_handset(frame, 10, 20)
        return

    if direction == "west":
        # The body runs left while the receiver pulls back to the right.
        frame.set(7, neck_y - 1, CORD_DARK)
        frame.set(8, neck_y, CORD)
        frame.set(9, neck_y, CORD)
        draw_line(frame, (9, neck_y + 1), (13, 9), CORD_DARK)
        draw_line(frame, (9, neck_y), (13, 8), CORD)
        paint_vertical_handset(frame, 13, 1)
        return

    if direction == "north":
        frame.fill(6, neck_y - 1, 10, neck_y - 1, CORD_DARK)
        frame.fill(7, neck_y, 9, neck_y, CORD)
        draw_line(frame, (10, neck_y), (13, 8), CORD_DARK)
        draw_line(frame, (10, neck_y - 1), (13, 7), CORD)
        paint_vertical_handset(frame, 13, 1)
        return

    # South-facing: the diagonal pull keeps the loop readable over the chest.
    frame.set(6, neck_y - 1, CORD_DARK)
    frame.set(6, neck_y, CORD)
    frame.fill(7, neck_y + 1, 9, neck_y + 1, CORD)
    frame.set(10, neck_y, CORD)
    draw_line(frame, (10, neck_y), (13, 8), CORD_DARK)
    draw_line(frame, (10, neck_y - 1), (13, 7), CORD)
    paint_vertical_handset(frame, 13, 1)


def recolor_sprinter_pixel(
    pixel: tuple[int, int, int, int],
    local_y: int,
) -> tuple[int, int, int, int]:
    """Turn the sprinter's red shirt into the call-center dark hoodie."""
    red, green, blue, alpha = pixel
    is_red_clothing = (
        7 <= local_y <= 18 and red > 35 and red > green * 1.2 and red > blue * 1.12
    )
    if not is_red_clothing:
        return pixel
    value = max(red, green, blue)
    return (int(value * 0.55), int(value * 0.62), int(value * 0.84), alpha)


def sprinter_frame(source: Image.Image, row: int, column: int) -> Frame:
    frame = Frame()
    for y in range(24):
        for x in range(16):
            pixel = source.getpixel((column * 16 + x, row * 24 + y))
            if pixel[3]:
                frame.set(x, y, recolor_sprinter_pixel(pixel, y))
    return frame


def base_sheet() -> Image.Image:
    source_path = os.path.abspath(
        os.path.join(
            os.path.dirname(__file__),
            "..",
            "assets",
            "characters",
            "zombies",
            "sprites",
            "sprinter.png",
        )
    )
    source = Image.open(source_path).convert("RGBA")
    south = [sprinter_frame(source, 0, column) for column in range(6)]
    west = [sprinter_frame(source, 1, column) for column in range(6)]
    north = [sprinter_frame(source, 3, column) for column in range(6)]
    for frame in south:
        paint_phone(frame, "south", neck_y=8)
    for frame in west:
        paint_phone(frame, "west", neck_y=8)
    for frame in north:
        paint_phone(frame, "north", neck_y=8)
    east = [frame.mirrored() for frame in west]
    return build_sheet((south, west, east, north))


def action_frame(action: str, direction: str, index: int) -> Frame:
    if action == "hit":
        frame = zombie_hit(SPEC, direction, min(index, 2))
        paint_phone(frame, direction, neck_y=9)
        return frame
    if action == "bite":
        frame = zombie_bite(SPEC, direction, min(index, 3))
        paint_phone(frame, direction, neck_y=11 if index in (1, 2) else 10)
        return frame
    frame = zombie_death(SPEC, direction, index)
    if index >= 4:
        paint_phone(frame, direction, prone=True)
    else:
        paint_phone(frame, direction, neck_y=9 + index * 2)
    return frame


def action_sheet(action: str) -> Image.Image:
    frame_count = {"hit": 3, "bite": 4, "death": 6}[action]

    def painter(direction: str) -> list[Frame]:
        frames = [
            action_frame(action, direction, index) for index in range(frame_count)
        ]
        return frames + [frames[-1]] * (6 - frame_count)

    return build_sheet(directional_rows(painter))


def main() -> None:
    out_dir = os.path.abspath(
        os.path.join(
            os.path.dirname(__file__),
            "..",
            "assets",
            "characters",
            "zombies",
            "sprites",
        )
    )
    os.makedirs(out_dir, exist_ok=True)
    outputs = {
        "call_center.png": base_sheet(),
        "call_center_hit.png": action_sheet("hit"),
        "call_center_bite.png": action_sheet("bite"),
        "call_center_death.png": action_sheet("death"),
    }
    for filename, sheet in outputs.items():
        sheet.save(os.path.join(out_dir, filename))
        print(f"wrote assets/characters/zombies/sprites/{filename}")


if __name__ == "__main__":
    main()
