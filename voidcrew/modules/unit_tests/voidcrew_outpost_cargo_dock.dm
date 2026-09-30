/**
 * Outpost cargo dock: the free catalog entry, the landing pad at every rotation, outpost
 * freight landing on it with no elevator and no freight berth, the ferry crushing whatever is
 * left on the pad, and the dock's area being released when its claim is torn down.
 *
 * Voidcrew defines are not visible from test files, so sizes and messages appear as literals.
 * The dock has one map per outpost style; the tests find its pad and doors in the placed room
 * rather than at map coordinates, so they hold for every style.
 */

// ===== SHARED HELPERS =====

/**
 * The doors of a placed upgrade room that lead out of it (a tile beside them is off the footprint)
 * as list(exterior doors, those of them with no tiny fan on their tile). An upgrade's entrance can
 * open onto vacuum or a planet, so every door out needs a fan to hold the air in while it is open.
 */
/datum/unit_test/proc/upgrade_exterior_doors(list/footprint_turfs)
	var/list/inside = list()
	for(var/turf/tile as anything in footprint_turfs)
		inside[tile] = TRUE
	var/list/exterior = list()
	var/list/unfanned = list()
	for(var/turf/tile as anything in footprint_turfs)
		var/obj/machinery/door/door = locate() in tile
		if(!door)
			continue
		var/leads_out = FALSE
		for(var/direction in GLOB.cardinals)
			if(!inside[get_step(tile, direction)])
				leads_out = TRUE
				break
		if(!leads_out)
			continue
		exterior += door
		if(!(locate(/obj/structure/fans/tiny) in tile))
			unfanned += door
	return list(exterior, unfanned)

/// A docking port's landing rectangle as list(min_x, min_y, max_x, max_y)
/datum/unit_test/proc/cargo_dock_rect(obj/docking_port/port)
	var/list/coords = port.return_coords()
	return list(min(coords[1], coords[3]), min(coords[2], coords[4]), max(coords[1], coords[3]), max(coords[2], coords[4]))

/// The bottom-left for a cargo dock beside the claim's shell: north, east, south or west of it by rotation.
/datum/unit_test/proc/cargo_dock_test_corner(obj/structure/overmap/dynamic/player_outpost/home, rotation)
	var/turf/shell_corner = home.template_bottom_left
	if(!shell_corner || !home.shell_template)
		return null
	var/left = shell_corner.x
	var/bottom = shell_corner.y
	var/right = left + home.shell_template.width - 1
	var/top = bottom + home.shell_template.height - 1
	var/turned = (rotation % 180) != 0
	var/footprint_width = turned ? 13 : 16
	var/footprint_height = turned ? 16 : 13
	switch(rotation)
		if(0)
			return locate(left, top + 4, shell_corner.z)
		if(90)
			return locate(right + 4, bottom, shell_corner.z)
		if(180)
			return locate(left, bottom - 4 - footprint_height, shell_corner.z)
		if(270)
			return locate(left - 4 - footprint_width, bottom, shell_corner.z)
	return null

/**
 * Stamps a cargo dock beside the claim's shell, trying each rotation's side in turn, without
 * going through the console. Returns the placed upgrade, or the last placement error, which
 * names the first tile that refused and what stood on it.
 */
/datum/unit_test/proc/place_test_cargo_dock(obj/structure/overmap/dynamic/player_outpost/home, list/rotations = list(0, 90, 180, 270), mob/user)
	var/datum/outpost_upgrade/cargo_dock/blueprint = home.outpost_upgrades["cargo_dock"]
	if(!blueprint)
		blueprint = new(home)
		home.outpost_upgrades["cargo_dock"] = blueprint
	var/error = "No side of the shell to try."
	for(var/rotation in rotations)
		var/turf/corner = cargo_dock_test_corner(home, rotation)
		if(!corner)
			continue
		error = home.place_outpost_upgrade(blueprint, corner, rotation, user)
		if(!error)
			return blueprint
		error = "[error] [cargo_dock_blocker(home, blueprint, corner, rotation)]"
	return error

/**
 * The first tile of a cargo dock footprint that refuses placement, and why. Placement here has
 * failed rarely and at random rotations with "Position obstructed." (never reproduced in 168
 * isolated placements), so a refusal reports what was in the way.
 */
