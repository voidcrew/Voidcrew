#ifndef VOIDCREW_ZONE_SHOPS_TESTS
#define VOIDCREW_ZONE_SHOPS_TESTS

/// Fork permission defines compile later; Public/Yellow/Advanced/Elite are 0/1/2/3.
/datum/unit_test/voidcrew_zone_shops
	parent_type = /datum/unit_test/voidcrew_zone_identity
	abstract_type = /datum/unit_test/voidcrew_zone_shops

/datum/unit_test/voidcrew_zone_shops/proc/set_permission(datum/voidcrew_crew_record/record, permission)
	record.zone_totals["1"] = permission >= 1 ? 3 : 0
	record.zone_totals["2"] = permission >= 2 ? 6 : 0
	record.zone_totals["3"] = permission >= 3 ? 9 : 0

/datum/unit_test/voidcrew_zone_shops/proc/fund(mob/living/carbon/human/buyer, credits = 10000, vouchers = 20)
	var/datum/bank_account/account = allocate(/datum/bank_account, "Shop test", null, 1, FALSE)
	account.account_balance = credits
	var/obj/structure/overmap/ship/ship = get_crew_ship(buyer)
	TEST_ASSERT_NOTNULL(ship, "Shop funding requires a selected ship")
	ship.ship_account = account
	var/obj/item/card/id/advanced/card = allocate(/obj/item/card/id/advanced)
	qdel(card.registered_account)
	card.registered_account = account
	buyer.put_in_hands(card)
	allocate(/obj/item/stack/trade_voucher, buyer, vouchers)
	return account

/// Exhaustive exact-path map: everything outside this list remains Public.
/datum/unit_test/voidcrew_zone_shops/proc/expected_tags()
	return list(
		/datum/shop_sku/fitter/rotating/suit_security = 1,
		/datum/shop_sku/fitter/rotating/plating_security = 1,
		/datum/shop_sku/outfitter/energy_gun = 1,
		/datum/shop_sku/outfitter/riot_shotgun = 1,
		/datum/shop_sku/black_market/rotating/mateba = 1,
		/datum/shop_sku/black_market/c20r = 1,
		/datum/shop_sku/black_market/wt550 = 1,
		/datum/shop_sku/outfitter/rotating/riot_suit = 1,
		/datum/shop_sku/outfitter/rare/ablative_vest = 1,
		/datum/shop_sku/skunk/rotating/thermal_glasses = 1,
		/datum/shop_sku/black_market/thermals = 1,
		/datum/shop_sku/fitter/rare/mod_visor_thermal = 1,
		/datum/shop_sku/fitter/rotating/mod_active_sonar = 1,
		/datum/shop_sku/favor/pike_ledger = 1,
		/datum/shop_sku/favor/field_contract_pad = 1,
		/datum/shop_sku/favor/freight_beacon = 1,
		/datum/shop_sku/favor/fitter_gauntlets = 1,
		/datum/shop_sku/fitter/rare/suit_advanced = 2,
		/datum/shop_sku/fitter/rare/mod_jetpack_advanced = 2,
		/datum/shop_sku/fitter/rare/mod_jump_jet = 2,
		/datum/shop_sku/fitter/rare/mod_emp_shield_advanced = 2,
		/datum/shop_sku/fitter/rare/mod_projectile_dampener = 2,
		/datum/shop_sku/black_market/mod_chassis_syndicate = 2,
		/datum/shop_sku/black_market/mod_interdyne = 2,
		/datum/shop_sku/black_market/mod_energy_shield = 2,
		/datum/shop_sku/black_market/shield_generator_board = 2,
		/datum/shop_sku/black_market/interdictor_board = 2,
		/datum/shop_sku/black_market/data_siphon_board = 2,
		/datum/shop_sku/black_market/ew_suite_board = 2,
		/datum/shop_sku/favor/skunkworks_cell = 2,
		/datum/shop_sku/favor/maneuvering_harness = 2,
		/datum/shop_sku/black_market/mod_chassis_elite = 3,
		/datum/shop_sku/black_market/mod_infiltrator = 3,
		/datum/shop_sku/black_market/mod_traitor = 3,
		/datum/shop_sku/black_market/mod_storage = 3,
		/datum/shop_sku/black_market/mod_plate_compression = 3,
		/datum/shop_sku/black_market/mod_wraith_cloak = 3,
		/datum/shop_sku/black_market/rotating/mod_flamethrower = 3,
		/datum/shop_sku/black_market/rotating/mod_chameleon = 3,
		/datum/shop_sku/black_market/rare/mod_adrenaline = 3,
		/datum/shop_sku/black_market/rare/energy_sword = 3,
		/datum/shop_sku/favor/vex_insurance = 3,
		/datum/shop_sku/ripperdoc/atlas = 3,
		/datum/shop_sku/ripperdoc/gorilla = 3,
		/datum/shop_sku/ripperdoc/monowire = 3,
		/datum/shop_sku/ripperdoc/ronin = 3,
		/datum/shop_sku/ripperdoc/rigger = 3,
		/datum/shop_sku/ripperdoc/slabskin = 3,
		/datum/shop_sku/ripperdoc/mantis = 3,
		/datum/shop_sku/ripperdoc/bunker_buster = 3,
		/datum/shop_sku/ripperdoc/ghostskin = 3,
		/datum/shop_sku/ripperdoc/lazarus = 3,
		/datum/shop_sku/ripperdoc/governor_delete = 3,
		/datum/shop_sku/ripperdoc/redline = 3,
		/datum/shop_sku/ripperdoc/cascade = 3,
		/datum/shop_sku/ripperdoc/ronin_mag = 3,
		/datum/shop_sku/ripperdoc/buster_rockets = 3,
	)

