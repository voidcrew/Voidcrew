"""The tracked ratings, one file per gear category, and the commands that keep them in step with the catalog. All validation lives here.

tools/gear_catalog/ratings/<category>.json:
    category  the gear category
    method    one or two sentences on how this category is judged
    groups    the peer groups, in reading order
    items     path -> name, group, tier (green, yellow, red, above or none), rank within the group, reason, confidence (high, medium, low), hash
              (the catalog's facts_hash when rated; empty means not stamped yet), and optionally score, score_inputs (see scoring.py), note (what the
              numbers can't show) and locked (true: the owner ruled on this tier, and merge won't change it)
    unrated   path -> why it has no rating. sync owns the mechanical words; the others are a rater's and stay until a rater changes them

locked is set by hand in the file. merge ignores it in a rater's output.
"""
from __future__ import annotations

import json
from pathlib import Path

from .build import obtainable
from .categories import GEAR_CATEGORIES, REP_ORDER, category_of
from .notes import note_rows, rating_note
from .scoring import SCORE_INPUTS, score_gun
from .sheets import left_out_reason

RATINGS_FOLDER = 'tools/gear_catalog/ratings'
POLICY_FILE = 'tools/gear_catalog/policy.json'
EXCEPTIONS_FILE = 'tools/gear_catalog/exceptions.json'

TIERS = ('green', 'yellow', 'red', 'above', 'none')
CONFIDENCE = ('high', 'medium', 'low')
MECHANICAL_WORDS = ('abstract', 'cosmetic', 'uncreatable', 'no route', 'literal only')
RATER_WORDS = ('toy', 'admin', 'leftover', 'needs another system')
ROUTE_KINDS = ('shops', 'cargo', 'order_consoles', 'other_sellers', 'printing', 'crafting', 'made_by_use')
RULES = ('unrated', 'below_reputation', 'above_on_route', 'price_out_of_band')

REQUIRED_ITEM_FIELDS = ('name', 'group', 'tier', 'rank', 'reason', 'confidence', 'hash')
OPTIONAL_ITEM_FIELDS = ('score', 'score_inputs', 'note', 'locked')
RATER_FILE_FIELDS = ('category', 'method', 'groups', 'items', 'unrated')


def is_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def is_text(value):
    return isinstance(value, str) and bool(value.strip())


# ---------------------------------------------------------------------------------------- validation

def score_input_problems(path, inputs):
    if not isinstance(inputs, dict):
        return [f'{path}: score_inputs must be an object']
    problems = []
    for name, value in inputs.items():
        where = f'{path}: score_inputs.{name}'
        if name not in SCORE_INPUTS:
            problems.append(f'{where} is not one of {", ".join(SCORE_INPUTS)}')
            continue
        if not isinstance(value, dict) or not is_text(value.get('why')):
            problems.append(f'{where} needs an object with a why')
            continue
        if name == 'extra_mode':
            if not is_text(value.get('label')):
                problems.append(f'{where} needs a label')
            wanted = ('armorless_stamina', 'rate') if 'armorless_stamina' in value else ('damage',)
            problems += [f'{where}.{field} must be a number' for field in wanted if not is_number(value.get(field))]
        elif name == 'rate':
            if value.get('listed') is not True and not is_number(value.get('value')):
                problems.append(f'{where} needs a number in value, or listed: true')
        elif name == 'cell_fed':
            if value.get('value') is not False:
                problems.append(f'{where}.value can only be false')
        elif not is_number(value.get('value')):
            problems.append(f'{where}.value must be a number')
    return problems


def item_problems(path, item, groups):
    if not isinstance(item, dict):
        return [f'{path}: a rating must be an object']
    problems = [f'{path}: missing {field}' for field in REQUIRED_ITEM_FIELDS if field not in item]
    problems += [f'{path}: unknown field {field}' for field in sorted(set(item) - set(REQUIRED_ITEM_FIELDS) - set(OPTIONAL_ITEM_FIELDS))]
    if 'name' in item and not is_text(item['name']):
        problems.append(f'{path}: name must be text')
    if 'group' in item and item['group'] not in groups:
        problems.append(f'{path}: group {item["group"]!r} is not in the file\'s groups')
    if 'tier' in item and item['tier'] not in TIERS:
        problems.append(f'{path}: tier must be one of {", ".join(TIERS)}')
    if 'rank' in item and (not isinstance(item['rank'], int) or isinstance(item['rank'], bool) or item['rank'] < 1):
        problems.append(f'{path}: rank must be a whole number from 1')
    if 'reason' in item and not is_text(item['reason']):
        problems.append(f'{path}: reason must be text')
    if 'confidence' in item and item['confidence'] not in CONFIDENCE:
        problems.append(f'{path}: confidence must be one of {", ".join(CONFIDENCE)}')
    if 'hash' in item and not isinstance(item['hash'], str):
        problems.append(f'{path}: hash must be text')
    if 'score' in item and not is_number(item['score']):
        problems.append(f'{path}: score must be a number')
    if 'score_inputs' in item:
        problems += score_input_problems(path, item['score_inputs'])
    if 'note' in item and not is_text(item['note']):
        problems.append(f'{path}: note must be text')
    if 'locked' in item and item['locked'] is not True:
        problems.append(f'{path}: locked can only be true')
    return problems


