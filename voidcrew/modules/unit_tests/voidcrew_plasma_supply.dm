// Package: P5 supply. Unit tests for voidcrew/modules/plasma_weapons/.

/// The guns and the flask leave a crew's hands only by use: no cargo export, buyback or peddler line covers them.
/datum/unit_test/voidcrew_plasma_no_resale

/datum/unit_test/voidcrew_plasma_no_resale/Run()
	var/list/sold = list(
		/obj/item/gun/energy/frontier_laser/pistol,
		/obj/item/gun/energy/frontier_laser/smg,
		/obj/item/gun/energy/plasma_weapon/pistol,
		/obj/item/gun/energy/plasma_weapon/pistol/loot,
		/obj/item/gun/energy/plasma_weapon/rifle,
		/obj/item/gun/energy/plasma_weapon/rifle/loot,
		/obj/item/gun/energy/plasma_weapon/rifle/old_furnace,
		/obj/item/plasma_flask,
	)
	if(!length(GLOB.exports_list))
		setupExports()
	TEST_ASSERT(length(GLOB.exports_list), "No cargo exports were set up")
	for(var/datum/export/export as anything in GLOB.exports_list)
		for(var/item_path in sold)
			if(!is_type_in_typecache(item_path, export.export_types))
				continue
			if(export.include_subtypes && is_type_in_typecache(item_path, export.exclude_types))
				continue
			TEST_FAIL("[export.type] exports [item_path]")

	for(var/datum/shop_buyback/buyback_path as anything in subtypesof(/datum/shop_buyback))
		var/bought = initial(buyback_path.item_path)
		if(!bought)
			continue
		// The outfitter's listed rows (#516) take any item, then only the exact types in their wanted list
		var/list/wanted
		if(ispath(buyback_path, /datum/shop_buyback/outfitter/listed))
			var/datum/shop_buyback/outfitter/listed/listed = new buyback_path
			wanted = listed.wanted_cache || list()
			qdel(listed)
		for(var/item_path in sold)
			if(wanted ? wanted[item_path] : (item_path == bought || (initial(buyback_path.match_subtypes) && ispath(item_path, bought))))
				TEST_FAIL("[buyback_path] buys back [item_path]")

	for(var/datum/shop_sku/sku_path as anything in subtypesof(/datum/shop_sku/peddler))
		var/stocked = initial(sku_path.item_path)
		if(stocked in sold)
			TEST_FAIL("Peddler line [sku_path] stocks [stocked]")

/// Shop lines sit at the gate and price the spec sets, and the loot pools carry each gun.
/datum/unit_test/voidcrew_plasma_supply_routes

/datum/unit_test/voidcrew_plasma_supply_routes/Run()
	// sku type = list(item, gate, credits, vouchers). Gates: 1 yellow, 2 advanced (fork defines follow test includes).
	var/list/lines = list(
		/datum/shop_sku/outfitter/kestrel = list(/obj/item/gun/energy/frontier_laser/pistol, 1, 900, 0),
		/datum/shop_sku/outfitter/cinder = list(/obj/item/gun/energy/plasma_weapon/pistol, 1, 2000, 0),
		/datum/shop_sku/outfitter/plasma_flask = list(/obj/item/plasma_flask, 1, 150, 0),
		/datum/shop_sku/black_market/hornet = list(/obj/item/gun/energy/frontier_laser/smg, 1, 3500, 0),
		/datum/shop_sku/black_market/rotating/furnace = list(/obj/item/gun/energy/plasma_weapon/rifle, 2, 5000, 1),
	)
	for(var/datum/shop_sku/sku_path as anything in lines)
		var/list/line = lines[sku_path]
		TEST_ASSERT_EQUAL(initial(sku_path.item_path), line[1], "[sku_path] sells the wrong item")
		TEST_ASSERT_EQUAL(initial(sku_path.zone_permission), line[2], "[sku_path] has the wrong gate")
		TEST_ASSERT_EQUAL(initial(sku_path.price_credits), line[3], "[sku_path] has the wrong credit price")
		TEST_ASSERT_EQUAL(initial(sku_path.price_vouchers), line[4], "[sku_path] has the wrong voucher price")

	// No Old Furnace on any shelf
	for(var/datum/shop_sku/sku_path as anything in subtypesof(/datum/shop_sku))
		if(initial(sku_path.item_path) == /obj/item/gun/energy/plasma_weapon/rifle/old_furnace)
			TEST_FAIL("[sku_path] sells the Old Furnace")

	// family, class (1 green, 2 yellow, 3 red), item, weight
	var/list/pool_entries = list(
		list("armory", "1", /obj/item/gun/energy/frontier_laser/pistol, 10),
		list("freight", "1", /obj/item/gun/energy/frontier_laser/pistol, 10),
		list("armory", "2", /obj/item/gun/energy/frontier_laser/smg, 10),
		list("armory", "2", /obj/item/gun/energy/plasma_weapon/pistol/loot, 10),
		list("plunder", "2", /obj/item/gun/energy/plasma_weapon/pistol/loot, 10),
		list("plunder", "3", /obj/item/gun/energy/plasma_weapon/rifle/loot, 10),
		list("plunder", "3", /obj/item/gun/energy/plasma_weapon/rifle/old_furnace, 1),
	)
	for(var/list/entry as anything in pool_entries)
		var/list/pool = GLOB.loot_gun_pools[entry[1]][entry[2]]
		TEST_ASSERT_EQUAL(pool[entry[3]], entry[4], "[entry[3]] has the wrong weight in [entry[1]] class [entry[2]]")
