/datum/map_zone
	var/name = "Map Zone"
	var/id
	/// Is the mapzone currently used by a overmap encounter?
	var/taken = FALSE
	/// List of all z levels this map zone contains
	var/list/z_levels = list()

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
/// `throttled` = whether the sweep shares the queued worldgen job's tick budget;
/// pass FALSE from unqueued (flat-encounter) teardowns - see worldgen_yield().
/datum/map_zone/proc/clear_reservation(throttled = TRUE)
	for(var/datum/space_level/zlevel as anything in z_levels)
		SSweather.set_z_level_weather_trait(zlevel, null)
		zlevel.clear_reservation(throttled)

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

/**
 * Sets or clears a single z-level trait, keeping SSmapping's reverse index in step.
 *
 * Map zones are recycled, and the levels in them are NOT re-minted between occupants -
 * a reused level still carries whatever the last one registered. That is harmless for
 * flag traits nothing reads twice, but not for value traits like ZTRAIT_BASETURF, where
 * a leftover would leave a space encounter bottoming out in a previous planet's ground.
 * Pass a null value to remove the trait outright.
 */
/datum/space_level/proc/set_trait(trait, value)
	if(isnull(value))
		traits -= trait
		var/list/old_levels = SSmapping.z_trait_levels[trait]
		if(old_levels)
			old_levels -= z_value
		return
	traits[trait] = value
	var/list/trait_levels = SSmapping.z_trait_levels[trait]
	if(!trait_levels)
		trait_levels = list()
		SSmapping.z_trait_levels[trait] = trait_levels
	trait_levels |= list(z_value)

/// Drops the bounds back to the whole z-level, so cleanup covers the cordon too
/datum/space_level/proc/reset_bounds()
	low_x = null
	low_y = null
	high_x = null
	high_y = null

/**
 * Fills everything outside the bounded region with cordon turfs. No-op when the
 * bounds already cover the whole level.
 *
 * The cordon is flagged NO_RUINS: try_to_place() samples ruin spots across the whole
 * 255x255 level, so on a 128x128 planet ~3/4 of candidates are centered off the
 * footprint. The flag check breaks out on the first flagged turf it scans, where the
 * area-whitelist rejection only fires after walking the full footprint - this turns
 * most wasted samples from a ~thousand-turf scan into a nearly free one. Set here
 * rather than on /turf/cordon itself to keep the upstream type untouched; no staleness
 * risk on recycled zones, since clear_reservation() resets the whole level through
 * ChangeTurf, which drops the flag with the turf.
 */
/datum/space_level/proc/place_cordon()
	if(isnull(low_x))
		return
	if(low_x <= 1 && low_y <= 1 && high_x >= world.maxx && high_y >= world.maxy)
		return

	var/skipped_ship_turfs = 0
	// Bottom strip (below the planet)
	if(low_y > 1)
		for(var/turf/cordon_turf as anything in block(locate(1, 1, z_value), locate(world.maxx, low_y - 1, z_value)))
			skipped_ship_turfs += place_cordon_turf(cordon_turf)
			// Throttled yield, not CHECK_TICK - see worldgen_yield() in worldgen_queue.dm
			SSovermap.worldgen_yield()
	// Top strip (above the planet)
	if(high_y < world.maxy)
		for(var/turf/cordon_turf as anything in block(locate(1, high_y + 1, z_value), locate(world.maxx, world.maxy, z_value)))
			skipped_ship_turfs += place_cordon_turf(cordon_turf)
			// Throttled yield, not CHECK_TICK - see worldgen_yield() in worldgen_queue.dm
			SSovermap.worldgen_yield()
	// Left strip (beside the planet, between the top and bottom strips)
	if(low_x > 1)
		for(var/turf/cordon_turf as anything in block(locate(1, low_y, z_value), locate(low_x - 1, high_y, z_value)))
			skipped_ship_turfs += place_cordon_turf(cordon_turf)
			// Throttled yield, not CHECK_TICK - see worldgen_yield() in worldgen_queue.dm
			SSovermap.worldgen_yield()
	// Right strip
	if(high_x < world.maxx)
		for(var/turf/cordon_turf as anything in block(locate(high_x + 1, low_y, z_value), locate(world.maxx, high_y, z_value)))
			skipped_ship_turfs += place_cordon_turf(cordon_turf)
			// Throttled yield, not CHECK_TICK - see worldgen_yield() in worldgen_queue.dm
			SSovermap.worldgen_yield()

	if(skipped_ship_turfs)
		var/seal_warning = "place_cordon: a shuttle occupies [skipped_ship_turfs] turf(s) inside the cordon band on z[z_value]. Its turfs were left alone, but a hull should never be out here - planet lifecycle bug likely, and the ship is probably sealed in. Admin recovery needed."
		log_mapping(seal_warning)
		message_admins(seal_warning)

