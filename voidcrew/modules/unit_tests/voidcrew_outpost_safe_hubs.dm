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

/**
 * Loads all three trader outposts and checks their checkpoints (voidcrew/modules/trade/outpost_checkpoint.dm):
 * every mapped scan chamber links up where the map put it with a scanner on its wall, the lift lands in the
 * checkpoint lobby, the lobby and the exterior only reach the concourse through a checkpoint, and one real
 * cycle refuses a gun and passes a clean visitor. The chamber's rules themselves are in
 * voidcrew_trader_checkpoint.dm.
 */
/datum/unit_test/voidcrew_trader_checkpoint_maps/Run()
	// checkpoint id -> list(outer x, outer y, inner x, inner y, chamber tiles, has a guard), map-local coordinates
	var/list/expected = list(
		/obj/structure/overmap/trader_outpost/general = list(
			"halcyon_arrivals" = list(38, 35, 38, 38, 4, TRUE),
		),
		/obj/structure/overmap/trader_outpost/outfitter = list(
			"quartermain_gate" = list(20, 9, 20, 12, 4, TRUE),
			"quartermain_west_yard" = list(11, 30, 13, 30, 1, FALSE),
			"quartermain_east_yard" = list(38, 8, 36, 8, 1, FALSE),
		),
		/obj/structure/overmap/trader_outpost/black_market = list(
			"undertow_door" = list(30, 5, 29, 7, 2, TRUE),
			"undertow_bar" = list(36, 18, 34, 18, 1, FALSE),
		),
	)
	// The lift landing's bottom-left tile
	var/list/landings = list(
		/obj/structure/overmap/trader_outpost/general = list(37, 27),
		/obj/structure/overmap/trader_outpost/outfitter = list(14, 7),
		/obj/structure/overmap/trader_outpost/black_market = list(34, 2),
	)
	var/checked = 0
	for(var/host_type in expected)
		var/obj/structure/overmap/trader_outpost/market = allocate(host_type)
		TEST_ASSERT(market.load_level(), "Could not load [host_type]")
		var/turf/origin = market.template_bottom_left
		var/list/entries = expected[host_type]
		TEST_ASSERT_EQUAL(length(market.checkpoints), length(entries), "[host_type] has the wrong number of checkpoints")
		for(var/checkpoint_id in entries)
			var/list/entry = entries[checkpoint_id]
			var/datum/outpost_checkpoint/checkpoint = market.checkpoints[checkpoint_id]
			TEST_ASSERT_NOTNULL(checkpoint, "[host_type] is missing checkpoint [checkpoint_id]")
			TEST_ASSERT_EQUAL(get_turf(checkpoint.outer_door), locate(origin.x + entry[1] - 1, origin.y + entry[2] - 1, origin.z), "[checkpoint_id]'s outer door moved")
			TEST_ASSERT_EQUAL(get_turf(checkpoint.inner_door), locate(origin.x + entry[3] - 1, origin.y + entry[4] - 1, origin.z), "[checkpoint_id]'s inner door moved")
			TEST_ASSERT_EQUAL(length(checkpoint.chamber_turfs), entry[5], "[checkpoint_id]'s chamber is the wrong size")
			TEST_ASSERT_NOTNULL(checkpoint.sensor, "[checkpoint_id] has no wall scanner")
			TEST_ASSERT(get_turf(checkpoint.sensor) in checkpoint.chamber_turfs, "[checkpoint_id]'s wall scanner is not in its chamber")
			TEST_ASSERT(isclosedturf(get_step(checkpoint.sensor, checkpoint.sensor.dir)), "[checkpoint_id]'s wall scanner is not on a wall")
			TEST_ASSERT_EQUAL(!isnull(checkpoint.guard), entry[6], "[checkpoint_id]'s guard is missing or unexpected")
			TEST_ASSERT(market.is_secured_turf(checkpoint.secured_turf), "[checkpoint_id]'s inner door does not lead past the checkpoint")
			TEST_ASSERT(!market.is_secured_turf(checkpoint.lobby_turf), "[checkpoint_id]'s outer door opens onto the concourse")
			for(var/turf/tile as anything in checkpoint.chamber_turfs + list(get_turf(checkpoint.outer_door), get_turf(checkpoint.inner_door)))
				TEST_ASSERT(!market.is_secured_turf(tile), "[checkpoint_id] has a chamber or door tile past the checkpoint")
			TEST_ASSERT(HAS_TRAIT(checkpoint.inner_door, "outpost_property") && HAS_TRAIT(checkpoint.outer_door, "outpost_property"), "[checkpoint_id]'s doors are not outpost property")
			if(checkpoint.guard)
				TEST_ASSERT(locate(/datum/shop_sku/weapons_permit) in checkpoint.guard.shop?.skus, "[checkpoint_id]'s guard does not sell permits")
		// The lift lands in the checkpoint lobby, in its old order, with its panel in reach
		TEST_ASSERT_EQUAL(length(market.lobby_alcove_turfs), 9, "[host_type]'s lift lost a landing tile")
		var/list/landing = landings[host_type]
		var/index = 0
		for(var/y_offset in 0 to 2)
			for(var/x_offset in 0 to 2)
				var/turf/tile = locate(origin.x + landing[1] + x_offset - 1, origin.y + landing[2] + y_offset - 1, origin.z)
				TEST_ASSERT_EQUAL(market.lobby_alcove_turfs[++index], tile, "[host_type]'s landing order changed")
				TEST_ASSERT(isopenturf(tile) && !market.is_secured_turf(tile), "[host_type]'s landing is walled or past the checkpoint")
				for(var/atom/movable/blocker in tile)
					TEST_ASSERT(!blocker.density, "[blocker] blocks [host_type]'s lift landing")
		TEST_ASSERT_EQUAL(length(market.lobby_panels), 1, "[host_type]'s lift panel disappeared")
		var/obj/machinery/outpost_elevator/panel = market.lobby_panels[1]
		TEST_ASSERT(get_turf(panel) in market.lobby_alcove_turfs, "[host_type]'s lift panel is out of reach of its riders")
		check_elevator_travel(market, panel)
		// The public network pad arrives in the lobby
		var/obj/machinery/outpost_network_pad/trader/pad = market.network_pad_ref?.resolve()
		TEST_ASSERT(istype(pad), "[host_type] has no network pad")
		TEST_ASSERT(!market.is_secured_turf(get_turf(pad)) && !market.is_secured_turf(pad.arrival_turf), "[host_type]'s network pad lands people past the checkpoint")
		// Sealed: the lobby and the exterior reach the concourse only through a checkpoint
		var/turf/leak = flood_to_concourse(market, market.lobby_alcove_turfs)
		TEST_ASSERT_NULL(leak, "[host_type]'s lift reaches the concourse around the checkpoint")
		var/list/exterior = list()
		for(var/turf/tile as anything in block(origin, locate(origin.x + market.outpost_template.width - 1, origin.y + market.outpost_template.height - 1, origin.z)))
			if(istype(tile.loc, /area/space) && isopenturf(tile))
				exterior += tile
		leak = flood_to_concourse(market, exterior)
		TEST_ASSERT_NULL(leak, "[host_type]'s exterior reaches the concourse around the checkpoint")
		// One real cycle at the main checkpoint
		var/datum/outpost_checkpoint/main
		for(var/checkpoint_id in market.checkpoints)
			var/datum/outpost_checkpoint/candidate = market.checkpoints[checkpoint_id]
			if(candidate.guard)
				main = candidate
		TEST_ASSERT_NOTNULL(main, "[host_type] has no guarded checkpoint")
		var/mob/living/carbon/human/visitor = allocate(/mob/living/carbon/human/consistent, main.chamber_turfs[1])
		var/obj/item/gun/weapon = allocate(/obj/item/gun/ballistic/automatic/pistol, visitor)
		TEST_ASSERT(main.request_cycle(visitor), "[host_type]'s inner door did not take a scan request")
		main.finish_scan()
		TEST_ASSERT_EQUAL(main.state, "rejecting", "[host_type]'s checkpoint let a gun through") // CHECKPOINT_REJECTING
		qdel(weapon)
		main.set_state("idle") // CHECKPOINT_IDLE
		sleep(2 SECONDS)
		main.close_door(main.outer_door)
		sleep(2 SECONDS)
		TEST_ASSERT(main.outer_door.density, "[host_type]'s outer door did not close")
		TEST_ASSERT_EQUAL(main.state, "scanning", "Closing the outer door on a visitor did not scan") // CHECKPOINT_SCANNING
		main.finish_scan()
		TEST_ASSERT_EQUAL(main.state, "passing", "[host_type]'s checkpoint refused a clean visitor") // CHECKPOINT_PASSING
		sleep(2 SECONDS)
		TEST_ASSERT(!main.inner_door.density, "[host_type]'s inner door did not open for a clean visitor")
		checked++
	TEST_ASSERT_EQUAL(checked, 3, "Did not check all three trader outposts")

