// Generic base datum
/datum/surveyed_celestial_object
	var/obj/structure/overmap/overmap_object

// Nebula
/datum/surveyed_celestial_object/nebula
	var/datum/gas/gas_type

// Asteroid
/datum/surveyed_celestial_object/asteroid
	var/list/datum/material/minerals

// Electric storm
/datum/surveyed_celestial_object/electric_storm
	var/intensity

// EMP storm
/datum/surveyed_celestial_object/emp_storm
	var/intensity

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

// Stars
/datum/surveyed_celestial_object/star
	var/star_type

/datum/survey_research
	var/list/datum/surveyed_celestial_object/nebula/nebulas = list()
	var/list/datum/surveyed_celestial_object/asteroid/asteroids = list()
	var/list/datum/surveyed_celestial_object/electric_storm/electric_storms = list()
	var/list/datum/surveyed_celestial_object/emp_storm/emp_storms = list()
	var/list/datum/surveyed_celestial_object/planet/planets = list()
	var/list/datum/surveyed_celestial_object/star/stars = list()

/datum/survey_research/proc/get_surveyed_objects_count()
	var/total_count = length(nebulas) + length(asteroids) + length(electric_storms) + length(emp_storms) + length(planets) + length(stars)
	return total_count
