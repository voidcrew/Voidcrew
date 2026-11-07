import collections
import json
from pathlib import Path
import tempfile
import unittest

from tools.gear_catalog.build import assemble, availability, is_abstract, randomised_vars, scan_procs, write_outputs
from tools.gear_catalog.categories import GEAR_CATEGORIES, NOT_GEAR_CATEGORIES, category_of, is_gear
from tools.gear_catalog.combat import blocked_percent, fire_mode, melee_state, penetrate_armour, reload_facts
from tools.gear_catalog.dm_reader import DM, clean_comments
from tools.gear_catalog.sections import decode_flags
from tools.gear_catalog.sheets import availability_text, sheet_text
from tools.gear_catalog.sources import Sources, under_condition
from tools.gear_catalog.static_sources import StaticSources, pack_counts, stack_recipe_args


DME = '''
#include "code\\items.dm"
#include "code\\late.dm"
'''
ITEMS_DM = '''
#define FORCE_BIG (10 * 2)

/obj/item
	var/force = 0
	name = "item"

/obj/item/sword
	name = "sword"
	force = FORCE_BIG

/obj/item/sword/rusty
	name = "rusty sword"

/obj/item/sword/rusty/proc/flake(mob/user)
	return

/obj/item/oddball
	parent_type = /obj/item/sword
	force = 3

/obj/item/hat
	name = "hat"

/obj/item/hat/fancy
	name = "fancy hat"

/obj/item/clothing/head/blasting
	name = "blasting hat"

/obj/item/clothing/head/blasting/equipped(mob/user)
	return ..()
'''
LATE_DM = '''
/obj/item/sword/rusty
	force = 7
'''
META = {
    'meta': True,
    'click_cd_range': 4,
    'click_cd_melee': 8,
    'armor_weakened_multiplier': 2,
    'armor_max_block': 90,
    'bitfields': {'flags_inv': {'HIDEHAIR': 1, 'HIDEFACE': 2}, 'sharpness': {'SHARP_EDGED': 1}, 'pass_flags': {'PASSTABLE': 1, 'PASSCLOSEDTURF': 2}},
    'body_parts': {'HEAD': 4, 'CHEST': 1},
    'item_base': {'force': '[0]', 'attack_speed': '[8]', 'armour_penetration': '[0]', 'damtype': '["brute"]', 'w_class': '[3]'},
}


def dump_row(path, parent='/obj/item', **facts):
    return dict(dict(path=path, parent=parent, name=path.rsplit('/', 1)[-1].replace('_', ' ') + ' thing', desc='', status='ok', no_sprite=False), **facts)


class StubSources:
    """The few things assemble() asks of the real route tracer."""

    ordinary = ()

    def __init__(self, dm, routes, fixtures=None, in_round=()):
        self.dm = dm
        self.routes = routes
        self.type_checked = set()
        self.ingredients = set()
        self.fixtures = fixtures or {}
        self.in_round = in_round

    def fixtures_for(self, needed):
        return {path: routes for path, routes in self.fixtures.items() if any(path == need or path.startswith(need + '/') for need in needed)}

    def fixture_in_round(self, fixture):
        return fixture in self.in_round

    def sources_for(self, path, raw):
        return json.loads(json.dumps(self.routes.get(path, {})))

    def surgery_by_zone(self):
        return {'chest': ['/datum/surgery/organ_manipulation']}


class GearCatalogTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / 'code').mkdir()
        (self.root / 'tgstation.dme').write_text(DME, encoding='utf-8')
        (self.root / 'code' / 'items.dm').write_text(ITEMS_DM, encoding='utf-8')
        (self.root / 'code' / 'late.dm').write_text(LATE_DM, encoding='utf-8')
        self.dm = DM(self.root)

    def test_dm_parser_inherits_and_merges_in_include_order(self):
        self.assertEqual(self.dm.val('/obj/item/sword', 'force'), 20)
        self.assertEqual(self.dm.val('/obj/item/sword/rusty', 'force'), 7, 'a later declaration wins')
        self.assertEqual(self.dm.val('/obj/item/sword/rusty', 'name'), 'rusty sword')
        self.assertEqual(self.dm.val('/obj/item/hat/fancy', 'force'), 0, 'falls back through the parent')
        self.assertTrue(self.dm.is_a('/obj/item/oddball', '/obj/item/sword'), 'an explicit parent_type counts')
        self.assertEqual(self.dm.val('/obj/item/oddball', 'name'), 'sword')
        self.assertIn('/obj/item/sword/rusty', self.dm.paths('/obj/item/sword'))

    def test_scan_finds_full_path_procs(self):
        procs = scan_procs(self.dm)
        self.assertIn('flake', procs['/obj/item/sword/rusty'])
        self.assertIn('equipped', procs['/obj/item/clothing/head/blasting'])

    def test_gun_numbers(self):
        gun = dict(fire_delay=0, burst_size=3, burst_delay=2, projectile_damage_multiplier=1, kind='ballistic')
        casing = dict(pellets=1, projectile=dict(damage=30, armor_flag='bullet', armour_penetration=0))
        mode = fire_mode(gun, casing, 'burst', 4, 20, vest=dict(bullet=30))
        self.assertEqual(mode['cycle_ds'], 8, 'burst_delay * 2 + the click cooldown')
        self.assertEqual(mode['shots_per_second'], 3.75)
        self.assertEqual(mode['dps'], 112.5)
        self.assertEqual(mode['damage_per_magazine'], 600)
        self.assertEqual(mode['target']['bare']['dps'], 112.5)
        self.assertEqual(mode['target']['vest']['damage_per_shot'], 21)
        self.assertEqual(mode['target']['vest']['dps'], 78.75)

    def test_gun_numbers_stamina_and_manual_action(self):
        gun = dict(fire_delay=0, burst_size=1, semi_auto=0, rack_delay=10, projectile_damage_multiplier=1)
        casing = dict(pellets=5, projectile=dict(damage=10, damage_type='stamina', stamina=2, armor_flag='bullet'))
        mode = fire_mode(gun, casing, 'semi', 4, 5, vest=dict(bullet=0))
        self.assertEqual(mode['cycle_ds'], 10, 'a rack per shot')
        self.assertEqual(mode['damage_per_shot'], 0)
        self.assertEqual(mode['stamina_per_shot'], 60)

    def test_armor_rule_matches_the_game(self):
        self.assertEqual(penetrate_armour(30, 100), 0)
        self.assertAlmostEqual(penetrate_armour(50, 20), 37.5)
        self.assertEqual(blocked_percent(0, 50), 0)
        self.assertEqual(blocked_percent(30, 0, weak=True), 60)
        self.assertEqual(blocked_percent(30, 40), 0, 'never below zero')
        self.assertEqual(blocked_percent(95), 90, 'capped')
        state = melee_state('default', 20, 8, 0, 'brute')
        self.assertEqual(state['hits_per_second'], 1.25)
        self.assertEqual(state['target']['bare']['dps'], 25)
        self.assertEqual(state['target']['armored']['damage_per_hit'], 14)
        stun = melee_state('default', 20, 8, 0, 'stamina')
        self.assertEqual(stun['damage_per_hit'], 0)
        self.assertEqual(stun['stamina_per_hit'], 20)

    def test_reload_says_when_the_code_gives_no_timer(self):
        facts = reload_facts(dict(kind='ballistic', rack_delay=5, tac_reloads=True), 5)
        self.assertIsNone(facts['seconds'])
        self.assertFalse(facts['timed_by_code'])
        self.assertTrue(facts['rack_is_default'])
        by_round = reload_facts(dict(kind='ballistic', rack_delay=10, internal_magazine=True, magazine=dict(multiload=0, max_ammo=4)), 5)
        self.assertEqual(by_round['clicks'], 4)
        self.assertIsNone(reload_facts(dict(kind='energy')))

    def test_category_mapping(self):
        self.assertEqual(category_of('/obj/item/gun/energy/laser'), ('guns', '/obj/item/gun'))
        self.assertEqual(category_of('/obj/item/clothing/suit/armor/vest')[0], 'suits')
        self.assertEqual(category_of('/obj/item/hatchet'), ('melee', '/obj/item'))
        self.assertEqual(category_of('/obj/item/reagent_containers/hypospray/medipen')[0], 'medical')
        self.assertEqual(category_of('/obj/item/reagent_containers/cup/beaker')[0], 'reagent_containers')
        self.assertEqual(category_of('/obj/item/stack/medical/gauze')[0], 'medical')
        self.assertEqual(category_of('/obj/item/stack/sheet/iron')[0], 'stacks')
        self.assertEqual(category_of('/obj/item/construction/rcd')[0], 'tools')
        self.assertEqual(category_of('/obj/item/gunslinger_thing'), ('misc', '/obj/item'), 'a prefix only matches whole path parts')
        self.assertTrue(is_gear('guns'))
        self.assertFalse(is_gear('food'))
        self.assertFalse(GEAR_CATEGORIES & NOT_GEAR_CATEGORIES)

    def test_abstract_rule(self):
        self.assertFalse(is_abstract('/obj/item/gun/ballistic/revolver', dict(name='.357 revolver', no_sprite=False), True, ['loot']), 'a base with a sprite, a real name and a route is real')
        self.assertTrue(is_abstract('/obj/item/gun/ballistic/revolver', dict(name='.357 revolver', no_sprite=False), True, []), 'no route anywhere')
        self.assertFalse(is_abstract('/obj/item/gun/ballistic/shotgun', dict(name='shotgun', no_sprite=False), True, ['loot']), 'a shotgun may be called shotgun')
        self.assertFalse(is_abstract('/obj/item/wrench', dict(name='wrench', no_sprite=False), True, ['printing', 'maps']), 'a category base named for itself, with a sprite and a route, is the plain tool')
        self.assertTrue(is_abstract('/obj/item/wrench', dict(name='wrench', no_sprite=False), True, []), 'the same base nobody can get')
        self.assertTrue(is_abstract('/obj/item/seeds', dict(name='item', no_sprite=False), True, ['loot']), 'the name it inherited from the plain item')
        self.assertTrue(is_abstract('/obj/item/thing', dict(name='thing', no_sprite=True), True, ['loot']), 'no sprite')
        self.assertFalse(is_abstract('/obj/item/bodypart/arm/left/robot', dict(name='cyborg left arm', no_sprite=True), True, ['printing', 'maps']), 'it draws itself at runtime, and a printer makes this path')
        self.assertTrue(is_abstract('/obj/item/ammo_box/magazine/internal', dict(name='internal magazine', no_sprite=True), True, ['in_containers', 'maps']), 'only ever inside something')
        self.assertFalse(is_abstract('/obj/item/gun', dict(name='gun', no_sprite=True), False, []), 'no subtypes: a leaf is never abstract')

    def built(self, dump_rows, routes=None, out=None):
        sources = StubSources(self.dm, routes or {})
        rows, entries, overrides, judged, ctx = assemble(dump_rows, META, sources, scan_procs(self.dm))
        if out:
            write_outputs(out, rows, entries, overrides, judged, ctx, META, {'ruin': 1})
        return rows, entries

    def test_cosmetic_rule(self):
        rows, _ = self.built({
            '/obj/item/clothing/head/plain': dump_row('/obj/item/clothing/head/plain', vars=dict(icon_state='hat', flags_inv=1, body_parts_covered=4, max_integrity=50)),
            '/obj/item/clothing/head/mask': dump_row('/obj/item/clothing/head/mask', vars=dict(flags_inv=3)),
            '/obj/item/clothing/suit/vest': dump_row('/obj/item/clothing/suit/vest', armor=dict(melee=30, type='/datum/armor/x')),
            '/obj/item/clothing/head/warm': dump_row('/obj/item/clothing/head/warm', vars=dict(cold_protection=4)),
            '/obj/item/knife/reskin': dump_row('/obj/item/knife/reskin', vars=dict(force=10)),
            '/obj/item/clothing/head/blasting': dump_row('/obj/item/clothing/head/blasting'),
        })
        self.assertTrue(rows['/obj/item/clothing/head/plain']['cosmetic'], 'a hat that only hides hair and covers a head')
        self.assertFalse(rows['/obj/item/clothing/head/mask']['cosmetic'], 'hides a face')
        self.assertFalse(rows['/obj/item/clothing/suit/vest']['cosmetic'], 'a vest')
        self.assertFalse(rows['/obj/item/clothing/head/warm']['cosmetic'], 'keeps the cold out')
        self.assertFalse(rows['/obj/item/knife/reskin']['cosmetic'], 'a reskinned knife still cuts')
        self.assertFalse(rows['/obj/item/clothing/head/blasting']['cosmetic'], 'has a proc that does something')

    def test_cosmetic_rulings_the_rule_cannot_see(self):
        rows, _ = self.built({
            '/obj/item/clothing/accessory/dogtag/borg_ready': dump_row('/obj/item/clothing/accessory/dogtag/borg_ready', vars=dict(display='x')),
            '/obj/item/clothing/accessory/pocketprotector/full': dump_row('/obj/item/clothing/accessory/pocketprotector/full', storage=dict(max_slots=3), contents={'/obj/item/pen': 3}),
            '/obj/item/clothing/accessory/pandora_hope': dump_row('/obj/item/clothing/accessory/pandora_hope', vars=dict(mood=6)),
        })
        self.assertTrue(rows['/obj/item/clothing/accessory/dogtag/borg_ready']['cosmetic'], 'only a line on an examine')
        self.assertTrue(rows['/obj/item/clothing/accessory/pocketprotector/full']['cosmetic'], 'pockets for pens')
        self.assertFalse(rows['/obj/item/clothing/accessory/pandora_hope']['cosmetic'], 'Hope does something')

    def test_note_rule(self):
        route = dict(loot=[dict(channel='ruin')])
        routes = {'/obj/item/clothing/head/blasting': route, '/obj/item/sword/rusty': route, '/obj/item/stock_parts/thing': route}
        dump_rows = {
            '/obj/item/clothing/head/blasting': dump_row('/obj/item/clothing/head/blasting'),
            '/obj/item/clothing/head/unreachable': dump_row('/obj/item/clothing/head/unreachable', components=[dict(type='/datum/component/odd', vars={})]),
            '/obj/item/sword/rusty': dump_row('/obj/item/sword/rusty', parent='/obj/item/sword', components=[dict(type='/datum/component/odd', vars={})]),
            '/obj/item/stock_parts/thing': dump_row('/obj/item/stock_parts/thing', components=[dict(type='/datum/component/odd', vars={})]),
        }
        rows, entries = self.built(dump_rows, routes)
        head = entries['headwear']['/obj/item/clothing/head/blasting']
        self.assertTrue(head['needs_note'], 'an obtainable hat with a proc that isn\'t plumbing')
        self.assertEqual(head['note_owners'], ['/obj/item/clothing/head/blasting'])
        self.assertFalse(entries['headwear']['/obj/item/clothing/head/unreachable']['needs_note'], 'nobody can get it')
        self.assertTrue(entries['misc']['/obj/item/sword/rusty']['gear'] is False)
        self.assertFalse(entries['misc']['/obj/item/sword/rusty']['needs_note'], 'not gear')
        self.assertFalse(entries['machine_parts']['/obj/item/stock_parts/thing']['needs_note'], 'not gear')

    def test_crafting_needs_a_route_for_every_kit(self):
        route = dict(loot=[dict(channel='ruin')])
        recipe = dict(recipe='/datum/crafting_recipe/x', ingredients={'/obj/item/kit': 1, '/datum/reagent/water': 5}, always_available=True, learned_from=[])
        book_recipe = dict(recipe='/datum/crafting_recipe/y', ingredients={'/obj/item/kit/good': 1}, always_available=False, learned_from=['/obj/item/book'])
        dump_rows = {path: dump_row(path) for path in ['/obj/item/gun/made', '/obj/item/gun/booked', '/obj/item/kit', '/obj/item/kit/good', '/obj/item/book']}
        rows, entries = self.built(dump_rows, {'/obj/item/gun/made': dict(crafting=[recipe]), '/obj/item/gun/booked': dict(crafting=[book_recipe])})
        self.assertFalse(entries['guns']['/obj/item/gun/made']['availability']['crafted'], 'no kit, no route')
        self.assertEqual(entries['guns']['/obj/item/gun/made']['availability']['crafted_kit_missing'], ['/obj/item/kit'])
        self.assertEqual(rows['/obj/item/gun/made']['firm_sources'], [])
        rows, entries = self.built(dump_rows, {'/obj/item/gun/made': dict(crafting=[recipe]), '/obj/item/kit/good': route, '/obj/item/gun/booked': dict(crafting=[book_recipe])})
        made = entries['guns']['/obj/item/gun/made']
        self.assertTrue(made['availability']['crafted'], 'a subtype of the kit counts')
        self.assertEqual(made['sources']['crafting'][0]['kit_routes'][0]['routes'], ['loot'])
        self.assertTrue(made['sources']['crafting'][0]['kit_routes'][0]['needs_no_rep'])
        self.assertFalse(entries['guns']['/obj/item/gun/booked']['availability']['crafted'], 'the book that teaches it has no route')
        rows, entries = self.built(dump_rows, {'/obj/item/gun/booked': dict(crafting=[book_recipe]), '/obj/item/kit/good': route, '/obj/item/book': route})
        self.assertTrue(entries['guns']['/obj/item/gun/booked']['availability']['crafted'])
        self.assertEqual(entries['guns']['/obj/item/gun/booked']['availability']['learned_from'], ['/obj/item/book'])

    def test_facts_hash_follows_the_bullet_and_ignores_names(self):
        def gun(damage=10, name='a gun', icon_state='gun', loot=False):
            row = dump_row('/obj/item/gun/test', name=name, icon_state=icon_state, gun=dict(kind='ballistic', magazine=dict(casing=dict(type='/obj/item/ammo_casing/x', projectile=dict(type='/obj/projectile/x', damage=damage)))))
            return {'/obj/item/gun/test': row}
        base = self.built(gun())[0]['/obj/item/gun/test']['facts_hash']
        self.assertEqual(base, self.built(gun(name='renamed', icon_state='other'))[0]['/obj/item/gun/test']['facts_hash'])
        self.assertEqual(base, self.built(gun(), {'/obj/item/gun/test': dict(loot=[dict(channel='ruin')])})[0]['/obj/item/gun/test']['facts_hash'], 'sources do not count')
        self.assertNotEqual(base, self.built(gun(damage=11))[0]['/obj/item/gun/test']['facts_hash'], 'a changed bullet changes the gun')

    def test_output_is_deterministic(self):
        dump_rows = {
            '/obj/item/gun/b': dump_row('/obj/item/gun/b', gun=dict(kind='energy', modes=[])),
            '/obj/item/gun/a': dump_row('/obj/item/gun/a', gun=dict(kind='energy', modes=[])),
            '/obj/item/clothing/suit/vest': dump_row('/obj/item/clothing/suit/vest', armor=dict(melee=30, type='/datum/armor/x')),
        }
        routes = {'/obj/item/gun/a': dict(loot=[dict(channel='ruin')])}
        first, second = self.root / 'first', self.root / 'second'
        self.built(dump_rows, routes, first)
        self.built(dict(reversed(list(dump_rows.items()))), routes, second)
        names = sorted(p.relative_to(first).as_posix() for p in first.rglob('*') if p.is_file())
        self.assertEqual(names, sorted(p.relative_to(second).as_posix() for p in second.rglob('*') if p.is_file()))
        self.assertIn('items/guns.json', names)
        for name in names:
            self.assertEqual((first / name).read_bytes(), (second / name).read_bytes(), name)

    def test_recipe_needs_its_machine(self):
        recipe = dict(recipe='/datum/crafting_recipe/sword', ingredients={'/obj/item/kit': 1}, machinery=['/obj/machinery/crystal/small'], always_available=True, learned_from=[])
        route = dict(loot=[dict(channel='ruin')])
        dump_rows = {path: dump_row(path) for path in ['/obj/item/melee/sword', '/obj/item/kit']}
        routes = {'/obj/item/melee/sword': dict(crafting=[recipe]), '/obj/item/kit': route}

        def built(fixtures, in_round=()):
            sources = StubSources(self.dm, routes, fixtures, in_round)
            return assemble(dump_rows, META, sources, scan_procs(self.dm))[1]['melee']['/obj/item/melee/sword']

        made = built({})
        self.assertFalse(made['availability']['crafted'], 'nothing makes the machine')
        self.assertEqual(made['firm_sources'], [])
        self.assertEqual([kit['path'] for kit in made['sources']['crafting'][0]['kit_routes'] if not kit['has_route']], ['/obj/machinery/crystal/small'])
        self.assertTrue(built({'/obj/machinery/crystal/small': {}}, ['/obj/machinery/crystal/small'])['availability']['crafted'], 'it stands on a map in a round')
        self.assertTrue(built({'/obj/machinery/crystal/small/big': dict(cargo=[dict(pack='/x')])})['availability']['crafted'], 'a subtype counts, and a pack sells it')
        board = dict(recipe='/obj/item/kit', ingredients={'/obj/item/kit': 1}, always_available=True, learned_from=[])
        self.assertTrue(built({'/obj/machinery/crystal/small': dict(crafting=[board])})['availability']['crafted'], 'built from a board with a route')

    def test_recipe_needs_its_tool(self):
        recipe = dict(recipe='/datum/crafting_recipe/x', ingredients={}, tool_paths=['/obj/item/kit/good'], always_available=True, learned_from=[])
        dump_rows = {path: dump_row(path) for path in ['/obj/item/gun/made', '/obj/item/kit', '/obj/item/kit/good']}
        rows, _ = self.built(dump_rows, {'/obj/item/gun/made': dict(crafting=[recipe])})
        self.assertEqual(rows['/obj/item/gun/made']['firm_sources'], [])
        rows, _ = self.built(dump_rows, {'/obj/item/gun/made': dict(crafting=[recipe]), '/obj/item/kit/good': dict(loot=[dict(channel='ruin')])})
        self.assertEqual(rows['/obj/item/gun/made']['firm_sources'], ['crafting'])

    def test_filled_box_is_not_crafted(self):
        stack = dict(stack_recipe='flashbang box', input_stacks=['/obj/item/stack/card'], made_empty=True, source='a.dm:1')
        box = '/obj/item/storage/box/bangs'
        dump_rows = {path: dump_row(path) for path in [box, '/obj/item/stack/card', '/obj/item/grenade/bang']}
        dump_rows[box]['contents'] = {'/obj/item/grenade/bang': 7}
        rows, entries = self.built(dump_rows, {box: dict(crafting=[stack]), '/obj/item/stack/card': dict(loot=[dict(channel='ruin')])})
        self.assertEqual(rows[box]['firm_sources'], [], 'the game empties it as it makes it')
        self.assertTrue(entries['storage'][box]['availability']['crafted_empty'])
        self.assertIn('craft:empty', availability_text(entries['storage'][box]))
        self.assertNotIn('in_containers', rows['/obj/item/grenade/bang']['sources'], 'so it is no route to what the filled one holds')

    def test_stack_recipe_needs_its_stack(self):
        made = dict(stack_recipe='ancient armor', input_stacks=['/obj/item/stack/hydrogen'], made_empty=False, source='a.dm:1')
        dump_rows = {path: dump_row(path) for path in ['/obj/item/clothing/suit/ancient', '/obj/item/stack/hydrogen']}
        rows, _ = self.built(dump_rows, {'/obj/item/clothing/suit/ancient': dict(crafting=[made])})
        self.assertEqual(rows['/obj/item/clothing/suit/ancient']['firm_sources'], [])
        rows, _ = self.built(dump_rows, {'/obj/item/clothing/suit/ancient': dict(crafting=[made]), '/obj/item/stack/hydrogen': dict(other_routes=[dict(kind='gas recipe')])})
        self.assertEqual(rows['/obj/item/clothing/suit/ancient']['firm_sources'], ['crafting'])

    def test_made_by_use_needs_the_item_used(self):
        use = dict(from_item='/obj/item/pipe', source='a.dm:1')
        dump_rows = {path: dump_row(path) for path in ['/obj/item/grenade/ied', '/obj/item/pipe']}
        rows, entries = self.built(dump_rows, {'/obj/item/grenade/ied': dict(made_by_use=[use])})
        self.assertEqual(rows['/obj/item/grenade/ied']['firm_sources'], [], 'nobody can get the pipe')
        rows, entries = self.built(dump_rows, {'/obj/item/grenade/ied': dict(made_by_use=[use]), '/obj/item/pipe': dict(loot=[dict(channel='ruin')])})
        self.assertEqual(rows['/obj/item/grenade/ied']['firm_sources'], ['made_by_use'])
        self.assertIn('use:pipe', availability_text(entries['explosives']['/obj/item/grenade/ied']).split())

    def test_made_by_use_counts_a_subtype_of_the_item_used(self):
        use = dict(from_item='/obj/item/pipe', source='a.dm:1')
        dump_rows = {path: dump_row(path) for path in ['/obj/item/sliced_pipe', '/obj/item/pipe', '/obj/item/pipe/binary']}
        rows, _ = self.built(dump_rows, {'/obj/item/sliced_pipe': dict(made_by_use=[use]), '/obj/item/pipe/binary': dict(loot=[dict(channel='ruin')])})
        self.assertEqual(rows['/obj/item/sliced_pipe']['firm_sources'], ['made_by_use'], 'a subtype inherits the proc that makes it')
        self.assertTrue(rows['/obj/item/sliced_pipe']['sources']['made_by_use'][0]['routable'])

    def test_sheet_says_how_it_prints(self):
        def text(*designs, **sources):
            all_sources = dict(sources, printing=list(designs))
            return availability_text(dict(availability=availability(all_sources), sources=all_sources))

        def design(unlock, nodes=(), disks=()):
            return dict(design='/d', unlock=unlock, roundstart=unlock == 'roundstart', material_value=1, nodes=list(nodes), disks=list(disks))
        open_node = dict(id='a', rep_step_with_prereqs='advanced', hidden_with_prereqs=False)
        shut_node = dict(id='b', rep_step_with_prereqs='public', hidden=1, hidden_with_prereqs=True)
        self.assertEqual(text(design('roundstart')), 'print:rs')
        self.assertEqual(text(design('research', [open_node])), 'print:adv')
        self.assertEqual(text(design('hidden research', [shut_node])), 'print:hid', 'not print:pub')
        self.assertEqual(text(design('research', [open_node, shut_node])), 'print:adv,hid')
        self.assertEqual(text(design('hacked autolathe')), 'print:hack')
        self.assertEqual(text(design('design disk', disks=['/obj/item/disk'])), 'print:disk')
        self.assertEqual(text(design('no active research node')), 'print:other')

    def test_sheet_says_what_a_recipe_is_made_beside(self):
        def text(*crafting):
            sources = dict(crafting=list(crafting))
            return availability_text(dict(availability=availability(sources), sources=sources))
        eaten = dict(recipe='/r', machinery=['/obj/machinery/power/crystal'], uses_up=['/obj/machinery/power/crystal'], routable=True, kit_routes=[])
        cooked = dict(recipe='/r', machinery=['/obj/machinery/oven'], uses_up=[], routable=True, kit_routes=[])
        plain = dict(recipe='/r', machinery=[], uses_up=[], routable=True, kit_routes=[])
        missing = dict(eaten, routable=False, kit_routes=[dict(path='/obj/machinery/power/crystal', has_route=False)])
        self.assertEqual(text(eaten), 'craft@power/crystal!', 'it eats the crystal')
        self.assertEqual(text(cooked), 'craft@oven', 'the oven stays')
        self.assertEqual(text(cooked, plain), 'craft', 'another recipe needs no machine')
        self.assertEqual(text(missing), 'craft:nokit@power/crystal!')
        self.assertEqual(text(missing, cooked), 'craft@oven', 'only the recipe that works')

    def test_sheet_names_the_condition_on_a_sale(self):
        def text(**sources):
            return availability_text(dict(availability=availability(sources), sources=sources))
        self.assertEqual(text(cargo=[dict(availability='ordinary console')]), 'cargo')
        self.assertEqual(text(cargo=[dict(availability='emagged console')]), 'cargo:emag', 'not plain cargo')
        self.assertEqual(text(cargo=[dict(availability='contraband enabled')]), 'cargo:contraband')
        self.assertEqual(text(cargo=[dict(availability='special_enabled (runtime unlock)')]), 'cargo:special')
        self.assertEqual(text(cargo=[dict(availability='special_enabled by default')]), 'cargo', 'on by default needs nothing')
        self.assertEqual(text(cargo=[dict(availability='emagged console; contraband enabled')]), 'cargo:emag+contraband')
        self.assertEqual(text(cargo=[dict(availability='ordinary console'), dict(availability='emagged console')]), 'cargo cargo:emag')
        console = lambda kind: dict(where='x', offer='/datum/orderable_item/x', shop_type=f'/obj/machinery/computer/order_console/{kind}')
        self.assertEqual(text(order_consoles=[console('mining'), console('mining/golem')]), 'console:golem,mining', 'not the same as a black market')
        self.assertEqual(text(other_sellers=[dict(offer='/datum/market_item/clothing/floortileset')]), 'blackmarket')
        self.assertEqual(text(other_sellers=[dict(offer='/datum/voucher_set/mining/crusher_kit')]), 'voucher')
        self.assertEqual(text(other_sellers=[dict(offer='/datum/exploration_event/simple/trader/fish')]), 'drone')
        self.assertEqual(text(other_sellers=[dict(offer='/datum/something_new')]), 'seller')

    def test_sheet_splits_where_it_comes_from(self):
        def text(**sources):
            return availability_text(dict(availability=availability(sources), sources=sources))
        outfit = dict(kind='outfit', outfit='/o')
        self.assertEqual(text(starting=[outfit, dict(kind='vendor', placed=dict(hull=1))]), 'start:1o1v')
        self.assertEqual(text(starting=[dict(outfit, conditional=True)]), 'start:if', 'a veteran cloak: only under a condition')
        self.assertEqual(text(field_vendors=[dict(kind='vendor', placed=dict(ruin=2, npc_ship=1))]), 'vend:nr', 'a ruin vendor is not starting gear')
        unused = dict(by_kind=dict(hull_unused=dict(container=14)), distinct_maps=5)
        self.assertEqual(text(maps=unused), '', 'a fixed hull nothing spawns shows nothing')
        self.assertEqual(availability(dict(maps=unused))['placed_on_hulls'], 0)
        self.assertEqual(availability(dict(maps=unused))['placed_on_unused_hulls'], 14)
        self.assertEqual(text(maps=dict(by_kind=dict(ruin=dict(spawner=12))), loot=[]), 'rnd:r12', 'only ever from a random spawner')
        self.assertEqual(text(maps=dict(by_kind=dict(hull=dict(direct=2)))), 'map:h2')

    def test_coverage_counts_what_armor_covers(self):
        body_parts = dict(META, body_parts={'CHEST': 1, 'GROIN': 2, 'HEAD': 4, 'ARM_LEFT': 128, 'HAND_LEFT': 512, 'FOOT_LEFT': 32})
        rows = {'/obj/item/clothing/suit/x': dump_row('/obj/item/clothing/suit/x', clothing=dict(body_parts_covered=1 | 2 | 128 | 512 | 32))}
        entry = assemble(rows, body_parts, StubSources(self.dm, {}), scan_procs(self.dm))[1]['suits']['/obj/item/clothing/suit/x']
        self.assertEqual(entry['coverage'], 2, 'chest and an arm; check_armor never matches groin, hand or foot')
        self.assertEqual(entry['parts_covered'], 5)

    def test_ammo_says_what_a_hit_does(self):
        casing = dict(pellets=1, caliber='12', projectile=dict(damage=5, paralyze=100, knockdown=20, projectile_phasing=2))
        rows = {'/obj/item/ammo_casing/slug': dump_row('/obj/item/ammo_casing/slug', casing=casing)}
        ammo = assemble(rows, META, StubSources(self.dm, {}), scan_procs(self.dm))[1]['ammo']['/obj/item/ammo_casing/slug']
        self.assertEqual((ammo['paralyze'], ammo['knockdown'], ammo['through_walls']), (100, 20, True))
        line = sheet_text('ammo', dict(items={'/obj/item/ammo_casing/slug': dict(ammo, firm_sources=['loot'], known_sources=['loot'])}), {}).splitlines()[3]
        self.assertIn('para10s', line)
        self.assertIn('kd2s', line)
        self.assertIn('thru:WALLS', line)

    def test_a_rolled_var_is_named(self):
        (self.root / 'code' / 'late.dm').write_text("""
/obj/item/glove
	var/siemens = 1
	var/colour = "red"
/obj/item/glove/Initialize(mapload)
	. = ..()
	siemens = pick(0, 0.5, 1)
	colour = pick("red", "blue")
	icon_state = pick("a", "b")
	var/local = rand(1, 2)
""", encoding='utf-8')
        dm = DM(self.root)
        raw = dict(vars=dict(siemens=0, icon_state='a', colour='blue'))
        self.assertEqual(randomised_vars(dm, '/obj/item/glove', raw), dict(siemens='pick(0, 0.5, 1)'), 'not a look, a word or a local')
        entry = dict(path='/obj/item/clothing/gloves/x', name='x', status='ok', abstract=False, cosmetic=False, known_sources=['loot'], firm_sources=['loot'], siemens_coefficient=0, randomised=dict(siemens_coefficient='pick(0,1)'),
                     sources={}, availability=availability({}))
        text = sheet_text('gloves', dict(items={entry['path']: entry}), {})
        self.assertIn('rolls:siemens_coefficient=pick(0,1)', text)
        self.assertNotIn('insul', text.splitlines()[3], 'the dump happened to roll zero')

    def test_a_roll_the_type_rules_out_is_no_roll(self):
        (self.root / 'code' / 'late.dm').write_text("""
/obj/item/bottle
	var/count
	var/shiny = TRUE
	var/plain
	var/kept = 0

/obj/item/bottle/Initialize(mapload)
	if(!count)
		count = rand(1, 7)
	if(shiny)
		kept = rand(1, 2)
	if(isnull(plain))
		plain = rand(1, 3)
	if(mapload)
		kept = rand(3, 4)
	. = ..()

/obj/item/bottle/full
	count = 7

/obj/item/bottle/dull
	shiny = FALSE

/obj/item/bottle/set_zero
	plain = 0

/obj/item/bottle/runtime
	count = pick(1, 2)
""", encoding='utf-8')
        dm = DM(self.root)
        raw = dict(vars=dict(count=3, kept=1, plain=2))
        self.assertEqual(randomised_vars(dm, '/obj/item/bottle', raw), dict(count='rand(1, 7)', kept='rand(1, 2)', plain='rand(1, 3)'))
        self.assertNotIn('count', randomised_vars(dm, '/obj/item/bottle/full', raw), 'it sets 7, so the roll never runs')
        self.assertEqual(randomised_vars(dm, '/obj/item/bottle/dull', raw)['kept'], 'rand(3, 4)', 'if(shiny) is off, and if(mapload) is an argument: it could run')
        self.assertNotIn('plain', randomised_vars(dm, '/obj/item/bottle/set_zero', raw), 'zero is not null')
        self.assertIn('count', randomised_vars(dm, '/obj/item/bottle/runtime', raw), 'the value is itself decided at runtime')

    def test_a_rolled_number_is_not_shown_as_a_fact(self):
        entry = dict(path='/obj/item/storage/pill_bottle/x', name='x', status='ok', abstract=False, cosmetic=False, known_sources=['loot'], firm_sources=['loot'], sources={}, availability=availability({}),
                     other_vars=dict(spawn_count=3, other=4), randomised=dict(spawn_count='rand(1,7)'))
        row = sheet_text('medical', dict(items={entry['path']: entry}), {}).splitlines()[3]
        self.assertIn('rolls:spawn_count=rand(1,7)', row)
        self.assertNotIn('spawn_count=3', row)
        self.assertIn('other=4', row)

    def test_upgrades_print_on_their_sheet(self):
        text = sheet_text('modsuits', dict(items={}, upgrades=['MOD fitting bench, any suit, Plating: adds melee+15']), {})
        self.assertIn('# upgrade: MOD fitting bench, any suit, Plating: adds melee+15', text)

    def test_flags_decode_and_sheet_is_compact(self):
        self.assertEqual(decode_flags(3, {'B': 2, 'A': 1, 'C': 4}), ['A', 'B'])
        self.assertEqual(decode_flags(None, {'A': 1}), [])
        _, entries = self.built({
            '/obj/item/gun/a': dump_row('/obj/item/gun/a'),
            '/obj/item/gun/lost': dump_row('/obj/item/gun/lost'),
        }, {'/obj/item/gun/a': dict(loot=[dict(channel='ruin')])})
        text = sheet_text('guns', dict(items=entries['guns']), {'/obj/item/gun/a': 'does a trick'})
        self.assertIn('gun/a', text)
        self.assertIn('does a trick', text)
        self.assertIn('no route (1): gun/lost', text)


