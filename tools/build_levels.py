#!/usr/bin/env python3
"""Paint what the levels are drawn with, or check that it is current.

A place used to live twice: as the ASCII `rows` the simulation reads
(lib/core/levels/tutorial) and as a PNG the player saw (assets/levels),
baked from those rows by one of eleven bakers. Nothing in `flutter test` or
`flutter analyze` saw the PNGs, so the two could drift apart unnoticed, and
this script was the gate that noticed.

No place has a baked picture any more: the game paints every one of them
at runtime from its rows, out of the tile atlas (assets/tiles). What is
left to keep current is the atlas itself -- the tiles and the objects the
painters make -- and that is what this runs.

    python tools/build_levels.py            repaint the tile atlas
    python tools/build_levels.py --check    fail if it is out of date

It stays the one documented entry point the CI jobs call; the work is
tools/build_tile_atlas.py's. It finds the repository from its own path, so
it runs from anywhere.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys

import PIL

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLS)
ATLAS_BAKER = "build_tile_atlas.py"


def run(*arguments: str) -> None:
    result = subprocess.run(
        [sys.executable, os.path.join("tools", ATLAS_BAKER), *arguments],
        cwd=ROOT, capture_output=True, text=True,
    )
    sys.stdout.write(result.stdout)
    if result.returncode != 0:
        sys.stderr.write(result.stderr)
        raise SystemExit(f"tools/{ATLAS_BAKER} {' '.join(arguments)} failed")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--check",
        action="store_true",
        help="do not write anything: fail if the committed atlas is not "
        "what its painters make today",
    )
    if parser.parse_args().check:
        print(f"Python {sys.version.split()[0]}, Pillow {PIL.__version__}")
        run("--check")
        print("every place is painted from its ASCII rows")
    else:
        run()


if __name__ == "__main__":
    main()
