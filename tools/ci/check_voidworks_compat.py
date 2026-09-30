"""Remind PRs that change what Voidworks reads to consider its compatibility version.

Reads the PR's changed file names from standard input. This only warns: most
edits to these files are compatible, and the author decides whether
tools/voidworks/compatibility.json needs a bump (see tools/voidworks/README.md).
"""

import argparse
import sys


DECLARATION = "tools/voidworks/compatibility.json"

# Files that declare the datums, variables and formats the Voidworks
# workshops read and write.
WATCHED = {
    "voidcrew/mapping/shuttles/_shuttle.dm": "ship hull templates",
    "voidcrew/modules/ship_upgrades/_ship_upgrades.dm": "ship upgrade modules and themes",
    "voidcrew/modules/ship_upgrades/modular_map_root_ship.dm": "ship upgrade slot markers",
    "code/modules/mapping/modular_map_loader/modular_map_loader.dm": "module map connectors",
    "voidcrew/mapping/docking_port/_docking_port.dm": "ship docking ports",
    "voidcrew/edits/jobs.dm": "ship crew roles",
    "voidcrew/datums/mapgen/planets/_planet.dm": "planet definitions",
    "voidcrew/datums/mapgen/planet_settings.dm": "planet environment and ruin settings",
    "voidcrew/datums/mapgen/planet_rivers.dm": "planet rivers",
    "voidcrew/datums/mapgen/PlanetGenerator.dm": "the planet generator",
    "voidcrew/datums/mapgen/biomes/_biome.dm": "planet biomes",
    "code/datums/mapgen/biomes/_biome.dm": "planet biomes",
    "code/datums/ruins.dm": "ruin templates",
    "tools/ship_previews/generate_ship_previews.py": "the ship preview generator",
}


def reminders(changed):
    changed = {name.strip().replace("\\", "/") for name in changed if name.strip()}
    if DECLARATION in changed:
        return []
    return [(name, WATCHED[name]) for name in sorted(changed) if name in WATCHED]


def main(argv=None, stdin=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--github", action="store_true")
    args = parser.parse_args(argv)
    found = reminders((stdin or sys.stdin).read().splitlines())
    for name, what in found:
        message = (f"This file defines {what}, which the Voidworks editor reads and writes. If this PR renames, "
                   f"removes or changes the format of something Voidworks edits, raise voidworks_api in "
                   f"{DECLARATION} (see tools/voidworks/README.md). Otherwise, ignore this.")
        print((f"::warning file={name}::" if args.github else f"{name}: ") + message)
    if not found:
        print("No Voidworks-facing files changed without a compatibility update.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