class ReaderFixture(unittest.TestCase):
    def reader(self, text):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        root = Path(self.temporary.name)
        (root / 'tgstation.dme').write_text('#include "code.dm"\n', encoding='utf-8')
        (root / 'code.dm').write_text(text, encoding='utf-8')
        return DM(root)

    def static(self, text, kind=StaticSources):
        found = kind.__new__(kind)
        found.dm = self.reader(text)
        found.root = found.dm.root
        found.source_index = collections.defaultdict(list)
        found.design_disks = {}
        return found


NODES = """
/datum/techweb_node
	var/id
	var/hidden = FALSE
	var/starting_node = FALSE
	var/zone_permission = 0
	var/list/prereq_ids = list()
	var/list/design_ids = list()

/datum/techweb_node/start
	id = "start"
	starting_node = TRUE
	design_ids = list("base")

/datum/techweb_node/public
	id = "public"
	prereq_ids = list("start")
	zone_permission = 1
	design_ids = list("plain", "shared")

/datum/techweb_node/shut
	id = "shut"
	hidden = TRUE
	prereq_ids = list("start")
	design_ids = list("rocket")

/datum/techweb_node/behind_shut
	id = "behind_shut"
	prereq_ids = list("shut")
	design_ids = list("later")

/datum/techweb_node/opens_by_sharing
	id = "opens_by_sharing"
	hidden = TRUE
	prereq_ids = list("start")
	zone_permission = 3
	design_ids = list("shared", "illegal")
"""