/**
 * Replaces a single out-of-bounds turf with cordon, unless a landed shuttle owns it.
 *
 * Ship turfs are never overwritten: a hull that has ended up in the cordon band got
 * there through a lifecycle bug (round 4: the derelict auto-crash placed a 10-hour
 * player hull in the band and the cordon sealed it in), and painting cordon over it
 * turns that bug into deleted player work. place_cordon() counts the skips and
 * raises the alarm once, after the sweep.
 *
 * Returns 1 when the turf was skipped for that reason, else 0.
 */
/datum/space_level/proc/place_cordon_turf(turf/cordon_turf)
	if(istype(cordon_turf.loc, /area/shuttle))
		return 1
	// NO_RUINS: see the doc comment on place_cordon() above
	var/turf/placed = new /turf/cordon(cordon_turf)
	placed.turf_flags |= NO_RUINS
	return 0

/datum/space_level/proc/get_block()
	if(isnull(low_x))
		low_x = 1
		low_y = 1
		high_x = world.maxx
		high_y = world.maxy
	return block(locate(low_x,low_y,z_value), locate(high_x,high_y,z_value))

/datum/space_level/proc/clear_reservation(throttled = TRUE)
	var/area/space_area = GLOB.areas_by_type[world.area]

	// Contents only ever exist inside the bounded region - the cordon around a small
	// planet is bare turf with nothing on it. The sweep below deliberately never yields,
	// so it stays scoped to the bounds instead of grinding through ~48k empty cordon
	// tiles that cannot possibly hold anything.
	for(var/turf/turf as anything in get_block())
		// don't waste time trying to qdelete the lighting object
		for(var/datum/thing in (turf.contents - turf.lighting_object))
			qdel(thing)
			// DO NOT CHECK_TICK HERE. IT CAN CAUSE ITEMS TO GET LEFT BEHIND
			// THIS IS REALLY IMPORTANT FOR CONSISTENCY. SORRY ABOUT THE LAG SPIKE

	// Resetting turfs and areas does have to cover the cordon, and that loop yields, so
	// widen to the whole level for it.
	reset_bounds()
	var/list/turf/block_turfs = get_block()

	for(var/turf/turf as anything in block_turfs)
		// Reset turf
		turf.empty(RESERVED_TURF_TYPE, RESERVED_TURF_TYPE, null, CHANGETURF_IGNORE_AIR|CHANGETURF_DEFER_CHANGE)
		// Reset area
		var/area/old_area = get_area(turf)
		turf.change_area(old_area, space_area)
		// Throttled yield, not CHECK_TICK - see worldgen_yield() in worldgen_queue.dm
		SSovermap.worldgen_yield(throttled)

	for(var/turf/turf as anything in block_turfs)
		turf.AfterChange(CHANGETURF_IGNORE_AIR)

		// we don't need to smooth anything in the reserve, because it's empty, nor do we need to check its starlight.
		// only the sides need to do that. this saved ~4-5% of reservation clear times in testing
		if(turf.x != low_x && turf.x != high_x && turf.y != low_y && turf.y != high_y)
			continue

		QUEUE_SMOOTH(turf)
		QUEUE_SMOOTH_NEIGHBORS(turf)
		// Throttled yield, not CHECK_TICK - see worldgen_yield() in worldgen_queue.dm
		SSovermap.worldgen_yield(throttled)

