#!/usr/bin/env python3
"""Generate Chiara's NPC idle and walk atlas.

The output follows Stepbound's shared character contract: a transparent
96x96 sheet made of 16x24 cells, with south/west/east/north rows and
idle_0, idle_1, walk_0..walk_3 columns.

Run from the repository root:  python tools/generate_chiara.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

CELL_W = 16
CELL_H = 24
SHEET_SIDE = 96
DIRECTIONS = ("south", "west", "east", "north")
TRANSPARENT = (0, 0, 0, 0)

OUTLINE = (20, 15, 20, 255)
HAIR = (52, 28, 40, 255)
HAIR_SHADE = (34, 20, 30, 255)
HAIR_HIGHLIGHT = (77, 43, 58, 255)
SKIN = (226, 137, 96, 255)
SKIN_SHADE = (184, 96, 72, 255)
SKIN_HIGHLIGHT = (244, 170, 122, 255)
POLO = (38, 53, 94, 255)
POLO_SHADE = (27, 36, 68, 255)
POLO_HIGHLIGHT = (56, 73, 119, 255)
TROUSERS = (63, 58, 63, 255)
TROUSERS_SHADE = (43, 40, 46, 255)
TROUSERS_HIGHLIGHT = (82, 75, 80, 255)
SHOES = (48, 40, 40, 255)
SOLES = (139, 119, 91, 255)
GUM = (216, 194, 222, 255)
GUM_HIGHLIGHT = (246, 231, 247, 255)


class Frame:
    """A sparse 16x24 RGBA frame."""

    def __init__(self) -> None:
        self.pixels: dict[tuple[int, int], tuple[int, int, int, int]] = {}

    def set(self, x: int, y: int, colour) -> None:
        if 0 <= x < CELL_W and 0 <= y < CELL_H:
            self.pixels[(x, y)] = colour

    def fill(self, x0: int, y0: int, x1: int, y1: int, colour) -> None:
        for y in range(min(y0, y1), max(y0, y1) + 1):
            for x in range(min(x0, x1), max(x0, x1) + 1):
                self.set(x, y, colour)

    def mirrored(self) -> "Frame":
        output = Frame()
        for (x, y), colour in self.pixels.items():
            output.set(CELL_W - 1 - x, y, colour)
        return output

    def outline(self) -> None:
        edges: set[tuple[int, int]] = set()
        for x, y in self.pixels:
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if (
                    0 <= nx < CELL_W
                    and 0 <= ny < CELL_H
                    and (nx, ny) not in self.pixels
                ):
                    edges.add((nx, ny))
        for x, y in edges:
            self.set(x, y, OUTLINE)


def paint_head(frame: Frame, direction: str, top: int, bubble_phase: int) -> None:
    """Dark wavy hair in a low bun, a small face and visible chewing gum."""
    if direction == "north":
        frame.fill(5, top + 1, 10, top + 6, HAIR)
        frame.fill(6, top, 9, top, HAIR)
        frame.fill(9, top + 1, 10, top + 5, HAIR_SHADE)
        frame.fill(5, top + 1, 6, top + 2, HAIR_HIGHLIGHT)
        frame.fill(11, top + 3, 12, top + 5, HAIR_SHADE)
        return

    if direction == "south":
        frame.fill(5, top + 1, 10, top + 4, HAIR)
        frame.fill(6, top, 9, top, HAIR)
        frame.fill(5, top + 2, 6, top + 5, HAIR_HIGHLIGHT)
        frame.fill(9, top + 1, 10, top + 5, HAIR_SHADE)
        frame.fill(11, top + 3, 12, top + 5, HAIR_SHADE)
        frame.fill(6, top + 3, 10, top + 7, SKIN)
        frame.fill(6, top + 7, 10, top + 7, SKIN_SHADE)
        frame.set(7, top + 4, OUTLINE)
        frame.set(9, top + 4, OUTLINE)
        frame.set(9, top + 6, SKIN_SHADE)
        bubble_x = 4 if bubble_phase == 0 else 3
        frame.fill(bubble_x, top + 5, bubble_x + 1, top + 6, GUM)
        frame.set(bubble_x, top + 5, GUM_HIGHLIGHT)
        return

    # West is painted directly; east mirrors the entire frame.
    frame.fill(5, top + 1, 10, top + 5, HAIR)
    frame.fill(6, top, 9, top, HAIR)
    frame.fill(9, top + 2, 11, top + 6, HAIR_SHADE)
    frame.fill(4, top + 3, 7, top + 7, SKIN)
    frame.fill(4, top + 7, 7, top + 7, SKIN_SHADE)
    frame.set(4, top + 4, OUTLINE)
    bubble_x = 2 if bubble_phase == 0 else 3
    frame.fill(bubble_x, top + 5, bubble_x + 1, top + 6, GUM)
    frame.set(bubble_x, top + 5, GUM_HIGHLIGHT)


def paint_body(frame: Frame, direction: str, y0: int) -> None:
    """A soft, broad silhouette in Chiara's navy polo."""
    frame.fill(4, y0, 11, y0 + 2, POLO)
    frame.fill(3, y0 + 2, 12, y0 + 5, POLO)
    frame.fill(2, y0 + 5, 13, y0 + 8, POLO)
    frame.fill(3, y0 + 8, 12, y0 + 9, POLO_SHADE)

    if direction == "west":
        frame.fill(2, y0 + 4, 5, y0 + 7, POLO_HIGHLIGHT)
        frame.fill(11, y0 + 2, 13, y0 + 8, POLO_SHADE)
    elif direction == "north":
        frame.fill(3, y0 + 2, 5, y0 + 7, POLO_HIGHLIGHT)
        frame.fill(10, y0 + 2, 12, y0 + 8, POLO_SHADE)
    else:
        frame.fill(4, y0 + 1, 5, y0 + 4, POLO_HIGHLIGHT)
        frame.fill(10, y0 + 3, 12, y0 + 8, POLO_SHADE)

    frame.fill(2, y0 + 2, 3, y0 + 7, SKIN)
    frame.fill(12, y0 + 2, 13, y0 + 7, SKIN)
    frame.set(2, y0 + 7, SKIN_SHADE)
    frame.set(13, y0 + 7, SKIN_SHADE)

    if direction == "south":
        frame.set(7, y0, POLO_HIGHLIGHT)
        frame.set(8, y0, POLO_SHADE)


