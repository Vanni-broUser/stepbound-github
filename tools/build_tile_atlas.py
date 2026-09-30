#!/usr/bin/env python3
"""Bake the tile atlas the game paints converted places from.

A place used to exist twice: as the ASCII rows the simulation reads and as
a PNG painted from those rows by a baker. A converted place has no PNG:
the renderer paints it at runtime from the same rows, one tile per glyph,
out of assets/levels/tiles/atlas.png.

This is where the bakers' *art* goes on living once their *composition*
dies. A baker knew two things: how to paint a bench, and where the benches
are. The second is in the ASCII rows and belongs to the game; only the
first is here. The rows are never read by this script: it paints tiles,
not places.

    python tools/build_tile_atlas.py            repaint the atlas
    python tools/build_tile_atlas.py --check    fail if it is out of date
    python tools/build_tile_atlas.py --preview  draw the places for the eye

Each interior is a module of its own, tile_atlas_<place>.py, and the
city's places are tile_atlas_city.py's: this script lists them, packs
what they paint into the atlas and writes the manifest. The machinery
they share is tile_atlas_core.py.

What the manifest says, per place, is a list of ordered rules: for the
glyphs of this rule, on this layer, take a tile out of this bucket. The
bucket is chosen by a handful of boolean keys (the parity of the cell, the
row, a neighbour), and the tile inside it by a hash of the position, so
the grit falls the same way at every start and nothing has to be saved.
Objects too big for a cell -- the railcar, a two-tile door -- are their
own images, anchored to the glyph that names them.
"""
from __future__ import annotations

import argparse
import json
import os
import random
import re
import sys
import tempfile

from PIL import Image, ImageChops

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from street_paint import TILE  # noqa: E402
import tile_atlas_city as city  # noqa: E402
import tile_atlas_company as company  # noqa: E402
import tile_atlas_shop as shop  # noqa: E402
import tile_atlas_hospital as hospital  # noqa: E402
import tile_atlas_palazzo as palazzo  # noqa: E402
import tile_atlas_terme as terme  # noqa: E402
from tile_atlas_core import (  # noqa: E402
    Atlas,
    LAYERS,
    SEED,
    compose,
)
from tile_atlas_airliner import (  # noqa: E402
    airliner_cabin,
    airliner_roofs,
)
from tile_atlas_bar import (  # noqa: E402
    bar_arcobaleno,
    bar_backroom,
)
from tile_atlas_barracks import (  # noqa: E402
    barracks,
)
from tile_atlas_church import (  # noqa: E402
    church,
)
from tile_atlas_duomo import (  # noqa: E402
    duomo,
    duomo_bells,
    duomo_second_floor,
    duomo_tower,
    duomo_tower_roof,
    duomo_upper,
)
from tile_atlas_mall import (  # noqa: E402
    mall_first,
    mall_ground,
)
from tile_atlas_station import (  # noqa: E402
    TERMINI_RAILCAR_DOOR_TILE,
    TERMINI_RAILCAR_TILES,
    TERMINI_WALL_SIGN_TILES,
    flight,
    station_far_side,
    station_hall,
    station_railcar_sprite,
    station_underpass,
    termini_platform_sign,
    termini_wall_sign,
)
from tile_atlas_termini import (  # noqa: E402
    termini_concourse,
    termini_far_platform,
    termini_overpass,
)
from tile_atlas_train import (  # noqa: E402
    train_interior,
)

# Tiles to a row of the atlas image: 64 keeps it square-ish and inside the
# 4096 pixels every phone's GPU takes, up to four thousand tiles.
COLUMNS = 64

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILES = os.path.join("assets", "levels", "tiles")
ATLAS = os.path.join(TILES, "atlas.png")
MANIFEST = os.path.join(TILES, "atlas_manifest.json")
PLACES_DIR = os.path.join("assets", "levels", "places")


def place_group(filename: str) -> str:
    """Return the level-area folder that owns a generated prop."""
    if filename.startswith(("duomo_", "termini_", "piazzaCinquecento_",
                            "viaMarsala_", "termeDiocleziano_")):
        return "rome"
    if filename.startswith("train_"):
        return "train"
    return "hometown"


def place_asset(filename: str) -> str:
    return os.path.join(PLACES_DIR, place_group(filename), filename)