class ResearchTest(ReaderFixture):
    def test_a_hidden_node_shuts_everything_behind_it(self):
        static = self.static(NODES)
        static.build_nodes()
        static.gates = {}
        nodes = static.node_details
        self.assertFalse(nodes['public']['hidden_with_prereqs'])
        self.assertTrue(nodes['shut']['hidden_with_prereqs'])
        self.assertTrue(nodes['behind_shut']['hidden_with_prereqs'], 'its prerequisite can never be researched')

    def test_a_shared_design_opens_a_hidden_node(self):
        # add_design() drops every other node that grants a design out of hidden_nodes.
        static = self.static(NODES)
        static.build_nodes()
        static.gates = {}
        node = static.node_details['opens_by_sharing']
        self.assertFalse(node['hidden_with_prereqs'])
        self.assertEqual(node['opened_by'], ['public'])
        self.assertEqual(static.gate_with_prereqs('opens_by_sharing'), 3, 'its own gate')
        self.assertEqual(static.gate_with_prereqs('public'), 1)

    def test_a_conditional_removal_keeps_the_design(self):
        dm = self.reader("""
/datum/techweb_node/ai
	id = "ai"
	design_ids = list("aicore", "law")

/datum/techweb_node/ai/New()
	. = ..()
	if(HAS_TRAIT(SSstation, STATION_TRAIT_HUMAN_AI))
		design_ids -= list(
			"aicore",
		)

/datum/techweb_node/mining
	id = "mining"
	design_ids = list("drill", "express")

/datum/techweb_node/mining/New()
	. = ..()
	design_ids -= list(
		"express",
	)
""")
        self.assertEqual(list(dm.node_designs('/datum/techweb_node/ai')), ['aicore', 'law'])
        self.assertEqual(list(dm.node_designs('/datum/techweb_node/mining')), ['drill'], 'a plain removal still applies')

    def test_a_list_with_a_space_reads(self):
        dm = self.reader("""
/datum/design/implant
	materials = list (/datum/material/iron = 125, /datum/material/silver = 75)
""")
        self.assertEqual(dm.val('/datum/design/implant', 'materials'), [('/datum/material/iron', 125), ('/datum/material/silver', 75)])

    def test_a_nested_quote_does_not_swallow_the_file(self):
        text = '/obj/item/foo/bar()' + chr(10) + chr(9) + 'to_chat(user, "[b ? "it' + chr(39) + 's" : "no"]")' + chr(10) + '/obj/item/thing // a comment' + chr(10) + chr(9) + 'name = "x"' + chr(10)
        self.assertEqual(clean_comments(text).splitlines()[2].strip(), '/obj/item/thing')
        self.assertIn('/obj/item/thing', self.reader(text).headers)


