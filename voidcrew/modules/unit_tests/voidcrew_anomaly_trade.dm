// Fork defines are included after upstream unit tests, so the signal and zone values
// below are the literals behind them: COMSIG_VOIDCREW_SHIP_DOCKED is
// "voidcrew_ship_docked" (voidcrew/_DEFINES/ship_defines.dm).

/// The nine raw anomaly crates are gone from every cargo console.
/datum/unit_test/voidcrew_anomaly_cargo_hidden/Run()
	var/list/raw_packs = list(
		/datum/supply_pack/science/raw_flux_anomaly,
		/datum/supply_pack/science/raw_hallucination_anomaly,
		/datum/supply_pack/science/raw_grav_anomaly,
		/datum/supply_pack/science/raw_vortex_anomaly,
		/datum/supply_pack/science/raw_ectoplasm_anomaly,
		/datum/supply_pack/science/raw_bluespace_anomaly,
		/datum/supply_pack/science/raw_pyro_anomaly,
		/datum/supply_pack/science/raw_bioscrambler_anomaly,
		/datum/supply_pack/science/raw_dimensional_anomaly,
	)
	for(var/pack_type in raw_packs)
		var/datum/supply_pack/pack = allocate(pack_type)
		TEST_ASSERT_NULL(pack.contains, "[pack_type] still has contents, so SSshuttle registers it")
	for(var/pack_id in SSshuttle.supply_packs)
		var/datum/supply_pack/pack = SSshuttle.supply_packs[pack_id]
		for(var/item in pack.contains)
			if(ispath(item, /obj/item/raw_anomaly_core))
				TEST_FAIL("[pack.type] sells [item] over cargo")

/// Boffin's core and chart rotations: every type, the right price band, one unit,
/// no discounts, and sold slots turn over instead of refilling.
/datum/unit_test/voidcrew_anomaly_boffin_shelves/Run()
	var/list/core_prices = list(
		/obj/item/raw_anomaly_core/flux = 25000,
		/obj/item/raw_anomaly_core/grav = 25000,
		/obj/item/raw_anomaly_core/hallucination = 25000,
		/obj/item/raw_anomaly_core/pyro = 25000,
		/obj/item/raw_anomaly_core/bioscrambler = 30000,
		/obj/item/raw_anomaly_core/ectoplasm = 30000,
		/obj/item/raw_anomaly_core/dimensional = 30000,
		/obj/item/raw_anomaly_core/bluespace = 35000,
		/obj/item/raw_anomaly_core/vortex = 35000,
	)
	var/list/chart_prices = list(
		/obj/effect/anomaly/flux = 12500,
		/obj/effect/anomaly/grav = 12500,
		/obj/effect/anomaly/hallucination = 12500,
		/obj/effect/anomaly/pyro = 12500,
		/obj/effect/anomaly/bioscrambler = 15000,
		/obj/effect/anomaly/ectoplasm = 15000,
		/obj/effect/anomaly/dimensional = 15000,
		/obj/effect/anomaly/bluespace = 17500,
		/obj/effect/anomaly/bhole = 17500,
	)

	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop/vendor/skunkworks, null)
	var/datum/shop_rotation/cores
	var/datum/shop_rotation/charts
	for(var/datum/shop_rotation/rotation as anything in shop.live_rotations)
		if(istype(rotation, /datum/shop_rotation/skunk_cores))
			cores = rotation
		else if(istype(rotation, /datum/shop_rotation/skunk_anomaly_charts))
			charts = rotation
	TEST_ASSERT_NOTNULL(cores, "Boffin has no raw core rotation")
	TEST_ASSERT_NOTNULL(charts, "Boffin has no anomaly chart rotation")

	var/list/cores_seen = list()
	for(var/datum/shop_sku/sku_type as anything in cores.pool)
		var/item = initial(sku_type.item_path)
		TEST_ASSERT(item in core_prices, "[sku_type] sells [item], which is not a raw anomaly core")
		TEST_ASSERT_EQUAL(initial(sku_type.price_credits), core_prices[item], "[sku_type] is in the wrong price band")
		TEST_ASSERT(!initial(sku_type.fixed_price), "[sku_type] ignores favor and specials")
		TEST_ASSERT(!initial(sku_type.contract_reward), "[sku_type] can be paid out by contracts")
		TEST_ASSERT_EQUAL(initial(sku_type.stock_max), 1, "[sku_type] stocks more than one unit")
		cores_seen[item] = cores.pool[sku_type]
	TEST_ASSERT_EQUAL(length(cores_seen), 9, "Boffin's core rotation does not cover all nine types")
	TEST_ASSERT(cores_seen[/obj/item/raw_anomaly_core/flux] > cores_seen[/obj/item/raw_anomaly_core/bioscrambler], "Uncommon cores are not rarer than common ones")
	TEST_ASSERT(cores_seen[/obj/item/raw_anomaly_core/bioscrambler] > cores_seen[/obj/item/raw_anomaly_core/vortex], "Rare cores are not rarer than uncommon ones")

	var/list/charts_seen = list()
	for(var/datum/shop_sku/anomaly_chart/sku_type as anything in charts.pool)
		var/anomaly = initial(sku_type.anomaly_type)
		var/base_type
		for(var/candidate in chart_prices)
			if(ispath(anomaly, candidate))
				base_type = candidate
				break
		TEST_ASSERT_NOTNULL(base_type, "[sku_type] points at [anomaly], which is not one of the nine anomaly types")
		TEST_ASSERT_EQUAL(initial(sku_type.price_credits), chart_prices[base_type], "[sku_type] is in the wrong price band")
		TEST_ASSERT(!initial(sku_type.fixed_price), "[sku_type] ignores favor and specials")
		var/obj/effect/anomaly/anomaly_path = anomaly
		TEST_ASSERT(initial(anomaly_path.immortal) && initial(anomaly_path.site_bound), "[sku_type] surfaces an anomaly that times out or can leave its site")
		charts_seen[base_type] = TRUE
	TEST_ASSERT_EQUAL(length(charts_seen), 9, "Boffin's chart rotation does not cover all nine types")

	for(var/datum/shop_rotation/rotation as anything in list(cores, charts))
		var/list/on_shelf = list()
		for(var/datum/shop_sku/sku as anything in shop.skus)
			if(sku.rotation == rotation)
				on_shelf += sku
		TEST_ASSERT(length(on_shelf) >= 1 && length(on_shelf) <= rotation.slots, "[rotation.type] put [length(on_shelf)] SKUs on the shelf")
		var/datum/shop_sku/sold = on_shelf[1]
		TEST_ASSERT_EQUAL(sold.stock, 1, "[sold.type] stocked [sold.stock] units")
		sold.discount_pct = 30
		TEST_ASSERT_EQUAL(sold.get_credit_price(), round(sold.price_credits * 0.7, 5), "A special did not discount [sold.type]")
		var/sold_type = sold.type
		sold.stock = 0
		shop.convoy_restock()
		TEST_ASSERT(!(sold in shop.skus), "The convoy refilled a sold [sold_type] in place")
		var/list/after = list()
		for(var/datum/shop_sku/sku as anything in shop.skus)
			if(sku.rotation == rotation)
				after += sku.type
		TEST_ASSERT_EQUAL(length(after), length(on_shelf), "The convoy did not replace the sold slot")
		TEST_ASSERT(!(sold_type in after), "The sold slot came back as the same [sold_type]")
		TEST_ASSERT_EQUAL(length(unique_list(after)), length(after), "The rotation shelved the same SKU twice")