/// Clears contents and resets turfs to uninitialized /turf/open/space/basic
/// This bypasses ChangeTurf so turfs remain uninitialized and unbuildable
/datum/space_level/proc/clear_to_uninitialized_space()
	var/area/space_area = GLOB.areas_by_type[world.area]

	// Contents live inside the bounds; the cordon outside them is bare turf. Same reason
	// as clear_reservation() - this sweep doesn't yield, so don't widen it.
	var/static/list/ignored_atoms = typecacheof(list(/mob/dead, /obj/effect/landmark, /obj/docking_port))
	for(var/turf/T as anything in get_block())
		for(var/atom/movable/AM in T.contents)
			if(AM == T.lighting_object)
				continue
			if(ignored_atoms[AM.type])
				continue
			qdel(AM)

	// Turf replacement has to cover the cordon, and it yields, so widen for that
	reset_bounds()
	var/list/turf/block_turfs = get_block()

	// Replace turfs with uninitialized space - bypass ChangeTurf entirely
	for(var/turf/T as anything in block_turfs)
		// Reset area first
		var/area/old_area = get_area(T)
		if(old_area != space_area)
			T.change_area(old_area, space_area)
		// VOIDCREW EDIT: hand-run the lighting teardown ChangeTurf would have done.
		// Replacing the turf in place is a raw BYOND turf swap: the replacement starts with
		// null lighting vars and every ref to the old turf silently retargets to it, so the
		// old turf's lighting datums are simply dropped instead of freed.
		// - lighting_object: mirrors change_turf.dm's space_lit branch, which qdels it because
		//   /turf/open/space/basic is space_lit. Also drops it out of SSlighting.objects_queue.
		// - light: a planet-style /lit floor turf owns a /datum/light_source, and that source is
		//   cross-linked with its lighting corners (light.effect_str[corner] <-> corner.affecting).
		//   That is a reference cycle, which BYOND's refcounting can never collect - so without
		//   this every zone recycle leaks one source plus its corners per lit turf, permanently.
		//   qdel -> Destroy() -> remove_lum() is what empties both sides of the cycle; the corners
		//   themselves need no explicit qdel, since once the last source releases them the old
		//   turf's four corner refs are gone too and they fall to zero references.
		//   (/atom/Destroy() does exactly this QDEL_NULL - we are standing in for it.)
		if(T.lighting_object)
			qdel(T.lighting_object, force = TRUE)
		if(T.light)
			QDEL_NULL(T.light)
		// END VOIDCREW EDIT
		// Create uninitialized space turf directly (bypasses ChangeTurf which would init it)
		new /turf/open/space/basic(T)
		// Every caller is an unqueued flat-encounter/outpost teardown: never wait
		// behind a queued planet job - see worldgen_yield() in worldgen_queue.dm
		SSovermap.worldgen_yield(throttled = FALSE)

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

/// `throttled` = whether the fill shares the queued worldgen job's tick budget; the
/// queued planet build leaves it TRUE, unqueued encounter builds (empty space, ruin
/// signals via spawn_dynamic_encounter) pass FALSE - see worldgen_yield().
/datum/space_level/proc/fill_in(turf/turf_type, area/area_override, throttled = TRUE)
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
			// Throttled yield, not CHECK_TICK - see worldgen_yield() in worldgen_queue.dm
			SSovermap.worldgen_yield(throttled)
			if(QDELETED(src))
				return
		area_to_use.reg_in_areas_in_z()

	if(turf_type)
		for(var/turf/iterated_turf as anything in get_block())
			iterated_turf.ChangeTurf(turf_type, turf_type)
			// Throttled yield, not CHECK_TICK - see worldgen_yield() in worldgen_queue.dm
			SSovermap.worldgen_yield(throttled)
			if(QDELETED(src))
				return

	return area_to_use