class MadeByUseTest(ReaderFixture):
    def rows(self, text):
        static = self.static(text)
        static.build_made_by_use()
        return {path: [row['from_item'] for row in rows] for path, rows in static.made_by_use.items()}

    def test_what_a_use_proc_makes(self):
        self.assertEqual(self.rows("""
/obj/item/pipe/welder_act(mob/living/user, obj/item/welder)
	new /obj/item/sliced_pipe(drop_location())
	qdel(src)

/obj/item/sliced_pipe/attackby(obj/item/item, mob/user)
	var/obj/item/grenade/ied/bomb = new(drop_location())
	new /obj/item/sliced_pipe(src)

/obj/item/pipe/proc/not_a_use()
	new /obj/item/nothing(src)
"""), {'/obj/item/sliced_pipe': ['/obj/item/pipe'], '/obj/item/grenade/ied': ['/obj/item/sliced_pipe']})

    def test_handing_back_what_went_in_makes_nothing(self):
        self.assertEqual(self.rows("""
/obj/item/assembly/attackby(obj/item/I, mob/user)
	if(istype(I, /obj/item/saber))
		swords++
	if(I.tool_behaviour == TOOL_SCREWDRIVER)
		new /obj/item/saber(drop_location())
		new /obj/item/helmet(drop_location())
"""), {'/obj/item/helmet': ['/obj/item/assembly']})

    def test_taking_one_in_to_make_another_still_counts(self):
        self.assertEqual(self.rows("""
/obj/item/card/attackby(obj/item/I, mob/user)
	if(istype(I, /obj/item/deck))
		new /obj/item/deck(drop_location())
"""), {'/obj/item/deck': ['/obj/item/card']})


