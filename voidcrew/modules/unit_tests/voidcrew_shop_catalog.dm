/**
 * # Outpost shop catalog integrity
 *
 * ~370 stocked SKUs across ten shelves, and the one thing that decides whether
 * a SKU is ever visible is a hand-typed string: `category` has to match an
 * entry in its shop's `categories` list or the storefront never renders it.
 * A SKU that misses is fully authored, priced, stocked and invisible, the
 * same failure mode voidcrew_loot.dm's reachability test was written to catch,
 * one layer up. shop_catalog_job_packs.dm's own header warns about it in prose.
 *
 * The other half is the shop's own tables: pools that must hold real SKU paths,
 * SKUs that must dispense a real movable, and buybacks/exclusive rewards that
 * must be real types.
 */

/datum/unit_test/voidcrew_shop_catalog/Run()
	var/shops_checked = 0
	var/skus_checked = 0
	for(var/shop_type in subtypesof(/datum/outpost_shop))
		var/datum/outpost_shop/shop = new shop_type(null)
		// Abstract parents carry no shelf of their own.
		if(!length(shop.categories))
			qdel(shop)
			continue
		shops_checked++
		var/list/every_sku = shop.sku_types + shop.rotating_pool + shop.rare_pool + shop.chart_pool
		for(var/datum/shop_rotation/rotation as anything in shop.live_rotations)
			for(var/sku_type in rotation.pool)
				every_sku += sku_type
		for(var/datum/shop_sku/sku_type as anything in every_sku)
			if(!ispath(sku_type, /datum/shop_sku))
				TEST_FAIL("[shop_type] lists [sku_type], which is not a /datum/shop_sku")
				continue
			skus_checked++
			var/category = initial(sku_type.category)
			if(!(category in shop.categories))
				TEST_FAIL("[shop_type] stocks [sku_type] under category '[category]', which is not in that shop's categories list. The SKU is priced and stocked and the storefront never renders it. Nobody can buy it.")
			if(initial(sku_type.is_chart))
				continue // intel SKUs legitimately dispense nothing
			var/item_path = initial(sku_type.item_path)
			if(!ispath(item_path, /atom/movable))
				TEST_FAIL("[sku_type] has item_path [item_path], which is not a spawnable movable, buying it hands over nothing")
			if(initial(sku_type.price_credits) < 0 || initial(sku_type.price_vouchers) < 0)
				TEST_FAIL("[sku_type] has a negative price")
			if(initial(sku_type.stock_min) > initial(sku_type.stock_max))
				TEST_FAIL("[sku_type] has stock_min above stock_max, so its per-round stock roll is inverted")
		for(var/datum/shop_buyback/buyback_type as anything in shop.buyback_types)
			if(!ispath(buyback_type, /datum/shop_buyback))
				TEST_FAIL("[shop_type] lists [buyback_type] as a buyback, which is not a /datum/shop_buyback")
		for(var/list/request as anything in shop.mission_requests)
			if(!islist(request))
				TEST_FAIL("[shop_type] has a malformed mission_requests row")
				continue
			if(!ispath(request["type"], /atom/movable))
				TEST_FAIL("[shop_type] requests [request["type"]], which is not a spawnable movable")
			if(!is_outpost_procurement_type(request["type"]))
				TEST_FAIL("[shop_type] requests unsupported procurement goods [request["type"]]")
			if((request["amount"] || 0) < 1)
				TEST_FAIL("[shop_type] requests [request["amount"]] of [request["type"]]")
			// A stack ask is settled off ONE stack (deliver/can_turn_in), so an
			// amount above that stack's max_amount is unpayable: the contract
			// posts, accepts, and then refuses every hand-over forever. The
			// outfitter shipped a 60-coil ask against MAXCOIL 30 this way.
			if(ispath(request["type"], /obj/item/stack))
				var/obj/item/stack/asked = request["type"]
				var/ceiling = initial(asked.max_amount)
				if(request["amount"] > ceiling)
					TEST_FAIL("[shop_type] requests [request["amount"]] of [request["type"]], but that stack caps at [ceiling] - the contract can never be turned in")
		TEST_ASSERT_EQUAL(length(shop.get_procurement_requests()), length(shop.mission_requests), "[shop_type] has procurement rows that fail eligibility")
		qdel(shop)

	TEST_ASSERT(shops_checked >= 5, "only [shops_checked] shops with a category list were checked")
	TEST_ASSERT(skus_checked >= 100, "only [skus_checked] SKUs were checked. The catalog walk is not seeing the shelves")

	var/list/banned_gear = list(
		/obj/item/restraints/legcuffs/bola,
		/obj/item/clothing/glasses/hud/health/sunglasses,
		/obj/item/mod/core/standard,
	)
	for(var/datum/shop_sku/sku_type as anything in subtypesof(/datum/shop_sku))
		TEST_ASSERT(!(initial(sku_type.item_path) in banned_gear), "[sku_type] still sells removed craftable gear.")
		TEST_ASSERT(findtext("[initial(sku_type.item_path)]/", "/obj/item/blueprint/") != 1, "[sku_type] still sells a schematic.")

