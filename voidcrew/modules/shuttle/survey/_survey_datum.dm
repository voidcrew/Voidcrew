/// BASE DATUMS SECTION
/datum/survey_research
	var/list/survey_objects_by_type = list(
		nebulas = list(),
		asteroids = list(),
		electric_storms = list(),
		emp_storms = list(),
		planets = list(),
		stars = list(),
		space_ruins = list(),
	)

/datum/surveyed_celestial_object
	var/ref_id
	var/object_name

/datum/surveyed_celestial_object/nebula
	var/datum/gas/gas_type

/datum/surveyed_celestial_object/asteroid
	var/list/datum/material/minerals

/datum/surveyed_celestial_object/electric_storm
	var/intensity

/datum/surveyed_celestial_object/emp_storm
	var/intensity

/datum/surveyed_celestial_object/star
	var/star_type

/datum/surveyed_celestial_object/space_ruin
	var/ruin_category
	var/true_name
	var/visited = FALSE

/datum/surveyed_celestial_object/planet
	var/visited = FALSE
	var/datum/weather/weather_type
	var/living_player_count
	// var/list/datum/material/mineral_types
	// var/list/obj/possible_loot
	// var/list/datum/map_template/ruin/ruin_type
	// var/list/mob/living/fauna_types
	// var/list/obj/structure/flora/flora_types

/// COPY SECTION
/datum/surveyed_celestial_object/proc/copy(var/datum/surveyed_celestial_object/new_object)
	new_object.ref_id = ref_id
	new_object.object_name = object_name

/datum/surveyed_celestial_object/nebula/copy(var/datum/surveyed_celestial_object/nebula/new_object)
	. = ..()
	new_object.gas_type = gas_type

/datum/surveyed_celestial_object/asteroid/copy(var/datum/surveyed_celestial_object/asteroid/new_object)
	. = ..()
	new_object.minerals = minerals

/datum/surveyed_celestial_object/electric_storm/copy(var/datum/surveyed_celestial_object/electric_storm/new_object)
	. = ..()
	new_object.intensity = intensity

/datum/surveyed_celestial_object/emp_storm/copy(var/datum/surveyed_celestial_object/emp_storm/new_object)
	. = ..()
	new_object.intensity = intensity

/datum/surveyed_celestial_object/planet/copy(var/datum/surveyed_celestial_object/planet/new_object)
	. = ..()
	new_object.visited = visited
	new_object.weather_type = weather_type
	new_object.living_player_count = living_player_count

/datum/surveyed_celestial_object/star/copy(var/datum/surveyed_celestial_object/star/new_object)
	. = ..()
	new_object.star_type = star_type

/datum/surveyed_celestial_object/space_ruin/copy(var/datum/surveyed_celestial_object/space_ruin/new_object)
	. = ..()
	new_object.ruin_category = ruin_category
	new_object.true_name = true_name
	new_object.visited = visited

/// SET VALUES SECTION
/datum/surveyed_celestial_object/proc/set_values(var/obj/structure/overmap/object)
	ref_id = ref(object)
	object_name = object.name

/datum/surveyed_celestial_object/nebula/set_values(var/obj/structure/overmap/event/nebula/object)
	. = ..()
	gas_type = object.gas_type

/datum/surveyed_celestial_object/asteroid/set_values(var/obj/structure/overmap/event/meteor/object)
	. = ..()
	minerals = object.mineral_types

/datum/surveyed_celestial_object/electric_storm/set_values(var/obj/structure/overmap/event/electric/object)
	. = ..()
	intensity = object.intensity

/datum/surveyed_celestial_object/emp_storm/set_values(var/obj/structure/overmap/event/emp/object)
	. = ..()
	intensity = object.intensity

/datum/surveyed_celestial_object/planet/set_values(var/obj/structure/overmap/planet/object)
	. = ..()
	visited = object.visited
	weather_type = object.weather_type
	// Set the number of players found on the planet
	var/datum/space_level/level = object.mapzone.z_levels[1]
	if(level && level.z_value)
		living_player_count = length(SSmobs.clients_by_zlevel[level.z_value])

/datum/surveyed_celestial_object/star/set_values(var/obj/structure/overmap/star/object)
	. = ..()
	star_type = object.star_type

/datum/surveyed_celestial_object/space_ruin/set_values(var/obj/structure/overmap/space_ruin/object)
	. = ..()
	ruin_category = object.ruin_category
	true_name = object.true_name
	visited = object.visited
	// Trigger the ruin's on_surveyed to reveal its true nature
	object.on_surveyed()

