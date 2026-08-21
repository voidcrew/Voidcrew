#define RANDOM_UPPER_X 200
#define RANDOM_UPPER_Y 200

#define RANDOM_LOWER_X 50
#define RANDOM_LOWER_Y 50

/// TRUE when a turf lies inside an inclusive list(low_x, low_y, high_x, high_y) rect.
#define TURF_IN_RIVER_BOUNDS(T, B) (!isnull(T) && (T).x >= (B)[1] && (T).y >= (B)[2] && (T).x <= (B)[3] && (T).y <= (B)[4])

/**
 * Lays one river turf down over `target`, and returns it.
 *
 * The raw `new turf_type(target)` / `ChangeTurf(..., CHANGETURF_SKIP)` this file used
 * everywhere is a bare BYOND turf swap: the replacement is constructed straight over the
 * old turf and the old turf's Destroy() never runs. Everything that Destroy() would have
 * freed is simply dropped instead - and a dropped /datum/light_source is not merely
 * garbage, it is UNCOLLECTABLE, because it and the lighting corners it applied to hold
 * each other (light.effect_str[corner] <-> corner.affecting) and BYOND is pure
 * refcounting. The turf's four corner refs are dropped with it, so the replacement mints
 * fresh corners for the same vertices and the old ones stay pinned by the orphan.
 *
 * That was sound for the only caller this code had when it was written - lavaland at
 * mapload, where nothing is initialized and no turf is lit yet - and the comments here
 * said so. Voidcrew planets generate MID-ROUND, over ground the terrain pass has already
 * initialized and (on a lava planet) lit, so every river tile leaked one light source plus
 * its corners for the rest of the round: measured at ~800 per planet, ~3,200 per
 * four-planet z-level per build, on a 32-bit DreamDaemon with a 4 GB ceiling.
 *
 * The mapload fast path is kept exactly as it was, gated on the same `SSlighting.initialized`
 * test place_biome_turf() in PlanetGenerator.dm already uses for the same reason.
 *
 * `new_baseturfs` is the caller's explicit override; without one the turf gets the stack
 * its own type declares, which is what the raw `new` always produced (ChangeTurf would
 * otherwise inherit the ground it is replacing).
 */
/proc/place_river_turf(turf/target, turf/turf_type, new_baseturfs)
	if(isnull(target) || isnull(turf_type))
		return null
	if(!SSlighting.initialized)
		var/turf/raw_turf = new turf_type(target)
		if(new_baseturfs)
			raw_turf.baseturfs = new_baseturfs
		return raw_turf
	var/turf/placed = target.ChangeTurf(turf_type, flags = CHANGETURF_IGNORE_AIR)
	if(isnull(placed))
		return null
	placed.assemble_baseturfs(new_baseturfs || initial(placed.baseturfs) || placed.type)
	return placed

/**
 * Carves a handful of randomly pathing rivers of turf_type across a planet surface.
 *
 * min_x/min_y/max_x/max_y bound where the river NODES are dropped. `bounds` bounds where
 * the river is allowed to WALK and SPREAD: list(low_x, low_y, high_x, high_y), inclusive,
 * or null for the unclamped behaviour every roundstart caller has always had. A z-level
 * can carry several tenants side by side now (/datum/map_footprint), and the area
 * whitelist alone cannot hold a river in - it is type-based, and every planet's cave area
 * is the same type - so a river reaching the footprint edge would carve straight into the
 * neighbour's ground.
 */
