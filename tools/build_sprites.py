#!/usr/bin/env python3
"""Regenerate the pictures the generators in tools/ make, or check that
the committed ones are what the generators make today.

The sprite sheets of the zombies and of Mario's actions and outfits, the
quest items, the menu sign and the app icons are all painted by a script
in tools/ and committed. Nothing in `flutter test` looks at them, so a
generator changed without being run again, or a sheet touched by hand
after its generator ran, drifts away unnoticed. This is the gate: the
same one `build_levels.py --check` is for the tile atlas.

    python tools/build_sprites.py            run every generator, in order
    python tools/build_sprites.py --check    fail if the committed pictures
                                             are not what they would make

The order matters: `strip_pistol_from_gun_sheets.py` reads the gun sheets
`generate_halloween_skins.py` writes, and `generate_team_throwable_skins.py`
reads the stripped ones. `--check` runs the whole chain in a temporary
copy of the repository and compares, pixel by pixel, every picture the
chain rewrote with the committed one: the bytes of a PNG are not stable
across Pillow or zlib versions, the pixels are. The previews under
docs/previews are documentation, drawn with whatever font the machine
has, and are left out of the comparison.

Not in the chain: `clean_portraits.py` (its dark-background rule cuts
through the outlines of the priest's and the carabiniere's portraits as
they are today: never run it blindly) and `process_story_images.py`
(needs the source art, which is not in the repository).

Runs in the environment of tools/requirements.txt; it finds the
repository from its own path, so it runs from anywhere.
"""
from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import subprocess
import sys
import tempfile

import PIL
from PIL import Image, ImageChops

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLS)

# In the order they must run.
GENERATORS = (
    "generate_action_sprites.py",
    "generate_carabiniere.py",
    "generate_special_zombies.py",
    "generate_crucified_zombie.py",
    "generate_protagonist_actions.py",
    "generate_halloween_skins.py",
    "strip_pistol_from_gun_sheets.py",
    "generate_team_throwable_skins.py",
    "clean_halloween_edges.py",
    "build_quest_items.py",
    "extract_logo.py",
    "generate_app_icons.py",
)

# What the generators read and write, copied into the temporary
# repository `--check` works in.
COPIED = (
    "tools",
    "assets/branding",
    "assets/characters",
    "assets/objects",
    "assets/story/ui",
    "docs/previews",
    "android/app/src/main/res",
    "ios/Runner/Assets.xcassets/AppIcon.appiconset",
    "web",
)

# Documentation, not assets: whatever a generator draws there is not
# compared.
NOT_COMPARED = ("docs/",)


def run(root: str, generator: str) -> None:
    result = subprocess.run(
        [sys.executable, os.path.join("tools", generator)],
        cwd=root, capture_output=True, text=True,
    )
    if result.returncode != 0:
        sys.stderr.write(result.stdout)
        sys.stderr.write(result.stderr)
        raise SystemExit(f"tools/{generator} failed")
    print(f"tools/{generator}: {result.stdout.strip().splitlines()[-1] if result.stdout.strip() else 'done'}")


def files_under(root: str) -> dict[str, str]:
    """Every file under [root] and the hash of its bytes."""
    found = {}
    for directory, _, names in os.walk(root):
        for name in names:
            path = os.path.join(directory, name)
            relative = os.path.relpath(path, root).replace(os.sep, "/")
            with open(path, "rb") as handle:
                found[relative] = hashlib.sha256(handle.read()).hexdigest()
    return found


def same_pixels(a: str, b: str) -> bool:
    """Whether the two pictures decode to the same pixels, frame by frame."""
    with Image.open(a) as first, Image.open(b) as second:
        frames = getattr(first, "n_frames", 1)
        if first.size != second.size or frames != getattr(second, "n_frames", 1):
            return False
        for index in range(frames):
            first.seek(index)
            second.seek(index)
            if ImageChops.difference(
                first.convert("RGBA"), second.convert("RGBA"),
            ).getbbox():
                return False
    return True


def check() -> None:
    print(f"Python {sys.version.split()[0]}, Pillow {PIL.__version__}")
    with tempfile.TemporaryDirectory(prefix="stepbound-sprites-") as temp:
        for relative in COPIED:
            source = os.path.join(ROOT, relative)
            if os.path.isdir(source):
                shutil.copytree(source, os.path.join(temp, relative))
        before = files_under(temp)
        for generator in GENERATORS:
            run(temp, generator)
        after = files_under(temp)
        rewritten = sorted(
            path for path, digest in after.items()
            if before.get(path) != digest
            and not path.startswith(NOT_COMPARED)
            and not path.startswith("tools/")
        )
        drifted = []
        for path in rewritten:
            committed = os.path.join(ROOT, path)
            if not os.path.exists(committed):
                drifted.append(f"{path}: not committed")
            elif not same_pixels(os.path.join(temp, path), committed):
                drifted.append(f"{path}: pixels differ")
        unchanged = sum(
            1 for path in after
            if path not in rewritten and not path.startswith(("docs/", "tools/"))
        )
    print(f"{len(rewritten)} pictures rewritten by the generators, "
          f"{len(rewritten) - len(drifted)} with the committed pixels; "
          f"{unchanged} files under the same folders left as they were")
    if drifted:
        raise SystemExit(
            "the committed pictures are not what the generators make:\n  "
            + "\n  ".join(drifted)
            + "\nRun the generators and commit the result:\n"
            "    python tools/build_sprites.py")
    print("every generated picture is what its generator makes")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--check",
        action="store_true",
        help="do not write anything: fail if the committed pictures are "
        "not what the generators make today",
    )
    if parser.parse_args().check:
        check()
    else:
        for generator in GENERATORS:
            run(ROOT, generator)


if __name__ == "__main__":
    main()
