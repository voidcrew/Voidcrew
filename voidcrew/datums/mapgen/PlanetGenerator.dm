#define BIOME_RANDOM_SQUARE_DRIFT 2

/datum/map_generator/planet_generator
	var/name = "Planet Generator"
	/// Whether generation loops share the queued worldgen job's tick budget (see
	/// worldgen_yield()). Planet builds under the worldgen queue leave this TRUE;
	/// spawn_dynamic_encounter() clears it on the instances it drives - by design
	/// rule, a survey must never slow the loading of a ruin or empty space.
	var/throttled = TRUE
	var/mountain_height = 0.85
	var/perlin_zoom = 65
	var/initial_closed_chance = 45
	var/smoothing_iterations = 20
	var/birth_limit = 4
	var/death_limit = 3

/datum/map_generator/planet_generator/generate_terrain(list/turf/turfs, datum/planet/planet_type, is_cave, init_planet)
	. = ..()
	if(!planet_type)
		log_world("[name] planet generation failed!")
		return
	var/start_time = REALTIMEOFDAY

	var/height_seed = rand(0, 50000)
	var/humidity_seed = rand(0, 50000)
	var/heat_seed = rand(0, 50000)

	var/string_gen = rustg_cnoise_generate("[initial_closed_chance]", "[smoothing_iterations]", "[birth_limit]", "[death_limit]", "[world.maxx]", "[world.maxy]") //Generate the raw CA data

	var/area/overmap_encounter/planetoid/cave/cave_area
	var/caves = FALSE
	var/overworld = FALSE

	if (planet_type.cave_biomes && length(planet_type.cave_biomes) > 0)
		caves = TRUE
		cave_area = new
		cave_area.map_generator = src
	// This is needed because planet surfaces start as /area/overmap_encounter/planetoid/planet_type
	// If we're starting with an /area/overmap_encounter/planetoid/cave, we want to ignore overworld_biomes
	if(!is_cave)
		if (planet_type.overworld_biomes && length(planet_type.overworld_biomes) > 0)
			overworld = TRUE

	if (!caves && !overworld)
		return
	for(var/t in turfs)
		var/turf/gen_turf = t
		var/drift_x = (gen_turf.x + rand(-BIOME_RANDOM_SQUARE_DRIFT, BIOME_RANDOM_SQUARE_DRIFT)) / perlin_zoom
		var/drift_y = (gen_turf.y + rand(-BIOME_RANDOM_SQUARE_DRIFT, BIOME_RANDOM_SQUARE_DRIFT)) / perlin_zoom

		var/heat = text2num(rustg_noise_get_at_coordinates("[heat_seed]", "[drift_x]", "[drift_y]"))
		var/height = text2num(rustg_noise_get_at_coordinates("[height_seed]", "[drift_x]", "[drift_y]"))
		var/humidity = text2num(rustg_noise_get_at_coordinates("[humidity_seed]", "[drift_x]", "[drift_y]"))
		var/humidity_level

		if(caves)
			var/area/A = gen_turf.loc
			if(!(A.area_flags & CAVES_ALLOWED))
				continue

		switch(humidity)
			if(0 to 0.20)
				humidity_level = BIOME_LOWEST_HUMIDITY
			if(0.20 to 0.40)
				humidity_level = BIOME_LOW_HUMIDITY
			if(0.40 to 0.60)
				humidity_level = BIOME_MEDIUM_HUMIDITY
			if(0.60 to 0.80)
				humidity_level = BIOME_HIGH_HUMIDITY
			if(0.80 to 1)
				humidity_level = BIOME_HIGHEST_HUMIDITY

		if(height <= mountain_height)
			if(overworld)
				generate_overworld(heat, humidity_level, gen_turf, planet_type)
			else
				generate_cave(heat, humidity_level, string_gen, gen_turf, cave_area, planet_type)
		else
			if(caves)
				generate_cave(heat, humidity_level, string_gen, gen_turf, cave_area, planet_type)
			else
				generate_overworld(heat, humidity_level, gen_turf, planet_type)
		// Not CHECK_TICK: that yields only once the tick is nearly full, which still
		// leaves this loop taking ~70% of every tick for its whole run. See
		// worldgen_yield() in worldgen_queue.dm.
		SSovermap.worldgen_yield(throttled)
	// Register cave areas
	if(caves)
		cave_area.reg_in_areas_in_z()

	// Logged, not announced: planets regenerate mid-round, and a world-wide bold
	// line every time one builds is a debug leftover from bring-up.
	log_world("[name] planet generation finished in [(REALTIMEOFDAY - start_time)/10]s!")