class RecipeMachineryTest(ReaderFixture):
    def test_what_a_recipe_uses_up(self):
        static = self.static("""
#define CRAFTING_MACHINERY_CONSUME 1
#define CRAFTING_MACHINERY_USE 0
#define CRAFTING_STRUCTURE_CONSUME 1

/datum/crafting_recipe/sword
	machinery = list(/obj/machinery/crystal = CRAFTING_MACHINERY_CONSUME, /obj/machinery/oven = CRAFTING_MACHINERY_USE)
	structures = list(/obj/structure/toilet = CRAFTING_STRUCTURE_CONSUME)
""")
        self.assertEqual(static.used_up_fixtures('/datum/crafting_recipe/sword'), ['/obj/machinery/crystal', '/obj/structure/toilet'])


class BiomeTest(ReaderFixture):
    def test_biome_features_are_a_loot_source(self):
        sources = self.static("""
/datum/planet/snow
	overworld_biomes = list("cold" = list("wet" = /datum/biome/xmas, "dry" = /datum/biome/xmas))
	cave_biomes = list("cold" = list("wet" = /datum/biome/rubble))

/datum/biome/xmas
	feature_spawn_chance = 10
	feature_spawn_list = list(/obj/item/gift = 50, /obj/item/storage/santabag = 1)
	flora_spawn_list = list(/obj/structure/flora/tree = 500)

/datum/biome/rubble
	feature_spawn_chance = 1
	feature_spawn_list = list(/obj/effect/spawner/random/maintenance = 1, /obj/structure/closet/crate/grave = 2)

/datum/biome/unused
	feature_spawn_list = list(/obj/item/never = 1)

/obj/structure/closet/crate/grave/PopulateContents()
	new /obj/item/shovel(src)
""", Sources)
        sources.dump = {}
        sources.loot = collections.defaultdict(list)
        sources.build_biome_features()
        bag = sources.loot['/obj/item/storage/santabag'][0]
        self.assertEqual((bag['channel'], bag['biome'], bag['weight'], bag['pool_weight'], bag['chance_per_turf']), ('biome', '/datum/biome/xmas', 1, 51, 10))
        self.assertEqual(sources.loot['/obj/item/shovel'][0]['via'], ['/obj/structure/closet/crate/grave'], 'what a crate on the ground holds')
        self.assertNotIn('/obj/item/never', sources.loot, 'no planet uses that biome')
        self.assertNotIn('/obj/effect/spawner/random/maintenance', sources.loot, 'map placements count the maintenance pool')
        self.assertNotIn('/obj/structure/flora/tree', sources.loot)