/// Existing field-good quantities and difficulties, including owner exceptions.
/datum/unit_test/voidcrew_procurement_catalog/Run()
	// Difficulty literals are EASY/MEDIUM/HARD (1/2/3); fork defines compile later.
	var/list/expected_catalogs = list(
		/datum/outpost_shop/general = list(
			list(/obj/item/fish, 1, 1),
			list(/obj/item/stack/sheet/animalhide/bear, 1, 2),
			list(/obj/item/stack/spice_pods, 6, 2),
			list(/obj/item/sea_crystal, 1, 3),
		),
		/datum/outpost_shop/black_market = list(
			list(/obj/item/stack/telecrystal_raw, 10, 3),
			list(/obj/item/organ/monster_core/regenerative_core/legion, 1, 3),
		),
		/datum/outpost_shop/outfitter = list(
			list(/obj/item/stack/sheet/animalhide/goliath_hide, 4, 3),
			list(/obj/item/stack/sheet/sinew, 4, 2),
			list(/obj/item/stack/glacial_core, 5, 2),
			list(/obj/item/mod/construction/broken_core, 2, 1),
			list(/obj/item/mod/control/pre_equipped, 1, 2),
			list(/obj/item/mod/module/springlock, 1, 2),
			list(/obj/item/mod/module/visor/rave, 1, 2),
			list(/obj/item/mod/module/balloon, 1, 2),
			list(/obj/item/mod/module/stamp, 1, 2),
		),
	)
	for(var/shop_type in expected_catalogs)
		var/datum/outpost_shop/shop = allocate(shop_type)
		var/list/expected_requests = expected_catalogs[shop_type]
		TEST_ASSERT_EQUAL(length(shop.mission_requests), length(expected_requests), "[shop_type] has unexpected procurement rows")
		for(var/list/expected as anything in expected_requests)
			var/list/found
			for(var/list/request as anything in shop.mission_requests)
				if(request["type"] == expected[1])
					found = request
					break
			TEST_ASSERT_NOTNULL(found, "[shop_type] lost its [expected[1]] request")
			TEST_ASSERT_EQUAL(found["amount"], expected[2], "[shop_type] changed its [expected[1]] quantity")
			TEST_ASSERT_EQUAL(found["difficulty"], expected[3], "[shop_type] changed its [expected[1]] difficulty")
		if(istype(shop, /datum/outpost_shop/general))
			TEST_ASSERT(shop.extra_offer_mix[/datum/mission/outpost_supply/angler] > 0, "The owner's angler exception must remain available")
			TEST_ASSERT(shop.extra_offer_mix[/datum/mission/outpost_supply/cook] > 0, "The owner's Kitchen Orders must remain available")

	var/datum/outpost_shop/vendor/suit_fitter/fitter = allocate(/datum/outpost_shop/vendor/suit_fitter)
	TEST_ASSERT_EQUAL(length(fitter.mission_requests), 6, "The fitter must supply all six salvage requests")
	var/datum/mission/delivery/delivery = allocate(/datum/mission/delivery)
	TEST_ASSERT_EQUAL(delivery.weight, 0, "Ore-only ship deliveries must not roll")
	TEST_ASSERT(delivery.generation_failed, "Explicit generation must also refuse suspended ship deliveries")
	TEST_ASSERT_EQUAL(length(delivery.objectives), 0, "Suspended deliveries must not build an ore objective")

/// Unsupported and malformed rows never enter the ordinary supply pool.
/datum/unit_test/voidcrew_procurement_filter/Run()
	var/datum/outpost_shop/general/shop = allocate(/datum/outpost_shop/general)
	var/list/valid = list("type" = /obj/item/stack/telecrystal_raw, "name" = "raw telecrystal", "amount" = 10, "difficulty" = 3)
	shop.mission_requests = list(
		"malformed",
		list("type" = /obj/item/stack/ore/iron, "name" = "iron", "amount" = 10, "difficulty" = 1),
		list("type" = /obj/item/stack/sheet/plasteel, "name" = "plasteel", "amount" = 10, "difficulty" = 2),
		list("type" = /obj/item/stack/cable_coil, "name" = "cable", "amount" = 30, "difficulty" = 1),
		list("type" = /obj/item/mod/control, "name" = "control", "amount" = 1, "difficulty" = 1),
		list("type" = /obj/item/mod/module, "name" = "module", "amount" = 1, "difficulty" = 1),
		list("type" = /obj/item/mod/module/storage, "name" = "module", "amount" = 1, "difficulty" = 1),
		list("type" = /obj/item/stack/telecrystal_raw, "name" = "raw telecrystal", "amount" = 0, "difficulty" = 3),
		list("type" = /obj/item/stack/telecrystal_raw, "name" = "raw telecrystal", "amount" = 31, "difficulty" = 3),
		list("type" = /obj/item/stack/telecrystal_raw, "name" = "raw telecrystal", "amount" = 1.5, "difficulty" = 3),
		list("type" = /obj/item/stack/telecrystal_raw, "name" = "raw telecrystal", "amount" = 10),
	)
	var/datum/mission/outpost_supply/rejected = allocate(/datum/mission/outpost_supply, shop)
	TEST_ASSERT(rejected.generation_failed, "An unsupported-only request pool must fail generation")
	shop.mission_requests += list(valid)
	var/list/filtered = shop.get_procurement_requests()
	TEST_ASSERT_EQUAL(length(filtered), 1, "Unsupported rows survived the eligibility filter")
	TEST_ASSERT_EQUAL(filtered[1], valid, "The filter must retain the original compliant request")
	var/datum/mission/outpost_supply/accepted = allocate(/datum/mission/outpost_supply, shop)
	TEST_ASSERT(!accepted.generation_failed, "A compliant request must still generate")
	TEST_ASSERT_EQUAL(accepted.required_type, valid["type"], "Generation chose an unsupported request")
	TEST_ASSERT_EQUAL(accepted.required_amount, 10, "Generation changed a compliant quantity")
	TEST_ASSERT_EQUAL(accepted.difficulty, 3, "Generation changed a compliant difficulty")
	TEST_ASSERT(istype(accepted.objectives[1], /datum/mission_objective/deliver/procurement), "Ordinary supply requests must use procurement validation")