/datum/map_generator/planet_generator/proc/generate_overworld(heat, humidity_level, turf/gen_turf, datum/planet/planet_type)
	var/heat_level
	var/datum/biome/selected_biome

	switch(heat)
		if(0 to 0.20)
			heat_level = planet_type.overworld_biomes[BIOME_COLDEST]
		if(0.20 to 0.40)
			heat_level = planet_type.overworld_biomes[BIOME_COLD]
		if(0.40 to 0.60)
			heat_level = planet_type.overworld_biomes[BIOME_WARM]
		if(0.60 to 0.65)
			heat_level = planet_type.overworld_biomes[BIOME_TEMPERATE]
		if(0.65 to 0.80)
			heat_level = planet_type.overworld_biomes[BIOME_HOT]
		if(0.80 to 1)
			heat_level = planet_type.overworld_biomes[BIOME_HOTTEST]
	selected_biome = heat_level[humidity_level]
	selected_biome = SSmapping.biomes[selected_biome]
	var/turf/picked_turf = pickweight(selected_biome.open_turf_types)
	picked_turf = place_biome_turf(gen_turf, picked_turf)
	picked_turf.generating_biome = selected_biome

/**
 * Lays one generated turf down over gen_turf.
 *
 * Raw `new turf_type(gen_turf)` is the fast path the roundstart map loader uses, but it
 * bypasses ChangeTurf - and with it the lighting update. That is invisible when terrain
 * generates before SSlighting comes up, and produces a black, unlit planet when it does
 * not. Planets that generate on first visit are always in the second case.
 */
/datum/map_generator/planet_generator/proc/place_biome_turf(turf/gen_turf, turf/turf_type)
	if(!SSlighting.initialized)
		return new turf_type(gen_turf)
	var/turf/new_turf = gen_turf.ChangeTurf(turf_type, flags = CHANGETURF_IGNORE_AIR)
	// ChangeTurf inherits the previous occupant's baseturfs - here that's the bare space
	// the z-level was filled with, so anything that later removes a tile (a ruin's
	// clear_below, an explosion, lava eating the ground) opens a hole into literal
	// space. Rebuild the stack from the turf type's own definition, exactly like the
	// raw-new boot path always produced. Every planet turf defines baseturfs as a
	// single path, so initial() is safe; the type itself is the never-space fallback.
	new_turf.assemble_baseturfs(initial(new_turf.baseturfs) || new_turf.type)
	return new_turf

/datum/map_generator/planet_generator/proc/generate_cave(heat, humidity_level, string_gen, turf/gen_turf, cave_area, datum/planet/planet_type)
	var/datum/biome/cave/selected_cave_biome
	var/heat_level

	switch(heat)
		if(0 to 0.25)
			heat_level = planet_type.cave_biomes[BIOME_COLDEST_CAVE]
		if(0.25 to 0.5)
			heat_level = planet_type.cave_biomes[BIOME_COLD_CAVE]
		if(0.5 to 0.75)
			heat_level = planet_type.cave_biomes[BIOME_WARM_CAVE]
		if(0.75 to 1)
			heat_level = planet_type.cave_biomes[BIOME_HOT_CAVE]
	selected_cave_biome = heat_level[humidity_level]
	selected_cave_biome = SSmapping.biomes[selected_cave_biome]
	var/closed = text2num(string_gen[world.maxx * (gen_turf.y - 1) + gen_turf.x])
	var/turf/picked_turf = pickweight(closed ? selected_cave_biome.closed_turf_types : selected_cave_biome.open_turf_types)
	picked_turf = place_biome_turf(gen_turf, picked_turf)
	if(gen_turf.turf_flags & NO_RUINS)
		picked_turf.turf_flags |= NO_RUINS
	var/turf_area = get_area(picked_turf)
	if(turf_area != cave_area)
		picked_turf.change_area(turf_area, cave_area)
	picked_turf.generating_biome = selected_cave_biome