/datum/unit_test/proc/cargo_dock_blocker(obj/structure/overmap/dynamic/player_outpost/home, datum/outpost_upgrade/blueprint, turf/corner, rotation)
	var/list/footprint = blueprint.footprint_at(corner, rotation)
	if(!footprint)
		return "(no footprint at [rotation] degrees)"
	var/list/protected = home.upgrade_protected_rects(corner.z)
	for(var/turf/tile as anything in footprint["turfs"])
		if(home.is_upgrade_turf_clear(tile, protected))
			continue
		var/list/why = list()
		if(!home.is_turf_buildable(tile))
			why += "outside the build area"
		if(isclosedturf(tile))
			why += "[tile.type]"
		if(home.is_upgrade_ground_reserved(tile, protected))
			why += "reserved ground"
		for(var/atom/movable/thing as anything in tile)
			if(thing.density || thing.anchored || isliving(thing))
				why += "[thing] ([thing.type])"
		return "(at [rotation] degrees, [tile.x],[tile.y]: [jointext(why, ", ")])"
	return "(at [rotation] degrees, every tile is clear now)"

/// Fresh rooms trade air for a while. Let it settle before the claim is torn down under SSair.
/datum/unit_test/proc/settle_cargo_dock_air(list/room_turfs)
	var/settle_until = world.time + 30 SECONDS
	while(world.time < settle_until)
		var/busy = FALSE
		for(var/turf/open/room_turf in room_turfs)
			if(room_turf.excited)
				busy = TRUE
				break
		if(!busy)
			return
		sleep(1 SECONDS)

/// settle_cargo_dock_air() for the claim's placed cargo dock, if it has one
/datum/unit_test/proc/settle_test_cargo_dock(obj/structure/overmap/dynamic/player_outpost/home)
	var/datum/outpost_upgrade/cargo_dock/dock = home?.outpost_upgrades["cargo_dock"]
	var/list/bounds = dock?.footprint_bounds
	if(bounds)
		settle_cargo_dock_air(block(bounds[1], bounds[2], bounds[5], bounds[3], bounds[4], bounds[5]))

// ===== CATALOG AND PURCHASE =====

