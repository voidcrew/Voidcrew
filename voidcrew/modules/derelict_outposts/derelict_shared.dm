/**
 * # Derelict outposts: shared pieces
 *
 * Frozen after the seams commit. The hooks other modules call (ship_sensors.dm, SSovermap's derelict sweep),
 * the names a derelict answers to, and the tile helpers the layout, theme and test files share.
 */

/// This round's derelict outpost, or null. Set by its Initialize(), cleared by its Destroy().
GLOBAL_DATUM(derelict_outpost, /obj/structure/overmap/dynamic/player_outpost/derelict)

/// The names a derelict outpost answers to once found; one is picked per round
GLOBAL_LIST_INIT(derelict_outpost_names, list(
	"Harrow Station",
	"Lantern Rest",
	"Greyfall Waystation",
	"Saint Orrin Habitat",
	"Morrow Deep",
	"Cinder Rest",
	"Pale Harbour",
	"Weir Station",
))

/// The name this contact shows `viewer` in place of its own, or null. get_contact_name() asks this first.
/obj/structure/overmap/proc/identified_contact_name(obj/structure/overmap/ship/viewer)
	return null

/// Whether hulls docked here skip the derelict and abandonment clocks (SSovermap.sweep_derelicts()).
/// Somebody's home does; an unclaimed derelict outpost does not.
/obj/structure/overmap/dynamic/player_outpost/proc/shelters_docked_hulls()
	return TRUE

/// The derelict's own areas on its level: the habitat's, then each installed room's, each once
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/derelict_areas()
	. = list()
	if(outpost_area)
		. += outpost_area
	for(var/upgrade_key in outpost_upgrades)
		var/datum/outpost_upgrade/upgrade = outpost_upgrades[upgrade_key]
		if(upgrade?.installed && upgrade.installed_area)
			. |= upgrade.installed_area

/// Every floor turf of derelict_areas() on the outpost's level
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/derelict_floor_turfs()
	. = list()
	var/z = upgrade_level_z()
	if(!z)
		return
	for(var/area/place as anything in derelict_areas())
		for(var/turf/open/floor/tile in place.get_turfs_by_zlevel(z))
			. += tile

/// Whether dressing, hostiles and fuel keep off `tile`: the arrival point, the elevator alcove and the ring round it,
/// anything dense, any machine or structure, and the tiles beside a door
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/is_derelict_protected_turf(turf/tile)
	if(!isturf(tile) || isclosedturf(tile) || isspaceturf(tile))
		return TRUE
	if(tile == arrival_turf)
		return TRUE
	for(var/turf/alcove as anything in lobby_alcove_turfs)
		if(get_dist(tile, alcove) <= 1)
			return TRUE
	for(var/atom/movable/thing as anything in tile)
		if(thing.density || istype(thing, /obj/machinery) || istype(thing, /obj/structure))
			return TRUE
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(tile, direction)
		if(beside && (locate(/obj/machinery/door) in beside))
			return TRUE
	return FALSE

/// Whether `tile` is within `radius` of the arrival point or any elevator alcove tile
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/near_derelict_arrival(turf/tile, radius = DERELICT_SAFE_RADIUS)
	if(arrival_turf && get_dist(tile, arrival_turf) <= radius)
		return TRUE
	for(var/turf/alcove as anything in lobby_alcove_turfs)
		if(get_dist(tile, alcove) <= radius)
			return TRUE
	return FALSE

/// The habitat's portable generator, or null
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/derelict_generator()
	var/z = upgrade_level_z()
	if(!z || !outpost_area)
		return null
	for(var/turf/tile as anything in outpost_area.get_turfs_by_zlevel(z))
		var/obj/machinery/power/port_gen/pacman/generator = locate() in tile
		if(generator)
			return generator
	return null