/// Empty and unsupported-only pools must let other offers fill the board.
/datum/unit_test/voidcrew_procurement_empty_board/Run()
	var/obj/structure/overmap/trader_outpost/outpost = allocate(/obj/structure/overmap/trader_outpost)
	// Kitchen Orders need no overmap target, making this a deterministic board.
	outpost.shop.extra_offer_mix = list(
		/datum/mission/recovery/kill/outpost = 0,
		/datum/mission/recovery/outpost = 0,
		/datum/mission/outpost_courier = 0,
		/datum/mission/outpost_supply/cook = 1,
	)
	var/list/pools = list(
		list(),
		list(list("type" = /obj/item/stack/ore/iron, "name" = "iron", "amount" = 10, "difficulty" = 1)),
		list(list("type" = /obj/item/stack/glacial_core, "name" = "glacial cores", "amount" = 5, "difficulty" = 2)),
	)
	for(var/list/pool as anything in pools)
		for(var/datum/mission/posted as anything in outpost.shop_offers.Copy())
			qdel(posted)
		outpost.shop_offers.Cut()
		outpost.shop.mission_requests = pool
		outpost.next_contract_refill = world.time
		outpost.ensure_shop_offers()
		// OUTPOST_SHOP_OFFER_COUNT = 4, defined after this test's include.
		TEST_ASSERT_EQUAL(length(outpost.shop_offers), 4, "Supply eligibility stalled the outpost board")
		TEST_ASSERT_EQUAL(outpost.has_posted_offer_type(/datum/mission/outpost_supply), length(pool) && is_outpost_procurement_type(pool[1]["type"]), "Only eligible pools should force a plain supply request")

/// Exact loot-module eligibility must not silently expand with printable designs.
/datum/unit_test/voidcrew_procurement_module_sources/Run()
	var/list/loot_modules = list(/obj/item/mod/module/springlock, /obj/item/mod/module/visor/rave, /obj/item/mod/module/balloon, /obj/item/mod/module/stamp)
	var/obj/effect/spawner/random/mod/maint/spawner_type = /obj/effect/spawner/random/mod/maint
	var/list/loot = initial(spawner_type.loot)
	for(var/module_type in loot_modules)
		TEST_ASSERT(module_type in loot, "Eligible [module_type] lost its loot source")
		TEST_ASSERT(is_outpost_procurement_type(module_type), "The loot module [module_type] must be supported")
	for(var/datum/design/design_type as anything in subtypesof(/datum/design))
		TEST_ASSERT(!(initial(design_type.build_path) in loot_modules), "[design_type] can print eligible loot module [initial(design_type.build_path)]")
	for(var/datum/crafting_recipe/recipe_type as anything in subtypesof(/datum/crafting_recipe))
		TEST_ASSERT(!(initial(recipe_type.result) in loot_modules), "[recipe_type] can craft an eligible loot module")