/datum/unit_test/voidcrew_outpost_cargo_dock_purchase
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_cargo_dock_purchase/Run()
	// Founding used to load a hangar-sized freight berth into its own turf reservation.
	var/list/reservations_before = LAZYCOPY(SSmapping.turf_reservations)
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("cargodockowner")
	TEST_ASSERT_NOTNULL(home, "The cargo dock test outpost did not load")
	TEST_ASSERT(home.home_bundle_installed, "Founding did not install the cargo console, bank and pod")
	var/datum/map_template/outpost_hangar/hangar = allocate(/datum/map_template/outpost_hangar)
	for(var/datum/turf_reservation/reservation as anything in SSmapping.turf_reservations)
		if(reservation in reservations_before)
			continue
		TEST_ASSERT(reservation.width != hangar.width || reservation.height != hangar.height, "Founding reserved a [reservation.width]x[reservation.height] freight berth")

	// The cargo console refuses to order until a dock is placed.
	var/obj/machinery/computer/voidcrew_cargo/cargo_console
	for(var/obj/machinery/computer/voidcrew_cargo/terminal as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/computer/voidcrew_cargo))
		if(get_outpost_from_atom(terminal) == home)
			cargo_console = terminal
			break
	TEST_ASSERT_NOTNULL(cargo_console, "The small shell has no cargo console")
	var/no_dock = "No cargo dock"
	TEST_ASSERT_EQUAL(cargo_console.get_shuttle_error_message(), no_dock, "The cargo console did not ask for a cargo dock")
	TEST_ASSERT(!cargo_console.can_call_cargo_shuttle(), "The cargo console could order with no cargo dock")
	TEST_ASSERT_EQUAL(home.freight.call_shuttle(), no_dock, "Freight was dispatched with no cargo dock")

	var/turf/console_turf = get_turf(home.management_console)
	var/mob/living/carbon/human/owner = make_player(console_turf, "cargodockowner")
	var/datum/player_outpost_management_ui/management_test/panel = upgrade_test_panel(home, owner)

	var/list/dock_entry
	for(var/list/entry as anything in panel.ui_static_data(owner)["upgrade_catalog"])
		if(entry["id"] == "cargo_dock")
			dock_entry = entry
	TEST_ASSERT_NOTNULL(dock_entry, "The cargo dock is missing from the upgrade catalog")
	TEST_ASSERT_EQUAL(dock_entry["price"], 0, "The cargo dock is not free")
	var/datum/outpost_upgrade/dock_prototype = GLOB.outpost_upgrade_catalog["cargo_dock"]
	var/datum/map_template/dock_template = dock_prototype.get_template(style = home.outpost_style)
	TEST_ASSERT_EQUAL(dock_entry["width"], dock_template.width, "The cargo dock's catalog width is not its map's")
	TEST_ASSERT_EQUAL(dock_entry["height"], dock_template.height, "The cargo dock's catalog height is not its map's")
	TEST_ASSERT_EQUAL(dock_prototype.entrance_side, SOUTH, "The cargo dock's entrance edge is wrong")
	TEST_ASSERT(dock_entry["preview"] && dock_entry["preview"] == dock_prototype.preview_asset(home.outpost_style), "The cargo dock's preview is missing")

	// Free, but still bought through the normal path: an empty treasury is enough, once.
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 0, "The test treasury did not start empty")
	TEST_ASSERT_NULL(home.upgrade_purchase_denial(owner, "cargo_dock"), "An empty treasury could not take the free cargo dock")
	act(panel, owner, "buy_upgrade", null, list("id" = "cargo_dock"))
	TEST_ASSERT_NULL(panel.upgrade_error, "Buying the cargo dock reported an error")
	var/datum/outpost_upgrade/cargo_dock/blueprint = home.outpost_upgrades["cargo_dock"]
	TEST_ASSERT(istype(blueprint), "Buying left no cargo dock blueprint")
	TEST_ASSERT_EQUAL(blueprint.paid, 0, "The free cargo dock recorded a payment")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 0, "The free cargo dock changed the treasury")
	TEST_ASSERT_EQUAL(home.buy_outpost_upgrade(owner, "cargo_dock"), "Blueprint already bought.", "A second cargo dock could be bought")
	TEST_ASSERT_EQUAL(home.freight.availability_error(), no_dock, "An unplaced blueprint counted as a cargo dock")

	act(panel, owner, "cancel_upgrade", null, list("id" = "cargo_dock"))
	TEST_ASSERT_NULL(panel.upgrade_error, "Cancelling the free cargo dock reported an error")
	TEST_ASSERT_NULL(home.outpost_upgrades["cargo_dock"], "Cancelling left the cargo dock blueprint")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 0, "Cancelling the free cargo dock changed the treasury")

	act(panel, owner, "buy_upgrade", null, list("id" = "cargo_dock"))
	blueprint = home.outpost_upgrades["cargo_dock"]
	TEST_ASSERT(istype(blueprint), "The cargo dock could not be bought again after cancelling")
	var/result = place_test_cargo_dock(home, list(0), owner)
	TEST_ASSERT_EQUAL(result, blueprint, "The bought cargo dock could not be placed: [result]")
	TEST_ASSERT_NULL(cargo_console.get_shuttle_error_message(), "The cargo console still refuses with a placed cargo dock")
	TEST_ASSERT_EQUAL(home.buy_outpost_upgrade(owner, "cargo_dock"), "Already installed.", "A second cargo dock could be bought after placing one")
	settle_test_cargo_dock(home)

// ===== THE PAD AT EVERY ROTATION =====