/datum/unit_test/voidcrew_zone_shops/catalog/Run()
	var/list/expected = expected_tags()
	TEST_ASSERT_EQUAL(length(expected), 57, "The retained permission catalog is incomplete")
	var/datum/voidcrew_crew_record/crew = allocate(/datum/voidcrew_crew_record)
	for(var/datum/shop_sku/sku_type as anything in subtypesof(/datum/shop_sku))
		var/permission = expected[sku_type] || 0
		TEST_ASSERT_EQUAL(initial(sku_type.zone_permission), permission, "[sku_type] has the wrong permission or lost its Public default")
		if(!permission)
			continue
		var/datum/shop_sku/sku = allocate(sku_type)
		TEST_ASSERT(!sku.has_zone_permission(null), "Missing context admitted [sku_type]")
		for(var/level in 0 to 3)
			set_permission(crew, level)
			TEST_ASSERT_EQUAL(!!sku.has_zone_permission(crew), level >= permission, "[sku_type] admitted the wrong crew permission")

	// Include undealt and weighted shelves so a random rotation cannot hide an omission.
	for(var/shop_type in subtypesof(/datum/outpost_shop))
		var/datum/outpost_shop/shop = allocate(shop_type)
		var/list/occurrences = shop.sku_types + shop.rotating_pool + shop.rare_pool + shop.favor_sku_types + shop.chart_pool
		for(var/datum/shop_rotation/rotation as anything in shop.live_rotations)
			occurrences |= rotation.pool
		for(var/datum/shop_sku/sku_type as anything in occurrences)
			TEST_ASSERT_EQUAL(initial(sku_type.zone_permission), expected[sku_type] || 0, "[shop_type] changed [sku_type]'s permission")
		for(var/datum/shop_sku/sku as anything in shop.skus)
			TEST_ASSERT_EQUAL(sku.zone_permission, expected[sku.type] || 0, "[shop_type] lost a tag while dealing stock")
		qdel(shop)