def ratings_problems(doc, category=None):
    """Everything wrong with one ratings file, as sentences. An empty list means it's good."""
    if not isinstance(doc, dict):
        return ['a ratings file must be an object']
    problems = [f'missing {field}' for field in ('category', 'method', 'groups', 'items', 'unrated') if field not in doc]
    problems += [f'unknown field {field}' for field in sorted(set(doc) - {'category', 'method', 'groups', 'items', 'unrated'})]
    if problems:
        return problems
    name = doc['category']
    if name not in GEAR_CATEGORIES:
        problems.append(f'{name!r} is not a gear category')
    if category and name != category:
        problems.append(f'category is {name!r}, expected {category!r}')
    groups = doc['groups']
    if not isinstance(groups, list) or not all(is_text(group) for group in groups) or len(set(groups)) != len(groups):
        problems.append('groups must be a list of different names')
        groups = []
    items, unrated = doc['items'], doc['unrated']
    if not isinstance(items, dict) or not isinstance(unrated, dict):
        return problems + ['items and unrated must be objects']
    if items and not is_text(doc['method']):
        problems.append('method must say how this category is judged')
    for path, item in items.items():
        problems += item_problems(path, item, groups)
    for path, word in unrated.items():
        if word not in MECHANICAL_WORDS and word not in RATER_WORDS:
            problems.append(f'{path}: {word!r} is not one of {", ".join(MECHANICAL_WORDS + RATER_WORDS)}')
    for path in [*items, *unrated]:
        if category_of(path)[0] != name:
            problems.append(f'{path} belongs in {category_of(path)[0]}, not {name}')
    problems += [f'{path} is in both items and unrated' for path in sorted(set(items) & set(unrated))]
    return problems


def policy_problems(policy):
    if not isinstance(policy, dict):
        return ['the policy must be an object']
    problems = [f'missing {field}' for field in ('min_reputation', 'checked_routes', 'price_bands') if field not in policy]
    if problems:
        return problems
    for tier, step in policy['min_reputation'].items():
        if tier not in TIERS or step not in REP_ORDER:
            problems.append(f'min_reputation: {tier!r} and {step!r} must be a tier and one of {", ".join(REP_ORDER)}')
    problems += [f'checked_routes: {kind!r} is not one of {", ".join(ROUTE_KINDS)}' for kind in policy['checked_routes'] if kind not in ROUTE_KINDS]
    for category, bands in policy['price_bands'].items():
        if category not in GEAR_CATEGORIES:
            problems.append(f'price_bands: {category!r} is not a gear category')
        for tier, band in bands.items():
            if tier not in TIERS or not isinstance(band, list) or len(band) != 2 or not all(is_number(value) for value in band) or band[0] > band[1]:
                problems.append(f'price_bands.{category}.{tier}: needs a tier and [low, high]')
    ordinary = policy.get('ordinary_ingredients', [])
    if not isinstance(ordinary, list):
        return problems + ['ordinary_ingredients must be a list']
    for row in ordinary:
        if not isinstance(row, dict) or set(row) != {'path', 'reason'} or not is_text(row['reason']) or not str(row['path']).startswith('/obj/'):
            problems.append(f'ordinary_ingredients: {row!r} needs exactly a path under /obj/ and a reason')
    return problems