/datum/unit_test/voidcrew_outpost_cargo_dock_placement
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_cargo_dock_placement/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("cargodockplacer")
	TEST_ASSERT_NOTNULL(home, "The cargo dock placement outpost did not load")
	var/mob/living/carbon/human/owner = make_player(get_turf(home.management_console), "cargodockplacer")
	var/datum/player_outpost_management_ui/management_test/panel = upgrade_test_panel(home, owner)
	var/z = home.upgrade_level_z()
	var/list/room_turfs = list()
	var/list/rotations = list(0, 90, 180, 270)
	for(var/rotation in rotations)
		var/datum/outpost_upgrade/cargo_dock/blueprint = new(home)
		home.outpost_upgrades["cargo_dock"] = blueprint
		var/turf/bottom_left = cargo_dock_test_corner(home, rotation)
		TEST_ASSERT_NOTNULL(bottom_left, "No test spot at [rotation] degrees")
		var/list/footprint = blueprint.footprint_at(bottom_left, rotation)
		TEST_ASSERT_NOTNULL(footprint, "No footprint at [rotation] degrees")
		var/turf/top_right = footprint["top_right"]
		for(var/turf/tile as anything in footprint["turfs"])
			TEST_ASSERT(home.is_upgrade_turf_clear(tile), "Test ground at [tile.x],[tile.y] was not clear at [rotation] degrees")
		var/mapping_log_count = length(GLOB.unit_test_mapping_logs)

		if(rotation == 90)
			act(panel, owner, "place_upgrade", null, list("id" = "cargo_dock", "x" = bottom_left.x, "y" = bottom_left.y, "rotation" = rotation))
			TEST_ASSERT_NULL(panel.upgrade_error, "The placement map's Build failed at [rotation] degrees")
		else
			TEST_ASSERT_NULL(home.place_outpost_upgrade(blueprint, bottom_left, rotation, owner), "The cargo dock was not placed at [rotation] degrees")
		TEST_ASSERT(blueprint.installed, "Placement did not install the cargo dock at [rotation] degrees")
		if(length(GLOB.unit_test_mapping_logs) > mapping_log_count)
			TEST_FAIL("Placing the cargo dock at [rotation] degrees logged mapping errors: [jointext(GLOB.unit_test_mapping_logs.Copy(mapping_log_count + 1), "; ")]")
			return
		var/area/voidcrew/player_outpost/cargo_dock/dock_area = blueprint.installed_area
		TEST_ASSERT(istype(dock_area), "No cargo dock area was recorded at [rotation] degrees")

		// The port: where the map put it, turned with the room, and the ferry's size.
		var/obj/docking_port/stationary/outpost_cargo_dock/pad = blueprint.pad
		TEST_ASSERT_NOTNULL(pad, "The placed cargo dock found no landing pad port at [rotation] degrees")
		TEST_ASSERT_EQUAL(home.cargo_dock_port(), pad, "The claim does not know its cargo dock at [rotation] degrees")
		TEST_ASSERT(blueprint.contains_turf(get_turf(pad)), "The pad port is outside the room at [rotation] degrees")
		TEST_ASSERT_EQUAL(pad.dir, angle2dir(rotation), "The pad port was not turned with the room at [rotation] degrees")
		TEST_ASSERT_EQUAL(pad.width, 12, "The pad is the wrong width at [rotation] degrees")
		TEST_ASSERT_EQUAL(pad.height, 7, "The pad is the wrong height at [rotation] degrees")
		TEST_ASSERT_EQUAL(pad.dwidth, 5, "The pad port is off-centre across the pad at [rotation] degrees")
		TEST_ASSERT_EQUAL(pad.dheight, 0, "The pad port is not on the pad's edge at [rotation] degrees")
		var/list/rect = cargo_dock_rect(pad)
		TEST_ASSERT_NULL(pad.pad_obstruction(), "Something stands on the landing pad at [rotation] degrees")
		TEST_ASSERT(rect[1] > bottom_left.x && rect[2] > bottom_left.y && rect[3] < top_right.x && rect[4] < top_right.y, "The landing rectangle reaches the room's walls at [rotation] degrees")
		// The ferry's airlocks sit on the port's row, so that row must face the entrance.
		TEST_ASSERT_EQUAL(REVERSE_DIR(pad.dir), footprint["entrance_dir"], "The pad's airlock side does not face the entrance at [rotation] degrees")
		var/turf/apron = get_step(pad, REVERSE_DIR(pad.dir))
		TEST_ASSERT(isopenturf(apron) && apron.loc == dock_area, "There is no deck outside the ferry's airlocks at [rotation] degrees")
		for(var/turf/pad_tile as anything in block(rect[1], rect[2], z, rect[3], rect[4], z))
			TEST_ASSERT(istype(pad_tile, /turf/open/floor), "Pad tile [pad_tile.x],[pad_tile.y] is not floor at [rotation] degrees")
			TEST_ASSERT_EQUAL(pad_tile.loc, dock_area, "Pad tile [pad_tile.x],[pad_tile.y] is not in the dock's area at [rotation] degrees")
			for(var/atom/movable/thing as anything in pad_tile)
				if(thing == pad || ismob(thing) || iseffect(thing))
					continue
				TEST_FAIL("[thing.type] stands on pad tile [pad_tile.x],[pad_tile.y] at [rotation] degrees")
				return
		// Other upgrades keep off the pad.
		TEST_ASSERT(!home.is_upgrade_turf_clear(locate(rect[1] + 3, rect[2] + 3, z)), "Another upgrade could be placed on the pad at [rotation] degrees")

		// Power and the way in.
		var/list/apcs = list()
		for(var/turf/tile as anything in footprint["turfs"])
			TEST_ASSERT_EQUAL(tile.loc, dock_area, "Footprint tile [tile.x],[tile.y] is not in the dock's area at [rotation] degrees")
			for(var/obj/machinery/power/apc/apc in tile)
				apcs += apc
		TEST_ASSERT_EQUAL(length(apcs), 1, "The cargo dock should have exactly one APC at [rotation] degrees")
		var/obj/machinery/power/apc/apc = apcs[1]
		TEST_ASSERT_EQUAL(dock_area.apc, apc, "The dock's area does not know its APC at [rotation] degrees")
		TEST_ASSERT(iswallturf(get_step(apc, apc.dir)), "The turned APC is not against a wall at [rotation] degrees")
		// The way in can open onto vacuum or a planet: a tiny fan under every door out holds the air.
		var/list/doors_out = upgrade_exterior_doors(footprint["turfs"])
		TEST_ASSERT_EQUAL(length(doors_out[1]), 1, "The cargo dock should have exactly one door out at [rotation] degrees")
		var/obj/machinery/door/airlock/entrance = doors_out[1][1]
		TEST_ASSERT(get_turf(entrance) in footprint["entrance"], "The airlock is not on the entrance edge at [rotation] degrees")
		var/list/unfanned = doors_out[2]
		TEST_ASSERT(!length(unfanned), "[length(unfanned)] door(s) out of the cargo dock have no tiny fan at [rotation] degrees")

		// One dock per claim: forget this one so the next rotation can be placed.
		room_turfs += footprint["turfs"]
		home.outpost_upgrades -= "cargo_dock"
		qdel(blueprint)
		TEST_ASSERT(QDELETED(pad), "Forgetting the cargo dock left its pad port registered at [rotation] degrees")
		TEST_ASSERT_NULL(home.cargo_dock_port(), "The claim kept a forgotten cargo dock at [rotation] degrees")
	settle_cargo_dock_air(room_turfs)

