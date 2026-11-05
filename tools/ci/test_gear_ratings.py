import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from tools.ci import check_gear_ratings as check
from tools.gear_catalog.__main__ import main as catalog_main
from tools.gear_catalog.dm_reader import DM, clean_comments
from tools.gear_catalog.notes import load_notes, note_rows, rating_note, write_batches
from tools.gear_catalog.ratings import (exception_problems, load_doc, load_docs, merge, policy_problems, ratings_problems, rating_text, score_input_problems, stale, sync, word_from_catalog, write_doc)
from tools.gear_catalog.recipes import covering_types, recipe_step, settle
from tools.gear_catalog.scoring import score_gun, tier_line
from tools.gear_catalog.sheets import score_cell, sheet_text


GUN = '/obj/item/gun/test'
SKU = '/datum/shop_sku/test'
POLICY = {
    'min_reputation': {'green': 'public', 'yellow': 'yellow', 'red': 'advanced'},
    'checked_routes': ['shops', 'cargo', 'order_consoles', 'other_sellers', 'printing', 'crafting'],
    'price_bands': {'guns': {'green': [0, 2500], 'yellow': [1000, 8000], 'red': [3000, 15000]}},
}
DME = '''
#include "code\\Items.dm"
'''
ITEMS_DM = '''
#define VOUCHER_CREDIT_VALUE 1200

/obj/item
/obj/item/gun
/obj/item/gun/test
/obj/item/gun/other
/obj/item/gun/kit_made
/obj/item/gun/core_made
/obj/item/gun/book_made
/obj/item/gun/stack_made
/obj/item/gun/made_of_made
/obj/item/kit
/obj/item/kit/fancy
/obj/item/core
/obj/item/book
/obj/item/stack
/obj/item/stack/sheet
/obj/item/stack/sheet/iron
/obj/item/stack/medical
/obj/item/stack/medical/gauze
	merge_type = /obj/item/stack/medical/gauze
/obj/item/stack/medical/gauze/twelve
/obj/item/food/cake

#ifdef TESTING
/obj/item/gun/debug
#endif
/obj/item/gun/VAR_PRIVATE
'''


def shop(price=1000, vouchers=0, step='public', sku=SKU, **extra):
    return dict(dict(sku=sku, credits=price, vouchers=vouchers, rep_step=step, fixed_price=0, contract_reward=1, source='voidcrew/shop.dm:12'), **extra)


def design(step=None, roundstart=False, unlock='research', name='/datum/design/test'):
    nodes = [dict(id='node', rep_step_with_prereqs=step)] if step else []
    return dict(design=name, roundstart=roundstart, unlock='roundstart' if roundstart else unlock, nodes=nodes, source='code/designs.dm:5')


def recipe(*ingredients, name='/datum/crafting_recipe/test', **extra):
    return dict(dict(recipe=name, ingredients={path: 1 for path in ingredients}, always_available=True, learned_from=[], non_craftable=None, source='code/recipes.dm:9'), **extra)


class StubStatic:
    """The part of StaticSources the check asks for, over a real DM reader of a small checkout."""

    def __init__(self, dm, routes):
        self.dm = dm
        self.table = routes

    def routes(self, path):
        return self.table.get(path) or self.table.get(self.merge_key(path)) or {}

    def routed_types(self):
        return set(self.table)

    def fixtures_for(self, needed):
        return {path: routes for path, routes in self.table.items() if path.startswith(('/obj/machinery', '/obj/structure')) and any(path == need or path.startswith(need + '/') for need in needed)}

    def merge_key(self, path):
        merged = self.dm.val(path, 'merge_type')
        return merged if isinstance(merged, str) else path


def rated(tier, **extra):
    return dict(dict(name='thing', group='all', tier=tier, rank=1, reason='A reason.', confidence='high', hash='abc'), **extra)


def doc(category='guns', items=None, unrated=None):
    return dict(category=category, method='How it is judged.', groups=['all'], items=items or {}, unrated=unrated or {})