class StackRecipeTest(ReaderFixture):
    TEXT = """
#define SHEET 5

/obj/item/stack/sheet/coal
	name = "coal"

GLOBAL_LIST_INIT(hydrogen_recipes, list(
	new /datum/stack_recipe("ancient armor", /obj/item/clothing/suit/ancient, req_amount = SHEET, res_amount = 1, crafting_flags = NONE, category = CAT_CLOTHING),
	new/datum/stack_recipe("bolt", /obj/item/bolt, 2, 4),
	new /datum/stack_recipe("plain", /obj/item/plain),
	new /datum/stack_recipe_list("boxes", list(
		new /datum/stack_recipe("bang box", /obj/item/storage/box/bangs, crafting_flags = NONE),
		new /datum/stack_recipe("empty box", /obj/item/storage/box),
		new /datum/stack_recipe("kit box", /obj/item/storage/box/kit/crafted),
	)),
	))

/obj/item/stack/sheet/hydrogen
	name = "metal hydrogen"

/obj/item/stack/sheet/hydrogen/get_main_recipes()
	. = ..()
	. += GLOB.hydrogen_recipes

/obj/item/storage/box

/obj/item/storage/box/bangs/PopulateContents()
	for(var/i in 1 to 7)
		new /obj/item/grenade/bang(src)

/obj/item/storage/box/kit
	var/crafted = FALSE

/obj/item/storage/box/kit/PopulateContents()
	if(crafted)
		return
	new /obj/item/tank(src)

/obj/item/storage/box/kit/crafted
	crafted = TRUE
"""

    def rows(self):
        static = self.static(self.TEXT)
        static.build_stack_recipes()
        return static, {path: rows[0] for path, rows in static.source_index.items()}

    def test_input_stack_comes_from_who_uses_the_list(self):
        _, rows = self.rows()
        armor = rows['/obj/item/clothing/suit/ancient']
        self.assertEqual(armor['input_stacks'], ['/obj/item/stack/sheet/hydrogen'], 'not the coal declared above the list')
        self.assertEqual((armor['req_amount'], armor['result_amount']), (5, 1))

    def test_arguments_by_position_and_by_name(self):
        _, rows = self.rows()
        self.assertEqual((rows['/obj/item/bolt']['req_amount'], rows['/obj/item/bolt']['result_amount']), (2, 4), 'new/datum with no space')
        self.assertEqual(rows['/obj/item/plain']['req_amount'], 1, 'two arguments are enough')
        self.assertEqual(stack_recipe_args(['"a=b"', '/obj/x', 'category = CAT_X'])['title'], '"a=b"')

    def test_a_filled_box_comes_out_empty(self):
        _, rows = self.rows()
        self.assertTrue(rows['/obj/item/storage/box/bangs']['made_empty'])
        self.assertFalse(rows['/obj/item/storage/box']['made_empty'], 'an empty box is what it says')
        self.assertFalse(rows['/obj/item/storage/box/kit/crafted']['made_empty'], 'its PopulateContents returns on crafted')