/// Procurement rejects forged submissions and consumes only eligible goods.
/datum/unit_test/voidcrew_procurement_turn_in/Run()
	var/obj/structure/overmap/ship/receiving_ship = allocate(/obj/structure/overmap/ship)
	receiving_ship.ship_account = allocate(/datum/bank_account)
	var/list/unsupported_types = list(
		/obj/item/stack/ore/iron,
		/obj/item/stack/sheet/plasteel,
		/obj/item/stack/cable_coil,
		/obj/item/mod/control,
		/obj/item/mod/module,
		/obj/item/mod/module/storage,
		/obj/item/mod/module/visor/meson,
		/obj/item/mod/module/balloon/advanced,
	)
	for(var/item_type in unsupported_types)
		var/datum/mission/mission = allocate(/datum/mission)
		mission.requires_item = TRUE
		mission.servant = receiving_ship
		mission.active = TRUE
		var/datum/mission_objective/deliver/procurement/ask = new
		ask.required_type = item_type
		mission.add_objective(ask)
		var/obj/item/item = allocate(item_type)
		TEST_ASSERT(!mission.turn_in(run_loc_floor_bottom_left, item), "A forged [item_type] turn-in must fail")
		TEST_ASSERT_EQUAL(ask.accept_item(item, run_loc_floor_bottom_left), 0, "Direct acceptance must refuse unsupported [item_type]") // MISSION_ITEM_REFUSED
		TEST_ASSERT(!QDELETED(item), "Refusing [item_type] must not consume it")

	var/datum/mission/control_mission = allocate(/datum/mission)
	control_mission.requires_item = TRUE
	control_mission.servant = receiving_ship
	control_mission.active = TRUE
	var/datum/mission_objective/deliver/procurement/control_ask = new
	control_ask.required_type = /obj/item/mod/control/pre_equipped
	control_mission.add_objective(control_ask)
	var/obj/item/mod/control/manufactured = allocate(/obj/item/mod/control)
	TEST_ASSERT(!control_mission.turn_in(run_loc_floor_bottom_left, manufactured), "An assembled base control cannot satisfy a salvaged-control ask")
	var/obj/item/mod/control/pre_equipped/salvaged = allocate(/obj/item/mod/control/pre_equipped/standard)
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(wearer.equip_to_slot_if_possible(salvaged, ITEM_SLOT_BACK), "The control fixture must be worn")
	TEST_ASSERT(!control_mission.turn_in(run_loc_floor_bottom_left, salvaged), "A worn salvaged control must be refused")
	TEST_ASSERT_EQUAL(control_ask.accept_item(salvaged, run_loc_floor_bottom_left), 0, "Direct acceptance must also refuse a worn control")
	TEST_ASSERT(!QDELETED(salvaged), "A refused worn suit must survive")
	TEST_ASSERT(wearer.dropItemToGround(salvaged), "The salvaged control must be removable")
	TEST_ASSERT(control_mission.turn_in(run_loc_floor_bottom_left, salvaged), "An unworn pre-equipped control must be accepted")
	TEST_ASSERT(QDELETED(salvaged), "The accepted control must be consumed")

	var/datum/mission_objective/deliver/procurement/exact_module = allocate(/datum/mission_objective/deliver/procurement)
	exact_module.required_type = /obj/item/mod/module/balloon
	var/obj/item/mod/module/balloon/advanced/descendant = allocate(/obj/item/mod/module/balloon/advanced)
	TEST_ASSERT(!exact_module.can_turn_in(descendant), "A loot-module ask must reject a different descendant type")
	TEST_ASSERT_EQUAL(exact_module.accept_item(descendant, run_loc_floor_bottom_left), 0, "Direct acceptance must preserve exact module matching")
	TEST_ASSERT(!QDELETED(descendant), "A refused module must survive")

	var/list/loose_types = list(/obj/item/sea_crystal, /obj/item/organ/monster_core/regenerative_core/legion, /obj/item/mod/construction/broken_core, /obj/item/mod/module/springlock, /obj/item/mod/module/visor/rave, /obj/item/mod/module/balloon, /obj/item/mod/module/stamp)
	for(var/item_type in loose_types)
		var/datum/mission/mission = allocate(/datum/mission)
		mission.requires_item = TRUE
		mission.servant = receiving_ship
		mission.active = TRUE
		var/datum/mission_objective/deliver/procurement/ask = new
		ask.required_type = item_type
		ask.required_amount = 2
		mission.add_objective(ask)
		var/obj/item/first = allocate(item_type)
		var/obj/item/second = allocate(item_type)
		mission.register_quest_atom(first)
		TEST_ASSERT(mission.turn_in(run_loc_floor_bottom_left, first), "The first [item_type] must count as progress")
		TEST_ASSERT(QDELETED(first), "The first loose item must be consumed")
		TEST_ASSERT_NULL(mission.quest_atom, "Consumption must forget the quest atom before deletion")
		TEST_ASSERT(!mission.failed, "Consuming a tracked item must not void the mission")
		TEST_ASSERT_EQUAL(ask.delivered_count, 1, "Loose deliveries must count one item per hand-over")
		TEST_ASSERT(!mission.turn_in(run_loc_floor_bottom_left, first), "A consumed item cannot be submitted twice")
		TEST_ASSERT(mission.turn_in(run_loc_floor_bottom_left, second), "The second [item_type] must finish the request")
		TEST_ASSERT(QDELETED(second), "The second loose item must be consumed")
		TEST_ASSERT(QDELETED(mission), "The counted request must finish")

	var/list/stack_cases = list(list(/obj/item/stack/telecrystal_raw, 10), list(/obj/item/stack/glacial_core, 5), list(/obj/item/stack/spice_pods, 6))
	for(var/list/stack_case as anything in stack_cases)
		var/datum/mission/mission = allocate(/datum/mission)
		mission.requires_item = TRUE
		mission.servant = receiving_ship
		mission.active = TRUE
		var/datum/mission_objective/deliver/procurement/ask = new
		ask.required_type = stack_case[1]
		ask.required_amount = stack_case[2]
		mission.add_objective(ask)
		var/obj/item/stack/short_stack = allocate(stack_case[1], run_loc_floor_bottom_left, ask.required_amount - 1, FALSE)
		var/obj/item/stack/full_stack = allocate(stack_case[1], run_loc_floor_bottom_left, ask.required_amount + 2, FALSE)
		TEST_ASSERT(!mission.turn_in(run_loc_floor_bottom_left, short_stack), "A short eligible stack must be refused")
		TEST_ASSERT_EQUAL(ask.accept_item(short_stack, run_loc_floor_bottom_left), 0, "Direct acceptance must also check stack quantities")
		TEST_ASSERT_EQUAL(short_stack.amount, stack_case[2] - 1, "A refused stack must remain untouched")
		mission.register_quest_atom(full_stack)
		TEST_ASSERT(mission.turn_in(run_loc_floor_bottom_left, full_stack), "A full eligible stack must be accepted")
		TEST_ASSERT_EQUAL(full_stack.amount, 2, "Only the configured stack quantity must be consumed")
		TEST_ASSERT(QDELETED(mission), "A full stack must finish the request")

