/// A planet's river recipe. Typepaths are authored data; each generation gets its own instance.
/datum/planet_rivers
	var/enabled = FALSE
	var/turf/turf_type
	/// Number of connected points. More points produce a denser network, not N separate rivers.
	var/node_count = 4
	var/spread_chance = 25
	var/spread_loss = 11
	var/detour_chance = 20
	/// Null allows every generated biome; a list selects exact biome types.
	var/list/biomes

/datum/planet_rivers/lava
	enabled = TRUE
	turf_type = /turf/open/lava/smooth/lava_land_surface/planetary

/datum/planet_rivers/plasma
	enabled = TRUE
	turf_type = /turf/open/lava/plasma/planetary

/// A bad authoring value must fail before any turfs are replaced.
/datum/planet_rivers/proc/validation_error()
	if(!ispath(turf_type, /turf/open) && enabled)
		return "Rivers need an open turf type."
	if(!isnum(node_count) || node_count != round(node_count) || node_count < 2 || node_count > 12)
		return "River point count must be between 2 and 12."
	if(!isnum(spread_chance) || spread_chance < 0 || spread_chance > 40)
		return "River spread chance must be between 0 and 40."
	if(!isnum(spread_loss) || spread_loss < 10 || spread_loss > 100)
		return "River spread loss must be between 10 and 100."
	if(!isnum(detour_chance) || detour_chance < 0 || detour_chance > 60)
		return "River detour chance must be between 0 and 60."
	if(!isnull(biomes) && !islist(biomes))
		return "River biomes must be a list."
	for(var/biome_type in biomes)
		if(!ispath(biome_type, /datum/biome))
			return "River biome filters must contain biome types."
	return null

/datum/planet_rivers/proc/allows(turf/target)
	if(!target)
		return FALSE
	if(isnull(biomes))
		return TRUE
	return target.generating_biome && (target.generating_biome.type in biomes)

/datum/planet_rivers/proc/generate(target_z, list/whitelist_areas, list/bounds)
	if(!enabled)
		return FALSE
	var/error = validation_error()
	if(error)
		log_mapping("Planet rivers ([type]): [error]")
		return FALSE
	if(!isnull(bounds))
		if(length(bounds) != 4)
			return FALSE
		for(var/coordinate in bounds)
			if(!isnum(coordinate) || coordinate != round(coordinate))
				return FALSE
		if(bounds[1] < 1 || bounds[2] < 1 || bounds[3] > world.maxx || bounds[4] > world.maxy || bounds[3] <= bounds[1] || bounds[4] <= bounds[2])
			return FALSE
		spawn_planet_rivers(target_z, node_count, turf_type, whitelist_areas, bounds[1], bounds[2], bounds[3], bounds[4], bounds = bounds, settings = src)
	else
		// Roundstart templates retain their existing central node placement region.
		spawn_planet_rivers(target_z, node_count, turf_type, whitelist_areas, settings = src)
	return TRUE

/// Shared by roundstart and dynamic planet construction. Ruin categories never select rivers.
/proc/generate_planet_rivers(planet_type, target_z, list/whitelist_areas, list/bounds)
	if(!ispath(planet_type, /datum/planet))
		return FALSE
	var/datum/planet/definition = new planet_type
	var/settings_type = definition.river_settings
	qdel(definition)
	if(!ispath(settings_type, /datum/planet_rivers))
		return FALSE
	var/datum/planet_rivers/settings = new settings_type
	var/generated = settings.generate(target_z, whitelist_areas, bounds)
	qdel(settings)
	return generated

/turf
	/// Generation marker: retain biome ownership without populating a river.
	var/planet_river = FALSE