class CargoTest(unittest.TestCase):
    def test_pack_counts(self):
        self.assertEqual(pack_counts([['/obj/item/defib', 2]]), {'/obj/item/defib': 2}, 'contains = list(type = 2)')
        self.assertEqual(pack_counts(['/obj/item/a', '/obj/item/a', '/obj/item/b']), {'/obj/item/a': 2, '/obj/item/b': 1})
        self.assertEqual(pack_counts('runtime validated material contents'), {})


HULLS = """
/datum/map_template/shuttle/voidcrew
	var/abstract = /datum/map_template/shuttle/voidcrew
	var/player_hidden = FALSE
	var/force_purchasable = FALSE
	var/has_upgrade_slots = FALSE
	var/list/upgrade_slot_ids = list()
	var/list/available_themes

/datum/map_template/shuttle/voidcrew/modular
	suffix = "modular"
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list("a")

/datum/map_template/shuttle/voidcrew/pill
	suffix = "pill"
	force_purchasable = TRUE

/datum/map_template/shuttle/voidcrew/fixed
	suffix = "fixed"

/datum/map_template/shuttle/voidcrew/dev
	suffix = "dev"
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list("a")
	player_hidden = TRUE

/datum/map_template/shuttle/voidcrew/pirate
	suffix = "pirate"

/obj/structure/overmap/ship/npc/raider
	shuttle_template = /datum/map_template/shuttle/voidcrew/pirate

/datum/ship_theme/modular_dark
	for_ship = /datum/map_template/shuttle/voidcrew/modular
	template_suffix = "modular_dark"

/datum/ship_theme/fixed_dark
	for_ship = /datum/map_template/shuttle/voidcrew/fixed
	template_suffix = "fixed_dark"

/datum/ship_upgrade_module/bay
	for_ship = /datum/map_template/shuttle/voidcrew/modular
	map_file = "bay/one.dmm"

/datum/ship_upgrade_module/old
	for_ship = /datum/map_template/shuttle/voidcrew/fixed
	map_file = "old/one.dmm"
"""


class HullTest(ReaderFixture):
    def sources(self):
        found = self.static(HULLS, Sources)
        found.classify_maps()
        return found

    def test_only_hulls_a_round_can_have_count(self):
        sources = self.sources()
        self.assertEqual(sources.played_hulls(), {'/datum/map_template/shuttle/voidcrew/modular', '/datum/map_template/shuttle/voidcrew/pill'})
        kinds = {name: sources.map_kind(f'_maps/voidcrew/ships/ship_{name}.dmm') for name in ['modular', 'modular_dark', 'pill', 'fixed', 'fixed_dark', 'dev', 'pirate', 'nothing']}
        self.assertEqual(kinds, dict(modular='hull', modular_dark='hull', pill='hull', fixed='hull_unused', fixed_dark='hull_unused', dev='hull_unused', pirate='npc_ship', nothing='hull_unreferenced'))
        self.assertEqual(sources.map_kind('_maps/voidcrew/ship_modules/bay/one.dmm'), 'module')
        self.assertEqual(sources.map_kind('_maps/voidcrew/ship_modules/bay/one_dark.dmm'), 'module', 'a themed file belongs to its base')
        self.assertEqual(sources.map_kind('_maps/voidcrew/ship_modules/old/one.dmm'), 'module_unused')

    def starting_rows(self, **attributes):
        sources = self.sources()
        defaults = dict(merge={}, shops={}, others={}, indexed={}, loots={}, vendors={}, starting={}, loadouts={}, closet_hits={}, placements={}, placement_maps={}, placement_expected={}, map_kinds={},
                        unused_outfits={}, made_by_use={}, blocked={}, mentions={}, buys=[], sheet=100)
        for name, value in dict(defaults, **attributes).items():
            setattr(sources, name, value)
        return sources.sources_for('/obj/item/thing', {})

    def test_starting_is_only_the_crews_own_ship(self):
        vendor = lambda **placed: dict(kind='vendor', machine='/obj/machinery/vending/x', placed=placed)
        found = self.starting_rows(vendors={'/obj/item/thing': [vendor(hull=1), vendor(ruin=2), vendor(npc_ship=1), vendor(hull_unused=3)]},
                                   closet_hits={'/obj/item/thing': {'/obj/structure/mine': dict(hull=1), '/obj/structure/theirs': dict(npc_ship=2), '/obj/structure/none': dict(hull_unused=1)}})
        self.assertEqual([row.get('placed') for row in found['starting']], [dict(hull=1), dict(hull=1)])
        self.assertEqual([row.get('container') for row in found['starting'] if row['kind'] == 'locker'], ['/obj/structure/mine'])
        self.assertEqual([row['placed'] for row in found['field_vendors']], [dict(ruin=2), dict(npc_ship=1)], 'a ruin vendor, an enemy ship vendor')
        self.assertEqual([row['placed'] for row in found['unplaced_vendors']], [dict(hull_unused=3)])

    def test_outfits_on_unused_hulls_are_set_apart(self):
        sources = self.sources()
        sources.outfit_uses = {
            '/datum/outfit/crew': [dict(hull='/datum/map_template/shuttle/voidcrew/modular', job='Crew'), dict(hull='/datum/map_template/shuttle/voidcrew/fixed', job='Old')],
            '/datum/outfit/old': [dict(hull='/datum/map_template/shuttle/voidcrew/fixed', job='Old')],
        }
        sources.dump = {}
        sources.outfit_items = lambda outfit: ((f'/obj/item/{outfit.rsplit("/", 1)[-1]}', 'suit', 'a.dm:1', False),)
        started = sources.starting_index()
        self.assertEqual(started['/obj/item/crew'][0]['hulls'], 1, 'the fixed hull it is also on doesn\'t count')
        self.assertEqual(sources.unused_outfits['/obj/item/old'][0]['hull_sample'], ['/datum/map_template/shuttle/voidcrew/fixed'])
        self.assertNotIn('/obj/item/old', started)

    def test_a_reward_under_a_condition_is_marked(self):
        code = """/datum/outfit/job/pre_equip(mob/H)
	back = /obj/item/plain
	if(client?.is_veteran())
		neck = /obj/item/cloak
	switch(H.backpack)
		if(GBACKPACK)
			back = /obj/item/grey
"""
        conditional = {name: under_condition(code, code.index(name)) for name in ['/obj/item/plain', '/obj/item/cloak', '/obj/item/grey']}
        self.assertEqual(conditional, {'/obj/item/plain': False, '/obj/item/cloak': True, '/obj/item/grey': True})


if __name__ == '__main__':
    unittest.main()
