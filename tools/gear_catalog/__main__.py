"""Command line for the item catalog. Run it from the repository root: python -m tools.gear_catalog --help"""
from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def parser():
    ap = argparse.ArgumentParser(
        prog='python -m tools.gear_catalog',
        description='Facts about every item type: what it does, what it costs and how players get it, and the tracked ratings on top of them. Nothing generated is tracked.',
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
                                            'A category with a known upgrade, like the MOD fitting bench or armor plates, has a line for it at the top. '
                                            'Guns also show their power score, using the score_inputs in their rating. Notes come from any .json or .jsonl file under notes/ in the '
                                            'output folder, with rows of {"path": ..., "note": ...}; batch-*.json files are work lists and are skipped.')
    sheet.add_argument('category', help='a category name, or "all"')

    notes = commands.add_parser('notes', parents=[shared], help='write the work lists of owner types that still need a note',
                                description='Writes notes/batch-<N>.json from the note rule in summary.json, replacing older batches: one entry per owner type with no note yet, grouped by '
                                            'category, each with path, category, name, desc, procs, parts and up to five example items. An owner is done when it has a note, or every item '
                                            'leaning on it has its own. Write notes as rows of {"path": owner, "note": ..., "effect": "special|plumbing|unknown", "refs": [...]} in notes/*.jsonl.')
    notes.add_argument('--batch-size', type=int, default=40)

    stale = commands.add_parser('stale', parents=[shared], help='list where the catalog and the ratings disagree',
                                description='Three lists. new: gear that players can get, not abstract or cosmetic, in neither items nor unrated. changed: rated, and the rating\'s hash differs '
                                            'from the catalog\'s facts_hash. removed: a path in the ratings no longer in the catalog.')
    stale.add_argument('--category', default=None, help='one category instead of all of them')
    stale.add_argument('--json', action='store_true', help='print the three lists as JSON')

    merge = commands.add_parser('merge', parents=[shared], help='apply a rater\'s output to a ratings file',
                                description='The file is {"category", "method", "groups", "items": {path: {name, group, tier, rank, reason, confidence, score_inputs}}, "unrated": {path: why}}. '
                                            'It may be partial: it adds to or replaces only the named paths. Each hash comes from the catalog, each note from notes/ where one exists (not plumbing), '
                                            'and a gun\'s score from scoring.py unless the file gives one. A change to the tier of a locked item is refused and printed; the rest still merges.')
    merge.add_argument('file', type=Path)
    merge.add_argument('--category', default=None, help='for a file that names no category')

    commands.add_parser('sync', parents=[shared], help='fill in why paths in gear categories have no rating',
                        description='Gives every path in a gear category with no rating its mechanical reason from the catalog: abstract, cosmetic, uncreatable, no route or literal only. '
                                    'Clears a mechanical word that no longer holds. A rater\'s word stays.')
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

    if args.command == 'notes':
        from .notes import write_batches
        batches, owners = write_batches(out, args.batch_size)
        print(f'{batches} batches, {owners} owners')
        return 0

    if args.command == 'stale':
        from .ratings import stale
        found = stale(root, out, args.category)
        if args.json:
            print(json.dumps(found, ensure_ascii=False, sort_keys=True, indent=1))
            return 0
        for name, rows in found.items():
            print(f'{name}: {len(rows)}')
            for row in rows:
                print(f"  {row['path']} ({row['category']})" + (f" {row['name']}" if row.get('name') else ''))
        return 0

    if args.command == 'merge':
        from .ratings import merge
        written, refused, dropped_locks, problems = merge(root, out, args.file, args.category)
        for line in refused:
            print(f'refused: {line}')
        for path in dropped_locks:
            print(f'ignored: {path}: only the owner locks a rating, by hand in the file')
        for line in problems:
            print(f'problem: {line}')
        if problems:
            print('Nothing written.')
            return 1
        print(f'{len(written)} merged, {len(refused)} refused.')
        return 0

    if args.command == 'sync':
        from .ratings import sync
        report = sync(root, out)
        for name, (words, changed) in sorted(report.items()):
            print(f"{name}: {words} unrated{' (changed)' if changed else ''}")
        return 0

    from .ratings import load_doc
    from .sheets import write_sheet, known_categories
    categories = known_categories(out) if args.category == 'all' else [args.category]
    for category in categories:
        path = write_sheet(out, category, load_doc(root, category))
        print(f'{path}: {path.stat().st_size} bytes')
    return 0


if __name__ == '__main__':
    sys.exit(main())