def paint_legs(frame: Frame, y0: int, step: int, direction: str) -> None:
    """Dark, sturdy trousers and practical shoes on a stable foot anchor."""
    if direction == "west":
        left_shift = -1 if step < 0 else 0
        right_shift = 1 if step > 0 else 0
    else:
        left_shift = -1 if step < 0 else 0
        right_shift = 1 if step > 0 else 0

    left = 4 + left_shift
    right = 8 + right_shift
    knee = min(y0 + 3, 21)
    frame.fill(left, y0, left + 3, knee, TROUSERS)
    frame.fill(right, y0, right + 3, knee, TROUSERS)
    frame.fill(left, knee, left + 3, 21, TROUSERS_SHADE)
    frame.fill(right, knee, right + 3, 21, TROUSERS_SHADE)
    frame.set(left, y0 + 1, TROUSERS_HIGHLIGHT)
    frame.set(right, y0 + 1, TROUSERS_HIGHLIGHT)
    frame.fill(left - (1 if step < 0 else 0), 22, left + 3, 23, SHOES)
    frame.fill(right, 22, right + 3 + (1 if step > 0 else 0), 23, SHOES)
    frame.set(left, 23, SOLES)
    frame.set(right + 3, 23, SOLES)


def chiara_frame(direction: str, column: int) -> Frame:
    """Paint one idle/walk frame; the walk carries a restrained heavy bob."""
    if column < 2:
        sink = 0
        step = 0
        bubble_phase = column
    else:
        phase = column - 2
        sink = 1 if phase in (1, 3) else 0
        step = (-1, 0, 1, 0)[phase]
        bubble_phase = phase % 2

    frame = Frame()
    paint_body(frame, direction, 9 + sink)
    paint_head(frame, direction, 1 + sink, bubble_phase)
    paint_legs(frame, 18 + sink, step, direction)
    frame.outline()
    return frame


def build_sheet() -> Image.Image:
    sheet = Image.new("RGBA", (SHEET_SIDE, SHEET_SIDE), TRANSPARENT)
    west: list[Frame] | None = None
    for row, direction in enumerate(DIRECTIONS):
        if direction == "east":
            assert west is not None
            frames = [frame.mirrored() for frame in west]
        else:
            frames = [chiara_frame(direction, column) for column in range(6)]
            if direction == "west":
                west = frames
        for column, frame in enumerate(frames):
            image = Image.new("RGBA", (CELL_W, CELL_H), TRANSPARENT)
            for (x, y), colour in frame.pixels.items():
                image.putpixel((x, y), colour)
            sheet.alpha_composite(image, (column * CELL_W, row * CELL_H))
    return sheet


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    output = root / "assets/characters/npcs/sprites/chiara.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    build_sheet().save(output)
    print("wrote assets/characters/npcs/sprites/chiara.png")


if __name__ == "__main__":
    main()
