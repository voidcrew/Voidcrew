"""How players get each item, beyond what static_sources reads: maps, loot tables, drops, outfits and vendors.

Everything here is read from source and carries its file:line. Where the game decides at runtime the row says so
instead of guessing. `literal` rows mean only "this path is written in a file that pays out loot"; they carry the
citation and no odds. Container contents come from the dump, which saw them for real.
"""
from __future__ import annotations

import collections
import fnmatch
import functools
import re

from .categories import PLACED_KINDS
from .dm_reader import assoc, clean_comments, paths, proc_chain, rounded, split_top
from .offers import ladder_restricted, paths_in
from .static_sources import StaticSources


# Files whose path literals are payouts. Only for sources without a table the scripts can read directly; the
# label names the channel in the catalog. Order matters: first match wins.
LOOT_FILES = [
    ('voidcrew/modules/npc_ships/code/bounty/*.dm', 'npc', 'pirate bounty crate'),
    ('voidcrew/modules/npc_ships/code/faction_pirates/*.dm', 'npc', 'faction pirate'),
    ('voidcrew/modules/npc_ships/code/npc_ship*.dm', 'npc', 'npc ship'),
    ('voidcrew/modules/npc_ships/code/ship_key.dm', 'npc', 'npc ship'),
    ('voidcrew/modules/bounties/*.dm', 'bounty', 'criminal bounty'),
    ('voidcrew/modules/lich/*.dm', 'boss', 'lich'),
    ('voidcrew/modules/colosseum/colosseum_controller.dm', 'boss', 'colosseum'),
    ('voidcrew/modules/colosseum/colosseum_gear.dm', 'boss', 'colosseum'),
    ('voidcrew/modules/antag_ruins/ascension*.dm', 'boss', 'vestige ascension'),
    ('voidcrew/modules/mining/lavaland/edits/necropolis_chests.dm', 'boss', 'necropolis chest'),
    ('code/modules/mining/lavaland/necropolis_chests.dm', 'boss', 'necropolis chest'),
    ('voidcrew/edits/objects/structures/lavaland/necropolis_tendril.dm', 'boss', 'necropolis tendril'),
    ('voidcrew/edits/mobs/weapon_drops.dm', 'npc', 'npc weapon ladder'),
    ('voidcrew/edits/mobs/ladder_outfits.dm', 'npc', 'npc weapon ladder'),
    ('voidcrew/objects/structures/spawner.dm', 'npc', 'nest or den'),
    ('voidcrew/objects/structures/icemoon/cave_entrance.dm', 'npc', 'demonic portal'),
    ('voidcrew/modules/anomalies/core_rewards.dm', 'npc', 'anomaly reward'),
    ('voidcrew/datums/mapgen/planet_anomalies.dm', 'npc', 'anomaly reward'),
    ('voidcrew/machinery/suit_storage_unit.dm', 'ruin', 'ruin suit storage'),
    ('voidcrew/modules/shuttle/ship_parts/spawners.dm', 'ruin', 'ship part spawner'),
    ('voidcrew/modules/contested_cache/*.dm', 'ruin', 'contested cache'),
    ('voidcrew/modules/derelict_outposts/*.dm', 'ruin', 'derelict outpost'),
    ('voidcrew/modules/dynamic_events/events/stray_cargo_market.dm', 'event', 'stray cargo'),
    ('voidcrew/modules/missions/missions/*.dm', 'mission', 'mission'),
    ('voidcrew/modules/missions/_missions.dm', 'mission', 'mission'),
    ('voidcrew/modules/trade/outpost_quests.dm', 'mission', 'trader board'),
    ('voidcrew/modules/drug_smuggling/mission.dm', 'mission', 'drug run'),
    ('code/modules/explorer_drone/loot.dm', 'other', 'exploration drone'),
]

# The four random spawner families whose make_item() swaps ladder guns and melee for something plain.
LADDER_REPLACED_SPAWNERS = ['/obj/effect/spawner/random/armory', '/obj/effect/spawner/random/contraband',
                            '/obj/effect/spawner/random/exotic', '/obj/effect/spawner/random/maintenance']

# Mob vars that hold death drops.
MOB_LOOT_FIELDS = {
    'loot': 'death drop',
    'loot_pool': 'death drop',
    'rare_loot_pool': 'rare death drop (rolled at spawn)',
    'random_loot': 'one of a random pool',
    'random_loot_2': 'one of a random pool',
    'crusher_loot': 'crusher kill drop',
    'butcher_results': 'butchering',
    'guaranteed_butcher_results': 'butchering',
    'loot_drop': 'elite drop when boosted',
}
OUTFIT_FIELDS = ['uniform', 'suit', 'back', 'belt', 'gloves', 'shoes', 'head', 'mask', 'neck', 'glasses', 'ears', 'id',
                 'l_pocket', 'r_pocket', 'l_hand', 'r_hand', 'suit_store', 'accessory', 'backpack_contents', 'box',
                 'belt_contents', 'implants', 'pda_slot']


# Map kinds a ship's crew starts on. Everywhere else a vending machine or locker is something to go and find.
PLAYER_SHIP_KINDS = ('hull', 'module')
HULL_BASE = '/datum/map_template/shuttle/voidcrew'