/// HELPER PROCS SECTION
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
			survey_objects_by_type[related_celestial_list] |= celestial

		// Asteroids
		if(/datum/surveyed_celestial_object/asteroid)
			var/datum/surveyed_celestial_object/asteroid/celestial
			for(var/datum/surveyed_celestial_object/asteroid/surveyed_asteroid in survey_objects_by_type[related_celestial_list])
				if(surveyed_asteroid.ref_id == ref(object))
					celestial = surveyed_asteroid
			if(!celestial)
				celestial = new()
			celestial.set_values(object)
			survey_objects_by_type[related_celestial_list] |= celestial

		// Electric storms
		if(/datum/surveyed_celestial_object/electric_storm)
			var/datum/surveyed_celestial_object/electric_storm/celestial
			for(var/datum/surveyed_celestial_object/electric_storm/surveyed_electric_storm in survey_objects_by_type[related_celestial_list])
				if(surveyed_electric_storm.ref_id == ref(object))
					celestial = surveyed_electric_storm
			if(!celestial)
				celestial = new()
			celestial.set_values(object)
			survey_objects_by_type[related_celestial_list] |= celestial

		// EMP storms
		if(/datum/surveyed_celestial_object/emp_storm)
			var/datum/surveyed_celestial_object/emp_storm/celestial
			for(var/datum/surveyed_celestial_object/emp_storm/surveyed_emp_storm in survey_objects_by_type[related_celestial_list])
				if(surveyed_emp_storm.ref_id == ref(object))
					celestial = surveyed_emp_storm
			if(!celestial)
				celestial = new()
			celestial.set_values(object)
			survey_objects_by_type[related_celestial_list] |= celestial

		// Planets
		if(/datum/surveyed_celestial_object/planet)
			var/datum/surveyed_celestial_object/planet/celestial
			for(var/datum/surveyed_celestial_object/planet/surveyed_planet in survey_objects_by_type[related_celestial_list])
				if(surveyed_planet.ref_id == ref(object))
					celestial = surveyed_planet
			if(!celestial)
				celestial = new()
			celestial.set_values(object)
			survey_objects_by_type[related_celestial_list] |= celestial

		// Stars
		if(/datum/surveyed_celestial_object/star)
			var/datum/surveyed_celestial_object/star/celestial
			for(var/datum/surveyed_celestial_object/star/surveyed_star in survey_objects_by_type[related_celestial_list])
				if(surveyed_star.ref_id == ref(object))
					celestial = surveyed_star
			if(!celestial)
				celestial = new()
			celestial.set_values(object)
			survey_objects_by_type[related_celestial_list] |= celestial

		// Space Ruins
		if(/datum/surveyed_celestial_object/space_ruin)
			var/datum/surveyed_celestial_object/space_ruin/celestial
			for(var/datum/surveyed_celestial_object/space_ruin/surveyed_ruin in survey_objects_by_type[related_celestial_list])
				if(surveyed_ruin.ref_id == ref(object))
					celestial = surveyed_ruin
			if(!celestial)
				celestial = new()
			celestial.set_values(object)
			survey_objects_by_type[related_celestial_list] |= celestial

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
	if(type in typesof(/obj/structure/overmap/space_ruin))
		return "space_ruins"

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
	if(type in typesof(/obj/structure/overmap/space_ruin))
		return /datum/surveyed_celestial_object/space_ruin

/datum/survey_research/proc/tgui_serialize()
	var/list/data = list(
		nebulas = list(),
		asteroids = list(),
		electric_storms = list(),
		emp_storms = list(),
		planets = list(),
		stars = list(),
		space_ruins = list(),
	)

	for(var/datum/surveyed_celestial_object/nebula/object in survey_objects_by_type["nebulas"])
		var/list/tgui = list(
			ref_id = object.ref_id,
			object_name = object.object_name,
			gas_type = object.gas_type,
		)
		var/object_name = get_unique_name(data["nebulas"], tgui["object_name"])
		data["nebulas"][object_name] = tgui

	for(var/datum/surveyed_celestial_object/asteroid/object in survey_objects_by_type["asteroids"])
		var/list/tgui = list(
			ref_id = object.ref_id,
			object_name = object.object_name,
			minerals = object.minerals,
		)
		var/object_name = get_unique_name(data["asteroids"], tgui["object_name"])
		data["asteroids"][object_name] = tgui

	for(var/datum/surveyed_celestial_object/electric_storm/object in survey_objects_by_type["electric_storms"])
		var/list/tgui = list(
			ref_id = object.ref_id,
			object_name = object.object_name,
			intensity = object.intensity,
		)
		var/object_name = get_unique_name(data["electric_storms"], tgui["object_name"])
		data["electric_storms"][object_name] = tgui

	for(var/datum/surveyed_celestial_object/emp_storm/object in survey_objects_by_type["emp_storms"])
		var/list/tgui = list(
			ref_id = object.ref_id,
			object_name = object.object_name,
			intensity = object.intensity,
		)
		var/object_name = get_unique_name(data["emp_storms"], tgui["object_name"])
		data["emp_storms"][object_name] = tgui

	for(var/datum/surveyed_celestial_object/planet/object in survey_objects_by_type["planets"])
		var/list/tgui = list(
			ref_id = object.ref_id,
			object_name = object.object_name,
			visited = object.visited,
			weather_type = object.weather_type,
			living_player_count = object.living_player_count,
		)
		var/object_name = get_unique_name(data["planets"], tgui["object_name"])
		data["planets"][object_name] = tgui

	for(var/datum/surveyed_celestial_object/star/object in survey_objects_by_type["stars"])
		var/list/tgui = list(
			ref_id = object.ref_id,
			object_name = object.object_name,
			star_type = object.star_type,
		)
		var/object_name = get_unique_name(data["stars"], tgui["object_name"])
		data["stars"][object_name] = tgui

	for(var/datum/surveyed_celestial_object/space_ruin/object in survey_objects_by_type["space_ruins"])
		var/list/tgui = list(
			ref_id = object.ref_id,
			object_name = object.object_name,
			ruin_category = object.ruin_category,
			true_name = object.true_name,
			visited = object.visited,
		)
		var/object_name = get_unique_name(data["space_ruins"], tgui["object_name"])
		data["space_ruins"][object_name] = tgui

	return data

/datum/survey_research/proc/get_unique_name(var/list/data, name)
	var/i = 1
	if(name in data)
		while(i)
			if(!("[name] [i]" in data))
				return "[name] [i]"
			else
				i++
	else
		return name