/// The authored ladder is shared stock, with exactly one SKU for each listed weapon.
/datum/unit_test/voidcrew_ladder_catalog/Run()
	var/list/catalogs = list(
		/datum/outpost_shop/general = list(
			list(/datum/shop_sku/general/hunting_knife, /obj/item/knife/hunting, 4, 200, 0),
			list(/datum/shop_sku/general/survival_knife, /obj/item/knife/combat/survival, 4, 350, 0),
			list(/datum/shop_sku/general/surplus_rifle, /obj/item/gun/ballistic/rifle/boltaction/surplus, 2, 900, 0),
		),
		/datum/outpost_shop/outfitter = list(
			list(/datum/shop_sku/outfitter/combat_knife, /obj/item/knife/combat, 3, 900, 0),
			list(/datum/shop_sku/outfitter/shortsword, /obj/item/claymore/shortsword, 2, 1200, 0),
			list(/datum/shop_sku/outfitter/ablative_bat, /obj/item/melee/baseball_bat/ablative, 2, 1000, 0),
			list(/datum/shop_sku/outfitter/fireaxe, /obj/item/fireaxe, 2, 1500, 0),
			list(/datum/shop_sku/outfitter/sabre, /obj/item/melee/sabre, 1, 1800, 0),
			list(/datum/shop_sku/outfitter/laser_gun, /obj/item/gun/energy/laser, 1, 1500, 0),
			list(/datum/shop_sku/outfitter/riot_shotgun, /obj/item/gun/ballistic/shotgun/riot, 1, 1800, 0),
			list(/datum/shop_sku/outfitter/energy_gun, /obj/item/gun/energy/e_gun, 1, 2400, 0),
		),
		/datum/outpost_shop/black_market = list(
			list(/datum/shop_sku/black_market/boarding_axe, /obj/item/fireaxe/boardingaxe, 1, 2400, 0),
			list(/datum/shop_sku/black_market/cutlass, /obj/item/claymore/cutlass, 1, 3000, 3),
			list(/datum/shop_sku/black_market/rare/energy_sword, /obj/item/melee/energy/sword/saber, 1, 4000, 4),
			list(/datum/shop_sku/black_market/c20r, /obj/item/gun/ballistic/automatic/c20r/unrestricted, 1, 3600, 2),
			list(/datum/shop_sku/black_market/wt550, /obj/item/gun/ballistic/automatic/wt550, 1, 4200, 2),
			list(/datum/shop_sku/black_market/rotating/mateba, /obj/item/gun/ballistic/revolver/mateba, 1, 3000, 1),
		),
		/datum/outpost_shop/vendor/ripperdoc = list(
			list(/datum/shop_sku/ripperdoc/monowire, /obj/item/organ/cyberimp/arm/toolkit/cyberware/monowire, 1, 0, 3),
			list(/datum/shop_sku/ripperdoc/mantis, /obj/item/cyberware_pair_case/mantis_blades, 1, 0, 4),
			list(/datum/shop_sku/ripperdoc/gorilla, /obj/item/cyberware_pair_case/gorilla_arms, 1, 0, 3),
		),
	)
	for(var/shop_type in catalogs)
		var/datum/outpost_shop/shop = allocate(shop_type)
		var/list/every_sku = shop.sku_types + shop.rotating_pool + shop.rare_pool + shop.favor_sku_types
		for(var/list/row as anything in catalogs[shop_type])
			TEST_ASSERT(row[1] in every_sku, "[shop_type] lost [row[1]]")
			var/datum/shop_sku/sku = allocate(row[1])
			TEST_ASSERT_EQUAL(sku.item_path, row[2], "[sku.type] dispenses the wrong weapon")
			TEST_ASSERT_EQUAL(sku.stock_min, row[3], "[sku.type] has random lower stock")
			TEST_ASSERT_EQUAL(sku.stock_max, row[3], "[sku.type] has the wrong stock cap")
			TEST_ASSERT_EQUAL(sku.stock, row[3], "[sku.type] starts with the wrong stock")
			TEST_ASSERT_EQUAL(sku.price_credits, row[4], "[sku.type] has the wrong credit price")
			TEST_ASSERT_EQUAL(sku.price_vouchers, row[5], "[sku.type] has the wrong voucher price")
			var/copies = 0
			for(var/datum/shop_sku/other as anything in every_sku)
				if(initial(other.item_path) == sku.item_path)
					copies++
			TEST_ASSERT_EQUAL(copies, 1, "[shop_type] has duplicate [sku.item_path] shelves")
			if(ispath(sku.item_path, /obj/item/gun))
				TEST_ASSERT(row[1] in shop.sku_types, "A gun must stay on its core shelf")
				TEST_ASSERT_EQUAL(sku.restock_interval, 1 HOURS, "Gun replenishment must be hourly")
				TEST_ASSERT_EQUAL(timeleft(sku.restock_timer), 1 HOURS, "The hourly delivery is not scheduled")
			else if(row[5])
				TEST_ASSERT_EQUAL(sku.restock_interval, INFINITY, "Red melee/chrome must remain finite")
				TEST_ASSERT_NULL(sku.restock_timer, "Finite melee acquired a refill timer")
			if(ispath(sku.item_path, /obj/item/gun) || row[5])
				TEST_ASSERT(sku.fixed_price, "A restricted weapon can be discounted")
				TEST_ASSERT(!sku.contract_reward, "A restricted weapon can pay a contract")