/// Trader favor never opens stock; zone reputation never changes credit/voucher prices.
/datum/unit_test/voidcrew_zone_shops/favor_and_prices/Run()
	var/obj/structure/overmap/ship/ship = make_ship()
	var/datum/voidcrew_crew_record/crew = record_for(ship)
	var/mob/living/carbon/human/buyer = make_member()
	ship.enlist_crewmember(buyer)
	var/datum/bank_account/account = fund(buyer)
	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop)
	shop.add_sku(/datum/shop_sku/favor/pike_ledger, "favor")
	var/datum/shop_sku/sku = shop.skus[1]
	shop.grant_favor(ship, 1000)
	TEST_ASSERT(!sku.can_afford(buyer) && !sku.try_purchase(buyer, null), "Old favor bypassed zone permission")
	TEST_ASSERT_EQUAL(account.account_balance, 10000, "Denied order took credits")
	TEST_ASSERT_EQUAL(count_trade_vouchers(buyer), 20, "Denied order took vouchers")
	TEST_ASSERT_EQUAL(shop.get_crew_purchases(ship, sku.type), 0, "Denied order claimed the crew cap")
	crew.trader_favor.Cut()
	set_permission(crew, 1)
	TEST_ASSERT_NULL(sku.get_favor_denial(buyer), "Zero trader favor blocked a qualified crew")
	TEST_ASSERT(sku.try_purchase(buyer, null), "Zone permission did not open the back room")
	TEST_ASSERT_EQUAL(account.account_balance, 6800, "Back-room credits changed")
	TEST_ASSERT_EQUAL(count_trade_vouchers(buyer), 18, "Back-room vouchers changed")

	shop.add_sku(/datum/shop_sku/general/toolbelt, "core")
	var/datum/shop_sku/ordinary = shop.skus[2]
	var/list/thresholds = list(0, 2, 4, 6)
	var/list/prices = list(500, 475, 450, 425)
	for(var/index in 1 to 4)
		crew.trader_favor[shop.favor_key()] = thresholds[index]
		TEST_ASSERT_EQUAL(ordinary.get_credit_price(buyer), prices[index], "Favor discount thresholds drifted")
	ordinary.discount_pct = 20
	TEST_ASSERT_EQUAL(ordinary.get_credit_price(buyer), 400, "Special and favor stacked")
	TEST_ASSERT_EQUAL(sku.price_vouchers, 2, "A discount changed vouchers")
	account.siphon_lock_until = world.time + 100
	TEST_ASSERT(!sku.try_purchase(buyer, null), "Frozen account purchased a back-room item")
	TEST_ASSERT_EQUAL(count_trade_vouchers(buyer), 18, "Failed debit consumed vouchers")
	TEST_ASSERT_EQUAL(shop.get_crew_purchases(ship, sku.type), 1, "Failed debit consumed a cap slot")

/// A nested buyer reaches the counter during item creation, after the final shared cap claim.
/datum/shop_sku/zone_shop_probe
	item_path = /obj/item/soap
	var/datum/callback/at_dispense
	var/grants = 0
	var/nested_result

/datum/shop_sku/zone_shop_probe/dispense(mob/living/user, mob/living/basic/outpost_trader/vendor)
	grants++
	if(at_dispense)
		nested_result = at_dispense.Invoke()

/datum/shop_sku/zone_shop_probe/Destroy()
	QDEL_NULL(at_dispense)
	return ..()

/datum/unit_test/voidcrew_zone_shops/shared_caps/Run()
	var/obj/structure/overmap/ship/first = make_ship()
	var/datum/voidcrew_crew_record/crew = record_for(first)
	var/obj/structure/overmap/ship/second = make_ship(crew)
	var/mob/living/carbon/human/one = make_member()
	var/mob/living/carbon/human/two = make_member()
	first.enlist_crewmember(one)
	second.enlist_crewmember(two)
	one.mind.select_crew_service_ship(first)
	two.mind.select_crew_service_ship(second)
	set_permission(crew, 1)
	var/datum/bank_account/account_one = fund(one)
	var/datum/bank_account/account_two = fund(two)
	var/datum/outpost_shop/shop_one = allocate(/datum/outpost_shop)
	var/datum/outpost_shop/shop_two = allocate(/datum/outpost_shop)
	shop_one.add_sku(/datum/shop_sku/zone_shop_probe, "favor")
	shop_two.add_sku(/datum/shop_sku/zone_shop_probe, "favor")
	var/datum/shop_sku/zone_shop_probe/sku_one = shop_one.skus[1]
	var/datum/shop_sku/zone_shop_probe/sku_two = shop_two.skus[1]
	for(var/datum/shop_sku/sku as anything in list(sku_one, sku_two))
		sku.zone_permission = 1
		sku.crew_limit = 3
		sku.price_credits = 1000
	crew.claim_purchase(sku_one.type, 3)
	crew.claim_purchase(sku_one.type, 3)
	sku_one.at_dispense = CALLBACK(sku_two, TYPE_PROC_REF(/datum/shop_sku, try_purchase), two, null)
	TEST_ASSERT(sku_one.try_purchase(one, null), "Final shared cap slot was refused")
	TEST_ASSERT(!sku_one.nested_result, "Concurrent hull bought past the shared cap")
	TEST_ASSERT_EQUAL(sku_one.grants, 1, "Last permitted unit was not dispensed")
	TEST_ASSERT_EQUAL(sku_two.grants, 0, "Capped buyer received goods")
	TEST_ASSERT_EQUAL(account_one.account_balance, 9000, "Permitted buyer paid the wrong account")
	TEST_ASSERT_EQUAL(account_two.account_balance, 10000, "Denied buyer was charged")
	TEST_ASSERT_EQUAL(shop_one.get_crew_purchases(first, sku_one.type), 3, "Shared cap changed during the nested sale")
	TEST_ASSERT_EQUAL(sku_one.stock, 3, "Back-room orders depleted shared shelf stock")

