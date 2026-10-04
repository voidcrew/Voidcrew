/**
 * Outpost upgrades: buying from the management console, the tiles a placement may cover, the
 * rotated template loader. The cargo dock is the example upgrade; its own tests are in
 * voidcrew_outpost_cargo_dock.dm.
 *
 * Voidcrew defines are not visible from test files, so prices appear as literals.
 */

/// Three by two, every tile different, with a sign hung on the one wall.
/datum/map_template/voidcrew_rotated_load_test
	name = "Rotated Load Test"
	mappath = "voidcrew/_maps/map_files/unit_tests/rotated_load_test.dmm"

/datum/unit_test/voidcrew_rotated_template_load
	var/datum/turf_reservation/reserved

/datum/unit_test/voidcrew_rotated_template_load/Destroy()
	QDEL_NULL(reserved)
	return ..()

/datum/unit_test/voidcrew_rotated_template_load/Run()
	var/datum/map_template/voidcrew_rotated_load_test/template = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT_EQUAL(template.width, 3, "The rotation test map has the wrong width")
	TEST_ASSERT_EQUAL(template.height, 2, "The rotation test map has the wrong height")
	reserved = SSmapping.request_turf_block_reservation(22, 6, 1)
	TEST_ASSERT_NOTNULL(reserved, "Could not reserve space for the rotation test")
	var/turf/origin = reserved.bottom_left_turfs[1]

	// Zero-based offsets from the rotated footprint's bottom-left, worked out by hand for each
	// clockwise rotation of:  y1: dark  wall  white
	//                         y0: plate sign  wood   (the sign hangs on the wall above it)
	var/list/expected = list(
		"0" = list(
			/turf/open/floor/plating = list(0, 0),
			/turf/closed/wall = list(1, 1),
			/turf/open/floor/iron/dark = list(0, 1),
			/turf/open/floor/iron/white = list(2, 1),
			/turf/open/floor/wood = list(2, 0),
			/obj/structure/sign = list(1, 0),
		),
		"90" = list(
			/turf/open/floor/plating = list(0, 2),
			/turf/closed/wall = list(1, 1),
			/turf/open/floor/iron/dark = list(1, 2),
			/turf/open/floor/iron/white = list(1, 0),
			/turf/open/floor/wood = list(0, 0),
			/obj/structure/sign = list(0, 1),
		),
		"180" = list(
			/turf/open/floor/plating = list(2, 1),
			/turf/closed/wall = list(1, 0),
			/turf/open/floor/iron/dark = list(2, 0),
			/turf/open/floor/iron/white = list(0, 0),
			/turf/open/floor/wood = list(0, 1),
			/obj/structure/sign = list(1, 1),
		),
		"270" = list(
			/turf/open/floor/plating = list(1, 0),
			/turf/closed/wall = list(0, 1),
			/turf/open/floor/iron/dark = list(0, 0),
			/turf/open/floor/iron/white = list(0, 2),
			/turf/open/floor/wood = list(1, 2),
			/obj/structure/sign = list(1, 1),
		),
	)
	var/list/sign_dirs = list("0" = NORTH, "90" = EAST, "180" = SOUTH, "270" = WEST)
	var/list/sign_offsets = list("0" = list(0, 32), "90" = list(32, 0), "180" = list(0, -32), "270" = list(-32, 0))

	var/list/rotations = list(0, 90, 180, 270)
	for(var/index in 1 to length(rotations))
		var/rotation = rotations[index]
		var/turf/bottom_left = locate(origin.x + 1 + (index - 1) * 5, origin.y + 1, origin.z)
		var/footprint_width = (rotation % 180) ? 2 : 3
		var/footprint_height = (rotation % 180) ? 3 : 2
		var/list/spots = expected["[rotation]"]
		var/list/old_areas = list()
		for(var/turf/ground as anything in block(bottom_left.x, bottom_left.y, bottom_left.z, bottom_left.x + footprint_width - 1, bottom_left.y + footprint_height - 1, bottom_left.z))
			old_areas[ground] = ground.loc

		// Something already on the ground keeps its own facing.
		var/list/wood_offset = spots[/turf/open/floor/wood]
		var/turf/wood_spot = locate(bottom_left.x + wood_offset[1], bottom_left.y + wood_offset[2], bottom_left.z)
		var/obj/item/wrench/bystander = allocate(__IMPLIED_TYPE__, wood_spot)
		bystander.setDir(NORTH)

		var/list/bounds = template.load_rotated(bottom_left, rotation)
		TEST_ASSERT_NOTNULL(bounds, "The rotated load failed at [rotation] degrees")
		TEST_ASSERT_EQUAL(bounds[MAP_MAXX] - bounds[MAP_MINX] + 1, footprint_width, "Wrong footprint width at [rotation] degrees")
		TEST_ASSERT_EQUAL(bounds[MAP_MAXY] - bounds[MAP_MINY] + 1, footprint_height, "Wrong footprint height at [rotation] degrees")
		TEST_ASSERT_EQUAL(bounds[MAP_MINX], bottom_left.x, "The footprint moved off its bottom-left corner at [rotation] degrees")
		TEST_ASSERT_EQUAL(bounds[MAP_MINY], bottom_left.y, "The footprint moved off its bottom-left corner at [rotation] degrees")

		for(var/turf_type in spots)
			if(!ispath(turf_type, /turf))
				continue
			var/list/offset = spots[turf_type]
			var/turf/tile = locate(bottom_left.x + offset[1], bottom_left.y + offset[2], bottom_left.z)
			TEST_ASSERT_EQUAL(tile.type, turf_type, "At [rotation] degrees, [turf_type] should be at +[offset[1]],+[offset[2]]")
			// template_noop keeps the ground's area; built-over space moves to nearstation as with load()
			var/area/old_area = old_areas[tile]
			var/area/new_area = tile.loc
			var/promoted = istype(old_area, /area/space) && istype(new_area, /area/space/nearstation)
			TEST_ASSERT(new_area == old_area || promoted, "A template_noop area replaced the ground's area at [rotation] degrees: [new_area.type], was [old_area.type]")

		var/list/sign_offset = spots[/obj/structure/sign]
		var/turf/sign_turf = locate(bottom_left.x + sign_offset[1], bottom_left.y + sign_offset[2], bottom_left.z)
		var/obj/structure/sign/sign = locate() in sign_turf
		TEST_ASSERT_NOTNULL(sign, "The sign is not at +[sign_offset[1]],+[sign_offset[2]] at [rotation] degrees")
		TEST_ASSERT_EQUAL(sign.dir, sign_dirs["[rotation]"], "The sign faces the wrong way at [rotation] degrees")
		var/list/pixels = sign_offsets["[rotation]"]
		TEST_ASSERT_EQUAL(sign.pixel_x, pixels[1], "The sign's x offset was not turned at [rotation] degrees")
		TEST_ASSERT_EQUAL(sign.pixel_y, pixels[2], "The sign's y offset was not turned at [rotation] degrees")
		TEST_ASSERT(iswallturf(get_step(sign, sign.dir)), "The turned sign does not face its wall at [rotation] degrees")
		TEST_ASSERT(length(sign.GetComponents(/datum/component/wall_mounted)), "The sign initialized before it was turned and found no wall at [rotation] degrees")

		TEST_ASSERT_EQUAL(bystander.dir, NORTH, "The load turned an object that was already on the ground at [rotation] degrees")
		TEST_ASSERT_EQUAL(bystander.loc, wood_spot, "The load moved an object that was already on the ground at [rotation] degrees")
		TEST_ASSERT(isspaceturf(locate(bottom_left.x + footprint_width, bottom_left.y, bottom_left.z)), "The load spilled past its footprint at [rotation] degrees")
		TEST_ASSERT(isspaceturf(locate(bottom_left.x, bottom_left.y + footprint_height, bottom_left.z)), "The load spilled past its footprint at [rotation] degrees")

