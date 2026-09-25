#!/usr/bin/env python3
"""Generate the Stepbound action sprite sheets.

Produces 96x96 transparent PNGs laid out on the shared 4x6 grid
(rows: south, west, east, north; columns: action frames) matching
assets/sprites/atlas_manifest.json.

Sheets:
  zombie_<type>_hit.png          damage flinch, 4 directions
  zombie_<type>_bite.png         lunge + bite, 4 directions
  zombie_<type>_death.png        collapse to prone, 4 directions

Run from the repository root:  python tools/generate_action_sprites.py
"""
from __future__ import annotations

import os

from PIL import Image

CELL_W = 16
CELL_H = 24
SHEET_SIDE = 96
DIRECTIONS = ("south", "west", "east", "north")
ZOMBIE_TYPES = ("wanderer", "sprinter", "brute", "blind")

OUTLINE = (16, 12, 12, 255)
FLASH_CORE = (255, 248, 224, 255)
FLASH_EDGE = (255, 196, 84, 255)
SMOKE = (150, 148, 140, 190)
MAW = (26, 16, 14, 255)
HIT_FLASH = (250, 244, 230, 220)
CENTER_X = 8


def rgb(hex_color: int) -> tuple[int, int, int, int]:
    return ((hex_color >> 16) & 255, (hex_color >> 8) & 255, hex_color & 255, 255)


class CharacterSpec:
    """Colors and body proportions for one character design."""

    def __init__(
        self,
        *,
        name: str,
        hair: int,
        hair_hi: int,
        skin: int,
        skin_shade: int,
        top: int,
        top_shade: int,
        top_hi: int,
        legs: int,
        legs_shade: int,
        boots: int,
        body_half_width: int = 3,
        arm_wide: bool = False,
        backpack: int | None = None,
        bandage: int | None = None,
    ):
        self.name = name
        self.hair = rgb(hair)
        self.hair_hi = rgb(hair_hi)
        self.skin = rgb(skin)
        self.skin_shade = rgb(skin_shade)
        self.top = rgb(top)
        self.top_shade = rgb(top_shade)
        self.top_hi = rgb(top_hi)
        self.legs = rgb(legs)
        self.legs_shade = rgb(legs_shade)
        self.boots = rgb(boots)
        self.body_half_width = body_half_width
        self.arm_wide = arm_wide
        self.backpack = rgb(backpack) if backpack else None
        self.bandage = rgb(bandage) if bandage else None
        self.gun = rgb(0x241F1E)
        self.gun_hi = rgb(0x4A423E)


PROTAGONIST = CharacterSpec(
    name="protagonist",
    hair=0x382A2A,
    hair_hi=0x52403C,
    skin=0xF0A878,
    skin_shade=0xC98858,
    top=0xA33B31,
    top_shade=0x74262A,
    top_hi=0xC25A44,
    legs=0x486078,
    legs_shade=0x33465A,
    boots=0xDED6C6,
    backpack=0x6B5A32,
)

ZOMBIE_SPECS = {
    "wanderer": CharacterSpec(
        name="wanderer",
        hair=0x423230,
        hair_hi=0x564440,
        skin=0xA8C060,
        skin_shade=0x7A9448,
        top=0x3C3C3C,
        top_shade=0x2A2A2C,
        top_hi=0x50504A,
        legs=0x46403A,
        legs_shade=0x332E2A,
        boots=0x5A5248,
    ),
    "sprinter": CharacterSpec(
        name="sprinter",
        hair=0x453432,
        hair_hi=0x5A4642,
        skin=0xC0D860,
        skin_shade=0x8FA84C,
        top=0x8E3038,
        top_shade=0x652028,
        top_hi=0xB04848,
        legs=0x3E3A40,
        legs_shade=0x2C2930,
        boots=0x6A5A48,
    ),
    "brute": CharacterSpec(
        name="brute",
        hair=0x3F302D,
        hair_hi=0x54423E,
        skin=0xC0D860,
        skin_shade=0x8FA84C,
        top=0x8E5A20,
        top_shade=0x6B4018,
        top_hi=0xB07A34,
        legs=0x44403A,
        legs_shade=0x322F2A,
        boots=0x4E463C,
        body_half_width=4,
        arm_wide=True,
    ),
    "blind": CharacterSpec(
        name="blind",
        hair=0x50464C,
        hair_hi=0x645860,
        skin=0x9AAC64,
        skin_shade=0x718448,
        top=0x5E4A62,
        top_shade=0x443548,
        top_hi=0x766078,
        legs=0x4A4450,
        legs_shade=0x38343C,
        boots=0x5E5860,
        bandage=0xC8C4AC,
    ),
}