def under_condition(code, offset):
    """Whether the line at this offset of a proc's source only runs sometimes: inside an if, an else or a switch."""
    lines = code[:offset].split('\n')
    tabs = lambda line: len(line) - len(line.lstrip('\t'))
    conditional = ('if(', 'if (', 'else', 'switch(', 'switch (')
    if lines[-1].strip().startswith(conditional):
        return True
    depth = tabs(lines[-1])
    for prior in reversed(lines[:-1]):
        if not prior.strip() or tabs(prior) >= depth:
            continue
        depth = tabs(prior)
        if prior.strip().startswith(conditional):
            return True
    return False


def item_literals(text):
    """/obj and /obj/item path literals outside type headers, with line numbers."""
    for number_, line in enumerate(text.splitlines(), 1):
        if not line.strip() or line.startswith('/'):
            continue
        if 'istype(' in line or 'locate(' in line or 'ispath(' in line or 'typesof(' in line or 'typecacheof(' in line:
            continue
        # var/obj/item/thing/name is a declaration, unless it is `= new(...)`, which builds the declared type.
        declared = re.search(r'\bvar/(?:list/)?(obj/[\w/]+)/\w+\s*(=\s*new\b(?!\s*/))?', line)
        if declared:
            if declared[2]:
                yield '/' + declared[1], number_
            line = line[:declared.start()] + line[declared.end():]
        for match in re.finditer(r'/obj/[\w/]+', line):
            yield match[0].rstrip('/'), number_


@functools.lru_cache(None)
def is_ladder_gun_or_melee(dm, item):
    """The checks ladder_floor_replacement() makes, from the same typecaches."""
    if dm.is_a(item, '/obj/item/gun') or dm.is_a(item, '/obj/item/weaponcrafting/receiver') or dm.is_a(item, '/obj/item/weaponcrafting/giant_wrench'):
        return ladder_restricted(dm, item)
    melee = dm.proc('/proc/is_ladder_restricted_melee')
    exempt = paths_in(melee.split('return FALSE', 1)[0])
    if any(dm.is_a(item, p) for p in exempt):
        return False
    restricted = paths_in(melee.split('typecacheof(list(', 1)[1].split('))', 1)[0])
    return any(dm.is_a(item, p) for p in restricted)


