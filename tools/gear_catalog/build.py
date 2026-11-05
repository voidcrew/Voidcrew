"""Rebuild the catalog from a dump and the source. No timestamps, sorted output: same input, same bytes.

Writes to the output folder (default data/gear_catalog under the checkout):
    catalog.jsonl         one row per item type: facts, sources, category, cosmetic flag, facts_hash
    items/<category>.json the rows a reader wants per category: stats, availability, note selection
    overrides.json        for each item, the procs its type and parents define below the category base
    summary.json          counts per category, the note rule's selection, a hash of the catalog

catalog.jsonl fields: path, parent, name, desc, category, gear, status, abstract, has_subtypes, cosmetic, cosmetic_blockers, facts, sources,
known_sources, firm_sources, overrides, facts_hash. status is ok, uncreatable (never built, no facts), self_deleted (a spawner or a part that
needs a parent; facts.spawned says what it left) or error (a runtime during creation).

A map's kind says whether it can appear in a round. hull is a hull players can buy or roll, npc_ship a pirate or patrol hull, hull_unused a fixed hull only an admin can
spawn; only the kinds in PLACED_KINDS are routes. sources.starting is what a crew finds on its own ship: outfits, loadout, and vendors and lockers on hull and module maps.
A vendor elsewhere is in field_vendors, an outfit only used by unused hulls in unused_outfits. A printing row's unlock is roundstart, hacked autolathe, research,
hidden research (only nodes that points can't open), design disk, or no active research node. A crafting row's machinery and structures are what it's made beside, and uses_up the
ones it eats. A made_by_use row is read from a `new` in a use proc, so it names the item used and no other part a step asks for.

Stats in facts come from a real instance, so inheritance and Initialize() are already applied, but a fresh item is all the dump sees: fantasy
prefixes, modkits, MOD upgrades and fire select still move numbers at runtime. Spawn rates, literal loot odds, corpse outfits and paths chosen by
pick(subtypesof()) aren't in static data; literal rows carry a citation and no odds, and a path only named in code is a code_mention, never a route.
A static scan can say which organ surgeries reach a zone, not whether a crew has the tools or a surgeon.
"""
from __future__ import annotations

import collections
import hashlib
import json
import re
from pathlib import Path

from .categories import (CATEGORIES, REP_ORDER, CHAIN_BASES, CHAIN_SETUP_PROCS, FAMILY_BASES, FIGHT_ONLY_CATEGORIES, FIGHT_PROCS, GEAR_CATEGORIES, ITEM, LOOK_CLOTHING_FLAGS, LOOK_INV_FLAGS, LOOK_ONLY_FAMILIES, LOOK_PARTS,
                         LOOK_VARS, MELEE_FORCE_MIN, NO_NOTE_FAMILIES, NUMBER_PARTS, PLACED_KINDS, PLUMBING_PROCS, PRESENTATION_VARS, SETUP_PROCS, SHAPE_BASES, UNARMORED_WORN_VARS, USED_CATEGORIES, WORN_CATEGORIES,
                         category_of, is_gear)
from .combat import ARMOR_MAX_BLOCK, ARMOR_WEAKENED_MULTIPLIER, CLICK_CD_MELEE, MELEE_FORMULAS, num
from .dm_reader import Expr, assoc, balance, clean_comments, enclosing_lines, proc_chain
from .recipes import covering_types, fixture_needs, is_basic_material, is_ordinary, item_needs, recipe_step, settle, use_recipe
from .sections import FORMULAS, category_stats, decode_flags

ARMOR_VEST = '/obj/item/clothing/suit/armor/vest'
ARMOR_RATINGS = ['melee', 'bullet', 'laser', 'energy', 'bomb', 'bio', 'fire', 'acid', 'wound', 'consume']
FIGHT_ARMOR = ['melee', 'bullet', 'laser', 'energy', 'bomb']

# Values that read the world clock or a timer id. Two dumps of one checkout differ only in these.
CLOCK_VARS = {'breeding_wait', 'last_feeding', 'decay_timer', 'restock_timer'}
CLOCK_COMPONENT_VARS = {'timer_id', 'last_move', 'expires_at'}
# Sections of a dump row that land in the catalog's facts.
FACT_SECTIONS = ['vars', 'refs', 'components', 'elements', 'traits', 'actions', 'action_types', 'armor', 'contents', 'spawned', 'storage', 'embed', 'reagents', 'inner_reagents',
                 'cell', 'mod_theme', 'mech_projectile', 'gun', 'ammo_box', 'casing', 'clothing', 'runtimes', 'delete_runtimes', 'section_errors', 'icon', 'icon_state']
# Sections that make a thing more than a look, whatever its vars say.
WORKING_SECTIONS = ['gun', 'ammo_box', 'casing', 'storage', 'actions', 'cell', 'embed', 'mod_theme', 'mech_projectile']
ROUTE_KINDS = ['shops', 'peddler', 'cargo', 'order_consoles', 'other_sellers', 'printing', 'crafting', 'made_by_use', 'other_routes', 'loot', 'starting', 'field_vendors', 'in_containers']
# Routes that hand out exactly this path, so a type with no sprite of its own can't be only a family base.
HANDED_OUT_KINDS = {'shops', 'cargo', 'printing'}
# What a pack's availability needs, as the word a sheet shows. An ordinary console needs nothing.
CARGO_NEEDS = (('emagged', 'emag'), ('contraband', 'contraband'), ('runtime unlock', 'special'))
# Who sells a thing outside the order consoles, from the offer's type. The conditions are nothing alike, so a sheet names them.
SELLER_WORDS = (('/datum/market_item', 'blackmarket'), ('/datum/voucher_set', 'voucher'), ('/datum/exploration_event', 'drone'), ('/obj/machinery/vending', 'prison'), ('/datum/outpost_shop_listing', 'playershop'))


