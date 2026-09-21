"""Convert the source story JPGs into game-ready PNGs for the intro.

The intro scenes are shown at the virtual 16:9 resolution doubled
(768x432, see docs/art_direction.md). The source JPGs are 1376x768
AI-pixel-art frames; a LANCZOS resize keeps them crisp enough while
staying inside the agreed resolution contract.
"""

from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = Path(r"C:\Users\vanni\Downloads")
TARGET_SIZE = (768, 432)

SCENES = [
    ("1.1.jpg", "scene_news.png"),
    ("1.2.jpg", "scene_blackout.png"),
    ("1.3.jpg", "scene_attack.png"),
]


def main() -> None:
    output_dir = REPO_ROOT / "assets" / "story"
    output_dir.mkdir(parents=True, exist_ok=True)
    for source_name, output_name in SCENES:
        with Image.open(SOURCE_DIR / source_name) as image:
            converted = image.convert("RGB").resize(TARGET_SIZE, Image.LANCZOS)
        destination = output_dir / output_name
        converted.save(destination, optimize=True)
        print(f"{source_name} -> {destination} ({destination.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