/datum/map_generator/planet_generator/populate_terrain(list/turfs, area/generate_in, zone_band)

	var/start_time = REALTIMEOFDAY

	// Zone danger scaling: planets in dangerous overmap zones spawn denser and
	// meaner fauna. Preloaded planets populate during SSmapping init (before
	// SSovermap places them), so their zone comes from the band SSmapping dealt the
	// planet pair up front, placement honors it later (setup_planets). Dynamic
	// planets populate at load time instead, and pass their marker's live band in.
	// Decided once here so it costs nothing at runtime. Loot is never scaled.
	var/mob_chance_mult = 1
	var/mob_upgrade_prob = 0
	var/spawner_budget = ZONE_PLANET_SPAWNER_BUDGET_GREEN
	var/anomaly_budget = ZONE_PLANET_ANOMALY_BUDGET_GREEN
	// Megafauna are apex content and stay out of the shallow end entirely - a green-zone
	// planet is where a crew takes its first landing.
	var/megafauna_allowed = FALSE
	if(isnull(zone_band) && length(turfs))
		var/turf/zone_sample = turfs[1]
		zone_band = SSmapping.get_planet_zone_band_for_z(zone_sample.z)
	switch(zone_band)
		if(ZONE_YELLOW)
			mob_chance_mult = ZONE_PLANET_MOB_CHANCE_MULT_YELLOW
			mob_upgrade_prob = ZONE_PLANET_MOB_UPGRADE_PROB_YELLOW
			spawner_budget = ZONE_PLANET_SPAWNER_BUDGET_YELLOW
			anomaly_budget = ZONE_PLANET_ANOMALY_BUDGET_YELLOW
			megafauna_allowed = TRUE
		if(ZONE_RED)
			mob_chance_mult = ZONE_PLANET_MOB_CHANCE_MULT_RED
			mob_upgrade_prob = ZONE_PLANET_MOB_UPGRADE_PROB_RED
			spawner_budget = ZONE_PLANET_SPAWNER_BUDGET_RED
			anomaly_budget = ZONE_PLANET_ANOMALY_BUDGET_RED
			megafauna_allowed = TRUE

	// Structure spawners and megafauna are placed after the pass, not during it. Both are
	// permanent terrain outside SSplanet_mobs' cap, so both need a budget - and picking
	// them as we go would bunch them into the low corner of the map, because get_block()
	// hands us turfs in row-major order. Gather candidates, then choose from the whole set.
	var/list/spawner_candidates = list()
	var/list/megafauna_candidates = list()

	for(var/turf/target_turf as anything in turfs)

		if(!target_turf.generating_biome)
			continue

		var/datum/biome/selected_biome = target_turf.generating_biome
		var/flora_allowed = selected_biome.flora_spawn_chance > 0 && length(selected_biome.flora_spawn_list) > 0 ? TRUE : FALSE
		var/fauna_allowed = selected_biome.mob_spawn_chance > 0 && length(selected_biome.mob_spawn_list) > 0 ? TRUE : FALSE
		var/feature_allowed = selected_biome.feature_spawn_chance > 0 && length(selected_biome.feature_spawn_list) > 0 ? TRUE : FALSE

		if(!(target_turf.type in selected_biome.open_turf_types)) //only put stuff on open turfs we generated, so closed walls and rivers and stuff are skipped
			continue

		// If we've spawned something yet
		var/spawned_something = FALSE

		if(!(target_turf.turf_flags & TURF_BLOCKS_POPULATE_TERRAIN_FLORAFEATURES))
			//FLORA SPAWNING HERE
			if(flora_allowed && prob(selected_biome.flora_spawn_chance))
				var/flora_type = pickweight(selected_biome.flora_spawn_list)
				new flora_type(target_turf)
				spawned_something = TRUE

			//FEATURE SPAWNING HERE
			//we may have generated something from the flora list on the target turf, so let's not place
			//a feature here if that's the case (because it would look stupid)
			if(feature_allowed && !spawned_something && prob(selected_biome.feature_spawn_chance))
				var/can_spawn = TRUE

				var/atom/picked_feature = pickweight(selected_biome.feature_spawn_list)

				// Don't place duplicate features
				for(var/obj/structure/existing_feature in range(7, target_turf))
					if(istype(existing_feature, picked_feature))
						can_spawn = FALSE
						break

				// Planets are a single z-level, so a cave ladder has nothing to link to
				// and would drop whoever used it into nowhere.
				if(ispath(picked_feature, /obj/structure/ladder))
					can_spawn = FALSE

				// Some biomes seed nests through the feature list rather than the mob list
				// (snow's demonic portals, wasteland's hivebot portals). They are the same
				// permanent, uncapped fauna source, so they share the same budget.
				if(can_spawn && ispath(picked_feature, /obj/structure/spawner))
					spawner_candidates[target_turf] = picked_feature
					continue

				if(can_spawn)
					new picked_feature(target_turf)
					spawned_something = TRUE

		//MOB SPAWNING HERE
		if(fauna_allowed && !spawned_something && prob(selected_biome.mob_spawn_chance * mob_chance_mult))
			var/atom/picked_mob = pickweight(selected_biome.mob_spawn_list)
			if(!picked_mob)
				continue

			if(picked_mob == SPAWN_MEGAFAUNA)
				// Banked as a candidate rather than placed - see megafauna_candidates.
				// Green zones bank nothing, so the roll falls through to ordinary fauna.
				if(megafauna_allowed && length(selected_biome.megafauna_spawn_list))
					megafauna_candidates[target_turf] = pickweight(selected_biome.megafauna_spawn_list)
					continue
				// Re-roll off the sentinel. Bounded: a table that is nothing but
				// SPAWN_MEGAFAUNA would spin here forever otherwise.
				for(var/attempt in 1 to 10)
					picked_mob = pickweight(selected_biome.mob_spawn_list)
					if(picked_mob != SPAWN_MEGAFAUNA)
						break
				if(picked_mob == SPAWN_MEGAFAUNA)
					continue

			// Zone danger scaling: some rolls upgrade to the biome's meaner tier. Megafauna
			// never reach this - they were banked above - so apex content stays untouched.
			if(mob_upgrade_prob && length(selected_biome.dangerous_mob_spawn_list) && prob(mob_upgrade_prob))
				picked_mob = pickweight(selected_biome.dangerous_mob_spawn_list)

			// Structure spawners are permanent terrain and are budgeted, so they are only
			// banked here. Everything else is ordinary fauna: the turf is registered as a
			// candidate and SSplanet_mobs populates it when players actually arrive, then
			// clears it again after they leave. On a z-level SSplanet_mobs isn't tracking,
			// register_spawn_turf() declines and the mob spawns here as it always did.
			// (This used to be istype(), which is always FALSE on a type path - so the
			// spawner branch never ran and tendrils placed themselves unbudgeted.)
			if(ispath(picked_mob, /obj/structure/spawner))
				spawner_candidates[target_turf] = picked_mob
				continue

			// On a tracked z-level the turf is only registered, and SSplanet_mobs populates
			// it when players actually arrive. Otherwise (asteroid fields take this path)
			// the mob is placed here and now, and can clump - so that case, and only that
			// case, pays for the anti-clump scan. Nothing is standing on a planet
			// mid-build for it to find anyway, and range() over 450 turfs per roll is the
			// most expensive thing in this loop.
			if(SSplanet_mobs.register_spawn_turf(target_turf, picked_mob))
				spawned_something = TRUE
			else
				var/can_spawn = TRUE
				for(var/mob/living/mob_blocker in range(12, target_turf))
					can_spawn = FALSE
					break

				if(can_spawn)
					new picked_mob(target_turf)
					spawned_something = TRUE
		// The expensive half of a planet build - every iteration runs several range()
		// scans - and the one that most needs to stop hogging the tick. See
		// worldgen_yield() in worldgen_queue.dm.
		SSovermap.worldgen_yield(throttled)

	var/spawners_placed = place_budgeted_spawners(spawner_candidates, spawner_budget)
	var/megafauna_placed = place_planet_megafauna(megafauna_candidates)
	var/anomalies_placed = place_budgeted_anomalies(turfs, anomaly_budget)

	log_world("[name] terrain population finished in [(REALTIMEOFDAY - start_time)/10]s! \
		spawners [spawners_placed]/[length(spawner_candidates)] (budget [spawner_budget]), \
		megafauna [megafauna_placed]/[length(megafauna_candidates)], \
		anomalies [anomalies_placed] (budget [anomaly_budget])")