/// Upgrade tests run on a real claim, like the other outpost service tests.
/datum/unit_test/voidcrew_outpost_upgrade_purchase
	parent_type = /datum/unit_test/voidcrew_outpost_management
	/// The cargo dock's real price, put back after the test gives it one
	var/real_price

/datum/unit_test/voidcrew_outpost_upgrade_purchase/Destroy()
	var/datum/outpost_upgrade/prototype = GLOB.outpost_upgrade_catalog["cargo_dock"]
	if(prototype && !isnull(real_price))
		prototype.price = real_price
	return ..()

/// A loaded small-shell claim owned by `owner_key`, with a management console panel for that owner.
/datum/unit_test/voidcrew_outpost_management/proc/upgrade_test_claim(owner_key)
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(/obj/structure/overmap/dynamic/player_outpost)
	home.shell_template = allocate(/datum/map_template/player_outpost/test_fixture)
	home.founder_ckey = owner_key
	if(!home.load_level())
		return null
	return home

/datum/unit_test/voidcrew_outpost_management/proc/upgrade_test_panel(obj/structure/overmap/dynamic/player_outpost/home, mob/user)
	var/obj/machinery/computer/player_outpost_management/console = allocate(/obj/machinery/computer/player_outpost_management, get_turf(home.management_console))
	return allocate(/datum/player_outpost_management_ui/management_test, home, user, console)

/datum/unit_test/voidcrew_outpost_management/proc/upgrade_status(datum/player_outpost_management_ui/panel, mob/user, upgrade_id)
	var/list/data = panel.ui_data(user)
	for(var/list/entry as anything in data["upgrades"])
		if(entry["id"] == upgrade_id)
			return entry
	return null