class Frame:
    """A 16x24 pixel canvas stored as a sparse (x, y) -> RGBA map."""

    def __init__(self) -> None:
        self.pixels: dict[tuple[int, int], tuple[int, int, int, int]] = {}

    def set(self, x: int, y: int, color) -> None:
        if 0 <= x < CELL_W and 0 <= y < CELL_H:
            if color is None:
                self.pixels.pop((x, y), None)
            else:
                self.pixels[(x, y)] = color

    def fill(self, x0: int, y0: int, x1: int, y1: int, color) -> None:
        for y in range(min(y0, y1), max(y0, y1) + 1):
            for x in range(min(x0, x1), max(x0, x1) + 1):
                self.set(x, y, color)

    def mirrored(self) -> "Frame":
        frame = Frame()
        for (x, y), color in self.pixels.items():
            frame.set(CELL_W - 1 - x, y, color)
        return frame

    def outline(self) -> None:
        edges: list[tuple[int, int]] = []
        for (x, y), _color in self.pixels.items():
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                inside = 0 <= nx < CELL_W and 0 <= ny < CELL_H
                if inside and (nx, ny) not in self.pixels:
                    edges.append((nx, ny))
        for pos in edges:
            self.set(pos[0], pos[1], OUTLINE)


# --------------------------------------------------------------------------
# Shared body painters (used by every pose)
# --------------------------------------------------------------------------

def paint_head(
    frame: Frame,
    spec: CharacterSpec,
    cx: int,
    top: int,
    direction: str,
) -> None:
    """Chibi head: hair dome + face, occupying rows top..top+7."""
    half = spec.body_half_width
    hx0, hx1 = cx - half - 1, cx + half + 1
    hy1 = top + 7
    # hair dome
    frame.fill(hx0 + 1, top, hx1 - 1, top, spec.hair)
    frame.fill(hx0, top + 1, hx1, hy1 - 1, spec.hair)
    frame.fill(hx0 + 1, hy1, hx1 - 1, hy1, spec.hair)
    frame.fill(hx0 + 2, top + 1, hx0 + 3, top + 2, spec.hair_hi)

    if direction == "north":
        frame.fill(hx0 + 2, hy1, hx1 - 2, hy1, spec.hair_hi)
        return

    fx0, fx1 = cx - half, cx + half
    fy0 = top + 3
    frame.fill(fx0, fy0, fx1, hy1, spec.skin)
    frame.fill(fx0, hy1, fx1, hy1, spec.skin_shade)
    if direction == "south":
        frame.set(cx - 1, fy0 + 1, OUTLINE)
        frame.set(cx + 1, fy0 + 1, OUTLINE)
    else:
        # profile: single eye on the leading edge, nose bump
        eye_x = fx0 if direction == "west" else fx1
        frame.set(eye_x, fy0 + 1, OUTLINE)
        nose_x = fx0 - 1 if direction == "west" else fx1 + 1
        frame.set(nose_x, fy0, spec.skin)
        frame.set(nose_x, fy0 + 1, spec.skin_shade)
    if spec.bandage:
        frame.fill(fx0, fy0 + 1, fx1, fy0 + 2, spec.bandage)


