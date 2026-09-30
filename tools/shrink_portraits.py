"""Bring every character portrait down to the height the game draws it at.

The portraits come in at 1048x1501, and nothing on a target phone
(docs/target_devices.md, all of them 1080 tall or less in landscape) ever
draws one above about 1000 pixels: the dialogue box shows them at two
thirds of the screen, the book and the wardrobe at a little under the
whole of it. A file taller than that carries pixels no screen shows, and
the twenty-four of them were 22 MB of the download. Here each is resized
to PORTRAIT_HEIGHT tall, its width in proportion, with a Lanczos filter
on the colour. The alpha keeps the kind it had: a portrait drawn with
every pixel either fully there or not (the older ones, and the Halloween
outfits, which test/sprite_atlas_test.dart holds to it) comes out the
same, its edge hardened again after the filter; one drawn with soft
edges (Chiara, the Bruto, the wanderer) keeps them. Exact white,
which the filter can make out of near-white, is moved into the outfit's
own light colour where clean_portraits.py says so (the Halloween
outfits). Saved as an optimised PNG. Already-small files are left alone,
so it can be run on the whole folder whenever a new portrait comes in at
full size. The originals stay in the history of the repository.

test/sprite_atlas_test.dart holds the resulting size as the contract.

    python tools/shrink_portraits.py            every portrait
    python tools/shrink_portraits.py PATH...    the ones named
"""
from __future__ import annotations

import glob
import os
import sys

from PIL import Image

from clean_portraits import SOFTEN_PURE_WHITE, soften_pure_white

PORTRAIT_HEIGHT = 1000

# For a hard-edged portrait: below this, a resized pixel's alpha is dropped
# to nothing; from it up, raised to full.
ALPHA_EDGE = 128
PORTRAIT_DIRS = [
    os.path.join("assets", "characters", kind, "portraits")
    for kind in ("mario", "npcs", "zombies")
]


def shrink(path: str) -> str:
    with Image.open(path) as source:
        image = source.convert("RGBA")
    if image.height <= PORTRAIT_HEIGHT:
        return f"{path}: {image.width}x{image.height}, left alone"
    width = round(image.width * PORTRAIT_HEIGHT / image.height)
    before = os.path.getsize(path)
    # The colour is resized premultiplied, so transparent pixels (black
    # in most of these files) do not bleed a dark rim into the edge.
    premultiplied = Image.alpha_composite(
        Image.new("RGBA", image.size, (0, 0, 0, 255)), image)
    colour = premultiplied.resize((width, PORTRAIT_HEIGHT), Image.LANCZOS)
    alpha = image.getchannel("A").resize((width, PORTRAIT_HEIGHT), Image.LANCZOS)
    histogram = image.getchannel("A").histogram()
    hard_edged = sum(histogram[1:255]) == 0
    small = _unpremultiply(colour, alpha)
    small.putalpha(
        alpha.point(lambda a: 255 if a >= ALPHA_EDGE else 0)
        if hard_edged else alpha)
    name = os.path.basename(path)
    if name in SOFTEN_PURE_WHITE:
        soften_pure_white(small, SOFTEN_PURE_WHITE[name])
    small.save(path, "PNG", optimize=True)
    return (f"{path}: {image.width}x{image.height} -> "
            f"{width}x{PORTRAIT_HEIGHT}, {before // 1024} -> "
            f"{os.path.getsize(path) // 1024} KB")


def _unpremultiply(colour: Image.Image, alpha: Image.Image) -> Image.Image:
    """The colour of each pixel divided back by its resized alpha, so an
    edge pixel keeps the hue it had rather than the black it was
    composited over; fully transparent pixels stay black."""
    out = Image.new("RGBA", colour.size)
    colour_px, alpha_px, out_px = colour.load(), alpha.load(), out.load()
    for y in range(colour.height):
        for x in range(colour.width):
            a = alpha_px[x, y]
            r, g, b, _ = colour_px[x, y]
            if a > 0:
                r, g, b = (min(255, round(c * 255 / a)) for c in (r, g, b))
            out_px[x, y] = (r, g, b, 255)
    return out


def main() -> None:
    paths = sys.argv[1:] or sorted(
        path
        for directory in PORTRAIT_DIRS
        for path in glob.glob(os.path.join(directory, "*.png"))
    )
    for path in paths:
        print(shrink(path))


if __name__ == "__main__":
    main()