/datum/unit_test/voidcrew_outpost_upgrade_purchase/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("upgradeowner")
	TEST_ASSERT_NOTNULL(home, "The upgrade test outpost did not load")
	var/turf/console_turf = get_turf(home.management_console)
	var/mob/living/carbon/human/owner = make_player(console_turf, "upgradeowner")
	var/mob/living/carbon/human/visitor = make_player(console_turf, "upgradevisitor")
	var/datum/player_outpost_management_ui/management_test/panel = upgrade_test_panel(home, owner)

	// The cargo dock is free; give it a price to exercise charging and refunds.
	var/datum/outpost_upgrade/prototype = GLOB.outpost_upgrade_catalog["cargo_dock"]
	TEST_ASSERT_NOTNULL(prototype, "The cargo dock is missing from the upgrade catalog")
	real_price = prototype.price
	prototype.price = 10000

	var/list/dock_entry
	var/list/static_data = panel.ui_static_data(owner)
	for(var/list/entry as anything in static_data["upgrade_catalog"])
		if(entry["id"] == "cargo_dock")
			dock_entry = entry
	TEST_ASSERT_NOTNULL(dock_entry, "The cargo dock is missing from the upgrade catalog")
	for(var/key in list("id", "name", "desc", "price", "width", "height", "preview"))
		TEST_ASSERT(key in dock_entry, "The catalog entry has no [key] for the Upgrades tab")
	TEST_ASSERT_EQUAL(dock_entry["price"], 10000, "The catalog price is wrong")
	var/datum/map_template/dock_template = prototype.get_template(style = home.outpost_style)
	TEST_ASSERT_EQUAL(dock_entry["width"], dock_template.width, "The cargo dock's catalog width is not its map's")
	TEST_ASSERT_EQUAL(dock_entry["height"], dock_template.height, "The cargo dock's catalog height is not its map's")
	TEST_ASSERT_EQUAL(prototype.entrance_side, SOUTH, "The cargo dock's entrance edge is wrong")
	TEST_ASSERT(dock_entry["preview"] && dock_entry["preview"] == prototype.preview_asset(home.outpost_style), "The cargo dock's preview is missing")
	TEST_ASSERT_NULL(static_data["upgrade_survey"], "The survey was sent without a placement map open")
	var/list/status = upgrade_status(panel, owner, "cargo_dock")
	for(var/key in list("id", "state", "denial", "manage_denial"))
		TEST_ASSERT(key in status, "The upgrade state has no [key] for the Upgrades tab")

	// Unfunded: refused with a reason, nothing charged, no blueprint.
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 0, "The test treasury did not start empty")
	TEST_ASSERT_EQUAL(status["denial"], "Insufficient outpost funds.", "An unfunded purchase gave no reason")
	act(panel, owner, "buy_upgrade", null, list("id" = "cargo_dock"))
	TEST_ASSERT_NULL(home.outpost_upgrades["cargo_dock"], "An unfunded purchase left a blueprint")
	TEST_ASSERT_EQUAL(panel.upgrade_error, "Insufficient outpost funds.", "An unfunded purchase showed no error")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 0, "An unfunded purchase changed the treasury")

	home.treasury.adjust_money(12500, "Upgrade test")
	TEST_ASSERT_EQUAL(home.upgrade_purchase_denial(visitor, "cargo_dock"), "Not authorized.", "A visitor was not refused")
	TEST_ASSERT_NOTNULL(home.buy_outpost_upgrade(visitor, "cargo_dock"), "A visitor bought an upgrade")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 12500, "A refused visitor purchase charged the treasury")
	TEST_ASSERT_EQUAL(home.buy_outpost_upgrade(owner, "not_an_upgrade"), "Unknown upgrade.", "An unknown upgrade was not refused")
	TEST_ASSERT_EQUAL(home.buy_outpost_upgrade(owner, 1), "Unknown upgrade.", "A numeric id reached the catalog by position")
	status = upgrade_status(panel, owner, "cargo_dock")
	TEST_ASSERT_EQUAL(status["state"], "available", "An unbought upgrade did not show as available")
	TEST_ASSERT_NULL(status["denial"], "A funded owner was refused")

	// Funded owner: exact debit, one unplaced blueprint.
	act(panel, owner, "buy_upgrade", null, list("id" = "cargo_dock"))
	TEST_ASSERT_NULL(panel.upgrade_error, "A funded purchase reported an error")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 2500, "The upgrade did not cost exactly its price")
	var/datum/outpost_upgrade/blueprint = home.outpost_upgrades["cargo_dock"]
	TEST_ASSERT(istype(blueprint, /datum/outpost_upgrade/cargo_dock), "The purchase left no cargo dock blueprint")
	TEST_ASSERT_EQUAL(blueprint.outpost, home, "The blueprint does not belong to the outpost")
	TEST_ASSERT_EQUAL(blueprint.paid, 10000, "The blueprint did not record what was paid")
	TEST_ASSERT(!blueprint.installed && !blueprint.placing, "A bought blueprint was already placed")
	var/list/blueprints = home.upgrade_blueprints()
	TEST_ASSERT_EQUAL(length(blueprints), 1, "The bought blueprint is not waiting to be placed")
	TEST_ASSERT_EQUAL(blueprints[1], blueprint, "The wrong blueprint is waiting to be placed")
	status = upgrade_status(panel, owner, "cargo_dock")
	TEST_ASSERT_EQUAL(status["state"], "ready", "A bought blueprint did not show as ready to place")
	TEST_ASSERT_EQUAL(status["denial"], "Blueprint already bought.", "A second purchase was offered")
	TEST_ASSERT_NULL(status["manage_denial"], "The owner could not place or cancel the blueprint")

	// A second purchase is refused while the first is unplaced, and charges nothing.
	home.treasury.adjust_money(20000, "Upgrade test")
	TEST_ASSERT_EQUAL(home.buy_outpost_upgrade(owner, "cargo_dock"), "Blueprint already bought.", "A second purchase was not refused")
	act(panel, owner, "buy_upgrade", null, list("id" = "cargo_dock"))
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 22500, "A refused second purchase charged the treasury")
	TEST_ASSERT_EQUAL(home.outpost_upgrades["cargo_dock"], blueprint, "A second purchase replaced the blueprint")

	// Cancelling refunds exactly what was paid and frees the slot; only management may do it.
	TEST_ASSERT_EQUAL(home.cancel_outpost_upgrade(visitor, "cargo_dock"), "Not authorized.", "A visitor cancelled the purchase")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 22500, "A refused cancel changed the treasury")
	act(panel, owner, "cancel_upgrade", null, list("id" = "cargo_dock"))
	TEST_ASSERT_NULL(panel.upgrade_error, "Cancelling the purchase reported an error")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 32500, "Cancelling did not refund exactly the price")
	TEST_ASSERT_NULL(home.outpost_upgrades["cargo_dock"], "Cancelling left the blueprint behind")
	TEST_ASSERT(QDELETED(blueprint), "The cancelled blueprint was not deleted")
	TEST_ASSERT_EQUAL(upgrade_status(panel, owner, "cargo_dock")["state"], "available", "A cancelled upgrade did not return to the catalog")
	TEST_ASSERT_EQUAL(home.cancel_outpost_upgrade(owner, "cargo_dock"), "No blueprint bought.", "A second cancel was accepted")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 32500, "A second cancel refunded again")

	// An installed upgrade cannot be bought again or refunded.
	TEST_ASSERT_NULL(home.buy_outpost_upgrade(owner, "cargo_dock"), "The upgrade could not be bought again after a refund")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 22500, "The second purchase did not cost exactly its price")
	blueprint = home.outpost_upgrades["cargo_dock"]
	blueprint.installed = TRUE
	TEST_ASSERT_EQUAL(home.buy_outpost_upgrade(owner, "cargo_dock"), "Already installed.", "An installed upgrade could be bought again")
	TEST_ASSERT_EQUAL(home.cancel_outpost_upgrade(owner, "cargo_dock"), "Already installed.", "An installed upgrade was refunded")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 22500, "Refusing an installed upgrade changed the treasury")

