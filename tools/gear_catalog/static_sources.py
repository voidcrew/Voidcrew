"""The routes that can be read from source alone: shops, cargo, printing, crafting and research.

Importing this runs nothing. load_static(root) needs only a checkout: no dump, no compiler, no world.
"""
from __future__ import annotations

import collections
import functools
import json
import math
import re

from .dm_reader import DM, assoc, balance, clean_comments, decode, enclosing_lines, number, paths, proc_chain, rounded, split_top
from .offers import PEDDLER_SHOP, load_offers

PERMISSION = {0: 'public', 1: 'yellow', 2: 'advanced', 3: 'elite'}
# Procs a player runs by using a thing. What one makes with new is something that item turns into, or gives you.
USE_PROCS = re.compile(r'/(attackby|attackby_secondary|item_interaction|item_interaction_secondary|attack_self|attack_self_secondary|\w+_act|\w+_act_secondary|tool_act|click_alt|interact_with_atom\w*)$')
# /datum/stack_recipe/New's arguments, in order.
STACK_RECIPE_ARGS = ['title', 'result_type', 'req_amount', 'res_amount', 'max_res_amount', 'time', 'crafting_flags', 'placement_checks', 'trait_booster', 'trait_modifier', 'category']


def pack_counts(contained):
    """How many of each type a supply pack ships. contains is a plain list, which may repeat a type, or an assoc list of type = count (fill() in _packs.dm)."""
    counts = collections.Counter()
    for entry in contained if isinstance(contained, list) else []:
        if isinstance(entry, list) and len(entry) == 2 and isinstance(entry[0], str) and isinstance(entry[1], (int, float)):
            counts[entry[0]] += entry[1]
        else:
            counts.update(paths(entry))
    return counts


def handed_back(code, path, offset):
    """Whether a proc takes this item in and gives it back under a tool: a screwdriver opens a securitron assembly and the sword that went in drops out."""
    takes_it = re.search(r'istype\(\s*\w+\s*,\s*' + re.escape(path) + r'\s*\)', code)
    return bool(takes_it) and any('tool_behaviour' in line for line in enclosing_lines(code, offset))


def closing_paren(text, start):
    """The offset just past the bracket that closes one opened right before start. Quotes hide brackets, up to the end of their line."""
    end, depth, quote, escaped = start, 1, None, False
    while end < len(text) and depth:
        c = text[end]
        if quote:
            if escaped: escaped = False
            elif c == '\\': escaped = True
            elif c == quote or c == '\n': quote = None
        elif c in '\"\'': quote = c
        elif c == '(': depth += 1
        elif c == ')': depth -= 1
        end += 1
    return end


def global_list_spans(text):
    """(name, start, end) of each GLOBAL_LIST_INIT in a file's comment-free text."""
    for m in re.finditer(r'GLOBAL_(?:LIST|ALIST)_INIT\(\s*(\w+)\s*,', text):
        yield m[1], m.start(), closing_paren(text, m.end())


def stack_recipe_args(args):
    """A stack recipe's arguments by name, whether written in order or as name = value."""
    named = {}
    for position, arg in enumerate(args):
        key, sep, value = arg.partition('=')
        if sep and re.fullmatch(r'\s*\w+\s*', key) and not value.startswith('='):
            named[key.strip()] = value.strip()
        elif position < len(STACK_RECIPE_ARGS):
            named[STACK_RECIPE_ARGS[position]] = arg
    return named


def stack_owner_before(text, offset):
    """The stack whose proc body holds a recipe written outside any GLOB list."""
    heads = re.findall(r'^(/obj/item/stack[\w/]*)/\w+\(', text[:offset], re.M)
    return heads[-1:]


