// Generic base datum
/datum/surveyed_celestial_object
	var/ref_id
	var/object_name
/datum/surveyed_celestial_object/proc/copy(var/datum/surveyed_celestial_object/new_object)
	new_object.ref_id = ref_id
	new_object.object_name = object_name

/datum/surveyed_celestial_object/proc/set_values(var/obj/structure/overmap/object)
	ref_id = ref(object)
	object_name = object.name

/// Nebula
/datum/surveyed_celestial_object/nebula
	var/datum/gas/gas_type

/datum/surveyed_celestial_object/nebula/set_values(var/obj/structure/overmap/event/nebula/object)
	. = ..()
	gas_type = object.gas_type

/datum/surveyed_celestial_object/nebula/copy(var/datum/surveyed_celestial_object/nebula/new_object)
	. = ..()
	new_object.gas_type = gas_type

/// Asteroid
/datum/surveyed_celestial_object/asteroid
	var/list/datum/material/minerals

/datum/surveyed_celestial_object/asteroid/set_values(var/obj/structure/overmap/event/meteor/object)
	. = ..()
	minerals = object.mineral_types

/datum/surveyed_celestial_object/asteroid/copy(var/datum/surveyed_celestial_object/asteroid/new_object)
	. = ..()
	new_object.minerals = minerals

/// Electric storm
/datum/surveyed_celestial_object/electric_storm
	var/intensity

/datum/surveyed_celestial_object/electric_storm/set_values(var/obj/structure/overmap/event/electric/object)
	. = ..()
	intensity = object.intensity

/datum/surveyed_celestial_object/electric_storm/copy(var/datum/surveyed_celestial_object/electric_storm/new_object)
	. = ..()
	new_object.intensity = intensity

/// EMP storm
/datum/surveyed_celestial_object/emp_storm
	var/intensity

/datum/surveyed_celestial_object/emp_storm/set_values(var/obj/structure/overmap/event/emp/object)
	. = ..()
	intensity = object.intensity

/datum/surveyed_celestial_object/emp_storm/copy(var/datum/surveyed_celestial_object/emp_storm/new_object)
	. = ..()
	new_object.intensity = intensity

/// Planets
/datum/surveyed_celestial_object/planet
	var/visited = FALSE
	var/datum/weather/weather_type
	var/living_player_count
	// var/list/datum/material/mineral_types
	// var/list/obj/possible_loot
	// var/list/datum/map_template/ruin/ruin_type
	// var/list/mob/living/fauna_types
	// var/list/obj/structure/flora/flora_types

/datum/surveyed_celestial_object/planet/set_values(var/obj/structure/overmap/planet/object)
	. = ..()
	visited = object.visited
	weather_type = object.weather_type
	// Set the number of players found on the planet
	var/datum/space_level/level = object.mapzone.z_levels[1]
	if(level && level.z_value)
		living_player_count = length(SSmobs.clients_by_zlevel[level.z_value])

/datum/surveyed_celestial_object/planet/copy(var/datum/surveyed_celestial_object/planet/new_object)
	. = ..()
	new_object.visited = visited
	new_object.weather_type = weather_type
	new_object.living_player_count = living_player_count

/// Stars
/datum/surveyed_celestial_object/star
	var/star_type

/datum/surveyed_celestial_object/star/set_values(var/obj/structure/overmap/star/object)
	. = ..()
	star_type = object.star_type

/datum/surveyed_celestial_object/star/copy(var/datum/surveyed_celestial_object/star/new_object)
	. = ..()
	new_object.star_type = star_type

/datum/survey_research
	var/list/survey_objects_by_type = list(
		nebulas = list(),
		asteroids = list(),
		electric_storms = list(),
		emp_storms = list(),
		planets = list(),
		stars = list(),
	)

/datum/survey_research/proc/get_related_celestial_list(type)
	if(type == /obj/structure/overmap/event/nebula)
		return "nebulas"
	if(type in typesof(/obj/structure/overmap/event/meteor))
		return "asteroids"
	if(type in typesof(/obj/structure/overmap/event/electric))
		return "electric_storms"
	if(type in typesof(/obj/structure/overmap/event/emp))
		return "emp_storms"
	if(type in typesof(/obj/structure/overmap/planet))
		return "planets"
	if(type in typesof(/obj/structure/overmap/star))
		return "stars"

