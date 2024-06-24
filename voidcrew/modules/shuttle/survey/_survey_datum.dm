// Generic base datum
/datum/surveyed_celestial_object
	var/ref_id
	var/object_name
/datum/surveyed_celestial_object/proc/copy(var/datum/surveyed_celestial_object/new_object)
	new_object.ref_id = ref_id
	new_object.object_name = object_name

// Nebula
/datum/surveyed_celestial_object/nebula
	var/datum/gas/gas_type

/datum/surveyed_celestial_object/nebula/copy(var/datum/surveyed_celestial_object/nebula/new_object)
	. = ..()
	new_object.gas_type = gas_type

// Asteroid
/datum/surveyed_celestial_object/asteroid
	var/list/datum/material/minerals

/datum/surveyed_celestial_object/asteroid/copy(var/datum/surveyed_celestial_object/asteroid/new_object)
	. = ..()
	new_object.minerals = minerals

// Electric storm
/datum/surveyed_celestial_object/electric_storm
	var/intensity

/datum/surveyed_celestial_object/electric_storm/copy(var/datum/surveyed_celestial_object/electric_storm/new_object)
	. = ..()
	new_object.intensity = intensity

// EMP storm
/datum/surveyed_celestial_object/emp_storm
	var/intensity

/datum/surveyed_celestial_object/emp_storm/copy(var/datum/surveyed_celestial_object/emp_storm/new_object)
	. = ..()
	new_object.intensity = intensity

// Planets
/datum/surveyed_celestial_object/planet
	var/visited = FALSE
	var/datum/weather/weather_type
	var/living_player_count
	// var/list/datum/material/mineral_types
	// var/list/obj/possible_loot
	// var/list/datum/map_template/ruin/ruin_type
	// var/list/mob/living/fauna_types
	// var/list/obj/structure/flora/flora_types

/datum/surveyed_celestial_object/planet/copy(var/datum/surveyed_celestial_object/planet/new_object)
	. = ..()
	new_object.visited = visited
	new_object.weather_type = weather_type
	new_object.living_player_count = living_player_count

// Stars
/datum/surveyed_celestial_object/star
	var/star_type

/datum/surveyed_celestial_object/star/copy(var/datum/surveyed_celestial_object/star/new_object)
	. = ..()
	new_object.star_type = star_type

/datum/survey_research
	var/list/datum/surveyed_celestial_object/nebula/nebulas = list()
	var/list/datum/surveyed_celestial_object/asteroid/asteroids = list()
	var/list/datum/surveyed_celestial_object/electric_storm/electric_storms = list()
	var/list/datum/surveyed_celestial_object/emp_storm/emp_storms = list()
	var/list/datum/surveyed_celestial_object/planet/planets = list()
	var/list/datum/surveyed_celestial_object/star/stars = list()
	var/list/celestial_types = list(
		"nebulas",
		"asteroids",
		"electric_storms",
		"emp_storms",
		"planets",
		"stars",
	)

/datum/survey_research/proc/get_surveyed_objects_count()
	var/total_count = length(nebulas) + length(asteroids) + length(electric_storms) + length(emp_storms) + length(planets) + length(stars)
	return total_count