/datum/unit_test/voidcrew_outpost_upgrade_tiles
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_upgrade_tiles/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("tileowner")
	TEST_ASSERT_NOTNULL(home, "The tile test outpost did not load")
	var/z = home.upgrade_level_z()
	var/list/claim = home.build_bounds
	var/turf/open_ground = locate(claim[1] + 12, claim[4] - 12, z)
	TEST_ASSERT(home.is_upgrade_turf_clear(open_ground), "Open space inside the claim was refused")

	var/obj/structure/lattice/lattice = allocate(__IMPLIED_TYPE__, open_ground)
	var/obj/item/wrench/loose = allocate(__IMPLIED_TYPE__, open_ground)
	TEST_ASSERT(home.is_upgrade_turf_clear(open_ground), "A lattice or a loose item blocked an upgrade")
	qdel(lattice)
	qdel(loose)
	// Level teardown keeps landmarks, and deleted hulls leave their job starts behind.
	var/obj/effect/landmark/stray_start = allocate(/obj/effect/landmark/start, open_ground)
	TEST_ASSERT(home.is_upgrade_turf_clear(open_ground), "A stray landmark blocked an upgrade")
	qdel(stray_start)
	var/obj/structure/grille/grille = allocate(__IMPLIED_TYPE__, open_ground)
	TEST_ASSERT(!home.is_upgrade_turf_clear(open_ground), "An anchored structure did not block an upgrade")
	qdel(grille)
	TEST_ASSERT(home.is_upgrade_turf_clear(open_ground), "Clearing the tile did not free it")

	var/turf/wall_spot = locate(open_ground.x + 1, open_ground.y, z)
	wall_spot.ChangeTurf(/turf/closed/wall)
	TEST_ASSERT(!home.is_upgrade_turf_clear(wall_spot), "A wall accepted an upgrade")

	var/turf/mob_spot = locate(open_ground.x + 2, open_ground.y, z)
	allocate(/mob/living/carbon/human/consistent, mob_spot)
	TEST_ASSERT(!home.is_upgrade_turf_clear(mob_spot), "A living mob did not block an upgrade")
	TEST_ASSERT(home.is_upgrade_turf_clear(mob_spot, ignore_mobs = TRUE), "The survey's mob exemption did not apply")

	var/datum/outpost_zone/berth_ground = home.berth_zone(1)
	TEST_ASSERT_NOTNULL(berth_ground, "The test outpost has no berth zone")
	TEST_ASSERT(!home.is_upgrade_turf_clear(locate(berth_ground.low_x + 5, berth_ground.low_y + 5, berth_ground.z_value)), "Berth ground accepted an upgrade")
	TEST_ASSERT(!home.is_upgrade_turf_clear(home.arrival_turf), "The arrival point accepted an upgrade")
	if(length(home.lobby_alcove_turfs))
		TEST_ASSERT(!home.is_upgrade_turf_clear(home.lobby_alcove_turfs[1]), "The elevator alcove accepted an upgrade")
	TEST_ASSERT(!home.is_upgrade_turf_clear(run_loc_floor_bottom_left), "Ground outside the claim accepted an upgrade")

	// An installed room blocks upgrades and the hangar elevator alike, but only inside it.
	var/datum/outpost_upgrade/cargo_dock/placed = new(home)
	home.outpost_upgrades["cargo_dock"] = placed
	placed.installed = TRUE
	var/turf/room_corner = locate(open_ground.x + 5, open_ground.y - 6, z)
	placed.footprint_bounds = list(room_corner.x, room_corner.y, room_corner.x + 2, room_corner.y + 2, z)
	var/turf/inside = locate(room_corner.x + 1, room_corner.y + 1, z)
	var/turf/beside = locate(room_corner.x + 3, room_corner.y + 1, z)
	TEST_ASSERT(!home.is_upgrade_turf_clear(inside), "An upgrade could overlap an installed one")
	TEST_ASSERT(home.is_upgrade_turf_clear(beside), "Ground next to an installed upgrade was refused")
	var/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/builder = home.construction_console
	TEST_ASSERT_NOTNULL(builder, "The test shell has no construction console")
	TEST_ASSERT(!builder.is_elevator_turf_clear(inside), "The hangar elevator could be placed inside an installed upgrade")
	TEST_ASSERT(builder.is_elevator_turf_clear(beside), "The hangar elevator was refused next to an installed upgrade")

	// Distance: open ground far from the outpost is refused, and nothing is claimed.
	home.outpost_upgrades -= "cargo_dock"
	qdel(placed)
	var/datum/outpost_upgrade/cargo_dock/blueprint = new(home)
	home.outpost_upgrades["cargo_dock"] = blueprint
	var/turf/far_corner = locate(claim[1] + 10, claim[4] - 40, z)
	var/list/far_footprint = blueprint.footprint_at(far_corner, 0)
	for(var/turf/far_tile as anything in far_footprint["turfs"])
		TEST_ASSERT(home.is_upgrade_turf_clear(far_tile), "Test ground at [far_tile.x],[far_tile.y] was not clear")
	TEST_ASSERT(!home.upgrade_footprint_near_outpost(far_corner, far_footprint["top_right"]), "A footprint across the claim counted as near the outpost")
	TEST_ASSERT_EQUAL(home.place_outpost_upgrade(blueprint, far_corner, 0, null), "Too far from the outpost.", "A room far from the outpost was placed")
	TEST_ASSERT(!blueprint.installed && !blueprint.placing && !blueprint.footprint_bounds, "A refused placement claimed the blueprint")

	// Just inside and just outside the gap, east of the easternmost outpost ground.
	var/list/owned = home.outpost_owned_turfs()
	var/turf/east_ground
	for(var/turf/owned_turf as anything in owned)
		if(!east_ground || owned_turf.x > east_ground.x)
			east_ground = owned_turf
	var/turf/near_corner = locate(east_ground.x + 8, east_ground.y, z) // OUTPOST_UPGRADE_MAX_GAP
	TEST_ASSERT(home.upgrade_footprint_near_outpost(near_corner, locate(near_corner.x + 16, near_corner.y + 15, z)), "A room eight tiles from the outpost was too far")
	// Every tile of this one is at least nine columns east of all outpost ground.
	var/turf/gap_corner = locate(east_ground.x + 9, east_ground.y, z)
	TEST_ASSERT(!home.upgrade_footprint_near_outpost(gap_corner, locate(gap_corner.x + 16, gap_corner.y + 15, z)), "A room nine tiles from the outpost counted as near")