/// Barter has the same permission/cap checks before consuming the offered stack.
/datum/unit_test/voidcrew_zone_shops/barter/Run()
	var/obj/structure/overmap/ship/ship = make_ship()
	var/datum/voidcrew_crew_record/crew = record_for(ship)
	var/mob/living/carbon/human/buyer = make_member()
	ship.enlist_crewmember(buyer)
	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop)
	shop.add_sku(/datum/shop_sku/barter/plasma_for_medkit, "core")
	var/datum/shop_sku/barter/sku = shop.skus[1]
	sku.zone_permission = 1
	sku.crew_limit = 1
	sku.barter_path = /obj/item/stack/sheet/iron
	sku.barter_amount = 2
	sku.item_path = /obj/item/soap
	var/obj/item/stack/sheet/iron/offered = allocate(/obj/item/stack/sheet/iron, buyer, 5)
	buyer.put_in_hands(offered)
	shop.grant_favor(ship, 1000)
	var/stock = sku.stock
	TEST_ASSERT(!sku.can_afford(buyer) && !sku.try_purchase(buyer, null), "Barter bypassed permission")
	TEST_ASSERT_EQUAL(offered.amount, 5, "Denied barter consumed its stack")
	TEST_ASSERT_EQUAL(sku.stock, stock, "Denied barter consumed stock")
	set_permission(crew, 1)
	TEST_ASSERT(sku.try_purchase(buyer, null), "Qualified barter failed")
	TEST_ASSERT_EQUAL(offered.amount, 3, "Barter consumed the wrong quantity")
	TEST_ASSERT(!sku.try_purchase(buyer, null), "A core-shelf barter bypassed the crew cap")
	TEST_ASSERT_EQUAL(offered.amount, 3, "Capped barter consumed its stack")

/// The case itself carries the gate, so buying a pair cannot buy ungated implants.
/datum/unit_test/voidcrew_zone_shops/cases/Run()
	var/obj/structure/overmap/ship/ship = make_ship()
	var/datum/voidcrew_crew_record/crew = record_for(ship)
	var/mob/living/carbon/human/buyer = make_member()
	ship.enlist_crewmember(buyer)
	fund(buyer)
	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop)
	for(var/sku_type in list(/datum/shop_sku/ripperdoc/gorilla, /datum/shop_sku/ripperdoc/mantis))
		shop.add_sku(sku_type, "core")
		var/datum/shop_sku/sku = shop.skus[length(shop.skus)]
		set_permission(crew, 2)
		var/before = count_trade_vouchers(buyer)
		TEST_ASSERT(!sku.try_purchase(buyer, null), "Advanced crew bought military chrome through a case")
		TEST_ASSERT_EQUAL(count_trade_vouchers(buyer), before, "Denied case consumed vouchers")
		set_permission(crew, 3)
		TEST_ASSERT(sku.try_purchase(buyer, null), "Elite crew could not buy its military case")
		var/turf/buyer_turf = get_turf(buyer)
		var/obj/item/cyberware_pair_case/case = locate(sku.item_path) in (buyer.contents + buyer_turf.contents)
		TEST_ASSERT_NOTNULL(case, "The military pair case was not dispensed")
		allocated += case
		TEST_ASSERT_EQUAL(length(case.contents), 2, "A military case changed its pair of implants")
		for(var/ware_type in case.ware_types)
			TEST_ASSERT(locate(ware_type) in case, "A military case lost an implant")

