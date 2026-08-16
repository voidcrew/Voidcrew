/datum/map_generator/cave_generator/asteroid
	open_turf_types = list(/turf/open/misc/asteroid/airless = 1)
	closed_turf_types =  list(/turf/closed/mineral/random = 1)

	feature_spawn_chance = 1
	feature_spawn_list = list(/obj/structure/geyser/random = 1)
	mob_spawn_list = list(/mob/living/basic/mining/goliath/ancient = 25, /obj/structure/spawner/mining/goliath = 30, \
		/mob/living/basic/mining/basilisk = 25, /obj/structure/spawner/mining = 30, \
		/mob/living/basic/mining/hivelord = 25, /obj/structure/spawner/mining/hivelord = 30, \
		SPAWN_MEGAFAUNA = 4, /mob/living/basic/mining/goldgrub = 10)
	//flora_spawn_list = list(/obj/structure/flora/ash/space/voidmelon = 2)

	initial_closed_chance = 55
	smoothing_iterations = 50
	birth_limit = 4
	death_limit = 3
	mob_spawn_chance = 6

/datum/map_generator/cave_generator/asteroid/generate_terrain(list/turfs)
	var/maxx
	var/maxy
	var/minx
	var/miny
	for(var/turf/T as anything in turfs)
		//Gets the min/max X value
		if(T.x < minx || !minx)
			minx = T.x
		else if(T.x > maxx)
			maxx = T.x

		//Gets the min/max Y value
		if(T.y < miny || !miny)
			miny = T.y
		else if(T.y > maxy)
			maxy = T.y
		// Runs mid-round over a whole encounter level - yield (see worldgen_yield())
		SSovermap.worldgen_yield()

	var/midx = minx + (maxx - minx) / 2
	var/midy = miny + (maxy - miny) / 2
	var/radius = min(maxx - minx, maxy - miny) / 2

	var/list/turfs_to_gen = list()
	var/area/centcom/asteroid/voidcrew/asteroid_area = GLOB.areas_by_type[/area/centcom/asteroid/voidcrew] || new
	for(var/turf/T as anything in turfs)
		var/randradius = rand(radius - 2, radius + 2) * rand(radius - 2, radius + 2)
		if((T.y - midy) ** 2 + (T.x - midx) ** 2 >= randradius)
			continue
		turfs_to_gen += T
		var/area/old_area = get_area(T)
		T.change_area(old_area, asteroid_area)
		SSovermap.worldgen_yield()

	return ..(turfs_to_gen)

/**
 * Landable meteor storm rock field generator (see events.dm /obj/structure/overmap/event/meteor).
 *
 * Same recipe as /datum/map_generator/cave_generator/asteroid above (cellular-automata
 * rock/sand mix, mining mob/geyser spawn tables, shared /area/centcom/asteroid/voidcrew)
 * but scattered as several independent blobs instead of one solid field, with real vacuum
 * left between and around them - "an asteroid field", not a single asteroid. Ore seeding
 * itself is handled separately by seed_asteroid_ore_block() (events.dm) after generation,
 * the way space ruin asteroid signals used to be seeded before that category was retired.
 *
 * Unlike /datum/map_generator/cave_generator/asteroid, weighted_* vars are used (not the
 * expanded open_turf_types/closed_turf_types/mob_spawn_list/feature_spawn_list directly) -
 * New() unconditionally rebuilds those from the weighted_* lists, so setting the expanded
 * vars straight would just get silently overwritten by the base class defaults.
 */