def manifest_place_asset(filename: str) -> str:
    return f"{place_group(filename)}/{filename}"


# ----------------------------------------------------------------- writing

PLACES = {
    "barracks": barracks,
    "church": church,
    "airlinerCabin": airliner_cabin,
    "airlinerRoofs": airliner_roofs,
    "barArcobaleno": bar_arcobaleno,
    "barBackroom": bar_backroom,
    "duomo": duomo,
    "duomoUpper": duomo_upper,
    "duomoSecondFloor": duomo_second_floor,
    "duomoTower": duomo_tower,
    "duomoBells": duomo_bells,
    "duomoTowerRoof": duomo_tower_roof,
    "mallFirst": mall_first,
    "mallGround": mall_ground,
    "station": station_hall,
    "stationFarSide": station_far_side,
    "stationUnderpass": station_underpass,
    "terminiConcourse": termini_concourse,
    "terminiFarPlatform": termini_far_platform,
    "terminiOverpass": termini_overpass,
    "trainInterior": train_interior,
    **city.PLACES,
    **hospital.PLACES,
    **terme.PLACES,
    **palazzo.PLACES,
    **company.PLACES,
    **shop.PLACES,
}


def build() -> tuple[Atlas, dict]:
    atlas = Atlas()
    # Each place has a stream of its own: one shared by all would shift
    # every place after the one being added, and the diff of a conversion
    # would repaint the ones already done.
    places = {
        name: make(atlas, random.Random(f"{SEED}/{name}"))
        for name, make in sorted(PLACES.items())
    }
    # Termini keeps the same material rules and railcar, but has its own
    # art key so Molfetta's two place-name boards do not follow it to Rome.
    far_side = places["stationFarSide"]
    places["romeTermini"] = {
        **far_side,
        # Its stairs go up, not down: the rest of the far side's rules.
        "rules": [spec for spec in far_side["rules"]
                  if not (spec["layer"] == "structures"
                          and spec["glyphs"] == "D")]
        + flight(atlas, "D", up=True),
        "objects": [{
            "glyph": "M",
            "image": "termini_railcar.png",
            "tiles": list(TERMINI_RAILCAR_TILES),
            "sprite": station_railcar_sprite(
                TERMINI_RAILCAR_TILES, TERMINI_RAILCAR_DOOR_TILE, False),
            "whenOpen": "termini_railcar_open.png",
            "openSprite": station_railcar_sprite(
                TERMINI_RAILCAR_TILES, TERMINI_RAILCAR_DOOR_TILE, True),
        }, {
            "glyph": "Q",
            "image": "termini_sign_wall.png",
            "tiles": list(TERMINI_WALL_SIGN_TILES),
            "sprite": termini_wall_sign(),
        }, {
            "glyph": "o",
            "image": "termini_sign_platform.png",
            # Its board stands a tile above the posts' cells.
            "offsetY": -1,
            "sprite": termini_platform_sign(),
        }],
    }
    manifest = {
        "format": "stepbound-tile-atlas-v1",
        "tileWidth": TILE,
        "tileHeight": TILE,
        "layers": [layer for layer in LAYERS if layer != "objects"],
        "palette": "assets/palette.gpl",
        "atlas": ATLAS.replace(os.sep, "/"),
        "columns": COLUMNS,
        "places": {
            name: {
                "void": place["void"],
                "voidGlyph": place["voidGlyph"],
                **{key: place[key] for key in ("outside", "ground")
                   if key in place},
                "rules": place["rules"],
                "objects": [
                    {
                        k: manifest_place_asset(v)
                        if k in ("image", "whenOpen") else v
                        for k, v in obj.items()
                        if k not in ("sprite", "openSprite")
                    }
                    for obj in place["objects"]
                ],
            }
            for name, place in places.items()
        },
    }
    return atlas, {"manifest": manifest, "places": places}