def paint_torso(
    frame: Frame,
    spec: CharacterSpec,
    cx: int,
    y0: int,
    y1: int,
    direction: str,
) -> None:
    half = spec.body_half_width
    x0, x1 = cx - half, cx + half
    frame.fill(x0, y0, x1, y1, spec.top)
    frame.fill(x0, y1 - 1, x1, y1, spec.top_shade)
    frame.fill(x0 + 1, y0, x0 + 1, y0 + 1, spec.top_hi)
    if direction == "west":
        frame.fill(x1, y0, x1, y1 - 1, spec.top_shade)
    elif direction == "east":
        frame.fill(x0, y0, x0, y1 - 1, spec.top_shade)
    if spec.backpack and direction == "north":
        frame.fill(cx - 2, y0 + 1, cx + 2, y1 - 2, spec.backpack)
    elif spec.backpack and direction == "west":
        frame.fill(x1 + 1, y0 + 1, x1 + 1, y1 - 2, spec.backpack)
    elif spec.backpack and direction == "east":
        frame.fill(x0 - 1, y0 + 1, x0 - 1, y1 - 2, spec.backpack)


def paint_arms_down(
    frame: Frame,
    spec: CharacterSpec,
    cx: int,
    y0: int,
    y1: int,
    direction: str,
) -> None:
    half = spec.body_half_width
    offset = half + (1 if spec.arm_wide else 0)
    sides = (1,) if direction == "west" else ((-1,) if direction == "east" else (-1, 1))
    for side in sides:
        x = cx + side * (offset + 1)
        frame.fill(x, y0, x, y1, spec.top)
        frame.set(x, y1 + 1, spec.skin)


def paint_arms_raised(
    frame: Frame,
    spec: CharacterSpec,
    cx: int,
    y_top: int,
    direction: str,
) -> None:
    half = spec.body_half_width
    offset = half + (1 if spec.arm_wide else 0)
    sides = (1,) if direction == "west" else ((-1,) if direction == "east" else (-1, 1))
    for side in sides:
        x = cx + side * (offset + 1)
        frame.fill(x, y_top, x, y_top + 2, spec.skin)


def paint_legs(
    frame: Frame,
    spec: CharacterSpec,
    cx: int,
    y0: int,
    stride: int = 0,
) -> None:
    """Legs from y0 down to the y23 foot line."""
    total = 24 - y0  # legs + boots
    boots_h = 2
    legs_h = total - boots_h
    lx0, lx1 = cx - 2, cx + 1
    if stride:
        frame.fill(lx0 + stride, y0, lx0 + 1 + stride, y0 + legs_h - 1, spec.legs)
        frame.fill(lx1 - stride, y0, lx1 + 1 - stride, y0 + legs_h - 1, spec.legs)
        frame.fill(lx0 + stride, y0 + legs_h, lx0 + 1 + stride, 23, spec.boots)
        frame.fill(lx1 - stride, y0 + legs_h, lx1 + 1 - stride, 23, spec.boots)
    else:
        frame.fill(lx0, y0, lx0 + 1, y0 + legs_h - 1, spec.legs)
        frame.fill(lx1, y0, lx1 + 1, y0 + legs_h - 1, spec.legs)
        frame.fill(lx0, y0 + legs_h, lx0 + 1, 23, spec.boots)
        frame.fill(lx1, y0 + legs_h, lx1 + 1, 23, spec.boots)
        frame.fill(lx0, y0 + legs_h - 1, lx0 + 1, y0 + legs_h - 1, spec.legs_shade)
        frame.fill(lx1, y0 + legs_h - 1, lx1 + 1, y0 + legs_h - 1, spec.legs_shade)


def base_standing(spec: CharacterSpec, direction: str) -> Frame:
    frame = Frame()
    top = 2
    paint_head(frame, spec, CENTER_X, top, direction)
    paint_torso(frame, spec, CENTER_X, top + 8, top + 14, direction)
    paint_arms_down(frame, spec, CENTER_X, top + 8, top + 12, direction)
    paint_legs(frame, spec, CENTER_X, top + 15)
    frame.outline()
    return frame