def dumps(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'))


def jsonable(value):
    return json.loads(json.dumps(value, default=str))


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=1) + '\n', encoding='utf-8', newline='\n')


# ---------------------------------------------------------------------------------------- dump

def read_dump(path):
    meta, summary, rows = {}, {}, {}
    with Path(path).open(encoding='utf-8', errors='replace') as f:
        for line in f:
            row = json.loads(line)
            if row.get('meta'):
                meta = row
            elif row.get('summary'):
                summary = row
            else:
                for name in CLOCK_VARS & set(row.get('vars') or {}):
                    del row['vars'][name]
                for component in row.get('components') or []:
                    for name in CLOCK_COMPONENT_VARS & set(component['vars']):
                        del component['vars'][name]
                rows[row['path']] = row
    return meta, summary, rows


# ---------------------------------------------------------------------------------------- procs

def scan_procs(dm):
    """Which procs each type path defines, whether written as a full path or nested under a type block."""
    procs = collections.defaultdict(dict)
    keywords = {'if', 'for', 'while', 'switch', 'return', 'var', 'else', 'do', 'try', 'catch', 'new', 'del', 'list', 'set'}

    def record(path, name, source, declared):
        if name.isupper():  # a macro line such as COOLDOWN_DECLARE(x), not a proc
            return
        entry = procs[path].setdefault(name, dict(source=source, declared=declared))
        entry['declared'] = entry['declared'] or declared

    for file in dm.files:
        if '/unit_tests/' in file:
            continue
        lines = clean_comments(dm.texts[file]).splitlines()
        context = []
        skip = None
        continuation = False
        index = 0
        while index < len(lines):
            line = lines[index]
            number = index + 1
            index += 1
            stripped = line.strip()
            if not stripped:
                continue
            if stripped.startswith('#') or continuation:
                continuation = stripped.endswith('\\')
                continue
            indent = len(line) - len(line.lstrip('\t'))
            if skip is not None:
                if indent > skip:
                    continue
                skip = None
            if indent == 0:
                context = []
                match = re.match(r'(/[\w/]*?)/(?:(proc|verb)/)?(\w+)\s*\(', stripped)
                if match and '=' not in stripped.split('(', 1)[0]:
                    record(match[1], match[3], f'{file}:{number}', bool(match[2]))
                    skip = 0
                elif re.fullmatch(r'/[\w/]+/?', stripped):
                    context.append((0, stripped.rstrip('/')))
                continue
            while context and context[-1][0] >= indent:
                context.pop()
            if not context:
                continue
            path = context[-1][1]
            if '=' in stripped.split('(', 1)[0]:
                raw = stripped.split('=', 1)[1]
                while balance(raw) and index < len(lines):
                    raw += lines[index].strip()
                    index += 1
                continue
            match = re.fullmatch(r'(?:(proc|verb)/)?(\w+)\s*\(.*\)', stripped)
            if match and match[2] not in keywords:
                record(path, match[2], f'{file}:{number}', bool(match[1]))
                skip = indent
                continue
            if stripped in ('proc', 'verb'):
                context.append((indent, path))
            elif re.fullmatch(r'[\w/]+', stripped) and not stripped.startswith('var'):
                context.append((indent, f'{path}/{stripped}'))
    return procs


def chain_below(dm, path, base):
    chain = []
    seen = set()
    while path and path != base and path not in seen and path != ITEM and path != '/obj' and path != '/':
        seen.add(path)
        chain.append(path)
        path = dm.parent(path)
    return chain


def override_row(dm, procs, path, base):
    own = sorted(procs.get(path, {}))
    inherited = {}
    for parent in chain_below(dm, path, base)[1:]:
        names = sorted(procs.get(parent, {}))
        if names:
            inherited[parent] = names
    return dict(path=path, base=base, own=own, inherited=inherited)


def behaviour_of(row, family=FAMILY_BASES, setup=SETUP_PROCS):
    """(type, proc) pairs below the base that do something the numbers can't show."""
    found = []
    if row.get('path') not in family:
        for name in row['own']:
            if name not in setup:
                found.append((row.get('path'), name))
    for parent, names in row['inherited'].items():
        if parent in family:
            continue
        for name in names:
            if name not in setup:
                found.append((parent, name))
    return found


def notable_behaviour(behaviour, category):
    """The behaviour a note would have to explain: no plumbing, and in a category whose job is in its desc, only what hurts or stops a person."""
    found = [(owner, name) for owner, name in behaviour if name not in PLUMBING_PROCS]
    if category in FIGHT_ONLY_CATEGORIES:
        found = [(owner, name) for owner, name in found if name in FIGHT_PROCS or (category == 'mech' and name == 'action')]
    return found


def chain_paths(raw):
    """Casings and projectiles this item fires or holds, each with the base its procs are measured below."""
    found = []

    def casing(facts):
        if not facts:
            return
        if facts.get('type'):
            found.append((facts['type'], '/obj/item/ammo_casing'))
        projectile = (facts.get('projectile') or {}).get('type')
        if projectile:
            found.append((projectile, '/obj/projectile'))

    gun = raw.get('gun') or {}
    casing((gun.get('magazine') or {}).get('casing'))
    for mode in gun.get('modes') or []:
        casing(mode)
    casing(gun.get('chambered'))
    casing((raw.get('ammo_box') or {}).get('casing'))
    casing(raw.get('casing'))
    projectile = (raw.get('mech_projectile') or {}).get('type')
    if projectile:
        found.append((projectile, '/obj/projectile'))
    return sorted(set(found))


# ---------------------------------------------------------------------------------------- routes

