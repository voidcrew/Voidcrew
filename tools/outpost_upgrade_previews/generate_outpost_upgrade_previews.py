#!/usr/bin/env python3
"""Generate preview assets for the outpost upgrades catalog and the founding catalog.

Renders every voidcrew/_maps/map_files/outposts/outpost_upgrade_*.dmm (one per
room and outpost style), every outpost_ship_bay_*.dmm, and every founder-selectable player_outpost_shell_*.dmm
with the ship preview renderer (tools/ship_previews), including its smoothing
repairs, and writes one PNG and one metadata file per map.

Outputs (commit these):
    voidcrew/modules/player_outposts/previews/<map stem>.png
    voidcrew/modules/player_outposts/previews/<map stem>.preview.json
        {"png": ..., "width": ..., "height": ..., "src_md5": ...}
        width/height are in tiles; src_md5 is the MD5 of the raw .dmm bytes.

Run from the repo root after editing an outpost upgrade or shell map:
    python tools/outpost_upgrade_previews/generate_outpost_upgrade_previews.py

To render only some maps, name them (stem, with or without the outpost_upgrade_
prefix or the .dmm suffix). Stale previews are only retired on a full run:
    python tools/outpost_upgrade_previews/generate_outpost_upgrade_previews.py cargo_dock_clean player_outpost_shell_rundown

dmm-tools location: $DMM_TOOLS or ~/code/tg-tools/bin/dmm-tools.exe
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "ship_previews"))
from generate_ship_previews import Dmm, find_dmm_tools, render, source_md5  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parents[2]
MAPS_DIR = REPO_ROOT / "voidcrew" / "_maps" / "map_files" / "outposts"
OUTPUT_DIR = REPO_ROOT / "voidcrew" / "modules" / "player_outposts" / "previews"
MAP_GLOBS = ("outpost_upgrade_*.dmm", "outpost_ship_bay_*.dmm", "player_outpost_shell_*.dmm")
# Maps founders never see need no picture
SKIPPED: set[str] = set()
# A picture bigger than this is cut to a 256-colour palette: it looks the same and is about a fifth of the size
PALETTE_ABOVE_BYTES = 1_000_000


def map_stem(name: str) -> str:
    stem = name.removesuffix(".dmm")
    if stem.startswith(("outpost_upgrade_", "outpost_ship_bay_", "player_outpost_shell_")):
        return stem
    return f"outpost_upgrade_{stem}"


def shrink(png: Path) -> None:
    if png.stat().st_size <= PALETTE_ABOVE_BYTES:
        return
    from PIL import Image

    with Image.open(png) as image:
        reduced = image.convert("RGBA").quantize(256, method=Image.Quantize.FASTOCTREE)
    reduced.save(png, "PNG", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Render outpost upgrade previews.")
    parser.add_argument("maps", nargs="*", help="only render these maps (default: all)")
    args = parser.parse_args()
    dmm_tools = find_dmm_tools()
    all_maps = sorted(path for pattern in MAP_GLOBS for path in MAPS_DIR.glob(pattern) if path.stem not in SKIPPED)
    if not all_maps:
        sys.exit(f"no {' or '.join(MAP_GLOBS)} found in {MAPS_DIR}")
    maps = all_maps
    if args.maps:
        wanted = {map_stem(name) for name in args.maps}
        maps = [path for path in all_maps if path.stem in wanted]
        missing = wanted - {path.stem for path in maps}
        if missing:
            sys.exit(f"no such outpost map: {', '.join(sorted(missing))}")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    tmp_dir = Path(tempfile.mkdtemp(prefix="outpost_upgrade_previews_"))
    try:
        for dmm_path in maps:
            dmm = Dmm(dmm_path)
            png_name = f"{dmm_path.stem}.png"
            render(dmm_tools, dmm_path, OUTPUT_DIR / png_name, tmp_dir, dmm)
            shrink(OUTPUT_DIR / png_name)
            metadata = {
                "png": png_name,
                "width": dmm.width,
                "height": dmm.height,
                "src_md5": source_md5(dmm_path),
            }
            text = json.dumps(metadata, indent=1, sort_keys=True) + "\n"
            (OUTPUT_DIR / f"{dmm_path.stem}.preview.json").write_bytes(text.encode("utf-8"))
            print(f"{dmm_path.stem}: {dmm.width}x{dmm.height}")
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)

    # Retire previews whose map was deleted or renamed. A partial run cannot tell.
    if args.maps:
        return
    stems = {path.stem for path in all_maps}
    for stale in [path for pattern in MAP_GLOBS for path in OUTPUT_DIR.glob(pattern.replace(".dmm", ".preview.json"))]:
        stem = stale.name.removesuffix(".preview.json")
        if stem not in stems:
            stale.unlink()
            (OUTPUT_DIR / f"{stem}.png").unlink(missing_ok=True)


if __name__ == "__main__":
    main()