/datum/unit_test/voidcrew_outpost_upgrade_survey
	parent_type = /datum/unit_test/voidcrew_outpost_management

/// Cells where the survey string disagrees with is_upgrade_turf_clear() now, with what stands there.
/datum/unit_test/voidcrew_outpost_upgrade_survey/proc/survey_disagreements(obj/structure/overmap/dynamic/player_outpost/home, list/survey, z)
	var/list/found = list()
	var/list/protected_rects = home.upgrade_protected_rects(z)
	var/width = survey["width"]
	var/string_cells = survey["cells"]
	for(var/row in 0 to survey["height"] - 1)
		for(var/column in 0 to width - 1)
			var/turf/tile = locate(survey["x"] + column, survey["y"] + row, z)
			var/cell = copytext(string_cells, row * width + column + 1, row * width + column + 2)
			if((findtext("slf", cell) > 0) == home.is_upgrade_turf_clear(tile, protected_rects, TRUE))
				continue
			var/list/stuff = list()
			for(var/atom/movable/thing as anything in tile)
				stuff += "[thing.type]{a=[thing.anchored],d=[thing.density]}"
			var/list/ports = list()
			for(var/obj/docking_port/port in SSshuttle.stationary_docking_ports + SSshuttle.mobile_docking_ports)
				if(port.z == z)
					ports += "[port.type]@[port.x],[port.y] ([port.return_coords().Join(",")])"
			found += "cell [cell] at [tile.x],[tile.y] is now [home.upgrade_survey_class(tile, protected_rects)], turf [tile.type], reserved [home.is_upgrade_ground_reserved(tile, protected_rects)], contents [stuff.Join(" ")], ports on z [ports.Join("; ")]"
			if(length(found) >= 3)
				return found
	return found