/**
 * Places up to `budget` structure spawners from the candidate turfs the terrain pass
 * banked, keeping them ZONE_PLANET_SPAWNER_SPACING apart.
 *
 * Candidates are drawn at random rather than in order: get_block() hands out turfs
 * row-major, so taking the first N would put every tendril on the planet in the same
 * corner. Returns how many were placed.
 */
/datum/map_generator/planet_generator/proc/place_budgeted_spawners(list/candidates, budget)
	if(!length(candidates) || budget <= 0)
		return 0

	var/list/available = candidates.Copy()
	var/list/placed_at = list()
	var/placed = 0

	while(placed < budget && length(available))
		var/turf/candidate = pick_n_take(available)
		if(!isturf(candidate) || candidate.density)
			continue

		var/too_close = FALSE
		for(var/turf/taken as anything in placed_at)
			if(get_dist(candidate, taken) < ZONE_PLANET_SPAWNER_SPACING)
				too_close = TRUE
				break
		if(too_close)
			continue

		var/spawner_type = candidates[candidate]
		new spawner_type(candidate)
		placed_at += candidate
		placed++
		CHECK_TICK

	return placed

/**
 * Seeds up to `budget` anomalies on the planet's open ground, keeping them
 * ZONE_PLANET_ANOMALY_SPACING apart. Returns how many were placed.
 *
 * Unlike spawners and megafauna this banks no candidates during the terrain pass. It
 * needs no biome table - any open ground will do - and that loop is already the expensive
 * half of a planet build, so it gets no extra work per turf. Turfs are drawn at random
 * instead: pick() is O(1), where walking the list in order would put every anomaly in the
 * low corner of the map, get_block() handing out turfs row-major.
 *
 * The draw is attempt-bounded rather than exhaustive. A planet whose open ground is
 * nearly all spoken for seeds fewer anomalies than its budget, which is the right way to
 * fail: this is optional scenery, not something worth stalling a build over.
 */
