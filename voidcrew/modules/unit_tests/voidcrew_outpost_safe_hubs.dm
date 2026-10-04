/**
 * Outposts are safe hubs: ship weapons never target one, player-owned or trader, and no trader
 * outpost map rolls hostile creatures inside itself.
 */

/// Neither a player outpost nor a trader outpost is a ship combat target, and a weapons console will not lock onto either
/datum/unit_test/voidcrew_outpost_not_combat_target
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_not_combat_target/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("notcombattargetowner")
	TEST_ASSERT_NOTNULL(home, "The test outpost did not load")
	var/obj/structure/overmap/trader_outpost/market = allocate(/obj/structure/overmap/trader_outpost/general)
	var/obj/machinery/computer/camera_advanced/ship_combat/console = allocate(/obj/machinery/computer/camera_advanced/ship_combat, run_loc_floor_bottom_left)

	// The two made here, and every outpost the round itself spawned
	var/list/outposts = list(home, market)
	outposts |= GLOB.player_outposts
	outposts |= GLOB.trader_outposts
	for(var/obj/structure/overmap/outpost in outposts)
		TEST_ASSERT(!outpost.is_combat_targetable(), "[outpost] ([outpost.type]) is a ship combat target")
		TEST_ASSERT(!console.start_targeting(outpost), "A weapons console started a lock on [outpost] ([outpost.type])")
		TEST_ASSERT(!console.set_target_ship(outpost), "A weapons console accepted [outpost] ([outpost.type]) as a target")
		TEST_ASSERT_NULL(console.targeting_ship, "A weapons console is locking onto [outpost] ([outpost.type])")
		TEST_ASSERT_NULL(console.target_ship, "A weapons console holds a lock on [outpost] ([outpost.type])")
		TEST_ASSERT(!console.is_targeting, "A weapons console is acquiring a lock after refusing [outpost] ([outpost.type])")

/// No trader outpost map places a zone mob marker or a mob spawner: those roll hostiles after the load, inside a safe hub
/datum/unit_test/voidcrew_trader_outpost_no_hostile_spawners

/datum/unit_test/voidcrew_trader_outpost_no_hostile_spawners/Run()
	var/static/list/banned_paths = list(
		"/obj/effect/zone_mobs",
		"/obj/structure/spawner",
	)
	var/checked = 0
	for(var/datum/map_template/trader_outpost/template_path as anything in subtypesof(/datum/map_template/trader_outpost))
		var/map_path = initial(template_path.mappath)
		if(!map_path)
			continue
		var/text = file2text(map_path)
		TEST_ASSERT(length(text), "[template_path] points at [map_path], which could not be read")
		checked++
		for(var/banned in banned_paths)
			if(findtext(text, banned))
				TEST_FAIL("[map_path] ([template_path]) places [banned], which spawns hostiles inside a trader outpost")
	TEST_ASSERT(checked, "No trader outpost map was checked")
