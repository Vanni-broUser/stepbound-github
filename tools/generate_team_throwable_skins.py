#!/usr/bin/env python3
"""Generate Roma and Lazio throwable atlases from their gun atlases.

The throwable poses differ from the one-handed poses by only a handful of
pixels in every 16x24 cell.  Pixels shared by both base sheets inherit the
team artwork at the same position.  New arm/torso pixels take the colour of
the nearest visually matching pixel in the same team frame, keeping the
existing Roma/Lazio palette and accents instead of inventing another style.

Run from the repository root:

    python tools/generate_team_throwable_skins.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image


CELL_WIDTH = 16
CELL_HEIGHT = 24
ROWS = 4
COLUMNS = 6
ROOT = Path("assets/characters/mario/sprites")
TRANSPARENT = (0, 0, 0, 0)


def colour_distance(left: tuple[int, ...], right: tuple[int, ...]) -> int:
    """RGB distance with a strong penalty for a different alpha edge."""
    return sum((left[index] - right[index]) ** 2 for index in range(3)) + (
        (left[3] - right[3]) ** 2 * 4
    )


def transfer_frame(
    base_gun: Image.Image,
    base_throwable: Image.Image,
    team_gun: Image.Image,
) -> Image.Image:
    output = Image.new("RGBA", (CELL_WIDTH, CELL_HEIGHT), TRANSPARENT)
    source_pixels = base_gun.load()
    throwable_pixels = base_throwable.load()
    team_pixels = team_gun.load()
    output_pixels = output.load()

    visible_source = [
        (x, y)
        for y in range(CELL_HEIGHT)
        for x in range(CELL_WIDTH)
        if source_pixels[x, y][3] > 0
    ]
    for y in range(CELL_HEIGHT):
        for x in range(CELL_WIDTH):
            throwable = throwable_pixels[x, y]
            if throwable[3] == 0:
                continue
            if throwable == source_pixels[x, y]:
                output_pixels[x, y] = team_pixels[x, y]
                continue

            # The changed pixels are the moving arm and the shirt immediately
            # around it.  Prefer the same source colour nearby so an accent
            # stripe follows the pose; fall back to the closest colour when
            # antialiasing produced a one-off shade.
            best = min(
                visible_source,
                key=lambda point: (
                    colour_distance(throwable, source_pixels[point]),
                    abs(point[0] - x) + abs(point[1] - y),
                ),
            )
            output_pixels[x, y] = team_pixels[best]
    return output


def generate(outfit: str) -> None:
    base_gun = Image.open(ROOT / "base_gun.png").convert("RGBA")
    base_throwable = Image.open(ROOT / "base_throwable.png").convert("RGBA")
    team_gun = Image.open(ROOT / f"{outfit}_gun.png").convert("RGBA")
    output = Image.new("RGBA", base_throwable.size, TRANSPARENT)

    for row in range(ROWS):
        for column in range(COLUMNS):
            box = (
                column * CELL_WIDTH,
                row * CELL_HEIGHT,
                (column + 1) * CELL_WIDTH,
                (row + 1) * CELL_HEIGHT,
            )
            output.alpha_composite(
                transfer_frame(
                    base_gun.crop(box),
                    base_throwable.crop(box),
                    team_gun.crop(box),
                ),
                (column * CELL_WIDTH, row * CELL_HEIGHT),
            )

    path = ROOT / f"{outfit}_throwable.png"
    output.save(path)
    print(f"wrote {path}")


def main() -> None:
    for outfit in ("roma", "lazio"):
        generate(outfit)


if __name__ == "__main__":
    main()
