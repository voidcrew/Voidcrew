#ifndef VOIDCREW_MISSION_BOARD_REWARDS_TESTS
#define VOIDCREW_MISSION_BOARD_REWARDS_TESTS

/// Board fixtures avoid random overmap sites; reward and lifecycle code stays real.
/datum/mission/m1_board_test/generate_mission_details()

/datum/mission/recovery/outpost/m1_board_test/generate_mission_details()

/datum/mission/recovery/kill/outpost/m1_board_test/generate_mission_details()

/datum/mission/outpost_courier/m1_board_test/generate_mission_details()

/obj/structure/overmap/trader_outpost/m1_board_test
	var/turf/counter_turf

/obj/structure/overmap/trader_outpost/m1_board_test/contains_site_turf(turf/location)
	return location && location == counter_turf

/// Verify conservation, shelf restrictions, stack amounts and all difficulty bands.
/datum/unit_test/voidcrew_m1_quotes/Run()
	for(var/shop_type in list(/datum/outpost_shop/general, /datum/outpost_shop/outfitter, /datum/outpost_shop/black_market, /datum/outpost_shop/vendor/suit_fitter))
		var/datum/outpost_shop/shop = allocate(shop_type)
		for(var/difficulty in list(1, 2, 3)) // MISSION_DIFFICULTY_* compile later.
			for(var/attempt in 1 to 15)
				var/datum/mission/mission = allocate(/datum/mission/m1_board_test, shop)
				mission.difficulty = difficulty
				TEST_ASSERT(shop.roll_contract_reward(mission), "A board must fund even an empty package")
				var/list/bands = list(list(600, 900), list(1300, 1800), list(2400, 3200))
				TEST_ASSERT(mission.contract_quote >= bands[difficulty][1] && mission.contract_quote <= bands[difficulty][2], "Quote left its difficulty band")
				var/package_value = 0
				TEST_ASSERT(length(mission.get_reward_types()) <= 2, "A quote includes too many shelf objects")
				TEST_ASSERT_EQUAL(length(mission.rare_reward_types), 0, "Hard board work must never draw an exclusive")
				for(var/item_type in mission.contract_stock)
					var/datum/shop_sku/sku = mission.contract_stock[item_type]
					TEST_ASSERT_EQUAL(sku.shelf, "core", "A package leaked a restricted shelf")
					TEST_ASSERT(sku.contract_reward && sku.price_credits > 0 && !sku.price_vouchers && sku.stock > 0, "A package includes ineligible stock")
					TEST_ASSERT_EQUAL(mission.reward_amounts[item_type], sku.dispense_amount, "A package changed a stack quantity")
					package_value += sku.price_credits
				TEST_ASSERT(package_value <= floor(mission.contract_quote * 0.6), "The package exceeds its shelf share")
				TEST_ASSERT_EQUAL(package_value + mission.value + mission.voucher_count * 1200, mission.contract_quote, "Settlement lost or created quoted value")
				TEST_ASSERT(mission.value >= 0 && mission.value < 1200, "Currency residual is not exact")
				qdel(mission)
		for(var/datum/shop_sku/sku as anything in shop.skus)
			sku.stock = 0
		var/datum/mission/empty = allocate(/datum/mission/m1_board_test, shop)
		TEST_ASSERT(shop.roll_contract_reward(empty), "Empty shelves must still offer work")
		TEST_ASSERT_EQUAL(length(empty.get_reward_types()), 0, "Depleted stock was quoted as goods")
		TEST_ASSERT_EQUAL(empty.value + empty.voucher_count * 1200, empty.contract_quote, "Empty shelves failed to settle in currency")
		TEST_ASSERT(!findtext(empty.get_contract_pay_summary(), "goods"), "Currency-only text invented a goods reward")
		qdel(shop)
	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop)
	var/list/expensive = list(/obj/item/gps = 601)
	TEST_ASSERT_NULL(shop.pick_valued_reward(expensive, 600), "The cheapest-item fallback or overshoot remains")

