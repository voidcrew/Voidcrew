/**
 * # Ship weapons and thrusters need a clear line to open space
 *
 * ship_device_exposed_to_space() (voidcrew/_HELPERS/ship_exposure.dm) is the rule:
 * at least one of the four straight lines out of the device's tile has to leave the
 * ship's footprint without crossing a tile the ship owns or a shut door. These cases
 * pin down the three exploits it closes (blast door over a turret, turret sealed in
 * a space pocket, thruster inside the hull) and the two things it must not break
 * (a device on the hull edge, a landed ship with rock against its hull).
 *
 * The fixture is the 5x5 test room: a throwaway /area/shuttle painted over some of
 * its tiles, and a bare mobile port whose footprint is exactly the room.
 */
/datum/unit_test/voidcrew_ship_device_exposure
	var/area/shuttle/hull_area
	var/list/original_areas
	var/obj/docking_port/mobile/port

/datum/unit_test/voidcrew_ship_device_exposure/Run()
	var/turf/bottom_left = run_loc_floor_bottom_left
	var/turf/top_right = run_loc_floor_top_right
	TEST_ASSERT(top_right.x - bottom_left.x >= 4 && top_right.y - bottom_left.y >= 4, "the test room is smaller than 5x5")

	hull_area = new
	original_areas = list()
	port = new /obj/docking_port/mobile(bottom_left)
	port.dir = NORTH
	port.dwidth = 0
	port.dheight = 0
	port.width = 5
	port.height = 5
	// Subscript assignment: list(hull_area = TRUE) would register the string "hull_area".
	port.shuttle_areas = list()
	port.shuttle_areas[hull_area] = TRUE

	run_cases()

	for(var/turf/tile as anything in original_areas)
		tile.change_area(hull_area, original_areas[tile])
	original_areas.Cut()
	qdel(port, force = TRUE)
	port = null
	if(!hull_area.has_contained_turfs())
		qdel(hull_area)
	hull_area = null

/datum/unit_test/voidcrew_ship_device_exposure/proc/run_cases()
	// The ship owns the west three columns; columns 4 and 5 are open space inside the footprint.
	set_hull(1, 3, 1, 5)
	var/turf/edge = room_tile(3, 3)
	var/turf/inside = room_tile(2, 3)

	var/obj/machinery/ship_combat/laser_turret/turret = allocate(/obj/machinery/ship_combat/laser_turret, edge)
	TEST_ASSERT(ship_device_exposed_to_space(turret, port), "a turret on the hull edge, with open space east of it, counted as blocked")
	TEST_ASSERT(!ship_device_exposed_to_space(allocate(/obj/item/wrench, inside), port), "a device inside the hull counted as exposed")

	// Blast door over the turret: shut blocks, open does not.
	var/obj/machinery/door/poddoor/shutter = allocate(/obj/machinery/door/poddoor, edge)
	TEST_ASSERT(shutter.density, "the test blast door did not start shut")
	TEST_ASSERT(!ship_device_exposed_to_space(turret, port), "a shut blast door over the turret did not block it")
	TEST_ASSERT(ship_device_exposed_to_space(turret, port, ignore_doors = TRUE), "ignore_doors still counted the blast door over the turret")
	qdel(shutter)
	var/obj/machinery/door/poddoor/preopen/open_shutter = allocate(/obj/machinery/door/poddoor/preopen, edge)
	TEST_ASSERT(!open_shutter.density, "the preopen blast door started shut")
	TEST_ASSERT(ship_device_exposed_to_space(turret, port), "an open blast door over the turret blocked it")
	qdel(open_shutter)

	// A shut door out in the open, on the turret's only clear line, blocks that line.
	var/obj/machinery/door/poddoor/outer_shutter = allocate(/obj/machinery/door/poddoor, room_tile(4, 3))
	TEST_ASSERT(!ship_device_exposed_to_space(turret, port), "a shut blast door on the turret's only line to space did not block it")
	qdel(outer_shutter)

	// Landed: rock the ship does not own, right against the hull, blocks nothing.
	var/turf/rock_tile = room_tile(4, 3)
	var/rock_original_type = rock_tile.type
	var/list/rock_original_baseturfs = rock_tile.baseturfs
	rock_tile.ChangeTurf(/turf/closed/wall)
	TEST_ASSERT(ship_device_exposed_to_space(turret, port), "rock the ship does not own blocked a turret on the hull edge")
	rock_tile.ChangeTurf(rock_original_type, rock_original_baseturfs)

	// Thrusters: the same rule, wired through update_engine().
	var/obj/machinery/power/shuttle_engine/ship/void/edge_engine = allocate(/obj/machinery/power/shuttle_engine/ship/void, edge)
	var/obj/machinery/power/shuttle_engine/ship/void/buried_engine = allocate(/obj/machinery/power/shuttle_engine/ship/void, inside)
	edge_engine.connect_to_shuttle(port = port)
	buried_engine.connect_to_shuttle(port = port)
	edge_engine.update_engine()
	buried_engine.update_engine()
	TEST_ASSERT(edge_engine.thruster_active && !edge_engine.exhaust_blocked, "a thruster on the hull edge was marked blocked")
	TEST_ASSERT(!buried_engine.thruster_active && buried_engine.exhaust_blocked, "a thruster inside the hull still produces thrust")
	TEST_ASSERT(buried_engine in port.engine_list, "a blocked thruster was unregistered instead of kept on the ship")
	var/reason = buried_engine.link_refusal_reason(port)
	TEST_ASSERT(findtext(reason, "exhaust"), "the engine report gave '[reason]' for a thruster inside the hull")

	// Cutting the hull away in front of it brings it back once the cache is refreshed.
	set_hull(1, 1, 1, 5)
	buried_engine.exhaust_recheck_at = 0
	buried_engine.update_engine()
	TEST_ASSERT(buried_engine.thruster_active && !buried_engine.exhaust_blocked, "a thruster did not recover after the hull in front of it was removed")
	qdel(edge_engine)
	qdel(buried_engine)

	// Space pocket: the ship owns everything but the middle tile, and the turret sits in it.
	set_hull(1, 5, 1, 5, list(room_tile(3, 3)))
	TEST_ASSERT(get_area(edge) != hull_area, "the pocket tile was painted into the hull")
	TEST_ASSERT(!ship_device_exposed_to_space(turret, port), "a turret sealed in a space pocket inside the hull counted as exposed")
	TEST_ASSERT(!ship_device_exposed_to_space(turret, port, ignore_doors = TRUE), "a turret sealed in a space pocket counted as exposed with doors ignored")

	// No ship at all: nothing can block it.
	TEST_ASSERT(ship_device_exposed_to_space(turret, null), "a device on no ship counted as blocked")

