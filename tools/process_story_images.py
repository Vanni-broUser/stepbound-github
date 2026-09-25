"""Put the story scenes of the game in place, from the source art or not.

Two kinds of scene live in assets/story:

* the three intro frames, shown at the virtual 16:9 resolution doubled
  (768x432, see docs/art_direction.md). The source JPGs are 1376x768
  AI-pixel-art frames; a LANCZOS resize keeps them crisp enough while
  staying inside the agreed resolution contract;
* the scenes played during the game, which keep the source frame as it is
  (1376x768), like every other `scene_*.jpg` already in the repository.

Both read from [SOURCE_DIR], the folder the frames are generated into. A
scene whose source is not there gets a painted stand-in instead, so the
story always has a frame to show: run the script again on the machine that
has the art and the stand-in is overwritten by the real thing.
"""

from __future__ import annotations

import random
from pathlib import Path

from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = Path(r"C:\Users\vanni\Downloads")
TARGET_SIZE = (768, 432)
SCENE_SIZE = (1376, 768)

INTRO_SCENES = [
    ("1.1.jpg", "scene_news.png"),
    ("1.2.jpg", "scene_blackout.png"),
    ("1.3.jpg", "scene_attack.png"),
]

# How the mass in the Duomo ends (DuomoScript.massacreScene): the sermon
# turned to worship, the community eating of the crucified zombie, what that
# makes of them, and Don Angelo dragged off by it.
STORY_SCENES = [
    ("Gemini_Generated_Image_ahymacahymacahym.jpg", "scene_priest_worship.jpg"),
    ("Gemini_Generated_Image_12b7am12b7am12b7.jpg", "scene_cultists_feast.jpg"),
    ("Gemini_Generated_Image_skd6igskd6igskd6.jpg", "scene_cultists_mutation.jpg"),
    ("Gemini_Generated_Image_jf8hxmjf8hxmjf8h.jpg", "scene_priest_seized.jpg"),
]

STONE = (58, 54, 50)
STONE_DARK = (34, 32, 31)
DARK = (14, 13, 15)
ROBE = (40, 36, 42)
ROBE_LIGHT = (62, 56, 64)
FLESH = (120, 138, 96)
VEIN = (196, 184, 72)
BLOOD = (112, 26, 28)
TORCH = (206, 148, 62)
CASSOCK = (24, 22, 26)
SASH = (92, 47, 94)
PALE = (166, 150, 146)