def known_kinds(sources):
    kinds = [key for key in ROUTE_KINDS if sources.get(key)]
    by_kind = (sources.get('maps') or {}).get('by_kind') or {}
    for kind in PLACED_KINDS:
        if any(mode in ('direct', 'container', 'spawner') for mode in by_kind.get(kind, {})):
            kinds.append('maps')
            break
    return kinds


def firm_kinds(sources):
    """As known_kinds, but a literal mention in a loot file isn't a route (it could be a hand-in, not a payout), and neither is a recipe nobody can make."""
    kinds = known_kinds(sources)
    if 'loot' in kinds and all(row.get('literal') for row in sources['loot']):
        kinds.remove('loot')
    for kind in ('crafting', 'made_by_use'):
        if kind in kinds and not any(row.get('routable', True) for row in sources[kind]):
            kinds.remove(kind)
    return kinds


def rep_steps(sources):
    """Lowest reputation step of the shop and research routes, and whether any route asks for no reputation at all. A hidden node isn't opened by reputation."""
    steps = []
    free = False
    for shop in sources.get('shops') or []:
        steps.append(shop.get('rep_step'))
    for design in sources.get('printing') or []:
        if design.get('roundstart') or design.get('unlock') == 'hacked autolathe':
            free = True
        for node in design.get('nodes') or []:
            if not node.get('hidden_with_prereqs'):
                steps.append(node.get('rep_step_with_prereqs'))
    steps = [step for step in steps if step in REP_ORDER]
    return min(steps, key=REP_ORDER.index) if steps else None, free


def cargo_words(packs):
    """How each pack reaches a console: plain, or what it takes. A pack can need more than one thing."""
    return sorted({'+'.join(word for text, word in CARGO_NEEDS if text in str(pack.get('availability'))) or 'plain' for pack in packs})


def seller_word(row):
    offer = str(row.get('offer'))
    return next((word for prefix, word in SELLER_WORDS if offer.startswith(prefix)), 'seller')


def made_beside(crafting):
    """The machines the easiest recipe has to be made beside, and the ones it uses up. If any recipe that works needs none, a machine isn't what's in the way."""
    rows = [row for row in crafting if row.get('routable', True)] or crafting
    if not all(fixture_needs(row) for row in rows):
        return [], []
    beside = sorted({need for row in rows for need in fixture_needs(row)})
    return beside, sorted({need for row in rows for need in row.get('uses_up') or []} & set(beside))


def availability(sources):
    shops = sources.get('shops') or []
    credit_shops = [s for s in shops if isinstance(s['credits'], (int, float)) and s['credits'] > 0]
    voucher_only = [s for s in shops if not s['credits'] and s.get('vouchers')]
    printing = sources.get('printing') or []
    peddler = sources.get('peddler') or []
    by_kind = (sources.get('maps') or {}).get('by_kind') or {}
    crafting = sources.get('crafting') or []

    def placed(kind):
        return sum(v for k, v in by_kind.get(kind, {}).items() if k in ('direct', 'container'))

    def research_nodes(hidden):
        return any(bool(node.get('hidden_with_prereqs')) == hidden for p in printing for node in p['nodes'])

    def routable(kind):
        return any(row.get('routable', True) for row in sources.get(kind) or [])

    starting = sources.get('starting') or []
    beside, uses_up = made_beside(crafting)
    return dict(
        cheapest_credits=min((s['credits'] for s in credit_shops), default=None),
        cheapest_credits_with_vouchers=min((s.get('vouchers') or 0 for s in credit_shops), default=None),
        voucher_only_shops=len(voucher_only),
        shop_lines=len(shops),
        shop_zones=sorted({z for s in shops for z in str(s['zone']).split('|')}),
        lowest_rep_step=min((str(s['rep_step']) for s in shops if s['rep_step'] in REP_ORDER), key=REP_ORDER.index, default=None),
        peddler_zones=sorted({z for s in peddler for z in str(s['zone']).split('|')}),
        peddler_cheapest_credits=min((s['credits'] for s in peddler if isinstance(s['credits'], (int, float)) and s['credits'] > 0), default=None),
        printable_roundstart=any(p['roundstart'] for p in printing),
        printable_by_research=research_nodes(False),
        printable_hidden=research_nodes(True),
        printable_hacked=any(p['unlock'] == 'hacked autolathe' for p in printing),
        printable_from_disk=sorted({disk for p in printing for disk in p.get('disks') or []}),
        lowest_print_material_value=min((p['material_value'] for p in printing if isinstance(p['material_value'], (int, float))), default=None),
        cargo_packs=len(sources.get('cargo') or []),
        cargo_words=cargo_words(sources.get('cargo') or []),
        console_words=sorted({str(row.get('shop_type')).rsplit('/', 1)[-1] for row in sources.get('order_consoles') or []}),
        seller_words=sorted({seller_word(row) for row in sources.get('other_sellers') or []}),
        crafted=routable('crafting'),
        crafted_beside=beside,
        crafted_uses_up=uses_up,
        made_by_use=routable('made_by_use'),
        used_from=sorted({row['from_item'] for row in sources.get('made_by_use') or [] if row.get('routable', True)}),
        crafted_empty=any(row.get('made_empty') for row in crafting),
        crafted_kit_missing=sorted({kit['path'] for row in crafting for kit in row.get('kit_routes') or [] if not kit['has_route']}),
        learned_from=sorted({book for row in crafting for book in row.get('learned_from') or []}),
        loot_rows=len(sources.get('loot') or []),
        starting_outfits=len([x for x in starting if x.get('kind') == 'outfit' and not x.get('conditional')]),
        starting_conditional=len([x for x in starting if x.get('conditional')]),
        starting_vendors=len([x for x in starting if x.get('kind') == 'vendor']),
        character_loadout=any(x.get('kind') == 'loadout' for x in starting),
        field_vendor_kinds=sorted({kind for row in sources.get('field_vendors') or [] for kind in row['placed'] if kind in PLACED_KINDS}),
        placed_on_hulls=placed('hull'),
        placed_on_unused_hulls=placed('hull_unused'),
        hull_maps=((sources.get('maps') or {}).get('distinct_by_kind') or {}).get('hull', 0),
        placed_on_modules=placed('module'),
        placed_in_ruins=placed('ruin'),
        placed_at_outposts=placed('outpost'),
        placed_on_npc_ships=placed('npc_ship'),
        spawner_placements={kind: modes['spawner'] for kind, modes in sorted(by_kind.items()) if modes.get('spawner') and kind in PLACED_KINDS},
        distinct_maps=(sources.get('maps') or {}).get('distinct_maps', 0),
    )


