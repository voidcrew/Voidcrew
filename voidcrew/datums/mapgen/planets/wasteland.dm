/datum/planet/wasteland
	terrain_generator = /datum/map_generator/planet_generator/lava
	environment = /datum/planet_environment/wasteland
	ruin_settings = /datum/planet_ruins/wasteland
	overworld_biomes = list(
		//NORMAL BIOMES
		BIOME_COLDEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/ruins,
			BIOME_LOW_HUMIDITY = /datum/biome/wasteland/plains,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/wasteland,
			BIOME_HIGH_HUMIDITY = /datum/biome/wasteland,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/wasteland/plains
		),
		BIOME_COLD = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/wasteland,
			BIOME_LOW_HUMIDITY = /datum/biome/wasteland,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/wasteland/forest,
			BIOME_HIGH_HUMIDITY = /datum/biome/ruins,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/wasteland/plains
		),
		BIOME_WARM = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/wasteland,
			BIOME_LOW_HUMIDITY = /datum/biome/wasteland,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/wasteland/forest,
			BIOME_HIGH_HUMIDITY = /datum/biome/wasteland/plains,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/nuclear
		),
		BIOME_TEMPERATE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/nuclear,
			BIOME_LOW_HUMIDITY = /datum/biome/wasteland/forest,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/wasteland/forest,
			BIOME_HIGH_HUMIDITY = /datum/biome/wasteland/plains,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/wasteland
		),
		BIOME_HOT = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/wasteland,
			BIOME_LOW_HUMIDITY = /datum/biome/wasteland/forest,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/wasteland,
			BIOME_HIGH_HUMIDITY = /datum/biome/nuclear,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/wasteland
		),
		BIOME_HOTTEST = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/wasteland,
			BIOME_LOW_HUMIDITY = /datum/biome/wasteland/forest,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/wasteland,
			BIOME_HIGH_HUMIDITY = /datum/biome/nuclear,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/nuclear
		),
	)
	cave_biomes = list(
		//CAVE BIOMES
		BIOME_COLDEST_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/wasteland,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/wasteland,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/mossy_stone,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/rubble,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/rubble
		),
		BIOME_COLD_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/wasteland,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/wasteland,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/rubble,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/rubble,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/rubble
		),
		BIOME_WARM_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/rubble,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/wasteland,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/wasteland,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/rubble,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/mossy_stone
		),
		BIOME_HOT_CAVE = list(
			BIOME_LOWEST_HUMIDITY = /datum/biome/cave/wasteland,
			BIOME_LOW_HUMIDITY = /datum/biome/cave/wasteland,
			BIOME_MEDIUM_HUMIDITY = /datum/biome/cave/rubble,
			BIOME_HIGH_HUMIDITY = /datum/biome/cave/mossy_stone,
			BIOME_HIGHEST_HUMIDITY = /datum/biome/cave/rubble
		)
	)