/// Every retained ask and all six fitter rows use the specified supply formula.
/datum/unit_test/voidcrew_m1_supply_rows/Run()
	var/obj/structure/overmap/trader_outpost/outpost = allocate(/obj/structure/overmap/trader_outpost/outfitter)
	var/datum/outpost_shop/vendor/suit_fitter/fitter = outpost.get_shop(/datum/outpost_shop/vendor/suit_fitter)
	TEST_ASSERT_EQUAL(length(outpost.shop.get_procurement_requests()), 9, "The shared outfitter pool must contain nine equal rows")
	for(var/shop_type in list(/datum/outpost_shop/general, /datum/outpost_shop/outfitter, /datum/outpost_shop/black_market))
		var/datum/outpost_shop/shop = shop_type == /datum/outpost_shop/outfitter ? outpost.shop : allocate(shop_type)
		var/list/requests = shop.mission_requests.Copy()
		for(var/list/request as anything in requests)
			shop.mission_requests = list(request)
			var/datum/mission/outpost_supply/mission = allocate(/datum/mission/outpost_supply, shop)
			TEST_ASSERT(!mission.generation_failed, "[request["type"]] failed generation")
			TEST_ASSERT_EQUAL(mission.required_amount, request["amount"], "Generation changed an ask quantity")
			TEST_ASSERT_EQUAL(mission.difficulty, request["difficulty"], "Generation changed ask difficulty")
			var/datum/outpost_shop/reward_shop = request["reward_shop"] ? fitter : shop
			TEST_ASSERT_EQUAL(mission.contract_reward_shop, reward_shop, "Fitter reward stock must come from Wick")
			TEST_ASSERT_EQUAL(mission.shop, shop, "Fitter favor must remain with Sarge")
			var/counter = reward_shop.get_counter_value(request["type"], request["amount"])
			if(ispath(request["type"], /obj/item/mod/module))
				TEST_ASSERT_EQUAL(counter, 0, "Loot-module reference value became a buyback")
				counter = 250
			var/list/bands = list(list(600, 900), list(1300, 1800), list(2400, 3200))
			var/list/band = bands[mission.difficulty]
			var/list/services = list(200, 350, 500)
			var/service = services[mission.difficulty]
			var/minimum = max(CEILING(counter * 1.15, 1), min(request["pay_min"] || band[1], counter + service))
			var/maximum = max(CEILING(counter * 1.15, 1), min(request["pay_max"] || band[2], counter + service))
			if(mission.is_routine_contract())
				minimum = max(CEILING(counter * 1.10, 1), min(floor(band[1] * 0.4), service))
				maximum = max(CEILING(counter * 1.10, 1), min(floor(band[2] * 0.4), service))
				TEST_ASSERT_EQUAL(mission.voucher_count, 0, "Routine supplies must not pay vouchers")
				TEST_ASSERT_EQUAL(mission.get_favor_reward(), 1, "Routine supplies must pay one favor")
			TEST_ASSERT(mission.contract_quote >= minimum && mission.contract_quote <= maximum, "[request["type"]] left its specified pay range")
			TEST_ASSERT_EQUAL(mission.value, mission.value_min, "The shell overwrote residual credits")
			TEST_ASSERT_EQUAL(mission.value, mission.value_max, "Residual credits must not reroll")
			qdel(mission)
		shop.mission_requests = requests
	for(var/mission_type in list(/datum/mission/outpost_supply/cook, /datum/mission/outpost_supply/angler))
		var/datum/mission/mission = allocate(mission_type, outpost.shop)
		TEST_ASSERT_EQUAL(mission.voucher_count, 0, "The food and angler exceptions must never pay vouchers")
		TEST_ASSERT_EQUAL(mission.get_favor_reward(), 1, "The food and angler exceptions must pay routine favor")