def close_routes(rows, dump_rows, sources_reader):
    """Routes that lean on another item: what a container holds, and what a recipe makes. Fills in_containers, kit_routes and firm_sources.

    Starts from items with a route of their own and grows until nothing changes, so a kit nobody can get never makes its gun look obtainable.
    A machine a recipe needs counts when it's on a map that can appear in a round, or a checked route reaches it. An ordinary ingredient has a route by definition.
    """
    dm = sources_reader.dm
    ordinary = sources_reader.ordinary
    held_in = collections.defaultdict(dict)
    for path, raw in dump_rows.items():
        for child, count in (raw.get('contents') or {}).items():
            if child != path:
                held_in[child][path] = count

    recipes = {path: (row['sources'].get('crafting') or []) + [use_recipe(use) for use in row['sources'].get('made_by_use') or []] for path, row in rows.items()}
    start = {}
    fixtures = {}
    while True:  # A machine's own recipe can ask for another machine.
        found = sources_reader.fixtures_for({need for entries in recipes.values() for entry in entries for need in fixture_needs(entry)})
        fresh = {fixture: routes for fixture, routes in found.items() if fixture not in fixtures}
        if not fresh:
            break
        fixtures.update(fresh)
        for fixture, routes in fresh.items():
            recipes[fixture] = routes.get('crafting') or []
            if sources_reader.fixture_in_round(fixture) or any(routes.get(kind) for kind in ('shops', 'cargo', 'order_consoles', 'other_sellers', 'other_routes')):
                start[fixture] = 0

    needed = {need for entries in recipes.values() for entry in entries for need in item_needs(entry) + fixture_needs(entry)}
    covers = covering_types([*rows, *fixtures], needed, dm.parent)

    def direct(row):
        return [k for k in firm_kinds(row['sources']) if k not in ('crafting', 'made_by_use', 'in_containers')]

    start.update({path: 0 for path, row in rows.items() if direct(row) or is_ordinary(path, ordinary)})
    routed = settle(start, recipes, covers, held_in)

    for path, row in rows.items():
        sources = row['sources']
        for use in sources.get('made_by_use') or []:
            # The proc belongs to from_item, so its subtypes inherit it: an /obj/item/pipe is only ever one of its subtypes.
            use['routable'] = any(p in routed for p in covers.get(use['from_item'], []))
        for entry in sources.get('crafting') or []:
            entry['routable'] = recipe_step(entry, routed, covers) is not None
            if 'recipe' not in entry:
                continue
            kits = []
            for need in item_needs(entry) + fixture_needs(entry):
                covered = [p for p in covers.get(need, []) if p in routed]
                route_rows = [rows[p] for p in covered if p in rows]
                if is_basic_material(need) and covered:
                    continue  # basic material with a route of its own
                kinds = sorted({k for r in route_rows for k in direct(r)})
                lowest, free = None, any(is_ordinary(p, ordinary) for p in covered)
                for route_row in route_rows:
                    step, roundstart = rep_steps(route_row['sources'])
                    if step and (lowest is None or REP_ORDER.index(step) < REP_ORDER.index(lowest)):
                        lowest = step
                    free = free or roundstart or any(k not in ('shops', 'printing') for k in direct(route_row))
                kits.append(dict(path=need, has_route=bool(covered), routes=kinds, lowest_rep_step=lowest, needs_no_rep=free))
            entry['kit_routes'] = kits
    for path, row in rows.items():
        routes = [dict(container=c, count=n) for c, n in sorted(held_in.get(path, {}).items()) if c in routed]
        if routes:
            row['sources']['in_containers'] = routes
        row['known_sources'] = known_kinds(row['sources'])
        row['firm_sources'] = firm_kinds(row['sources'])
    for path, row in rows.items():
        for route in row['sources'].get('in_containers') or []:
            route['routes'] = rows[route['container']]['firm_sources']


# ---------------------------------------------------------------------------------------- what an item is

def real_name(name):
    """A name a player would read. The category bases call themselves things like wrench too, so a name alone can't say what's abstract: a route has to."""
    return bool(name) and name not in ('item', 'object')


def is_abstract(path, raw, has_subtypes, known):
    """A family base with nothing of its own. A type with its own sprite and a real name that's in any source or map is a real item.

    So is one with no sprite of its own that a shop, a pack or a printer hands out by name: a cyborg arm draws itself at runtime.
    """
    if not has_subtypes:
        return False
    if not (raw.get('no_sprite') or path in SHAPE_BASES):
        return False
    if not real_name(raw.get('name')):
        return True
    return not (set(known) & HANDED_OUT_KINDS if raw.get('no_sprite') else known)


