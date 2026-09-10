/// Environment data shared by planet generation, overmap registration and the editor.
/datum/planet_environment
	var/area/area_type
	var/turf/baseturf
	/// Null preserves the atmosphere authored on each biome turf.
	var/atmosphere
	var/datum/weather/weather_type
	var/weather_trait
	var/light_color = "#FFFFFF"
	var/light_alpha = 255
	var/gravity = 1

/datum/planet_environment/lava
	area_type = /area/overmap_encounter/planetoid/lava
	baseturf = /turf/open/misc/asteroid/basalt/lava_land_surface
	weather_type = /datum/weather/ash_storm
	weather_trait = ZTRAIT_ASHSTORM
	light_color = "#F98511"

/datum/planet_environment/snow
	area_type = /area/overmap_encounter/planetoid/ice
	// NOT plain /turf/open/misc/asteroid/snow/icemoon: that one's own baseturf is
	// /turf/open/openspace/icemoon, so it would drop diggers through the floor of a
	// single-z planet.
	baseturf = /turf/open/misc/asteroid/snow/icemoon/breathable
	weather_type = /datum/weather/snow_storm
	weather_trait = ZTRAIT_SNOWSTORM

/datum/planet_environment/beach
	area_type = /area/overmap_encounter/planetoid/beach
	baseturf = /turf/open/misc/asteroid/sand/beach
	weather_type = /datum/weather/rain_storm
	weather_trait = ZTRAIT_RAINSTORM
	light_color = LIGHT_COLOR_TUNGSTEN

/datum/planet_environment/jungle
	area_type = /area/overmap_encounter/planetoid/jungle
	baseturf = /turf/open/misc/dirt/jungle
	weather_type = /datum/weather/rain_storm
	weather_trait = ZTRAIT_RAINSTORM

/datum/planet_environment/wasteland
	area_type = /area/overmap_encounter/planetoid/wasteland
	baseturf = /turf/open/misc/wasteland
	weather_type = /datum/weather/sand_storm
	weather_trait = ZTRAIT_SANDSTORM

/// Planet ruin selection. Existing templates still own their costs and placement rules.
/datum/planet_ruins
	var/enabled = TRUE
	var/theme
	var/budget_multiplier = 1
	var/mineral_budget = 15
	/// Null uses the theme's pool; an explicit list selects exact ruin template types.
	var/list/templates

/datum/planet_ruins/lava
	theme = ZTRAIT_LAVA_RUINS
/datum/planet_ruins/snow
	theme = ZTRAIT_ICE_RUINS
/datum/planet_ruins/beach
	theme = ZTRAIT_BEACH_RUINS
/datum/planet_ruins/jungle
	theme = ZTRAIT_JUNGLE_RUINS
/datum/planet_ruins/wasteland
	theme = ZTRAIT_WASTELAND_RUINS

/datum/planet_ruins/proc/validation_error()
	if(!isnum(budget_multiplier) || budget_multiplier < 0 || budget_multiplier > 5 || !isnum(mineral_budget) || mineral_budget < 0 || mineral_budget > 100)
		return "Ruin budgets are outside the supported range."
	if(!isnull(templates) && !islist(templates))
		return "Ruin templates must be a list."
	for(var/datum/map_template/ruin/ruin_type as anything in templates)
		if(!ispath(ruin_type, /datum/map_template/ruin) || !initial(ruin_type.id) || initial(ruin_type.ruin_type) == ZTRAIT_SPACE_RUINS)
			return "Only planet ruin templates can be selected."
	return null

/datum/planet_ruins/proc/selected_templates()
	if(isnull(templates))
		return SSmapping.themed_ruins[theme]
	var/list/selected = list()
	for(var/key in SSmapping.ruins_templates)
		var/datum/map_template/ruin/ruin = SSmapping.ruins_templates[key]
		if(ruin.type in templates)
			selected[key] = ruin
	return selected

/datum/planet_ruins/proc/generate(list/levels, list/whitelist_areas, list/bounds, list/owned_areas)
	if(!enabled || validation_error())
		return FALSE
	var/list/selected = selected_templates()
	if(!length(selected))
		return FALSE
	seedRuins(levels, CONFIG_GET(number/lavaland_budget) * budget_multiplier, whitelist_areas, selected, clear_below = TRUE, mineral_budget = mineral_budget, mineral_budget_update = OREGEN_PRESET_LAVALAND, bounds = bounds, area_whitelist_instances = owned_areas)
	return TRUE

/proc/generate_planet_ruins(planet_type, list/levels, list/whitelist_areas, list/bounds, list/owned_areas)
	if(!ispath(planet_type, /datum/planet))
		return FALSE
	var/datum/planet/definition = new planet_type
	var/settings_type = definition.ruin_settings
	qdel(definition)
	if(!ispath(settings_type, /datum/planet_ruins))
		return FALSE
	var/datum/planet_ruins/settings = new settings_type
	var/generated = settings.generate(levels, whitelist_areas, bounds, owned_areas)
	qdel(settings)
	return generated