/**
 * The first concourse tile past the checkpoint reached from `starts`, or null. Walls, full windows,
 * shutters, checkpoint doors and exit gates stop the walk; furniture, railings and ordinary doors do
 * not. False walls stop it too: the Undertow's hidden restroom doors to the hull are its smugglers' way.
 */
/datum/unit_test/voidcrew_trader_checkpoint_maps/proc/flood_to_concourse(obj/structure/overmap/trader_outpost/market, list/starts)
	var/list/reached = list()
	var/list/queue = list()
	for(var/turf/start as anything in starts)
		reached[start] = TRUE
		queue += start
	var/index = 1
	while(index <= length(queue))
		var/turf/current = queue[index++]
		if(market.is_secured_turf(current))
			return current
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || reached[next])
				continue
			reached[next] = TRUE
			if(!seal_barrier(next))
				queue += next
	return null

/datum/unit_test/voidcrew_trader_checkpoint_maps/proc/seal_barrier(turf/tile)
	if(isclosedturf(tile))
		return TRUE
	for(var/obj/thing in tile)
		if(istype(thing, /obj/machinery/door/airlock/outpost/checkpoint) || istype(thing, /obj/structure/outpost_exit_gate) || istype(thing, /obj/machinery/door/poddoor) || istype(thing, /obj/structure/falsewall))
			return TRUE
		if(istype(thing, /obj/structure/window))
			var/obj/structure/window/pane = thing
			if(pane.fulltile)
				return TRUE
	return FALSE

