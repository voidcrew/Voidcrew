// Boot hooks for the Frontier, the one permanent planet. It loads in SSmapping.loadWorld() as a
// LoadGroup pair (cave below, surface above) on the dormant preloaded path; these procs close that
// path's gaps in boot order:
// 1. frontier_before_ruins() from setup_ruins(): the band, the two fauna trackers, the dock strip,
//    the homestead stamp and its keep-out ring, the homestead controller.
// 2. frontier_after_terrain() from setup_rivers(), after terrain and before population: the ladders,
//    then the ruins.
// 3. frontier_attach_cave() from SSovermap.setup_planets(): the cave footprint, the trackers'
//    footprints, then homestead_after_atoms().

/obj/structure/overmap/planet
	/// The Frontier's cave level, owned by its planet
	var/datum/map_footprint/cave_footprint

/// The Frontier's record in SSmapping.planets, or null when it was not built this round
/proc/frontier_record()
	for(var/planet_key in SSmapping.planets)
		var/list/record = SSmapping.planets[planet_key]
		if(islist(record) && record["type"] == /datum/overmap/planet/frontier)
			return record
	return null

/// The Frontier's surface z, or 0
/proc/frontier_surface_z()
	var/list/record = frontier_record()
	return record ? record["z"] : 0

/// The Frontier's cave z, or 0
/proc/frontier_cave_z()
	var/list/record = frontier_record()
	return record ? record["z"] - 1 : 0

/// Whether `thing` stands on either of the Frontier's two levels
/proc/is_frontier_turf(atom/thing)
	var/turf/here = get_turf(thing)
	if(!here)
		return FALSE
	var/surface_z = frontier_surface_z()
	return surface_z && (here.z == surface_z || here.z == surface_z - 1)

/// Stamps the homestead and its keep-out rings before ruins seed
/proc/frontier_before_ruins(list/record)
	if(!islist(record) || record["type"] != /datum/overmap/planet/frontier)
		return
	var/surface_z = record["z"]
	var/cave_z = surface_z - 1
	if(!surface_z || !cave_z)
		return
	// Green, set where population reads it: the areas this planet's two levels were loaded with
	for(var/z_level in list(surface_z, cave_z))
		var/area/overmap_encounter/planetoid/ground = get_area(locate(1, 1, z_level))
		if(istype(ground))
			ground.zone_band = ZONE_GREEN
	// Fauna managed from the start: population files its turfs with these instead of spawning them
	// for the whole round. Their footprints come in frontier_attach_cave().
	if(!SSplanet_mobs.tracked_planets["frontier_surface"])
		SSplanet_mobs.register_planet("frontier_surface", surface_z, null, ZONE_GREEN)
	if(!SSplanet_mobs.tracked_planets["frontier_cave"])
		SSplanet_mobs.register_planet("frontier_cave", cave_z, null, ZONE_GREEN)
	frontier_reserve_dock_strip(surface_z)

	var/datum/map_template/ruin/frontier_homestead/template = new
	var/turf/centre = locate(round(world.maxx / 2) + 1, round(world.maxy / 2) + 1, surface_z)
	var/turf/placed = template.try_to_place(surface_z, typecacheof(/area/overmap_encounter/planetoid/frontier), centre, TRUE)
	if(!placed)
		log_mapping("Frontier: the homestead could not be stamped at [AREACOORD(centre)]")
		return
	var/low_x = placed.x - round(template.width / 2)
	var/low_y = placed.y - round(template.height / 2)
	var/list/bounds = list(low_x, low_y, low_x + template.width - 1, low_y + template.height - 1, surface_z)
	var/ring = BACKGROUND_HOMESTEAD_RING
	var/turf/ring_low = locate(max(1, bounds[1] - ring), max(1, bounds[2] - ring), surface_z)
	var/turf/ring_high = locate(min(world.maxx, bounds[3] + ring), min(world.maxy, bounds[4] + ring), surface_z)
	for(var/turf/kept as anything in block(ring_low, ring_high))
		kept.turf_flags |= NO_RUINS
	CHECK_TICK
	if(GLOB.homestead)
		qdel(GLOB.homestead)
	GLOB.homestead = new /datum/homestead(bounds, surface_z, cave_z)
	log_mapping("Frontier: homestead stamped at [AREACOORD(placed)]")