def manifest_json(manifest: dict) -> str:
    """The manifest as JSON, indented for a diff to read, with every list
    of numbers kept on one line: a bucket is a handful of tile numbers,
    and one to a line made the city's rules half a megabyte of line
    breaks."""
    text = json.dumps(manifest, indent=2)
    text = re.sub(r"\[\s*(-?\d+(?:,\s*-?\d+)*)\s*\]",
                  lambda m: "[" + ", ".join(re.split(r",\s*", m.group(1)))
                  + "]", text)
    text = re.sub(r"\[\s*\]", "[]", text)
    # and a list of those lists -- the buckets of a rule -- on one line too
    text = re.sub(r"\[\s*(\[[^\[\]]*\](?:,\s*\[[^\[\]]*\])*)\s*\]",
                  lambda m: "[" + ", ".join(
                      re.findall(r"\[[^\[\]]*\]", m.group(1))) + "]", text)
    return text + "\n"


def save_object(sprite: Image.Image, path: str) -> None:
    """Write an object's picture unless the one there already holds the
    same pixels: the encoding of a PNG is not stable from one Pillow or
    zlib to the next, and a byte change is a diff nobody can review."""
    if os.path.exists(path):
        with Image.open(path) as old:
            if old.convert("RGBA").tobytes() == sprite.convert(
                    "RGBA").tobytes() and old.size == sprite.size:
                return
    sprite.save(path, optimize=True)


def write(root: str) -> None:
    atlas, built = build()
    os.makedirs(os.path.join(root, TILES), exist_ok=True)
    atlas.image(built["manifest"]["columns"]).save(
        os.path.join(root, ATLAS), optimize=True)
    for place in built["places"].values():
        for obj in place["objects"]:
            image_path = os.path.join(root, place_asset(obj["image"]))
            os.makedirs(os.path.dirname(image_path), exist_ok=True)
            save_object(obj["sprite"], image_path)
            if "openSprite" in obj:
                open_path = os.path.join(root, place_asset(obj["whenOpen"]))
                os.makedirs(os.path.dirname(open_path), exist_ok=True)
                save_object(obj["openSprite"], open_path)
    with open(os.path.join(root, MANIFEST), "w", encoding="utf-8") as out:
        out.write(manifest_json(built["manifest"]))
    print(f"{ATLAS}: {len(atlas.tiles)} tile")
    for name in sorted(built["places"]):
        print(f"  {name}: {len(built['places'][name]['rules'])} regole, "
              f"{len(built['places'][name]['objects'])} oggetti")


# The marker of each converted place's ASCII rows, for --preview only: the
# atlas itself never reads a place.
PREVIEW_ROWS = {
    "barracks": "barracks-rows",
    "church": "church-rows",
    "airlinerCabin": "airliner-cabin-rows",
    "airlinerRoofs": "airliner-roof-rows",
    "barArcobaleno": "bar-rows",
    "barBackroom": "bar-backroom-rows",
    "duomo": "duomo-rows",
    "duomoUpper": "duomo-upper-rows",
    "duomoSecondFloor": "duomo-second-rows",
    "duomoTower": "duomo-tower-rows",
    "duomoBells": "duomo-bells-rows",
    "duomoTowerRoof": "duomo-roof-rows",
    "mallFirst": "mall-first-rows",
    "mallGround": "mall-ground-rows",
    "station": "station-rows",
    "stationFarSide": "far-platform-rows",
    "stationUnderpass": "underpass-rows",
    "terminiConcourse": "termini-concourse-rows",
    "terminiFarPlatform": "termini-far-platform-rows",
    "terminiOverpass": "termini-overpass-rows",
    "trainInterior": "train-interior-rows",
    **city.PREVIEW_ROWS,
    **hospital.PREVIEW_ROWS,
    **terme.PREVIEW_ROWS,
    **palazzo.PREVIEW_ROWS,
    **company.PREVIEW_ROWS,
    **shop.PREVIEW_ROWS,
}


def preview(root: str) -> None:
    from street_paint import read_rows  # noqa: PLC0415 - preview only

    atlas, built = build()
    tiles = atlas.tiles
    for name, marker in sorted(PREVIEW_ROWS.items()):
        rows = read_rows(marker)
        place = built["places"][name]
        for opened in ([False, True] if any("openSprite" in o
                                            for o in place["objects"])
                       else [False]):
            image = compose(rows, place, tiles, opened=opened)
            out = os.path.join(
                root, f"preview_{name}{'_open' if opened else ''}.png")
            image.convert("RGB").save(out)
            print(f"{out}: {image.size[0]}x{image.size[1]}")