def crouched(
    spec: CharacterSpec,
    direction: str,
    sink: int,
    lean: int = 0,
    arms_raised: bool = False,
) -> Frame:
    """Body sunk by `sink` px, head optionally leaning sideways."""
    frame = Frame()
    dx, dy = lean_vector(direction)
    head_cx = CENTER_X + dx * lean
    head_top = 2 + dy * lean + sink
    torso_y0 = max(head_top + 8, 16 - sink)
    paint_head(frame, spec, head_cx, head_top, direction)
    if torso_y0 > head_top + 8:
        frame.fill(head_cx - 1, head_top + 8, head_cx + 1, torso_y0 - 1, spec.top)
    paint_torso(frame, spec, CENTER_X, torso_y0, 16, direction)
    if arms_raised:
        paint_arms_raised(frame, spec, CENTER_X, torso_y0 - 1, direction)
    else:
        paint_arms_down(frame, spec, CENTER_X, torso_y0, min(torso_y0 + 4, 15), direction)
    paint_legs(frame, spec, CENTER_X, 17)
    frame.outline()
    return frame


def lean_vector(direction: str) -> tuple[int, int]:
    return {
        "south": (0, -1),
        "north": (0, -1),
        "west": (1, 0),
        "east": (-1, 0),
    }[direction]


# --------------------------------------------------------------------------
# Protagonist gun poses
# --------------------------------------------------------------------------

def gun_aim(spec: CharacterSpec, direction: str, variant: int) -> Frame:
    """Standing aim pose, pistol clearly drawn. variant 1 adds a dip."""
    frame = Frame()
    top = 2
    dip = 1 if variant == 2 else 0
    paint_head(frame, spec, CENTER_X, top + dip, direction)
    paint_torso(frame, spec, CENTER_X, top + 8, top + 14, direction)
    paint_legs(frame, spec, CENTER_X, top + 15)
    cx = CENTER_X
    if direction == "south":
        # pistol held two-handed at chest height, muzzle toward the camera
        frame.fill(cx - 3, 11, cx - 2, 12, spec.top)
        frame.fill(cx + 2, 11, cx + 3, 12, spec.top)
        frame.set(cx - 3, 13, spec.skin)
        frame.set(cx + 3, 13, spec.skin)
        frame.fill(cx - 1, 12, cx + 1, 13, spec.gun)
        frame.set(cx, 14, spec.gun_hi)
        frame.set(cx - 1, 11, spec.gun_hi)
    elif direction == "north":
        # shooting away: arms up, muzzle tip over the head
        frame.fill(cx - 5, 10, cx - 4, 12, spec.top)
        frame.fill(cx + 4, 10, cx + 5, 12, spec.top)
        frame.set(cx - 5, 13, spec.skin)
        frame.set(cx + 5, 13, spec.skin)
        frame.fill(cx - 1, 0, cx, 3, spec.gun)
        frame.set(cx, 0, spec.gun_hi)
        frame.set(cx - 1, 3, spec.gun)
    else:
        sign = -1 if direction == "west" else 1
        # arm extended toward the facing, pistol with barrel + grip
        frame.fill(cx + sign * 2, 11, cx + sign * 4, 12, spec.top)
        frame.set(cx + sign * 4, 12, spec.skin)
        frame.fill(cx + sign * 5, 10, cx + sign * 7, 10, spec.gun)
        frame.set(cx + sign * 5, 11, spec.gun)
        frame.set(cx + sign * 5, 12, spec.gun)
        frame.set(cx + sign * 7, 9, spec.gun_hi)
    frame.outline()
    return frame


def gun_fire(spec: CharacterSpec, direction: str, index: int) -> Frame:
    """index 0: big flash + recoil, 1: smoke wisp, 2: recover."""
    frame = gun_aim(spec, direction, 1)
    if index == 0:
        back = {"south": (0, -1), "north": (0, 1), "west": (1, 0), "east": (-1, 0)}[direction]
        shifted = Frame()
        for (x, y), color in frame.pixels.items():
            shifted.set(x + back[0], y + back[1], color)
        frame = shifted
    if index < 2:
        mx, my = {
            "south": (8, 13),
            "north": (8, 0),
            "west": (0, 10),
        }[direction]
        draw_flash(frame, mx, my, 2 if index == 0 else 1)
        if index == 1:
            sx, sy = {"south": (6, 16), "north": (10, 1), "west": (3, 8)}[direction]
            frame.set(sx, sy, SMOKE)
    return frame