class StaticSources:
    def __init__(self, root):
        self.dm = DM(root)
        self.root = self.dm.root
        self.catalog, self.buys, self.packs, self.rejected = load_offers(self.dm)
        self.sheet = self.dm.eval('SHEET_MATERIAL_AMOUNT')
        self.market = {'diamond': 120, 'bluespace': 80, 'gold': 40, 'titanium': 40,
                       'uranium': 30, 'silver': 15, 'iron': 2, 'glass': 2}
        self.market = {'/datum/material/' + k: v for k, v in self.market.items()}
        # Plasma isn't on the market list; its actual export bid has a separate cap.
        self.market['/datum/material/plasma'] = self.dm.val('/datum/material/plasma', 'value_per_unit') * self.sheet
        self.source_index = collections.defaultdict(list)
        policy = self.root / 'tools/gear_catalog/policy.json'
        self.ordinary = [row['path'] for row in json.loads(policy.read_text(encoding='utf-8')).get('ordinary_ingredients') or []] if policy.exists() else []
        self.build_nodes()
        self.build_teachers()
        self.build_design_disks()
        self.build_sources()
        self.build_route_indexes()
        self.build_made_by_use()

    def cite(self, file, text):
        return self.dm.cite(file, text)

    @functools.lru_cache(None)
    def ancestors(self, p):
        result = set()
        while p and p not in result:
            result.add(p)
            p = self.dm.parent(p)
        return frozenset(result)

    def is_a(self, p, base):
        return base in self.ancestors(p)


    def build_nodes(self):
        self.nodes = collections.defaultdict(list)
        self.node_details = {}
        self.node_by_id = {}
        for p in self.dm.paths('/datum/techweb_node'):
            ident = self.dm.val(p, 'id')
            self.node_by_id[ident] = p
            costs = assoc(self.dm.val(p, 'research_costs'))
            points = sum(v for v in costs.values() if isinstance(v, (int, float)))
            # A cost-tier, not graph depth. Prerequisites are retained separately.
            tier = points / 40 if points and points % 40 == 0 and points <= 200 else None
            node = dict(type=p, id=ident, name=self.dm.val(p, 'display_name'),
                        tier=rounded(tier), tier_basis='research_costs / TECHWEB_TIER_1_POINTS; not prerequisite depth',
                        point_cost=costs, starting_node=self.dm.val(p, 'starting_node'),
                        prereqs=self.dm.val(p, 'prereq_ids'), surveys=self.dm.val(p, 'required_surveyed_objects'),
                        experiments=self.dm.val(p, 'required_experiments'), hidden=self.dm.val(p, 'hidden'),
                        experimental=self.dm.val(p, 'experimental'), source=self.dm.loc(p),
                        zone_permission=self.dm.val(p, 'zone_permission'),
                        design_list_sources=[s for _, _, s in self.dm.node_ops.get(p, [])],
                        cost_source=self.dm.field(p, 'research_costs').source)
            self.node_details[ident] = node
            for d in self.dm.node_designs(p):
                if isinstance(d, str):
                    self.nodes[d].append(node)
        for node in self.node_details.values():
            pending = [node['id']]
            closure = set()
            while pending:
                ident = pending.pop()
                if ident in closure or ident not in self.node_details:
                    continue
                closure.add(ident)
                current = self.node_details[ident]
                if not current['starting_node']:
                    pending.extend(current['prereqs'] or [])
            required = [self.node_details[x] for x in sorted(closure) if not self.node_details[x]['starting_node']]
            node['total_prerequisite_points_including_self'] = sum(sum(x for x in n['point_cost'].values() if isinstance(x,(int,float))) for n in required)
            node['early_without_extra_gates'] = all((n['tier'] or 99) <= 2 and not n['surveys'] and not n['experiments'] and not n['hidden'] and not n['experimental'] for n in required) and node['total_prerequisite_points_including_self'] <= 400
        self.settle_research()

    def settle_research(self):
        """Which nodes a crew can open by spending points, each with the lowest reputation step that gets there.

        A hidden node stays shut until a disk, an experiment or an emag opens it, and so does everything behind it. The one way in by plain research: learning a design
        takes every other node that grants it out of hidden_nodes (add_design(), _techweb.dm), so a hidden node sharing a design with an open one opens with it.
        """
        sharing = collections.defaultdict(set)
        for owners in self.nodes.values():
            for node in owners:
                sharing[node['id']].update(other['id'] for other in owners if other['id'] != node['id'])
        self.research_steps = {}
        changed = True
        while changed:
            changed = False
            for ident, node in self.node_details.items():
                prereqs = [] if node['starting_node'] else [p for p in node['prereqs'] or [] if p in self.node_details]
                if any(p not in self.research_steps for p in prereqs):
                    continue
                permission = node.get('zone_permission')
                step = max([permission if isinstance(permission, (int, float)) else 0] + [self.research_steps[p] for p in prereqs])
                if node['hidden'] and not node['starting_node']:
                    openers = [self.research_steps[other] for other in sharing[ident] if other in self.research_steps]
                    if not openers:
                        continue
                    step = max(step, min(openers))
                if self.research_steps.get(ident, step + 1) > step:
                    self.research_steps[ident] = step
                    changed = True
        for ident, node in self.node_details.items():
            node['hidden_with_prereqs'] = ident not in self.research_steps
            node['opened_by'] = sorted(other for other in sharing[ident] if other in self.research_steps) if node['hidden'] and ident in self.research_steps else []

    def mat_value(self, materials):
        """Value materials at the market rates above; retain unpriced materials explicitly."""
        total = 0
        unpriced = {}
        for mat, amt in materials.items():
            if not isinstance(amt, (int, float)):
                unpriced[mat] = amt
            elif mat in self.market:
                total += amt / self.sheet * self.market[mat]
            elif self.is_a(mat, '/datum/material/alloy'):
                composition = assoc(self.dm.val(mat, 'composition'))
                v, unknown = self.mat_value({m: a * amt for m, a in composition.items()})
                total += v
                unpriced.update(unknown)
            else:
                unpriced[mat] = amt
        return rounded(total), unpriced

    @functools.lru_cache(None)
    def materials(self, item):
        field = 'mats_per_unit' if self.is_a(item, '/obj/item/stack') else 'custom_materials'
        mats = assoc(self.dm.val(item, field))
        if self.is_a(item, '/obj/item/ammo_box'):
            # Ordinary magazines/boxes shrink their declared shell composition on
            # Initialize. Lazy stored_ammo is separate, never a whole print refund.
            mats = {m: a * .1 if isinstance(a, (int, float)) else a for m, a in mats.items()}
        return mats, self.dm.field(item, field).source

    def add_source(self, item, kind, **data):
        if isinstance(item, str) and item.startswith(('/obj/', '/mob/')):
            self.source_index[item].append(dict(kind=kind, produced_path=item, evidence='CODE', **data))

    def build_sources(self):
        dm = self.dm
        machines = [(x, dm.eval(x)) for x in ['AUTOLATHE', 'PROTOLATHE', 'IMPRINTER', 'MECHFAB', 'SMELTER', 'BIOGENERATOR', 'LIMBGROWER']]
        extra = {'c9mm', 'c10mm', 'c45', 'strilka310_surplus'}
        for p in dm.paths('/datum/design'):
            item = dm.val(p, 'build_path')
            build = dm.val(p, 'build_type')
            if not item or not isinstance(build, int):
                continue
            ms = [name for name, bit in machines if isinstance(bit, int) and bit > 0 and build & bit]
            if not ms:
                continue
            ident = dm.val(p, 'id')
            cats = dm.val(p, 'category') or []
            initial = (dm.eval('RND_CATEGORY_INITIAL') in cats and any(x in ms for x in ['AUTOLATHE','SMELTER','BIOGENERATOR','LIMBGROWER'])) or ident in extra
            hacked = dm.eval('RND_CATEGORY_HACKED') in cats
            nodes = self.nodes.get(ident, [])
            disks = self.design_disks.get(p, [])
            if initial or any(n['starting_node'] for n in nodes):
                unlock = 'roundstart'
            elif hacked and 'AUTOLATHE' in ms:
                unlock = 'hacked autolathe'
            elif any(not n['hidden_with_prereqs'] for n in nodes):
                unlock = 'research'
            elif nodes:
                unlock = 'hidden research'
            elif disks:
                unlock = 'design disk'
            else:
                unlock = 'no active research node / disk or special unlock required'
            mats = assoc(dm.val(p, 'materials'))
            value, unpriced = self.mat_value(mats)
            auto = 'AUTOLATHE' in ms
            coeff = 1 if self.is_a(item, '/obj/item/stack') or not auto else 1.6
            self.add_source(item, 'design', design=p, id=ident, machines=ms, material_cost_cm3=mats,
                            material_base_value=value, unpriced_materials=unpriced,
                            initial_machine_coefficient=coeff, initial_machine_material_value=rounded(value * coeff),
                            unlock=unlock, nodes=nodes, disks=disks, reagents=dm.val(p, 'reagents_list'),
                            source=dm.loc(p), cost_source=dm.field(p, 'materials').source,
                            coefficient_source=self.cite('code/game/machinery/autolathe.dm', 'var/creation_efficiency = 1.6') if auto else self.cite('code/modules/research/machinery/_production.dm', 'var/efficiency_coeff = 1'))
        for p in dm.paths('/datum/crafting_recipe'):
            for item in paths(dm.val(p, 'result')):
                reqs = assoc(dm.val(p, 'reqs'))
                material_cost = collections.Counter()
                unknown = {}
                for req, count in reqs.items():
                    mats, _ = self.materials(req)
                    if not mats or not isinstance(count, (int, float)):
                        unknown[req] = count
                    else:
                        for mat, amt in mats.items():
                            if isinstance(amt, (int, float)):
                                material_cost[mat] += amt * count
                value, unpriced = self.mat_value(material_cost)
                self.add_source(item, 'crafting', recipe=p, requirements=reqs, tools=dm.val(p, 'tool_behaviors'),
                                learned_from=self.teachers.get(p, []),
                                tool_paths=paths(dm.val(p, 'tool_paths')), machinery=[x for x in paths(dm.val(p, 'machinery')) if x.startswith('/obj/')],
                                structures=[x for x in paths(dm.val(p, 'structures')) if x.startswith('/obj/')],
                                uses_up=self.used_up_fixtures(p),
                                made_empty=bool(dm.val(p, 'delete_contents')) and self.filled_storage(item),
                                time_deciseconds=dm.val(p, 'time'),
                                always_available=not self.must_be_learned(p), material_base_value=value,
                                unpriced_inputs={**unknown, **unpriced}, source=dm.loc(p))
        self.build_stack_recipes()
        for pack in self.packs:
            count = pack_counts(decode(pack['contains']))
            cost = number(pack['cost'])
            dynamic = 'fill' in pack['notes'].lower() or 'random' in pack['notes'].lower()
            for item, n in count.items():
                units = (dm.val(item, 'amount') or 1) if self.is_a(item, '/obj/item/stack') else 1
                self.add_source(item, 'cargo', pack=pack['pack_type'], name=pack['name'], pack_cost=cost,
                                count=n, units_per_stack=units, price_per_unit=rounded(cost / n / units) if cost else None,
                                price_semantics='whole pack cost allocated to matching units; other goods not credited',
                                availability=pack['availability'], runtime_fill=dynamic, notes=pack['notes'],
                                source=pack['source'])
        self.build_loot()
        self.build_misc_sources()

    def build_stack_recipes(self):
        """Recipes made from a stack in hand: inline new /datum/stack_recipe(...), nearly all in a GLOB list that a stack's get_main_recipes() adds to its own."""
        dm = self.dm
        owners = collections.defaultdict(list)
        for key, bodies in dm.procs.items():
            if key.endswith('/get_main_recipes'):
                for _, code in bodies:
                    for name in re.findall(r'GLOB\.(\w+)', code):
                        owners[name].append(key.rsplit('/', 1)[0])
        for file in dm.files:
            if '/unit_tests/' in file:
                continue
            text = clean_comments(dm.texts[file])
            if 'stack_recipe' not in text:
                continue
            spans = list(global_list_spans(text))
            for m in re.finditer(r'new\s*/datum/stack_recipe(?:/[\w/]+)?\(', text):
                args = stack_recipe_args(split_top(text[m.end():closing_paren(text, m.end()) - 1]))
                item = dm.eval(args.get('result_type', ''))
                name = next((name for name, start, end in spans if start <= m.start() < end), None)
                stacks = sorted(set(owners.get(name, []))) if name else stack_owner_before(text, m.start())
                self.add_source(item, 'stack crafting', name=dm.eval(args.get('title', '')), req_amount=dm.eval(args.get('req_amount', '1')), result_amount=dm.eval(args.get('res_amount', '1')),
                                input_context=stacks[0] if stacks else '', input_stacks=stacks, made_empty=self.is_a(item, '/obj/item/storage') and self.filled_storage(item),
                                source=f'{file}:{text.count(chr(10),0,m.start())+1}')

    def filled_storage(self, item):
        """Whether this type starts with something in it and is storage. The game empties storage it has just crafted: produce_recipe() for a stack's, delete_contents for a recipe's."""
        if not isinstance(item, str) or not item.startswith('/obj/item'):
            return False
        storage = self.is_a(item, '/obj/item/storage') or self.dm.val(item, 'storage_type') or any('create_storage(' in code for _, code in proc_chain(self.dm, item, 'Initialize'))
        return bool(storage and self.contents(item))

    def build_made_by_use(self):
        """Item -> the items that turn into it when used: a sliced pipe into a pipe bomb, a helmet into a securitron. It only counts once the item used has a route."""
        self.made_by_use = collections.defaultdict(list)
        for key, bodies in self.dm.procs.items():
            if not key.startswith('/obj/item/') or not USE_PROCS.search(key):
                continue
            owner = key.rsplit('/', 1)[0]
            for source, code in bodies:
                made = set()
                for match in re.finditer(r'\bnew\s+(/obj/item/[\w/]+)\s*\(|\bvar/(obj/item/[\w/]+)/\w+\s*=\s*new\s*\(', code):
                    path = match[1] or '/' + match[2]
                    if path != owner and not handed_back(code, path, match.start()):
                        made.add(path)
                for path in sorted(made):
                    self.made_by_use[path].append(dict(from_item=owner, source=source))

    def build_design_disks(self):
        """Design type -> the design disks that carry it. A disk fills blueprints in Initialize from a literal type, a var holding one, or a list var."""
        dm = self.dm
        self.design_disks = collections.defaultdict(list)
        for disk in dm.paths('/obj/item/disk/design_disk'):
            found = set()
            for _, code in proc_chain(dm, disk, 'Initialize'):
                for written in re.findall(r'blueprints\s*\+=\s*new\s+([\w/]+)', code):
                    found.update(paths(written) if written.startswith('/') else paths(dm.val(disk, written)))
                for name in re.findall(r'\bfor\s*\(\s*var/\w+\s+in\s+(\w+)\s*\)', code):
                    found.update(paths(dm.val(disk, name)))
            for design in found:
                if self.is_a(design, '/datum/design'):
                    self.design_disks[design].append(disk)

    def build_misc_sources(self):
        dm = self.dm
        # Hull themes and selected modules explicitly assign crew outfits.
        for p in dm.paths('/obj/item/seeds'):
            product = dm.val(p, 'product')
            self.add_source(product, 'hydroponics', seed=p, yield_per_harvest=dm.val(p, 'yield'),
                            maturation=dm.val(p, 'maturation'), production=dm.val(p, 'production'),
                            source=dm.field(p, 'product').source)
            for mutant in paths(dm.val(p, 'mutatelist')):
                self.add_source(mutant, 'seed mutation', parent_seed=p, source=dm.field(p, 'mutatelist').source)
        for p in dm.paths('/obj/item/food'):
            for field in ['slice_type', 'trash_type']:
                self.add_source(dm.val(p, field), 'food processing', input=p, action=field,
                                quantity=dm.val(p, 'slices_left') if field == 'slice_type' else 1,
                                source=dm.field(p, field).source)
        # Selected-theme assembly gives the same capabilities but not the
        # pre_equipped subtype or its bundled modules (important for procurement).
        wanted = set(p for r in self.catalog for p in paths(decode(r['item_path'])))
        for p in sorted(wanted):
            if self.is_a(p, '/obj/item/mod/control/pre_equipped'):
                theme = dm.val(p, 'theme')
                platings = [x for x in dm.paths('/obj/item/mod/construction/plating') if dm.val(x, 'theme') == theme]
                if platings:
                    self.add_source(p, 'MOD assembly alternative', theme=theme, plating=platings,
                                    frame_parts=['/obj/item/mod/construction/shell','/obj/item/mod/construction/helmet','/obj/item/mod/construction/chestplate','/obj/item/mod/construction/gauntlets','/obj/item/mod/construction/boots'],
                                    output='/obj/item/mod/control', source=self.cite('code/modules/mod/mod_construction.dm', 'external_plating.theme, null, core'),
                                    note='bare assembled control; requires core/cell and separate modules; not a procurement-valid pre_equipped subtype')
        for p in dm.paths('/obj/effect/anomaly'):
            core = dm.val(p, 'anomaly_core')
            if core:
                self.add_source(core, 'anomaly neutralization', anomaly=p, source=dm.field(p, 'anomaly_core').source,
                                note='processed core, not a raw core; planet/chart encounter and successful stabilization required')
        raw = [p for p in dm.paths('/obj/item/raw_anomaly_core') if p not in ['/obj/item/raw_anomaly_core','/obj/item/raw_anomaly_core/random']]
        for p in raw:
            self.add_source(p, 'random raw anomaly core', from_item='/obj/item/raw_anomaly_core/random',
                            eventual_probability=1/len(raw), source=self.cite('code/modules/research/anomaly/raw_anomaly.dm', 'pick(subtypesof(/obj/item/raw_anomaly_core))'),
                            frequency_note='uniform concrete subtypes, accounting for placeholder self-rerolls; research prime pool has random core weight 4')
        self.add_source('/obj/item/food/honeycomb', 'beekeeping', source=self.cite('code/modules/hydroponics/beekeeping/beebox.dm', 'honeycomb/new_comb = new(src)'),
                        frequency_note='working apiary; runtime frames, queen, bee health and processing')
        for suffix, warhead in [('light','/obj/item/bombcore/missile/light'),('standard','/obj/item/bombcore/missile'),('heavy','/obj/item/bombcore/missile/heavy')]:
            self.add_source('/obj/structure/ship_missile/armed/'+suffix, 'missile assembly alternative',
                            parts=['/obj/structure/ship_missile','/obj/item/stack/cable_coil','/obj/item/electronics/ship_missile_tracking',warhead],
                            source=self.cite('voidcrew/modules/ship_combat/missile_item.dm', '/obj/structure/ship_missile/armed'),
                            note='wire frame, fit tracking and appropriate warhead; assembled base frame changes state rather than subtype; functional equivalent')
        for p in dm.paths('/datum/gas_recipe'):
            for product in paths(dm.val(p, 'products')):
                self.add_source(product, 'gas recipe', recipe=p, machine=dm.val(p, 'machine_type'), source=dm.field(p, 'products').source)
        for p in dm.paths('/datum/chemical_reaction'):
            for source, code in proc_chain(dm, p, 'on_reaction'):
                for m in re.finditer(r'\bnew\s+(/obj/[\w/]+)', code):
                    self.add_source(m[1], 'chemical item reaction', reaction=p,
                                    required_reagents=dm.val(p, 'required_reagents'), required_catalysts=dm.val(p, 'required_catalysts'),
                                    required_temp=dm.val(p, 'required_temp'), source=source)

    def used_up_fixtures(self, recipe):
        """The machines and structures a recipe eats. Each maps to CRAFTING_MACHINERY_CONSUME or CRAFTING_MACHINERY_USE, which is 0 (crafting.dm)."""
        found = [path for field in ('machinery', 'structures') for path, amount in assoc(self.dm.val(recipe, field)).items() if amount]
        return sorted(path for path in found if isinstance(path, str))

    def must_be_learned(self, recipe):
        """crafting_flags with CRAFT_MUST_BE_LEARNED: a player can't make this until something teaches it."""
        flags = self.dm.val(recipe, 'crafting_flags')
        bit = self.dm.eval('CRAFT_MUST_BE_LEARNED')
        if isinstance(flags, int) and isinstance(bit, int):
            return bool(flags & bit)
        return 'CRAFT_MUST_BE_LEARNED' in str(flags)

    def build_teachers(self):
        """Recipes a player learns rather than knows: crafting books, and items whose procs teach one."""
        dm = self.dm
        teachers = collections.defaultdict(set)
        for book in dm.paths('/obj/item/book/granter/crafting_recipe'):
            for recipe in paths(dm.val(book, 'crafting_recipe_types')):
                teachers[recipe].add(book)
        for key, bodies in dm.procs.items():
            owner = key.rsplit('/', 1)[0]
            if not owner.startswith('/obj/item'):
                continue
            for _, code in bodies:
                for recipe in re.findall(r'teach_crafting_recipe\(\s*(/datum/crafting_recipe[\w/]*)', code):
                    teachers[recipe].add(owner)
        self.teachers = {recipe: sorted(owners) for recipe, owners in teachers.items()}

    def global_list(self, name):
        for file in self.dm.files:
            text = clean_comments(self.dm.texts[file])
            m = re.search(r'GLOBAL_(?:LIST|ALIST)_INIT\(\s*' + name + r'\s*,\s*(list\()', text)
            if not m:
                continue
            start = m.start(1)
            end = m.end(1)
            raw = text[start:end]
            while balance(raw) and end < len(text):
                raw += text[end]
                end += 1
            return self.dm.eval(raw), f'{file}:{text.count(chr(10),0,m.start())+1}'
        return [], ''

    def build_loot(self):
        dm = self.dm
        tiers = [('common', 'loot_common', '1'), ('uncommon', 'loot_uncommon', '2'), ('prime', 'loot_prime', '3'), ('unique', 'loot_uniques', '4')]
        gun_pools, gun_source = self.global_list('loot_gun_pools')
        melee_pools, melee_source = self.global_list('loot_melee_pools')
        spare, spare_source = self.global_list('loot_gun_spare_ammo')
        spare = assoc(spare)
        for theme in dm.paths('/datum/loot_theme'):
            if theme == '/datum/loot_theme':
                continue
            for tier, field, key in tiers:
                pool = assoc(dm.val(theme, field))
                total = sum(w for w in pool.values() if isinstance(w, (int, float)))
                for item, weight in pool.items():
                    if not isinstance(weight, (int, float)):
                        continue
                    odds = {}
                    for band in ['GREEN', 'YELLOW', 'RED']:
                        tier_odds = assoc(dm.eval('ZONE_LOOT_ODDS_' + band))
                        # One draw is reserved for the weapon attempt, even when it fails.
                        lo = dm.eval('ZONE_LOOT_DRAWS_MIN_' + band) - 1
                        hi = dm.eval('ZONE_LOOT_DRAWS_MAX_' + band) - 1
                        odds[band.lower()] = dict(nonweapon_draws=[lo, hi], first_draw_probability=rounded(tier_odds.get(key, 0) / sum(tier_odds.values()) * weight / total))
                    self.add_source(item, 'zone loot', theme=theme, tier=tier, weight=weight, pool_weight=total,
                                    frequency=odds, frequency_note='first nonweapon draw only; without replacement and exhausted-tier fallback change subsequent draws',
                                    source=dm.field(theme, field).source)
            for field, global_pool, source, class_prefix in [('gun_extras', gun_pools, gun_source, 'LOOT_GUN_CLASSES_'), ('melee_extras', melee_pools, melee_source, 'LOOT_MELEE_CLASSES_')]:
                is_gun = field == 'gun_extras'
                base_pool = assoc(assoc(global_pool).get(dm.val(theme, 'gun_pool') or 'armory', [])) if is_gun else assoc(global_pool)
                extras = assoc(dm.val(theme, field))
                for key in ['1', '2', '3']:
                    pool = assoc(base_pool.get(key, []))
                    for item, w in assoc(extras.get(key, [])).items():
                        if item not in pool:
                            pool[item] = w
                    total = sum(w for w in pool.values() if isinstance(w, (int, float)))
                    for item, weight in pool.items():
                        frequencies = {}
                        for i, band in enumerate(['GREEN', 'YELLOW', 'RED']):
                            classes = assoc(dm.eval(class_prefix + band))
                            chance = dm.val(theme, 'gun_chance') or [0, 0, 0]
                            gun_chance = chance[i] / 100 if isinstance(chance, list) else 0
                            frequencies[band.lower()] = rounded((gun_chance if is_gun else 1 - gun_chance) * classes.get(key, 0) / sum(classes.values()) * weight / total) if total else 0
                        data = dict(theme=theme, weapon_class=key, weight=weight, pool_weight=total, frequency=frequencies,
                                    source=source, extra_source=dm.field(theme, field).source)
                        self.add_source(item, 'zone weapon loot', **data)
                        if item in spare:
                            self.add_source(spare[item], 'loot spare ammunition', accompanying_gun=item, **data)

    @functools.lru_cache(None)
    def contents(self, owner):
        """Conservative explicit spawn graph; quantities remain unknown for loops/branches."""
        result = []
        for method in ['PopulateContents', 'populate_contents_immediate', 'Initialize']:
            for source, code in proc_chain(self.dm, owner, method):
                # A guard var on the type can leave it empty: if(empty) or if(crafted), then return.
                guard = re.search(r'if\((\w+)\)\s*\n\s*return', code) if method == 'PopulateContents' else None
                if guard and self.dm.val(owner, guard[1]) == 1:
                    break
                if source.startswith(('code/game/objects/items/storage/storage.dm:', 'code/game/objects/items/_items.dm:', 'code/game/objects/structures/closets/closet.dm:')):
                    continue
                for m in re.finditer(r'\bnew\s+(/(?:obj|mob)/[\w/]+|\w+)\s*\(', code):
                    item = m[1] if m[1].startswith('/') else self.dm.val(owner,m[1])
                    if not isinstance(item,str) or not item.startswith(('/obj/','/mob/')):
                        continue
                    # Only actual child contents: new path(src), not nearby drops or effects.
                    after = code[m.end():].split('\n', 1)[0]
                    if not re.match(r'\s*src\s*[,)]', after):
                        continue
                    at = code.count('\n', 0, m.start())
                    sfile, sline = source.rsplit(':', 1)
                    lines = code.splitlines()
                    depth = len(lines[at])-len(lines[at].lstrip('\t'))
                    count = 1
                    for prior in reversed(lines[:at]):
                        if not prior.strip():
                            continue
                        indent = len(prior)-len(prior.lstrip('\t'))
                        if indent >= depth:
                            continue
                        depth = indent
                        if prior.strip().startswith(('if(', 'else', 'switch(')):
                            count = None
                        if prior.strip().startswith('for('):
                            loop = re.search(r'(?:in\s+1|=\s*1)\s+to\s+(\w+)', prior)
                            n = self.dm.eval(loop[1]) if loop else None
                            if loop and not isinstance(n, (int, float)):
                                n = self.dm.val(owner, loop[1])
                            count = count * n if count is not None and isinstance(n, (int, float)) else None
                    args = split_top(after.split(')',1)[0])
                    stack_units = number(args[1]) if len(args)>1 else None
                    result.append(dict(item=item, source=f'{sfile}:{int(sline)+at}', count=count,
                                       stack_units=stack_units, count_note='None: conditional/procedural loop, not assumed guaranteed'))
                # Declarative filled containers and their weighted population lists.
                for m in re.finditer(r'(/(?:obj|mob)/[\w/]+)\s*=\s*(\d+)', code):
                    if any(x in code for x in ['spawn_contents', 'generate_items_inside']):
                        result.append(dict(item=m[1], count=int(m[2]), source=source))
                # Parent is only called when ..() occurs.
                if '..(' not in code:
                    break
        for field in ['spawn_contents', 'starting_contents', 'applied_modules', 'applied_core', 'applied_cell', 'warhead_path']:
            for item in paths(self.dm.val(owner, field)):
                if field in ['warhead_path','applied_core','applied_cell'] and any(c['item']==item for c in result):
                    continue  # variable new field(src) was already resolved.
                result.append(dict(item=item, count=1 if field in ['applied_modules','applied_core','applied_cell','warhead_path'] else None, source=self.dm.field(owner, field).source))
        spawn = self.dm.val(owner,'spawn_type')
        spawn_count = self.dm.val(owner,'spawn_count')
        if isinstance(spawn_count,(int,float)) and spawn_count > 0 and spawn:
            for item in paths(spawn):
                result.append(dict(item=item,count=spawn_count if isinstance(spawn,str) else None,
                                   source=self.dm.field(owner,'spawn_type').source))
        if self.is_a(owner, '/obj/item/ammo_box') and not self.dm.val(owner, 'start_empty'):
            result.append(dict(item=self.dm.val(owner, 'ammo_type'), count=self.dm.val(owner, 'max_ammo'),
                               source=self.dm.field(owner, 'ammo_type').source, note='lazy ammo must be unloaded/materialized before recovery'))
        if self.is_a(owner, '/obj/item/gun/ballistic'):
            mag = self.dm.val(owner, 'mag_type')
            if mag:
                result.append(dict(item=mag, count=1, source=self.dm.field(owner, 'mag_type').source))
        return tuple(result)

    def buybacks(self, item, units, r):
        result = []
        for b in self.buys:
            if b['kind'] not in ('buyback', 'supply contract', 'angler contract', 'cook contract', 'barter', 'exploration-drone barter'):
                continue
            matching = any((self.is_a(item, p) if number(b['match_subtypes']) else item == p) for p in paths(decode(b['item_path'])))
            if not matching:
                continue
            amt = number(b['amount']) or 1
            cr = number(b['pay_credits'])
            vouchers = number(b['pay_vouchers'])
            blocked = None
            rule = decode(b['match_rule'])
            rule_text = json.dumps(rule, ensure_ascii=False, separators=(',', ':'))
            if b['kind'] == 'cook contract' or 'TRAIT_FOOD_CHEF_MADE' in rule_text:
                blocked = 'as-sold shop food has no player-cooked provenance; diner plating uses excluded OUTPOST_KITCHEN provenance'
            if isinstance(rule, dict) and isinstance(rule.get('min_complexity'), (int, float)):
                complexity = self.dm.val(item, 'crafting_complexity')
                if isinstance(complexity, (int, float)) and complexity < rule['min_complexity']:
                    blocked = 'food crafting complexity below buyback minimum; player-cooked provenance also required'
            if 'exotic_gas' in b['entry_type']:
                blocked = 'conditional: tank must contain required_moles of gas; initial contents checked separately'
            if 'graft' in b['entry_type']:
                blocked = 'conditional: graft origin/complexity; inspect match_rule'
            sale_units = units / amt if self.is_a(item, '/obj/item/stack') else units
            result.append(dict(kind=b['kind'], shop=b['shop'], entry=b['entry_type'], amount=amt,
                               credits_per_sale=cr, vouchers_per_sale=vouchers,
                               credits_per_offer=rounded(cr * sale_units) if cr is not None else None,
                               vouchers_per_offer=rounded(vouchers * sale_units) if vouchers is not None else None,
                               sale_units_per_offer=sale_units, batch_needed=math.ceil(amt / units) if self.is_a(item, '/obj/item/stack') else 1,
                               other_payment=decode(b['other_payment']), blocked_or_conditional=blocked,
                               demand=b['demand'], demand_max=number(b['demand_max']), refill=b['refill_rule'],
                               match_rule=rule, notes=b['notes'], source=b['source']))
        return result

    def export_matches(self, item):
        hits = []
        for b in self.buys:
            if b['kind'] != 'cargo export reference':
                continue
            params = decode(b['other_payment'])
            match = any((self.is_a(item, p) if params['include_subtypes'] else item == p) for p in paths(decode(b['item_path'])))
            if not match or any(self.is_a(item, p) for p in paths(params['exclude_types'])):
                continue
            hits.append((b, params))
        return hits

    @functools.lru_cache(None)
    def exports(self, item, units):
        result = []
        mats, _ = self.materials(item)
        for b, params in self.export_matches(item):
            entry = b['entry_type']
            cost = params['base_cost']
            k = params['k_elasticity']
            amount = 1
            conditional = None
            value = None
            if entry.startswith('/datum/export/material'):
                mat = params['material_id']
                amount = mats.get(mat, 0) * units / self.sheet
                if self.is_a(item, '/obj/item/stack/ore'):
                    amount *= .8
                amount = math.floor(amount)
                if not amount:
                    continue
                if '/market' in entry:
                    price = self.market.get(mat)
                    if price is not None:
                        value = (min(10, price) if mat == '/datum/material/plasma' else price) * amount
                elif mat == '/datum/material/plasma':
                    value = min(10, self.market[mat]) * amount
                elif isinstance(cost, (int, float)):
                    value = math.floor(cost * amount if not k else cost/k * (1-math.exp(-k*amount)))
            elif entry.startswith('/datum/export/seed'):
                rarity = self.dm.val(item, 'rarity')
                if entry.endswith('/potency'):
                    conditional = 'only improved potency after this species was discovered; runtime potency difference'
                elif isinstance(rarity, (int, float)):
                    value = math.floor(cost/k * (1-math.exp(-k))) * rarity
                    conditional = 'once per previously undiscovered species; all seed exports share elasticity'
            elif entry == '/datum/export/food':
                elastic = math.floor(cost/k * (1-math.exp(-k)))
                venue = self.dm.val(item, 'venue_value')
                value = math.floor(venue * elastic / cost) if isinstance(venue, (int, float)) and venue else elastic
                conditional = 'fresh ordinary food; silver food is worthless; no trader-kitchen exclusion on cargo export'
            elif entry == '/datum/export/research_notes':
                v = self.dm.val(item, 'value')
                value = math.floor(v*.5) if isinstance(v, (int, float)) else None
            elif entry == '/datum/export/large/gas_canister':
                value = cost
                conditional = 'canister shell baseline; gas contents add dynamic value'
            elif entry == '/datum/export/fish':
                conditional = 'runtime fish health/size/weight/traits affect get_export_price'
            elif entry.startswith('/datum/export/organ'):
                value = math.floor(cost/k * (1-math.exp(-k))) if k else cost
                conditional = 'shop organ has no CLIENT_STARTING_ORGAN trait; starting-player organ is 10x'
            else:
                special_cost = [s for s, _ in proc_chain(self.dm, entry, 'get_cost') if not s.startswith('code/modules/cargo/exports.dm:')]
                special_amount = [s for s, _ in proc_chain(self.dm, entry, 'get_amount') if not s.startswith('code/modules/cargo/exports.dm:')]
                if not special_cost and not special_amount and isinstance(cost, (int, float)):
                    value = math.floor(cost/k * (1-math.exp(-k))) if k else cost
                else:
                    conditional = 'runtime get_cost/get_amount; full function preserved'
            result.append(dict(entry=entry, initial_credits=rounded(value), amount=amount, conditional=conditional,
                               source=b['source'], parameters=params, applies_to=decode(b['match_rule']),
                               precedence='first applicable datum in subtypesof order; alternatives are not additive'))
        return result

    # ------------------------------------------------------------------ one item's routes

    def merge_key(self, path):
        """A stack counts as whatever it merges into, so buying a 50-stack counts for the 1-stack."""
        if path not in self.merge:
            key = path
            if self.is_a(path, '/obj/item/stack'):
                merged = self.dm.val(path, 'merge_type')
                if isinstance(merged, str):
                    key = merged
            self.merge[path] = key
        return self.merge[path]

    def merged_index(self, rows):
        out = collections.defaultdict(list)
        for key, values in rows.items():
            out[self.merge_key(key)].extend((key, value) for value in values)
        return out

    def build_route_indexes(self):
        self.merge = {}
        self.gates = {}
        shop_rows = collections.defaultdict(list)
        other_rows = collections.defaultdict(list)
        for row in self.catalog:
            for item in paths(decode(row['item_path'])):
                (shop_rows if row['sku_type'].startswith('/datum/shop_sku/') else other_rows)[item].append(row)
        self.shops = self.merged_index(shop_rows)
        self.others = self.merged_index(other_rows)
        self.indexed = self.merged_index(self.source_index)
        self.blocked = collections.defaultdict(list)
        for reason, pack_list in self.rejected.items():
            if reason.startswith('unregistered') or reason.startswith('raw anomaly'):
                continue
            for pack in pack_list:
                for entry in self.dm.val(pack, 'contains') or []:
                    item = entry[0] if isinstance(entry, tuple) else entry
                    if isinstance(item, str):
                        self.blocked[item].append(dict(pack=pack, name=self.dm.val(pack, 'name'), cost=self.dm.val(pack, 'cost'), reason=reason,
                                                       express_console='its pack list has no such filter, code/modules/cargo/expressconsole.dm'))
        self.ingredients = set()
        for recipe in self.dm.paths('/datum/crafting_recipe'):
            self.ingredients.update(p for p in paths(self.dm.val(recipe, 'reqs')) if p.startswith('/obj/item'))
        self.fixture_types = sorted(p for p in self.dm.headers if p.startswith(('/obj/machinery', '/obj/structure')))
        self.boards = collections.defaultdict(list)
        for board in self.dm.paths('/obj/item/circuitboard'):
            built = self.dm.val(board, 'build_path')
            if isinstance(built, str):
                self.boards[built].append(board)

    def routed_types(self):
        """Every path with a shop, seller, console, cargo, printing or crafting row, including types with no block of their own."""
        return set(self.shops) | set(self.others) | set(self.indexed) | set(self.made_by_use)

    def gate_with_prereqs(self, node_id):
        """The lowest reputation step that opens a node: the highest anywhere in its prerequisite closure, and for a hidden node that plain research opens, whatever opens it too."""
        if node_id in self.research_steps:
            return self.research_steps[node_id]
        if node_id in self.gates:
            return self.gates[node_id]
        details = self.node_details
        best = 0
        pending, seen = [node_id], set()
        while pending:
            current = pending.pop()
            if current in seen or current not in details:
                continue
            seen.add(current)
            node = details[current]
            zone_permission = node.get('zone_permission')
            best = max(best, zone_permission if isinstance(zone_permission, (int, float)) else 0)
            if not node['starting_node']:
                pending.extend(node['prereqs'] or [])
        self.gates[node_id] = best
        return best

    def routes(self, path):
        """Shops, the peddler, consoles, cargo, printing and crafting for one path. A key appears only when it has something."""
        key = self.merge_key(path)
        out = {}

        shops, peddler = [], []
        for produced, r in self.shops.get(key, []):
            entry = dict(
                seller=r['seller_npc'], shop=r['shop'], shop_type=r['shop_type'], outpost=r['outpost'], zone=r['zone'], sku=r['sku_type'],
                credits=number(r['price_credits']), vouchers=number(r['price_vouchers']),
                other_currency=decode(r['other_currency']) or None, rep_step=PERMISSION.get(number(r['zone_permission']), r['zone_permission']),
                shelf=r['shelf'], stock=r['stock'], stock_max=number(r['stock_max']), restock=r['restock_rule'],
                units=number(r['delivered_units']), rotation_weight=number(r['rotation_weight']),
                fixed_price=number(r['fixed_price']), contract_reward=number(r['contract_reward']),
                crew_limit=number(r['crew_limit']), produced=produced if produced != path else None, source=r['source'])
            (peddler if r['shop_type'] == PEDDLER_SHOP else shops).append(entry)
        if shops:
            out['shops'] = shops
        if peddler:
            out['peddler'] = peddler

        consoles, others = [], []
        for produced, r in self.others.get(key, []):
            entry = dict(where=r['shop'], shop_type=r['shop_type'], offer=r['sku_type'], credits=r['price_credits'], other_currency=decode(r['other_currency']) or None,
                         stock=r['stock'], notes=(r['notes'] or '')[:300] or None, produced=produced if produced != path else None, source=r['source'])
            (consoles if r['shop_type'].startswith('/obj/machinery/computer/order_console') else others).append(entry)
        if consoles:
            out['order_consoles'] = consoles
        if others:
            out['other_sellers'] = others

        cargo, printing, crafting, misc = [], [], [], []
        for produced, r in self.indexed.get(key, []):
            kind = r['kind']
            if kind == 'cargo':
                cargo.append(dict(pack=r['pack'], name=r['name'], pack_cost=r['pack_cost'], count=r['count'], units_per_stack=r['units_per_stack'],
                                  price_per_unit=r['price_per_unit'], availability=r['availability'], runtime_fill=r['runtime_fill'],
                                  produced=produced if produced != path else None, source=r['source']))
            elif kind == 'design':
                nodes = [dict(id=n['id'], name=n['name'], point_cost=n['point_cost'], rep_step=PERMISSION.get(n.get('zone_permission'), n.get('zone_permission')),
                              rep_step_with_prereqs=PERMISSION.get(self.gate_with_prereqs(n['id'])), starting_node=n['starting_node'],
                              hidden=n['hidden'], hidden_with_prereqs=n['hidden_with_prereqs'], opened_by=n['opened_by'], experimental=n['experimental'], surveys=n['surveys'], experiments=n['experiments'],
                              total_prereq_points=n['total_prerequisite_points_including_self'], source=n['source']) for n in r['nodes']]
                printing.append(dict(design=r['design'], id=r['id'], machines=r['machines'], materials=r['material_cost_cm3'],
                                     material_value=r['material_base_value'], unlock=r['unlock'], roundstart=r['unlock'] == 'roundstart', nodes=nodes, disks=r['disks'],
                                     produced=produced if produced != path else None, source=r['source']))
            elif kind == 'crafting':
                crafting.append(dict(recipe=r['recipe'], ingredients=r['requirements'], tools=r['tools'], tool_paths=r['tool_paths'], machinery=r['machinery'], structures=r['structures'], uses_up=r['uses_up'],
                                     made_empty=r['made_empty'], time_ds=r['time_deciseconds'], always_available=r['always_available'], learned_from=r['learned_from'],
                                     non_craftable=self.dm.val(r['recipe'], 'non_craftable'),
                                     produced=produced if produced != path else None, source=r['source']))
            elif kind == 'stack crafting':
                crafting.append(dict(stack_recipe=r['name'], input_stack=r['input_context'], input_stacks=r['input_stacks'], made_empty=r['made_empty'], req_amount=r['req_amount'], result_amount=r['result_amount'],
                                     produced=produced if produced != path else None, source=r['source']))
            elif kind in ('hydroponics', 'seed mutation', 'food processing', 'anomaly neutralization', 'random raw anomaly core',
                          'beekeeping', 'chemical item reaction', 'gas recipe', 'MOD assembly alternative', 'missile assembly alternative'):
                misc.append({k: v for k, v in r.items() if k in ('kind', 'seed', 'parent_seed', 'input', 'action', 'anomaly', 'reaction', 'recipe', 'machine', 'from_item', 'eventual_probability', 'note', 'source')})
        if cargo:
            out['cargo'] = cargo
        if printing:
            out['printing'] = printing
        if crafting:
            out['crafting'] = crafting
        if misc:
            out['other_routes'] = misc
        used = self.made_by_use.get(path)
        if used:
            out['made_by_use'] = [dict(row) for row in used]
        return out

    def fixtures_for(self, needed):
        """Every machine or structure type that satisfies the ones recipes ask for, with its own routes. The game takes a subtype of what a recipe names (ispath, crafting.dm).

        A machine's circuit board reads as a recipe: get the board and you can build it, parts being ordinary stock. Returns type -> routes, in the shape routes() gives.
        """
        found = {}
        for fixture in self.fixture_types:
            if not any(self.is_a(fixture, need) for need in needed):
                continue
            routes = self.routes(fixture)
            boards = [dict(recipe=board, ingredients={board: 1}, always_available=True, learned_from=[], source=self.dm.loc(board)) for board in self.boards.get(fixture, [])]
            if boards:
                routes['crafting'] = routes.get('crafting', []) + boards
            found[fixture] = routes
        return found

    def surgery_by_zone(self):
        """Body zone -> the organ surgeries that reach it. Read from possible_locs; a zone with none can't be fitted by surgery."""
        dm = self.dm
        zones = collections.defaultdict(list)
        for surgery in dm.paths('/datum/surgery/organ_manipulation'):
            for zone in dm.val(surgery, 'possible_locs') or []:
                if isinstance(zone, str):
                    zones[zone].append(surgery)
        return {zone: sorted(found) for zone, found in zones.items()}


def load_static(root):
    """The DM reader, shops, cargo, printing and crafting for a checkout, with no dump and no world. See StaticSources.routes()."""
    return StaticSources(root)