/// Raw cores take the normal favor discount, and the better of favor or special wins.
/datum/unit_test/voidcrew_anomaly_core_favor/Run()
	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop)
	shop.add_sku(/datum/shop_sku/skunk/anomaly_core/vortex, "rotating")
	var/datum/shop_sku/skunk/anomaly_core/sku = shop.skus[1]
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/mob/living/carbon/human/buyer = allocate(/mob/living/carbon/human/consistent)
	buyer.mind_initialize()
	allocated += buyer.mind
	var/datum/team/voidcrew/team = allocate(/datum/team/voidcrew)
	team.ship = ship
	buyer.mind.ship_teams = list(team)
	sku.discount_pct = 0
	TEST_ASSERT_EQUAL(sku.get_credit_price(buyer), 35000, "A stranger got a discount")
	ship.trader_favor = list()
	ship.trader_favor[shop.favor_key()] = 6 // FAVOR_TIER_TRUSTED, 15% off
	TEST_ASSERT_EQUAL(sku.get_credit_price(buyer), 29750, "A Trusted crew did not get the normal favor discount")
	sku.discount_pct = 30
	TEST_ASSERT_EQUAL(sku.get_credit_price(buyer), 24500, "The better special did not win over favor")
	sku.discount_pct = 10
	TEST_ASSERT_EQUAL(sku.get_credit_price(buyer), 29750, "Favor and special stacked, or the better one lost")
	buyer.mind.ship_teams = null
	team.ship = null

