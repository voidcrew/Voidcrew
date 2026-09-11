/// Settings must resolve identically through the definition and overmap registration.
/datum/unit_test/voidcrew_planet_definitions/Run()
	var/list/registrations = list(/datum/overmap/planet/lava, /datum/overmap/planet/ice, /datum/overmap/planet/beach, /datum/overmap/planet/jungle, /datum/overmap/planet/wasteland)
	for(var/registration_type in registrations)
		var/datum/overmap/planet/registration = allocate(registration_type)
		var/datum/planet/definition = allocate(registration.planet_template)
		var/datum/planet_environment/environment = allocate(definition.environment)
		var/datum/planet_ruins/ruins = allocate(definition.ruin_settings)
		var/datum/planet_rivers/rivers = allocate(definition.river_settings)
		TEST_ASSERT_NULL(environment.validation_error(), "Invalid default environment: [registration_type]")
		TEST_ASSERT_NULL(ruins.validation_error(), "Invalid default ruins: [registration_type]")
		TEST_ASSERT_NULL(rivers.validation_error(), "Invalid default rivers: [registration_type]")
		TEST_ASSERT_EQUAL(registration.mapgen, definition.terrain_generator, "Terrain bypassed the definition")
		TEST_ASSERT_EQUAL(registration.surface_area, environment.area_type, "Surface area bypassed the environment")
		TEST_ASSERT_EQUAL(registration.baseturf, environment.baseturf, "Base turf bypassed the environment")
		TEST_ASSERT_EQUAL(registration.weather_controller_type, environment.weather_type, "Weather bypassed the environment")
		TEST_ASSERT_EQUAL(registration.ruin_type, ruins.theme, "Ruin theme bypassed the settings")
		TEST_ASSERT_EQUAL(registration.planet_size, 123, "Default footprint changed")
		if(registration_type == /datum/overmap/planet/lava || registration_type == /datum/overmap/planet/ice)
			TEST_ASSERT(rivers.enabled, "Existing planet lost its rivers")
		else
			TEST_ASSERT(!rivers.enabled, "Existing planet acquired rivers")
		var/area/overmap_encounter/planetoid/surface = new environment.area_type
		allocated += surface
		TEST_ASSERT_EQUAL(surface.map_generator, definition.terrain_generator, "Area terrain bypassed the definition")
		TEST_ASSERT_EQUAL(surface.base_lighting_color, environment.light_color, "Daylight color bypassed the environment")
		TEST_ASSERT_EQUAL(surface.base_lighting_alpha, environment.light_alpha, "Daylight strength bypassed the environment")
		TEST_ASSERT_EQUAL(surface.default_gravity, environment.gravity, "Gravity bypassed the environment")
		var/list/traits = environment.level_traits()
		TEST_ASSERT_EQUAL(traits["Baseturf"], environment.baseturf, "Roundstart base turf differs from dynamic generation")

/// Filters survive turf replacement, and no carve/spread can cross its supplied rectangle.
/datum/unit_test/voidcrew_planet_river_settings/Run()
	var/turf/first = run_loc_floor_bottom_left
	var/area/allowed_area = get_area(first)
	var/datum/planet_rivers/settings = allocate(/datum/planet_rivers)
	settings.enabled = TRUE
	settings.turf_type = /turf/open/floor/plating
	settings.node_count = 3
	settings.spread_chance = 40
	settings.spread_loss = 10
	var/list/bounds = list(first.x + 1, first.y + 1, first.x + 3, first.y + 3)
	var/turf/inside = locate(first.x + 2, first.y + 2, first.z)
	var/original_type = inside.type
	settings.node_count = 1000
	TEST_ASSERT(settings.validation_error(), "Invalid node count accepted")
	TEST_ASSERT(!settings.generate(first.z, list(allowed_area.type), bounds), "Invalid river settings generated terrain")
	TEST_ASSERT_EQUAL(inside.type, original_type, "Invalid settings changed a tile")
	settings.node_count = 3
	settings.biomes = list()
	settings.generate(first.z, list(allowed_area.type), bounds)
	TEST_ASSERT(!inside.planet_river, "Empty biome selection generated a river")
	settings.biomes = null
	// Explicitly permit these ordinary fixture floors; surrounding tiles keep their flags.
	for(var/turf/tile in block(locate(bounds[1], bounds[2], first.z), locate(bounds[3], bounds[4], first.z)))
		tile.turf_flags &= ~NO_LAVA_GEN
	TEST_ASSERT(settings.generate(first.z, list(allowed_area.type), bounds), "Valid river settings refused generation")
	var/river_count = 0
	for(var/turf/tile in block(locate(first.x, first.y, first.z), run_loc_floor_top_right))
		if(!tile.planet_river)
			continue
		river_count++
		TEST_ASSERT(tile.x >= bounds[1] && tile.y >= bounds[2] && tile.x <= bounds[3] && tile.y <= bounds[4], "River crossed the planet boundary")
	TEST_ASSERT(river_count > 0, "Valid settings produced no river tiles")
	var/datum/biome/biome = SSmapping.biomes[/datum/biome/beach]
	TEST_ASSERT_NOTNULL(biome, "Missing test biome")
	inside.generating_biome = biome
	settings.biomes = list(biome.type)
	TEST_ASSERT(settings.allows(inside), "Selected biome was refused")
	inside = place_river_turf(inside, /turf/open/floor/plating)
	TEST_ASSERT_EQUAL(inside.generating_biome, biome, "River placement lost its biome ownership")
	TEST_ASSERT(settings.allows(inside), "Replaced tile lost its biome eligibility")
	settings.biomes = list(/datum/biome/cave)
	TEST_ASSERT(!settings.allows(inside), "Different biome passed an exact filter")
	settings.spread_loss = 0
	TEST_ASSERT(settings.validation_error(), "Unbounded spread was accepted")