// ===== FREIGHT LANDS ON THE PAD =====

/datum/unit_test/voidcrew_launch_cargo_fixture/outpost_cargo_dock_delivery
	var/obj/structure/overmap/dynamic/player_outpost/test_home
	var/list/saved_elevator_panels

/datum/unit_test/voidcrew_launch_cargo_fixture/outpost_cargo_dock_delivery/Destroy()
	if(test_home && saved_elevator_panels)
		test_home.lobby_panels = saved_elevator_panels
	test_home = null
	saved_elevator_panels = null
	return ..()

/datum/unit_test/voidcrew_launch_cargo_fixture/outpost_cargo_dock_delivery/Run()
	save_economy()
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(/obj/structure/overmap/dynamic/player_outpost)
	test_home = home
	home.shell_template = allocate(/datum/map_template/player_outpost/test_fixture)
	home.founder_ckey = "cargodockdelivery"
	TEST_ASSERT(home.load_level(), "The cargo dock delivery outpost did not load")
	var/datum/voidcrew_cargo_shuttle/outpost/ferry = home.freight
	TEST_ASSERT_NOTNULL(ferry, "The claim has no freight service")
	var/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/builder = home.construction_console
	TEST_ASSERT_NOTNULL(builder, "The small shell has no construction console")
	// Freight must not need the hangar elevator at all.
	saved_elevator_panels = home.lobby_panels
	home.lobby_panels = list()
	TEST_ASSERT(!home.has_hangar_elevator(), "The claim still has a working elevator")

	var/list/room_turfs = list()
	var/list/rotations = list(0, 90, 180, 270)
	for(var/rotation in rotations)
		var/result = place_test_cargo_dock(home, list(rotation))
		TEST_ASSERT(istype(result, /datum/outpost_upgrade/cargo_dock), "The cargo dock could not be placed at [rotation] degrees: [result]")
		var/datum/outpost_upgrade/cargo_dock/dock = result
		var/obj/docking_port/stationary/outpost_cargo_dock/pad = dock.pad
		TEST_ASSERT_NOTNULL(pad, "The cargo dock has no pad at [rotation] degrees")
		var/list/pad_rect = cargo_dock_rect(pad)
		var/list/pad_turfs = block(pad_rect[1], pad_rect[2], pad.z, pad_rect[3], pad_rect[4], pad.z)
		var/list/pad_types = list()
		var/list/pad_depths = list()
		for(var/turf/pad_tile as anything in pad_turfs)
			pad_types[pad_tile] = pad_tile.type
			pad_depths[pad_tile] = pad_tile.count_baseturfs()
		var/entrance_side = REVERSE_DIR(pad.dir)

		home.treasury.account_balance = 10000
		var/datum/supply_pack/voidcrew_outpost_cancel_during_generation/pack = new
		var/datum/supply_order/order = new(pack)
		order.manifest_can_fail = FALSE
		home.cargo_cart += order
		TEST_ASSERT_NULL(ferry.call_shuttle(), "Freight was not dispatched to the cargo dock at [rotation] degrees")
		deltimer(ferry.warmup_timer)
		TEST_ASSERT(ferry.complete_arrival(), "Freight did not land on the cargo dock at [rotation] degrees: [ferry.last_error]")

		// Docked on the pad, on the main level, lined up with the painted rectangle.
		var/obj/docking_port/mobile/ferry_port = ferry.shuttle_port
		TEST_ASSERT_NOTNULL(ferry_port, "The ferry vanished on arrival at [rotation] degrees")
		TEST_ASSERT_EQUAL(ferry_port.get_docked(), pad, "The ferry is not docked on the pad at [rotation] degrees")
		TEST_ASSERT_EQUAL(ferry_port.z, home.upgrade_level_z(), "The ferry is not on the claim's main level at [rotation] degrees")
		TEST_ASSERT_EQUAL(ferry_port.dir, pad.dir, "The ferry landed turned against the pad at [rotation] degrees")
		var/list/ferry_rect = cargo_dock_rect(ferry_port)
		for(var/index in 1 to 4)
			TEST_ASSERT_EQUAL(ferry_rect[index], pad_rect[index], "The ferry ([ferry_rect.Join(",")]) does not cover the pad ([pad_rect.Join(",")]) at [rotation] degrees")
		// Its airlocks open onto the apron, toward the room's entrance.
		var/airlocks = 0
		for(var/area/ferry_area as anything in ferry_port.shuttle_areas)
			for(var/turf/ferry_turf as anything in ferry_area.get_turfs_by_zlevel(pad.z))
				for(var/obj/machinery/door/airlock/airlock in ferry_turf)
					airlocks++
					var/turf/outside = get_step(airlock, entrance_side)
					TEST_ASSERT_EQUAL(outside.loc, dock.installed_area, "A ferry airlock at [airlock.x],[airlock.y] does not open onto the apron at [rotation] degrees")
		TEST_ASSERT_EQUAL(airlocks, 2, "The docked ferry has [airlocks] airlocks at [rotation] degrees")
		// The order was unloaded aboard, on the pad.
		var/obj/structure/closet/crate/crate = pack.generated_crate
		TEST_ASSERT(!QDELETED(crate), "The order was not delivered at [rotation] degrees")
		TEST_ASSERT(ferry_port.is_in_shuttle_bounds(crate), "The delivered crate is not aboard the docked ferry at [rotation] degrees")
		TEST_ASSERT(!(order in home.cargo_cart), "The delivered order stayed in the cart at [rotation] degrees")
		// Construction keeps off the docked ferry, and only the ferry.
		TEST_ASSERT(!builder.can_build_at(get_turf(crate)), "Construction could build on the docked ferry at [rotation] degrees")
		TEST_ASSERT(builder.can_build_at(get_step(get_step(pad, entrance_side), entrance_side)), "The docked ferry blocked construction on the apron at [rotation] degrees")

		// Departure takes the ferry off and leaves the pad as it was.
		var/list/ferry_areas = ferry_port.shuttle_areas.Copy()
		TEST_ASSERT(length(ferry_areas), "The docked ferry has no areas at [rotation] degrees")
		TEST_ASSERT(ferry.send_shuttle(), "The ferry could not be sent away at [rotation] degrees")
		deltimer(ferry.warmup_timer)
		TEST_ASSERT(ferry.complete_departure(), "The ferry could not depart at [rotation] degrees: [ferry.last_error]")
		TEST_ASSERT_NULL(ferry.shuttle_port, "The departed ferry left its port behind at [rotation] degrees")
		// Each delivery loads the ferry with areas of its own; departing deletes them, or one leaks per delivery.
		for(var/area/ferry_area as anything in ferry_areas)
			TEST_ASSERT(QDELETED(ferry_area), "The departed ferry's [ferry_area.type] was not deleted at [rotation] degrees")
			TEST_ASSERT(!(ferry_area in GLOB.areas), "The departed ferry's area is still listed at [rotation] degrees")
			for(var/level_key in SSmapping.areas_in_z)
				TEST_ASSERT(!(ferry_area in SSmapping.areas_in_z[level_key]), "SSmapping.areas_in_z still holds the departed ferry's area on z [level_key] at [rotation] degrees")
		for(var/turf/pad_tile as anything in pad_turfs)
			TEST_ASSERT_EQUAL(pad_tile.loc, dock.installed_area, "Pad tile [pad_tile.x],[pad_tile.y] did not return to the dock's area at [rotation] degrees")
			TEST_ASSERT_EQUAL(pad_tile.type, pad_types[pad_tile], "Pad tile [pad_tile.x],[pad_tile.y] is [pad_tile.type] after departure at [rotation] degrees")
			TEST_ASSERT_EQUAL(pad_tile.count_baseturfs(), pad_depths[pad_tile], "Pad tile [pad_tile.x],[pad_tile.y] kept the ferry's baseturfs at [rotation] degrees")
		TEST_ASSERT(builder.can_build_at(locate(pad_rect[1] + 3, pad_rect[2] + 3, pad.z)), "The empty pad still refused construction at [rotation] degrees")
		TEST_ASSERT_NULL(ferry.availability_error(), "The cargo dock could not take another delivery at [rotation] degrees")

		var/list/bounds = dock.footprint_bounds
		room_turfs += block(bounds[1], bounds[2], bounds[5], bounds[3], bounds[4], bounds[5])
		home.outpost_upgrades -= "cargo_dock"
		qdel(dock)

	home.lobby_panels = saved_elevator_panels
	saved_elevator_panels = null
	settle_cargo_dock_air(room_turfs)