/// The test room tile at (x, y), counting from 1 at the bottom left.
/datum/unit_test/voidcrew_ship_device_exposure/proc/room_tile(x, y)
	return locate(run_loc_floor_bottom_left.x + x - 1, run_loc_floor_bottom_left.y + y - 1, run_loc_floor_bottom_left.z)

/// Paints the hull area over room columns low_x..high_x and rows low_y..high_y, minus `except`,
/// and puts every other room tile back in its own area.
/datum/unit_test/voidcrew_ship_device_exposure/proc/set_hull(low_x, high_x, low_y, high_y, list/except)
	for(var/x in 1 to 5)
		for(var/y in 1 to 5)
			var/turf/tile = room_tile(x, y)
			var/want_hull = x >= low_x && x <= high_x && y >= low_y && y <= high_y && !(tile in except)
			var/area/current = get_area(tile)
			if(want_hull && current != hull_area)
				original_areas[tile] = current
				tile.change_area(current, hull_area)
			else if(!want_hull && current == hull_area)
				tile.change_area(hull_area, original_areas[tile])
				original_areas -= tile

/**
 * # Every mapped weapon and thruster on the fleet can reach open space
 *
 * Static scan in the voidcrew_ship_assembly.dm style: every purchasable hull on
 * every theme, with default modules and each single-module substitution, plus every
 * NPC ship hull, assembled from the shipped `.dmm` files. A tile is the ship's when
 * its area is an /area/shuttle, which is what the mobile port registers into
 * shuttle_areas, and the footprint is the whole map.
 *
 * Thrusters must be clear with every door as mapped. Weapon mounts are judged with
 * doors open: a blast door over a gun is a legitimate design, the crew just has to
 * open it to fire.
 */
/datum/unit_test/voidcrew_fleet_device_exposure
	priority = TEST_LONGER