/datum/map_generator/cave_generator/asteroid_field
	name = "Asteroid Field Generator"
	weighted_open_turf_types = list(/turf/open/misc/asteroid/airless = 1)
	weighted_closed_turf_types = list(/turf/closed/mineral/random = 1)

	feature_spawn_chance = 1
	weighted_feature_spawn_list = list(/obj/structure/geyser/random = 1)
	weighted_mob_spawn_list = list(/mob/living/basic/mining/goliath/ancient = 25, /obj/structure/spawner/mining/goliath = 30, \
		/mob/living/basic/mining/basilisk = 25, /obj/structure/spawner/mining = 30, \
		/mob/living/basic/mining/hivelord = 25, /obj/structure/spawner/mining/hivelord = 30, \
		/mob/living/basic/mining/goldgrub = 10)

	initial_closed_chance = 55
	smoothing_iterations = 50
	birth_limit = 4
	death_limit = 3
	// Sparse ambience only: the real danger comes from the zone-scaled mob packs
	// the meteor event scatters after generation (events.dm populate_field_extras)
	mob_spawn_chance = 1

	/// Number of scattered rock blobs to carve - minor/majour subtypes below scale this with severity
	var/blob_count_min = EVENT_FIELD_MIN_BLOBS
	var/blob_count_max = EVENT_FIELD_MAX_BLOBS
	/// Radius bounds for each blob - higher severity fields contain larger rocks as well as more of them
	var/blob_radius_min = EVENT_FIELD_BLOB_RADIUS_MIN
	var/blob_radius_max = EVENT_FIELD_BLOB_RADIUS_MAX

/datum/map_generator/cave_generator/asteroid_field/minor
	blob_count_min = 22
	blob_count_max = 28
	blob_radius_min = 4
	blob_radius_max = 7

/datum/map_generator/cave_generator/asteroid_field/majour
	blob_count_min = 46
	blob_count_max = 58
	blob_radius_min = 6
	blob_radius_max = 11

/**
 * Carves several jittered-radius circular blobs across the supplied turf set (instead of
 * AsteroidCaves.dm's single field above) and runs the parent cave_generator's CA-based
 * open/closed terrain pass only across those blobs. Respecting the supplied set lets the
 * caller cut non-rectangular ship-berth holes out of the field; everything else is left as
 * real vacuum between and around the rock. Returns the unique turfs actually generated, so
 * the caller can pass the exact same list to populate_terrain() without re-scanning the
 * shared /area/centcom/asteroid/voidcrew (which may also contain turfs from other,
 * currently-loaded fields).
 */
/datum/map_generator/cave_generator/asteroid_field/generate_terrain(list/turfs, area/generate_in)
	var/list/turfs_to_gen = list()
	if(!length(turfs))
		return turfs_to_gen

	var/turf/first_turf = turfs[1]
	var/z = first_turf.z
	var/list/allowed_turfs = list()
	for(var/turf/allowed_turf as anything in turfs)
		allowed_turfs[allowed_turf] = TRUE
		SSovermap.worldgen_yield()
	var/list/selected_turfs = list()

	var/maxx
	var/maxy
	var/minx
	var/miny
	for(var/turf/T as anything in turfs)
		if(T.x < minx || !minx)
			minx = T.x
		else if(T.x > maxx)
			maxx = T.x
		if(T.y < miny || !miny)
			miny = T.y
		else if(T.y > maxy)
			maxy = T.y
		SSovermap.worldgen_yield()

	var/blob_count = rand(blob_count_min, blob_count_max)
	var/area/centcom/asteroid/voidcrew/asteroid_area = GLOB.areas_by_type[/area/centcom/asteroid/voidcrew] || new

	for(var/i in 1 to blob_count)
		var/radius = rand(blob_radius_min, blob_radius_max)
		if((maxx - minx) <= radius * 2 || (maxy - miny) <= radius * 2)
			continue // block too small for this blob, skip rather than clamp into overlap
		var/turf/blob_center = pick(turfs)
		var/center_x = blob_center.x
		var/center_y = blob_center.y

		for(var/turf/candidate as anything in block(
			locate(max(minx, center_x - radius), max(miny, center_y - radius), z),
			locate(min(maxx, center_x + radius), min(maxy, center_y + radius), z)))
			if(!allowed_turfs[candidate] || selected_turfs[candidate])
				continue
			var/jittered_radius = rand(radius - 1, radius + 1)
			if((candidate.x - center_x) ** 2 + (candidate.y - center_y) ** 2 > jittered_radius ** 2)
				continue
			selected_turfs[candidate] = TRUE
			var/area/old_area = get_area(candidate)
			candidate.change_area(old_area, asteroid_area)
			turfs_to_gen += candidate
		// A majour field carves ~60 blobs over thousands of turfs mid-round - yield
		SSovermap.worldgen_yield()

	if(!length(turfs_to_gen))
		return turfs_to_gen

	asteroid_area.reg_in_areas_in_z()
	..(turfs_to_gen, asteroid_area)
	return turfs_to_gen