/// Target scaling precedes the board quote; only the board multiplier changes fees.
/datum/unit_test/voidcrew_m1_field_fees/Run()
	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop)
	var/list/bands = list(list(600, 900), list(1300, 1800), list(2400, 3200))
	var/list/zones = list(1, 2, 3) // ZONE_GREEN/YELLOW/RED
	for(var/index in 1 to 3)
		var/list/band = bands[index]
		for(var/mission_type in list(/datum/mission/recovery/outpost/m1_board_test, /datum/mission/recovery/kill/outpost/m1_board_test))
			var/datum/mission/mission = allocate(mission_type, shop)
			mission.apply_zone_scaling(zones[index])
			mission.generate_details()
			var/multiplier = 1.15
			if(istype(mission, /datum/mission/recovery/kill))
				var/list/kill_multipliers = list(1.10, 0.95, 0.55)
				multiplier = kill_multipliers[index]
			TEST_ASSERT(mission.contract_quote >= floor(band[1] * multiplier) && mission.contract_quote <= floor(band[2] * multiplier), "Field fee scaled twice or used the old multiplier")
			TEST_ASSERT_EQUAL(mission.get_favor_reward(), index == 3 ? 3 : index, "Field favor has the wrong difficulty reward")
	var/obj/structure/overmap/trader_outpost/origin = allocate(/obj/structure/overmap/trader_outpost, run_loc_floor_bottom_left)
	var/obj/structure/overmap/trader_outpost/destination = allocate(/obj/structure/overmap/trader_outpost, run_loc_floor_top_right)
	var/datum/mission/outpost_courier/mission = allocate(/datum/mission/outpost_courier/m1_board_test, origin.shop)
	var/datum/mission_target/outpost/target = new(mission)
	target.outpost = destination
	mission.target = target
	mission.generate_details()
	TEST_ASSERT_EQUAL(mission.contract_quote, 10 * max(abs(origin.x - destination.x), abs(origin.y - destination.y)), "Courier pay ignored the fixed endpoint distance")

/// Stock races, convoy caps, failure/delete release and exact once-only payout.
/datum/unit_test/voidcrew_m1_reservations/Run()
	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop)
	shop.add_sku(/datum/shop_sku/general/beans, "core")
	var/datum/shop_sku/sku = shop.skus[1]
	sku.stock = 1
	sku.stock_max = 1
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/datum/bank_account/account = allocate(/datum/bank_account, "Contract settlement", null, 1, FALSE)
	ship.ship_account = account
	var/datum/mission/first = allocate(/datum/mission/m1_board_test, shop)
	var/datum/mission/second = allocate(/datum/mission/m1_board_test, shop)
	shop.roll_contract_reward(first)
	shop.roll_contract_reward(second)
	var/second_quote = second.contract_quote
	TEST_ASSERT(shop.roll_contract_reward(second), "A fixed quote could not be read again")
	TEST_ASSERT_EQUAL(second.contract_quote, second_quote, "Reading the quote rerolled its value")
	TEST_ASSERT(first.start_mission(ship), "The first crew could not accept its quote")
	TEST_ASSERT_EQUAL(sku.stock, 0, "Acceptance did not claim shared stock")
	TEST_ASSERT_EQUAL(sku.reserved_stock, 1, "Acceptance did not record its reservation")
	TEST_ASSERT(!first.start_mission(ship), "A second acceptance reserved stock again")
	TEST_ASSERT(second.start_mission(ship), "The second crew must still receive a currency award")
	TEST_ASSERT_EQUAL(length(second.get_reward_types()), 0, "Two crews reserved the same last shelf object")
	TEST_ASSERT_EQUAL(second.value + second.voucher_count * 1200, second_quote, "A drained shelf changed total pay")
	shop.convoy_restock()
	TEST_ASSERT_EQUAL(sku.stock, 0, "The convoy refilled a unit held by a contract")
	first.fail("Abandoned.")
	TEST_ASSERT_EQUAL(sku.stock, 1, "Abandonment did not release its stock")
	qdel(first)
	TEST_ASSERT_EQUAL(sku.stock, 1, "Deletion released the same reservation twice")
	qdel(second)
	var/datum/mission/paid = allocate(/datum/mission/m1_board_test, shop)
	shop.roll_contract_reward(paid)
	TEST_ASSERT(paid.start_mission(ship), "The completion fixture could not start")
	var/cash = paid.value
	var/balance = account.account_balance
	TEST_ASSERT(paid.turn_in(run_loc_floor_bottom_left, null), "A completed contract could not settle")
	TEST_ASSERT_EQUAL(account.account_balance, balance + cash, "Settlement paid the wrong residual credits")
	TEST_ASSERT_EQUAL(sku.stock, 0, "Completion returned the paid shelf object to stock")
	TEST_ASSERT_EQUAL(sku.reserved_stock, 0, "Completion left a reservation behind")
	TEST_ASSERT(!paid.turn_in(run_loc_floor_bottom_left, null), "A stale hand-in completed twice")
	paid.finish_mission(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(account.account_balance, balance + cash, "A repeated completion paid twice")

/// Missing receiving accounts refuse both partial and final consumption.
/datum/unit_test/voidcrew_m1_accounts/Run()
	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop)
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/datum/bank_account/account = allocate(/datum/bank_account, "Contract handover", null, 1, FALSE)
	var/datum/mission/mission = allocate(/datum/mission/m1_board_test, shop)
	shop.roll_contract_reward(mission)
	ship.ship_account = null
	TEST_ASSERT(!mission.start_mission(ship), "An accountless crew accepted work")
	ship.ship_account = account
	mission.requires_item = TRUE
	var/datum/mission_objective/deliver/procurement/ask = new
	ask.required_type = /obj/item/mod/construction/broken_core
	ask.required_amount = 2
	mission.add_objective(ask)
	TEST_ASSERT(mission.start_mission(ship), "A funded crew could not accept work")
	var/obj/item/first = allocate(/obj/item/mod/construction/broken_core)
	var/obj/item/second = allocate(/obj/item/mod/construction/broken_core)
	ship.ship_account = null
	TEST_ASSERT(!mission.turn_in(run_loc_floor_bottom_left, first), "A partial delivery consumed goods without a receiving account")
	TEST_ASSERT(!QDELETED(first) && ask.delivered_count == 0, "Refused partial goods were consumed")
	ship.ship_account = account
	TEST_ASSERT(mission.turn_in(run_loc_floor_bottom_left, first), "A valid partial delivery failed")
	TEST_ASSERT_EQUAL(ask.delivered_count, 1, "Partial delivery did not advance")
	TEST_ASSERT(!mission.turn_in(run_loc_floor_bottom_left, first), "The same partial delivery counted twice")
	ship.ship_account = null
	TEST_ASSERT(!mission.turn_in(run_loc_floor_bottom_left, second), "A final delivery consumed goods without an account")
	TEST_ASSERT(!QDELETED(second), "Refused final goods were consumed")
	ship.ship_account = account
	TEST_ASSERT(mission.turn_in(run_loc_floor_bottom_left, second), "Restoring the account did not allow settlement")
	TEST_ASSERT(!mission.turn_in(run_loc_floor_bottom_left, second), "A final delivery settled twice")