/// Check removed sources across all owned shelf families, including undealt stock.
/datum/unit_test/voidcrew_ladder_removed_shelves/Run()
	var/list/allowed_guns = list(
		/obj/item/gun/ballistic/rifle/boltaction/surplus,
		/obj/item/gun/energy/disabler,
		/obj/item/gun/energy/laser,
		/obj/item/gun/energy/e_gun,
		/obj/item/gun/ballistic/shotgun/riot,
		/obj/item/gun/ballistic/automatic/c20r/unrestricted,
		/obj/item/gun/ballistic/automatic/wt550,
		/obj/item/gun/ballistic/revolver/mateba,
	)
	var/list/printed_gear = list(
		/obj/item/gps, /obj/item/storage/belt/utility/full, /obj/item/weldingtool/largetank,
		/obj/item/lightreplacer, /obj/item/holosign_creator/atmos, /obj/item/construction/rcd/loaded,
		/obj/item/healthanalyzer, /obj/item/pickaxe, /obj/item/pickaxe/drill, /obj/item/clothing/glasses/meson,
		/obj/item/t_scanner/adv_mining_scanner/lesser, /obj/item/bodybag/bluespace, /obj/item/clothing/glasses/welding,
		/obj/item/flashlight/seclite, /obj/item/assembly/flash/handheld, /obj/item/clothing/shoes/magboots,
		/obj/item/crowbar/power, /obj/item/defibrillator/compact, /obj/item/suppressor, /obj/item/mod/module/active_sonar,
		/obj/item/cultivator, /obj/item/shovel/spade, /obj/item/hatchet, /obj/item/secateurs,
		/obj/item/reagent_containers/cup/watering_can, /obj/item/plant_analyzer, /obj/item/fishing_rod/tech,
	)
	for(var/shop_type in list(/datum/outpost_shop/general, /datum/outpost_shop/outfitter, /datum/outpost_shop/black_market, /datum/outpost_shop/vendor/potting_shed, /datum/outpost_shop/vendor/bait_shop, /datum/outpost_shop/vendor/ripperdoc))
		var/datum/outpost_shop/shop = allocate(shop_type)
		for(var/datum/shop_sku/sku_type as anything in shop.sku_types + shop.rotating_pool + shop.rare_pool + shop.favor_sku_types)
			var/item_path = initial(sku_type.item_path)
			TEST_ASSERT(!(item_path in printed_gear), "[shop_type] still sells printable gear [item_path]")
			if(ispath(item_path, /obj/item/gun))
				TEST_ASSERT(item_path in allowed_guns, "[shop_type] bypasses the ladder with [item_path]")
			TEST_ASSERT(item_path != /obj/item/organ/cyberimp/arm/toolkit/cyberware/ronin && item_path != /obj/item/organ/cyberimp/arm/toolkit/cyberware/bunker_buster, "Splice still sells a gun arm")

/// Convoys and rotations cannot accelerate deliveries or revive finite stock.
/datum/unit_test/voidcrew_ladder_restock/Run()
	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop)
	shop.add_sku(/datum/shop_sku/general/surplus_rifle, "core")
	var/datum/shop_sku/gun = shop.skus[1]
	gun.stock = 0
	var/timer_id = gun.restock_timer
	for(var/convoy in 1 to 6)
		shop.convoy_restock()
		TEST_ASSERT_EQUAL(gun.stock, 0, "A convoy bypassed the hourly refill")
		TEST_ASSERT_EQUAL(gun.restock_timer, timer_id, "Convoys reset the gun clock")
	gun.restock_unit()
	TEST_ASSERT_EQUAL(gun.stock, 1, "One delivery must return one gun")
	gun.restock_unit()
	gun.restock_unit()
	TEST_ASSERT_EQUAL(gun.stock, 2, "Hourly stock exceeded its cap")
	gun.stock = 0
	gun.reserved_stock = 1
	gun.restock_unit()
	gun.restock_unit()
	TEST_ASSERT_EQUAL(gun.stock, 1, "Restocking duplicated reserved stock")
	qdel(shop)
	TEST_ASSERT_NULL(timeleft(timer_id), "Deleting the shop left a gun delivery alive")

	for(var/sku_type in list(/datum/shop_sku/outfitter/lethalshot, /datum/shop_sku/outfitter/smg_mag, /datum/shop_sku/ripperdoc/ronin_mag))
		var/datum/outpost_shop/ammo_shop = allocate(/datum/outpost_shop)
		ammo_shop.add_sku(sku_type, "core")
		var/datum/shop_sku/ammo = ammo_shop.skus[1]
		ammo.stock = 0
		ammo_shop.convoy_restock()
		TEST_ASSERT(ammo.stock > 0, "Ammunition lost ordinary convoy refills")
		TEST_ASSERT_NULL(ammo.restock_timer, "Ammunition acquired a gun clock")

	for(var/sku_type in list(/datum/shop_sku/general/rotating/freight_crate, /datum/shop_sku/black_market/rare/energy_sword, /datum/shop_sku/general/surplus_rifle))
		for(var/weighted in list(FALSE, TRUE))
			var/datum/outpost_shop/rotating = allocate(/datum/outpost_shop)
			rotating.rotating_pool = list(sku_type, /datum/shop_sku/general/soap)
			if(weighted)
				var/datum/shop_rotation/rotation = new
				rotation.pool = list()
				rotation.pool[sku_type] = 1
				rotation.pool[/datum/shop_sku/general/soap] = 1
				rotating.live_rotations += rotation
				rotating.add_rotation_sku(rotation, sku_type)
			else
				rotating.add_sku(sku_type, "rotating")
			var/datum/shop_sku/finite = rotating.skus[1]
			finite.stock = 0
			for(var/convoy in 1 to 8)
				rotating.convoy_restock()
				TEST_ASSERT_EQUAL(length(rotating.skus), 1, "A rotation duplicated restricted stock")
				TEST_ASSERT_EQUAL(rotating.skus[1], finite, "A rotation replaced the exhausted SKU and its clock")
				TEST_ASSERT_EQUAL(finite.stock, 0, "A rotation refilled restricted stock")

	for(var/sku_type in list(/datum/shop_sku/general/hunting_knife, /datum/shop_sku/outfitter/fireaxe, /datum/shop_sku/black_market/boarding_axe))
		var/datum/outpost_shop/melee_shop = allocate(/datum/outpost_shop)
		melee_shop.add_sku(sku_type, "core")
		var/datum/shop_sku/melee = melee_shop.skus[1]
		melee.stock = 0
		melee_shop.convoy_restock()
		TEST_ASSERT(melee.stock > 0, "Green/yellow melee stopped replenishing")