/datum/unit_test/voidcrew_planet_ruin_settings/Run()
	var/datum/planet_ruins/settings = allocate(/datum/planet_ruins/lava)
	var/list/theme_pool = settings.selected_templates()
	TEST_ASSERT(length(theme_pool), "Default ruin theme has no templates")
	var/datum/map_template/ruin/selected = theme_pool[theme_pool[1]]
	settings.templates = list(selected.type)
	var/list/explicit_pool = settings.selected_templates()
	TEST_ASSERT_EQUAL(length(explicit_pool), 1, "Explicit ruin selection leaked another template")
	TEST_ASSERT_EQUAL(explicit_pool[explicit_pool[1]], selected, "Explicit selection did not use the registered template")
	settings.templates = list()
	TEST_ASSERT_EQUAL(length(settings.selected_templates()), 0, "Empty selection restored the entire theme")
	settings.templates = list(/datum/map_template/ruin/space)
	TEST_ASSERT(settings.validation_error(), "Space ruin accepted in a planet definition")
	settings.templates = null
	settings.budget_multiplier = -1
	TEST_ASSERT(settings.validation_error(), "Negative budget accepted")

/datum/unit_test/voidcrew_planet_environment_air
	var/turf/test_turf
	var/area/original_area

/datum/unit_test/voidcrew_planet_environment_air/Destroy()
	if(test_turf && original_area)
		test_turf.change_area(get_area(test_turf), original_area)
	return ..()

/datum/unit_test/voidcrew_planet_environment_air/Run()
	test_turf = run_loc_floor_bottom_left
	original_area = get_area(test_turf)
	var/area/overmap_encounter/planetoid/lava/surface = new
	allocated += surface
	surface.prepare_planet_definition()
	TEST_ASSERT_NOTNULL(surface.planet_environment, "Surface environment was not prepared")
	surface.planet_environment.atmosphere = "o2=10;n2=20;TEMP=250"
	test_turf.change_area(original_area, surface)
	var/turf/open/ground = test_turf.ChangeTurf(/turf/open/floor/plating, flags = CHANGETURF_IGNORE_AIR)
	TEST_ASSERT_EQUAL(ground.initial_gas_mix, surface.planet_environment.atmosphere, "Ground initialized with the wrong planet air")
	TEST_ASSERT(ground.planetary_atmos, "Authored air was not marked planetary")
	TEST_ASSERT_EQUAL(ground.air.temperature, 250, "Authored atmosphere temperature was ignored")

