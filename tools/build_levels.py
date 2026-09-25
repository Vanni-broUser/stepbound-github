#!/usr/bin/env python3
"""Bake every level background, or check the committed ones are current.

The layout of a place lives twice: as the ASCII `rows` the simulation
reads (lib/core/levels/tutorial) and as the PNG the player sees
(assets/levels), painted from those same rows by one of the bakers below.
Nothing in `flutter test` or `flutter analyze` sees the PNGs, so the two
can drift apart unnoticed. This is the gate that notices.

    python tools/build_levels.py            repaint assets/levels
    python tools/build_levels.py --check    fail if a PNG is out of date

`--check` paints into a temporary directory and compares the decoded
pixels, not the bytes of the file: the PNG encoder is not guaranteed
stable across versions of Pillow or zlib, the pixels are. It exits
non-zero at the first background that differs, naming the baker to re-run.

The bakers stay runnable on their own -- `python tools/build_station.py`,
from the repository root -- this only gives them one documented order and
one place that knows what each of them paints. This script finds the
repository from its own path, so it runs from anywhere.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile

import PIL
from PIL import Image, ImageChops

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_street_level import TILE  # noqa: E402

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLS)
LEVELS = os.path.join("assets", "levels")

# Every baker of a level background, with what it paints, in the order
# they run. Deterministic on purpose: the report of a --check run reads
# the same way twice. Sprites, audio and quest items are baked elsewhere
# and are not part of this gate.
#
# A place converted to the tile atlas leaves this table: it has no picture
# to keep up to date. The atlas itself is checked at the end of the run.
BAKERS: list[tuple[str, tuple[str, ...]]] = [
    (
        "build_street_level.py",
        (
            "first_street.png",
            "north_district.png",
            "harbour.png",
            "mall_north_street.png",
        ),
    ),
]


def run_baker(script: str, root: str) -> None:
    """Run one baker from `root`, which it reads and writes relative to."""
    result = subprocess.run(
        [sys.executable, os.path.join("tools", script)],
        cwd=root,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        sys.stdout.write(result.stdout)
        sys.stderr.write(result.stderr)
        raise SystemExit(f"tools/{script} failed ({result.returncode})")


def shadow_root(tmp: str) -> str:
    """A repository root the bakers can paint into without touching the
    working tree: everything is a symlink back to the real thing, except
    assets/levels, which is an empty directory of their own."""
    for name in sorted(os.listdir(ROOT)):
        if name != "assets":
            os.symlink(os.path.join(ROOT, name), os.path.join(tmp, name))
    assets = os.path.join(tmp, "assets")
    os.mkdir(assets)
    for name in sorted(os.listdir(os.path.join(ROOT, "assets"))):
        if name != "levels":
            os.symlink(
                os.path.join(ROOT, "assets", name), os.path.join(assets, name)
            )
    os.makedirs(os.path.join(tmp, LEVELS))
    return tmp


def compare(committed: str, fresh: str) -> str | None:
    """What differs between two backgrounds, or None if nothing does.
    Compares the decoded pixels: the PNG encoding is not guaranteed stable
    across versions of Pillow or zlib, the picture is."""
    if not os.path.exists(committed):
        return "it is missing from the repository"
    with Image.open(committed) as a, Image.open(fresh) as b:
        old, new = a.convert("RGBA"), b.convert("RGBA")
        if old.size != new.size:
            return (
                f"it measures {old.size[0]}x{old.size[1]} px, "
                f"the rows now ask for {new.size[0]}x{new.size[1]} px"
            )
        if old.tobytes() == new.tobytes():
            return None
        difference = ImageChops.difference(old, new)
        # An RGBA image reports the box of its alpha alone, and two opaque
        # backgrounds differ in their colours: ask the colours first.
        box = difference.convert("RGB").getbbox()
        if box is None:
            box = difference.getchannel("A").getbbox()
        if box is None:  # the bytes differ, so some band must
            return "its pixels differ"
        left, top, right, bottom = box
        return (
            f"the pixels from ({left}, {top}) to ({right - 1}, {bottom - 1}) "
            f"differ, that is tiles ({left // TILE}, {top // TILE}) to "
            f"({(right - 1) // TILE}, {(bottom - 1) // TILE})"
        )


def orphans() -> list[str]:
    """Backgrounds in assets/levels no baker paints any more."""
    baked = {name for _, outputs in BAKERS for name in outputs}
    return sorted(
        name
        for name in os.listdir(os.path.join(ROOT, LEVELS))
        if name.endswith(".png") and name not in baked
    )


ATLAS_BAKER = "build_tile_atlas.py"


def bake_all() -> None:
    for script, outputs in BAKERS:
        run_baker(script, ROOT)
        print(f"tools/{script}: {', '.join(outputs)}")
    print(f"{sum(len(o) for _, o in BAKERS)} backgrounds painted")
    run_baker(ATLAS_BAKER, ROOT)
    print(f"tools/{ATLAS_BAKER}: the tile atlas of the converted places")


def check_all() -> None:
    print(f"Python {sys.version.split()[0]}, Pillow {PIL.__version__}")
    with tempfile.TemporaryDirectory() as tmp:
        root = shadow_root(tmp)
        for script, outputs in BAKERS:
            run_baker(script, root)
            for name in outputs:
                painted = os.path.join(root, LEVELS, name)
                if not os.path.exists(painted):
                    raise SystemExit(
                        f"tools/{script} no longer paints {name}: fix the "
                        f"BAKERS table in tools/build_levels.py"
                    )
                difference = compare(os.path.join(ROOT, LEVELS, name), painted)
                if difference is not None:
                    raise SystemExit(
                        f"{LEVELS}/{name} is out of date: {difference}.\n"
                        f"Re-run it and commit the result:\n"
                        f"    python tools/{script}"
                    )
                print(f"{LEVELS}/{name}: up to date")
    left_over = orphans()
    if left_over:
        raise SystemExit(
            f"{LEVELS} holds backgrounds no baker paints any more: "
            f"{', '.join(left_over)}. Delete them, or add their baker to "
            f"the BAKERS table in tools/build_levels.py"
        )
    # The converted places have no picture to compare; what has to stay
    # current for them is the atlas they are painted from.
    result = subprocess.run(
        [sys.executable, os.path.join("tools", ATLAS_BAKER), "--check"],
        cwd=ROOT, capture_output=True, text=True,
    )
    sys.stdout.write(result.stdout)
    if result.returncode != 0:
        sys.stderr.write(result.stderr)
        raise SystemExit(f"tools/{ATLAS_BAKER} --check failed")
    print("every level background matches its ASCII rows")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--check",
        action="store_true",
        help="do not write anything: fail if a committed background is "
        "not what its rows would paint today",
    )
    check = parser.parse_args().check
    if not os.path.isdir(os.path.join(ROOT, LEVELS)):
        raise SystemExit(f"no {LEVELS} under {ROOT}")
    if check:
        check_all()
    else:
        bake_all()


if __name__ == "__main__":
    main()