/// Re-querying after a crew switch, withdrawal, retirement or embargo refuses stale orders.
/datum/unit_test/voidcrew_zone_shops/stale_context/Run()
	var/obj/structure/overmap/ship/ship = make_ship()
	var/datum/voidcrew_crew_record/crew = record_for(ship)
	set_permission(crew, 3)
	var/mob/living/carbon/human/buyer = make_member()
	ship.enlist_crewmember(buyer)
	var/datum/bank_account/account = fund(buyer)
	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop)
	shop.add_sku(/datum/shop_sku/favor/pike_ledger, "favor")
	var/datum/shop_sku/sku = shop.skus[1]
	TEST_ASSERT_NULL(sku.get_denial_reason(buyer), "Eligible buyer was denied")
	var/obj/structure/overmap/ship/other = make_ship()
	other.enlist_crewmember(buyer)
	TEST_ASSERT(!sku.try_purchase(buyer, null), "Stale UI bought using its former crew")
	TEST_ASSERT_NOTNULL(sku.get_favor_denial(buyer, ship), "Explicit stale hull bypassed membership")
	TEST_ASSERT_EQUAL(account.account_balance, 10000, "Stale order charged its buyer")
	TEST_ASSERT_EQUAL(shop.get_crew_purchases(ship, sku.type), 0, "Stale order charged its old crew cap")
	ship.enlist_crewmember(buyer)
	ship.retired_by_checkpoint = TRUE
	TEST_ASSERT(!sku.try_purchase(buyer, null), "Retired hull retained service access")
	ship.retired_by_checkpoint = FALSE
	var/obj/structure/overmap/trader_outpost/outpost = allocate(/obj/structure/overmap/trader_outpost)
	shop.outpost = outpost
	outpost.embargo_ship(ship)
	TEST_ASSERT(!sku.try_purchase(buyer, null), "Direct purchase bypassed an embargo")
	outpost.embargoed_ships.Cut()
	shop.skus -= sku
	TEST_ASSERT(!sku.try_purchase(buyer, null), "Removed stock remained purchasable")
	qdel(sku)
	TEST_ASSERT(!sku.try_purchase(buyer, null), "Deleted stock remained purchasable")

/// UI payloads never publish favor totals, tier labels or discount percentages.
/datum/unit_test/voidcrew_zone_shops/presentation/Run()
	var/mob/living/carbon/human/buyer = make_member()
	var/obj/structure/overmap/ship/first = make_ship()
	first.enlist_crewmember(buyer)
	var/datum/voidcrew_crew_record/crew = record_for(first)
	var/obj/structure/overmap/ship/second = make_ship(crew)
	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop/general)
	var/mob/living/basic/outpost_trader/npc = allocate(/mob/living/basic/outpost_trader, run_loc_floor_bottom_left)
	npc.shop = shop
	var/datum/outpost_trader_ui/shop/facet = npc.shop_ui
	var/list/data = facet.ui_data(buyer)
	TEST_ASSERT(!("favor" in data), "Storefront exposed favor standing")
	TEST_ASSERT_EQUAL(length(data["crew_ships"]), 2, "Ship selector did not enumerate the continuing crew's hulls")
	TEST_ASSERT_NULL(data["crew_ship_ref"], "Ambiguous fleet silently chose an account")
	TEST_ASSERT(facet.select_service_ship(buyer, REF(second)), "Counter refused an explicit own-crew hull")
	TEST_ASSERT_EQUAL(get_crew_ship(buyer), second, "Counter did not preserve the selection")
	var/obj/structure/overmap/ship/foreign = make_ship()
	TEST_ASSERT(!facet.select_service_ship(buyer, REF(foreign)), "Ship selector admitted another crew's account")
	var/list/catalog_data = facet.ui_static_data(buyer)
	for(var/list/row as anything in catalog_data["catalog"])
		TEST_ASSERT(!("favor_required" in row) && !("discount_pct" in row), "Catalog exposed an internal admission or discount number")
	TEST_ASSERT_NULL(shop.get_back_room_line(buyer), "Public crew received back-room clearance")
	set_permission(crew, 1)
	TEST_ASSERT_EQUAL(shop.get_back_room_line(buyer), "I'll put a word in at the depot.", "Barnaby's clearance line changed")
	var/list/contracts = npc.contracts_ui.ui_data(buyer)
	TEST_ASSERT(!("favor" in contracts), "Contract counter exposed favor standing")
	var/datum/shop_sku/sku = shop.skus[1]
	TEST_ASSERT(sku.can_trade(buyer, npc), "The live counter rejected its own stock")
	npc.forceMove(run_loc_floor_top_right)
	TEST_ASSERT(!sku.can_trade(buyer, npc), "Moving the counter left a stale live context")
	TEST_ASSERT(!sku.try_purchase(buyer, npc), "A stale action purchased beyond counter range")

