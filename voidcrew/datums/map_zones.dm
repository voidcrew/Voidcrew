/datum/map_zone
	var/name = "Map Zone"
	var/id
	/// Is the mapzone currently used by a overmap encounter?
	var/taken = FALSE
	/// List of all z levels this map zone contains
	var/list/z_levels = list()
	/**
	 * TRUE if this zone holds a planet's surface + cave z-pair, allocated back to back
	 * so cave_z == surface_z - 1 and the up/down traits actually line up.
	 *
	 * Zones are pooled and reused, and a single-z encounter that recycled half of a
	 * pair would leave the other half stranded - so the two pools are kept apart:
	 * find_free_mapzone() skips these, find_free_planet_mapzone() only returns these.
	 */
	var/planet_pair = FALSE

/datum/map_zone/New(passed_name)
	if(!isnull(passed_name))
		name = passed_name
	SSovermap.map_zones += src
	id = SSovermap.map_zones.len
	. = ..()

/datum/map_zone/Destroy()
	SSovermap.map_zones -= src
	return ..()

/// Clears all of what's inside the z levels managed by the mapzone.
/datum/map_zone/proc/clear_reservation()
	for(var/datum/space_level/zlevel as anything in z_levels)
		SSweather.set_z_level_weather_trait(zlevel, null)
		zlevel.clear_reservation()

/// Clears contents and resets turfs to uninitialized space (for empty space cleanup)
/datum/map_zone/proc/clear_to_uninitialized_space()
	for(var/datum/space_level/zlevel as anything in z_levels)
		SSweather.set_z_level_weather_trait(zlevel, null)
		zlevel.clear_to_uninitialized_space()

/datum/map_zone/proc/add_space_level(datum/space_level/level)
	z_levels += level
	// Otherwise only set as a side effect of get_block() (via fill_in()), which
	// skips its loops - and this assignment - when called with no area/turf
	// type to paint. Set eagerly so bounds are never null for callers that
	// read them before (or without) a fill_in() call, e.g. player outposts.
	level.low_x = 1
	level.low_y = 1
	level.high_x = world.maxx
	level.high_y = world.maxy

/datum/map_zone/proc/get_mind_mobs()
	. = list()
	for(var/datum/space_level/zlevel as anything in z_levels)
		. += zlevel.get_mind_mobs()

/datum/space_level
	var/low_x
	var/low_y
	var/high_x
	var/high_y

/datum/space_level/proc/get_mind_mobs()
	. = list()
	for(var/mob/living/living_mob as anything in GLOB.mob_living_list)
		if(!living_mob.mind || living_mob.stat == DEAD)
			continue
		if(living_mob.z == z_value)
			. += living_mob

/**
 * Confines this z-level to a centred region of the given size. Everything that walks
 * the level - terrain generation, population, ruin seeding, rivers, cleanup - goes
 * through get_block(), so setting bounds is all it takes to make a small planet on a
 * full-size z-level. Call place_cordon() afterwards to wall off the remainder.
 */
/datum/space_level/proc/set_bounds(width, height)
	width = clamp(width, PLANET_MIN_SIZE, world.maxx)
	height = clamp(height, PLANET_MIN_SIZE, world.maxy)
	low_x = round((world.maxx - width) / 2) + 1
	low_y = round((world.maxy - height) / 2) + 1
	high_x = low_x + width - 1
	high_y = low_y + height - 1

/// Drops the bounds back to the whole z-level, so cleanup covers the cordon too
/datum/space_level/proc/reset_bounds()
	low_x = null
	low_y = null
	high_x = null
	high_y = null

/**
 * Fills everything outside the bounded region with cordon turfs. No-op when the
 * bounds already cover the whole level.
 */
/datum/space_level/proc/place_cordon()
	if(isnull(low_x))
		return
	if(low_x <= 1 && low_y <= 1 && high_x >= world.maxx && high_y >= world.maxy)
		return

	// Bottom strip (below the planet)
	if(low_y > 1)
		for(var/turf/cordon_turf as anything in block(locate(1, 1, z_value), locate(world.maxx, low_y - 1, z_value)))
			new /turf/cordon(cordon_turf)
			CHECK_TICK
	// Top strip (above the planet)
	if(high_y < world.maxy)
		for(var/turf/cordon_turf as anything in block(locate(1, high_y + 1, z_value), locate(world.maxx, world.maxy, z_value)))
			new /turf/cordon(cordon_turf)
			CHECK_TICK
	// Left strip (beside the planet, between the top and bottom strips)
	if(low_x > 1)
		for(var/turf/cordon_turf as anything in block(locate(1, low_y, z_value), locate(low_x - 1, high_y, z_value)))
			new /turf/cordon(cordon_turf)
			CHECK_TICK
	// Right strip
	if(high_x < world.maxx)
		for(var/turf/cordon_turf as anything in block(locate(high_x + 1, low_y, z_value), locate(world.maxx, high_y, z_value)))
			new /turf/cordon(cordon_turf)
			CHECK_TICK

/datum/space_level/proc/get_block()
	if(isnull(low_x))
		low_x = 1
		low_y = 1
		high_x = world.maxx
		high_y = world.maxy
	return block(locate(low_x,low_y,z_value), locate(high_x,high_y,z_value))

