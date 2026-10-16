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
		for(var/reward in shop.exclusive_rewards)
			if(!ispath(reward, /atom/movable))
				TEST_FAIL("[shop_type] lists exclusive reward [reward], which is not a spawnable movable. The contract that pays it out gives nothing")
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
		TEST_ASSERT(findtext("[initial(sku_type.item_path)]/", "/obj/item/blueprint/gun/") != 1, "[sku_type] still sells a gun schematic.")

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
	TEST_ASSERT_EQUAL(length(fitter.mission_requests), 0, "New suit salvage requests need reward-design inputs before activation")
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
		QDEL_LIST(outpost.shop_offers)
		outpost.shop.mission_requests = pool
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
		var/datum/mission_objective/deliver/procurement/ask = new
		ask.required_type = item_type
		mission.add_objective(ask)
		var/obj/item/item = allocate(item_type)
		TEST_ASSERT(!mission.turn_in(run_loc_floor_bottom_left, item), "A forged [item_type] turn-in must fail")
		TEST_ASSERT_EQUAL(ask.accept_item(item, run_loc_floor_bottom_left), 0, "Direct acceptance must refuse unsupported [item_type]") // MISSION_ITEM_REFUSED
		TEST_ASSERT(!QDELETED(item), "Refusing [item_type] must not consume it")

	var/datum/mission/control_mission = allocate(/datum/mission)
	control_mission.requires_item = TRUE
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