/datum/unit_test/voidcrew_outpost_upgrade_survey/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("surveyowner")
	TEST_ASSERT_NOTNULL(home, "The survey test outpost did not load")
	var/mob/living/carbon/human/owner = make_player(get_turf(home.management_console), "surveyowner")
	var/datum/player_outpost_management_ui/management_test/panel = upgrade_test_panel(home, owner)
	var/z = home.upgrade_level_z()
	var/list/owned = home.outpost_owned_turfs()
	TEST_ASSERT(length(owned), "The small shell has no outpost ground")

	// Obstacles for the survey to see: a wall, a grille, and a mob it must leave out.
	var/list/claim = home.build_bounds
	var/turf/shell_corner = home.template_bottom_left
	var/turf/wall_spot = locate(shell_corner.x - 3, shell_corner.y, z)
	wall_spot.ChangeTurf(/turf/closed/wall)
	allocate(/obj/structure/grille, locate(shell_corner.x - 3, shell_corner.y + 1, z))
	var/turf/mob_spot = locate(shell_corner.x - 3, shell_corner.y + 2, z)
	allocate(/mob/living/carbon/human/consistent, mob_spot)

	var/list/survey = home.build_upgrade_survey()
	TEST_ASSERT_NOTNULL(survey, "The survey failed")
	var/width = survey["width"]
	var/height = survey["height"]
	var/string_cells = survey["cells"]
	var/string_near = survey["near"]
	TEST_ASSERT_EQUAL(length(string_cells), width * height, "The survey has the wrong number of cells")
	TEST_ASSERT_EQUAL(length(string_near), width * height, "The near mask has the wrong number of cells")
	TEST_ASSERT(survey["x"] >= claim[1] && survey["y"] >= claim[2] && survey["x"] + width - 1 <= claim[3] && survey["y"] + height - 1 <= claim[4], "The survey left the claim")
	for(var/turf/owned_turf as anything in owned)
		TEST_ASSERT(owned_turf.x >= survey["x"] && owned_turf.y >= survey["y"] && owned_turf.x < survey["x"] + width && owned_turf.y < survey["y"] + height, "The survey does not cover all outpost ground")

	// Every cell agrees with the placement rule, mobs aside. Something passing through while the
	// survey yields can change one tile, so a disagreement must survive a fresh survey to fail.
	var/list/disagreements = survey_disagreements(home, survey, z)
	if(length(disagreements))
		var/list/retry = home.build_upgrade_survey()
		var/list/still = survey_disagreements(home, retry, z)
		if(length(still))
			TEST_FAIL("The survey disagrees with the placement rule twice: [still.Join(" | ")]")
			return
		log_test("Survey cells changed while the survey ran and settled on a retry: [disagreements.Join(" | ")]")
		survey = retry
		string_cells = survey["cells"]
	var/checked_open = 0
	var/checked_blocked = 0
	for(var/index in 1 to length(string_cells))
		if(findtext("slf", copytext(string_cells, index, index + 1)))
			checked_open++
		else
			checked_blocked++
	TEST_ASSERT(checked_open && checked_blocked, "The survey sample had no open or no blocked ground")
	var/wall_cell = copytext(string_cells, (wall_spot.y - survey["y"]) * width + (wall_spot.x - survey["x"]) + 1, (wall_spot.y - survey["y"]) * width + (wall_spot.x - survey["x"]) + 2)
	TEST_ASSERT_EQUAL(wall_cell, "w", "The survey did not draw the wall as a wall")
	var/mob_index = (mob_spot.y - survey["y"]) * width + (mob_spot.x - survey["x"]) + 1
	TEST_ASSERT(findtext("slf", copytext(string_cells, mob_index, mob_index + 1)), "The survey blocked a tile only because a mob stood on it")

	// The near mask is "within the gap of outpost ground", checked by brute force on a sample.
	for(var/index in 1 to width * height step 7)
		var/column = (index - 1) % width
		var/row = round((index - 1) / width)
		var/x = survey["x"] + column
		var/y = survey["y"] + row
		var/expected = FALSE
		for(var/turf/owned_turf as anything in owned)
			if(abs(owned_turf.x - x) <= 8 && abs(owned_turf.y - y) <= 8) // OUTPOST_UPGRADE_MAX_GAP
				expected = TRUE
				break
		if((copytext(string_near, index, index + 1) == "1") != expected)
			TEST_FAIL("The near mask is wrong at [x],[y]")
			return

	// The console path: opening the map surveys in the background and sends it as static data.
	home.outpost_upgrades["cargo_dock"] = new /datum/outpost_upgrade/cargo_dock(home)
	act(panel, owner, "open_upgrade_map", null, list("id" = "cargo_dock"))
	TEST_ASSERT_NULL(panel.upgrade_error, "Opening the placement map reported an error")
	var/deadline = world.time + 20 SECONDS
	while(home.upgrade_surveying && world.time < deadline)
		sleep(1)
	TEST_ASSERT(!home.upgrade_surveying, "The background survey never finished")
	var/list/sent = panel.ui_static_data(owner)["upgrade_survey"]
	TEST_ASSERT_NOTNULL(sent, "The finished survey was not sent to the open map")
	// Something loose drifting through open space between the two surveys (seen once in 5 runs:
	// one tile went from object to open and another the other way) is not a disagreement about
	// the rules. Anything else is.
	var/sent_cells = sent["cells"]
	TEST_ASSERT_EQUAL(length(sent_cells), length(string_cells), "The background survey covers a different area")
	var/list/moved = list()
	for(var/index in 1 to length(string_cells))
		var/before = copytext(string_cells, index, index + 1)
		var/after = copytext(sent_cells, index, index + 1)
		if(before == after)
			continue
		if(!findtext("mslf", before) || !findtext("mslf", after) || length(moved) >= 4)
			TEST_FAIL("The background survey disagrees with the direct one at cell [index]: [before] became [after]")
			return
		moved += "[index]:[before]>[after]"
	if(length(moved))
		log_test("Loose objects moved between the two surveys: [moved.Join(" ")]")
	act(panel, owner, "close_upgrade_map", null, list("id" = "cargo_dock"))
	TEST_ASSERT_NULL(panel.ui_static_data(owner)["upgrade_survey"], "The survey was still sent after the map closed")

