"""Written notes on what items do beyond their numbers, and the batches of owner types that still need one.

A note is a row of {"path": owner, "note": ..., "effect": "special|plumbing|unknown", "refs": [...]} in notes/*.jsonl under the output folder, where path
is the item or the type that owns the behaviour. Batches are notes/batch-<N>.json: work lists, not notes, so reading notes skips them.
"""
from __future__ import annotations

import fnmatch
import json
from pathlib import Path

from .build import write_json

BATCH_PATTERN = 'batch-*.json'
EXAMPLE_ITEMS = 5


def note_rows(out):
    """Path to its row, from every note file under notes/. Later files win, in name order, so a fix can be dropped in beside a batch."""
    rows_by_path = {}
    folder = Path(out) / 'notes'
    if not folder.exists():
        return rows_by_path
    for file in sorted(folder.rglob('*.json*')):
        if fnmatch.fnmatch(file.name, BATCH_PATTERN):
            continue
        try:
            text = file.read_text(encoding='utf-8')
            rows = json.loads(text) if file.suffix == '.json' else [json.loads(line) for line in text.splitlines() if line.strip()]
        except (OSError, ValueError):  # someone may be writing it right now; its rows count next time
            continue
        if isinstance(rows, dict):
            rows = rows.get('notes') or rows.get('items') or []
        for row in rows:
            if isinstance(row, dict) and row.get('path') and row.get('note'):
                rows_by_path[row['path']] = row
    return rows_by_path


def load_notes(out):
    """Path to note text."""
    return {path: row['note'] for path, row in note_rows(out).items()}


def rating_note(path, owners, rows_by_path):
    """The note a rating carries: its own and its owners', without any that only describe plumbing."""
    found = []
    for owner in [path] + list(owners or []):
        row = rows_by_path.get(owner)
        if row and row.get('effect') != 'plumbing' and row['note'] not in found:
            found.append(row['note'])
    return ' / '.join(found)


def read_items(out):
    """Every item row from items/<category>.json, as path to (category, entry)."""
    entries = {}
    for file in sorted((Path(out) / 'items').glob('*.json')):
        for path, entry in json.loads(file.read_text(encoding='utf-8'))['items'].items():
            entries[path] = (file.stem, entry)
    return entries


def owner_entries(out):
    """One entry per owner type in the summary's note rule, grouped by the first category that needs it, each with the items that lean on it."""
    summary = json.loads((Path(out) / 'summary.json').read_text(encoding='utf-8'))['note_rule']
    entries = read_items(out)
    found = {}
    for category in sorted(summary['by_category']):
        for path in sorted(summary['by_category'][category]):
            _, entry = entries[path]
            for owner in entry.get('note_owners') or []:
                row = found.setdefault(owner, dict(path=owner, category=category, name=None, desc=None, procs=set(), parts=[], items=[]))
                row['items'].append(dict(path=path, name=entry.get('name')))
                for text in (entry.get('behaviour_procs') or []) + (entry.get('chain_behaviour_procs') or []):
                    if text.rsplit('/', 1)[0] == owner:
                        row['procs'].add(text.rsplit('/', 1)[1])
    for owner, row in found.items():
        entry = entries.get(owner, (None, {}))[1]
        row.update(name=entry.get('name'), desc=entry.get('desc'), procs=sorted(row['procs']), parts=entry.get('behaviour_parts') or [])
    return sorted(found.values(), key=lambda row: (row['category'], row['path']))


def has_note(row, written):
    """An owner is done when it has a note, or when every item leaning on it has one of its own."""
    return row['path'] in written or all(item['path'] in written for item in row['items'])


def write_batches(out, batch_size=40):
    """Write notes/batch-<N>.json for every owner type with no note yet, replacing older batches. Returns (batches, owners)."""
    written = note_rows(out)
    rows = [row for row in owner_entries(out) if not has_note(row, written)]
    for row in rows:
        row['items'] = row['items'][:EXAMPLE_ITEMS]
    folder = Path(out) / 'notes'
    folder.mkdir(parents=True, exist_ok=True)
    for old in folder.glob(BATCH_PATTERN):
        old.unlink()
    batches = [rows[start:start + batch_size] for start in range(0, len(rows), batch_size)]
    for number, batch in enumerate(batches, 1):
        write_json(folder / f'batch-{number}.json', batch)
    return len(batches), len(rows)