/// Buying a chart takes the money and puts a sealed anomaly rumor on the ship.
/datum/unit_test/voidcrew_anomaly_chart_purchase/Run()
	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop)
	shop.add_sku(/datum/shop_sku/anomaly_chart/grav, "rotating")
	var/datum/shop_sku/anomaly_chart/sku = shop.skus[1]
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/mob/living/carbon/human/buyer = allocate(/mob/living/carbon/human/consistent)
	buyer.mind_initialize()
	allocated += buyer.mind
	var/datum/team/voidcrew/team = allocate(/datum/team/voidcrew)
	team.ship = ship
	buyer.mind.ship_teams = list(team)
	var/datum/bank_account/account = allocate(/datum/bank_account, "Anomaly chart test", null, 1, FALSE)
	account.account_balance = 20000
	var/obj/item/card/id/advanced/id_card = allocate(/obj/item/card/id/advanced)
	qdel(id_card.registered_account)
	id_card.registered_account = account
	TEST_ASSERT(buyer.put_in_hands(id_card), "Buyer could not carry their paying ID")

	TEST_ASSERT(sku.try_purchase(buyer, null), "Chart purchase failed")
	TEST_ASSERT_EQUAL(account.account_balance, 7500, "The chart charged the wrong amount")
	TEST_ASSERT_EQUAL(length(ship.pending_rumors), 1, "Purchase did not upload a sealed chart")
	var/datum/rumor_chart/anomaly/chart = ship.pending_rumors[1]
	TEST_ASSERT(istype(chart), "The sealed chart is not an anomaly chart")
	TEST_ASSERT_EQUAL(chart.anomaly_type, /obj/effect/anomaly/grav/planetary, "The chart names the wrong anomaly")
	TEST_ASSERT(!chart.revealed && !chart.surfaced, "A fresh chart is already revealed")
	TEST_ASSERT(!sku.try_purchase(buyer, null), "A one-unit chart sold twice")
	TEST_ASSERT_EQUAL(account.account_balance, 7500, "A refused purchase took money")

	qdel(ship)
	TEST_ASSERT(QDELETED(chart), "Hull loss left its sealed chart alive")
	buyer.mind.ship_teams = null
	team.ship = null

/// Test chart that skips site generation and spawn-point search
/datum/rumor_chart/anomaly/unit_test
	var/obj/structure/overmap/test_site
	var/turf/test_turf

/datum/rumor_chart/anomaly/unit_test/pick_site(obj/structure/overmap/ship/ship)
	return test_site

/datum/rumor_chart/anomaly/unit_test/find_spawn_turf(obj/structure/overmap/site)
	return test_turf

/// Nothing on reveal, nothing for other ships or other sites, one anomaly when the
/// buyer docks at the charted site, and a lost site re-seals the chart.
/datum/unit_test/voidcrew_anomaly_chart_arrival
	var/list/obj/effect/anomaly/spawned = list()

/datum/unit_test/voidcrew_anomaly_chart_arrival/Destroy()
	QDEL_LIST(spawned)
	return ..()

/datum/unit_test/voidcrew_anomaly_chart_arrival/Run()
	var/obj/structure/overmap/ship/buyer = allocate(/obj/structure/overmap/ship)
	var/obj/structure/overmap/ship/stranger = allocate(/obj/structure/overmap/ship)
	var/obj/structure/overmap/space_ruin/site = allocate(/obj/structure/overmap/space_ruin)
	var/obj/structure/overmap/space_ruin/elsewhere = allocate(/obj/structure/overmap/space_ruin)
	var/turf/spot = run_loc_floor_top_right

	var/datum/rumor_chart/anomaly/unit_test/chart = new
	chart.anomaly_type = /obj/effect/anomaly/flux/planetary
	chart.test_site = site
	chart.test_turf = spot
	buyer.add_pending_rumor(chart)

	TEST_ASSERT_EQUAL(buyer.reveal_pending_rumor(chart), site, "Reveal did not chart the site")
	TEST_ASSERT(!QDELETED(chart) && (chart in buyer.active_anomaly_charts), "Revealing consumed the chart before arrival")
	TEST_ASSERT(!(chart in buyer.pending_rumors), "The revealed chart is still sealed on the helm")
	TEST_ASSERT_NULL(locate(/obj/effect/anomaly) in spot, "Revealing the chart spawned the anomaly")

	stranger.docked = site
	SEND_SIGNAL(stranger, "voidcrew_ship_docked")
	TEST_ASSERT_NULL(locate(/obj/effect/anomaly) in spot, "Another crew's arrival surfaced the buyer's anomaly")

	buyer.docked = elsewhere
	SEND_SIGNAL(buyer, "voidcrew_ship_docked")
	TEST_ASSERT_NULL(locate(/obj/effect/anomaly) in spot, "Docking at a different site surfaced the anomaly")

	buyer.docked = site
	SEND_SIGNAL(buyer, "voidcrew_ship_docked")
	var/obj/effect/anomaly/anomaly = locate(/obj/effect/anomaly) in spot
	if(anomaly)
		spawned += anomaly
	TEST_ASSERT_NOTNULL(anomaly, "The buyer docked at the site and no anomaly formed")
	TEST_ASSERT(istype(anomaly, /obj/effect/anomaly/flux/planetary), "The wrong anomaly formed")
	TEST_ASSERT(QDELETED(chart), "The chart outlived its anomaly")

	SEND_SIGNAL(buyer, "voidcrew_ship_docked")
	var/count = 0
	for(var/obj/effect/anomaly/extra in spot)
		count++
		spawned |= extra
	TEST_ASSERT_EQUAL(count, 1, "A second arrival surfaced another anomaly")

	// A site that disappears before arrival hands the chart back sealed
	buyer.docked = null
	stranger.docked = null
	var/datum/rumor_chart/anomaly/unit_test/second = new
	second.anomaly_type = /obj/effect/anomaly/flux/planetary
	second.test_site = elsewhere
	second.test_turf = spot
	buyer.add_pending_rumor(second)
	TEST_ASSERT_EQUAL(buyer.reveal_pending_rumor(second), elsewhere, "Second reveal did not chart its site")
	qdel(elsewhere)
	TEST_ASSERT(!QDELETED(second), "Losing the site deleted the paid chart")
	TEST_ASSERT((second in buyer.pending_rumors) && !(second in buyer.active_anomaly_charts), "Losing the site did not re-seal the chart")
	TEST_ASSERT(!second.revealed, "The re-sealed chart still counts as revealed")