/// The Upgrades tab and the founding catalog show baked art; it must be regenerated whenever a map changes.
/datum/unit_test/voidcrew_outpost_upgrade_previews

/datum/unit_test/voidcrew_outpost_upgrade_previews/Run()
	var/checked = 0
	for(var/upgrade_id in GLOB.outpost_upgrade_catalog)
		var/datum/outpost_upgrade/upgrade = GLOB.outpost_upgrade_catalog[upgrade_id]
		TEST_ASSERT(length(outpost_style_maps(upgrade.template_type)), "The [upgrade.name] upgrade has no map")
		// Its left-hand room's maps too, when it has one
		for(var/datum/map_template/map_type as anything in upgrade.all_map_types())
			checked += check_preview(map_type, "The [upgrade.name] ([outpost_map_preview_name(map_type)])")
	for(var/datum/map_template/player_outpost/shell_type as anything in outpost_selectable_shells())
		checked += check_preview(shell_type, "The [initial(shell_type.name)] shell")
	TEST_ASSERT(checked, "No previews were checked")

/// Checks one map's baked preview. Returns 1 when it was checked.
/datum/unit_test/voidcrew_outpost_upgrade_previews/proc/check_preview(datum/map_template/map_type, label)
	var/map_path = initial(map_type.mappath)
	var/preview = outpost_map_preview_name(map_type)
	var/json_path = "voidcrew/modules/player_outposts/previews/[preview].preview.json"
	if(!fexists(json_path))
		TEST_FAIL("[json_path] is missing. Run tools/outpost_upgrade_previews/generate_outpost_upgrade_previews.py")
		return 0
	var/list/meta = json_decode(file2text(json_path))
	if(!islist(meta))
		TEST_FAIL("[json_path] is not valid JSON")
		return 0
	TEST_ASSERT_EQUAL(meta["png"], "[preview].png", "[json_path] names the wrong image")
	TEST_ASSERT(fexists("voidcrew/modules/player_outposts/previews/[meta["png"]]"), "[label] preview image is missing")
	var/datum/map_template/template = allocate(map_type)
	TEST_ASSERT(template.width, "[label] template did not load its map")
	TEST_ASSERT_EQUAL(meta["width"], template.width, "[label] preview has the wrong width")
	TEST_ASSERT_EQUAL(meta["height"], template.height, "[label] preview has the wrong height")
	if(meta["src_md5"] != rustg_hash_file(RUSTG_HASH_MD5, map_path))
		TEST_FAIL("[label] preview was rendered from a different version of [map_path] than the one on disk, so players 			see a room that no longer exists. Run tools/outpost_upgrade_previews/generate_outpost_upgrade_previews.py and commit 			the new PNG and .preview.json with the map change.")
	return 1

// ===== ADMIN DELETES, LOOSE ITEMS AND THE SURVEY WINDOW =====

/**
 * An admin deleting the running prison can start it again, and deleting an upgrade takes it off
 * the outpost's list, so the shop does not call it installed forever.
 */
/datum/unit_test/voidcrew_outpost_upgrade_admin_deletes
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_upgrade_admin_deletes/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("upgradedeleteowner")
	TEST_ASSERT_NOTNULL(home, "The upgrade deletion test prison did not load")
	var/datum/outpost_upgrade/prison/blueprint = home.outpost_upgrades["prison"]
	qdel(blueprint.prison)
	TEST_ASSERT_NULL(blueprint.prison, "The upgrade kept a deleted prison")
	blueprint.on_installed(null)
	TEST_ASSERT(!QDELETED(blueprint.prison), "The prison could not be started again after an admin deleted it")
	STOP_PROCESSING(SSprocessing, blueprint.prison)
	var/datum/outpost_prison/restarted = blueprint.prison
	qdel(blueprint)
	TEST_ASSERT_NULL(home.outpost_upgrades["prison"], "A deleted upgrade stayed on the outpost's list")
	TEST_ASSERT(QDELETED(restarted), "Deleting the upgrade left its prison running")
	settle_prison_air(home)

/// Loose things on a footprint are moved out of the way before the room is built over them.
/datum/unit_test/voidcrew_outpost_upgrade_sweep
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_upgrade_sweep/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("sweepowner")
	TEST_ASSERT_NOTNULL(home, "The sweep test outpost did not load")
	var/datum/outpost_upgrade/cargo_dock/blueprint = new(home)
	home.outpost_upgrades["cargo_dock"] = blueprint
	var/turf/bottom_left = locate(home.template_bottom_left.x, home.template_bottom_left.y + home.shell_template.height + 3, home.upgrade_level_z())
	var/list/footprint = blueprint.footprint_at(bottom_left, 0)
	TEST_ASSERT_NOTNULL(footprint, "No footprint for the sweep test")
	// One loose wrench on every tile of the room's back row, where its wall goes up.
	var/list/obj/item/wrench/loose = list()
	var/top = bottom_left.y + blueprint.get_template().height - 1
	for(var/x in bottom_left.x to bottom_left.x + blueprint.get_template().width - 1)
		loose += allocate(/obj/item/wrench, locate(x, top, bottom_left.z))
	TEST_ASSERT_NULL(home.place_outpost_upgrade(blueprint, bottom_left, 0, null), "The cargo dock was not placed")
	var/list/entrance = footprint["entrance"]
	var/turf/outside = get_step(entrance[CEILING(length(entrance) / 2, 1)], SOUTH)
	for(var/obj/item/wrench/wrench as anything in loose)
		TEST_ASSERT(!blueprint.contains_turf(get_turf(wrench)), "A loose wrench was left inside the new room, at [wrench.x],[wrench.y]")
		TEST_ASSERT_EQUAL(get_turf(wrench), outside, "A wrench was not moved outside the entrance")
	settle_test_cargo_dock(home)