/datum/map_generator/planet_generator/proc/place_budgeted_anomalies(list/turfs, budget)
	if(!length(turfs) || budget <= 0)
		return 0

	var/list/placed_at = list()
	var/placed = 0

	for(var/attempt in 1 to PLANET_ANOMALY_PLACEMENT_ATTEMPTS)
		if(placed >= budget)
			break

		var/turf/candidate = pick(turfs)
		if(!isturf(candidate) || candidate.density)
			continue

		// The same rule the terrain pass uses for flora, features and fauna: only ground
		// this generator actually laid down. Keeps anomalies off rivers, lava and walls.
		var/datum/biome/candidate_biome = candidate.generating_biome
		if(!candidate_biome || !(candidate.type in candidate_biome.open_turf_types))
			continue

		// Don't bury one under a rock, a tendril or anything else the pass already placed.
		if((locate(/obj/structure) in candidate) || (locate(/mob/living) in candidate))
			continue

		var/too_close = FALSE
		for(var/turf/taken as anything in placed_at)
			if(get_dist(candidate, taken) < ZONE_PLANET_ANOMALY_SPACING)
				too_close = TRUE
				break
		if(too_close)
			continue

		var/anomaly_type = pickweight(GLOB.voidcrew_planet_anomalies)
		new anomaly_type(candidate)
		placed_at += candidate
		placed++
		CHECK_TICK

	return placed

/// Places a single megafauna from the banked candidates. One per planet, and only where
/// the zone band allows them at all - see megafauna_allowed in populate_terrain().
/datum/map_generator/planet_generator/proc/place_planet_megafauna(list/candidates)
	if(!length(candidates))
		return 0

	var/list/available = candidates.Copy()
	while(length(available))
		var/turf/candidate = pick_n_take(available)
		if(!isturf(candidate) || candidate.density)
			continue
		var/megafauna_type = candidates[candidate]
		new megafauna_type(candidate)
		return 1

	return 0