/// Every anomaly type can seed on planets, as immortal site-bound subtypes, rarer
/// for the dangerous ones.
/datum/unit_test/voidcrew_planet_anomaly_table/Run()
	var/list/base_types = list(
		/obj/effect/anomaly/flux,
		/obj/effect/anomaly/grav,
		/obj/effect/anomaly/hallucination,
		/obj/effect/anomaly/pyro,
		/obj/effect/anomaly/bioscrambler,
		/obj/effect/anomaly/ectoplasm,
		/obj/effect/anomaly/dimensional,
		/obj/effect/anomaly/bluespace,
		/obj/effect/anomaly/bhole,
	)
	var/list/weights = list()
	for(var/base_type in base_types)
		for(var/obj/effect/anomaly/entry as anything in GLOB.voidcrew_planet_anomalies)
			if(!ispath(entry, base_type))
				continue
			TEST_ASSERT(initial(entry.immortal), "[entry] times out on a planet")
			TEST_ASSERT(initial(entry.site_bound), "[entry] can wander off its planet")
			weights[base_type] = GLOB.voidcrew_planet_anomalies[entry]
		TEST_ASSERT(weights[base_type], "[base_type] never seeds on planets")
	TEST_ASSERT(weights[/obj/effect/anomaly/pyro] > weights[/obj/effect/anomaly/dimensional], "Uncommon planet anomalies are not rarer than common ones")
	TEST_ASSERT(weights[/obj/effect/anomaly/dimensional] > weights[/obj/effect/anomaly/bhole], "Rare planet anomalies are not rarer than uncommon ones")
	// Literals 1/2/3 = ZONE_GREEN/YELLOW/RED: every band can roll one, deeper bands more often
	TEST_ASSERT_EQUAL(planet_anomaly_chance(1), 5, "Wrong green planet anomaly chance")
	TEST_ASSERT_EQUAL(planet_anomaly_chance(2), 15, "Wrong yellow planet anomaly chance")
	TEST_ASSERT_EQUAL(planet_anomaly_chance(3), 25, "Wrong red planet anomaly chance")

/// The planetary pyroclastic anomaly burns whoever is next to it and never touches the air.
/datum/unit_test/voidcrew_planet_pyro_jets/Run()
	var/obj/effect/anomaly/pyro/planetary/pyro = allocate(/obj/effect/anomaly/pyro/planetary)
	var/turf/open/origin = get_turf(pyro)
	var/turf/next_door = get_step(origin, NORTH)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, next_door)
	var/datum/gas_mixture/air = origin.return_air()
	var/moles_before = air.total_moles()
	pyro.anomalyEffect(pyro.burst_delay)
	TEST_ASSERT(victim.fire_stacks > 0, "Someone standing next to the burst was not set alight")
	TEST_ASSERT(victim.getFireLoss() > 0, "Someone standing next to the burst took no burns")
	air = origin.return_air()
	TEST_ASSERT_EQUAL(air.total_moles(), moles_before, "The planetary pyroclastic anomaly released gas")
	victim.extinguish_mob()