def protects(raw, base_armor):
    """Armor that means something: any fighting rating, or anything above what the category's plain item already has. A jumpsuit's bit of bio doesn't count."""
    armor = {k: v for k, v in (raw.get('armor') or {}).items() if k != 'type'}
    if any(num(armor.get(k)) for k in FIGHT_ARMOR):
        return True
    return any((num(v) or 0) > (num(base_armor.get(k)) or 0) for k, v in armor.items())


def vars_that_count(raw, base_values, category, meta, base_armor):
    """Vars differing from the category base that aren't only looks."""
    found = []
    fields = meta.get('bitfields') or {}
    armored = protects(raw, base_armor)
    worn = category in WORN_CATEGORIES
    for name, value in (raw.get('vars') or {}).items():
        if name in LOOK_VARS or base_values.get(name) == value:
            continue
        if worn and not armored and name in UNARMORED_WORN_VARS:
            continue
        if name == 'flags_inv' and fields.get('flags_inv') and set(decode_flags(value, fields['flags_inv'])) <= LOOK_INV_FLAGS:
            continue
        if name == 'clothing_flags' and fields.get('clothing_flags') and set(decode_flags(value, fields['clothing_flags'])) <= LOOK_CLOTHING_FLAGS:
            continue
        found.append(name)
    return sorted(found)


def does_work(raw, category, base_armor):
    """Reasons a thing is more than a look that no comparison with its base would show: a reskin of a knife still cuts."""
    reasons = []
    if protects(raw, base_armor):
        reasons.append('armor')
    reasons += [section for section in WORKING_SECTIONS if raw.get(section)]
    held = (raw.get('reagents') or {}).get('held')
    if held:
        reasons.append('reagents')
    values = raw.get('vars') or {}
    force = num(values.get('force')) or 0
    if force >= MELEE_FORCE_MIN or (category in ('melee', 'shields') and force > 0):
        reasons.append('force')
    if values.get('tool_behaviour'):
        reasons.append('tool')
    return reasons


def part_owner(path, part, dump_rows, dm):
    """The highest type in the chain that still has this part: one note there covers the rest."""
    owner = path
    walker = dm.parent(path)
    seen = {path}
    while walker and walker not in seen and walker != ITEM:
        seen.add(walker)
        raw = dump_rows.get(walker)
        if not raw:
            break
        parts = [c['type'] for c in raw.get('components') or []] + [e['type'] for e in raw.get('elements') or []]
        if part not in parts:
            break
        owner = walker
        walker = dm.parent(walker)
    return owner


def should_note(row, behaviour, chain_behaviour, note_parts):
    """Players can get it, it's gear, and the numbers can't speak for it."""
    if row['status'] != 'ok' or row['abstract'] or row['cosmetic'] or not row['firm_sources'] or not row['gear']:
        return False
    if any(row['path'] == family or row['path'].startswith(family + '/') for family in NO_NOTE_FAMILIES):
        return False
    return bool(behaviour or chain_behaviour or note_parts)


def strip_presentation(value):
    if isinstance(value, dict):
        return {k: strip_presentation(v) for k, v in value.items() if k not in PRESENTATION_VARS}
    if isinstance(value, list):
        return [strip_presentation(v) for v in value]
    return value


def digest(value):
    return hashlib.sha256(dumps(value).encode('utf-8')).hexdigest()[:16]


def proc_code(dm, owner_and_proc):
    """The source of a proc, comments and indentation gone, where the DM reader found it. Nested-block procs have none, so only their name counts."""
    owner, name = owner_and_proc
    bodies = dm.procs.get(f'{owner}/{name}') or []
    return [[line.strip() for line in text.splitlines() if line.strip()] for _, text in bodies]


def facts_digest(row, behaviour, chain_behaviour, note_parts, dm):
    """What the item does: its facts, including the magazine and projectile nested in them, and the code of what makes it special. Names, descs, icons and sources don't count."""
    return digest(dict(
        facts=strip_presentation(row['facts']),
        behaviour=sorted(f'{owner}/{proc}' for owner, proc in behaviour),
        chain=sorted(f'{owner}/{proc}' for owner, proc in chain_behaviour),
        code=[proc_code(dm, pair) for pair in sorted(set(behaviour) | set(chain_behaviour))],
        parts=note_parts,
    ))


# ---------------------------------------------------------------------------------------- assembly

