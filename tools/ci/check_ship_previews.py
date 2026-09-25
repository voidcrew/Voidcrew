"""Reject purchase previews rendered from an older version of their map.

The purchase screen shows committed PNGs, so a hull or module map edit stays
invisible there until its preview is regenerated. The generator records each
source map's MD5 as `src_md5`; this compares it with the map on disk, like
/datum/unit_test/voidcrew_ship_previews, but runs in CI without a server.
"""

import argparse
import hashlib
import json
from pathlib import Path


HULLS = Path("_maps/voidcrew/ships")
MODULES = Path("_maps/voidcrew/ship_modules")
PREVIEWS = Path("voidcrew/modules/ship_upgrades/previews")
HOW_TO_FIX = ("Regenerate it: in Voidworks use Help > Ship Purchase Previews > Refresh outdated previews, "
              "or run tools/ship_previews/generate_ship_previews.py. Commit the PNG and .preview.json with the map.")


def metadata(root):
    """Yield (metadata file, group, key, entry) for every hull and module entry."""
    output = root / PREVIEWS
    files = sorted(output.glob("hulls/**/*.preview.json")) + sorted(output.glob("modules/**/*.preview.json"))
    files += sorted(output.glob("*.preview.json"))
    if (output / "manifest.json").is_file():
        files.append(output / "manifest.json")
    for path in files:
        document = json.loads(path.read_text(encoding="utf-8"))
        for group in ("hulls", "modules"):
            for key, entry in (document.get(group) or {}).items():
                yield path, group, key, entry


def images(group, key, entry):
    """Yield (entry, source map) pairs, following the generator's naming."""
    if group == "hulls":
        yield entry, HULLS / f"ship_{key}.dmm"
        return
    base = MODULES / key
    yield entry, base
    for theme, variant in (entry.get("themes") or {}).items():
        yield variant, base.with_name(f"{base.stem}_{theme}.dmm")


def source_hashes(path):
    data = path.read_bytes()
    # rustg hashes raw bytes; also accept a Windows checkout of the same map.
    return {hashlib.md5(data).hexdigest(), hashlib.md5(data.replace(b"\r\n", b"\n")).hexdigest()}


def check_previews(root):
    problems = []
    for path, group, key, entry in metadata(root):
        for image, source in images(group, key, entry):
            if not isinstance(image, dict) or not image.get("png"):
                continue
            if not (root / source).is_file():
                continue  # check_ship_assets owns missing and orphaned maps.
            baked = image.get("src_md5")
            if not baked:
                problems.append((path.relative_to(root), f"Preview {image['png']} has no src_md5, so nothing can tell "
                                                         f"whether it matches {source.as_posix()}. {HOW_TO_FIX}"))
            elif baked not in source_hashes(root / source):
                problems.append((source, f"Preview {image['png']} was rendered from an older version of "
                                         f"{source.as_posix()}. {HOW_TO_FIX}"))
    return problems


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--github", action="store_true")
    args = parser.parse_args(argv)
    try:
        problems = check_previews(args.root)
    except (OSError, ValueError) as error:
        print(f"{'::error::' if args.github else ''}Cannot check ship previews: {error}")
        return 1
    for path, message in problems:
        prefix = f"::error file={path.as_posix()}::" if args.github else f"{path.as_posix()}: "
        print(prefix + message)
    if problems:
        print(f"{len(problems)} ship purchase previews are out of date.")
        return 1
    print("Ship purchase previews match their maps.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