/datum/space_level/proc/clear_reservation()
	// Cleanup has to cover the cordon as well as the planet, so drop the bounds first
	reset_bounds()

	var/area/space_area = GLOB.areas_by_type[world.area]

	var/list/turf/block_turfs = get_block()

	for(var/turf/turf as anything in block_turfs)
		// don't waste time trying to qdelete the lighting object
		for(var/datum/thing in (turf.contents - turf.lighting_object))
			qdel(thing)
			// DO NOT CHECK_TICK HERE. IT CAN CAUSE ITEMS TO GET LEFT BEHIND
			// THIS IS REALLY IMPORTANT FOR CONSISTENCY. SORRY ABOUT THE LAG SPIKE

	for(var/turf/turf as anything in block_turfs)
		// Reset turf
		turf.empty(RESERVED_TURF_TYPE, RESERVED_TURF_TYPE, null, CHANGETURF_IGNORE_AIR|CHANGETURF_DEFER_CHANGE)
		// Reset area
		var/area/old_area = get_area(turf)
		turf.change_area(old_area, space_area)
		CHECK_TICK

	for(var/turf/turf as anything in block_turfs)
		turf.AfterChange(CHANGETURF_IGNORE_AIR)

		// we don't need to smooth anything in the reserve, because it's empty, nor do we need to check its starlight.
		// only the sides need to do that. this saved ~4-5% of reservation clear times in testing
		if(turf.x != low_x && turf.x != high_x && turf.y != low_y && turf.y != high_y)
			continue

		QUEUE_SMOOTH(turf)
		QUEUE_SMOOTH_NEIGHBORS(turf)
		CHECK_TICK

/// Clears contents and resets turfs to uninitialized /turf/open/space/basic
/// This bypasses ChangeTurf so turfs remain uninitialized and unbuildable
/datum/space_level/proc/clear_to_uninitialized_space()
	// Cleanup has to cover the cordon as well as the planet, so drop the bounds first
	reset_bounds()

	var/area/space_area = GLOB.areas_by_type[world.area]
	var/list/turf/block_turfs = get_block()

	// Delete all contents (except lighting objects, dead mobs, landmarks)
	var/static/list/ignored_atoms = typecacheof(list(/mob/dead, /obj/effect/landmark, /obj/docking_port))
	for(var/turf/T as anything in block_turfs)
		for(var/atom/movable/AM in T.contents)
			if(AM == T.lighting_object)
				continue
			if(ignored_atoms[AM.type])
				continue
			qdel(AM)

	// Replace turfs with uninitialized space - bypass ChangeTurf entirely
	for(var/turf/T as anything in block_turfs)
		// Reset area first
		var/area/old_area = get_area(T)
		if(old_area != space_area)
			T.change_area(old_area, space_area)
		// Create uninitialized space turf directly (bypasses ChangeTurf which would init it)
		new /turf/open/space/basic(T)
		CHECK_TICK

/**
 * Force-initializes any uninitialized turfs in a block (i.e. /turf/open/space/basic,
 * whose New() skips initialization as a map-loader optimization). Players can't
 * interact with uninitialized turfs - no throwing, building, etc. - so any space
 * handed to players must pass through here.
 */
/proc/initialize_uninitialized_block_turfs(turf/bottom_left, turf/top_right)
	if(!bottom_left || !top_right)
		return
	if(!SSatoms.initialized) // roundstart init will sweep every atom in world anyway
		return
	var/list/to_init = list()
	for(var/turf/tile as anything in block(bottom_left, top_right))
		if(!(tile.flags_1 & INITIALIZED_1))
			to_init += tile
	if(length(to_init))
		SSatoms.InitializeAtoms(to_init)

/// Initializes every uninitialized turf on the level - see initialize_uninitialized_block_turfs
/datum/space_level/proc/initialize_space_turfs()
	initialize_uninitialized_block_turfs(locate(low_x, low_y, z_value), locate(high_x, high_y, z_value))

/**
 * Whether any client-having player is standing within a turf reservation's bounds.
 * Reservations share their z-level with other reservations (space ruins, landable
 * meteor fields, player outposts, ...), so a level-wide clients_by_zlevel check would
 * false-positive whenever a neighbouring reservation has visitors - this scopes
 * strictly to the given reservation's own footprint. Shared by space_ruin.dm and
 * events.dm's landable field cleanup guards.
 */
/proc/turf_reservation_has_players(datum/turf_reservation/reservation)
	if(!reservation)
		return FALSE

	var/turf/bottom_left = reservation.bottom_left_turfs[1]
	if(!bottom_left)
		return FALSE

	var/min_x = bottom_left.x
	var/min_y = bottom_left.y
	var/max_x = min_x + reservation.width - 1
	var/max_y = min_y + reservation.height - 1
	var/res_z = bottom_left.z

	for(var/mob/player in SSmobs.clients_by_zlevel[res_z])
		var/turf/player_turf = get_turf(player)
		if(!player_turf)
			continue
		if(player_turf.x >= min_x && player_turf.x <= max_x && player_turf.y >= min_y && player_turf.y <= max_y)
			return TRUE

	return FALSE

/datum/space_level/proc/fill_in(turf/turf_type, area/area_override)
	var/area/area_to_use = null
	if(area_override)
		if(ispath(area_override))
			area_to_use = new area_override
		else
			area_to_use = area_override

	if(area_to_use)
		for(var/turf/iterated_turf as anything in get_block())
			var/area/old_area = get_area(iterated_turf)
			iterated_turf.change_area(old_area, area_to_use)
			CHECK_TICK
			if(QDELETED(src))
				return
		area_to_use.reg_in_areas_in_z()

	if(turf_type)
		for(var/turf/iterated_turf as anything in get_block())
			iterated_turf.ChangeTurf(turf_type, turf_type)
			CHECK_TICK
			if(QDELETED(src))
				return

	return area_to_use
