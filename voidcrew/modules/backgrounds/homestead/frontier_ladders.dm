/// Backgrounds: owned by P6. See data/backgrounds/spec.md.

/// Random darts thrown at the surface before giving up on more entrances
#define FRONTIER_LADDER_DARTS 400

/**
 * Cave entrances between the Frontier's surface and its cave level: the dart-thrower from the old
 * planet pairs (git 17cd4a5d69f, voidcrew/mapping/_mapping.dm), never the Poisson version, which the
 * shipped rust-g lacks. Darts land BACKGROUND_CAVE_LADDER_DIST_MIN to _MAX from `house`, at least
 * BACKGROUND_CAVE_LADDER_SPACING apart, where both ends are open ground of their own biome. It aims
 * for BACKGROUND_CAVE_LADDERS_WANT and stops at _MAX; under _MIN it throws again at half the spacing.
 *
 * Runs after terrain and before population, so each ladder turf and its ring are flagged NO_RUINS
 * before population banks a nest there. At boot the two ladders link themselves in LateInitialize
 * (they are stacked, and the pair is linked Up/Down); later they are linked here.
 *
 * Returns how many entrances were placed.
 */
/proc/spawn_frontier_cave_ladders(surface_z, cave_z, turf/house)
	if(!surface_z || !cave_z || !house)
		return 0
	var/list/turf/placed_at = list()
	var/spacing = BACKGROUND_CAVE_LADDER_SPACING
	for(var/pass in 1 to 2)
		var/spacing_squared = spacing * spacing
		for(var/attempt in 1 to FRONTIER_LADDER_DARTS)
			if(length(placed_at) >= BACKGROUND_CAVE_LADDERS_WANT)
				break
			CHECK_TICK
			var/distance = rand(BACKGROUND_CAVE_LADDER_DIST_MIN, BACKGROUND_CAVE_LADDER_DIST_MAX)
			var/bearing = rand(0, 359)
			var/candidate_x = round(house.x + distance * cos(bearing))
			var/candidate_y = round(house.y + distance * sin(bearing))
			if(candidate_x < 2 || candidate_y < 2 || candidate_x > world.maxx - 1 || candidate_y > world.maxy - 1)
				continue
			var/too_close = FALSE
			for(var/turf/existing as anything in placed_at)
				var/dx = existing.x - candidate_x
				var/dy = existing.y - candidate_y
				if((dx * dx) + (dy * dy) < spacing_squared)
					too_close = TRUE
					break
			if(too_close)
				continue
			// Both ends have to be walkable generated ground, or the entrance goes into rock
			var/turf/surface_turf = locate(candidate_x, candidate_y, surface_z)
			if(!frontier_ladder_ground_ok(surface_turf))
				continue
			var/turf/cave_turf = locate(candidate_x, candidate_y, cave_z)
			if(!frontier_ladder_ground_ok(cave_turf))
				continue
			var/obj/structure/ladder/cave/surface_ladder = new(surface_turf)
			var/obj/structure/ladder/cave/cave_ladder = new(cave_turf)
			// Before SSatoms, a link made here would be lost (its ladder hole initializes without
			// its ladder); LateInitialize finds the stacked partner by itself
			if(SSatoms.initialized != INITIALIZATION_INSSATOMS)
				surface_ladder.link_down(cave_ladder)
			for(var/turf/end as anything in list(surface_turf, cave_turf))
				end.turf_flags |= TURF_BLOCKS_POPULATE_TERRAIN_FLORAFEATURES
				for(var/turf/ring as anything in RANGE_TURFS(1, end))
					ring.turf_flags |= NO_RUINS
			placed_at += surface_turf
			if(length(placed_at) >= BACKGROUND_CAVE_LADDERS_MAX)
				break
		if(length(placed_at) >= BACKGROUND_CAVE_LADDERS_MIN)
			break
		spacing = round(spacing / 2)
	return length(placed_at)

/// Whether a ladder can stand on `ground`: open ground its biome generated, no river, no other ladder
/proc/frontier_ladder_ground_ok(turf/ground)
	if(!ground?.generating_biome || ground.planet_river)
		return FALSE
	if(!(ground.type in ground.generating_biome.open_turf_types))
		return FALSE
	return !(locate(/obj/structure/ladder) in ground)

#undef FRONTIER_LADDER_DARTS