/// Move nine passengers down and back through the real elevator proc, retaining their tile order.
/datum/unit_test/voidcrew_trader_checkpoint_maps/proc/check_elevator_travel(obj/structure/overmap/trader_outpost/market, obj/machinery/outpost_elevator/lobby_panel)
	var/datum/outpost_berth/berth = new(market, 1, null)
	market.berths[1] = berth
	berth.reservation = SSmapping.request_turf_block_reservation(3, 3, 1)
	TEST_ASSERT_NOTNULL(berth.reservation, "Could not reserve an elevator destination")
	for(var/turf/tile as anything in block(berth.reservation.bottom_left_turfs[1], berth.reservation.top_right_turfs[1]))
		berth.alcove_turfs += tile.ChangeTurf(/turf/open/indestructible)
	berth.panel = new /obj/machinery/outpost_elevator(berth.alcove_turfs[1])
	berth.panel.outpost = market
	berth.panel.berth = berth
	var/list/obj/item/coin/passengers = list()
	var/list/stationary_fixtures = list()
	for(var/turf/landing as anything in market.lobby_alcove_turfs)
		passengers += allocate(/obj/item/coin, landing)
		for(var/obj/machinery/fixture in landing)
			if(fixture.anchored)
				stationary_fixtures[fixture] = landing
	var/mob/living/carbon/human/rider = allocate(/mob/living/carbon/human, market.lobby_alcove_turfs[5])
	TEST_ASSERT(get_dist(rider, lobby_panel) <= 1, "Elevator controls are out of reach of a standing rider")
	lobby_panel.complete_ride(1, WEAKREF(rider))
	for(var/obj/machinery/fixture as anything in stationary_fixtures)
		TEST_ASSERT_EQUAL(get_turf(fixture), stationary_fixtures[fixture], "Elevator carried an anchored fixture downstairs")
	for(var/i in 1 to 9)
		TEST_ASSERT_EQUAL(get_turf(passengers[i]), berth.alcove_turfs[i], "Elevator changed the outgoing tile order")
	TEST_ASSERT_EQUAL(get_turf(rider), berth.alcove_turfs[5], "Elevator did not carry the rider down")
	berth.panel.complete_ride(0, WEAKREF(rider))
	for(var/obj/machinery/fixture as anything in stationary_fixtures)
		TEST_ASSERT_EQUAL(get_turf(fixture), stationary_fixtures[fixture], "Elevator moved an anchored fixture on return")
	for(var/i in 1 to 9)
		TEST_ASSERT_EQUAL(get_turf(passengers[i]), market.lobby_alcove_turfs[i], "Elevator changed the returning tile order")
	TEST_ASSERT_EQUAL(get_turf(rider), market.lobby_alcove_turfs[5], "Elevator did not return the rider")
	qdel(rider)
	for(var/obj/item/coin/passenger as anything in passengers)
		qdel(passenger)
	qdel(berth)