def draw_flash(frame: Frame, mx: int, my: int, size: int) -> None:
    deltas = [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]
    if size >= 2:
        deltas += [(2, 0), (-2, 0), (0, 2), (0, -2), (1, 1), (-1, -1)]
    for dx, dy in deltas:
        x, y = mx + dx, my + dy
        if 0 <= x < CELL_W and 0 <= y < CELL_H:
            frame.set(x, y, FLASH_EDGE)
    frame.set(mx, my, FLASH_CORE)


# --------------------------------------------------------------------------
# Zombie action poses
# --------------------------------------------------------------------------

def zombie_hit(spec: CharacterSpec, direction: str, index: int) -> Frame:
    amp = (1, 2, 1)[index]
    frame = crouched(spec, direction, sink=0, lean=amp)
    if index == 1:
        # small impact blot on the leading edge of the face
        dx, dy = lean_vector(direction)
        sx = CENTER_X + dx * 2 + (1 if dx == 0 else dx)
        sy = 8 + dy * 2
        frame.set(sx, sy, HIT_FLASH)
        frame.set(sx + (1 if dx == 0 else 0), sy + (1 if dy == 0 else 0), HIT_FLASH)
    return frame


def zombie_bite(spec: CharacterSpec, direction: str, index: int) -> Frame:
    if index in (0, 3):
        return crouched(spec, direction, sink=1, lean=0, arms_raised=True)
    frame = Frame()
    paint_lunge(frame, spec, direction)
    return frame


def paint_lunge(frame: Frame, spec: CharacterSpec, direction: str) -> None:
    """Head-first lunge toward the player, maw open, arms reaching."""
    cx = CENTER_X
    if direction == "south":
        paint_head(frame, spec, cx, 4, "south")
        frame.fill(cx - 1, 9, cx + 1, 10, MAW)
        paint_torso(frame, spec, cx, 12, 17, "south")
        frame.fill(cx - 5, 12, cx - 4, 14, spec.top)
        frame.fill(cx + 4, 12, cx + 5, 14, spec.top)
        frame.set(cx - 5, 15, spec.skin)
        frame.set(cx + 5, 15, spec.skin)
        paint_legs(frame, spec, cx, 18)
    elif direction == "north":
        paint_head(frame, spec, cx, 3, "north")
        paint_torso(frame, spec, cx, 11, 16, "north")
        frame.fill(cx - 5, 11, cx - 4, 13, spec.top)
        frame.fill(cx + 4, 11, cx + 5, 13, spec.top)
        paint_legs(frame, spec, cx, 17)
    else:
        profile = "west" if direction == "west" else "east"
        sign = -1 if direction == "west" else 1
        head_cx = cx + sign * 2
        paint_head(frame, spec, head_cx, 5, profile)
        maw_x = head_cx + sign * (spec.body_half_width + 1)
        frame.fill(maw_x, 10, maw_x + sign, 11, MAW) if sign == 1 else frame.fill(
            maw_x - 1, 10, maw_x, 11, MAW
        )
        paint_torso(frame, spec, cx, 13, 18, profile)
        frame.fill(cx + sign * 3, 13, cx + sign * 5, 14, spec.top)
        frame.set(cx + sign * 5, 15, spec.skin)
        paint_legs(frame, spec, cx - sign, 19)
    frame.outline()


def zombie_death(spec: CharacterSpec, direction: str, index: int) -> Frame:
    if index == 0:
        return zombie_hit(spec, direction, 1)
    if index in (1, 2):
        return crouched(spec, direction, sink=2 * index, lean=index)
    return death_prone(spec, direction, index)