def _nave(image: Image.Image, d: ImageDraw.ImageDraw) -> None:
    """The basilica every stand-in is set in: the dark of the nave, the lit
    apse at the end of it and the floor running away under the figures."""
    width, height = image.size
    horizon = int(height * 0.42)
    d.rectangle([0, 0, width, horizon], fill=DARK)
    d.rectangle([0, horizon, width, height], fill=STONE_DARK)
    for step in range(1, 11):
        y = horizon + int((height - horizon) * (step / 11) ** 1.8)
        d.rectangle([0, y, width, y + 3], fill=(46, 43, 40))
    # The apse: a lit arch at the end of the nave, the only warmth in it.
    arch = (int(width * 0.41), int(height * 0.08), int(width * 0.59), horizon)
    d.rectangle([arch[0], int(height * 0.16), arch[2], arch[3]], fill=(46, 40, 34))
    d.ellipse(
        [arch[0], int(height * 0.08), arch[2], int(height * 0.24)],
        fill=(46, 40, 34),
    )
    d.ellipse(
        [
            int(width * 0.455),
            int(height * 0.17),
            int(width * 0.545),
            int(height * 0.40),
        ],
        fill=(86, 66, 40),
    )
    # The piers down each side, closing the nave in.
    for side in (-1, 1):
        for depth in (0.02, 0.14, 0.30):
            middle = int(width * (0.5 + side * (0.22 + depth)))
            shaft = int(width * (0.018 + depth * 0.030))
            foot = horizon + int((height - horizon) * (depth + 0.08))
            d.rectangle([middle - shaft, 0, middle + shaft, foot], fill=STONE)
            d.rectangle(
                [middle - shaft, 0, middle - shaft + max(3, shaft // 3), foot],
                fill=(80, 74, 66),
            )
            d.rectangle(
                [middle - shaft - 6, foot - 14, middle + shaft + 6, foot],
                fill=(72, 66, 60),
            )
            # A torch burning on the pier, and the stone it lights.
            flame_y = int(height * (0.26 + depth * 0.22))
            d.ellipse(
                [
                    middle - shaft - 10,
                    flame_y - 26,
                    middle + shaft + 10,
                    flame_y + 26,
                ],
                fill=(64, 50, 34),
            )
            d.polygon(
                [
                    (middle, flame_y - 20),
                    (middle + 9, flame_y + 8),
                    (middle - 9, flame_y + 8),
                ],
                fill=TORCH,
            )


def _legs(d: ImageDraw.ImageDraw, x: int, y: int, height: int, spread: int, colour) -> None:
    for side in (-1, 1):
        d.rectangle(
            [x + side * spread - height // 9, y - height, x + side * spread + height // 9, y],
            fill=colour,
        )


def _hooded(d: ImageDraw.ImageDraw, x: int, y: int, scale: float, bowed: bool) -> None:
    """A cultist in his robe, standing or bent forward over the floor."""
    body = int(230 * scale)
    width = int(46 * scale)
    lean = int(body * 0.30) if bowed else 0
    shoulders = y - body
    d.polygon(
        [
            (x - width, y),
            (x + width, y),
            (x + int(width * 0.62) + lean, shoulders),
            (x - int(width * 0.62) + lean, shoulders),
        ],
        fill=ROBE,
    )
    d.polygon(
        [
            (x - int(width * 0.5), y),
            (x + int(width * 0.5), y),
            (x, y - int(body * 0.12)),
        ],
        fill=(20, 18, 22),
    )
    head = int(24 * scale)
    # The hood: a point over the face, not a ball on a stick.
    d.polygon(
        [
            (x - head + lean, shoulders + head // 2),
            (x + head + lean, shoulders + head // 2),
            (x + int(head * 0.2) + lean, shoulders - int(head * 1.9)),
        ],
        fill=ROBE_LIGHT,
    )
    d.polygon(
        [
            (x - int(head * 0.62) + lean, shoulders + head // 3),
            (x + int(head * 0.62) + lean, shoulders + head // 3),
            (x + int(head * 0.1) + lean, shoulders - head),
        ],
        fill=(16, 15, 18),
    )
    # The arms, forward when he is bent over what he is eating.
    for side in (-1, 1):
        end = (
            (x + side * int(width * 0.7) + lean * 2, y - int(body * 0.18))
            if bowed
            else (x + side * int(width * 1.1), y - int(body * 0.30))
        )
        d.line(
            [(x + lean // 2, shoulders + int(body * 0.10)), end],
            fill=ROBE,
            width=max(4, int(18 * scale)),
        )


def _mutated(d: ImageDraw.ImageDraw, x: int, y: int, scale: float) -> None:
    """One of them after the feast: swollen out of the torn robe, the hood
    fallen on the shoulders and the veins standing out on the arms."""
    body = int(260 * scale)
    shoulders = y - body
    chest = int(52 * scale)
    _legs(d, x, y, int(body * 0.42), int(chest * 0.55), ROBE)
    d.polygon(
        [
            (x - int(chest * 0.8), y - int(body * 0.34)),
            (x + int(chest * 0.8), y - int(body * 0.34)),
            (x + chest, shoulders),
            (x - chest, shoulders),
        ],
        fill=FLESH,
    )
    # What is left of the robe, hanging off the shoulders and the waist.
    d.polygon(
        [
            (x - int(chest * 0.95), y - int(body * 0.30)),
            (x + int(chest * 0.95), y - int(body * 0.30)),
            (x + int(chest * 0.75), y - int(body * 0.55)),
            (x - int(chest * 0.75), y - int(body * 0.55)),
        ],
        fill=ROBE,
    )
    for side in (-1, 1):
        d.line(
            [
                (x + side * chest, shoulders + int(body * 0.06)),
                (x + side * int(chest * 1.7), y - int(body * 0.34)),
            ],
            fill=FLESH,
            width=max(5, int(26 * scale)),
        )
        d.line(
            [
                (x + side * int(chest * 1.1), shoulders + int(body * 0.12)),
                (x + side * int(chest * 1.55), y - int(body * 0.40)),
            ],
            fill=VEIN,
            width=max(2, int(5 * scale)),
        )
    head = int(30 * scale)
    d.ellipse(
        [x - head, shoulders - int(head * 1.7), x + head, shoulders + head // 3],
        fill=FLESH,
    )
    eye = max(3, int(6 * scale))
    for side in (-1, 1):
        d.ellipse(
            [
                x + side * head // 2 - eye,
                shoulders - head,
                x + side * head // 2 + eye,
                shoulders - head + eye * 2,
            ],
            fill=VEIN,
        )


def _priest(d: ImageDraw.ImageDraw, x: int, y: int, scale: float, arms_up: bool) -> None:
    """Don Angelo in his cassock, preaching or held off the ground."""
    body = int(240 * scale)
    width = int(42 * scale)
    shoulders = y - body
    d.polygon(
        [
            (x - width, y),
            (x + width, y),
            (x + int(width * 0.55), shoulders),
            (x - int(width * 0.55), shoulders),
        ],
        fill=CASSOCK,
    )
    d.rectangle(
        [
            x - int(width * 0.55),
            shoulders + int(body * 0.14),
            x + int(width * 0.55),
            shoulders + int(body * 0.19),
        ],
        fill=SASH,
    )
    head = int(21 * scale)
    d.ellipse(
        [x - head, shoulders - int(head * 1.8), x + head, shoulders + head // 3],
        fill=PALE,
    )
    arm = int(body * 0.5)
    for side in (-1, 1):
        end = (
            (x + side * int(arm * 0.75), shoulders - int(arm * 0.75))
            if arms_up
            else (x + side * int(arm * 0.85), shoulders + int(arm * 0.45))
        )
        d.line(
            [(x, shoulders + int(body * 0.08)), end],
            fill=CASSOCK,
            width=max(4, int(17 * scale)),
        )


def _splatter(d: ImageDraw.ImageDraw, rng: random.Random, x: int, y: int, count: int) -> None:
    for _ in range(count):
        radius = rng.randrange(5, 26)
        cx = x + rng.randrange(-320, 320)
        cy = y + rng.randrange(-140, 30)
        d.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=BLOOD)


def _caption(image: Image.Image, name: str) -> None:
    """Says on the frame itself that it is a stand-in, so nobody takes it
    for the finished scene: the script overwrites it once the art is there."""
    width, height = image.size
    d = ImageDraw.Draw(image)
    strip = int(height * 0.055)
    d.rectangle([0, height - strip, width, height], fill=(10, 9, 11))
    label = Image.new("RGB", (width // 4, strip // 2), (10, 9, 11))
    ImageDraw.Draw(label).text(
        (6, 2),
        f"arte provvisoria - {name}",
        fill=(120, 112, 104),
    )
    image.paste(label.resize((width // 2, strip), Image.NEAREST), (14, height - strip))


def placeholder(name: str) -> Image.Image:
    """A painted stand-in for the scene called [name]: the nave of the Duomo
    with the moment blocked out in silhouette, so the story reads even
    before the final art is dropped in."""
    width, height = SCENE_SIZE
    image = Image.new("RGB", SCENE_SIZE, DARK)
    d = ImageDraw.Draw(image)
    rng = random.Random(name)
    _nave(image, d)
    floor = int(height * 0.90)
    middle = width // 2
    if name == "scene_priest_worship.jpg":
        # The crucified zombie over the altar, Don Angelo preaching under it,
        # his community standing along the nave.
        d.rectangle([middle - 10, int(height * 0.10), middle + 10, int(height * 0.44)],
                    fill=(96, 74, 44))
        d.rectangle(
            [middle - 110, int(height * 0.17), middle + 110, int(height * 0.20)],
            fill=(96, 74, 44),
        )
        _mutated(d, middle, int(height * 0.42), 0.42)
        _priest(d, middle, int(height * 0.80), 0.85, arms_up=True)
        for index, offset in enumerate((-590, -390, 400, 600)):
            _hooded(d, middle + offset, floor, 0.95 + index * 0.05, bowed=False)
    elif name == "scene_cultists_feast.jpg":
        # Bent over what they are eating, Mario watching from the aisle.
        for index, offset in enumerate((-480, -230, 70, 330)):
            _hooded(d, middle + offset, floor, 1.0 + index * 0.08, bowed=True)
        _splatter(d, rng, middle - 70, floor - 40, 24)
    elif name == "scene_cultists_mutation.jpg":
        # Standing up again, swollen, the robes torn open.
        for index, offset in enumerate((-520, -240, 130, 470)):
            _mutated(d, middle + offset, floor, 0.95 + index * 0.05)
        _splatter(d, rng, middle, floor - 30, 14)
    else:
        # Don Angelo taken by what his community has become.
        _mutated(d, middle - 340, floor - 30, 1.0)
        _mutated(d, middle + 340, floor - 30, 1.05)
        _priest(d, middle, floor - 70, 0.8, arms_up=True)
        _mutated(d, middle - 150, floor, 1.1)
        _mutated(d, middle + 160, floor, 1.15)
        _splatter(d, rng, middle, floor - 90, 26)
    _caption(image, name)
    return image


def main() -> None:
    output_dir = REPO_ROOT / "assets" / "story"
    output_dir.mkdir(parents=True, exist_ok=True)
    for source_name, output_name in INTRO_SCENES:
        source = SOURCE_DIR / source_name
        if not source.exists():
            print(f"{source_name} missing: {output_name} left as it is")
            continue
        with Image.open(source) as image:
            converted = image.convert("RGB").resize(TARGET_SIZE, Image.LANCZOS)
        destination = output_dir / output_name
        converted.save(destination, optimize=True)
        print(f"{source_name} -> {destination} ({destination.stat().st_size} bytes)")
    for source_name, output_name in STORY_SCENES:
        source = SOURCE_DIR / source_name
        destination = output_dir / output_name
        if source.exists():
            with Image.open(source) as image:
                converted = image.convert("RGB")
            if converted.size != SCENE_SIZE:
                converted = converted.resize(SCENE_SIZE, Image.LANCZOS)
            origin = source_name
        else:
            converted = placeholder(output_name)
            origin = "stand-in"
        converted.save(destination, quality=88, optimize=True)
        print(f"{origin} -> {destination} ({destination.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