/// Actual favor and authored specials cannot discount restricted weapons.
/datum/unit_test/voidcrew_ladder_prices_and_contracts/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	user.mind_initialize()
	allocated += user.mind
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/datum/team/voidcrew/team = allocate(/datum/team/voidcrew)
	team.ship = ship
	ship.ship_team = team
	team.join_member(user.mind)
	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop)
	shop.grant_favor(ship, 6) // FAVOR_TIER_TRUSTED
	TEST_ASSERT_EQUAL(shop.get_discount_pct(ship), 15, "Favor fixture did not reach the maximum discount")
	var/list/restricted = list(
		/datum/shop_sku/general/surplus_rifle, /datum/shop_sku/outfitter/disabler,
		/datum/shop_sku/outfitter/laser_gun, /datum/shop_sku/outfitter/energy_gun, /datum/shop_sku/outfitter/riot_shotgun,
		/datum/shop_sku/black_market/c20r, /datum/shop_sku/black_market/wt550, /datum/shop_sku/black_market/rotating/mateba,
		/datum/shop_sku/black_market/cutlass, /datum/shop_sku/black_market/rare/energy_sword,
		/datum/shop_sku/ripperdoc/monowire, /datum/shop_sku/ripperdoc/gorilla, /datum/shop_sku/ripperdoc/mantis,
		/datum/shop_sku/general/rotating/freight_crate, /datum/shop_sku/black_market/mystery_cache, /datum/shop_sku/black_market/mystery_cache_rare,
	)
	for(var/sku_type in restricted)
		shop.add_sku(sku_type, "core") // Test the flag even if a shelf changes later.
		var/datum/shop_sku/sku = shop.skus[length(shop.skus)]
		shop.roll_special()
		TEST_ASSERT_EQUAL(sku.discount_pct, 0, "A restricted weapon went on special")
		sku.discount_pct = 30
		TEST_ASSERT_EQUAL(sku.get_credit_price(user), sku.price_credits, "A special/favor combination changed a fixed price")
	for(var/attempt in 1 to 20)
		var/datum/mission/mission = allocate(/datum/mission)
		mission.difficulty = 3 // MISSION_DIFFICULTY_HARD
		mission.contract_pay_mult = 100 // Every shelf price fits, so price cannot hide a leak.
		TEST_ASSERT(shop.roll_contract_reward(mission), "Restricted-only shelves could not quote currency")
		TEST_ASSERT_EQUAL(length(mission.get_reward_types()), 0, "A contract paid a gun, red melee/chrome or bought cache")
		TEST_ASSERT_EQUAL(length(mission.contract_stock), 0, "A contract reserved restricted stock")
	var/datum/bank_account/account = allocate(/datum/bank_account, "Ladder counter test", null, 1, FALSE)
	account.account_balance = 2700
	ship.ship_account = account
	var/obj/item/card/id/advanced/card = allocate(/obj/item/card/id/advanced)
	qdel(card.registered_account)
	card.registered_account = account
	TEST_ASSERT(user.put_in_hands(card), "First buyer could not carry their ID")
	var/mob/living/carbon/human/other_buyer = allocate(/mob/living/carbon/human/consistent, run_loc_floor_top_right)
	other_buyer.mind_initialize()
	allocated += other_buyer.mind
	team.join_member(other_buyer.mind)
	var/obj/item/card/id/advanced/other_card = allocate(/obj/item/card/id/advanced)
	qdel(other_card.registered_account)
	other_card.registered_account = account
	TEST_ASSERT(other_buyer.put_in_hands(other_card), "Second buyer could not carry their ID")
	var/datum/shop_sku/rifle = shop.skus[1]
	TEST_ASSERT(rifle.try_purchase(user, null), "The first shared-stock purchase failed")
	TEST_ASSERT(rifle.try_purchase(other_buyer, null), "A second buyer could not buy the remaining rifle")
	TEST_ASSERT_EQUAL(rifle.stock, 0, "Two buyers did not exhaust the same stock")
	TEST_ASSERT_EQUAL(account.account_balance, 900, "Actual purchases bypassed the fixed price")
	TEST_ASSERT(!rifle.try_purchase(other_buyer, null), "An exhausted SKU sold another gun")
	TEST_ASSERT_EQUAL(account.account_balance, 900, "A refused purchase took money")
	rifle.restock_unit()
	TEST_ASSERT(rifle.try_purchase(other_buyer, null), "An hourly delivery could not be purchased")
	TEST_ASSERT_EQUAL(account.account_balance, 0, "The returned rifle sold at a discount")
	user.mind.ship_teams = list()
	team.ship = null