// ===== THE FERRY CRUSHES WHAT IS LEFT ON THE PAD =====

/// Freight is dispatched and landed by hand here, so the real timers never fire mid-test.
/datum/unit_test/voidcrew_launch_cargo_fixture/outpost_cargo_dock_delivery/obstruction

/datum/unit_test/voidcrew_launch_cargo_fixture/outpost_cargo_dock_delivery/obstruction/Run()
	save_economy()
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(/obj/structure/overmap/dynamic/player_outpost)
	test_home = home
	home.shell_template = allocate(/datum/map_template/player_outpost/test_fixture)
	home.founder_ckey = "cargodockobstruction"
	TEST_ASSERT(home.load_level(), "The cargo pad crush outpost did not load")
	var/result = place_test_cargo_dock(home, list(0))
	TEST_ASSERT(istype(result, /datum/outpost_upgrade/cargo_dock), "The cargo dock could not be placed: [result]")
	var/datum/outpost_upgrade/cargo_dock/dock = result
	var/obj/docking_port/stationary/outpost_cargo_dock/pad = dock.pad
	TEST_ASSERT_NOTNULL(pad, "The cargo dock has no pad")
	var/datum/voidcrew_cargo_shuttle/outpost/ferry = home.freight
	var/list/rect = cargo_dock_rect(pad)
	TEST_ASSERT_NULL(pad.pad_obstruction(), "The freshly placed pad already counts as obstructed")

	home.treasury.account_balance = 10000
	var/datum/supply_pack/voidcrew_outpost_cancel_during_generation/pack = new
	var/datum/supply_order/order = new(pack)
	order.manifest_can_fail = FALSE
	home.cargo_cart += order
	var/price = order.get_final_cost()

	// Someone who stayed on the pad, a bolted machine and a loose item with some grime
	var/mob/living/carbon/human/consistent/bystander = allocate(/mob/living/carbon/human/consistent, locate(rect[1] + 5, rect[2] + 3, pad.z))
	var/obj/machinery/recharger/machine = allocate(/obj/machinery/recharger, locate(rect[1] + 3, rect[2] + 3, pad.z))
	TEST_ASSERT(machine.anchored, "The recharger fixture is not anchored")
	var/obj/item/crowbar/loose_item = allocate(/obj/item/crowbar, locate(rect[1] + 8, rect[2] + 3, pad.z))
	allocate(/obj/effect/decal/cleanable/dirt, loose_item.loc)
	TEST_ASSERT_NOTNULL(pad.pad_obstruction(), "Someone on the pad did not count as something the ferry would crush")
	TEST_ASSERT_NULL(ferry.call_shuttle(), "Freight was not dispatched to a pad with someone on it")
	// The pad's alarm is due 10 seconds before the landing.
	TEST_ASSERT_NOTNULL(ferry.landing_warning_timer, "Dispatch set no landing alarm")
	TEST_ASSERT_EQUAL(timeleft(ferry.warmup_timer) - timeleft(ferry.landing_warning_timer), 10 SECONDS, "The landing alarm is not due 10 seconds before the landing")
	TEST_ASSERT(!ferry.warn_landing(ferry.delivery_generation + 1), "An alarm for another delivery went off")
	TEST_ASSERT(ferry.warn_landing(ferry.delivery_generation), "The landing alarm did not reach the pad")
	TEST_ASSERT(length(ferry.shuttle_port.ripples), "The landing alarm did not mark the ferry's footprint")
	deltimer(ferry.warmup_timer)
	TEST_ASSERT(ferry.complete_arrival(), "Freight did not land on an occupied pad: [ferry.last_error]")
	TEST_ASSERT_EQUAL(ferry.shuttle_port.get_docked(), pad, "The ferry is not docked on the pad")
	TEST_ASSERT_NULL(ferry.landing_warning_timer, "The landing left its alarm armed")
	TEST_ASSERT(!length(ferry.shuttle_port.ripples), "The landing left its warning ripples behind")
	TEST_ASSERT(QDELETED(bystander) || bystander.stat == DEAD, "The ferry landed on someone and left them alive")
	TEST_ASSERT(QDELETED(machine), "The ferry landed on a bolted machine and left it standing")
	TEST_ASSERT(!QDELETED(loose_item), "The landing destroyed a loose item on the pad")
	TEST_ASSERT(!(order in home.cargo_cart), "The landed order stayed in the cart")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 10000 - price, "The landed order was not charged once")

	// The ferry will not leave with a living brain aboard, so the remains come off first
	for(var/area/ferry_area as anything in ferry.shuttle_port.shuttle_areas)
		for(var/turf/deck in ferry_area)
			for(var/obj/item/remains in deck)
				if(length(remains.get_all_contents_type(/mob/living)))
					qdel(remains)
	TEST_ASSERT(ferry.send_shuttle(), "The ferry could not be sent away")
	deltimer(ferry.warmup_timer)
	TEST_ASSERT(ferry.complete_departure(), "The ferry could not depart: [ferry.last_error]")
	settle_test_cargo_dock(home)