/// Acceptance, reopening, failure and target loss never advance the refill clock.
/datum/unit_test/voidcrew_m1_board_clock/Run()
	var/obj/structure/overmap/trader_outpost/outpost = allocate(/obj/structure/overmap/trader_outpost)
	for(var/datum/mission/posted as anything in outpost.shop_offers.Copy())
		qdel(posted)
	outpost.shop_offers.Cut()
	outpost.shop.mission_requests = list()
	outpost.shop.extra_offer_mix = list(
		/datum/mission/outpost_supply = 0,
		/datum/mission/recovery/kill/outpost = 0,
		/datum/mission/recovery/outpost = 0,
		/datum/mission/outpost_courier = 0,
		/datum/mission/outpost_supply/cook = 1,
	)
	outpost.next_contract_refill = world.time
	outpost.ensure_shop_offers()
	TEST_ASSERT_EQUAL(length(outpost.shop_offers), 4, "Scheduled refill did not fill the shared slots")
	var/next_refill = outpost.next_contract_refill
	var/datum/mission/taken = outpost.shop_offers[1]
	outpost.shop_offers -= taken
	qdel(taken)
	outpost.ensure_shop_offers()
	TEST_ASSERT_EQUAL(length(outpost.shop_offers), 3, "Reopening replaced a vacant offer early")
	TEST_ASSERT_EQUAL(outpost.next_contract_refill, next_refill, "Reopening moved the refill clock")
	var/datum/mission/expired = outpost.shop_offers[1]
	expired.posted_at = world.time - (22 MINUTES)
	outpost.next_contract_refill = world.time
	outpost.ensure_shop_offers()
	TEST_ASSERT(QDELETED(expired), "An unaccepted offer survived its expiry")
	TEST_ASSERT_EQUAL(length(outpost.shop_offers), 4, "Scheduled refill did not replace expired offers")
	outpost.next_contract_refill = world.time - (1 SECONDS)
	var/delayed_deadline = outpost.next_contract_refill
	outpost.ensure_shop_offers()
	TEST_ASSERT_EQUAL(outpost.next_contract_refill, delayed_deadline + (11 MINUTES), "A delayed callback shifted the fixed cadence")