/datum/survey_research/proc/get_related_celestial(type)
	if(type in typesof(/obj/structure/overmap/event/nebula))
		return /datum/surveyed_celestial_object/nebula
	if(type in typesof(/obj/structure/overmap/event/meteor))
		return /datum/surveyed_celestial_object/asteroid
	if(type in typesof(/obj/structure/overmap/event/electric))
		return /datum/surveyed_celestial_object/electric_storm
	if(type in typesof(/obj/structure/overmap/event/emp))
		return /datum/surveyed_celestial_object/emp_storm
	if(type in typesof(/obj/structure/overmap/planet))
		return /datum/surveyed_celestial_object/planet
	if(type in typesof(/obj/structure/overmap/star))
		return /datum/surveyed_celestial_object/star

/datum/survey_research/proc/update_survey_data(var/obj/structure/overmap/object)
	var/related_celestial_list = get_related_celestial_list(object.type)
	var/related_celestial_type = get_related_celestial(object.type)

	switch(related_celestial_type)
		// Nebulas
		if(/datum/surveyed_celestial_object/nebula)
			var/datum/surveyed_celestial_object/nebula/celestial
			for(var/datum/surveyed_celestial_object/nebula/surveyed_nebula in survey_objects_by_type[related_celestial_list])
				if(surveyed_nebula.ref_id == ref(object))
					celestial = surveyed_nebula
			if(!celestial)
				celestial = new()
			celestial.set_values(object)
			survey_objects_by_type[related_celestial_list] += celestial

		// Asteroids
		if(/datum/surveyed_celestial_object/asteroid)
			var/datum/surveyed_celestial_object/asteroid/celestial
			for(var/datum/surveyed_celestial_object/asteroid/surveyed_asteroid in survey_objects_by_type[related_celestial_list])
				if(surveyed_asteroid.ref_id == ref(object))
					celestial = surveyed_asteroid
			if(!celestial)
				celestial = new()
			celestial.set_values(object)
			survey_objects_by_type[related_celestial_list] += celestial

		// Electric storms
		if(/datum/surveyed_celestial_object/electric_storm)
			var/datum/surveyed_celestial_object/electric_storm/celestial
			for(var/datum/surveyed_celestial_object/electric_storm/surveyed_electric_storm in survey_objects_by_type[related_celestial_list])
				if(surveyed_electric_storm.ref_id == ref(object))
					celestial = surveyed_electric_storm
			if(!celestial)
				celestial = new()
			celestial.set_values(object)
			survey_objects_by_type[related_celestial_list] += celestial

		// EMP storms
		if(/datum/surveyed_celestial_object/emp_storm)
			var/datum/surveyed_celestial_object/emp_storm/celestial
			for(var/datum/surveyed_celestial_object/emp_storm/surveyed_emp_storm in survey_objects_by_type[related_celestial_list])
				if(surveyed_emp_storm.ref_id == ref(object))
					celestial = surveyed_emp_storm
			if(!celestial)
				celestial = new()
			celestial.set_values(object)
			survey_objects_by_type[related_celestial_list] += celestial

		// Planets
		if(/datum/surveyed_celestial_object/planet)
			var/datum/surveyed_celestial_object/planet/celestial
			for(var/datum/surveyed_celestial_object/planet/surveyed_planet in survey_objects_by_type[related_celestial_list])
				if(surveyed_planet.ref_id == ref(object))
					celestial = surveyed_planet
			if(!celestial)
				celestial = new()
			celestial.set_values(object)
			survey_objects_by_type[related_celestial_list] += celestial

		// Stars
		if(/datum/surveyed_celestial_object/star)
			var/datum/surveyed_celestial_object/star/celestial
			for(var/datum/surveyed_celestial_object/star/surveyed_star in survey_objects_by_type[related_celestial_list])
				if(surveyed_star.ref_id == ref(object))
					celestial = surveyed_star
			if(!celestial)
				celestial = new()
			celestial.set_values(object)
			survey_objects_by_type[related_celestial_list] += celestial