class Sources(StaticSources):
    def __init__(self, root, dump):
        self.dump = dump
        self.placements = collections.defaultdict(lambda: collections.defaultdict(collections.Counter))
        self.placement_maps = collections.defaultdict(collections.Counter)
        self.placement_expected = collections.defaultdict(collections.Counter)
        self.closet_hits = collections.defaultdict(lambda: collections.defaultdict(collections.Counter))
        self.map_kinds = {}
        self.map_notes = collections.Counter()
        self.mob_placements = collections.Counter()
        self.mentions = collections.defaultdict(list)
        self.voidcrew_mentions = set()
        self.type_checked = set()
        self.expanded = {}
        self.loot = collections.defaultdict(list)
        self.outfit_uses = collections.defaultdict(list)
        super().__init__(root)
        self.build_maps()
        self.build_mentions()
        self.build_loot_channels()
        self.build_mob_drops()
        self.build_mob_code_drops()
        self.build_outfits()
        self.starting = self.starting_index()
        self.vendors = self.vendor_index()
        self.loadouts = self.loadout_index()
        self.loots = self.merged_index(self.loot)

    # ------------------------------------------------------------------ item containers

    @functools.lru_cache(None)
    def direct_children(self, owner):
        """What this thing holds or rolls: list of (child, count, how). Items use the dump, which saw it for real."""
        row = self.dump.get(owner)
        if row and (row.get('contents') or row.get('spawned')):
            out = []
            for child, count in {**row.get('contents', {}), **row.get('spawned', {})}.items():
                out.append((child, count, 'dump'))
            return tuple(out)
        if owner.startswith('/obj/effect/spawner'):
            pool, total = self.spawner_pool(owner)
            return tuple((child, weight / total if total else None, 'spawner') for child, weight in pool.items())
        return tuple((c['item'], c.get('count'), 'static') for c in self.contents(owner))

    @functools.lru_cache(None)
    def spawner_pool(self, spawner):
        """Weights of one random spawner. Handles the list forms the upstream spawner proc reads."""
        dm = self.dm
        pool = {}
        if self.is_a(spawner, '/obj/effect/spawner/random/maintenance'):
            pool = self.maintenance_pool()
            return pool, sum(pool.values())
        loot = dm.val(spawner, 'loot')
        if isinstance(loot, list):
            for entry in loot:
                if isinstance(entry, tuple) and len(entry) == 2:
                    if isinstance(entry[0], str):
                        pool[entry[0]] = entry[1] if isinstance(entry[1], (int, float)) else 1
                elif isinstance(entry, str):
                    pool[entry] = pool.get(entry, 0) + 1
        for field, sub in [('loot_type_path', False), ('loot_subtype_path', True)]:
            base = dm.val(spawner, field)
            if isinstance(base, str) and base.startswith('/'):
                for path in dm.paths(base):
                    if not sub or path != base:
                        pool.setdefault(path, 1)
        total = sum(pool.values())
        return pool, total

    @functools.lru_cache(None)
    def maintenance_pool(self):
        """GLOB.maintenance_loot flattened to item -> chance per pick, following its nested weighted lists."""
        def flatten(value, chance, out):
            if isinstance(value, str):
                if value.startswith('/obj/'):
                    out[value] = out.get(value, 0) + chance
                return
            if not isinstance(value, list) or not value:
                return
            weights = []
            for entry in value:
                if isinstance(entry, tuple) and len(entry) == 2:
                    weights.append((entry[0], entry[1] if isinstance(entry[1], (int, float)) else 1))
                else:
                    weights.append((entry, 1))
            total = sum(w for _, w in weights)
            for child, weight in weights:
                flatten(child, chance * weight / total, out)
        out = {}
        tiers = []
        table = self.global_expression('maintenance_loot')
        for key, weight in re.findall(r'GLOB\.(\w+)\s*=\s*(\w+)', table):
            tiers.append((key, self.dm.eval(weight)))
        total = sum(w for _, w in tiers if isinstance(w, (int, float)))
        for name, weight in tiers:
            sub, _ = self.global_list(name)
            if isinstance(weight, (int, float)) and total:
                flatten(sub, weight / total, out)
        return out

    def global_expression(self, name):
        for file in self.dm.files:
            text = clean_comments(self.dm.texts[file])
            match = re.search(r'GLOBAL_(?:LIST|ALIST)_INIT\(\s*' + name + r'\s*,', text)
            if match:
                depth = 1
                end = match.end()
                while end < len(text) and depth:
                    depth += {'(': 1, ')': -1}.get(text[end], 0)
                    end += 1
                return text[match.end():end]
        return ''

    def ladder_replaced(self, spawner_chain, item):
        """True when a floor spawner in the chain would swap this item out at runtime. weapon_ladder.dm."""
        if not item.startswith('/obj/item'):
            return False
        if not any(self.is_a(p, base) for p in spawner_chain for base in LADDER_REPLACED_SPAWNERS):
            return False
        return is_ladder_gun_or_melee(self.dm, item)

    def expand_container(self, owner, depth=0, seen=frozenset()):
        """Children and grandchildren, as (child, count or None, how, via chain)."""
        if depth > 3 or owner in seen:
            return []
        out = []
        for child, count, how in self.direct_children(owner):
            if not isinstance(child, str):
                continue
            out.append((child, count, how, (owner,)))
            for grand, grand_count, grand_how, via in self.expand_container(child, depth + 1, seen | {owner}):
                total = None if count is None or grand_count is None else rounded(count * grand_count)
                out.append((grand, total, grand_how, (owner,) + via))
        return out

    # ------------------------------------------------------------------ maps

    def played_hulls(self):
        """Hull templates that can be a player's ship: is_player_purchasable_ship() is the shelf, and is_roundstart_eligible_hull_type() rolls the fleet from what's on it.

        Every other template only spawns by admin verb, or for the NPC ships named by their shuttle_template.
        """
        dm = self.dm
        found = set()
        for template in dm.paths(HULL_BASE):
            if dm.val(template, 'abstract') == template or dm.val(template, 'player_hidden'):
                continue
            if dm.val(template, 'force_purchasable') or (dm.val(template, 'has_upgrade_slots') and (dm.val(template, 'upgrade_slot_ids') or dm.val(template, 'available_themes'))):
                found.add(template)
        return found

    def classify_maps(self):
        dm = self.dm
        npc_templates = set()
        for ship in dm.paths('/obj/structure/overmap/ship/npc'):
            template = dm.val(ship, 'shuttle_template')
            if isinstance(template, str):
                npc_templates.add(template)
        played = self.played_hulls()
        hulls, npc_hulls, unused_hulls = set(), set(), set()
        for template in dm.paths(HULL_BASE):
            suffix = dm.val(template, 'suffix')
            if suffix:
                (hulls if template in played else npc_hulls if template in npc_templates else unused_hulls).add(f'ship_{suffix}.dmm')
        for theme in dm.paths('/datum/ship_theme'):
            suffix = dm.val(theme, 'template_suffix')
            if suffix:
                (hulls if dm.val(theme, 'for_ship') in played else unused_hulls).add(f'ship_{suffix}.dmm')
        # The loader tries <base>_<theme>.dmm before <base>.dmm, so a themed file belongs to its base module.
        modules, unused_modules = set(), set()
        for module in dm.paths('/datum/ship_upgrade_module'):
            value = dm.val(module, 'map_file')
            if isinstance(value, str):
                (modules if dm.val(module, 'for_ship') in played else unused_modules).add(value.replace('\\', '/').rsplit('.', 1)[0])
        ruins = set()
        for ruin in dm.paths('/datum/map_template/ruin'):
            prefix, suffix = dm.val(ruin, 'prefix'), dm.val(ruin, 'suffix')
            if isinstance(prefix, str) and isinstance(suffix, str):
                ruins.add((prefix + suffix).replace('\\', '/'))
        self.classified = dict(played=played, hulls=hulls, npc_hulls=npc_hulls, unused_hulls=unused_hulls, modules=modules, unused_modules=unused_modules, ruins=ruins)

    def map_kind(self, rel):
        c = self.classified
        name = rel.split('/')[-1]
        if '/unit_tests/' in rel or '/backup/' in rel or '/test_modular/' in rel:
            return None
        if '/ships/' in rel:
            if name in c['hulls']:
                return 'hull'
            if name in c['npc_hulls']:
                return 'npc_ship'
            return 'hull_unused' if name in c['unused_hulls'] else 'hull_unreferenced'
        if '/ship_modules/' in rel:
            stem = rel.split('/ship_modules/', 1)[1].rsplit('.', 1)[0]
            if stem in c['modules'] or any(stem.startswith(base + '_') for base in c['modules']):
                return 'module'
            return 'module_unused' if stem in c['unused_modules'] or any(stem.startswith(base + '_') for base in c['unused_modules']) else 'module_unreferenced'
        if '/RandomRuins/' in rel:
            return 'ruin' if rel in c['ruins'] else 'ruin_unreferenced'
        if '/outposts/' in rel:
            return 'outpost'
        if '/events/' in rel:
            return 'event'
        if '/planets/' in rel:
            return 'planet'
        if '/shuttles/' in rel:
            return 'shuttle'
        return 'other'

    def build_maps(self):
        """In-scope folders only, counted by kind, with what containers hold."""
        self.classify_maps()
        roots = [self.root / '_maps/voidcrew', self.root / 'voidcrew/_maps']
        for base in roots:
            for file in sorted(base.rglob('*.dmm')):
                rel = file.relative_to(self.root).as_posix()
                kind = self.map_kind(rel)
                if not kind:
                    continue
                self.map_kinds[rel] = kind
                self.map_notes[kind] += 1
                self.read_map(rel, kind, file.read_text(encoding='utf-8', errors='replace'))

    def read_map(self, rel, kind, text):
        # A TGM key runs up to the next key or the grid. A plain dmm key sits on one line.
        defs = []
        starts = list(re.finditer(r'^"([^"\n]+)"\s*=\s*\((.*)$', text, re.M))
        for index, match in enumerate(starts):
            if match[2].strip():
                body = match[2].strip()[:-1]
                atoms = [part.strip() for part in split_top(body)]
            else:
                end = starts[index + 1].start() if index + 1 < len(starts) else text.find('\n(', match.end())
                body = text[match.end():end if end >= 0 else len(text)]
                atoms = re.findall(r'(?m)^(/(?:obj|mob)/[\w/]+)', body)
            defs.append((match[1], atoms))
        if not defs:
            return
        size = len(defs[0][0])
        counts = collections.Counter()
        for grid in re.finditer(r'\(\d+,\d+,\d+\)\s*=\s*\{"(.*?)"\}', text, re.S):
            for line in grid[1].splitlines():
                if line and len(line) % size == 0:
                    counts.update(line[x:x + size] for x in range(0, len(line), size))
        totals = collections.Counter()
        for key, atoms in defs:
            placed = counts[key]
            if not placed:
                continue
            for atom in atoms:
                match = re.match(r'/(?:obj|mob)/[\w/]+', atom)
                if match:
                    totals[match[0]] += placed
        for atom, placed in totals.items():
            self.place(atom, kind, rel, placed)

    def fixture_in_round(self, fixture):
        """Whether a machine or structure stands on a map that can appear in a round."""
        return any(kind in PLACED_KINDS for kind in self.placements.get(fixture, {}))

    def place(self, atom, kind, rel, count):
        if atom.startswith('/mob/'):
            if kind in PLACED_KINDS:
                self.mob_placements[atom] += count
            return
        self.placements[atom][kind]['direct'] += count
        self.placement_maps[atom][rel] += count
        if atom not in self.expanded:
            self.expanded[atom] = self.expand_container(atom)
        for child, child_count, how, via in self.expanded[atom]:
            if how == 'spawner' or any(p.startswith('/obj/effect/spawner') for p in via):
                if self.ladder_replaced(via, child):
                    self.placements[child][kind]['spawner_swapped_out'] += count
                    continue
                self.placements[child][kind]['spawner'] += count
                self.placement_expected[child][kind] += count * child_count if child_count is not None else 0
            else:
                self.placements[child][kind]['container'] += count
                if atom.startswith(('/obj/structure', '/obj/machinery')):
                    self.closet_hits[child][atom][kind] += count
            self.placement_maps[child][rel] += count

    # ------------------------------------------------------------------ mentions


    def build_mentions(self):
        items = set(self.dump)
        for file in self.dm.files:
            if '/unit_tests/' in file:
                continue
            text = clean_comments(self.dm.texts[file])
            voidcrew = file.startswith('voidcrew/')
            for line_text in text.splitlines():
                if 'istype(' in line_text or 'locate(' in line_text or 'ispath(' in line_text or 'typecacheof(' in line_text:
                    self.type_checked.update(match[0] for match in re.finditer(r'/obj/item/[\w/]+', line_text))
            for path, line in item_literals(text):
                if path in items:
                    if len(self.mentions[path]) < 8:
                        self.mentions[path].append(f'{file}:{line}')
                    if voidcrew:
                        self.voidcrew_mentions.add(path)
            if voidcrew:
                for match in re.finditer(r'/mob/[\w/]+', text):
                    self.voidcrew_mentions.add(match[0])

    # ------------------------------------------------------------------ loot

    def add_loot(self, item, **row):
        if isinstance(item, str):
            self.loot[item].append(row)

    def global_table(self, name):
        table, source = self.global_list(name)
        if isinstance(table, list):
            return {(e[0] if isinstance(e, tuple) else e): (e[1] if isinstance(e, tuple) else 1) for e in table}, source
        return {}, source

    def build_loot_channels(self):
        dm = self.dm
        # Ruin caches come from the theme tables, which the loot unit tests also pin.
        for item, rows in self.source_index.items():
            for row in rows:
                if row['kind'] == 'zone loot':
                    self.add_loot(item, channel='ruin', label='ruin cache', theme=row['theme'], tier=row['tier'],
                                  weight=row['weight'], pool_weight=row['pool_weight'], odds=row['frequency'],
                                  odds_note=row['frequency_note'], source=row['source'])
                elif row['kind'] == 'zone weapon loot':
                    self.add_loot(item, channel='ruin', label='ruin cache weapon roll', theme=row['theme'],
                                  weapon_class=row['weapon_class'], weight=row['weight'], pool_weight=row['pool_weight'],
                                  odds=row['frequency'], odds_note='chance per cache: theme gun chance x zone class odds x pool weight',
                                  source=row['source'], extra_source=row['extra_source'])
                elif row['kind'] == 'loot spare ammunition':
                    self.add_loot(item, channel='ruin', label='spare ammo with a cache gun', accompanying_gun=row['accompanying_gun'],
                                  theme=row['theme'], odds=row['frequency'], source=row['source'])
        self.build_freight()
        self.build_mission_prizes()
        self.build_lich_hoard()
        self.build_suit_storage()
        self.build_shuttle_loans()
        self.build_biome_features()
        seen = set()
        for file in self.dm.files:
            for pattern, channel, label in LOOT_FILES:
                if fnmatch.fnmatch(file, pattern):
                    text = clean_comments(dm.texts[file])
                    for path, line in item_literals(text):
                        key = (path, file, line)
                        if key in seen:
                            continue
                        seen.add(key)
                        for target, count, how, via in [(path, 1, 'literal', ())] + self.expand_container(path):
                            self.add_loot(target, channel=channel, label=label, literal=True, via=list(via), count=count,
                                          source=f'{file}:{line}')
                    break

    def build_freight(self):
        """Locked freight crates and the bought caches that use the same freight weapon profile."""
        file = 'voidcrew/modules/loot/abandoned_crate.dm'
        odds_source = self.dm.procs.get('/freight_weapon_pool', [('', '')])[0][0] or file
        for name, tier in [('abandoned_crate_common', 'common'), ('abandoned_crate_uncommon', 'uncommon'), ('abandoned_crate_prime', 'prime')]:
            table, source = self.global_table(name)
            total = sum(w for w in table.values() if isinstance(w, (int, float)))
            for item, weight in table.items():
                self.add_loot(item, channel='freight', label='locked freight crate', tier=tier, weight=weight, pool_weight=total,
                              odds=None, odds_note='tier pick then weight, without replacement; the crate draws 5-7 items', source=source)
                for child, count, how, via in self.expand_container(item):
                    self.add_loot(child, channel='freight', label='locked freight crate', tier=tier, weight=weight, pool_weight=total,
                                  via=list(via), count=count, odds=None, source=source)
        # Read the chances out of freight_weapon_pool(): the green values are the var defaults, then a switch by zone.
        code = self.dm.proc('/proc/freight_weapon_pool')
        head, _, rest = code.partition('switch(zone_type)')
        yellow_block, _, red_block = rest.partition('if(ZONE_RED)')
        def chances(block):
            return {name: int(re.search(name + r'\s*=\s*(\d+)', block)[1]) for name in ['gun_chance', 'gun_green', 'melee_green', 'melee_through_yellow']}
        by_zone = dict(green=chances(head), yellow=chances(yellow_block), red=chances(red_block))
        gun = {z: v['gun_chance'] / 100 for z, v in by_zone.items()}
        pools = [
            ('abandoned_crate_guns_green', 'gun', {z: gun[z] * v['gun_green'] / 1000 for z, v in by_zone.items()}),
            ('abandoned_crate_guns_yellow', 'gun', {z: gun[z] * (1000 - v['gun_green']) / 1000 for z, v in by_zone.items()}),
            ('abandoned_crate_melee_green', 'melee', {z: (1 - gun[z]) * v['melee_green'] / 1000 for z, v in by_zone.items()}),
            ('abandoned_crate_melee_yellow', 'melee', {z: (1 - gun[z]) * (v['melee_through_yellow'] - v['melee_green']) / 1000 for z, v in by_zone.items()}),
            ('abandoned_crate_melee_red', 'melee', {z: (1 - gun[z]) * (1000 - v['melee_through_yellow']) / 1000 for z, v in by_zone.items()}),
        ]
        for name, kind, zone_odds in pools:
            table, source = self.global_table(name)
            for item in table:
                self.add_loot(item, channel='freight', label='locked freight crate weapon roll', weapon=kind,
                              odds={z: rounded(p / max(1, len(table))) for z, p in zone_odds.items()},
                              odds_note='one weapon draw per crate, chance read from freight_weapon_pool', source=source,
                              odds_source=odds_source)

    def build_mission_prizes(self):
        dm = self.dm
        text = dm.proc('/proc/mission_prize_pool')
        source = dm.procs['/mission_prize_pool'][0][0]
        outcome = dm.proc('/proc/mission_prize_outcome')
        chance = {}
        for key, var in [('suit', 'suit_chance'), ('gadget', 'gadget_chance')]:
            m = re.search(var + r'\s*=\s*zone == ZONE_RED \? (\d+) : \(zone == ZONE_YELLOW \? (\d+) : (\d+)\)', outcome)
            chance[key] = dict(red=int(m[1]) / 1000, yellow=int(m[2]) / 1000, green=int(m[3]) / 1000)
        for category, marker in [('suit', 'suits = list('), ('gadget', 'gadgets = list(')]:
            block = text.split(marker, 1)[1].split('\n\t)', 1)[0]
            for family, values in re.findall(r'"(\w+)"\s*=\s*list\(([^)]*)\)', block):
                items = re.findall(r'/obj/[\w/]+', values)
                for item in items:
                    odds = {z: rounded(p / len(items)) for z, p in chance[category].items()}
                    if family in ('stake', 'lair'):
                        odds['green'] = 0
                    self.add_loot(item, channel='mission', label='guarded work prize', family=family, prize=category,
                                  odds=odds, odds_note='per completed job of this family; suits are capped per crew per round', source=source)

    def build_lich_hoard(self):
        table, source = self.global_table('lich_hoard_contents')
        for item in table:
            self.add_loot(item, channel='boss', label='lich', odds=None, odds_note='hoard pays every entry; the staff needs a 25% roll at spawn', source=source)

    def build_suit_storage(self):
        table, source = self.global_table('base_tier_modsuits')
        for item in table:
            self.add_loot(item, channel='ruin', label='ruin suit storage', odds={'green': rounded(1 / max(1, len(table))), 'yellow': 0, 'red': 0},
                          odds_note='per unit, stocked by zone', source=source)
        text = self.dm.proc('/obj/machinery/suit_storage_unit/ruin_zone/stock_for_zone')
        for zone, item in re.findall(r'if\(ZONE_(RED|YELLOW)\)\s*\n\s*mod_type = (/obj/[\w/]+)', text):
            odds = {'green': 0, 'yellow': 0, 'red': 0, zone.lower(): 1}
            self.add_loot(item, channel='ruin', label='ruin suit storage', odds=odds, odds_note='per unit, stocked by zone',
                          source=self.dm.procs['/obj/machinery/suit_storage_unit/ruin_zone/stock_for_zone'][0][0])

    def build_shuttle_loans(self):
        """What a shuttle loan can bring. Each offer's spawn_items names its goods, in lists or directly, and can hand over a whole supply pack."""
        dm = self.dm
        table, _ = self.global_list('voidcrew_shuttle_loans')
        for loan in paths(table):
            for source, code in dm.procs.get(f'{loan}/spawn_items', []):
                file, first = source.rsplit(':', 1)
                goods = list(item_literals(code))
                for pack in re.findall(r'/datum/supply_pack/[\w/]+', code):
                    goods += [(item, code[:code.index(pack)].count('\n') + 1) for item in paths(dm.val(pack, 'contains'))]
                for path, line in goods:
                    for target, count, _, via in [(path, 1, 'direct', ())] + self.expand_container(path):
                        self.add_loot(target, channel='event', label='shuttle loan', loan=loan, via=list(via), count=count, source=f'{file}:{int(first) + line - 1}')

    def build_biome_features(self):
        """What a planet's ground can spawn: the feature and flora tables of every biome a planet's overworld or caves use, and what a crate in those tables holds.

        A random spawner in a table is left out. The one there is the maintenance pool, which map placements already count, and it would put this channel on hundreds of rows.
        """
        dm = self.dm
        used = set()
        for planet in dm.paths('/datum/planet'):
            for field in ('overworld_biomes', 'cave_biomes'):
                used.update(path for path in paths(dm.val(planet, field)) if path.startswith('/datum/biome'))
        for biome in sorted(used):
            for field, chance in (('feature_spawn_list', 'feature_spawn_chance'), ('flora_spawn_list', 'flora_spawn_chance')):
                table = assoc(dm.val(biome, field))
                total = sum(weight for weight in table.values() if isinstance(weight, (int, float)))
                for item, weight in table.items():
                    if not isinstance(item, str) or not item.startswith(('/obj/item', '/obj/structure/closet')):
                        continue
                    for target, count, _, via in [(item, 1, 'direct', ())] + self.expand_container(item):
                        self.add_loot(target, channel='biome', label='planet ground', biome=biome, weight=weight, pool_weight=total, chance_per_turf=dm.val(biome, chance),
                                      via=list(via), count=count, source=dm.field(biome, field).source)

    def build_mob_drops(self):
        dm = self.dm
        for mob in dm.paths('/mob/living'):
            for field, how in MOB_LOOT_FIELDS.items():
                declared = dm.field(mob, field)
                if not declared.source:
                    continue
                value = dm.val(mob, field)
                entries = []
                if isinstance(value, list):
                    for entry in value:
                        if isinstance(entry, tuple) and len(entry) == 2:
                            entries.append(entry)
                        else:
                            entries.append((entry, None))
                elif isinstance(value, str):
                    entries.append((value, None))
                total = len(entries)
                for item, weight in entries:
                    if not isinstance(item, str) or not item.startswith('/obj/'):
                        continue
                    reachable = self.mob_placements[mob] > 0 or mob in self.voidcrew_mentions
                    for target, count, why, via in [(item, 1, 'direct', ())] + self.expand_container(item):
                        self.add_loot(target, channel='npc', label=how, mob=mob, field=field, entry_weight=weight, pool_size=total,
                                      map_placements=self.mob_placements[mob], mob_referenced_by_voidcrew=mob in self.voidcrew_mentions,
                                      reachable=reachable, via=list(via), count=count, source=declared.source)

    def build_mob_code_drops(self):
        """Drops written into mob procs and static lists rather than the usual vars. Citations, no odds."""
        dm = self.dm
        for mob in dm.paths('/mob/living'):
            for key, declared in dm.types.get(mob, {}).items():
                if key in MOB_LOOT_FIELDS or not re.search(r'loot|drop|jackpot|reward|hoard|prize', key):
                    continue
                for path in re.findall(r'/obj/item/[\w/]+', declared.raw):
                    for target, count, _, via in [(path, 1, 'direct', ())] + self.expand_container(path):
                        self.add_loot(target, channel='npc', label='mob drop list', mob=mob, field=key, via=list(via), count=count,
                                      map_placements=self.mob_placements[mob], reachable=self.mob_placements[mob] > 0 or mob in self.voidcrew_mentions,
                                      source=declared.source)
        for key, bodies in dm.procs.items():
            if not key.startswith('/mob/living/'):
                continue
            mob = key.rsplit('/', 1)[0]
            for source, code in bodies:
                file, first = source.rsplit(':', 1)
                if '/unit_tests/' in file:
                    continue
                for path, offset in item_literals(code):
                    if not path.startswith('/obj/item'):
                        continue
                    for target, count, _, via in [(path, 1, 'direct', ())] + self.expand_container(path):
                        self.add_loot(target, channel='npc', label='mob code', mob=mob, literal=True, via=list(via), count=count,
                                      map_placements=self.mob_placements[mob], reachable=self.mob_placements[mob] > 0 or mob in self.voidcrew_mentions,
                                      source=f'{file}:{int(first) + offset - 1}')

    def build_outfits(self):
        dm = self.dm
        for base, field in [('/datum/ship_theme', 'job_slots'), ('/datum/ship_upgrade_module', 'job_slots_add'), ('/datum/map_template/shuttle/voidcrew', 'job_slots')]:
            for owner in dm.paths(base):
                for job in dm.val(owner, field) or []:
                    self.use_outfit(owner, field, job)
        for module in dm.paths('/datum/ship_upgrade_module'):
            for _, crew in assoc(dm.val(module, 'job_slots_add_by_theme')).items():
                for job in crew or []:
                    self.use_outfit(module, 'job_slots_add_by_theme', job)

    def use_outfit(self, owner, field, job):
        data = assoc(job)
        outfit = data.get('outfit')
        if not isinstance(outfit, str):
            return
        hull = self.dm.val(owner, 'for_ship') or owner
        self.outfit_uses[outfit].append(dict(owner=owner, hull=hull, job=data.get('name'), slots=data.get('slots')))

    @functools.lru_cache(None)
    def outfit_items(self, outfit):
        """Items an outfit hands out, from its fields and from literal paths in its equip procs, as (item, field, source, whether it only happens sometimes)."""
        dm = self.dm
        found = []
        for field in OUTFIT_FIELDS:
            declared = dm.field(outfit, field)
            for item in paths(dm.val(outfit, field)):
                if item.startswith('/obj/'):
                    found.append((item, field, declared.source, False))
        for method in ['pre_equip', 'post_equip']:
            for source, code in proc_chain(dm, outfit, method):
                for match in re.finditer(r'/obj/item/[\w/]+', code):
                    found.append((match[0], method, source, under_condition(code, match.start())))
        return tuple(dict.fromkeys(found))

    def starting_index(self):
        """item -> outfit rows, for the jobs on hulls that can be a player's ship. Built once, because many jobs share an outfit. An outfit only on other hulls goes in unused_outfits."""
        index = collections.defaultdict(list)
        self.unused_outfits = collections.defaultdict(list)
        for outfit, uses in self.outfit_uses.items():
            played = [use for use in uses if use['hull'] in self.classified['played']]
            table = index if played else self.unused_outfits
            hulls = sorted({str(u['hull']) for u in played or uses})
            jobs = sorted({str(u['job']) for u in played or uses})
            for item, field, source, conditional in self.outfit_items(outfit):
                for target, count, _, via in [(item, 1, 'direct', ())] + self.expand_container(item):
                    row = dict(kind='outfit', outfit=outfit, field=field, hulls=len(hulls), hull_sample=hulls[:6], jobs=jobs[:6], via=list(via), count=count, source=source)
                    if conditional:
                        row['conditional'] = True
                    table[target].append(row)
        return index

    def vendor_index(self):
        """item -> vending machines that carry it, with where those machines are placed."""
        dm = self.dm
        index = collections.defaultdict(list)
        for machine in dm.paths('/obj/machinery/vending'):
            where = {kind: sum(modes.values()) for kind, modes in self.placements.get(machine, {}).items()}
            stock = [(field, assoc(dm.val(machine, field))) for field in ['products', 'contraband', 'premium']]
            # Newer vendors keep their stock in named categories rather than `products`.
            for category in dm.val(machine, 'product_categories') or []:
                stock.append(('product_categories', assoc(assoc(category).get('products'))))
            for field, goods in stock:
                for item, count in goods.items():
                    if not isinstance(item, str):
                        continue
                    for target, n, _, via in [(item, 1, 'direct', ())] + self.expand_container(item):
                        index[target].append(dict(kind='vendor', machine=machine, field=field, stock=count, placed=where,
                                                  via=list(via), count=n, source=dm.field(machine, field).source))
        return index

    def loadout_index(self):
        """item -> character setup entries. A player picks these before joining."""
        dm = self.dm
        index = collections.defaultdict(list)
        for entry in dm.paths('/datum/loadout_item'):
            if dm.val(entry, 'abstract_type') == entry:
                continue
            item = dm.val(entry, 'item_path')
            if isinstance(item, str):
                index[item].append(dict(kind='loadout', entry=entry, name=dm.val(entry, 'name'), source=dm.field(entry, 'item_path').source))
        return index

    def sources_for(self, path, row):
        """Every route for one item path, built on StaticSources.routes(). A key appears only when it has something."""
        out = self.routes(path)
        key = self.merge_key(path)

        loot = [dict(value, produced=produced) if produced != path else value for produced, value in self.loots.get(key, [])]
        if loot:
            out['loot'] = loot

        # Starting gear is what a crew finds on its own ship. A ruin's vending machine or an enemy ship's locker is a find.
        vendors = list(self.vendors.get(path, []))
        ship_vendors = [v for v in vendors if any(kind in PLAYER_SHIP_KINDS for kind in v['placed'])]
        field_vendors = [v for v in vendors if v not in ship_vendors and any(kind in PLACED_KINDS for kind in v['placed'])]
        unplaced = [v for v in vendors if v not in ship_vendors and v not in field_vendors]
        starting = list(self.starting.get(path, [])) + list(self.loadouts.get(path, [])) + ship_vendors
        if unplaced:
            out['unplaced_vendors'] = unplaced
        if field_vendors:
            out['field_vendors'] = field_vendors
        lockers = self.closet_hits.get(path)
        if lockers:
            for container, kinds in lockers.items():
                if any(kinds.get(kind) for kind in PLAYER_SHIP_KINDS):
                    starting.append(dict(kind='locker', container=container, placed=dict(kinds)))
        if starting:
            out['starting'] = starting
        unused = self.unused_outfits.get(path)
        if unused:
            out['unused_outfits'] = unused

        placed = self.placements.get(path)
        if placed:
            maps = self.placement_maps.get(path, {})
            by_kind = collections.Counter(self.map_kinds[m] for m in maps)
            maps = {m: count for m, count in maps.items() if self.map_kinds[m] in PLACED_KINDS}
            top = sorted(maps.items(), key=lambda kv: (-kv[1], kv[0]))
            kinds_summary = {}
            for kind, modes in placed.items():
                kinds_summary[kind] = {mode: count for mode, count in modes.items()}
                expected = self.placement_expected.get(path, {}).get(kind)
                if expected:
                    kinds_summary[kind]['spawner_expected'] = rounded(float(expected))
            out['maps'] = dict(by_kind=kinds_summary, distinct_maps=len(maps), distinct_by_kind=dict(sorted(by_kind.items())), top_maps=[dict(map=m, count=c) for m, c in top[:8]])

        units = 1
        if self.is_a(path, '/obj/item/stack'):
            amount = (row.get('vars') or {}).get('amount')
            units = amount if isinstance(amount, (int, float)) and amount > 0 else (self.dm.val(path, 'amount') or 1)
        sale = {}
        exports = []
        for e in self.exports(path, units):
            exports.append(dict(entry=e['entry'], initial_credits=e['initial_credits'], amount=e['amount'], conditional=e['conditional'], source=e['source']))
        if exports:
            sale['exports'] = exports
        buybacks = []
        for b in self.buybacks(path, units, None):
            buybacks.append(dict(kind=b['kind'], shop=b['shop'], entry=b['entry'], amount=b['amount'], credits_per_sale=b['credits_per_sale'],
                                 vouchers_per_sale=b['vouchers_per_sale'], demand=b['demand'], demand_max=b['demand_max'],
                                 blocked_or_conditional=b['blocked_or_conditional'], source=b['source']))
        if buybacks:
            sale['buybacks'] = buybacks
        if sale:
            out['sale'] = sale

        barred = self.blocked.get(path)
        if barred:
            out['cargo_barred'] = barred

        mentions = self.mentions.get(path)
        if mentions:
            out['code_mentions'] = mentions
        return out
