import json
from pathlib import Path
import tempfile
import unittest

from tools.gear_catalog.build import assemble, is_abstract, scan_procs, write_outputs
from tools.gear_catalog.categories import GEAR_CATEGORIES, NOT_GEAR_CATEGORIES, category_of, is_gear
from tools.gear_catalog.combat import blocked_percent, fire_mode, melee_state, penetrate_armour, reload_facts
from tools.gear_catalog.dm_reader import DM
from tools.gear_catalog.sections import decode_flags
from tools.gear_catalog.sheets import sheet_text


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

    def __init__(self, dm, routes):
        self.dm = dm
        self.routes = routes
        self.type_checked = set()
        self.ingredients = set()

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
        self.assertTrue(is_abstract('/obj/item/gun', dict(name='gun', no_sprite=False), True, ['loot']), 'the category base with its generic name')
        self.assertTrue(is_abstract('/obj/item/thing', dict(name='thing', no_sprite=True), True, ['loot']), 'no sprite')
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


if __name__ == '__main__':
    unittest.main()
