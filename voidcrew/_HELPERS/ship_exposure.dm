/**
 * Whether a ship device (weapon mount, thruster) has a clear line out to open space.
 *
 * Weapons and thrusters have to sit on the outside of the hull. The old rule only
 * asked whether any of the eight neighbouring tiles lay outside the ship's areas,
 * which a sealed space pocket inside the hull, or a blast door over the mount,
 * both satisfied. This asks the real question instead: can at least one of the
 * four straight lines out of the device's tile leave the ship's footprint without
 * crossing anything solid the ship owns?
 *
 * All four directions count, because mapped dirs on thrusters and mounts are not
 * reliable, and firing is abstract anyway.
 *
 * A ray tile blocks when its area is one of the ship's `shuttle_areas` and it holds
 * something dense: a wall, or a dense object such as a shut door or blast door, a
 * window, a grille or a machine. Open deck, plating and catwalks the ship owns do
 * not block, so a thruster can sit behind an exterior plating strip.
 *
 * Terrain the ship does not own - planet rock, asteroids, an outpost, another ship
 * docked alongside - never blocks, so a landed or docked ship keeps its weapons
 * and engines.
 *
 * The device's own tile is not judged by its turf (wall mounts sit inside a hull
 * wall, thrusters stand on deck), but a closed door on that tile blocks every ray.
 *
 * Arguments:
 * * device - the machine to test.
 * * port - the ship's mobile docking port. With no port there is no ship to be
 *   blocked by, so the device counts as exposed.
 * * ignore_doors - judge only the permanent structure, as if every door were
 *   open. Used by auto-linking, which should not care whether a blast door
 *   happened to be shut at roundstart.
 */
/proc/ship_device_exposed_to_space(atom/device, obj/docking_port/mobile/port, ignore_doors = FALSE)
	var/turf/origin = get_turf(device)
	if(!origin)
		return FALSE
	if(!port || QDELETED(port) || port.z != origin.z)
		return TRUE
	if(!ignore_doors && ship_exposure_closed_door(origin))
		return FALSE

	var/list/owned_areas = port.shuttle_areas
	var/list/coords = port.return_coords()
	var/min_x = min(coords[1], coords[3])
	var/max_x = max(coords[1], coords[3])
	var/min_y = min(coords[2], coords[4])
	var/max_y = max(coords[2], coords[4])

	for(var/ray_dir in GLOB.cardinals)
		var/turf/tile = origin
		var/blocked = FALSE
		while(TRUE)
			tile = get_step(tile, ray_dir)
			// Off the map edge, or past the ship's footprint: nothing further out is ours.
			if(!tile || tile.x < min_x || tile.x > max_x || tile.y < min_y || tile.y > max_y)
				break
			if(owned_areas?[tile.loc] && ship_exposure_tile_solid(tile, ignore_doors))
				blocked = TRUE
				break
		if(!blocked)
			return TRUE
	return FALSE

/// Whether this tile has a wall on it, or a dense object. Shut doors are skipped with ignore_doors.
/proc/ship_exposure_tile_solid(turf/tile, ignore_doors = FALSE)
	if(tile.density)
		return TRUE
	for(var/obj/thing in tile)
		if(!thing.density)
			continue
		if(ignore_doors && istype(thing, /obj/machinery/door))
			continue
		return TRUE
	return FALSE

/// A shut door on this tile, blast doors included.
/proc/ship_exposure_closed_door(turf/tile)
	for(var/obj/machinery/door/door in tile)
		if(door.density)
			return TRUE
	return FALSE