/// Default shares reproduce the old fixed cut points; custom shares resize or remove bands.
/datum/unit_test/voidcrew_planet_climate_shares/Run()
	var/datum/map_generator/planet_generator/generator = allocate(/datum/map_generator/planet_generator)
	TEST_ASSERT_EQUAL(planet_climate_band(0.2, generator.heat_shares), 1, "Coldest band lost its inclusive edge")
	TEST_ASSERT_EQUAL(planet_climate_band(0.21, generator.heat_shares), 2, "Cold band starts too late")
	TEST_ASSERT_EQUAL(planet_climate_band(0.62, generator.heat_shares), 4, "Temperate band moved")
	TEST_ASSERT_EQUAL(planet_climate_band(0.7, generator.heat_shares), 5, "Hot band moved")
	TEST_ASSERT_EQUAL(planet_climate_band(1, generator.heat_shares), 6, "Hottest band lost the top of the range")
	TEST_ASSERT_EQUAL(planet_climate_band(0.5, generator.cave_heat_shares), 2, "Cave cold band lost its inclusive edge")
	TEST_ASSERT_EQUAL(planet_climate_band(0.76, generator.cave_heat_shares), 4, "Cave hot band moved")
	TEST_ASSERT_EQUAL(planet_climate_band(0.9, generator.humidity_shares), 5, "Wettest band moved")
	TEST_ASSERT_EQUAL(planet_climate_band(0.49, list(50, 50, 0, 0, 0, 0)), 1, "Custom share boundary moved")
	TEST_ASSERT_EQUAL(planet_climate_band(0.99, list(50, 50, 0, 0, 0, 0)), 2, "Empty bands still appeared")
	TEST_ASSERT_EQUAL(planet_climate_band(0.3, list(0, 0, 0, 0, 0)), 2, "Empty shares should split the map evenly")
	TEST_ASSERT_EQUAL(length(GLOB.planet_heat_bands), length(generator.heat_shares), "Heat band keys and shares disagree")
	TEST_ASSERT_EQUAL(length(GLOB.planet_cave_heat_bands), length(generator.cave_heat_shares), "Cave band keys and shares disagree")
	TEST_ASSERT_EQUAL(length(GLOB.planet_humidity_bands), length(generator.humidity_shares), "Humidity band keys and shares disagree")

/**
 * The map loader mints a fresh instance of a ruin's mapped planet-surface yard and changes
 * turfs into it before that instance initializes. The planet definition has to be applied by
 * then, or every yard tile is built statically lit and renders black on daylit ground - and
 * the yard never generated terrain, so populating it must not call a bare generator path.
 */
/datum/unit_test/voidcrew_planet_ruin_yard
	var/datum/turf_reservation/reserve

/datum/unit_test/voidcrew_planet_ruin_yard/Destroy()
	QDEL_NULL(reserve)
	return ..()

/datum/unit_test/voidcrew_planet_ruin_yard/Run()
	TEST_ASSERT(SSlighting.initialized, "Lighting must be initialized for this regression")
	var/datum/map_template/ruin/template = SSmapping.ruins_templates["Tidewater Tiki Bar"]
	TEST_ASSERT_NOTNULL(template, "The tiki bar ruin is missing")
	reserve = SSmapping.request_turf_block_reservation(template.width + 4, template.height + 4, 1)
	TEST_ASSERT_NOTNULL(reserve, "Could not reserve room for the ruin")
	var/turf/bottom_left = reserve.bottom_left_turfs[1]

	// A beach surface the way build_planet() lays one: a fresh area instance, then ground.
	var/area/overmap_encounter/planetoid/beach/surface = new
	for(var/turf/tile as anything in reserve.reserved_turfs)
		tile.change_area(get_area(tile), surface)
	surface.reg_in_areas_in_z()
	var/datum/map_generator/planet_generator/beach/generator = new
	for(var/turf/tile as anything in reserve.reserved_turfs)
		generator.place_biome_turf(tile, /turf/open/misc/asteroid/sand/beach)

	planet_ruin_area_instancing_begin(bottom_left.z)
	var/loaded = template.load(locate(bottom_left.x + 2, bottom_left.y + 2, bottom_left.z))
	planet_ruin_area_instancing_end(bottom_left.z)
	TEST_ASSERT(loaded, "The ruin did not load")

	var/list/yard_areas = list()
	var/checked_tiles = 0
	for(var/turf/tile as anything in reserve.reserved_turfs)
		var/area/overmap_encounter/planetoid/tile_area = tile.loc
		if(!istype(tile_area) || tile_area == surface)
			continue
		yard_areas |= tile_area
		TEST_ASSERT(tile_area.ambient_lighting && !tile_area.static_lighting && tile_area.area_has_base_lighting, "The ruin's yard area is not daylit")
		// Ground that lights itself keeps an object on purpose; see /turf/proc/skips_lighting_object().
		if(tile.light_range)
			continue
		checked_tiles++
		TEST_ASSERT_NULL(tile.lighting_object, "A ruin yard tile was built statically lit: [tile] at [tile.x],[tile.y]")
	TEST_ASSERT(checked_tiles, "The ruin brought no plain planet-surface yard tiles to test")
	for(var/area/yard as anything in yard_areas)
		try
			yard.RunTerrainPopulation()
		catch(var/exception/problem)
			TEST_FAIL("Populating an ungenerated ruin yard runtimed: [problem.name]")