class Context:
    """What the category sections need besides their own row."""

    def __init__(self, rows, dump_rows, meta, procs, sources):
        self.rows = rows
        self.dump_rows = dump_rows
        self.meta = meta
        self.procs = procs
        self.dm = sources.dm
        self.click_cd = meta.get('click_cd_range', 4)
        self.click_cd_melee = meta.get('click_cd_melee', CLICK_CD_MELEE)
        self.armor_rule = dict(weakened_multiplier=meta.get('armor_weakened_multiplier', ARMOR_WEAKENED_MULTIPLIER), max_block=meta.get('armor_max_block', ARMOR_MAX_BLOCK))
        self.vest = {k: v for k, v in ((dump_rows.get(ARMOR_VEST) or {}).get('armor') or {}).items() if k != 'type'}
        pass_table = (meta.get('bitfields') or {}).get('pass_flags')
        self.decode_pass = (lambda value: decode_flags(value, pass_table)) if pass_table else None
        self.default_rack_ds = ((dump_rows.get('/obj/item/gun/ballistic') or {}).get('gun') or {}).get('rack_delay')
        self.surgeries = sources.surgery_by_zone()
        self.loose_boxes = collections.defaultdict(list)
        self.by_magazine = collections.defaultdict(list)
        self.by_caliber = collections.defaultdict(list)
        for path in sorted(dump_rows):
            raw = dump_rows[path]
            box = raw.get('ammo_box') or {}
            if box.get('caliber') and path.startswith('/obj/item/ammo_box') and not path.startswith('/obj/item/ammo_box/magazine') and not box.get('start_empty'):
                self.loose_boxes[box['caliber']].append(path)
            gun = raw.get('gun')
            if gun and gun.get('kind') == 'ballistic':
                for magazine in gun.get('spare_magazines') or []:
                    self.by_magazine[magazine].append(path)
                caliber = (gun.get('magazine') or {}).get('caliber')
                if caliber:
                    self.by_caliber[caliber].append(path)

    def number_var(self, path, name, default=0):
        value = num(((self.dump_rows.get(path) or {}).get('vars') or {}).get(name))
        return default if value is None else value

    def name_of(self, path):
        return (self.dump_rows.get(path) or {}).get('name') if isinstance(path, str) else None

    def actions_of(self, path):
        return (self.dump_rows.get(path) or {}).get('actions') or []

    def proc_owner(self, path, name):
        walker, seen = path, set()
        while walker and walker not in seen and walker != ITEM:
            seen.add(walker)
            if name in self.procs.get(walker, {}):
                return walker
            walker = self.dm.parent(walker)
        return None

    def fitted_item(self, path):
        """An arm implant's tool or weapon, with its fighting numbers if it has any."""
        raw = self.dump_rows.get(path) or {}
        values = raw.get('vars') or {}
        sharpness = decode_flags(values.get('sharpness'), (self.meta.get('bitfields') or {}).get('sharpness')) or None
        facts = dict(path=path, name=raw.get('name'), force=values.get('force'), armour_penetration=values.get('armour_penetration'), sharpness=sharpness,
                     attack_speed=values.get('attack_speed'), tool_behaviour=values.get('tool_behaviour'), toolspeed=values.get('toolspeed'))
        gun = raw.get('gun')
        if gun:
            facts['gun'] = dict(kind=gun.get('kind'), cell_maxcharge=gun.get('cell_maxcharge'), self_recharge=gun.get('selfcharge'),
                                projectile=(((gun.get('modes') or [{}])[0]).get('projectile') or {}).get('type'))
        return {k: v for k, v in facts.items() if v is not None}

    def upgrades_for(self, category, items):
        """What can change a rated item's armor after it's made: a suit bench's plating, and armor plates an item takes. Sorted lines of plain text, for the category's sheet."""
        lines = []
        if category == 'modsuits':
            lines += self.bench_lines()
        plates = collections.Counter()
        for path in items:
            for component in (self.dump_rows[path].get('components') or []):
                if component['type'] == '/datum/component/armor_plate':
                    values = component.get('vars') or {}
                    plates[(values.get('upgrade_name'), values.get('maxamount'), values.get('armor_mod'))] += 1
        for (name, amount, armor_mod), count in sorted(plates.items(), key=lambda kv: str(kv[0])):
            ratings = {rating: self.dm.val(armor_mod, rating) for rating in ARMOR_RATINGS}
            bonus = ' '.join(f'{rating}+{value}' for rating, value in ratings.items() if isinstance(value, (int, float)) and value)
            lines.append(f'{count} items here take {amount} {name}, each {bonus}')
        return lines

    def bench_lines(self):
        """The MOD fitting bench, on one line: each upgrade family with what all of it costs and adds to armor."""
        families = collections.defaultdict(list)
        for upgrade in self.dm.paths('/datum/mod_upgrade'):
            if self.dm.val(upgrade, 'id'):
                families[self.dm.val(upgrade, 'category')].append(upgrade)
        parts = []
        for family, upgrades in sorted(families.items()):
            added = collections.Counter()
            credits = vouchers = 0
            for upgrade in upgrades:
                credits += self.dm.val(upgrade, 'price_credits') or 0
                vouchers += self.dm.val(upgrade, 'price_vouchers') or 0
                for rating, value in assoc(self.dm.val(upgrade, 'armor_modifiers')).items():
                    added[str(rating)] += value
            armor = ' '.join(f'{rating}+{value}' for rating, value in sorted(added.items()))
            price = f'{credits} cr' + (f' {vouchers}v' if vouchers else '')
            parts.append(f'{family} ({price})' + (f' {armor}' if armor else ''))
        return ['MOD fitting bench, on any suit, for all of a family: ' + '; '.join(parts)] if parts else []

    def guns_for_ammo(self, path, box, casing):
        if path.startswith('/obj/item/ammo_box/magazine'):
            guns = self.by_magazine.get(path, [])
            if not guns and box and box.get('caliber'):
                guns = self.by_caliber.get(box['caliber'], [])
        else:
            guns = self.by_caliber.get((box or {}).get('caliber') or casing.get('caliber'), [])
        return [g for g in guns if self.rows.get(g, {}).get('firm_sources') and not self.rows[g].get('abstract')]