/datum/unit_test/voidcrew_fleet_device_exposure/Run()
	ensure_ship_upgrades_initialized()
	var/list/hulls_by_type = vc_test_voidcrew_hull_templates()

	var/list/checked_types = list()
	for(var/datum/map_template/shuttle/voidcrew/hull as anything in get_purchasable_ship_templates())
		checked_types[hull.type] = TRUE
	for(var/npc_type in subtypesof(/obj/structure/overmap/ship/npc))
		var/obj/structure/overmap/ship/npc/npc_ship = npc_type
		var/template_type = initial(npc_ship.shuttle_template)
		if(template_type)
			checked_types[template_type] = TRUE

	var/list/datum/vc_test_fitout/fitouts = list()
	var/list/modular_types = list()
	for(var/datum/vc_test_fitout/fitout as anything in vc_test_ship_fitouts())
		if(!checked_types[fitout.hull_type])
			continue
		fitouts += fitout
		modular_types[fitout.hull_type] = TRUE
	for(var/hull_type in checked_types)
		if(modular_types[hull_type])
			continue
		var/datum/map_template/shuttle/voidcrew/hull = hulls_by_type[hull_type]
		if(!hull || !fexists(hull.mappath))
			continue
		fitouts += vc_test_build_fitout(hull_type, null, hull.mappath, "[hull_type]", list())

	TEST_ASSERT(length(fitouts) >= 20, "only [length(fitouts)] ship assemblies were found to check")

	var/list/reported = list()
	var/devices_checked = 0
	for(var/datum/vc_test_fitout/fitout as anything in fitouts)
		var/datum/vc_test_ship/ship = vc_test_assemble_ship(fitout)
		if(!ship)
			continue
		for(var/index in 1 to length(ship.tiles))
			var/list/atoms = ship.tiles[index]
			if(!length(atoms))
				continue
			for(var/entry in atoms)
				var/is_thruster = vc_test_entry_is(entry, /obj/machinery/power/shuttle_engine/ship)
				var/is_weapon = vc_test_entry_is(entry, /obj/machinery/ship_combat/laser_turret) \
					|| vc_test_entry_is(entry, /obj/machinery/ship_combat/missile_launcher) \
					|| vc_test_entry_is(entry, /obj/machinery/ship_combat/pod_launcher)
				if(!is_thruster && !is_weapon)
					continue
				var/atom/movable/device_type = vc_test_entry_type(entry)
				if(!vc_test_entry_boolean(entry, "anchored", initial(device_type.anchored)))
					continue
				devices_checked++
				if(vc_test_static_device_exposed(ship, index, ignore_doors = is_weapon))
					continue
				var/list/module_placed = ship.module_atoms[index]
				var/source = (module_placed && (entry in module_placed)) ? "module in slot [ship.module_slots[index]]" : "hull"
				var/report_key = "[fitout.hull_map]|[device_type]|[index]|[source]"
				if(reported[report_key])
					continue
				reported[report_key] = TRUE
				var/door_note = (!is_weapon && vc_test_static_device_exposed(ship, index, ignore_doors = TRUE)) ? " (only a shut door is in the way)" : ""
				TEST_FAIL("[fitout.hull_map], [fitout.label]: [device_type] at [ship.tile_coords(index)] ([source]) has no clear line to open space[door_note]")

	TEST_ASSERT(devices_checked >= 50, "only [devices_checked] mapped weapons and thrusters were found; the scan is not looking at the fleet")

/// Static twin of ship_device_exposed_to_space(), over an assembled ship.
/proc/vc_test_static_device_exposed(datum/vc_test_ship/ship, index, ignore_doors = FALSE)
	if(!ignore_doors && vc_test_tile_has_closed_door(ship.tiles[index]))
		return FALSE
	var/origin_x = ship.tile_x(index)
	var/origin_y = ship.tile_y(index)
	for(var/ray_dir in GLOB.cardinals)
		var/step_x = (ray_dir == EAST) ? 1 : ((ray_dir == WEST) ? -1 : 0)
		var/step_y = (ray_dir == NORTH) ? 1 : ((ray_dir == SOUTH) ? -1 : 0)
		var/x = origin_x
		var/y = origin_y
		var/blocked = FALSE
		while(TRUE)
			x += step_x
			y += step_y
			if(x < 1 || y < 1 || x > ship.width || y > ship.height)
				break
			var/list/atoms = ship.tiles[(y - 1) * ship.width + x]
			if(vc_test_tile_ship_owned(atoms) || (!ignore_doors && vc_test_tile_has_closed_door(atoms)))
				blocked = TRUE
				break
		if(!blocked)
			return TRUE
	return FALSE

/// Whether a mapped tile's area is one a ship's port registers (see mobile port Initialize()).
/proc/vc_test_tile_ship_owned(list/atoms)
	if(!length(atoms))
		return FALSE
	var/area_entry = atoms[length(atoms)]
	return vc_test_entry_is(area_entry, /area/shuttle) && !vc_test_entry_is(area_entry, /area/shuttle/transit)

/// Whether a mapped tile holds a door that loads shut.
/proc/vc_test_tile_has_closed_door(list/atoms)
	for(var/entry in atoms)
		if(!vc_test_entry_is(entry, /obj/machinery/door))
			continue
		var/obj/machinery/door/door_type = vc_test_entry_type(entry)
		if(vc_test_entry_boolean(entry, "density", initial(door_type.density)))
			return TRUE
	return FALSE
