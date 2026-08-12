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

/// All planet overmap objects (used to map interior z-levels back to overmap tiles, e.g. for zone-aware loot)
GLOBAL_LIST_EMPTY(overmap_planets)

/obj/structure/overmap/planet/Initialize(mapload)
	. = ..()
	GLOB.overmap_planets += src
	apply_planet_identity()

/obj/structure/overmap/planet/Destroy()
	GLOB.overmap_planets -= src
	return ..()

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
	// Dock-in-empty-space placeholder, not a real celestial: neither scannable nor
	// drawn on the chart when the ship is sitting on top of it, and nothing to survey.
	sensor_detectable = FALSE
	sensor_visible = FALSE
	survey_value = 0
	/// How many times we've tried to unload this level
	var/unload_attempts = 0
	/// Maximum number of unload retry attempts
	var/max_unload_attempts = 5
	/// Delay between unload retries in seconds
	var/unload_retry_delay = 10 SECONDS

// Not a docking target in its own right. It IS empty space, and the helm's
// dock_in_empty_space() path already finds and reuses any placeholder on the tile.
/obj/structure/overmap/planet/empty/get_dock_description()
	return null

/obj/structure/overmap/planet/empty/crashed_ship
	planet = /datum/overmap/planet/crashed_ship

/obj/structure/overmap/planet/empty/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	// The parent registers COMSIG_VOIDCREW_SHIP_UNDOCKED for us - registering it again
	// here would be a duplicate registration on the same source. Our on_ship_undocked()
	// override below is what that registration ends up calling.
	. = ..()
	if(istype(arrived, /obj/structure/overmap/ship))
		// If an NPC ship docks here, show its name on the overmap instead of "Empty Space"
		if(istype(arrived, /obj/structure/overmap/ship/npc))
			name = arrived.name

// Note: We don't override Exited() because the ship exits BEFORE the undock signal fires
// The signal handler in on_ship_undocked() cleans up the registration

/// Signal handler - called when a ship that was docked here finishes undocking.
/// Overrides the planet countdown: empty space has no terrain worth keeping, so it
/// tears down and deletes itself instead of waiting out a despawn timer.
/obj/structure/overmap/planet/empty/on_ship_undocked(obj/structure/overmap/ship/source)
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
	// Failed - the encounter lives on (usually another ship is still docked here),
	// so restore any freed reserve dock to its default geometry now. Ship-to-ship
	// and cargo-shuttle docking park these ports right against another shuttle;
	// left stale, the next ship to claim one would be placed overlapping the ship
	// that stayed behind.
	reset_free_reserve_docks()
	// Retry if we haven't hit max attempts
	unload_attempts++
	if(unload_attempts < max_unload_attempts)
		addtimer(CALLBACK(src, PROC_REF(try_unload_level)), unload_retry_delay)

/// Same contract as the parent's, minus its mapzone requirement: an empty-space
/// encounter that never got as far as allocating one still needs cleaning up.
/// preserve_level is handled by unload_level() itself, which has to stop the retries.
/obj/structure/overmap/planet/empty/can_release_interior()
	// Don't unload if any ships are still docked here
	if(first_dock_taken || second_dock_taken)
		return FALSE

	// Check if any ships are still inside (catches race conditions with async unload)
	for(var/obj/structure/overmap/ship/docked_ship in contents)
		return FALSE

	if(length(mapzone?.get_mind_mobs()))
		return FALSE

	return TRUE

/obj/structure/overmap/planet/empty/unload_level()
	if(preserve_level)
		return TRUE // Return TRUE to stop retries - this is intentional

	if(unloading)
		return FALSE

	if(!can_release_interior())
		return FALSE

	unloading = TRUE

	// Delete the reserve docks explicitly - clear_to_uninitialized_space() skips
	// /obj/docking_port, so they'd otherwise be orphaned on the recycled map zone
	remove_docks()
	remove_mapzone()
	qdel(src)
	return TRUE

// `throttled` unused: clear_to_uninitialized_space() is always unqueued bystander
// work and never waits behind a planet job (see worldgen_yield())
/obj/structure/overmap/planet/empty/remove_mapzone(throttled = TRUE)
	if(mapzone)
		mapzone.clear_to_uninitialized_space()
		mapzone.taken = FALSE
		mapzone = null

/**
 * Restores any unoccupied reserve docks to the default encounter layout.
 *
 * Ship-to-ship docking (position_docks_for_direct_docking) and the cargo shuttle
 * (position_cargo_dock_next_to_ship) move, rotate and resize these shared
 * stationary ports so one shuttle can dock right up against another. Nothing
 * restored them afterwards: if this encounter outlives that pairing (one ship
 * stays behind, or an unload attempt fails), the next shuttle to claim a dock
 * would be placed with the stale adjacent geometry - materialising on top of
 * the ship still docked here, or failing to fit a dock that was shrunk down to
 * cargo-shuttle size.
 *
 * Docks that are claimed (dock_taken flags) or physically occupied are left alone.
 */
