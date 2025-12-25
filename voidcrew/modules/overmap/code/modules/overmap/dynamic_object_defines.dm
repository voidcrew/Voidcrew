/obj/structure/overmap/dynamic
	name = "weak energy signature"
	desc = "A very weak energy signal. It may not still be here if you leave it."
	icon_state = "strange_event"
	///The active turf reservation, if there is one
	var/datum/map_zone/mapzone
	///The preset ruin template to load, if/when it is loaded.
	var/datum/map_template/template
	///The docking port in the reserve
	var/obj/docking_port/stationary/reserve_dock
	///The docking port in the reserve
	var/obj/docking_port/stationary/reserve_dock_secondary
	///If the level should be preserved. Useful for if you want to build an autismfort or something.
	var/preserve_level = FALSE
	///What kind of planet the level is, if it's a planet at all.
	var/datum/overmap/planet/planet
	///Keep track of whether or not the docks have been reserved by a ship. This is required to prevent issues where two ships will attempt to dock in the same place due to unfortunate timing
	var/first_dock_taken = FALSE
	var/second_dock_taken = FALSE

/obj/structure/overmap/dynamic/attack_ghost(mob/user)
	if(reserve_dock)
		user.forceMove(get_turf(reserve_dock))
		return TRUE
	else
		return

/obj/structure/overmap/planet/Initialize(mapload)
	. = ..()
	if(planet)
		var/datum/overmap/planet/planet_info = new planet
		name = planet_info.name
		desc = planet_info.desc
		icon_state = planet_info.icon_state
		color = planet_info.color
		weather_type = planet_info.weather_controller_type
		qdel(planet_info)

/obj/structure/overmap/planet/lava
	planet = /datum/overmap/planet/lava

/obj/structure/overmap/planet/ice
	planet = /datum/overmap/planet/ice

/obj/structure/overmap/planet/beach
	planet = /datum/overmap/planet/beach

/obj/structure/overmap/planet/jungle
	planet = /datum/overmap/planet/jungle

/obj/structure/overmap/planet/asteroid
	planet = /datum/overmap/planet/asteroid

/obj/structure/overmap/planet/energy_signal
	planet = /datum/overmap/planet/space

/obj/structure/overmap/planet/wasteland
	planet = /datum/overmap/planet/wasteland

/obj/structure/overmap/planet/empty
	planet = /datum/overmap/planet/empty
	/// How many times we've tried to unload this level
	var/unload_attempts = 0
	/// Maximum number of unload retry attempts
	var/max_unload_attempts = 5
	/// Delay between unload retries in seconds
	var/unload_retry_delay = 10 SECONDS

/obj/structure/overmap/planet/empty/crashed_ship
	planet = /datum/overmap/planet/crashed_ship

/obj/structure/overmap/planet/empty/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	. = ..()
	if(istype(arrived, /obj/structure/overmap/ship))
		// Register for undock signal so we can clean up when the ship leaves
		RegisterSignal(arrived, COMSIG_VOIDCREW_SHIP_UNDOCKED, PROC_REF(on_ship_undocked))

// Note: We don't override Exited() because the ship exits BEFORE the undock signal fires
// The signal handler in on_ship_undocked() cleans up the registration

/// Signal handler - called when a ship that was docked here finishes undocking
/obj/structure/overmap/planet/empty/proc/on_ship_undocked(obj/structure/overmap/ship/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_VOIDCREW_SHIP_UNDOCKED)
	// Reset retry counter for this undock attempt
	unload_attempts = 0
	// Use a 3 second delay to ensure the shuttle has fully entered transit
	addtimer(CALLBACK(src, PROC_REF(try_unload_level)), 3 SECONDS)

/// Attempts to unload the level, retrying if conditions aren't met
/obj/structure/overmap/planet/empty/proc/try_unload_level()
	if(unload_level())
		return // Success, level unloaded
	// Failed - retry if we haven't hit max attempts
	unload_attempts++
	if(unload_attempts < max_unload_attempts)
		addtimer(CALLBACK(src, PROC_REF(try_unload_level)), unload_retry_delay)

/obj/structure/overmap/planet/empty/unload_level()
	if(preserve_level)
		return TRUE // Return TRUE to stop retries - this is intentional

	// Don't unload if any ships are still docked here
	if(first_dock_taken || second_dock_taken)
		return FALSE

	// Don't unload if there are still living mobs with minds
	if(length(mapzone?.get_mind_mobs()))
		return FALSE

	remove_mapzone()
	qdel(src)
	return TRUE

/obj/structure/overmap/planet/empty/remove_mapzone()
	if(mapzone)
		mapzone.clear_to_uninitialized_space()
		mapzone.taken = FALSE
		mapzone = null