/// An ID for one hull cannot redirect the selected hull's balance or payment.
/datum/unit_test/voidcrew_zone_shops/selected_account/Run()
	var/mob/living/carbon/human/buyer = make_member()
	var/obj/structure/overmap/ship/first = make_ship()
	first.enlist_crewmember(buyer)
	var/datum/bank_account/first_account = fund(buyer, 0)
	var/datum/voidcrew_crew_record/crew = record_for(first)
	set_permission(crew, 1)
	var/obj/structure/overmap/ship/second = make_ship(crew)
	var/datum/bank_account/second_account = allocate(/datum/bank_account, "Selected ship", null, 1, FALSE)
	second_account.account_balance = 10000
	second.ship_account = second_account
	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop)
	shop.add_sku(/datum/shop_sku/favor/pike_ledger, "favor")
	var/datum/shop_sku/sku = shop.skus[1]
	var/mob/living/basic/outpost_trader/npc = allocate(/mob/living/basic/outpost_trader, run_loc_floor_bottom_left)
	npc.shop = shop
	var/datum/outpost_trader_ui/shop/facet = npc.shop_ui
	var/list/data = facet.ui_data(buyer)
	TEST_ASSERT_NULL(data["account_credits"], "Ambiguous fleet displayed the ID's account")
	TEST_ASSERT_EQUAL(data["sell_account_credits"], 0, "Unselected sale did not display the ID's balance")
	TEST_ASSERT_NULL(sku.get_account(buyer), "Ambiguous fleet fell back to the ID's account")
	var/obj/structure/overmap/trader_outpost/outpost = allocate(/obj/structure/overmap/trader_outpost)
	// Bounds only: no turfs are claimed or released by this reservation fixture.
	outpost.reservation = allocate(/datum/turf_reservation)
	outpost.reservation.bottom_left_turfs = list(run_loc_floor_bottom_left)
	outpost.reservation.width = 1
	outpost.reservation.height = 1
	first.docked = outpost
	TEST_ASSERT_EQUAL(get_crew_ship(buyer), first, "Fixture did not exercise the sole-berthed-hull fallback")
	TEST_ASSERT(facet.select_service_ship(buyer, REF(second)), "Could not select the second ship")
	TEST_ASSERT_EQUAL(get_crew_ship(buyer), second, "The sole berthed hull overrode an explicit account selection")
	TEST_ASSERT_EQUAL(buyer.get_idcard(TRUE).registered_account, first_account, "Selecting a ship rewrote the carried ID")
	data = facet.ui_data(buyer)
	TEST_ASSERT_EQUAL(data["account_credits"], 10000, "Storefront did not display the selected ship's balance")
	TEST_ASSERT(sku.can_afford(buyer), "An empty ID account blocked the funded selected ship")
	TEST_ASSERT_NULL(sku.get_denial_reason(buyer), "The selected ship's funds were denied")
	var/list/stock_state = data["stock_states"][1]
	TEST_ASSERT(stock_state["can_buy"], "Storefront refused the funded selected ship")
	TEST_ASSERT(sku.try_purchase(buyer, npc), "The selected ship could not pay")
	TEST_ASSERT_EQUAL(first_account.account_balance, 0, "Purchase charged the ID's ship")
	TEST_ASSERT_EQUAL(second_account.account_balance, 6800, "Purchase did not charge the selected ship")
	data = facet.ui_data(buyer)
	TEST_ASSERT_EQUAL(data["account_credits"], 6800, "Storefront did not refresh the selected ship's balance")
	TEST_ASSERT_EQUAL(shop.get_crew_purchases(second, sku.type), 1, "Purchase did not use the selected ship's crew cap")
	var/datum/shop_buyback/buyback = allocate(/datum/shop_buyback)
	buyback.item_path = /obj/item/sea_crystal
	buyback.pay_credits = 300
	allocate(/obj/item/sea_crystal, buyer)
	TEST_ASSERT_NULL(buyback.get_denial_reason(buyer), "An empty ID account blocked a sale to the selected ship")
	TEST_ASSERT(buyback.try_sell(buyer, null), "The selected ship could not receive a sale")
	TEST_ASSERT_EQUAL(first_account.account_balance, 0, "Sale paid the ID's ship")
	TEST_ASSERT_EQUAL(second_account.account_balance, 7100, "Sale did not pay the selected ship")
	data = facet.ui_data(buyer)
	TEST_ASSERT_EQUAL(data["sell_account_credits"], 7100, "Sell balance did not reflect the account paid")

	first_account.account_balance = 10000
	second_account.account_balance = 0
	TEST_ASSERT(!sku.can_afford(buyer), "The ID's funds bypassed the selected ship's empty account")
	TEST_ASSERT_NOTNULL(sku.get_denial_reason(buyer), "Empty selected account had no denial")
	TEST_ASSERT(!sku.try_purchase(buyer, npc), "Purchase fell back to the funded ID account")
	TEST_ASSERT_EQUAL(first_account.account_balance, 10000, "Refused purchase charged the ID's ship")
	TEST_ASSERT_EQUAL(count_trade_vouchers(buyer), 18, "Refused purchase consumed vouchers")
	TEST_ASSERT_EQUAL(shop.get_crew_purchases(second, sku.type), 1, "Refused purchase consumed a cap slot")
	data = facet.ui_data(buyer)
	TEST_ASSERT_EQUAL(data["account_credits"], 0, "Storefront hid an empty selected account")
	stock_state = data["stock_states"][1]
	TEST_ASSERT(!stock_state["can_buy"], "Storefront offered an unaffordable purchase")
	second.ship_account = null
	allocate(/obj/item/sea_crystal, buyer)
	TEST_ASSERT_NULL(buyback.get_denial_reason(buyer), "A missing ship account blocked the ID fallback")
	TEST_ASSERT(buyback.try_sell(buyer, null), "A missing ship account did not fall back to the ID")
	TEST_ASSERT_EQUAL(first_account.account_balance, 10300, "The ID fallback did not receive the sale")
	TEST_ASSERT_EQUAL(second_account.account_balance, 0, "The sale paid the detached ship account")
	TEST_ASSERT_EQUAL(buyback.count_carried_units(buyer), 0, "The ID fallback did not consume the goods")
	data = facet.ui_data(buyer)
	TEST_ASSERT_NULL(data["account_credits"], "Purchases displayed the fallback ID account")
	TEST_ASSERT_EQUAL(data["sell_account_credits"], 10300, "Sell balance did not refresh the ID fallback")
	TEST_ASSERT_NULL(sku.get_account(buyer), "Missing selected account fell back to the ID")
	TEST_ASSERT(!sku.try_purchase(buyer, npc), "Missing selected account charged the ID")
	var/obj/structure/overmap/ship/foreign = make_ship()
	foreign.ship_account = first_account
	TEST_ASSERT_NULL(sku.get_account(buyer, foreign), "Explicit foreign ship supplied a payment account")
	foreign.ship_account = null
	second.ship_account = second_account

