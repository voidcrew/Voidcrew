/**
 * Shared fixtures for the derelict outpost tests. Frozen after the seams commit; parts add helpers only
 * in their own test files. Voidcrew defines are not visible here, so values appear as literals.
 */
/datum/unit_test/voidcrew_derelict
	parent_type = /datum/unit_test/voidcrew_outpost_management
	abstract_type = /datum/unit_test/voidcrew_derelict

/// A derelict built now, in `shell_type`, with `theme_id` (null: no theme) in `band` (2 yellow, 3 red)
/datum/unit_test/voidcrew_derelict/proc/built_derelict(shell_type, theme_id, band = 2)
	var/obj/structure/overmap/dynamic/player_outpost/derelict/site = allocate(/obj/structure/overmap/dynamic/player_outpost/derelict)
	site.setup_derelict(shell_type, theme_id || "xeno", band)
	site.derelict_skip_theme = isnull(theme_id)
	site.build_derelict(null)
	if(!site.is_loaded())
		TEST_NOTICE(src, "The [shell_type] derelict did not build")
		return null
	return site

/// Whether a test walker can stand on `tile`: not a wall, and nothing dense on it but doors and mobs
/datum/unit_test/voidcrew_derelict/proc/derelict_walkable(turf/tile)
	if(!tile || isclosedturf(tile))
		return FALSE
	for(var/atom/movable/thing as anything in tile)
		if(!thing.density || ismob(thing) || istype(thing, /obj/machinery/door))
			continue
		return FALSE
	return TRUE

/// Turfs reachable on foot from `start` without leaving the derelict's areas, as turf = TRUE
/datum/unit_test/voidcrew_derelict/proc/derelict_reach(obj/structure/overmap/dynamic/player_outpost/derelict/site, turf/start)
	var/list/allowed = list()
	for(var/area/place as anything in site.derelict_areas())
		for(var/turf/tile as anything in place.get_turfs_by_zlevel(start.z))
			allowed[tile] = TRUE
	var/list/reached = list()
	reached[start] = TRUE
	var/list/queue = list(start)
	while(length(queue))
		var/turf/tile = queue[1]
		queue.Cut(1, 2)
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(tile, direction)
			if(!next || reached[next] || !allowed[next] || !derelict_walkable(next))
				continue
			reached[next] = TRUE
			queue += next
	return reached

/// Every atom of `type` on the derelict's floor turfs
/datum/unit_test/voidcrew_derelict/proc/derelict_atoms(obj/structure/overmap/dynamic/player_outpost/derelict/site, type)
	. = list()
	for(var/turf/tile as anything in site.derelict_floor_turfs())
		for(var/atom/movable/thing in tile)
			if(istype(thing, type))
				. += thing
