/datum/overmap/planet
	///Name of the planet
	var/name = "Planet"
	///Description of the planet
	var/desc = "A generic planet, tell the Coders that you found this."
	///Icon of the planet
	var/icon_state = "globe"
	///Colour of the planet
	var/color = COLOR_WHITE

	/* Planet Generation */
	///Planet spawn rate
	var/spawn_rate = 20
	///Size of the generated region on the planet's z-levels. The rest of each level is
	///cordoned off - see /datum/space_level/set_bounds(). Clamped to PLANET_MIN_SIZE.
	///
	///123 = MAP_SLOT_SIDE = PLANET_MIN_SIZE, the smallest a planet may be and still fit its
	///two side-by-side reserve berths. It was 128; the 5 turfs per axis are the entire price
	///of packing four planets onto one z-level (-3.9% linear, -7.7% area), since a lattice
	///cell is exactly PLANET_MIN_SIZE. A larger value here would be clamped back down to the
	///slot by build_planet() rather than growing into the neighbour.
	var/planet_size = 123
	///The list of ruins that can spawn here
	var/ruin_type
	///The map generator to use
	var/datum/map_generator/mapgen
	///The area type to use on the planet
	var/area/target_area
	///The area type for the planet's z-level. Planets that set this build real terrain;
	///anything else (empty space, crashed ships) is a flat encounter.
	var/area/surface_area
	///The ground this planet is made of, published as the z-level's ZTRAIT_BASETURF.
	///Anything that removes a turf - digging, an explosion, a ruin wall coming down,
	///a shuttle leaving - bottoms out here. Null (flat encounters: empty space, crashed
	///ships) leaves the bottom as space, which is correct for those. On a planet it is
	///NOT: /turf/open/floor/plating and most dirt/grass/sand turfs declare a baseturfs
	///chain ending in /turf/baseturf_bottom, which ChangeTurf resolves to open space
	///unless the z-level names a replacement. Every ruin floor and half the biome ground
	///on a planet without this opens a hole into vacuum when broken.
	///Use the plain, UNLIT variant of the planet's ground. This used to be the /lit
	///subtype, back when a surface was lit by a light source on each of its own turfs and
	///an unlit baseturf read as a black pit. Daylight is now one ambient overlay on the
	///surface AREA (see /area/overmap_encounter/planetoid/* and voidcrew/edits/lighting.dm),
	///so the ground needs no light of its own - and a /lit baseturf here would be actively
	///wrong: light_range 2 makes /turf/proc/skips_lighting_object() return FALSE, so every
	///scraped-through ruin floor and blown-out plating tile bottoming out into this type
	///would mint a lighting object AND a light source inside an ambient area. That is a slow
	///re-accretion of exactly the memory the ambient system removes, and it renders as a
	///bright halo blob on otherwise flat daylight.
	///The /lit types themselves stay alive for the ruin .dmms that place them directly.
	var/turf/baseturf
	///Weather controller for planet specific weather
	var/datum/weather/weather_controller_type
	///Z-level trait for weather audio (e.g. ZTRAIT_ASHSTORM, ZTRAIT_SNOWSTORM)
	var/weather_trait
	///A planet template that contains a list of biomes to use
	var/datum/planet/planet_template
	///Parallax theme (PARALLAX_THEME_* define) crews see while over/inside this planet,
	///copied onto the overmap object at Initialize. Null = plain space. One line here
	///themes a planet type - see the context-parallax system in modules/overmap/_overmap.dm
	var/parallax_theme
	///Which terrain the helm chart colours this planet as. The chart has one planet
	///glyph and tells the types apart by colour alone, so this is the whole of what
	///a navigator sees before landing - see PLANET_COLOR in HelmComputer.tsx.
	var/chart_variant = "rock"

/datum/overmap/planet/lava
	name = "Lava Planet"
	desc = "A planet with lots of seismic and volcanic activity."
	color = COLOR_ORANGE

	ruin_type = ZTRAIT_LAVA_RUINS
	mapgen = /datum/map_generator/planet_generator/lava
	target_area = /area/overmap_encounter/planetoid/lava
	surface_area = /area/overmap_encounter/planetoid/lava
	baseturf = /turf/open/misc/asteroid/basalt/lava_land_surface
	weather_controller_type = /datum/weather/particle/ash_storm // upstream reparented this under /particle
	weather_trait = ZTRAIT_ASHSTORM
	planet_template = /datum/planet/lava
	parallax_theme = PARALLAX_THEME_PLANET
	chart_variant = "lava"