def exception_problems(rows):
    if not isinstance(rows, list):
        return ['the exceptions file must be a list']
    problems = []
    for index, row in enumerate(rows):
        if not isinstance(row, dict) or set(row) != {'path', 'rule', 'route', 'reason'}:
            problems.append(f'entry {index + 1}: needs exactly path, rule, route and reason')
            continue
        if row['rule'] not in RULES:
            problems.append(f'{row["path"]}: rule {row["rule"]!r} is not one of {", ".join(RULES)}')
        if not is_text(row['reason']):
            problems.append(f'{row["path"]}: an exception needs a reason')
        if not is_text(row['route']):
            problems.append(f'{row["path"]}: an exception needs the route it excuses: the SKU, pack, design or recipe type')
    return problems


# ---------------------------------------------------------------------------------------- files

def ratings_path(root, category):
    return Path(root) / RATINGS_FOLDER / f'{category}.json'


def rating_text(doc):
    return json.dumps(doc, ensure_ascii=False, sort_keys=True, indent=1) + '\n'


def new_doc(category):
    return dict(category=category, method='', groups=[], items={}, unrated={})


def load_doc(root, category):
    """One ratings file, or None if the category has none."""
    path = ratings_path(root, category)
    return json.loads(path.read_text(encoding='utf-8')) if path.exists() else None


def load_docs(root):
    """Every ratings file as category -> doc, and what's wrong with them as (file, sentence). A file that won't parse gives a problem and no doc."""
    docs, problems = {}, []
    for path in sorted((Path(root) / RATINGS_FOLDER).glob('*.json')):
        relative = f'{RATINGS_FOLDER}/{path.name}'
        try:
            doc = json.loads(path.read_text(encoding='utf-8'))
        except ValueError as error:
            problems.append((relative, f'not valid JSON: {error}'))
            continue
        found = ratings_problems(doc, path.stem)
        problems += [(relative, sentence) for sentence in found]
        if not found:
            docs[path.stem] = doc
    return docs, problems


def write_doc(root, doc):
    """Write if something changed. Always LF: the file is compared byte for byte in review."""
    found = ratings_problems(doc)
    if found:
        raise ValueError(found)
    path = ratings_path(root, doc['category'])
    text = rating_text(doc)
    if path.exists() and path.read_text(encoding='utf-8') == text:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding='utf-8', newline='\n')
    return True


def read_category(out, category):
    """The catalog's rows for one category: path -> entry."""
    path = Path(out) / 'items' / f'{category}.json'
    return json.loads(path.read_text(encoding='utf-8'))['items'] if path.exists() else {}


def require_catalog(out):
    if not (Path(out) / 'items').is_dir():
        raise SystemExit(f'No catalog in {out}. Run python -m tools.gear_catalog build first.')


def gear_categories(out):
    return sorted(file.stem for file in (Path(out) / 'items').glob('*.json') if file.stem in GEAR_CATEGORIES)


def word_from_catalog(entry):
    """Why the catalog says a path has no rating to give, or None when it's real obtainable gear. A type that deletes itself on creation is uncreatable as an item."""
    reason = left_out_reason(entry)
    if reason is None:
        return None
    return reason if reason in MECHANICAL_WORDS else 'uncreatable'


# ---------------------------------------------------------------------------------------- stale

def stale(root, out, category=None):
    """What the catalog and the ratings disagree on: {'new': [...], 'changed': [...], 'removed': [...]}."""
    require_catalog(out)
    docs, problems = load_docs(root)
    if problems:
        raise SystemExit('\n'.join(f'{file}: {sentence}' for file, sentence in problems))
    found = dict(new=[], changed=[], removed=[])
    for name in sorted(set(gear_categories(out)) | set(docs)):
        if category and name != category:
            continue
        rows = read_category(out, name)
        doc = docs.get(name) or new_doc(name)
        items, unrated = doc['items'], doc['unrated']
        for path, entry in sorted(rows.items()):
            if path in items:
                if items[path]['hash'] != entry['facts_hash']:
                    found['changed'].append(dict(path=path, category=name, name=entry.get('name'), tier=items[path]['tier'], rated_hash=items[path]['hash'], catalog_hash=entry['facts_hash']))
            # A mechanical word only says what the catalog said then: a path that's now real gear is new, even before sync clears the word.
            elif entry.get('gear') and obtainable(entry) and not entry.get('cosmetic') and (path not in unrated or unrated[path] in MECHANICAL_WORDS):
                found['new'].append(dict(path=path, category=name, name=entry.get('name')))
        for where, paths in (('items', items), ('unrated', unrated)):
            found['removed'] += [dict(path=path, category=name, where=where) for path in sorted(paths) if path not in rows]
    return found


# ---------------------------------------------------------------------------------------- sync