/proc/spawn_planet_rivers(target_z, nodes, turf_type, list/whitelist_areas, min_x = RANDOM_LOWER_X, min_y = RANDOM_LOWER_Y, max_x = RANDOM_UPPER_X, max_y = RANDOM_UPPER_Y, list/bounds = null)
	if(length(bounds) < 4)
		bounds = null // A malformed rect must never be treated as "clamp to nothing".
	var/list/river_nodes = list()
	var/num_spawned = 0
	var/width = max_x - min_x
	var/height = max_y - min_y
	var/turf/corner = locate(min_x, min_y, target_z)
	var/list/possible_locs = CORNER_BLOCK(corner, width, height)
	while(num_spawned < nodes && possible_locs.len)
		var/turf/T = pick(possible_locs)
		var/area/A = get_area(T)
		var/valid_area = FALSE
		for(var/whitelist_area in whitelist_areas)
			if(istype(A, whitelist_area))
				valid_area = TRUE
				break
		if(!valid_area || (T.turf_flags & NO_LAVA_GEN))
			possible_locs -= T
		else
			river_nodes += new /obj/effect/landmark/river_waypoint(T)
			num_spawned++
		valid_area = FALSE
	//make some randomly pathing rivers
	for(var/obj/effect/landmark/river_waypoint/waypoints as anything in river_nodes)
		if (waypoints.z != target_z || waypoints.connected)
			continue
		waypoints.connected = TRUE
		// Raw swap only while nothing is initialized - see place_river_turf()
		var/turf/cur_turf = get_turf(waypoints)
		cur_turf = place_river_turf(cur_turf, turf_type)
		var/turf/target_turf = get_turf(pick(river_nodes - waypoints))
		if(!target_turf)
			break
		var/detouring = FALSE
		var/cur_dir = get_dir(cur_turf, target_turf)
		while(cur_turf != target_turf)

			if(detouring) //randomly snake around a bit
				if(prob(20))
					detouring = FALSE
					cur_dir = get_dir(cur_turf, target_turf)
			else if(prob(20))
				detouring = TRUE
				if(prob(50))
					cur_dir = turn(cur_dir, 45)
				else
					cur_dir = turn(cur_dir, -45)
			else
				cur_dir = get_dir(cur_turf, target_turf)

			var/turf/stepped_turf = get_step(cur_turf, cur_dir)
			// A snaking detour that would leave the rect is refused outright: the step is
			// discarded and the river aims straight back at its target node, which is always
			// inside the rect, so both coordinates move back inward and the walk terminates.
			if(bounds && !TURF_IN_RIVER_BOUNDS(stepped_turf, bounds))
				detouring = FALSE
				cur_dir = get_dir(cur_turf, target_turf)
				stepped_turf = get_step(cur_turf, cur_dir)
				if(!TURF_IN_RIVER_BOUNDS(stepped_turf, bounds))
					break // Cornered; nothing left to carve without writing outside the rect.
			cur_turf = stepped_turf
			var/area/new_area = get_area(cur_turf)
			var/valid_area = FALSE
			for(var/whitelist_area in whitelist_areas)
				if(istype(new_area, whitelist_area))
					valid_area = TRUE
					break
			if(!valid_area || (cur_turf.turf_flags & NO_LAVA_GEN)) //Rivers will skip ruins
				detouring = FALSE
				cur_dir = get_dir(cur_turf, target_turf)
				var/turf/skipped_turf = get_step(cur_turf, cur_dir)
				if(bounds && !TURF_IN_RIVER_BOUNDS(skipped_turf, bounds))
					break // Same rule for the skip-over step.
				cur_turf = skipped_turf
				continue
			else
				// Raw swap only while nothing is initialized - see place_river_turf()
				var/turf/river_turf = place_river_turf(cur_turf, turf_type)
				river_turf.SpreadAcrossPlanet(25, 11, whitelist_areas, bounds)

	for(var/waypoints_spawned in river_nodes)
		qdel(waypoints_spawned)


/**
 * Bleeds this turf's type outwards a tile at a time, losing probability as it goes.
 *
 * `bounds` is an inclusive list(low_x, low_y, high_x, high_y) the spread may not leave,
 * or null for the unclamped behaviour. See spawn_planet_rivers() - RANGE_TURFS does not
 * know about footprints, so without this the last ring of a river's spread writes over
 * the co-tenant next door.
 */
/turf/proc/SpreadAcrossPlanet(probability = 30, prob_loss = 25, list/whitelisted_areas, list/bounds = null)
	if(probability <= 0)
		return
	if(length(bounds) < 4)
		bounds = null
	var/list/cardinal_turfs = list()
	var/list/diagonal_turfs = list()
	var/logged_turf_type
	for(var/turf/canidate as anything in RANGE_TURFS(1, src) - src)
		if(!canidate || (canidate.density && !ismineralturf(canidate)) || isindestructiblefloor(canidate))
			continue

		if(bounds && !TURF_IN_RIVER_BOUNDS(canidate, bounds))
			continue

		var/area/new_area = get_area(canidate)
		var/area_found = FALSE
		for(var/whitelisted_area in whitelisted_areas)
			if(istype(new_area, whitelisted_area))
				area_found = TRUE
		if((!area_found) || (canidate.turf_flags & NO_LAVA_GEN))
			continue

		if(!logged_turf_type && ismineralturf(canidate))
			var/turf/closed/mineral/mineral_canidate = canidate
			logged_turf_type = mineral_canidate.turf_type

		if(get_dir(src, canidate) in GLOB.cardinals)
			cardinal_turfs += canidate
		else
			diagonal_turfs += canidate

	// place_river_turf() decides between the raw swap this code used to do unconditionally
	// and a real ChangeTurf. The old blanket "safe because this only runs during mapload"
	// comment stopped being true the moment planets started generating mid-round; see the
	// proc's doc comment for what the raw swap leaks when the ground is already lit.
	for(var/turf/cardinal_canidate as anything in cardinal_turfs) //cardinal turfs are always changed but don't always spread
		if(!istype(cardinal_canidate, logged_turf_type) && place_river_turf(cardinal_canidate, type, baseturfs) && prob(probability))
			cardinal_canidate.SpreadAcrossPlanet(probability - prob_loss, prob_loss, whitelisted_areas, bounds)

	for(var/turf/diagonal_canidate as anything in diagonal_turfs) //diagonal turfs only sometimes change, but will always spread if changed
		if(!istype(diagonal_canidate, logged_turf_type) && prob(probability) && place_river_turf(diagonal_canidate, type, baseturfs))
			diagonal_canidate.SpreadAcrossPlanet(probability - prob_loss, prob_loss, whitelisted_areas, bounds)
		else if(ismineralturf(diagonal_canidate))
			var/turf/closed/mineral/diagonal_mineral = diagonal_canidate
			place_river_turf(diagonal_mineral, diagonal_mineral.turf_type)

#undef RANDOM_UPPER_X
#undef RANDOM_UPPER_Y

#undef RANDOM_LOWER_X
#undef RANDOM_LOWER_Y

#undef TURF_IN_RIVER_BOUNDS