/datum/overmap/planet/ice
	name = "Frozen Planet"
	desc = "A planet with traces of water and extremely low temperatures."
	color = COLOR_BLUE_LIGHT

	ruin_type = ZTRAIT_ICE_RUINS
	mapgen = /datum/map_generator/planet_generator/snow
	target_area = /area/overmap_encounter/planetoid/ice
	surface_area = /area/overmap_encounter/planetoid/ice
	// NOT plain /turf/open/misc/asteroid/snow/icemoon: that one's own baseturf is
	// /turf/open/openspace/icemoon, so it would drop diggers through the floor of a
	// single-z planet.
	baseturf = /turf/open/misc/asteroid/snow/icemoon/breathable
	weather_controller_type = /datum/weather/snow_storm
	weather_trait = ZTRAIT_SNOWSTORM
	planet_template = /datum/planet/snow
	parallax_theme = PARALLAX_THEME_ICEMOON
	chart_variant = "ice"

/datum/overmap/planet/beach
	name = "Oceanic Planet"
	desc = "A planet with many traces of fish."
	color = COLOR_NAVY

	ruin_type = ZTRAIT_BEACH_RUINS
	mapgen = /datum/map_generator/planet_generator/beach
	target_area = /area/overmap_encounter/planetoid/beach
	surface_area = /area/overmap_encounter/planetoid/beach
	baseturf = /turf/open/misc/asteroid/sand/beach
	weather_controller_type = /datum/weather/particle/rain_storm // upstream reparented this under /particle
	weather_trait = ZTRAIT_RAINSTORM
	planet_template = /datum/planet/beach
	chart_variant = "ocean"

/datum/overmap/planet/jungle
	name = "Tropical Planet"
	desc = "A planet teeming with life."
	color = COLOR_LIME

	ruin_type = ZTRAIT_JUNGLE_RUINS
	mapgen = /datum/map_generator/planet_generator
	target_area = /area/overmap_encounter/planetoid/jungle
	surface_area = /area/overmap_encounter/planetoid/jungle
	baseturf = /turf/open/misc/dirt/jungle
	weather_controller_type = /datum/weather/particle/rain_storm // upstream reparented this under /particle
	weather_trait = ZTRAIT_RAINSTORM
	planet_template = /datum/planet/jungle
	chart_variant = "jungle"

/datum/overmap/planet/wasteland
	name = "Apocalyptic Planet"
	desc = "An abandoned industrial planet."
	color = COLOR_BEIGE

	ruin_type = ZTRAIT_WASTELAND_RUINS
	mapgen = /datum/map_generator/planet_generator/lava
	target_area = /area/overmap_encounter/planetoid/wasteland
	surface_area = /area/overmap_encounter/planetoid/wasteland
	baseturf = /turf/open/misc/wasteland
	weather_controller_type = /datum/weather/sand_storm
	weather_trait = ZTRAIT_SANDSTORM
	planet_template = /datum/planet/wasteland
	chart_variant = "wasteland"

/datum/overmap/planet/asteroid
	name = "large asteroid"
	desc = "A large asteroid with significant traces of minerals."
	color = COLOR_GRAY
	icon_state = "asteroid"

	//spawn_rate = 30
	spawn_rate = -1
	mapgen = /datum/map_generator/cave_generator/asteroid
	parallax_theme = PARALLAX_THEME_ASTEROIDS
	chart_variant = "asteroid"

/datum/overmap/planet/space // not a planet but freak off!!
	name = "weak energy signal"
	desc = "A very weak energy signal emenating from space."
	color = null
	icon_state = "strange_event"

	ruin_type = ZTRAIT_SPACE_RUINS
	chart_variant = "signal"

/datum/overmap/planet/empty // not a planet but freak off!!
	name = "Empty Space"
	desc = "A ship appears to be docked here."
	color = null
	icon_state = "object"
	spawn_rate = -1

/datum/overmap/planet/crashed_ship
	name = "Crashed Ship"
	desc = "A distress signal is coming from this location. A ship appears to have suffered critical damage."
	color = "#ff4444"
	icon_state = "strange_event"
	spawn_rate = -1
	chart_variant = "wreck"