/obj/structure/overmap/planet/empty/proc/reset_free_reserve_docks()
	if(QDELETED(src))
		return
	reset_free_reserve_docks_for(reserve_dock, reserve_dock_secondary, first_dock_taken, second_dock_taken)

/**
 * Which pair of reserve docks a cargo shuttle would use to berth alongside `ship_shuttle`:
 * the dock that ship is parked on, and the free one the shuttle gets laid against.
 *
 * Returns list("ship_dock" = ..., "cargo_dock" = ..., "index" = 1|2) on success, or
 * list("error" = "<crew-facing reason>") when there is no such pair.
 *
 * Both the cargo console's up-front refusal and the arrival itself ask this, so the
 * button's enabled state and what actually happens after the warmup cannot disagree.
 * An encounter only has two reserve docks and ship-to-ship docking claims BOTH of them
 * (dock_ships_directly() in ship.dm), so any crew docked to another ship has nowhere to
 * put a cargo shuttle - which used to be discoverable only after the full 30-second
 * warmup had been spent building and then destroying one.
 *
 * * cargo_claim - the dock index a cargo shuttle is already holding, if any. It claims its
 * berth when the order is placed and keeps it through the flight, so it has to be able to
 * ask this again on arrival without reading its own claim as somebody else's ship.
 */
/obj/structure/overmap/planet/empty/proc/get_cargo_berth(obj/docking_port/mobile/ship_shuttle, cargo_claim = 0)
	if(!ship_shuttle)
		return list("error" = "Ship docking port not found")
	var/first_taken = first_dock_taken && cargo_claim != 1
	var/second_taken = second_dock_taken && cargo_claim != 2
	if(first_taken && reserve_dock?.get_docked() == ship_shuttle)
		if(second_taken)
			return list("error" = "Docking ports occupied by another ship")
		return list("ship_dock" = reserve_dock, "cargo_dock" = reserve_dock_secondary, "index" = 2)
	if(second_taken && reserve_dock_secondary?.get_docked() == ship_shuttle)
		if(first_taken)
			return list("error" = "Docking ports occupied by another ship")
		return list("ship_dock" = reserve_dock_secondary, "cargo_dock" = reserve_dock, "index" = 1)
	return list("error" = "Ship docking port not found")

/**
 * The encounter's other reserve dock, when something is physically parked on it.
 *
 * A ship arriving into an encounter someone else is already sitting in has no way to
 * reach the ship-to-ship handshake - a docked ship leaves the overmap tile, so it is no
 * longer a contact anyone can act on - and would otherwise be berthed at the default
 * port on the far side of the level. This is what lets that arrival dock against them.
 *
 * * excluding - The dock the arriving ship has already claimed.
 */
/obj/structure/overmap/planet/empty/proc/get_occupied_reserve_dock(obj/docking_port/stationary/excluding)
	if(reserve_dock && reserve_dock != excluding && reserve_dock.get_docked())
		return reserve_dock
	if(reserve_dock_secondary && reserve_dock_secondary != excluding && reserve_dock_secondary.get_docked())
		return reserve_dock_secondary
	return null


/**
 * Base area for everything inside an encounter reservation - planet surfaces, caves
 * and planetary ruins.
 *
 * Deliberately NOT NOTELEPORT. It used to be, inherited from the overmap port, which
 * cost more than it bought: jaunt was unusable planetside (every phased step blocked,
 * and the exit path treated you as an exploiter and scattered you), fulton packs died
 * on the one kind of map that wants them, and both of our own orbit-to-surface systems
 * had to bypass the flag with forced teleports to work at all. Nothing was actually
 * gated by it either - process_teleport_locs() only lists station-level areas, so a
 * teleporter console could never target a planet by name, and check_teleport_valid()
 * already rejects imprecise teleports that would land outside the reservation. The
 * remaining vector is a bluespace beacon someone physically carried down, which costs a
 * landing anyway.
 *
 * Set NOTELEPORT on a specific subtype when that place is meant to be shielded.
 */
/area/overmap_encounter
	name = "\improper Overmap Encounter"
	icon_state = "away"
	area_flags = HIDDEN_AREA | CAVES_ALLOWED | FLORA_ALLOWED | MOB_SPAWN_ALLOWED
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
	/// Overmap zone band this planet sits in. Set before population so fauna scales to
	/// how dangerous the planet's neighbourhood is - see planet_generator/populate_terrain.
	var/zone_band

/**
 * Ruin interiors that want their front door to mean something. NOTELEPORT here is the
 * deliberate exception to the base area's rule, so a beacon or a jaunt can't skip
 * whatever the ruin puts between you and its loot.
 *
 * Note that most planetary ruins map their interiors with tg's own /area/ruin subtypes
 * and have never carried this flag - only ruins tagged with this area are shielded.
 */
/area/overmap_encounter/planet_ruin
	name = "\improper Unknown Planetary Ruin"
	sound_environment = SOUND_ENVIRONMENT_MOUNTAINS
	area_flags = HIDDEN_AREA | CAVES_ALLOWED | FLORA_ALLOWED | MOB_SPAWN_ALLOWED | NOTELEPORT
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
		map_generator.populate_terrain(turfs, src, zone_band)

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