/**
 * The berths' strip along the bottom of the surface, NO_RUINS before ruins seed. The planet marker
 * that owns reserve_dock_strip() does not exist yet at boot; the berths sit on the whole level's low
 * edge, so this is the same rectangle get_dock_strip_top_y() names for a whole-level footprint.
 */
/proc/frontier_reserve_dock_strip(surface_z)
	var/strip_top = min(world.maxy, 1 + RESERVE_DOCK_DEFAULT_PADDING + RESERVE_DOCK_MAX_SIZE_SHORT + PLANET_DOCK_HOSTILE_CLEARANCE)
	for(var/turf/reserved as anything in block(locate(1, 1, surface_z), locate(world.maxx, strip_top, surface_z)))
		reserved.turf_flags |= NO_RUINS
	CHECK_TICK

/**
 * Once the ground is generated: the cave ladders, then the ruins. The Frontier seeds its ruins here,
 * after terrain, as a dynamic planet does, and not before it as the other preloaded planets do:
 * seeded first, every ruin tile mapped in a planet area (a ruin's yard, a cave around it) is
 * generated over afterwards, burying what the ruin put there.
 */
/proc/frontier_after_terrain(list/record)
	if(!islist(record) || record["type"] != /datum/overmap/planet/frontier)
		return
	var/surface_z = record["z"]
	var/turf/house = GLOB.homestead?.centre || locate(round(world.maxx / 2) + 1, round(world.maxy / 2) + 1, surface_z)
	var/placed = spawn_frontier_cave_ladders(surface_z, surface_z - 1, house)
	log_mapping("Frontier: [placed] cave entrance\s")
	generate_planet_ruins(/datum/planet/frontier, list(surface_z, surface_z - 1), list(/area/overmap_encounter/planetoid/frontier))

/// Gives the planet its cave footprint and trackers
/proc/frontier_attach_cave(obj/structure/overmap/planet/planet, datum/map_zone/mapzone, list/record)
	if(!planet || !mapzone || !islist(record) || record["type"] != /datum/overmap/planet/frontier)
		return
	var/surface_z = record["z"]
	var/datum/space_level/cave_level = SSmapping.get_level(surface_z - 1)
	if(cave_level && !planet.cave_footprint)
		// After the surface: docks, drop pods and ghost jumps all read z_levels[1]
		if(!(cave_level in mapzone.z_levels))
			mapzone.add_space_level(cave_level)
		var/datum/map_footprint/cave = new(mapzone, MAP_TENANT_CLASS_SOLO, 1, planet)
		cave.attach_level(cave_level)
		cave.planetary_faction = planet.footprint?.planetary_faction
		cave.baseturf = planet.footprint?.baseturf
		planet.cave_footprint = cave
		cave.add_planetary_faction_to_existing_mobs()

	var/datum/planet_mob_tracker/surface_tracker = SSplanet_mobs.tracked_planets["frontier_surface"]
	if(!surface_tracker)
		surface_tracker = SSplanet_mobs.register_planet("frontier_surface", surface_z, null, ZONE_GREEN)
	surface_tracker.footprint = planet.footprint
	var/datum/planet_mob_tracker/cave_tracker = SSplanet_mobs.tracked_planets["frontier_cave"]
	if(!cave_tracker)
		cave_tracker = SSplanet_mobs.register_planet("frontier_cave", surface_z - 1, null, ZONE_GREEN)
	cave_tracker.footprint = planet.cave_footprint

	// No fauna banked inside the homestead's keep-out ring: the family would hide all round
	var/datum/homestead/homestead = GLOB.homestead
	if(homestead && length(homestead.bounds) >= 5)
		var/ring = BACKGROUND_HOMESTEAD_RING
		for(var/turf/candidate as anything in surface_tracker.surface_spawn_turfs.Copy())
			if(candidate.z == homestead.bounds[5] && candidate.x >= homestead.bounds[1] - ring && candidate.x <= homestead.bounds[3] + ring \
				&& candidate.y >= homestead.bounds[2] - ring && candidate.y <= homestead.bounds[4] + ring)
				surface_tracker.surface_spawn_turfs -= candidate
	homestead_after_atoms()
