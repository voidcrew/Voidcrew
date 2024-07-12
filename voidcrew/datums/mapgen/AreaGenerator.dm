#define BIOME_RANDOM_SQUARE_DRIFT_DEBUG 2

/datum/map_generator/planet_generator_area
	var/name = "Planet Generator"
	var/mountain_height = 0.85
	var/perlin_zoom = 65
	var/initial_closed_chance = 45
	var/smoothing_iterations = 20
	var/birth_limit = 4
	var/death_limit = 3
	var/list/cave_biomes = list(
		BIOME_COLDEST_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/debug,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/debug,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/debug,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/debug,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/debug
		),
		BIOME_COLD_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/debug,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/debug,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/debug,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/debug,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/debug
		),
		BIOME_WARM_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/debug,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/debug,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/debug,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/debug,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/debug
		),
		BIOME_HOT_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/debug,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/debug,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/debug,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/debug,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/debug
		)
	)
	var/list/overworld_biomes = list(
		BIOME_COLDEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/debug,
			BIOME_LOW_HUMIDITY = /datum/biome/debug,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/debug,
			BIOME_HIGH_HUMIDITY = /datum/biome/debug,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/debug,
		),
		BIOME_COLD = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/debug,
			BIOME_LOW_HUMIDITY = /datum/biome/debug,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/debug,
			BIOME_HIGH_HUMIDITY = /datum/biome/debug,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/debug,
		),
		BIOME_WARM = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/debug,
			BIOME_LOW_HUMIDITY = /datum/biome/debug,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/debug,
			BIOME_HIGH_HUMIDITY = /datum/biome/debug,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/debug,
		),
		BIOME_TEMPERATE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/debug,
			BIOME_LOW_HUMIDITY = /datum/biome/debug,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/debug,
			BIOME_HIGH_HUMIDITY = /datum/biome/debug,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/debug,
		),
		BIOME_HOT = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/debug,
			BIOME_LOW_HUMIDITY = /datum/biome/debug,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/debug,
			BIOME_HIGH_HUMIDITY = /datum/biome/debug,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/debug,
		),
		BIOME_HOTTEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/debug,
			BIOME_LOW_HUMIDITY = /datum/biome/debug,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/debug,
			BIOME_HIGH_HUMIDITY = /datum/biome/debug,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/debug,
		),
	)