/// A seller without a crew ship can sell into the account on their ID.
/datum/unit_test/voidcrew_zone_shops/crewless_sale/Run()
	var/mob/living/carbon/human/seller = make_member()
	TEST_ASSERT_NULL(get_crew_ship(seller), "The seller unexpectedly has a crew ship")
	var/datum/bank_account/account = allocate(/datum/bank_account, "Crewless seller", null, 1, FALSE)
	account.account_balance = 200
	var/obj/item/card/id/advanced/card = allocate(/obj/item/card/id/advanced)
	qdel(card.registered_account)
	card.registered_account = account
	TEST_ASSERT(seller.put_in_hands(card), "The seller could not carry their ID")
	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop)
	var/datum/shop_buyback/buyback = allocate(/datum/shop_buyback)
	buyback.item_path = /obj/item/sea_crystal
	buyback.name = "sea crystal"
	buyback.pay_credits = 300
	buyback.demand = 3
	shop.buybacks += buyback
	var/mob/living/basic/outpost_trader/npc = allocate(/mob/living/basic/outpost_trader, run_loc_floor_bottom_left)
	npc.shop = shop
	var/datum/outpost_trader_ui/shop/facet = npc.shop_ui
	allocate(/obj/item/sea_crystal, seller)
	var/list/data = facet.ui_data(seller)
	TEST_ASSERT_NULL(data["account_credits"], "Crewless purchases displayed the ID account")
	TEST_ASSERT_EQUAL(data["sell_account_credits"], 200, "Crewless sale did not display the ID balance")
	var/list/ledger_state = data["ledger_states"][1]
	TEST_ASSERT(ledger_state["can_sell"], "The Sell tab denied the crewless ID account")
	TEST_ASSERT_NULL(buyback.get_denial_reason(seller), "The crewless ID account was denied")
	TEST_ASSERT(buyback.try_sell(seller, npc), "The crewless seller could not sell for credits")
	TEST_ASSERT_EQUAL(account.account_balance, 500, "The crewless seller's ID account was not paid")
	TEST_ASSERT_EQUAL(buyback.count_carried_units(seller), 0, "The sale did not consume the goods")
	TEST_ASSERT_EQUAL(buyback.demand, 2, "The sale did not consume one demand")
	data = facet.ui_data(seller)
	TEST_ASSERT_EQUAL(data["sell_account_credits"], 500, "Sell balance did not refresh the paid ID account")
	allocate(/obj/item/sea_crystal, seller)
	TEST_ASSERT_EQUAL(buyback.try_sell_bulk(seller, npc), 1, "Crewless bulk sale could not use the ID account")
	TEST_ASSERT_EQUAL(account.account_balance, 800, "Bulk sale did not pay the ID account")
	card.registered_account = null
	allocate(/obj/item/sea_crystal, seller)
	TEST_ASSERT_EQUAL(buyback.get_denial_reason(seller), "No bank account on your ID.", "Missing accounts had the wrong refusal")
	TEST_ASSERT(!buyback.try_sell(seller, npc), "A seller without either account could sell for credits")
	TEST_ASSERT_EQUAL(buyback.count_carried_units(seller), 1, "An accountless sale consumed the goods")
	TEST_ASSERT_EQUAL(buyback.demand, 1, "An accountless sale consumed demand")
	TEST_ASSERT_EQUAL(account.account_balance, 800, "An accountless sale paid the former ID account")
	data = facet.ui_data(seller)
	TEST_ASSERT_NULL(data["sell_account_credits"], "Sell balance retained a removed ID account")
	ledger_state = data["ledger_states"][1]
	TEST_ASSERT(!ledger_state["can_sell"], "The Sell tab offered a sale without either account")