/// Flat encounters keep their own fields; terrain planets resolve their authored definition.
/datum/overmap/planet/New()
	. = ..()
	if(!ispath(planet_template, /datum/planet))
		return
	var/datum/planet/definition = new planet_template
	planet_definition_error = definition.validation_error()
	if(planet_definition_error)
		qdel(definition)
		return
	mapgen = definition.terrain_generator
	planet_size = definition.planet_size
	if(ispath(definition.environment, /datum/planet_environment))
		var/datum/planet_environment/environment = new definition.environment
		target_area = environment.area_type
		surface_area = environment.area_type
		baseturf = environment.baseturf
		weather_controller_type = environment.weather_type
		weather_trait = environment.weather_trait
		qdel(environment)
	if(ispath(definition.ruin_settings, /datum/planet_ruins))
		var/datum/planet_ruins/ruins = new definition.ruin_settings
		ruin_type = ruins.theme
		qdel(ruins)
	qdel(definition)

/area/overmap_encounter/planetoid
	var/datum/planet_environment/planet_environment

/area/overmap_encounter/planetoid/Initialize(mapload)
	prepare_planet_definition()
	return ..()

/area/overmap_encounter/planetoid/proc/prepare_planet_definition()
	if(ispath(planet_type, /datum/planet))
		planet_type = new planet_type
	if(!istype(planet_type, /datum/planet))
		return
	var/datum/planet/definition = planet_type
	if(ispath(map_generator))
		map_generator = definition.terrain_generator
	if(!planet_environment && ispath(definition.environment, /datum/planet_environment))
		planet_environment = new definition.environment
	if(!planet_environment)
		return
	default_gravity = planet_environment.gravity
	if(!istype(src, /area/overmap_encounter/planetoid/cave))
		static_lighting = FALSE
		ambient_lighting = TRUE
		base_lighting_alpha = planet_environment.light_alpha
		base_lighting_color = planet_environment.light_color

/// Apply the planet atmosphere before a new ground or river tile initializes its air.
/turf/open/proc/prepare_planet_atmosphere()
	var/area/overmap_encounter/planetoid/planet_area = loc
	if(!istype(planet_area))
		return
	var/datum/planet_environment/environment = planet_area.planet_environment
	if(!isnull(environment?.atmosphere))
		initial_gas_mix = environment.atmosphere
		planetary_atmos = TRUE

/datum/planet_environment/proc/validation_error()
	if(!ispath(area_type, /area/overmap_encounter/planetoid) || ispath(area_type, /area/overmap_encounter/planetoid/cave))
		return "Environment needs a planet surface area."
	if(!ispath(baseturf, /turf/open))
		return "Environment needs an open base turf."
	if(!isnull(atmosphere) && !istext(atmosphere))
		return "Atmosphere must be a gas mixture string."
	if(!isnull(weather_type) && (!ispath(weather_type, /datum/weather) || !weather_trait))
		return "Weather needs a controller and matching trait."
	if(!istext(light_color) || !regex(@"^#[0-9a-fA-F]{6}$").Find(light_color))
		return "Daylight needs a six-digit hex color."
	if(!isnum(light_alpha) || light_alpha < 0 || light_alpha > 255 || !isnum(gravity) || gravity < 0 || gravity > 5)
		return "Daylight or gravity is outside the supported range."
	return null

/area/overmap_encounter/planetoid/Destroy()
	QDEL_NULL(planet_environment)
	// Surface and mountain caves can share their definition and generator.
	// Clearing our references lets their remaining owner finish normally.
	planet_type = null
	map_generator = null
	return ..()

/// The same environment traits serve preloaded z-pairs and dynamic footprints.
/datum/planet_environment/proc/level_traits()
	var/list/traits = list(ZTRAIT_MINING = TRUE, ZTRAIT_BASETURF = baseturf)
	if(weather_trait)
		traits[weather_trait] = TRUE
	return traits

/datum/planet/proc/validation_error()
	if(definition_version != 1 || !isnum(planet_size) || planet_size < PLANET_MIN_SIZE || planet_size > world.maxx)
		return "Unsupported planet definition or footprint size."
	if(!ispath(terrain_generator, /datum/map_generator/planet_generator))
		return "Planet needs a terrain generator."
	if(!ispath(environment, /datum/planet_environment))
		return "Planet needs an environment."
	var/datum/planet_environment/environment_data = new environment
	var/error = environment_data.validation_error()
	qdel(environment_data)
	if(error)
		return error
	if(!isnull(ruin_settings))
		if(!ispath(ruin_settings, /datum/planet_ruins))
			return "Invalid ruin settings type."
		var/datum/planet_ruins/ruin_data = new ruin_settings
		error = ruin_data.validation_error()
		qdel(ruin_data)
		if(error)
			return error
	if(!isnull(river_settings))
		if(!ispath(river_settings, /datum/planet_rivers))
			return "Invalid river settings type."
		var/datum/planet_rivers/river_data = new river_settings
		error = river_data.validation_error()
		qdel(river_data)
	return error

/datum/overmap/planet
	var/planet_definition_error
