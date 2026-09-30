/**
 * Snap upgrades (outpost_upgrades.dm): rooms that only go against a joint on another upgrade's
 * wall. Tested with a small host room that has a joint on each side wall, and a small room whose
 * first column is a seam over the wall it joins, at every rotation: the offers land where worked
 * out by hand, placement anywhere else is refused, the joined wall is left as it was, the room's own
 * far joint is registered for the next one, and a mob, a broken wall or a table on the seam refuse it.
 *
 * The host (5x4) has walls all round, windows at (1,3) and (5,3), and joints at (1,1) (left) and
 * (5,1) (right), each opening rows 2 and 3. The room (4x4) has its seam in column 1, wood floor
 * inside, a window at (4,3) and its own right joint at (4,1); the left room is the same mirrored.
 * The test types have no id on the type, so the shop never lists them.
 */

/area/voidcrew/player_outpost/snap_test_host
	name = "Snap Test Host"

/area/voidcrew/player_outpost/snap_test_room
	name = "Snap Test Room"

/datum/map_template/outpost_upgrade/snap_test_host
	name = "Snap Test Host"
	mappath = "voidcrew/_maps/map_files/unit_tests/outpost_snap_test_host.dmm"

/datum/map_template/outpost_upgrade/snap_test_room
	name = "Snap Test Room"
	mappath = "voidcrew/_maps/map_files/unit_tests/outpost_snap_test_room.dmm"

/datum/map_template/outpost_upgrade/snap_test_room/left
	name = "Snap Test Room (left)"
	mappath = "voidcrew/_maps/map_files/unit_tests/outpost_snap_test_room_left.dmm"

/datum/outpost_upgrade/snap_test_host
	name = "Snap Test Host"
	max_owned = 4
	template_type = /datum/map_template/outpost_upgrade/snap_test_host
	area_type = /area/voidcrew/player_outpost/snap_test_host

/datum/outpost_upgrade/snap_test_host/New(obj/structure/overmap/dynamic/player_outpost/owner)
	id = "snap_test_host"
	return ..()

/datum/outpost_upgrade/snap_test_room
	name = "Snap Test Room"
	max_owned = 3
	template_type = /datum/map_template/outpost_upgrade/snap_test_room
	left_template_type = /datum/map_template/outpost_upgrade/snap_test_room/left
	area_type = /area/voidcrew/player_outpost/snap_test_room
	entrance_side = EAST
	snap_group = "snap_test"

/datum/outpost_upgrade/snap_test_room/New(obj/structure/overmap/dynamic/player_outpost/owner)
	id = "snap_test_room"
	return ..()

/// A test upgrade of `upgrade_type` on the outpost's list, under the next free key of its id
/datum/unit_test/voidcrew_outpost_management/proc/snap_test_blueprint(obj/structure/overmap/dynamic/player_outpost/home, upgrade_type)
	var/datum/outpost_upgrade/blueprint = new upgrade_type(home)
	blueprint.key = home.free_upgrade_key(blueprint.id, blueprint.max_owned)
	home.outpost_upgrades[blueprint.key] = blueprint
	return blueprint

/// The offer on `side` among `offers`, or null
/datum/unit_test/voidcrew_outpost_management/proc/offer_on(list/offers, side)
	for(var/list/offer as anything in offers)
		if(offer["side"] == side)
			return offer
	return null