/datum/map_generator/planet_generator_area/generate_terrain(var/list/turf/turfs, var/datum/planet/planet_type)
	. = ..()
	var/start_time = REALTIMEOFDAY

	var/height_seed = rand(0, 50000)
	var/humidity_seed = rand(0, 50000)
	var/heat_seed = rand(0, 50000)

	var/string_gen = rustg_cnoise_generate("[initial_closed_chance]", "[smoothing_iterations]", "[birth_limit]", "[death_limit]", "[world.maxx]", "[world.maxy]") //Generate the raw CA data

	var/area/overmap_encounter/planetoid/cave/cave_area = new
	var/caves = FALSE
	var/overworld = FALSE

	if (cave_biomes && length(cave_biomes) > 0)
		caves = TRUE
	if (overworld_biomes && length(overworld_biomes) > 0)
		overworld = TRUE

	if (!caves && !overworld)
		return
	for(var/t in turfs)
		var/turf/gen_turf = t
		var/drift_x = (gen_turf.x + rand(-BIOME_RANDOM_SQUARE_DRIFT_DEBUG, BIOME_RANDOM_SQUARE_DRIFT_DEBUG)) / perlin_zoom
		var/drift_y = (gen_turf.y + rand(-BIOME_RANDOM_SQUARE_DRIFT_DEBUG, BIOME_RANDOM_SQUARE_DRIFT_DEBUG)) / perlin_zoom

		var/heat = text2num(rustg_noise_get_at_coordinates("[heat_seed]", "[drift_x]", "[drift_y]"))
		var/height = text2num(rustg_noise_get_at_coordinates("[height_seed]", "[drift_x]", "[drift_y]"))
		var/humidity = text2num(rustg_noise_get_at_coordinates("[humidity_seed]", "[drift_x]", "[drift_y]"))
		var/heat_level
		var/humidity_level
		var/datum/biome/selected_biome
		var/datum/biome/cave/selected_cave_biome

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
				switch(heat)
					if(0 to 0.20)
						heat_level = overworld_biomes[BIOME_COLDEST]
					if(0.20 to 0.40)
						heat_level = overworld_biomes[BIOME_COLD]
					if(0.40 to 0.60)
						heat_level = overworld_biomes[BIOME_WARM]
					if(0.60 to 0.65)
						heat_level = overworld_biomes[BIOME_TEMPERATE]
					if(0.65 to 0.80)
						heat_level = overworld_biomes[BIOME_HOT]
					if(0.80 to 1)
						heat_level = overworld_biomes[BIOME_HOTTEST]
				selected_biome = heat_level[humidity_level]
				selected_biome = SSmapping.biomes[selected_biome]
				var/turf/picked_turf = pickweight(selected_biome.open_turf_types)
				picked_turf = new picked_turf(gen_turf)
				// selected_biome.generate_overworld(gen_turf)

			else
				switch(heat)
					if(0 to 0.25)
						heat_level = cave_biomes[BIOME_COLDEST_CAVE]
					if(0.25 to 0.5)
						heat_level = cave_biomes[BIOME_COLD_CAVE]
					if(0.5 to 0.75)
						heat_level = cave_biomes[BIOME_WARM_CAVE]
					if(0.75 to 1)
						heat_level = cave_biomes[BIOME_HOT_CAVE]
				selected_cave_biome = heat_level[humidity_level]
				selected_cave_biome = SSmapping.biomes[selected_cave_biome]
				// selected_cave_biome.generate_caves(gen_turf, string_gen, cave_area)
				var/closed = text2num(string_gen[world.maxx * (gen_turf.y - 1) + gen_turf.x])
				var/turf/picked_turf = pickweight(closed ? selected_cave_biome.closed_turf_types : selected_cave_biome.open_turf_types)
				picked_turf = new picked_turf(gen_turf)
				if(gen_turf.turf_flags & NO_RUINS)
					picked_turf.turf_flags |= NO_RUINS
				picked_turf.change_area(get_area(picked_turf), /area/overmap_encounter/planetoid/cave)
		else
			if(caves)
				switch(heat)
					if(0 to 0.25)
						heat_level = cave_biomes[BIOME_COLDEST_CAVE]
					if(0.25 to 0.5)
						heat_level = cave_biomes[BIOME_COLD_CAVE]
					if(0.5 to 0.75)
						heat_level = cave_biomes[BIOME_WARM_CAVE]
					if(0.75 to 1)
						heat_level = cave_biomes[BIOME_HOT_CAVE]
				selected_cave_biome = heat_level[humidity_level]
				selected_cave_biome = SSmapping.biomes[selected_cave_biome]
				var/closed = text2num(string_gen[world.maxx * (gen_turf.y - 1) + gen_turf.x])
				var/turf/picked_turf = pickweight(closed ? selected_cave_biome.closed_turf_types : selected_cave_biome.open_turf_types)
				picked_turf = new picked_turf(gen_turf)
				if(gen_turf.turf_flags & NO_RUINS)
					picked_turf.turf_flags |= NO_RUINS
			else
				switch(heat)
					if(0 to 0.20)
						heat_level = overworld_biomes[BIOME_COLDEST]
					if(0.20 to 0.40)
						heat_level = overworld_biomes[BIOME_COLD]
					if(0.40 to 0.60)
						heat_level = overworld_biomes[BIOME_WARM]
					if(0.60 to 0.65)
						heat_level = overworld_biomes[BIOME_TEMPERATE]
					if(0.65 to 0.80)
						heat_level = overworld_biomes[BIOME_HOT]
					if(0.80 to 1)
						heat_level = overworld_biomes[BIOME_HOTTEST]
				selected_biome = heat_level[humidity_level]
				selected_biome = SSmapping.biomes[selected_biome]
				var/turf/picked_turf = pickweight(selected_biome.open_turf_types)
				picked_turf = new picked_turf(gen_turf)
		CHECK_TICK
	cave_area.reg_in_areas_in_z()
	var/message = "[name] planet generation finished in [(REALTIMEOFDAY - start_time)/10]s!"
	to_chat(world, span_boldannounce("[message]"))
	log_world(message)

