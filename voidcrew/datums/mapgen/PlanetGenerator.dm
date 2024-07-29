#define BIOME_RANDOM_SQUARE_DRIFT 2

/datum/map_generator/planet_generator
	var/name = "Planet Generator"
	var/mountain_height = 0.85
	var/perlin_zoom = 65
	var/initial_closed_chance = 45
	var/smoothing_iterations = 20
	var/birth_limit = 4
	var/death_limit = 3

	var/edge_turf_light_power = 1000

/obj/effect/dummy/cave_light
	name = "cave lighting"
	desc = "Tell a coder if you're seeing this."
	icon_state = "nothing"
	light_range = 0
	blocks_emissive = EMISSIVE_BLOCK_NONE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/datum/map_generator/planet_generator/generate_terrain(list/turf/turfs, datum/planet/planet_type, is_cave)
	. = ..()
	if(!planet_type)
		var/message = "[name] planet generation failed!"
		to_chat(world, span_boldannounce("[message]"))
		log_world(message)
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
		CHECK_TICK
	// Register cave areas
	if(caves)
		cave_area.reg_in_areas_in_z()
		for(var/i in 1 to length(cave_area.turfs_by_zlevel))
			for(var/turf/cave_turf in cave_area.turfs_by_zlevel[i])
				var/list/adjacent_turfs = RANGE_TURFS(1, cave_turf)
				if(!adjacent_turfs || !length(adjacent_turfs))
					return
				var/list/area/adjacent_areas = list()
				for(var/near_turf in adjacent_turfs)
					adjacent_areas |= get_area(near_turf)
				if(length(adjacent_areas))
					var/found_adj_area = FALSE
					var/found_adjacent_cave = FALSE
					var/adj_area_color
					var/adj_area_alpha
					for(var/area/adjacent_area in adjacent_areas)
						if(!istype(adjacent_area, /area/overmap_encounter/planetoid/cave))
							// Check if area uses different lighting than ours
							if(adjacent_area.static_lighting)
								continue
							else
								adj_area_color = adjacent_area.base_lighting_color
								adj_area_alpha = adjacent_area.base_lighting_alpha
								found_adj_area = TRUE
								// break
						else
							found_adjacent_cave = TRUE

					if(found_adj_area)
						// Cave turfs look bad with low lighting if there's no adjacent cave turfs
						if(!found_adjacent_cave)
							cave_turf.light_power = 2
						else
							if(istype(cave_turf, /turf/closed))
								cave_turf.light_power = 2
							else
								cave_turf.light_power = 2
						cave_turf.light_range = 1.4
						cave_turf.light_color = adj_area_color
						cave_turf.light_on = TRUE
						cave_turf.should_pass_light_to_child = TRUE
						continue

				var/list/near_turfs = RANGE_TURFS(2, cave_turf)
				var/list/area/near_areas = list()
				for(var/near_turf in near_turfs)
					near_areas |= get_area(near_turf)
				if(length(near_areas))
					var/found_near_area = FALSE
					var/near_area_color
					var/near_area_alpha
					for(var/area/near_area in near_areas)
						if(!istype(near_area, /area/overmap_encounter/planetoid/cave))
							// Check if area uses different lighting than ours
							if(near_area.static_lighting)
								continue
							else
								near_area_color = near_area.base_lighting_color
								near_area_alpha = near_area.base_lighting_alpha
								found_near_area = TRUE
								break
					if(found_near_area)
						cave_turf.light_on = TRUE
						cave_turf.light_range = 0
						cave_turf.should_pass_light_to_child = TRUE
					else
						cave_turf.light_on = FALSE

	var/message = "[name] planet generation finished in [(REALTIMEOFDAY - start_time)/10]s!"
	to_chat(world, span_boldannounce("[message]"))
	log_world(message)

/datum/map_generator/planet_generator/proc/generate_overworld(heat, humidity_level, gen_turf, datum/planet/planet_type)
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
	picked_turf = new picked_turf(gen_turf)
	picked_turf.generating_biome = selected_biome

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
	picked_turf = new picked_turf(gen_turf)
	if(gen_turf.turf_flags & NO_RUINS)
		picked_turf.turf_flags |= NO_RUINS
	var/turf_area = get_area(picked_turf)
	if(turf_area != cave_area)
		picked_turf.change_area(turf_area, cave_area)
	picked_turf.generating_biome = selected_cave_biome

/datum/map_generator/planet_generator/populate_terrain(list/turfs)

	var/start_time = REALTIMEOFDAY
	var/megafauna_spawned = FALSE
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

				// Spawn linked ladders after checks pass
				if((picked_feature in typesof(/obj/structure/ladder)) && can_spawn)
					var/turf/turf_below = GET_TURF_BELOW(target_turf)
					var/turf/turf_above = GET_TURF_ABOVE(target_turf)
					// Since we aren't doing triple z, no reason to spawn both above and below
					if(turf_below)
						// Don't create up/down ladders if the turfs don't exist in our whitelist)
						if(!turf_below.generating_biome || !(turf_below.type in turf_below.generating_biome.open_turf_types))
							can_spawn = FALSE
						else
							new /obj/structure/ladder/cave(turf_below)
					else if(turf_above)
						if(!turf_above.generating_biome || !(turf_above.type in turf_above.generating_biome.open_turf_types))
							can_spawn = FALSE
						else
							new /obj/structure/ladder/cave(turf_above)

				if(can_spawn)
					new picked_feature(target_turf)
					spawned_something = TRUE

		//MOB SPAWNING HERE
		if(fauna_allowed && !spawned_something && prob(selected_biome.mob_spawn_chance))
			var/atom/picked_mob = pickweight(selected_biome.mob_spawn_list)
			if(!picked_mob)
				continue
			var/is_megafauna = FALSE

			if(picked_mob == SPAWN_MEGAFAUNA && !megafauna_spawned)
				picked_mob = pickweight(selected_biome.megafauna_spawn_list)
				is_megafauna = TRUE
				megafauna_spawned = TRUE
			else if(picked_mob == SPAWN_MEGAFAUNA && megafauna_spawned )
				while(picked_mob == SPAWN_MEGAFAUNA)
					picked_mob = pickweight(selected_biome.mob_spawn_list)

			var/can_spawn = TRUE

			// prevents spawners being created in each other's collapse range
			if(istype(picked_mob, /obj/structure/spawner))
				for(var/obj/structure/spawner/spawn_blocker in range(2, target_turf))
					can_spawn = FALSE
					break
			// if the random is not a tendril (hopefully meaning it is a mob), avoid spawning if there's another one within 12 tiles
			else
				var/list/things_in_range = range(12, target_turf)
				for(var/mob/living/mob_blocker in things_in_range)
					can_spawn = FALSE
					break
				// Also block spawns if there's a random lavaland mob spawner nearby and it's not a mega
				if(!is_megafauna)
					can_spawn = can_spawn && !(locate(/obj/effect/spawner) in things_in_range)
			//if there's a megafauna within standard view don't spawn anything at all (This isn't really consistent, I don't know why we do this. you do you tho)
			if(can_spawn)
				for(var/mob/living/simple_animal/hostile/megafauna/found_fauna in range(7, target_turf))
					can_spawn = FALSE
					break

			if(can_spawn)
				new picked_mob(target_turf)
				spawned_something = TRUE
		CHECK_TICK

	var/message = "[name] terrain population finished in [(REALTIMEOFDAY - start_time)/10]s!"
	to_chat(world, span_boldannounce("[message]"))
	log_world(message)