/datum/unit_test/voidcrew_outpost_upgrade_snaps
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_upgrade_snaps/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("snapowner")
	TEST_ASSERT_NOTNULL(home, "The snap test outpost did not load")
	var/z = home.upgrade_level_z()
	var/turf/shell = home.template_bottom_left
	var/shell_right = shell.x + home.shell_template.width - 1
	var/shell_top = shell.y + home.shell_template.height - 1
	// Each host goes on its own side of the shell, five tiles out, clear of the other rotations' rooms.
	var/list/host_corners = list(
		"0" = locate(shell.x + 6, shell_top + 6, z),
		"90" = locate(shell_right + 6, shell.y + 7, z),
		"180" = locate(shell.x + 6, shell.y - 10, z),
		"270" = locate(shell.x - 10, shell.y + 7, z),
	)
	// Worked out by hand from the rotated footprints: each room's bottom-left from its host's, and the
	// bottom-left of a second right-hand room chained onto the first's far wall.
	var/list/right_offsets = list("0" = list(4, 0), "90" = list(0, -3), "180" = list(-3, 0), "270" = list(0, 4))
	var/list/left_offsets = list("0" = list(-3, 0), "90" = list(0, 4), "180" = list(4, 0), "270" = list(0, -3))
	var/list/chain_offsets = list("0" = list(7, 0), "90" = list(0, -6), "180" = list(-6, 0), "270" = list(0, 7))

	for(var/rotation in list(0, 90, 180, 270))
		var/turf/host_corner = host_corners["[rotation]"]
		TEST_ASSERT_NOTNULL(host_corner, "No ground for the host at [rotation] degrees")
		var/datum/outpost_upgrade/snap_test_host/host = snap_test_blueprint(home, /datum/outpost_upgrade/snap_test_host)
		var/error = home.place_outpost_upgrade(host, host_corner, rotation, null)
		TEST_ASSERT_NULL(error, "The snap test host was not placed at [rotation] degrees: [error] [cargo_dock_blocker(home, host, host_corner, rotation)]")
		TEST_ASSERT_EQUAL(length(host.snap_points), 2, "The host registered [length(host.snap_points)] joints at [rotation] degrees, not 2")
		var/list/host_bounds = host.footprint_bounds
		for(var/turf/tile as anything in block(host_bounds[1], host_bounds[2], z, host_bounds[3], host_bounds[4], z))
			TEST_ASSERT_NULL(locate(/obj/effect/landmark/outpost_upgrade_snap) in tile, "A joint's landmark was left on the host at [rotation] degrees")

		// Two offers, one per wall, where worked out by hand, turned as the host is.
		var/datum/outpost_upgrade/snap_test_room/room = snap_test_blueprint(home, /datum/outpost_upgrade/snap_test_room)
		var/list/offers = room.snap_offers()
		TEST_ASSERT_EQUAL(length(offers), 2, "[length(offers)] offers at [rotation] degrees, not one per wall")
		for(var/side in list("right", "left"))
			var/list/offer = offer_on(offers, side)
			TEST_ASSERT_NOTNULL(offer, "No [side] offer at [rotation] degrees")
			var/list/want = side == "right" ? right_offsets["[rotation]"] : left_offsets["[rotation]"]
			var/turf/corner = offer["bottom_left"]
			TEST_ASSERT_EQUAL(corner, locate(host_corner.x + want[1], host_corner.y + want[2], z), "The [side] offer at [rotation] degrees is at [corner.x - host_corner.x],[corner.y - host_corner.y] from the host, not [want[1]],[want[2]]")
			TEST_ASSERT_EQUAL(offer["rotation"], rotation, "The [side] offer is turned [offer["rotation"]] degrees on a host turned [rotation]")
			var/list/seam = offer["seam"]
			TEST_ASSERT_EQUAL(length(seam), 4, "The [side] seam at [rotation] degrees is [length(seam)] tiles, not the room's height")
			for(var/turf/tile as anything in seam)
				TEST_ASSERT(host.contains_turf(tile) && tile.loc == host.installed_area, "The [side] seam at [rotation] degrees leaves the host's wall at [tile.x],[tile.y]")
			var/list/openings = offer["openings"]
			TEST_ASSERT_EQUAL(length(openings), 2, "The [side] seam at [rotation] degrees opens [length(openings)] tiles, not 2")
			var/walls = 0
			var/windows = 0
			for(var/turf/tile as anything in openings)
				if(isclosedturf(tile))
					walls++
				else if(locate(/obj/structure/window) in tile)
					windows++
			TEST_ASSERT(walls == 1 && windows == 1, "The [side] openings at [rotation] degrees are not the wall and the window of rows 2 and 3")

		// The placement map gets the same offers, all buildable.
		var/datum/player_outpost_management_ui/management_test/panel = allocate(/datum/player_outpost_management_ui/management_test, home, null, null)
		panel.placing_upgrade_id = "snap_test_room"
		var/list/payload = panel.upgrade_snap_payload()
		TEST_ASSERT_EQUAL(length(payload), 2, "The placement map offers [length(payload)] joints at [rotation] degrees")
		for(var/list/entry as anything in payload)
			for(var/key in list("x", "y", "rotation", "side", "reason", "blocked", "openings"))
				TEST_ASSERT(key in entry, "A placement map offer has no [key]")
			TEST_ASSERT_NULL(entry["reason"], "A clear [entry["side"]] offer at [rotation] degrees was refused on the map: [entry["reason"]]")
			TEST_ASSERT_EQUAL(length(entry["openings"]), 2, "The placement map shows [length(entry["openings"])] openings, not 2")

		// Anywhere else is refused, and nothing is claimed.
		var/list/right_offer = offer_on(offers, "right")
		var/turf/right_corner = right_offer["bottom_left"]
		TEST_ASSERT_EQUAL(home.place_outpost_upgrade(room, locate(right_corner.x + 1, right_corner.y, z), rotation, null), "Must join a matching wall.", "A room off the joint was placed at [rotation] degrees")
		TEST_ASSERT_EQUAL(home.place_outpost_upgrade(room, right_corner, (rotation + 90) % 360, null), "Must join a matching wall.", "A room turned the wrong way was placed at [rotation] degrees")
		if(rotation == 0)
			var/list/seam = right_offer["seam"]
			var/list/footprint = right_offer["footprint"]
			var/turf/inside
			for(var/turf/tile as anything in footprint["turfs"])
				if(!seam[tile])
					inside = tile
					break
			var/mob/living/carbon/human/consistent/bystander = allocate(__IMPLIED_TYPE__, inside)
			TEST_ASSERT_EQUAL(home.place_outpost_upgrade(room, right_corner, rotation, null), "Position obstructed.", "A room was built over someone standing in it")
			qdel(bystander)
			// A hole where the wall should stay, and a table on an opening, each refuse it until put right.
			var/datum/outpost_upgrade_snap/used = right_offer["snap"]
			var/turf/joint = used.joint
			joint.ChangeTurf(/turf/open/floor/plating)
			TEST_ASSERT_EQUAL(home.place_outpost_upgrade(room, right_corner, rotation, null), "Repair the wall first.", "A room joined a wall with a hole in it")
			joint.ChangeTurf(/turf/closed/wall)
			var/turf/window_tile
			for(var/turf/tile as anything in right_offer["openings"])
				if(!isclosedturf(tile))
					window_tile = tile
			var/obj/structure/table/table = allocate(__IMPLIED_TYPE__, window_tile)
			TEST_ASSERT_EQUAL(home.place_outpost_upgrade(room, right_corner, rotation, null), "Repair the wall first.", "A room joined a wall with a table in an opening")
			qdel(table)
		TEST_ASSERT(!room.placing && !room.installed && !room.footprint_bounds, "A refused placement claimed the blueprint at [rotation] degrees")

		// The right-hand room goes on its joint and leaves the wall it joins alone.
		var/list/seam_before = list()
		for(var/turf/tile as anything in right_offer["seam"])
			seam_before[tile] = "[tile.type][locate(/obj/structure/window) in tile ? "+window" : ""]"
		error = home.place_outpost_upgrade(room, right_corner, rotation, null)
		TEST_ASSERT_NULL(error, "The right-hand room was not placed at [rotation] degrees: [error]")
		TEST_ASSERT(room.installed, "The room was not installed at [rotation] degrees")
		TEST_ASSERT_EQUAL(room.snap_side, "right", "The room does not know which wall it joined")
		TEST_ASSERT(istype(room.installed_area, /area/voidcrew/player_outpost/snap_test_room), "The room did not get its own area at [rotation] degrees")
		for(var/turf/tile as anything in seam_before)
			TEST_ASSERT_EQUAL(tile.loc, host.installed_area, "Loading the room took the host's wall at [tile.x],[tile.y] ([rotation] degrees)")
			TEST_ASSERT_EQUAL("[tile.type][locate(/obj/structure/window) in tile ? "+window" : ""]", seam_before[tile], "Loading the room changed the host's wall at [tile.x],[tile.y] ([rotation] degrees)")
		var/datum/map_template/room_template = room.get_template("right")
		var/turf/room_floor = room_template.rotated_template_turf(right_corner, 1, 1, rotation)
		TEST_ASSERT(istype(room_floor, /turf/open/floor/wood), "The room's floor is not where its map puts it at [rotation] degrees")
		var/datum/outpost_upgrade_snap/taken = right_offer["snap"]
		TEST_ASSERT_EQUAL(taken.taken_by, room.key, "The joint the room took is not marked as taken")

		// Its far joint is now on the host's list: the next room chains on, and the used joint is gone.
		TEST_ASSERT_EQUAL(length(host.snap_points), 3, "The room's own joint was not registered at [rotation] degrees")
		var/datum/outpost_upgrade/snap_test_room/second = snap_test_blueprint(home, /datum/outpost_upgrade/snap_test_room)
		offers = second.snap_offers()
		TEST_ASSERT_EQUAL(length(offers), 2, "[length(offers)] offers after the first room at [rotation] degrees, not the left wall and the chain")
		var/list/chain = offer_on(offers, "right")
		var/list/chain_want = chain_offsets["[rotation]"]
		TEST_ASSERT_EQUAL(chain?["bottom_left"], locate(host_corner.x + chain_want[1], host_corner.y + chain_want[2], z), "The chained offer is not on the room's far wall at [rotation] degrees")

		// The left-hand room goes on the other wall.
		var/list/left_offer = offer_on(offers, "left")
		error = home.place_outpost_upgrade(second, left_offer["bottom_left"], rotation, null)
		TEST_ASSERT_NULL(error, "The left-hand room was not placed at [rotation] degrees: [error]")
		var/datum/map_template/left_template = second.get_template("left")
		var/turf/left_floor = left_template.rotated_template_turf(left_offer["bottom_left"], 1, 1, rotation)
		TEST_ASSERT(istype(left_floor, /turf/open/floor/wood), "The left-hand room's floor is not where its map puts it at [rotation] degrees")

		// Off the list, so the next rotation's host is the only one.
		qdel(second)
		qdel(room)
		qdel(host)
	settle_cargo_dock_air(block(shell.x - 20, shell.y - 20, z, shell_right + 20, shell_top + 20, z))