def death_prone(spec: CharacterSpec, direction: str, index: int) -> Frame:
    """index 3: mid-fall slump, 4: prone, 5: prone settled."""
    frame = Frame()
    if index == 3:
        shift = {"south": 0, "north": 0, "west": -1, "east": 1}[direction]
        head_cx = 6 + shift
        paint_head(frame, spec, head_cx, 8, "south")
        frame.fill(head_cx - 1, 16, head_cx + 1, 17, spec.top)  # neck
        frame.fill(6, 18, 12, 20, spec.top)
        frame.fill(7, 21, 11, 21, spec.top_shade)
        frame.fill(9, 22, 12, 22, spec.legs)
        frame.fill(9, 23, 12, 23, spec.boots)
        frame.fill(4, 19, 5, 20, spec.top)  # trailing arm
        frame.set(4, 21, spec.skin)
    else:
        dir_shift = {"south": 0, "north": -2, "west": -1, "east": 1}[direction]
        head_x = 2 + max(dir_shift, 0)
        y0 = 19
        frame.fill(head_x, y0, head_x + 3, y0 + 2, spec.hair)
        frame.fill(head_x, y0 + 3, head_x + 3, y0 + 4, spec.skin)
        frame.set(head_x + 1, y0 + 4, spec.skin_shade)
        frame.fill(head_x + 4, y0, head_x + 9, y0 + 2, spec.top)
        frame.fill(head_x + 4, y0 + 3, head_x + 9, y0 + 4, spec.top_shade)
        frame.fill(head_x + 4, y0 + 2, head_x + 9, y0 + 2, spec.top_hi)
        frame.fill(head_x + 10, y0 + 1, head_x + 12, y0 + 4, spec.legs)
        frame.set(head_x + 12, y0 + 1, spec.legs_shade)
        frame.fill(head_x + 13, y0 + 1, head_x + 13, y0 + 4, spec.boots)
        if index == 5:
            frame.fill(head_x + 10, y0, head_x + 13, y0, spec.legs_shade)
    frame.outline()
    return frame


# --------------------------------------------------------------------------
# Sheet assembly
# --------------------------------------------------------------------------

def paste(sheet: Image.Image, frame: Frame, row: int, column: int) -> None:
    image = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
    for (x, y), color in frame.pixels.items():
        image.putpixel((x, y), color)
    sheet.alpha_composite(image, (column * CELL_W, row * CELL_H))


def build_sheet(row_frames) -> Image.Image:
    sheet = Image.new("RGBA", (SHEET_SIDE, SHEET_SIDE), (0, 0, 0, 0))
    for row, frames in enumerate(row_frames):
        for column, frame in enumerate(frames):
            paste(sheet, frame, row, column)
    return sheet


def directional_rows(painter):
    """Frames per row; the east row mirrors the west row."""
    rows = []
    for direction in DIRECTIONS:
        if direction == "east":
            rows.append([f.mirrored() for f in rows[1]])
        else:
            rows.append(painter(direction))
    return rows


def gun_sheet(spec: CharacterSpec) -> Image.Image:
    return build_sheet(
        directional_rows(
            lambda d: [
                gun_aim(spec, d, 0),
                gun_aim(spec, d, 1),
                gun_aim(spec, d, 2),
                gun_fire(spec, d, 0),
                gun_fire(spec, d, 1),
                gun_fire(spec, d, 2),
            ]
        )
    )


def zombie_sheet(spec: CharacterSpec, action: str) -> Image.Image:
    def painter(direction: str):
        if action == "hit":
            return [zombie_hit(spec, direction, i) for i in range(3)] + [zombie_hit(spec, direction, 2)] * 3
        if action == "bite":
            return [zombie_bite(spec, direction, i) for i in range(4)] + [zombie_bite(spec, direction, 3)] * 2
        return [zombie_death(spec, direction, i) for i in range(6)]

    return build_sheet(directional_rows(painter))


def main() -> None:
    out_dir = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
    )
    os.makedirs(out_dir, exist_ok=True)

    # Mario's gun and pickup sheets come from tools/generate_protagonist_actions.py,
    # which builds them from his real idle frames.
    outputs = {}
    for zombie_type in ZOMBIE_TYPES:
        spec = ZOMBIE_SPECS[zombie_type]
        for action in ("hit", "bite", "death"):
            outputs[f"zombie_{zombie_type}_{action}.png"] = zombie_sheet(spec, action)

    for filename, sheet in outputs.items():
        path = os.path.join(out_dir, filename)
        sheet.save(path)
        print(f"wrote assets/sprites/{filename}")


if __name__ == "__main__":
    main()