def assemble(dump_rows, meta, sources, procs):
    """Dump rows plus routes, into catalog rows and per-category entries. Pure: writes nothing."""
    dm = sources.dm
    rows, overrides, judged = {}, {}, {}
    subtypes = collections.Counter(row.get('parent') for row in dump_rows.values())
    base_vars = {ITEM: {}}
    for _, _, base in CATEGORIES:
        if base in dump_rows:
            base_vars[base] = dump_rows[base].get('vars') or {}

    for path in sorted(dump_rows):
        raw = dump_rows[path]
        category, base = category_of(path)
        over = override_row(dm, procs, path, base)
        behaviour = behaviour_of(over)
        chain = []
        for chain_path, chain_base in chain_paths(raw):
            chain_over = override_row(dm, procs, chain_path, chain_base)
            chain += behaviour_of(chain_over, family=CHAIN_BASES, setup=CHAIN_SETUP_PROCS)
        chain = sorted(set(chain))
        parts = [p['type'] for p in raw.get('components', [])] + [e['type'] for e in raw.get('elements', [])]
        behaviour_parts = sorted({p for p in parts if p not in LOOK_PARTS})
        note_parts = [p for p in behaviour_parts if p not in NUMBER_PARTS]
        base_armor = (dump_rows.get(base) or {}).get('armor') or {}
        extra_vars = vars_that_count(raw, base_vars.get(base, {}), category, meta, base_armor)
        looked_for = path in sources.type_checked or path in sources.ingredients
        item_sources = jsonable(sources.sources_for(path, raw))
        rows[path] = dict(
            path=path, parent=raw.get('parent'), name=raw.get('name'), desc=raw.get('desc'), category=category, gear=is_gear(category), status=raw['status'],
            has_subtypes=bool(subtypes[path]), no_sprite=raw.get('no_sprite'), uncreatable=raw['status'] == 'uncreatable',
            # A cap that flips or a hood that folds is still only a look, so plumbing doesn't count on clothing.
            cosmetic_blockers=dict(vars=extra_vars, parts=behaviour_parts, procs=sorted({p for _, p in (notable_behaviour(behaviour, category) if category in WORN_CATEGORIES else behaviour)}),
                                   looked_for_by_other_code=looked_for, works=does_work(raw, category, base_armor)),
            facts={k: raw[k] for k in FACT_SECTIONS if raw.get(k)},
            sources=item_sources, overrides=over['own'],
        )
        overrides[path] = dict(base=base, own=over['own'], inherited=over['inherited'], behaviour=[f'{t}/{p}' for t, p in behaviour])
        judged[path] = dict(behaviour=notable_behaviour(behaviour, category), chain=chain, parts=note_parts)

    close_routes(rows, dump_rows, sources)

    for path, row in rows.items():
        raw = dump_rows[path]
        row['abstract'] = is_abstract(path, raw, row['has_subtypes'], row['known_sources'])
        blockers = row['cosmetic_blockers']
        looks_only = any(path == family or path.startswith(family + '/') for family in LOOK_ONLY_FAMILIES)
        row['cosmetic'] = raw['status'] == 'ok' and not row['abstract'] and (looks_only or (row['category'] not in USED_CATEGORIES and not blockers['looked_for_by_other_code']
                          and not blockers['works'] and not blockers['vars'] and not blockers['parts'] and not blockers['procs']))
        info = judged[path]
        info['needs_note'] = should_note(row, info['behaviour'], info['chain'], info['parts'])
        owners = {owner for owner, _ in info['behaviour'] + info['chain']} | {part_owner(path, part, dump_rows, dm) for part in info['parts']}
        info['owners'] = sorted(owners) if info['needs_note'] else []
        row['own_hash'] = facts_digest(row, info['behaviour'], info['chain'], info['parts'], dm)

    for path, row in rows.items():
        values = dump_rows[path].get('vars') or {}
        refers = list(values.get('items_to_create') or []) + list(values.get('applied_modules') or [])
        for name in ['imp_type', 'starting_organ', 'applied_cell']:
            if isinstance(values.get(name), str):
                refers.append(values[name])
        row['facts_hash'] = digest([row['own_hash'], sorted(rows[r]['own_hash'] for r in refers if r in rows)])
    for row in rows.values():
        del row['own_hash']

    ctx = Context(rows, dump_rows, meta, procs, sources)
    entries = collections.defaultdict(dict)
    for path, row in rows.items():
        info = judged[path]
        entry = dict(path=path, name=row['name'], desc=row['desc'], status=row['status'], abstract=row['abstract'], has_subtypes=row['has_subtypes'], cosmetic=row['cosmetic'], gear=row['gear'])
        entry.update(category_stats(row, dump_rows[path], ctx))
        randomised = randomised_vars(dm, path, dump_rows[path])
        if randomised:
            entry['randomised'] = randomised
        entry['other_vars'] = other_vars(dump_rows[path], base_vars.get(category_of(path)[1], {}), entry)
        entry.update(
            behaviour_procs=[f'{owner}/{name}' for owner, name in info['behaviour']],
            behaviour_parts=info['parts'],
            needs_note=info['needs_note'],
            note_owners=info['owners'],
            sources=row['sources'],
            availability=availability(row['sources']),
            known_sources=row['known_sources'],
            firm_sources=row['firm_sources'],
            facts_hash=row['facts_hash'],
        )
        if info['chain']:
            entry['chain_behaviour_procs'] = [f'{owner}/{proc}' for owner, proc in info['chain']]
        entries[row['category']][path] = entry
    return rows, entries, overrides, judged, ctx


def roll_ruled_out(dm, path, code, offset):
    """Whether what this type sets keeps a roll from running: if(!spawn_count) only rolls when nothing set a count. A condition decided at runtime leaves the roll in."""
    above = enclosing_lines(code, offset)
    guard = above and re.fullmatch(r'if\s*\(\s*(!|isnull\()?\s*(?:src\.)?(\w+)\s*\)?\s*\)', above[0])
    if not guard:
        return False
    value = dm.val(path, guard[2])
    if isinstance(value, Expr):
        return False
    if guard[1] == '!':
        return value not in (None, 0, '')
    if guard[1]:
        return value is not None
    # if(x) names anything, an argument too, so x has to be a var this type really leaves empty.
    return value in (None, 0, '') and bool(dm.field(path, guard[2]).source)