class Fixture(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / 'game'
        (self.root / 'code').mkdir(parents=True)
        (self.root / 'tgstation.dme').write_text(DME, encoding='utf-8')
        (self.root / 'code' / 'Items.dm').write_text(ITEMS_DM, encoding='utf-8')
        self.dm = DM(self.root)

    def problems(self, routes, items=None, unrated=None, exceptions=(), policy=POLICY, category='guns'):
        docs = {category: doc(category, items, unrated)}
        return check.find_problems(StubStatic(self.dm, routes), docs, policy, list(exceptions))

    def rules(self, *args, **kwargs):
        errors, _ = self.problems(*args, **kwargs)
        return sorted((row['rule'], row['path'], row['route']) for row in errors)


class ReaderTest(Fixture):
    def test_includes_ignore_case_and_backslashes(self):
        (self.root / 'tgstation.dme').write_text('#include "CODE\\items.DM"\n', encoding='utf-8')
        self.assertIn('/obj/item/gun/test', DM(self.root).headers)

    def test_compiled_types_skip_testing_blocks_and_macro_lines(self):
        types = self.dm.compiled_types('/obj/item')
        self.assertIn('/obj/item/gun/test', types)
        self.assertNotIn('/obj/item/gun/debug', types)
        self.assertNotIn('/obj/item/gun/VAR_PRIVATE', types)

    def test_known_type_sees_implicit_parents_procs_and_directional_helpers(self):
        (self.root / 'code' / 'Items.dm').write_text('/obj/item/hidden/child\n/obj/item/procs_only/fire()\n\treturn\n', encoding='utf-8')
        dm = DM(self.root)
        self.assertTrue(dm.known_type('/obj/item/hidden'))
        self.assertTrue(dm.known_type('/obj/item/procs_only'))
        self.assertTrue(dm.known_type('/obj/item/hidden/directional/north'))
        self.assertFalse(dm.known_type('/obj/item/gone'))

    def test_clean_comments_keeps_every_offset(self):
        text = 'a // b\n"// kept" /* x /* y */ z\n*/ c \'/*\' "\\"//"'
        cleaned = clean_comments(text)
        self.assertEqual(len(cleaned), len(text))
        self.assertEqual(cleaned, 'a' + ' ' * 5 + '\n"// kept"' + ' ' * 15 + '\n   c \'/*\' "\\"//"')


class RuleTest(Fixture):
    def test_clean_when_rated_at_the_right_reputation(self):
        routes = {GUN: dict(shops=[shop(step='advanced', price=5000)])}
        self.assertEqual(self.rules(routes, {GUN: rated('red')}), [])

    def test_unrated_fails_with_a_checked_route_and_warns_without_one(self):
        routes = {GUN: dict(shops=[shop()]), '/obj/item/gun/other': dict(peddler=[shop(sku='/datum/shop_sku/peddler/x')], loot=[dict(channel='ruin')])}
        errors, warnings = self.problems(routes)
        self.assertEqual([(row['rule'], row['path'], row['route']) for row in errors], [('unrated', GUN, SKU)])
        self.assertEqual(errors[0]['file'], 'voidcrew/shop.dm')
        self.assertEqual(errors[0]['line'], 12)
        self.assertIn('/obj/item/gun/other', {row['path'] for row in warnings})
        self.assertNotIn('/obj/item/gun/debug', {row['path'] for row in warnings}, 'a real build has no such type')

    def test_non_gear_is_never_checked(self):
        routes = {'/obj/item/food/cake': dict(shops=[shop()])}
        self.assertEqual(self.rules(routes), [])

    def test_a_word_that_denies_a_route_does_not_hide_a_new_offer(self):
        routes = {GUN: dict(shops=[shop()])}
        for word in ('no route', 'literal only', 'admin', 'leftover'):
            self.assertEqual(self.rules(routes, unrated={GUN: word}), [('unrated', GUN, SKU)], word)
        for word in ('toy', 'needs another system', 'cosmetic', 'abstract', 'uncreatable'):
            self.assertEqual(self.rules(routes, unrated={GUN: word}), [], word)

    def test_below_reputation_by_shop(self):
        errors, _ = self.problems({GUN: dict(shops=[shop(step='public', price=5000)])}, {GUN: rated('red')})
        self.assertEqual([row['rule'] for row in errors], ['below_reputation'])
        message = errors[0]['message']
        self.assertIn(f'{GUN} is sold at no reputation by {SKU} but is rated red (needs advanced).', message)
        self.assertIn("Raise the SKU's zone_permission", message)
        self.assertIn('tools/gear_catalog/ratings/guns.json', message)
        self.assertIn('tools/gear_catalog/exceptions.json with a reason', message)

    def test_below_reputation_by_printing(self):
        rating = {GUN: rated('red')}
        self.assertEqual(self.rules({GUN: dict(printing=[design('yellow')])}, rating), [('below_reputation', GUN, '/datum/design/test')])
        self.assertEqual(self.rules({GUN: dict(printing=[design('advanced')])}, rating), [])
        self.assertEqual(self.rules({GUN: dict(printing=[design(roundstart=True)])}, rating), [('below_reputation', GUN, '/datum/design/test')], 'round start counts as public')
        self.assertEqual(self.rules({GUN: dict(printing=[design(unlock='hacked autolathe')])}, rating), [('below_reputation', GUN, '/datum/design/test')], 'hacking takes no reputation')
        self.assertEqual(self.rules({GUN: dict(printing=[design(unlock='no active research node / disk or special unlock required')])}, rating), [], 'a disk is a find')
        lowest = dict(design='/datum/design/test', roundstart=False, unlock='research', source='a.dm:1', nodes=[dict(id='a', rep_step_with_prereqs='advanced'), dict(id='b', rep_step_with_prereqs='public')])
        self.assertEqual(self.rules({GUN: dict(printing=[lowest])}, rating), [('below_reputation', GUN, '/datum/design/test')], 'the easiest node counts')

    def test_a_hidden_node_is_not_a_checked_route(self):
        def printed(*nodes):
            return {GUN: dict(printing=[dict(design='/datum/design/test', roundstart=False, unlock='research', source='a.dm:1', nodes=list(nodes))])}
        shut = dict(id='a', rep_step_with_prereqs='public', hidden=1, hidden_with_prereqs=True)
        behind = dict(id='b', rep_step_with_prereqs='public', hidden=0, hidden_with_prereqs=True)
        open_node = dict(id='c', rep_step_with_prereqs='yellow', hidden=0, hidden_with_prereqs=False)
        opened = dict(id='d', rep_step_with_prereqs='advanced', hidden=1, hidden_with_prereqs=False, opened_by=['c'])
        rating = {GUN: rated('red')}
        self.assertEqual(self.rules(printed(shut), rating), [], 'it comes from a disk, an experiment or an emag')
        self.assertEqual(self.rules(printed(behind), rating), [], 'behind a hidden node is the same')
        self.assertEqual(self.rules(printed(shut), {GUN: rated('above')}), [], 'not for above either')
        self.assertEqual(self.rules(printed(shut, open_node), rating), [('below_reputation', GUN, '/datum/design/test')], 'a plain node as well still counts')
        self.assertEqual(self.rules(printed(opened), rating), [], 'research that opens it counts at its own step')
        self.assertEqual(self.rules(printed(dict(opened, rep_step_with_prereqs='public')), rating), [('below_reputation', GUN, '/datum/design/test')])
        self.assertEqual(self.rules(printed(dict(id='old', rep_step_with_prereqs='public', hidden=1)), rating), [], 'a row with only the node\'s own flag')

    def test_below_reputation_on_cargo_consoles_and_sellers(self):
        rating = {GUN: rated('yellow')}
        self.assertEqual(self.rules({GUN: dict(cargo=[dict(pack='/datum/supply_pack/x', source='a.dm:1')])}, rating), [('below_reputation', GUN, '/datum/supply_pack/x')])
        self.assertEqual(self.rules({GUN: dict(order_consoles=[dict(offer='/datum/orderable_item/x', source='a.dm:1')])}, rating), [('below_reputation', GUN, '/datum/orderable_item/x')])
        self.assertEqual(self.rules({GUN: dict(other_sellers=[dict(offer='/datum/market_item/x', source='a.dm:1')])}, rating), [('below_reputation', GUN, '/datum/market_item/x')])
        self.assertEqual(self.rules({GUN: dict(other_sellers=[dict(offer='/datum/exploration_event/simple/trader/x', source='a.dm:1')])}, rating), [], 'exploration may bypass reputation')

    def test_loot_maps_starting_gear_and_peddlers_never_count(self):
        routes = {GUN: dict(peddler=[shop(price=99999)], loot=[dict(channel='ruin')], starting=[dict(kind='outfit')], other_routes=[dict(kind='hydroponics')])}
        self.assertEqual(self.rules(routes, {GUN: rated('above')}), [])

    def test_above_on_route(self):
        errors, _ = self.problems({GUN: dict(shops=[shop(step='elite', price=5000)])}, {GUN: rated('above')})
        self.assertEqual([row['rule'] for row in errors], ['above_on_route'])
        self.assertIn('rated above', errors[0]['message'])

    def test_none_tier_has_no_reputation_or_band(self):
        self.assertEqual(self.rules({GUN: dict(shops=[shop(price=999999)])}, {GUN: rated('none')}), [])

    def test_price_out_of_band_counts_vouchers(self):
        rating = {GUN: rated('yellow')}
        ok = shop(step='yellow', price=2000, vouchers=1)
        self.assertEqual(self.rules({GUN: dict(shops=[ok])}, rating), [])
        high = shop(step='yellow', price=2000, vouchers=6)
        errors, _ = self.problems({GUN: dict(shops=[high])}, rating)
        self.assertEqual([row['rule'] for row in errors], ['price_out_of_band'])
        self.assertEqual(errors[0]['price'], 9200)
        self.assertIn('outside the 1000 to 8000 cr band', errors[0]['message'])

    def test_price_skips_free_rows_missing_bands_and_peddlers(self):
        rating = {GUN: rated('yellow')}
        self.assertEqual(self.rules({GUN: dict(shops=[shop(step='yellow', price=0, fixed_price=1)])}, rating), [], 'a fixed price of 0 is not a price')
        self.assertEqual(self.rules({GUN: dict(shops=[shop(step='yellow', price=0, contract_reward=1)])}, rating), [], 'nor is a contract reward with none')
        self.assertEqual(self.rules({GUN: dict(shops=[shop(step='yellow', price=9000, contract_reward=1)])}, rating), [('price_out_of_band', GUN, SKU)], 'contract_reward only says a contract may pay it out')
        self.assertEqual(self.rules({GUN: dict(peddler=[shop(price=1)])}, rating), [])
        no_band = dict(POLICY, price_bands={})
        self.assertEqual(self.rules({GUN: dict(shops=[shop(step='yellow', price=999999)])}, rating, policy=no_band), [])

    def test_stacks_follow_merge_type(self):
        gauze, twelve = '/obj/item/stack/medical/gauze', '/obj/item/stack/medical/gauze/twelve'
        routes = {gauze: dict(shops=[shop(produced=twelve)])}
        self.assertEqual(self.rules(routes, {gauze: rated('green')}, category='medical'), [], 'the rating of what it merges into covers the 12-stack')
        self.assertEqual(self.rules(routes, {twelve: rated('yellow')}, category='medical'), [('below_reputation', twelve, SKU), ('unrated', gauze, SKU)], 'buying a stack counts for the type it merges into')

    def test_only_the_routes_in_the_policy_count(self):
        policy = dict(POLICY, checked_routes=['shops'])
        self.assertEqual(self.rules({GUN: dict(cargo=[dict(pack='/datum/supply_pack/x', source='a.dm:1')])}, {GUN: rated('red')}, policy=policy), [])


class CraftingTest(Fixture):
    def test_gate_is_the_highest_ingredient(self):
        routes = {
            '/obj/item/gun/kit_made': dict(crafting=[recipe('/obj/item/kit', '/obj/item/gun/other')]),
            '/obj/item/kit': dict(printing=[design('advanced', name='/datum/design/kit')]),
            '/obj/item/gun/other': dict(shops=[shop(step='yellow', price=2000)]),
        }
        items = {'/obj/item/gun/kit_made': rated('red'), '/obj/item/gun/other': rated('yellow')}
        self.assertEqual(self.rules(routes, items), [], 'the X-ray: kit at advanced, laser at yellow, rated red')
        routes['/obj/item/kit'] = dict(printing=[design('yellow', name='/datum/design/kit')])
        errors, _ = self.problems(routes, items)
        self.assertEqual([(row['rule'], row['route']) for row in errors], [('below_reputation', '/datum/crafting_recipe/test')])
        self.assertIn('crafted at yellow reputation', errors[0]['message'])

    def test_an_ingredient_with_no_checked_route_exempts_the_recipe(self):
        routes = {
            '/obj/item/gun/core_made': dict(crafting=[recipe('/obj/item/core', '/obj/item/kit')]),
            '/obj/item/kit': dict(printing=[design('yellow', name='/datum/design/kit')]),
            '/obj/item/core': dict(other_routes=[dict(kind='anomaly neutralization')], loot=[dict(channel='npc')]),
        }
        # The tesla cannon: a kit at low reputation, and a core you have to go and get.
        self.assertEqual(self.rules(routes, {'/obj/item/gun/core_made': rated('red')}), [])
        self.assertEqual(self.rules(routes, {'/obj/item/gun/core_made': rated('above')}), [], 'not a checked route for above either')
        errors, warnings = self.problems(routes)
        self.assertNotIn('/obj/item/gun/core_made', {row['path'] for row in errors}, 'nor for unrated')
        self.assertIn('/obj/item/gun/core_made', {row['path'] for row in warnings}, 'but it is unrated gear with no checked route')

    def test_basic_materials_count_as_public(self):
        routes = {
            '/obj/item/gun/stack_made': dict(crafting=[recipe('/obj/item/stack/sheet/iron', '/obj/item/kit')]),
            '/obj/item/stack/sheet/iron': dict(shops=[shop(step='advanced')]),
            '/obj/item/kit': dict(printing=[design('yellow', name='/datum/design/kit')]),
        }
        self.assertEqual(self.rules(routes, {'/obj/item/gun/stack_made': rated('yellow')}), [], 'yellow from the kit; the sheet asks nothing')
        self.assertEqual(self.rules({'/obj/item/gun/stack_made': routes['/obj/item/gun/stack_made'], '/obj/item/kit': routes['/obj/item/kit']}, {'/obj/item/gun/stack_made': rated('yellow')}), [], 'a sheet no checked route sells is a find')

    def test_stack_recipe_is_public(self):
        routes = {GUN: dict(crafting=[dict(stack_recipe='iron gun', input_stack='', req_amount=1, result_amount=1, source='a.dm:1')])}
        self.assertEqual(self.rules(routes, {GUN: rated('yellow')}), [('below_reputation', GUN, 'stack recipe: iron gun')])

    def test_a_subtype_of_the_ingredient_counts(self):
        routes = {'/obj/item/gun/kit_made': dict(crafting=[recipe('/obj/item/kit')]), '/obj/item/kit/fancy': dict(shops=[shop(step='yellow', sku='/datum/shop_sku/kit', price=2000)])}
        errors, _ = self.problems(routes, {'/obj/item/gun/kit_made': rated('red')})
        self.assertIn(('below_reputation', '/obj/item/gun/kit_made'), [(row['rule'], row['path']) for row in errors])

    def test_crafted_ingredients_chain(self):
        routes = {
            '/obj/item/gun/made_of_made': dict(crafting=[recipe('/obj/item/gun/kit_made', name='/datum/crafting_recipe/outer')]),
            '/obj/item/gun/kit_made': dict(crafting=[recipe('/obj/item/kit', name='/datum/crafting_recipe/inner')]),
            '/obj/item/kit': dict(printing=[design('yellow', name='/datum/design/kit')]),
        }
        self.assertEqual(self.rules(routes, {'/obj/item/gun/made_of_made': rated('yellow'), '/obj/item/gun/kit_made': rated('yellow')}), [])
        found = self.rules(routes, {'/obj/item/gun/made_of_made': rated('red'), '/obj/item/gun/kit_made': rated('yellow')})
        self.assertEqual(found, [('below_reputation', '/obj/item/gun/made_of_made', '/datum/crafting_recipe/outer')])

    def test_ordinary_ingredients_count_as_public(self):
        routes = {
            '/obj/item/gun/core_made': dict(crafting=[recipe('/obj/item/core', '/obj/item/kit')]),
            '/obj/item/kit': dict(printing=[design('yellow', name='/datum/design/kit')]),
        }
        rating = {'/obj/item/gun/core_made': rated('red')}
        self.assertEqual(self.rules(routes, rating), [], 'nobody sells the core, so it is a find')
        ordinary = dict(POLICY, ordinary_ingredients=[dict(path='/obj/item/core', reason='Lying around.')])
        self.assertEqual(self.rules(routes, rating, policy=ordinary), [('below_reputation', '/obj/item/gun/core_made', '/datum/crafting_recipe/test')], 'now the kit at yellow is the gate')
        self.assertEqual(self.rules(routes, {'/obj/item/gun/core_made': rated('yellow')}, policy=ordinary), [], 'and yellow is what it asks')
        self.assertEqual(self.rules({'/obj/item/core': dict(loot=[dict(channel='ruin')])}, {'/obj/item/core': rated('above')}, policy=ordinary, category='misc'), [], 'it is not an offer of the thing itself')

    def test_an_ordinary_prefix_covers_subtypes_and_what_is_above_it_stays(self):
        routes = {'/obj/item/gun/kit_made': dict(crafting=[recipe('/obj/item/kit')])}
        rating = {'/obj/item/gun/kit_made': rated('red')}
        by_prefix = dict(POLICY, ordinary_ingredients=[dict(path='/obj/item/kit', reason='x')])
        self.assertEqual(self.rules(routes, rating, policy=by_prefix), [('below_reputation', '/obj/item/gun/kit_made', '/datum/crafting_recipe/test')])
        by_subtype = dict(POLICY, ordinary_ingredients=[dict(path='/obj/item/kit/fancy', reason='x')])
        self.assertEqual(self.rules(routes, rating, policy=by_subtype), [('below_reputation', '/obj/item/gun/kit_made', '/datum/crafting_recipe/test')], 'a recipe takes a subtype')
        self.assertEqual(self.rules(routes, rating, policy=dict(POLICY, ordinary_ingredients=[dict(path='/obj/item/kitchen', reason='x')])), [], 'a prefix only matches whole path parts')

    def test_a_gone_ordinary_ingredient_warns(self):
        policy = dict(POLICY, ordinary_ingredients=[dict(path='/obj/item/gone', reason='x')])
        _, warnings = self.problems({}, policy=policy)
        self.assertIn(('missing_type', '/obj/item/gone', 'tools/gear_catalog/policy.json'), [(row['rule'], row['path'], row['file']) for row in warnings])

    def test_a_filled_box_is_not_an_offer(self):
        made = dict(stack_recipe='bang box', input_stacks=[], made_empty=True, source='a.dm:1')
        self.assertEqual(self.rules({GUN: dict(crafting=[made])}, {GUN: rated('above')}), [], 'the game empties it as it makes it')
        self.assertEqual(self.rules({GUN: dict(crafting=[dict(made, made_empty=False)])}, {GUN: rated('above')}), [('above_on_route', GUN, 'stack recipe: bang box')])

    def test_made_by_use_counts_when_the_policy_lists_it(self):
        used = dict(from_item='/obj/item/kit', source='a.dm:1')
        kit = dict(cargo=[dict(pack='/datum/supply_pack/x', source='a.dm:2')])
        ratings = {GUN: rated('above'), '/obj/item/kit': rated('green')}
        routes = {GUN: dict(made_by_use=[used]), '/obj/item/kit': kit}
        checked = dict(POLICY, checked_routes=POLICY['checked_routes'] + ['made_by_use'])
        self.assertEqual(self.rules(routes, ratings), [], 'not on the list')
        self.assertEqual(self.rules(routes, ratings, policy=checked), [('above_on_route', GUN, '/obj/item/kit')])
        self.assertEqual(self.rules({GUN: dict(made_by_use=[used])}, {GUN: rated('above')}, policy=checked), [], 'nobody can get the item used')
        self.assertEqual(self.rules({GUN: dict(made_by_use=[used]), '/obj/item/kit/good': kit}, {GUN: rated('above'), '/obj/item/kit/good': rated('green')}, policy=checked), [('above_on_route', GUN, '/obj/item/kit')], 'a subtype inherits the proc')
        chained = {GUN: dict(crafting=[recipe('/obj/item/kit')]), '/obj/item/kit': dict(made_by_use=[dict(from_item='/obj/item/kit/good', source='a.dm:3')]), '/obj/item/kit/good': kit}
        self.assertEqual(self.rules(chained, {GUN: rated('above'), '/obj/item/kit': rated('green'), '/obj/item/kit/good': rated('green')}, policy=checked), [('above_on_route', GUN, '/datum/crafting_recipe/test')], 'a recipe can use what it makes')

    def test_a_stack_recipe_needs_its_stack(self):
        made = dict(stack_recipe='ancient armor', input_stacks=['/obj/item/stack/sheet/iron'], source='a.dm:1')
        routes = {GUN: dict(crafting=[made])}
        self.assertEqual(self.rules(routes, {GUN: rated('red')}), [], 'nothing checked sells the sheet: found in the field')
        routes['/obj/item/stack/sheet/iron'] = dict(shops=[shop(step='advanced', sku='/datum/shop_sku/iron')])
        self.assertEqual(self.rules(routes, {GUN: rated('red'), '/obj/item/stack/sheet/iron': rated('red')}, category='guns'), [('below_reputation', GUN, 'stack recipe: ancient armor')], 'a sheet is no step, as in any recipe')

    def test_a_recipe_needs_its_machine(self):
        crystal = '/obj/machinery/crystal'
        kit = dict(shops=[shop(step='yellow', sku='/datum/shop_sku/kit', price=2000)])
        made = recipe('/obj/item/kit', machinery=[crystal])
        rating = {GUN: rated('red')}
        self.assertEqual(self.rules({GUN: dict(crafting=[made]), '/obj/item/kit': kit}, rating), [], 'nothing checked makes the machine')
        cargo = dict(cargo=[dict(pack='/datum/supply_pack/crystal', source='a.dm:1')])
        self.assertEqual(self.rules({GUN: dict(crafting=[made]), '/obj/item/kit': kit, crystal: cargo}, rating), [('below_reputation', GUN, '/datum/crafting_recipe/test')], 'a pack sells it')
        self.assertEqual(self.rules({GUN: dict(crafting=[made]), '/obj/item/kit': kit, crystal + '/shard': cargo}, rating), [('below_reputation', GUN, '/datum/crafting_recipe/test')], 'a subtype counts')
        board = dict(crafting=[recipe('/obj/item/core', name='/obj/item/core')])
        board_sold = dict(printing=[design('advanced', name='/datum/design/board')])
        self.assertEqual(self.rules({GUN: dict(crafting=[made]), '/obj/item/kit': kit, crystal: board, '/obj/item/core': board_sold}, rating), [], 'built from a board at advanced: that sets the gate')
        chain = {GUN: dict(crafting=[made]), '/obj/item/kit': kit, crystal: dict(crafting=[recipe('/obj/item/kit', machinery=['/obj/structure/forge'], name='/datum/crafting_recipe/crystal')])}
        self.assertEqual(self.rules(chain, rating), [], 'its own recipe needs a forge nothing makes')
        chain['/obj/structure/forge'] = cargo
        self.assertEqual(self.rules(chain, rating), [('below_reputation', GUN, '/datum/crafting_recipe/test')], 'machines chain')

    def test_a_recipe_needs_its_tool(self):
        kit = dict(shops=[shop(step='yellow', sku='/datum/shop_sku/kit', price=2000)])
        made = recipe('/obj/item/kit', tool_paths=['/obj/item/core'])
        self.assertEqual(self.rules({GUN: dict(crafting=[made]), '/obj/item/kit': kit}, {GUN: rated('red')}), [])
        self.assertEqual(self.rules({GUN: dict(crafting=[made]), '/obj/item/kit': kit, '/obj/item/core': dict(shops=[shop(sku='/datum/shop_sku/core')])}, {GUN: rated('red')}, category='guns')[0][0], 'below_reputation')

    def test_recipes_that_cannot_be_made_are_exempt(self):
        taught = recipe('/obj/item/kit', always_available=False, learned_from=['/obj/item/book'])
        kit = dict(shops=[shop(step='yellow', sku='/datum/shop_sku/kit', price=2000)])
        self.assertEqual(self.rules({GUN: dict(crafting=[taught]), '/obj/item/kit': kit}, {GUN: rated('red')}), [], 'nobody sells the book')
        sold_book = dict(shops=[shop(step='public', sku='/datum/shop_sku/book')])
        self.assertEqual(self.rules({GUN: dict(crafting=[taught]), '/obj/item/kit': kit, '/obj/item/book': sold_book}, {GUN: rated('red')}), [('below_reputation', GUN, '/datum/crafting_recipe/test')])
        self.assertEqual(self.rules({GUN: dict(crafting=[recipe('/obj/item/kit', non_craftable=1)]), '/obj/item/kit': kit}, {GUN: rated('red')}), [], 'non_craftable')

    def test_cycles_settle(self):
        steps = settle({}, {'/a': [recipe('/obj/item/b')], '/obj/item/b': [recipe('/obj/item/a')]}, {'/obj/item/a': ['/a'], '/obj/item/b': ['/obj/item/b']})
        self.assertEqual(steps, {}, 'two items made only from each other are out of reach')

    def test_shared_helpers(self):
        covers = covering_types(['/obj/item/kit/fancy', '/obj/item/core'], {'/obj/item/kit'}, self.dm.parent)
        self.assertEqual(covers['/obj/item/kit'], ['/obj/item/kit/fancy'])
        self.assertEqual(recipe_step(recipe('/obj/item/kit'), {'/obj/item/kit/fancy': 2}, covers), 2)
        self.assertIsNone(recipe_step(recipe('/obj/item/kit'), {}, covers))


class ExceptionTest(Fixture):
    def setUp(self):
        super().setUp()
        self.routes = {GUN: dict(shops=[shop(price=5000)])}
        self.rating = {GUN: rated('red')}

    def exception(self, **changes):
        return dict(dict(path=GUN, rule='below_reputation', route=SKU, reason='Sold this way on purpose.'), **changes)

    def test_an_exception_excuses_only_that_offer(self):
        self.assertEqual(self.rules(self.routes, self.rating, exceptions=[self.exception()]), [])
        second = shop(price=5000, sku='/datum/shop_sku/second')
        routes = {GUN: dict(shops=[shop(price=5000), second])}
        self.assertEqual(self.rules(routes, self.rating, exceptions=[self.exception()]), [('below_reputation', GUN, '/datum/shop_sku/second')], 'a new route for the same item still fails')

    def test_stale_exception_when_nothing_matches(self):
        errors, _ = self.problems({GUN: dict(shops=[shop(step='advanced', price=5000)])}, self.rating, exceptions=[self.exception()])
        self.assertEqual([(row['rule'], row['path'], row['file']) for row in errors], [('stale_exception', GUN, 'tools/gear_catalog/exceptions.json')])
        self.assertIn('no longer matches', errors[0]['message'])

    def test_stale_exception_for_a_path_that_is_gone(self):
        errors, _ = self.problems(self.routes, self.rating, exceptions=[self.exception(), self.exception(path='/obj/item/gun/gone')])
        self.assertEqual([(row['rule'], row['path']) for row in errors], [('stale_exception', '/obj/item/gun/gone')])
        self.assertIn('no longer exists', errors[0]['message'])

    def test_stale_exception_points_at_its_line(self):
        text = json.dumps([self.exception(path='/obj/item/gun/gone')], indent=1)
        errors, _ = check.find_problems(StubStatic(self.dm, {}), {}, POLICY, json.loads(text), text)
        self.assertEqual(errors[0]['line'], 3)

    def test_an_exception_needs_a_reason_and_a_real_rule(self):
        self.assertEqual(exception_problems([self.exception()]), [])
        self.assertTrue(exception_problems([self.exception(reason=' ')]))
        self.assertTrue(exception_problems([self.exception(rule='stale_exception')]))
        self.assertTrue(exception_problems([self.exception(route='')]))
        self.assertTrue(exception_problems([dict(path=GUN)]))

    def test_rating_for_a_gone_path_is_a_warning(self):
        errors, warnings = self.problems({}, {'/obj/item/gun/gone': rated('red')}, {'/obj/item/gun/lost': 'no route'})
        self.assertEqual(errors, [])
        self.assertEqual([row['path'] for row in warnings if row['rule'] == 'missing_type'], ['/obj/item/gun/gone', '/obj/item/gun/lost'])


class MainTest(Fixture):
    def setUp(self):
        super().setUp()
        folder = self.root / 'tools' / 'gear_catalog'
        (folder / 'ratings').mkdir(parents=True)
        (folder / 'policy.json').write_text(json.dumps(POLICY), encoding='utf-8')
        (folder / 'exceptions.json').write_text('[]\n', encoding='utf-8')
        write_doc(self.root, doc(items={GUN: rated('red')}))

    def run_main(self, routes, *flags):
        output = io.StringIO()
        with mock.patch.object(check, 'load_static', return_value=StubStatic(self.dm, routes)), contextlib.redirect_stdout(output):
            result = check.main(['--root', str(self.root), *flags])
        return result, output.getvalue()

    def test_github_annotations_point_at_the_offer(self):
        result, text = self.run_main({GUN: dict(shops=[shop(price=5000)])}, '--github')
        self.assertEqual(result, 1)
        self.assertIn('::error file=voidcrew/shop.dm,line=12::/obj/item/gun/test is sold at no reputation', text)
        self.assertIn('::warning file=tools/gear_catalog/ratings/guns.json::/obj/item/gun/other has no rating', text)

    def test_json_lists_every_violation(self):
        result, text = self.run_main({GUN: dict(shops=[shop(price=5000)])}, '--json')
        self.assertEqual(result, 1)
        found = json.loads(text)
        self.assertEqual([(row['rule'], row['path'], row['route']) for row in found['violations']], [('below_reputation', GUN, SKU)])
        self.assertTrue(found['warnings'])

    def test_clean_tree_passes(self):
        result, text = self.run_main({GUN: dict(shops=[shop(step='advanced', price=5000)])})
        self.assertEqual(result, 0)
        self.assertIn('0 errors', text)

    def test_a_bad_ratings_file_fails_with_its_name(self):
        (self.root / 'tools' / 'gear_catalog' / 'ratings' / 'guns.json').write_text('{"category": "guns"', encoding='utf-8')
        result, text = self.run_main({}, '--github')
        self.assertEqual(result, 1)
        self.assertIn('::error file=tools/gear_catalog/ratings/guns.json::', text)

    def test_unreadable_source_fails_cleanly(self):
        output = io.StringIO()
        with mock.patch.object(check, 'load_static', side_effect=AssertionError(('Missing SKU', '/datum/shop_sku/x'))), contextlib.redirect_stdout(output):
            self.assertEqual(check.main(['--root', str(self.root), '--github']), 1)
        self.assertIn('::error::Cannot read', output.getvalue())

    def test_annotation_text_is_escaped(self):
        self.assertEqual(check.escape_annotation('50% off\nnow'), '50%25 off%0Anow')
        self.assertEqual(check.escape_annotation('a:b,c', True), 'a%3Ab%2Cc')


class ValidationTest(unittest.TestCase):
    def test_good_file_passes(self):
        self.assertEqual(ratings_problems(doc(items={GUN: rated('red', score=262, note='Note.', locked=True)}, unrated={'/obj/item/gun/x': 'toy'})), [])

    def test_each_field_is_checked(self):
        bad = [
            dict(rated('purple')),
            dict(rated('red'), rank=0),
            dict(rated('red'), rank=True),
            dict(rated('red'), reason=''),
            dict(rated('red'), confidence='sure'),
            dict(rated('red'), group='elsewhere'),
            dict(rated('red'), score='high'),
            dict(rated('red'), locked=False),
            dict(rated('red'), misleads='not a rating field'),
            {key: value for key, value in rated('red').items() if key != 'hash'},
        ]
        for item in bad:
            self.assertTrue(ratings_problems(doc(items={GUN: item})), item)

    def test_file_level_rules(self):
        self.assertTrue(ratings_problems(doc(unrated={GUN: 'because'})))
        self.assertTrue(ratings_problems(doc(items={GUN: rated('red')}, unrated={GUN: 'toy'})))
        self.assertTrue(ratings_problems(doc('food')))
        self.assertTrue(ratings_problems(doc(items={'/obj/item/clothing/glasses/x': rated('red')})), 'wrong category')
        self.assertTrue(ratings_problems(dict(doc(items={GUN: rated('red')}), method='')), 'a rated category says how')
        self.assertEqual(ratings_problems(dict(doc(unrated={GUN: 'toy'}), method='', groups=[])), [], 'a file of only words needs no method yet')

    def test_score_inputs_shapes(self):
        good = dict(rate=dict(value=0.5, why='x'), points=dict(value=-5, why='x'), cell_fed=dict(value=False, why='x'),
                    extra_mode=dict(label='buck', damage=30, pellets=6, why='x'))
        self.assertEqual(score_input_problems(GUN, good), [])
        self.assertEqual(score_input_problems(GUN, dict(rate=dict(listed=True, why='x'))), [])
        for bad in (dict(rate=dict(value=1)), dict(rate=dict(why='x')), dict(cell_fed=dict(value=True, why='x')), dict(magic=dict(value=1, why='x')), dict(extra_mode=dict(why='x', label='a'))):
            self.assertTrue(score_input_problems(GUN, bad), bad)

    def test_policy_rules(self):
        self.assertEqual(policy_problems(POLICY), [])
        self.assertTrue(policy_problems(dict(POLICY, min_reputation=dict(red='famous'))))
        self.assertTrue(policy_problems(dict(POLICY, checked_routes=['loot'])))
        self.assertTrue(policy_problems(dict(POLICY, price_bands=dict(guns=dict(red=[9, 1])))))
        self.assertEqual(policy_problems(dict(POLICY, ordinary_ingredients=[dict(path='/obj/item/shard', reason='Break a window.')])), [])
        for bad in ('shard', [dict(path='/obj/item/shard')], [dict(path='/obj/item/shard', reason=' ')], [dict(path='shard', reason='x')], [dict(path='/obj/item/shard', reason='x', extra=1)]):
            self.assertTrue(policy_problems(dict(POLICY, ordinary_ingredients=bad)), bad)

    def test_tracked_files_are_valid(self):
        root = Path(__file__).resolve().parents[2]
        docs, problems = load_docs(root)
        self.assertEqual(problems, [])
        for category, found in docs.items():
            self.assertEqual((root / 'tools/gear_catalog/ratings' / f'{category}.json').read_text(encoding='utf-8'), rating_text(found), f'{category} is hand formatted')
        self.assertEqual(policy_problems(json.loads((root / 'tools/gear_catalog/policy.json').read_text(encoding='utf-8'))), [])
        self.assertEqual(exception_problems(json.loads((root / 'tools/gear_catalog/exceptions.json').read_text(encoding='utf-8'))), [])


def catalog_entry(path, **changes):
    entry = dict(path=path, name=path.rsplit('/', 1)[-1], status='ok', abstract=False, cosmetic=False, gear=True, known_sources=['loot'], firm_sources=['loot'], facts_hash='hash-' + path.rsplit('/', 1)[-1], note_owners=[])
    return dict(entry, **changes)


class CommandTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / 'game'
        self.out = Path(self.temporary.name) / 'out'
        (self.out / 'items').mkdir(parents=True)
        self.root.mkdir()
        self.catalog({
            '/obj/item/gun/real': catalog_entry('/obj/item/gun/real'),
            '/obj/item/gun/rated': catalog_entry('/obj/item/gun/rated', modes=[dict(label='semi', damage_per_shot=30, stamina_per_shot=0, pellets=1, capacity=20, shots_per_second=2, automatic=False, burst_size=1, projectile={}, casing='a')], kind='ballistic', note_owners=['/obj/item/gun']),
            '/obj/item/gun/locked': catalog_entry('/obj/item/gun/locked'),
            '/obj/item/gun/base': catalog_entry('/obj/item/gun/base', abstract=True),
            '/obj/item/gun/hat': catalog_entry('/obj/item/gun/hat', cosmetic=True),
            '/obj/item/gun/lost': catalog_entry('/obj/item/gun/lost', known_sources=[], firm_sources=[]),
            '/obj/item/gun/literal': catalog_entry('/obj/item/gun/literal', firm_sources=[]),
            '/obj/item/gun/never': catalog_entry('/obj/item/gun/never', status='uncreatable'),
            '/obj/item/gun/gone_soon': catalog_entry('/obj/item/gun/gone_soon', status='self_deleted'),
        })
        (self.out / 'items' / 'food.json').write_text(json.dumps(dict(items={'/obj/item/food/cake': catalog_entry('/obj/item/food/cake', gear=False)})), encoding='utf-8')

    def catalog(self, items):
        (self.out / 'items' / 'guns.json').write_text(json.dumps(dict(items=items)), encoding='utf-8')

    def rater_file(self, **data):
        path = Path(self.temporary.name) / 'rater.json'
        path.write_text(json.dumps(data), encoding='utf-8')
        return path

    def seed(self):
        doc_ = doc(items={'/obj/item/gun/rated': rated('yellow', hash='hash-rated'), '/obj/item/gun/locked': rated('green', hash='hash-locked', locked=True)}, unrated={'/obj/item/gun/lost': 'no route'})
        write_doc(self.root, doc_)

    def test_stale_lists(self):
        write_doc(self.root, doc(items={'/obj/item/gun/rated': rated('yellow', hash='old'), '/obj/item/gun/removed': rated('red')}, unrated={'/obj/item/gun/lost': 'no route', '/obj/item/gun/also_removed': 'admin'}))
        found = stale(self.root, self.out)
        self.assertEqual([row['path'] for row in found['new']], ['/obj/item/gun/locked', '/obj/item/gun/real'])
        self.assertEqual([(row['path'], row['rated_hash'], row['catalog_hash']) for row in found['changed']], [('/obj/item/gun/rated', 'old', 'hash-rated')])
        self.assertEqual([(row['path'], row['where']) for row in found['removed']], [('/obj/item/gun/removed', 'items'), ('/obj/item/gun/also_removed', 'unrated')])

    def test_stale_filters_and_prints_json(self):
        self.seed()
        self.assertEqual(stale(self.root, self.out, 'eyewear'), dict(new=[], changed=[], removed=[]))
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            self.assertEqual(catalog_main(['--root', str(self.root), '--out', str(self.out), 'stale', '--category', 'guns', '--json']), 0)
        self.assertEqual([row['path'] for row in json.loads(output.getvalue())['new']], ['/obj/item/gun/real'])

    def test_stale_sees_real_gear_behind_an_old_mechanical_word(self):
        write_doc(self.root, doc(unrated={'/obj/item/gun/real': 'no route', '/obj/item/gun/locked': 'admin'}))
        self.assertEqual([row['path'] for row in stale(self.root, self.out)['new']], ['/obj/item/gun/rated', '/obj/item/gun/real'], "a rater's word stands")

    def test_sync_fills_mechanical_words_and_leaves_raters_alone(self):
        write_doc(self.root, doc(items={'/obj/item/gun/rated': rated('yellow')}, unrated={'/obj/item/gun/lost': 'admin', '/obj/item/gun/real': 'no route'}))
        sync(self.root, self.out)
        found = load_doc(self.root, 'guns')
        self.assertEqual(found['unrated'], {'/obj/item/gun/base': 'abstract', '/obj/item/gun/hat': 'cosmetic', '/obj/item/gun/lost': 'admin', '/obj/item/gun/literal': 'literal only',
                                            '/obj/item/gun/never': 'uncreatable', '/obj/item/gun/gone_soon': 'uncreatable'})
        self.assertIn('/obj/item/gun/rated', found['items'])
        self.assertIsNone(load_doc(self.root, 'food'), 'not a gear category')
        before = (self.root / 'tools/gear_catalog/ratings/guns.json').read_bytes()
        sync(self.root, self.out)
        self.assertEqual((self.root / 'tools/gear_catalog/ratings/guns.json').read_bytes(), before, 'stable')

    def test_word_from_catalog(self):
        self.assertIsNone(word_from_catalog(catalog_entry('/x')))
        self.assertEqual(word_from_catalog(catalog_entry('/x', known_sources=[], firm_sources=[])), 'no route')

    def test_merge_stamps_hash_score_and_note_and_replaces_only_named_paths(self):
        self.seed()
        notes = self.out / 'notes'
        notes.mkdir()
        (notes / 'a.jsonl').write_text(json.dumps(dict(path='/obj/item/gun', note='Owner note.', effect='special')) + '\n' + json.dumps(dict(path='/obj/item/gun/rated', note='Plumbing.', effect='plumbing')) + '\n', encoding='utf-8')
        (notes / 'batch-1.json').write_text(json.dumps([dict(path='/obj/item/gun/real', category='guns', name='real', desc='', procs=[], parts=[], items=[])]), encoding='utf-8')
        item = dict(name='rated', group='all', tier='red', rank=2, reason='Better.', confidence='low')
        source = self.rater_file(category='guns', method='New method.', groups=['all', 'extra'], items={'/obj/item/gun/rated': item}, unrated={'/obj/item/gun/real': 'toy'})
        written, refused, dropped, problems = merge(self.root, self.out, source)
        self.assertEqual((sorted(written), refused, dropped, problems), (['/obj/item/gun/rated', '/obj/item/gun/real'], [], [], []))
        found = load_doc(self.root, 'guns')
        rating = found['items']['/obj/item/gun/rated']
        self.assertEqual(rating['tier'], 'red')
        self.assertEqual(rating['hash'], 'hash-rated')
        self.assertEqual(rating['note'], 'Owner note.', "the owner's note, and not the item's plumbing one")
        self.assertEqual(rating['score'], round(score_gun(catalog_entry('/x', modes=[dict(label='semi', damage_per_shot=30, stamina_per_shot=0, pellets=1, capacity=20, shots_per_second=2, projectile={}, casing='a')], kind='ballistic'))['score']))
        self.assertIn('/obj/item/gun/locked', found['items'], 'unnamed paths stay')
        self.assertEqual(found['unrated'], {'/obj/item/gun/lost': 'no route', '/obj/item/gun/real': 'toy'})
        self.assertEqual(found['groups'], ['all', 'extra'])
        self.assertEqual(found['method'], 'New method.')

    def test_merge_refuses_a_locked_tier_and_merges_the_rest(self):
        self.seed()
        change = dict(name='locked', group='all', tier='red', rank=1, reason='Raters disagree.', confidence='low')
        other = dict(name='real', group='all', tier='green', rank=3, reason='Fine.', confidence='high')
        written, refused, _, problems = merge(self.root, self.out, self.rater_file(category='guns', items={'/obj/item/gun/locked': change, '/obj/item/gun/real': other}))
        self.assertEqual(problems, [])
        self.assertEqual(written, ['/obj/item/gun/real'])
        self.assertEqual(len(refused), 1)
        self.assertIn('/obj/item/gun/locked', refused[0])
        found = load_doc(self.root, 'guns')
        self.assertEqual(found['items']['/obj/item/gun/locked']['tier'], 'green')
        self.assertEqual(found['items']['/obj/item/gun/locked']['reason'], 'A reason.', 'the ruling stands whole')
        self.assertIn('/obj/item/gun/real', found['items'])

    def test_merge_keeps_a_lock_when_the_tier_matches_and_ignores_a_raters_lock(self):
        self.seed()
        same = dict(name='locked', group='all', tier='green', rank=4, reason='Reworded.', confidence='high')
        sneaky = dict(name='real', group='all', tier='red', rank=1, reason='Mine now.', confidence='high', locked=True)
        written, refused, dropped, problems = merge(self.root, self.out, self.rater_file(category='guns', items={'/obj/item/gun/locked': same, '/obj/item/gun/real': sneaky}))
        self.assertEqual((refused, dropped, problems), ([], ['/obj/item/gun/real'], []))
        found = load_doc(self.root, 'guns')
        self.assertTrue(found['items']['/obj/item/gun/locked']['locked'])
        self.assertEqual(found['items']['/obj/item/gun/locked']['rank'], 4)
        self.assertNotIn('locked', found['items']['/obj/item/gun/real'])

    def test_merge_refuses_to_unrate_a_locked_item(self):
        self.seed()
        _, refused, _, problems = merge(self.root, self.out, self.rater_file(category='guns', unrated={'/obj/item/gun/locked': 'toy'}))
        self.assertEqual(problems, [])
        self.assertEqual(len(refused), 1)
        self.assertIn('/obj/item/gun/locked', load_doc(self.root, 'guns')['items'])

    def test_merge_writes_nothing_when_a_rating_is_bad(self):
        self.seed()
        before = (self.root / 'tools/gear_catalog/ratings/guns.json').read_bytes()
        bad_tier = dict(name='real', group='all', tier='purple', rank=1, reason='x', confidence='high')
        for data in (dict(category='guns', items={'/obj/item/gun/real': bad_tier}), dict(category='guns', items={'/obj/item/gun/invented': dict(bad_tier, tier='red')}), dict(category='food'), dict(items={}), dict(category='guns', surprise=1)):
            _, _, _, problems = merge(self.root, self.out, self.rater_file(**data))
            self.assertTrue(problems, data)
            self.assertEqual((self.root / 'tools/gear_catalog/ratings/guns.json').read_bytes(), before)

    def test_merge_category_flag(self):
        self.seed()
        item = dict(name='real', group='all', tier='green', rank=1, reason='x', confidence='high')
        _, _, _, problems = merge(self.root, self.out, self.rater_file(items={'/obj/item/gun/real': item}), 'guns')
        self.assertEqual(problems, [])
        self.assertIn('/obj/item/gun/real', load_doc(self.root, 'guns')['items'])
        _, _, _, problems = merge(self.root, self.out, self.rater_file(category='guns'), 'eyewear')
        self.assertTrue(problems)

    def test_merge_command_prints_refusals_and_exit_codes(self):
        self.seed()
        change = dict(name='locked', group='all', tier='red', rank=1, reason='x', confidence='low')
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            result = catalog_main(['--root', str(self.root), '--out', str(self.out), 'merge', str(self.rater_file(category='guns', items={'/obj/item/gun/locked': change}))])
        self.assertEqual(result, 0)
        self.assertIn('refused: /obj/item/gun/locked', output.getvalue())

    def test_ratings_format_is_stable(self):
        text = rating_text(doc(items={GUN: rated('red')}))
        self.assertTrue(text.endswith('\n'))
        self.assertEqual(json.loads(text), doc(items={GUN: rated('red')}))
        keys = list(json.loads(text))
        self.assertEqual(keys, sorted(keys))


class NotesTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.out = Path(self.temporary.name)
        (self.out / 'notes').mkdir()
        (self.out / 'items').mkdir()
        items = {
            '/obj/item/gun/a': dict(name='a', desc='A gun.', note_owners=['/obj/item/gun/a'], behaviour_procs=['/obj/item/gun/a/fire', '/obj/item/gun/base/load'], behaviour_parts=['/datum/component/odd']),
            '/obj/item/gun/b': dict(name='b', desc='', note_owners=['/obj/item/gun/base', '/obj/projectile/x'], behaviour_procs=['/obj/item/gun/base/load'], chain_behaviour_procs=['/obj/projectile/x/on_hit']),
            '/obj/item/gun/base': dict(name='base', desc='Base.', note_owners=[]),
        }
        (self.out / 'items' / 'guns.json').write_text(json.dumps(dict(items=items)), encoding='utf-8')
        summary = dict(note_rule=dict(selected=2, distinct_owner_types=3, owners=['/obj/item/gun/a', '/obj/item/gun/base', '/obj/projectile/x'], by_category=dict(guns=['/obj/item/gun/a', '/obj/item/gun/b'], melee=[])))
        (self.out / 'summary.json').write_text(json.dumps(summary), encoding='utf-8')

    def test_batches_skip_noted_owners_and_list_the_rest(self):
        self.assertEqual(write_batches(self.out, 2), (2, 3))
        first = json.loads((self.out / 'notes' / 'batch-1.json').read_text(encoding='utf-8'))
        self.assertEqual([row['path'] for row in first], ['/obj/item/gun/a', '/obj/item/gun/base'])
        self.assertEqual(sorted(first[0]), ['category', 'desc', 'items', 'name', 'parts', 'path', 'procs'])
        self.assertEqual(first[0]['procs'], ['fire'])
        self.assertEqual(first[0]['parts'], ['/datum/component/odd'])
        self.assertEqual(first[1]['items'], [dict(path='/obj/item/gun/b', name='b')])
        self.assertEqual(first[1]['procs'], ['load'])
        second = json.loads((self.out / 'notes' / 'batch-2.json').read_text(encoding='utf-8'))
        self.assertEqual(second[0]['path'], '/obj/projectile/x')
        self.assertEqual(second[0]['procs'], ['on_hit'])
        self.assertIsNone(second[0]['name'])

    def test_batches_shrink_and_old_ones_go(self):
        write_batches(self.out, 1)
        self.assertTrue((self.out / 'notes' / 'batch-3.json').exists())
        (self.out / 'notes' / 'done.jsonl').write_text(json.dumps(dict(path='/obj/item/gun/base', note='Loads.', effect='special')) + '\n' + json.dumps(dict(path='/obj/projectile/x', note='Hits.', effect='special')) + '\n', encoding='utf-8')
        self.assertEqual(write_batches(self.out, 1), (1, 1))
        self.assertFalse((self.out / 'notes' / 'batch-2.json').exists())
        self.assertTrue((self.out / 'notes' / 'done.jsonl').exists())

    def test_an_owner_is_done_when_every_item_has_its_own_note(self):
        (self.out / 'notes' / 'done.jsonl').write_text(json.dumps(dict(path='/obj/item/gun/b', note='Item note.', effect='special')) + '\n', encoding='utf-8')
        self.assertEqual(write_batches(self.out, 40), (1, 1))
        self.assertEqual([row['path'] for row in json.loads((self.out / 'notes' / 'batch-1.json').read_text(encoding='utf-8'))], ['/obj/item/gun/a'])

    def test_note_loading_ignores_batches_and_half_written_files(self):
        (self.out / 'notes' / 'batch-1.json').write_text(json.dumps([dict(path='/obj/item/gun/a', note='Not a note, a work list.')]), encoding='utf-8')
        (self.out / 'notes' / 'broken.jsonl').write_text('{"path": "/obj/item/gun/b", "no', encoding='utf-8')
        (self.out / 'notes' / 'good.jsonl').write_text(json.dumps(dict(path='/obj/item/gun/c', note='Real.', effect='special')) + '\n\n', encoding='utf-8')
        (self.out / 'notes' / 'later.jsonl').write_text(json.dumps(dict(path='/obj/item/gun/c', note='Newer.', effect='unknown')) + '\n', encoding='utf-8')
        self.assertEqual(load_notes(self.out), {'/obj/item/gun/c': 'Newer.'})
        self.assertEqual(note_rows(self.out)['/obj/item/gun/c']['effect'], 'unknown')

    def test_rating_note_skips_plumbing_and_joins_owners(self):
        rows = {'/a': dict(note='One.', effect='special'), '/b': dict(note='Pipes.', effect='plumbing'), '/c': dict(note='Two.', effect='unknown'), '/d': dict(note='One.', effect='special')}
        self.assertEqual(rating_note('/a', ['/b', '/c', '/d'], rows), 'One. / Two.')
        self.assertEqual(rating_note('/b', [], rows), '')


LASER = dict(path='laser', kind='energy', spread=0, weapon_weight_name='WEAPON_LIGHT', modes=[dict(label='kill', casing='lens', damage_per_shot=25, stamina_per_shot=0, pellets=1, capacity=16, shots_per_second=2.5, automatic=False, burst_size=1, projectile=dict(armor_flag='laser'))])
THOMPSON = dict(path='tommygun', kind='ballistic', spread=0, semi_auto=1, weapon_weight_name='WEAPON_LIGHT', modes=[dict(label='auto', casing='c45', damage_per_shot=30, stamina_per_shot=0, pellets=1, capacity=50, shots_per_second=10, automatic=True, burst_size=1, projectile=dict(armor_flag='bullet'))])
DISABLER = dict(path='disabler', kind='energy', spread=0, weapon_weight_name='WEAPON_LIGHT', modes=[dict(label='disable', casing='disabler', damage_per_shot=0, stamina_per_shot=30, pellets=1, capacity=20, shots_per_second=2.5, automatic=False, burst_size=1, projectile=dict(armor_flag='energy'))])
SURPLUS = dict(path='surplus', kind='ballistic', spread=0, semi_auto=0, weapon_weight_name='WEAPON_HEAVY', modes=[dict(label='semi', casing='a', damage_per_shot=60, stamina_per_shot=0, pellets=1, capacity=5, shots_per_second=2, automatic=False, burst_size=1, projectile=dict(armor_flag='bullet', weak_against_armour=1))])


class ScoringTest(unittest.TestCase):
    def test_the_first_ratings_numbers_stand(self):
        # Rows and scores from the first rating pass: laser gun 44, Thompson 262, disabler 32, surplus rifle 15.
        self.assertEqual(round(score_gun(LASER)['score']), 44)
        self.assertEqual(round(score_gun(THOMPSON)['score']), 262)
        self.assertEqual(round(score_gun(DISABLER)['score']), 32)
        self.assertEqual(round(score_gun(SURPLUS)['score']), 15)

    def test_the_tier_line_is_on_the_vest_number(self):
        self.assertEqual(round(score_gun(THOMPSON)['bare']), 375)
        self.assertEqual(round(score_gun(SURPLUS)['bare']), 61, 'weak against armor: the bare number shows what the vest hides')
        self.assertEqual(tier_line(score_gun(SURPLUS)['score']), 'green')
        self.assertEqual([tier_line(score) for score in (39.9, 40, 109.9, 110)], ['green', 'yellow', 'yellow', 'red'])

    def test_rate_inputs(self):
        slow = dict(rate=dict(value=0.25, why='Two cranks.'))
        self.assertEqual(score_gun(LASER, slow)['score'], 25 * 0.7 * 0.25 * 1.25)
        listed = dict(rate=dict(listed=True, why='Racks itself.'))
        self.assertEqual(round(score_gun(SURPLUS, listed)['score'] / score_gun(SURPLUS)['score'], 3), round(1 / 0.6, 3))

    def test_damage_inputs_and_hit(self):
        self.assertEqual(score_gun(LASER, dict(damage=dict(value=55, why='x')))['score'], 55 * 0.7 * 2.5 * 0.8 * 1.25)
        armorless = score_gun(LASER, dict(armorless_damage=dict(value=10, why='x')))
        self.assertEqual(armorless['score'], (17.5 + 10) * 2.5 * 0.8 * 1.25)
        self.assertEqual(armorless['bare'], (25 + 10) * 2.5 * 0.8 * 1.25)
        wide = dict(DISABLER, spread=40)
        self.assertAlmostEqual(score_gun(wide, dict(hit=dict(value=0.8, why='x')))['score'] / score_gun(DISABLER)['score'], 0.8)

    def test_cell_fed_and_points_and_judged(self):
        self.assertEqual(score_gun(LASER, dict(cell_fed=dict(value=False, why='x')))['score'], score_gun(LASER)['score'] / 1.25)
        self.assertEqual(score_gun(LASER, dict(points=dict(value=10, why='x')))['score'], score_gun(LASER)['score'] + 10)
        self.assertEqual(score_gun(LASER, dict(points=dict(value=10, why='x')))['basis'], 'formula+hand')
        self.assertEqual(score_gun(LASER, dict(judged=dict(value=45, why='x'))), dict(score=45, bare=None, basis='judged'))

    def test_second_load_needs_a_different_casing(self):
        selector = dict(LASER, modes=LASER['modes'] + [dict(LASER['modes'][0], label='burst', shots_per_second=1)])
        self.assertEqual(score_gun(selector)['score'], score_gun(LASER)['score'], 'a fire selector is the same round')
        second = dict(LASER, modes=LASER['modes'] + [dict(LASER['modes'][0], label='other', casing='other', shots_per_second=1)])
        self.assertGreater(score_gun(second)['score'], score_gun(LASER)['score'])

    def test_extra_modes(self):
        buckshot = dict(extra_mode=dict(label='buckshot', damage=30, pellets=6, armour_penetration=0, weak=0, why='x'))
        shotgun = dict(path='shotgun', kind='ballistic', semi_auto=0, spread=0, weapon_weight_name='WEAPON_HEAVY', modes=[dict(label='semi', casing='beanbag', damage_per_shot=10, stamina_per_shot=55, pellets=1, capacity=4, shots_per_second=2, projectile=dict(armor_flag='bullet'))])
        self.assertGreater(score_gun(shotgun, buckshot)['score'], score_gun(shotgun)['score'])
        tether = dict(extra_mode=dict(label='tether', armorless_stamina=60, rate=1.0, why='x'))
        self.assertGreater(score_gun(LASER, tether)['score'], score_gun(LASER)['score'])

    def test_taser_tether_replaces_stamina_and_rate(self):
        taser = dict(path='taser', kind='energy', spread=0, weapon_weight_name='WEAPON_LIGHT', modes=[dict(label='taser', casing='t', damage_per_shot=0, stamina_per_shot=0, pellets=1, capacity=5, shots_per_second=2.5, projectile={})])
        scored = score_gun(taser, dict(armorless_stamina=dict(value=60, rate=1.0, why='x')))
        self.assertEqual(round(scored['score']), 40)
        self.assertEqual(scored['score'], scored['bare'], 'past armor')

    def test_a_gun_that_does_not_fire_has_no_score(self):
        self.assertIsNone(score_gun(dict(path='x', modes=[])))

    def test_sheet_shows_scores(self):
        self.assertEqual(score_cell(THOMPSON, None), 's262 red bare375')
        self.assertEqual(score_cell(LASER, dict(tier='yellow', score_inputs=dict(judged=dict(value=45, why='x')))), 's45 yellow judged')
        self.assertEqual(score_cell(LASER, dict(tier='above')), '', 'a tier set by rule has no score')
        self.assertEqual(score_cell(LASER, dict(tier='none')), '')
        entry = dict(THOMPSON, path='/obj/item/gun/t', name='Thompson', status='ok', abstract=False, cosmetic=False, known_sources=['loot'], firm_sources=['loot'], sources={}, w_class=3, availability=dict(
            cheapest_credits=None, cheapest_credits_with_vouchers=None, voucher_only_shops=0, shop_zones=[], lowest_rep_step=None, peddler_zones=[], peddler_cheapest_credits=None, printable_roundstart=False, printable_by_research=False,
            printable_hidden=False, printable_hacked=False, printable_from_disk=[], crafted=False, crafted_empty=False, made_by_use=False, crafted_kit_missing=[], learned_from=[], cargo_packs=0, starting_outfits=0, starting_conditional=0,
            starting_vendors=0, field_vendor_kinds=[], placed_on_hulls=0, placed_on_modules=0, placed_in_ruins=0, placed_at_outposts=0, placed_on_npc_ships=0, spawner_placements={}))
        entry['modes'] = [dict(entry['modes'][0], target=dict(vest=dict(dps=210)), dps=300, stamina_dps=0)]
        text = sheet_text('guns', dict(items={'/obj/item/gun/t': entry}), {}, dict(items={}))
        self.assertIn('s262 red bare375', text)
        self.assertIn('| score |', text.splitlines()[0])

    def test_real_catalog_keeps_its_scores(self):
        root = Path(__file__).resolve().parents[2]
        source = root / 'data' / 'gear_catalog' / 'items' / 'guns.json'
        if not source.exists():
            self.skipTest('no catalog in this checkout')
        items = json.loads(source.read_text(encoding='utf-8'))['items']
        moved = {}
        for path, rating in load_doc(root, 'guns')['items'].items():
            if 'score' in rating and path in items:
                scored = score_gun(items[path], rating.get('score_inputs'))
                if not scored or round(scored['score']) != rating['score']:
                    moved[path] = (rating['score'], scored and scored['score'])
        self.assertEqual(moved, {})


if __name__ == '__main__':
    unittest.main()