/area/overmap_encounter
	name = "\improper Overmap Encounter"
	icon_state = "away"
	area_flags = HIDDEN_AREA | CAVES_ALLOWED | FLORA_ALLOWED | MOB_SPAWN_ALLOWED | NOTELEPORT
	flags_1 = CAN_BE_DIRTY_1
	always_unpowered = TRUE
	power_environ = FALSE
	power_equip = FALSE
	power_light = FALSE
	requires_power = TRUE
	luminosity = 0
	sound_environment = SOUND_ENVIRONMENT_STONEROOM
	ambientsounds = RUINS
	outdoors = TRUE

/area/overmap_encounter/reg_in_areas_in_z()
	if(!has_contained_turfs())
		return
	var/list/areas_in_z = SSmapping.areas_in_z
	update_areasize()
	if(!z)
		WARNING("No z found for [src]")
		return
	if(!areas_in_z["[z]"])
		areas_in_z["[z]"] = list()
	areas_in_z["[z]"] |= src

/area/overmap_encounter/planetoid
	name = "\improper Unknown Planetoid"
	sound_environment = SOUND_ENVIRONMENT_MOUNTAINS
	default_gravity = STANDARD_GRAVITY
	always_unpowered = TRUE
	map_generator = /datum/map_generator/planet_generator
	static_lighting = TRUE
	var/planet_type

/area/overmap_encounter/planet_ruin
	name = "\improper Unknown Planetary Ruin"
	sound_environment = SOUND_ENVIRONMENT_MOUNTAINS
	default_gravity = STANDARD_GRAVITY
	always_unpowered = TRUE
	map_generator = null

/area/overmap_encounter/planetoid/RunTerrainGeneration()
	planet_type = new src.planet_type()
	map_generator = new map_generator()
	var/list/turfs = list()
	for(var/turf/T in contents)
		turfs += T
	map_generator.generate_terrain(turfs, planet_type, FALSE, TRUE)

/area/overmap_encounter/planetoid/RunTerrainPopulation()
	if(map_generator)
		var/list/turfs = list()
		for(var/turf/T in contents)
			turfs += T
		map_generator.populate_terrain(turfs, src)

// SURFACE AREAS
/area/overmap_encounter/planetoid/lava
	name = "\improper Volcanic Planetoid"
	ambientsounds = MINING
	planet_type = /datum/planet/lava
	map_generator = /datum/map_generator/planet_generator/lava

/area/overmap_encounter/planetoid/ice
	name = "\improper Frozen Planetoid"
	sound_environment = SOUND_ENVIRONMENT_CAVE
	ambientsounds = SPOOKY
	planet_type = /datum/planet/snow
	map_generator = /datum/map_generator/planet_generator/snow

/area/overmap_encounter/planetoid/beach
	name = "\improper Beach Planetoid"
	sound_environment = SOUND_ENVIRONMENT_FOREST
	ambientsounds = BEACH
	planet_type = /datum/planet/beach
	map_generator = /datum/map_generator/planet_generator/beach

/area/overmap_encounter/planetoid/jungle
	name = "\improper Jungle Planetoid"
	sound_environment = SOUND_ENVIRONMENT_FOREST
	ambientsounds = AWAY_MISSION
	planet_type = /datum/planet/jungle

/area/overmap_encounter/planetoid/wasteland
	name = "\improper Apocalyptic Planetoid"
	sound_environment = SOUND_ENVIRONMENT_HANGAR
	ambientsounds = MINING
	planet_type = /datum/planet/wasteland

// CAVE AREAS
/area/overmap_encounter/planetoid/cave
	name = "\improper Mysterious Cave"
	sound_environment = SOUND_ENVIRONMENT_CAVE
	ambientsounds = SPOOKY
	outdoors = FALSE

// We want to run generate terrain with is_cave set to TRUE for cave areas
/area/overmap_encounter/planetoid/cave/RunTerrainGeneration()
	planet_type = new src.planet_type()
	map_generator = new map_generator()
	var/list/turfs = list()
	for(var/turf/T in contents)
		turfs += T
	map_generator.generate_terrain(turfs, planet_type, TRUE, TRUE)

/area/overmap_encounter/planetoid/cave/lava
	name = "\improper Mysterious Lava Cave"
	planet_type = /datum/planet/lava

/area/overmap_encounter/planetoid/cave/ice
	name = "\improper Mysterious Ice Cave"
	planet_type = /datum/planet/snow

/area/overmap_encounter/planetoid/cave/jungle
	name = "\improper Mysterious Jungle Cave"
	planet_type = /datum/planet/jungle

/area/overmap_encounter/planetoid/cave/beach
	name = "\improper Mysterious Beach Cave"
	planet_type = /datum/planet/beach

/area/overmap_encounter/planetoid/cave/wasteland
	name = "\improper Mysterious Wasteland Cave"
	planet_type = /datum/planet/wasteland