def sync(root, out):
    """Fill unrated from the catalog for every path in a gear category with no rating. A rater's word stays. Returns category -> (words now in the file, whether it changed)."""
    require_catalog(out)
    docs, problems = load_docs(root)
    if problems:
        raise SystemExit('\n'.join(f'{file}: {sentence}' for file, sentence in problems))
    report = {}
    for name in gear_categories(out):
        doc = docs.get(name) or new_doc(name)
        for path, entry in read_category(out, name).items():
            word = doc['unrated'].get(path)
            if path in doc['items'] or (word is not None and word not in MECHANICAL_WORDS):
                continue
            fresh = word_from_catalog(entry)
            if fresh:
                doc['unrated'][path] = fresh
            else:
                doc['unrated'].pop(path, None)
        if doc['unrated'] or doc['items'] or name in docs:
            report[name] = (len(doc['unrated']), write_doc(root, doc))
    return report


# ---------------------------------------------------------------------------------------- merge

def rater_file_problems(data):
    if not isinstance(data, dict):
        return ['a rater file must be an object']
    problems = [f'unknown field {field}' for field in sorted(set(data) - set(RATER_FILE_FIELDS))]
    if not isinstance(data.get('items', {}), dict) or not isinstance(data.get('unrated', {}), dict):
        problems.append('items and unrated must be objects')
    if not isinstance(data.get('groups', []), list):
        problems.append('groups must be a list')
    return problems


def merge(root, out, source, category=None):
    """Apply a rater's output to one ratings file. Returns (written, refused, dropped_locks, problems): nothing is written when there are problems.

    Partial files add to or replace only the named paths. An owner's ruling stands: a rater's change to a locked item's tier, or its word for one, is refused and listed.
    """
    require_catalog(out)
    data = json.loads(Path(source).read_text(encoding='utf-8'))
    problems = rater_file_problems(data)
    if problems:
        return [], [], [], problems
    named = data.get('category')
    if named and category and named != category:
        return [], [], [], [f'the file says {named} but --category says {category}']
    name = named or category
    if not name:
        return [], [], [], ['the file names no category: add one, or pass --category']
    if name not in GEAR_CATEGORIES:
        return [], [], [], [f'{name!r} is not a gear category']
    doc = load_doc(root, name) or new_doc(name)
    problems = ratings_problems(doc, name)
    if problems:
        return [], [], [], [f'{RATINGS_FOLDER}/{name}.json: {sentence}' for sentence in problems]
    rows = read_category(out, name)
    notes = note_rows(out)
    written, refused, dropped_locks = [], [], []
    if is_text(data.get('method')):
        doc['method'] = data['method']
    doc['groups'] += [group for group in data.get('groups') or [] if group not in doc['groups']]

    for path, given in sorted((data.get('items') or {}).items()):
        if path not in rows:
            problems.append(f'{path} is not in the {name} catalog')
            continue
        if not isinstance(given, dict):
            problems.append(f'{path}: a rating must be an object')
            continue
        entry = rows[path]
        item = dict(given)
        old = doc['items'].get(path) or {}
        if item.pop('locked', None) is not None:
            dropped_locks.append(path)
        if old.get('locked'):
            if item.get('tier') != old['tier']:
                refused.append(f'{path} is locked at {old["tier"]}; the rating stays as it is')
                continue
            item['locked'] = True
        item['hash'] = entry['facts_hash']
        if not item.get('name'):
            item['name'] = entry.get('name')
        note = rating_note(path, entry.get('note_owners'), notes)
        if note:
            item['note'] = note
        if name == 'guns' and 'score' not in item and item.get('tier') not in ('above', 'none'):
            scored = score_gun(entry, item.get('score_inputs') if isinstance(item.get('score_inputs'), dict) else None)
            if scored:
                item['score'] = round(scored['score'])
        doc['items'][path] = item
        doc['unrated'].pop(path, None)
        written.append(path)

    for path, word in sorted((data.get('unrated') or {}).items()):
        if path not in rows:
            problems.append(f'{path} is not in the {name} catalog')
            continue
        if (doc['items'].get(path) or {}).get('locked'):
            refused.append(f'{path} is locked at {doc["items"][path]["tier"]}; it stays rated')
            continue
        doc['items'].pop(path, None)
        doc['unrated'][path] = word
        written.append(path)

    problems += ratings_problems(doc, name)
    if problems:
        return [], refused, dropped_locks, problems
    write_doc(root, doc)
    return written, refused, dropped_locks, []
