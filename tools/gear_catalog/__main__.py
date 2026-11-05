"""Command line for the item catalog. Run it from the repository root: python -m tools.gear_catalog --help"""
from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def parser():
    ap = argparse.ArgumentParser(
        prog='python -m tools.gear_catalog',
        description='Facts about every item type: what it does, what it costs and how players get it. Nothing generated is tracked.',
    )
    ap.add_argument('--root', type=Path, default=ROOT, help='the checkout to read (default: this one)')
    ap.add_argument('--out', type=Path, default=None, help='where everything goes (default: data/gear_catalog under the checkout)')
    # --out works before or after the command.
    shared = argparse.ArgumentParser(add_help=False)
    shared.add_argument('--out', type=Path, default=argparse.SUPPRESS, help='where everything goes (default: data/gear_catalog under the checkout)')
    commands = ap.add_subparsers(dest='command', required=True)

    dump = commands.add_parser('dump', parents=[shared], help='compile the dump and run it in a private world, about 6 minutes. Windows only (junctions)',
                               description='Compile the item dump and run it in one private test world. Windows only: the world is staged with junctions. '
                                           'Finds dm.exe and dd.exe from BYOND_PATH, then PATH, then the standard install folder. Refuses reserved ports and any port in use.')
    dump.add_argument('--port', type=int, default=3311)
    dump.add_argument('--world', type=Path, default=None, help='private world folder (default: beside the checkout)')
    dump.add_argument('--keep', action='store_true', help='leave the world folder in place afterwards')
    dump.add_argument('--clean', action='store_true', help='only remove a leftover world folder')
    dump.add_argument('--boot-minutes', type=int, default=30)
    dump.add_argument('--dump-minutes', type=int, default=90)

    build = commands.add_parser('build', parents=[shared], help='rebuild the facts from the dump plus the source. Runs anywhere',
                                description='Rebuild the catalog from an existing dump and the source. No timestamps and sorted output: the same input gives the same bytes. '
                                            'Only rerun dump when item stats change; prices, maps, research, loot and crafting come from source.')
    build.add_argument('--dump', type=Path, default=None, help='dump file to read (default: dump/dump.jsonl under the output folder)')

    sheet = commands.add_parser('sheet', parents=[shared], help='write a compact table of one category for a reader',
                                description='One row per obtainable, non-abstract, non-cosmetic item, similar items together, then a short list of what was left out and why. '
                                            'Notes come from any .json or .jsonl file under notes/ in the output folder, with rows of {"path": ..., "note": ...}.')
    sheet.add_argument('category', help='a category name, or "all"')
    return ap


def main(argv=None):
    args = parser().parse_args(argv)
    root = args.root.resolve()
    out = (args.out or root / 'data' / 'gear_catalog').resolve()
    started = time.time()

    if args.command == 'dump':
        from . import world
        if args.clean:
            world.clean(args.world.resolve() if args.world else world.default_world(root))
            return 0
        return world.dump(root, out, port=args.port, world=args.world, keep=args.keep, boot_minutes=args.boot_minutes, dump_minutes=args.dump_minutes)

    if args.command == 'build':
        from .build import build
        report = build(root, out, args.dump or out / 'dump' / 'dump.jsonl')
        print(f"{report['total']} items, {report['note_rule']['selected']} need a note from {report['note_rule']['distinct_owner_types']} owner types, "
              f"{time.time() - started:.0f}s. catalog {report['catalog_sha256'][:16]}")
        return 0

    from .sheets import write_sheet, known_categories
    categories = known_categories(out) if args.category == 'all' else [args.category]
    for category in categories:
        path = write_sheet(out, category)
        print(f'{path}: {path.stat().st_size} bytes')
    return 0


if __name__ == '__main__':
    sys.exit(main())