/// Bought and premium crates have exact freight odds and no extra weapon draws.
/datum/unit_test/voidcrew_ladder_bought_caches/Run()
	var/list/gun_pools = list(
		list(/obj/item/gun/ballistic/rifle/boltaction/surplus, /obj/item/gun/ballistic/automatic/pistol, /obj/item/gun/ballistic/revolver/c38/detective, /obj/item/gun/ballistic/shotgun/doublebarrel),
		list(/obj/item/gun/ballistic/shotgun/riot, /obj/item/gun/ballistic/automatic/tommygun, /obj/item/gun/ballistic/automatic/mini_uzi),
	)
	var/list/gun_weights = list(list(940, 59, 1), list(45, 54, 1), list(15, 35, 50))
	var/list/melee_weights = list(list(900, 99, 1), list(35, 64, 1), list(10, 45, 45))
	var/list/chances = list(8, 19, 33)
	var/list/classes = list("green", "yellow", "red")
	var/list/caches = list(
		list(/datum/shop_sku/general/rotating/freight_crate, 750, 0),
		list(/datum/shop_sku/black_market/mystery_cache, 0, 2),
		list(/datum/shop_sku/black_market/mystery_cache_rare, 0, 4),
	)
	for(var/list/row as anything in caches)
		var/datum/shop_sku/sku = allocate(row[1])
		TEST_ASSERT_EQUAL(sku.stock, 1, "Bought caches must have exactly one unit")
		TEST_ASSERT_EQUAL(sku.price_credits, row[2], "Bought cache has the wrong credit price")
		TEST_ASSERT_EQUAL(sku.price_vouchers, row[3], "Bought cache has the wrong voucher price")
		TEST_ASSERT_EQUAL(sku.restock_interval, INFINITY, "Bought caches can refill")
		for(var/zone in 1 to 3) // ZONE_GREEN/YELLOW/RED compile later.
			var/obj/structure/closet/crate/zone_loot/syndicate/trader/cache = allocate(sku.item_path, run_loc_floor_bottom_left)
			cache.on_zone_resolved(zone)
			cache.forceMove(run_loc_floor_top_right)
			TEST_ASSERT_EQUAL(cache.loot_zone, zone, "Moving bought cargo changed its origin zone")
			TEST_ASSERT_EQUAL(cache.get_gun_chance(), chances[zone], "Bought cache has the wrong gun probability")
			var/list/weapon_paths = list()
			for(var/class_index in 1 to 3)
				var/list/gun_class_weights = cache.get_weapon_class_weights(TRUE)
				var/list/melee_class_weights = cache.get_weapon_class_weights(FALSE)
				TEST_ASSERT_EQUAL(gun_class_weights[classes[class_index]], gun_weights[zone][class_index], "Bought cache has wrong gun class weights")
				TEST_ASSERT_EQUAL(melee_class_weights[classes[class_index]], melee_weights[zone][class_index], "Bought cache has wrong melee class weights")
				var/list/guns = cache.get_weapon_pool(TRUE, classes[class_index])
				TEST_ASSERT(compare_list(guns, gun_pools[min(2, class_index)]), "Freight gun class changed or gained advanced weapons")
				weapon_paths |= guns
				weapon_paths |= cache.get_weapon_pool(FALSE, classes[class_index])
			var/datum/loot_theme/theme = GLOB.loot_themes[cache.theme]
			var/list/original_pools = list(theme.loot_common.Copy(), theme.loot_uncommon.Copy(), theme.loot_prime.Copy(), theme.loot_uniques.Copy())
			var/list/pools = cache.get_supply_pools()
			for(var/tier in pools)
				var/list/pool = pools[tier]
				TEST_ASSERT(length(pool), "Filtering bought cargo emptied a supply tier")
				for(var/item_path in pool)
					TEST_ASSERT(!(item_path in weapon_paths) && !ispath(item_path, /obj/item/gun) && !ispath(item_path, /obj/item/knife), "Supplies can pay an extra weapon")
					TEST_ASSERT(!ispath(item_path, /obj/item/organ/cyberimp), "Bought cargo can pay chrome")
				pool.Cut() // A caller may consume every working pool safely.
			var/weapon_count = 0
			cache.PopulateContents()
			for(var/obj/item/item in cache.contents)
				if(item.type in weapon_paths)
					weapon_count++
			TEST_ASSERT_EQUAL(weapon_count, 1, "Bought/premium cache did not pay exactly one weapon")
			var/contents_count = length(cache.contents)
			var/spare_count = 0
			for(var/obj/item/gun/gun in cache.contents)
				if(GLOB.loot_gun_spare_ammo[gun.type])
					spare_count++
					var/ammo_path = GLOB.loot_gun_spare_ammo[gun.type]
					TEST_ASSERT(locate(ammo_path) in cache, "A freight gun arrived without its spare reload")
			TEST_ASSERT(contents_count - spare_count >= 2 + (zone == 3 ? 2 : zone == 2 ? 1 : 0) + cache.bonus_draws, "Premium crate lost ordinary draws")
			TEST_ASSERT(contents_count - spare_count <= 3 + (zone == 3 ? 2 : zone == 2 ? 1 : 0) + cache.bonus_draws, "Premium crate added unbudgeted draws")
			cache.PopulateContents()
			TEST_ASSERT_EQUAL(length(cache.contents), contents_count, "Reopening bought cargo paid twice")
			TEST_ASSERT(deep_compare_list(list(theme.loot_common, theme.loot_uncommon, theme.loot_prime, theme.loot_uniques), original_pools), "Bought cargo mutated the shared theme")
