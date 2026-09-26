"""Cleans the character portraits of what their generated background left.

Two kinds of leftovers, both drawn in white and light grey:

- the checkerboard the image generator paints to mean "transparent",
  trapped in the gaps between an arm and the body: every patch of neutral
  white alternating with neutral light grey is made transparent;
- a light fringe just outside the black outline: light, unsaturated pixels
  touching transparency are removed, over and over, until none is left.

Eyes, teeth and light soles sit inside the black outline and are never
reached; saturated light colours (flames) are left alone.

A few white blocks caught between locks of hair look to any rule like an
eye or a tooth; they are listed by hand in HAND_FIXES and filled with the
colour most of their surroundings have.

    python tools/clean_portraits.py            # every character portrait
    python tools/clean_portraits.py --check    # exit 1 if any still needs it
"""

import glob
import os
import sys

from PIL import Image

LIGHT = 170
SATURATION = 45
CHECKER_LIGHT = 180
CHECKER_MIN = 40

# Portrait file name -> boxes (left, top, right, bottom, inclusive) whose
# near-white pixels are stray background, not part of the drawing.
HAND_FIXES = {
    "mutilated.png": [(595, 552, 611, 573)],
    "burning.png": [
        (570, 299, 608, 344),
        (530, 346, 552, 353),
        (709, 347, 717, 353),
        (785, 427, 792, 435),
    ],
}


def _is_light(p):
    return p[3] > 0 and min(p[:3]) >= LIGHT and max(p[:3]) - min(p[:3]) <= SATURATION


def _is_checker_grey(p):
    return p[3] > 0 and max(p[:3]) - min(p[:3]) <= 10 and min(p[:3]) >= CHECKER_LIGHT


def _neighbours(x, y, w, h):
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nx, ny = x + dx, y + dy
        if 0 <= nx < w and 0 <= ny < h:
            yield nx, ny


def checker_patches(im):
    """Patches of white alternating with light grey, as pixel lists."""
    px = im.load()
    w, h = im.size
    seen = set()
    patches = []
    for y in range(h):
        for x in range(w):
            if (x, y) in seen or not _is_checker_grey(px[x, y]):
                continue
            patch = [(x, y)]
            seen.add((x, y))
            i = 0
            while i < len(patch):
                for n in _neighbours(*patch[i], w, h):
                    if n not in seen and _is_checker_grey(px[n]):
                        seen.add(n)
                        patch.append(n)
                i += 1
            whites = sum(1 for c in patch if min(px[c][:3]) >= 245)
            greys = sum(1 for c in patch if 185 <= min(px[c][:3]) <= 225)
            if (len(patch) >= CHECKER_MIN and whites >= 0.2 * len(patch)
                    and greys >= 0.2 * len(patch)):
                patches.append(patch)
    return patches


def fringe(im):
    """Light pixels touching transparency, peeled layer by layer."""
    px = im.load()
    w, h = im.size
    removed = []
    while True:
        layer = [
            (x, y)
            for y in range(h)
            for x in range(w)
            if _is_light(px[x, y])
            and any(px[n][3] == 0 for n in _neighbours(x, y, w, h))
        ]
        if not layer:
            return removed
        for c in layer:
            px[c] = (0, 0, 0, 0)
        removed += layer


def hand_fix(im, boxes):
    """Fills the light pixels of [boxes] with the commonest other
    colour around each box; returns how many were filled."""
    px = im.load()
    w, h = im.size
    count = 0
    for left, top, right, bottom in boxes:
        around = {}
        for y in range(max(0, top - 6), min(h, bottom + 7)):
            for x in range(max(0, left - 6), min(w, right + 7)):
                p = px[x, y]
                if p[3] > 0 and not _is_light(p):
                    around[p] = around.get(p, 0) + 1
        fill = max(around, key=around.get)
        for y in range(top, bottom + 1):
            for x in range(left, right + 1):
                if _is_light(px[x, y]):
                    px[x, y] = fill
                    count += 1
    return count


def clean(im, name=""):
    """Cleans [im] in place; returns how many pixels were changed."""
    px = im.load()
    count = hand_fix(im, HAND_FIXES.get(name, []))
    for patch in checker_patches(im):
        for c in patch:
            px[c] = (0, 0, 0, 0)
        count += len(patch)
    return count + len(fringe(im))


def main():
    check = "--check" in sys.argv
    dirty = []
    portrait_dirs = [
        os.path.join("assets", "characters", kind, "portraits")
        for kind in ("mario", "npcs", "zombies")
    ]
    paths = sorted(
        path for directory in portrait_dirs
        for path in glob.glob(os.path.join(directory, "*.png"))
    )
    for path in paths:
        im = Image.open(path).convert("RGBA")
        cleared = clean(im, os.path.basename(path))
        if cleared:
            dirty.append(path)
            print(f"{path}: {cleared} pixels")
            if not check:
                im.save(path)
    if check and dirty:
        sys.exit(1)


if __name__ == "__main__":
    main()