def compare(dump: str) -> None:
    """Hold the renderer in lib/game/render to this file's reference draw.
    `dump` holds what the game drew, one <place>.rgba per converted place,
    written by test/levels/tile_place_render_test.dart."""
    from street_paint import read_rows  # noqa: PLC0415 - compare only

    atlas, built = build()
    failures = []
    for name, marker in sorted(PREVIEW_ROWS.items()):
        path = os.path.join(dump, f"{name}.rgba")
        if not os.path.exists(path):
            failures.append(f"{name}: the game drew nothing to {path}")
            continue
        rows = read_rows(marker)
        place = built["places"][name]
        expected = compose(rows, place, atlas.tiles).tobytes()
        with open(path, "rb") as f:
            drawn = f.read()
        if drawn != expected:
            wrong = sum(1 for a, b in zip(drawn[::4], expected[::4])
                        if a != b)
            failures.append(f"{name}: {wrong} pixels differ from the "
                            f"reference draw")
        else:
            print(f"{name}: drawn as the reference draws it")
    if failures:
        raise SystemExit("\n".join(failures))


def check() -> None:
    """The atlas is generated art: re-make it and see that nothing moved,
    the same gate tools/build_levels.py gives the baked backgrounds."""
    with tempfile.TemporaryDirectory() as tmp:
        write(tmp)
        for name in (ATLAS, MANIFEST):
            fresh = os.path.join(tmp, name)
            committed = os.path.join(ROOT, name)
            if not os.path.exists(committed):
                raise SystemExit(f"{name} is missing: run "
                                 f"python tools/build_tile_atlas.py")
            if name.endswith(".png"):
                with Image.open(committed) as a, Image.open(fresh) as b:
                    old, new = a.convert("RGBA"), b.convert("RGBA")
                    same = old.size == new.size and \
                        old.tobytes() == new.tobytes()
                    where = "" if same else (
                        f" (differisce in {ImageChops.difference(old, new).getbbox()})"
                        if old.size == new.size else
                        f" ({old.size} contro {new.size})")
            else:
                with open(committed, encoding="utf-8") as a, \
                        open(fresh, encoding="utf-8") as b:
                    same, where = a.read() == b.read(), ""
            if not same:
                raise SystemExit(
                    f"{name} is out of date{where}.\nRe-run it and commit "
                    f"the result:\n    python tools/build_tile_atlas.py")
            print(f"{name}: up to date")
        made = set()
        for directory, _, filenames in os.walk(os.path.join(tmp, PLACES_DIR)):
            for entry in filenames:
                fresh_path = os.path.join(directory, entry)
                relative = os.path.relpath(fresh_path, tmp)
                made.add(relative)
                committed = os.path.join(ROOT, relative)
                with Image.open(fresh_path) as fresh:
                    new = fresh.convert("RGBA")
                if not os.path.exists(committed):
                    raise SystemExit(f"{relative} is missing")
                with Image.open(committed) as a:
                    if a.convert("RGBA").tobytes() != new.tobytes():
                        raise SystemExit(
                            f"{relative} is out of date.\nRe-run it and "
                            f"commit the result:\n"
                            f"    python tools/build_tile_atlas.py")
                print(f"{relative}: up to date")
        committed_objects = set()
        for directory, _, filenames in os.walk(os.path.join(ROOT, PLACES_DIR)):
            for entry in filenames:
                committed_objects.add(os.path.relpath(
                    os.path.join(directory, entry), ROOT))
        left_over = sorted(committed_objects - made)
        if left_over:
            raise SystemExit(
                f"{PLACES_DIR} holds pictures no painter makes any more: "
                f"{', '.join(left_over)}. Delete them.")
    print("the tile atlas matches its painters")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true",
                        help="do not write anything: fail if the committed "
                             "atlas is not what the painters make today")
    parser.add_argument("--compare", metavar="DIR",
                        help="compare what the game drew into DIR "
                             "(TILE_RENDER_DUMP) with the reference draw")
    parser.add_argument("--preview", metavar="DIR",
                        help="draw the converted places into DIR, the way "
                             "the game will draw them")
    args = parser.parse_args()
    if args.check:
        check()
    elif args.compare:
        compare(args.compare)
    elif args.preview:
        os.makedirs(args.preview, exist_ok=True)
        preview(args.preview)
    else:
        write(ROOT)


if __name__ == "__main__":
    main()