// ===== THE DOCK'S AREA IS RELEASED =====

/**
 * SSmapping.areas_in_z used to keep a claim's areas after it was torn down. A template load
 * registers every area it touched, then each new area registered itself again in Initialize(), and
 * /area/Destroy() removes one entry, so the second kept the area from ever being collected (the
 * shell's area hard deleted, and so did every deleted upgrade's). Registering is idempotent now.
 */
/datum/unit_test/voidcrew_outpost_cargo_dock_area_release
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_cargo_dock_area_release/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("cargodockrelease")
	TEST_ASSERT_NOTNULL(home, "The cargo dock release outpost did not load")
	var/result = place_test_cargo_dock(home)
	TEST_ASSERT(istype(result, /datum/outpost_upgrade/cargo_dock), "The cargo dock could not be placed: [result]")
	var/datum/outpost_upgrade/cargo_dock/dock = result
	var/area/voidcrew/player_outpost/cargo_dock/dock_area = dock.installed_area
	TEST_ASSERT(istype(dock_area), "The placed cargo dock recorded no area")
	var/area/voidcrew/player_outpost/shell_area = home.outpost_area
	TEST_ASSERT(istype(shell_area), "The claim recorded no outpost area")
	var/z_key = "[dock.footprint_bounds[5]]"
	for(var/area/checked as anything in list(dock_area, shell_area))
		var/registrations = 0
		for(var/area/listed as anything in SSmapping.areas_in_z[z_key])
			if(listed == checked)
				registrations++
		TEST_ASSERT_EQUAL(registrations, 1, "[checked.type] is registered [registrations] times on its level")
	// No area anywhere is listed twice on one level.
	for(var/level_key in SSmapping.areas_in_z)
		var/list/level_areas = SSmapping.areas_in_z[level_key]
		TEST_ASSERT_EQUAL(length(level_areas), length(unique_list(level_areas)), "An area is registered twice on z [level_key]")
	settle_test_cargo_dock(home)

	qdel(home)
	var/deadline = world.time + 30 SECONDS
	UNTIL((QDELETED(dock_area) && QDELETED(shell_area)) || world.time > deadline)
	TEST_ASSERT(QDELETED(dock_area), "Tearing the claim down did not delete the cargo dock's area")
	TEST_ASSERT(QDELETED(shell_area), "Tearing the claim down did not delete the outpost's area")
	for(var/level_key in SSmapping.areas_in_z)
		TEST_ASSERT(!(dock_area in SSmapping.areas_in_z[level_key]), "SSmapping.areas_in_z still holds the deleted cargo dock area on z [level_key]")
		TEST_ASSERT(!(shell_area in SSmapping.areas_in_z[level_key]), "SSmapping.areas_in_z still holds the deleted outpost area on z [level_key]")