def randomised_vars(dm, path, raw):
    """Vars that do something and that Initialize or New set from a dice roll, as name -> the roll as written. The dump saw one result, so the row's value for these is only an example."""
    found = {}
    values = raw.get('vars') or {}
    for method in ('Initialize', 'New'):
        for _, code in proc_chain(dm, path, method):
            for match in re.finditer(r'^\s*(?:src\.)?(\w+)\s*=\s*((?:pick|pick_weight|rand|prob|roll)\(.*)$', code, re.M):
                name = match[1]
                if name in LOOK_VARS or name in PRESENTATION_VARS or not (name in values or dm.field(path, name).source):
                    continue
                value = values.get(name, dm.val(path, name))
                # A word: a colour, a sprite, a flavour line. A number or a type path is what changes a fight.
                if isinstance(value, str) and not value.startswith('/'):
                    continue
                if roll_ruled_out(dm, path, code, match.start(1)):
                    continue
                found.setdefault(name, match[2].strip())
    return found


def other_vars(raw, base_values, entry):
    """What differs from the category base, isn't only a look and isn't already a named stat: a tank's volume, a jetpack's speed, a mesh's healing."""
    return {name: value for name, value in sorted((raw.get('vars') or {}).items())
            if name not in LOOK_VARS and name not in PRESENTATION_VARS and name not in entry and base_values.get(name) != value
            and name not in ('item_flags', 'allowed', 'force_string', 'block_sound', 'block_effect', 'embed_type', 'interaction_flags_item', 'armor_type', 'body_parts_covered', 'cold_protection', 'heat_protection')}


def obtainable(row):
    return row['status'] == 'ok' and not row['abstract'] and bool(row['firm_sources'])


def family_of(path):
    """The first path part below /obj/item: how misc gets listed."""
    return '/'.join(path.split('/')[:4])


def category_counts(rows, judged):
    counts = {}
    groups = collections.defaultdict(list)
    for path, row in rows.items():
        groups[row['category']].append(row)
    for category, group in groups.items():
        owners = set()
        for row in group:
            owners.update(judged[row['path']]['owners'])
        counts[category] = dict(
            gear=category in GEAR_CATEGORIES, total=len(group), obtainable=sum(obtainable(r) for r in group),
            non_cosmetic=sum(obtainable(r) and not r['cosmetic'] for r in group), needs_note=sum(judged[r['path']]['needs_note'] for r in group), note_owners=len(owners),
        )
    return counts


def misc_families(rows):
    found = collections.Counter()
    for row in rows.values():
        if row['category'] == 'misc' and obtainable(row):
            found[family_of(row['path'])] += 1
    return sorted(found.items(), key=lambda kv: (-kv[1], kv[0]))


def write_outputs(out, rows, entries, overrides, judged, ctx, meta, map_notes):
    """Everything goes under `out`. Sorted, no clock, so two builds of the same input match byte for byte."""
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    catalog_path = out / 'catalog.jsonl'
    with catalog_path.open('w', encoding='utf-8', newline='\n') as f:
        for path in sorted(rows):
            f.write(dumps(rows[path]) + '\n')
    click_cd = ctx.click_cd
    for category, items in entries.items():
        document = dict(gear=category in GEAR_CATEGORIES, items=items)
        formulas = dict(FORMULAS.get(category, {}))
        if category not in ('melee', 'shields') and any('melee' in entry for entry in items.values()):
            formulas['melee block'] = MELEE_FORMULAS
        if formulas:
            document['formulas'] = formulas
        upgrades = ctx.upgrades_for(category, items)
        if upgrades:
            document['upgrades'] = upgrades
        if category == 'guns':
            document.update(click_cooldown_ds=click_cd, weapon_weight=meta.get('weapon_weight'), bolt_type=meta.get('bolt_type'), target=dict(vest=ctx.vest, vest_type=ARMOR_VEST))
        if category in ('melee', 'shields'):
            document['click_cooldown_ds'] = ctx.click_cd_melee
        if category == 'eyewear':
            document['sight_constants'] = meta.get('sight_flags')
        write_json(out / 'items' / f'{category}.json', document)
    write_json(out / 'overrides.json', overrides)

    counts = category_counts(rows, judged)
    all_owners = set()
    for info in judged.values():
        all_owners.update(info['owners'])
    status_counts = collections.Counter(r['status'] for r in rows.values())
    kinds = collections.Counter()
    for r in rows.values():
        kinds.update(r['known_sources'])
    report = dict(
        categories=dict(sorted(counts.items())),
        total=len(rows), statuses=dict(sorted(status_counts.items())), cosmetic=sum(r['cosmetic'] for r in rows.values()), abstract=sum(r['abstract'] for r in rows.values()),
        items_with_source_kind=dict(sorted(kinds.items())), no_known_source=sum(not r['known_sources'] for r in rows.values()),
        dump=dict(byond=meta.get('byond')),
        misc_families=misc_families(rows),
        note_rule=dict(
            selected=sum(info['needs_note'] for info in judged.values()), distinct_owner_types=len(all_owners),
            owners=sorted(all_owners),
            by_category={category: sorted(p for p, r in rows.items() if r['category'] == category and judged[p]['needs_note']) for category in sorted(GEAR_CATEGORIES)},
        ),
        map_files=dict(sorted(map_notes.items())),
        catalog_sha256=hashlib.sha256(catalog_path.read_bytes()).hexdigest(),
    )
    write_json(out / 'summary.json', report)
    return report


def build(root, out, dump_path):
    """The whole rebuild for a checkout."""
    from .sources import Sources

    meta, _, dump_rows = read_dump(dump_path)
    sources = Sources(root, dump_rows)
    procs = scan_procs(sources.dm)
    print('sources read', flush=True)
    rows, entries, overrides, judged, ctx = assemble(dump_rows, meta, sources, procs)
    print('rows built', flush=True)
    return write_outputs(out, rows, entries, overrides, judged, ctx, meta, sources.map_notes)