/// A quote retains the tagged SKU, including through its stock reservation.
/// Z2 uses this same permission predicate for the viewer's effective package.
/datum/unit_test/voidcrew_zone_shops/packages/Run()
	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop)
	shop.add_sku(/datum/shop_sku/fitter/rotating/suit_security, "core")
	var/datum/shop_sku/sku = shop.skus[1]
	// A cheap fixture makes the package deterministic, independent of random quote value.
	sku.price_credits = 300
	sku.price_vouchers = 0
	var/datum/mission/mission = allocate(/datum/mission)
	mission.difficulty = 3
	TEST_ASSERT(shop.roll_contract_reward(mission), "Could not build the package fixture")
	TEST_ASSERT_EQUAL(mission.contract_stock[sku.item_path], sku, "Package lost the tagged shelf occurrence")
	var/quoted_value = mission.contract_quote
	var/datum/voidcrew_crew_record/crew = allocate(/datum/voidcrew_crew_record)
	TEST_ASSERT(!sku.has_zone_permission(crew), "A package SKU lost its permission")
	set_permission(crew, 1)
	TEST_ASSERT(sku.has_zone_permission(crew), "Qualified package was denied")
	mission.reserve_contract_stock()
	TEST_ASSERT_EQUAL(sku.reserved_stock, 1, "Package did not reserve its tagged SKU")
	TEST_ASSERT_EQUAL(sku.zone_permission, 1, "Reservation discarded the SKU permission")
	TEST_ASSERT_EQUAL(mission.contract_quote, quoted_value, "Reservation rerolled the quote")
	mission.release_contract_stock()
	TEST_ASSERT_EQUAL(sku.reserved_stock, 0, "Package release leaked a stock hold")

/datum/bank_account/zone_shop_refuse/adjust_money(amount, reason)
	if(amount < 0)
		return FALSE
	return ..()

/// Failure at the actual debit must release a previously claimed cap slot.
/datum/unit_test/voidcrew_zone_shops/failed_payment/Run()
	var/obj/structure/overmap/ship/ship = make_ship()
	var/datum/voidcrew_crew_record/crew = record_for(ship)
	set_permission(crew, 1)
	var/mob/living/carbon/human/buyer = make_member()
	ship.enlist_crewmember(buyer)
	fund(buyer)
	var/datum/bank_account/refusing = allocate(/datum/bank_account/zone_shop_refuse, "Refusing bank", null, 1, FALSE)
	refusing.account_balance = 10000
	var/obj/item/card/id/card = buyer.get_idcard(TRUE)
	card.registered_account = refusing
	ship.ship_account = refusing
	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop)
	shop.add_sku(/datum/shop_sku/favor/pike_ledger, "favor")
	var/datum/shop_sku/sku = shop.skus[1]
	TEST_ASSERT(!sku.try_purchase(buyer, null), "Refused debit granted stock")
	TEST_ASSERT_EQUAL(count_trade_vouchers(buyer), 20, "Refused debit consumed vouchers")
	TEST_ASSERT_EQUAL(refusing.account_balance, 10000, "Refused debit changed credits")
	TEST_ASSERT_EQUAL(shop.get_crew_purchases(ship, sku.type), 0, "Refused debit retained a shared cap claim")

#endif