/// A cached window cannot act for visitors, former members or a displaced trader.
/datum/unit_test/voidcrew_m1_counter_access/Run()
	var/obj/structure/overmap/trader_outpost/m1_board_test/outpost = allocate(/obj/structure/overmap/trader_outpost/m1_board_test)
	var/mob/living/basic/outpost_trader/npc = allocate(/mob/living/basic/outpost_trader, run_loc_floor_bottom_left)
	outpost.counter_turf = get_turf(npc)
	outpost.trader = npc
	npc.outpost = outpost
	npc.shop = outpost.shop
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	user.mind_initialize()
	allocated += user.mind
	TEST_ASSERT(!npc.can_use_contracts(user), "A visitor could act on the board")
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/datum/team/voidcrew/team = allocate(/datum/team/voidcrew)
	team.ship = ship
	ship.ship_team = team
	team.join_member(user.mind)
	TEST_ASSERT(npc.can_use_contracts(user), "A present crew member could not use the board")
	user.mind.leave_reputation_crew()
	TEST_ASSERT(!npc.can_use_contracts(user), "A former crew member could send a stale action")
	team.join_member(user.mind)
	npc.forceMove(get_step(run_loc_floor_bottom_left, NORTH))
	TEST_ASSERT(!npc.can_use_contracts(user), "A relocated trader could settle outside its site")
	user.mind.ship_teams = list()
	team.ship = null

/// Spawned stack quantities, vouchers and cash match the accepted quote exactly.
/datum/unit_test/voidcrew_m1_physical_settlement/Run()
	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop)
	shop.add_sku(/datum/shop_sku/general/suture, "core")
	var/datum/shop_sku/sku = shop.skus[1]
	var/datum/mission/mission = allocate(/datum/mission/m1_board_test, shop)
	mission.difficulty = 3
	shop.roll_contract_reward(mission)
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/datum/bank_account/account = allocate(/datum/bank_account, "Physical settlement", null, 1, FALSE)
	ship.ship_account = account
	ship.ship_team = allocate(/datum/team/voidcrew)
	ship.ship_team.ship = ship
	allocated += ship.get_crew_record()
	TEST_ASSERT(mission.start_mission(ship), "The physical settlement could not start")
	var/cash = mission.value
	var/vouchers = mission.voucher_count
	var/quote = mission.contract_quote
	var/balance = account.account_balance
	TEST_ASSERT(mission.turn_in(run_loc_floor_bottom_left, null), "The physical settlement failed")
	var/obj/item/stack/medical/suture/pack = locate() in run_loc_floor_bottom_left
	var/obj/item/stack/trade_voucher/scrip = locate() in run_loc_floor_bottom_left
	TEST_ASSERT_NOTNULL(pack, "The shelf package was not spawned")
	TEST_ASSERT_NOTNULL(scrip, "The currency vouchers were not spawned")
	TEST_ASSERT_EQUAL(pack.amount, 10, "The shelf package spawned one unit instead of ten")
	TEST_ASSERT_EQUAL(scrip.amount, vouchers, "Settlement spawned the wrong voucher count")
	TEST_ASSERT_EQUAL(account.account_balance - balance + scrip.amount * 1200 + sku.price_credits, quote, "Physical and bank rewards do not equal the quote")
	TEST_ASSERT_EQUAL(account.account_balance, balance + cash, "The bank did not receive the residual cash")
	TEST_ASSERT_EQUAL(shop.get_favor(ship), 3, "Hard completion granted the wrong standing")

/// Existing food checks still distinguish player cooking from the diner's own plates.
/datum/unit_test/voidcrew_m1_cooked_goods/Run()
	var/datum/mission_objective/deliver/cooked/ask = allocate(/datum/mission_objective/deliver/cooked)
	var/obj/item/food/dish = allocate(/obj/item/food)
	dish.crafting_complexity = ask.min_complexity
	TEST_ASSERT(!ask.can_turn_in(dish), "Factory food satisfied a Kitchen Order")
	ADD_TRAIT(dish, TRAIT_FOOD_CHEF_MADE, "outpost_kitchen") // TRAIT_SOURCE_OUTPOST_KITCHEN
	TEST_ASSERT(!ask.can_turn_in(dish), "A counter plate satisfied a Kitchen Order")
	ADD_TRAIT(dish, TRAIT_FOOD_CHEF_MADE, "player_cook")
	TEST_ASSERT(ask.can_turn_in(dish), "Player-cooked food failed an otherwise valid order")
	dish.crafting_complexity = ask.min_complexity - 1
	TEST_ASSERT(!ask.can_turn_in(dish), "An underspecified meal satisfied a Kitchen Order")

#endif