/// An outpost sprawled across its claim is surveyed only in a window around its core.
/datum/unit_test/voidcrew_outpost_upgrade_survey_window
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_upgrade_survey_window/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("windowowner")
	TEST_ASSERT_NOTNULL(home, "The survey window test outpost did not load")
	var/turf/center = home.upgrade_survey_center()
	TEST_ASSERT_NOTNULL(center, "The outpost has no core to survey around")
	var/list/claim = home.build_bounds
	var/turf/far = locate(claim[3], center.y, center.z)
	if(far.x - center.x < 80)
		TEST_NOTICE(src, "The claim is too small to sprawl past the survey window")
		return
	// One far-off tile of outpost ground stretches the outpost across the claim.
	var/area/old_area = far.loc
	far.change_area(old_area, home.outpost_area)
	var/list/survey = home.build_upgrade_survey()
	far.change_area(home.outpost_area, old_area)
	TEST_ASSERT_NOTNULL(survey, "The sprawled outpost could not be surveyed")
	TEST_ASSERT(survey["width"] <= 128 && survey["height"] <= 128, "The survey covered [survey["width"]] x [survey["height"]] tiles") // UPGRADE_SURVEY_WINDOW
	TEST_ASSERT(center.x >= survey["x"] && center.x < survey["x"] + survey["width"], "The survey window does not hold the outpost's core")

// ===== A PLACEMENT THAT NEVER FINISHES =====

/**
 * A placement whose map load crashed never came back to release its blueprint, which then stayed
 * "placing" for good: it could be neither placed again nor refunded. Every placement arms a
 * watchdog that puts the blueprint back on the shelf once no map is loading, waits while one is,
 * and leaves a later placement and a finished one alone.
 */
/datum/unit_test/voidcrew_outpost_upgrade_placement_watchdog
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_upgrade_placement_watchdog/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("watchdogowner")
	TEST_ASSERT_NOTNULL(home, "The watchdog test outpost did not load")
	var/mob/living/carbon/human/owner = make_player(get_turf(home.management_console), "watchdogowner")
	home.ensure_home_services()
	var/datum/outpost_upgrade/cargo_dock/blueprint = new(home)
	home.outpost_upgrades["cargo_dock"] = blueprint

	// A placement that died mid-load: the blueprint claimed, its footprint recorded, nobody coming back.
	blueprint.placing = TRUE
	var/crashed = ++blueprint.placement_serial
	blueprint.rotation = 90
	blueprint.footprint_bounds = list(1, 1, 13, 16, home.upgrade_level_z())
	TEST_ASSERT_EQUAL(home.cancel_outpost_upgrade(owner, "cargo_dock"), "Placement in progress.", "A claimed blueprint could be cancelled")
	TEST_ASSERT_NULL(home.unplaced_upgrade("cargo_dock"), "A claimed blueprint could be placed again")

	// While a map is loading, it may be this placement's own load, or the one it waits behind.
	var/was_loading = Master.map_loading
	Master.map_loading = TRUE
	blueprint.placement_watchdog(crashed)
	Master.map_loading = was_loading
	TEST_ASSERT(blueprint.placing, "The watchdog released a placement while a map was loading")

	// With no map loading it gives up on the placement.
	TEST_ASSERT(!Master.map_loading, "A map was loading during the watchdog test")
	blueprint.placement_watchdog(crashed)
	TEST_ASSERT(!blueprint.placing, "The watchdog did not release a placement that never finished")
	TEST_ASSERT_NULL(blueprint.footprint_bounds, "The released blueprint kept its footprint")
	TEST_ASSERT_EQUAL(blueprint.rotation, 0, "The released blueprint kept its rotation")
	TEST_ASSERT_EQUAL(home.unplaced_upgrade("cargo_dock"), blueprint, "The released blueprint cannot be placed again")
	TEST_ASSERT(blueprint in home.upgrade_blueprints(), "The released blueprint is not back on the shelf")

	// An earlier placement's watchdog leaves a later placement alone.
	blueprint.placing = TRUE
	var/later = ++blueprint.placement_serial
	blueprint.placement_watchdog(crashed)
	TEST_ASSERT(blueprint.placing, "An earlier placement's watchdog released a later one")
	blueprint.placing = FALSE

	// A real placement still installs, and its watchdog finds nothing to do.
	var/result = place_test_cargo_dock(home, user = owner)
	TEST_ASSERT_EQUAL(result, blueprint, "The released blueprint could not be placed: [result]")
	TEST_ASSERT(blueprint.installed && !blueprint.placing, "The placement did not install the blueprint")
	TEST_ASSERT(blueprint.placement_serial > later, "The placement did not count itself")
	var/list/bounds = blueprint.footprint_bounds.Copy()
	blueprint.placement_watchdog(blueprint.placement_serial)
	TEST_ASSERT(blueprint.installed && blueprint.footprint_bounds ~= bounds, "The watchdog touched a finished placement")
	settle_test_cargo_dock(home)
