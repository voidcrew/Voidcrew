/obj/structure/overmap/dynamic
	name = "weak energy signature"
	desc = "A very weak energy signal. It may not still be here if you leave it."
	icon_state = "strange_event"
	///The active turf reservation, if there is one
	var/datum/map_zone/mapzone
	/// This site's rectangle inside the map zone's level - the slot it was dealt. Every
	/// "is this turf mine?" question is answered from here rather than from the z-level,
	/// which a packed level shares with up to three neighbours. See /datum/map_footprint.
	var/datum/map_footprint/footprint
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

/obj/structure/overmap/dynamic/get_interior_footprint()
	return footprint

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

/**
 * Covers every planet and every flat encounter (/planet/empty and its crashed_ship subtype).
 *
 * The orderly teardowns - unload_level() and /planet/empty/unload_level() - both go through
 * remove_mapzone(), which clears the ground and then releases the slot, and leave `mapzone`
 * and `footprint` null before anything gets here. What lands here with either still set is a
 * planet deleted OUT of that path: an admin Del, a runtime mid-build, a qdel from something
 * that never knew about the map zone. Those used to leak the slot (and, before packing, the
 * whole map zone) for the rest of the round, and with four slots to a level a leaked one is
 * a quarter of a z-level nobody can ever be dealt again.
 *
 * The slot is handed back WITHOUT clearing its turfs. Destroy() is not a safe place to run a
 * teardown sweep - it can be reentrant, it can run mid-build, and clear_reservation() yields -
 * so the ground is left as-is and the next tenant's own fill_in() paints over it. Loud,
 * because reaching here with a live interior is a lifecycle bug worth seeing in the logs.
 */
/obj/structure/overmap/planet/Destroy()
	GLOB.overmap_planets -= src
	// Same reasoning as the slot below: the orderly paths already did these, so anything
	// still set here is a planet deleted out of band. A leaked weather site keeps arming
	// storm timers on a level nobody owns; a leaked SSplanet_mobs tracker keeps a footprint
	// ref and a share of the global fauna budget.
	if(weather_site)
		SSweather.unregister_weather_site(weather_site)
		weather_site = null
	if(planet_key)
		SSplanet_mobs.unregister_planet(planet_key)
		planet_key = null
	if(footprint || mapzone)
		var/datum/map_footprint/departing_footprint = footprint
		var/datum/map_zone/departing_zone = mapzone || departing_footprint?.zone
		log_mapping("SSovermap: '[display_name || name]' was deleted while still holding [departing_footprint ? departing_footprint.describe() : "a map zone with no footprint"] - releasing the slot without a teardown sweep; its ground is left for the next tenant to repaint")
		footprint = null
		mapzone = null
		departing_zone?.release_slot(departing_footprint)
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
	/// How many quick retries an undock gets before the loop backs off. Never a give-up
	/// point - see try_unload_level().
	var/max_unload_attempts = 5
	/// Delay between the quick unload retries
	var/unload_retry_delay = 10 SECONDS
	/// Delay between unload retries once the quick burst is spent
	var/unload_backoff_delay = 30 SECONDS

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
	// Keep trying, forever. This used to stop after five attempts, which is fifty
	// seconds - shorter than a routine ship-to-ship rendezvous or a cargo run - and an
	// encounter still busy at that point was pinned, along with its map zone and the
	// z-level under it, until another ship happened to dock here and undock again. The
	// only terminal answer is unload_level() returning TRUE, which preserve_level does.
	// The first few retries stay quick for the common case (the departing shuttle is
	// still mid-move); after that back off to a cheap 30s heartbeat. TIMER_UNIQUE on the
	// backoff so a fresh undock's burst can't stack a second heartbeat on top.
	unload_attempts++
	if(unload_attempts < max_unload_attempts)
		addtimer(CALLBACK(src, PROC_REF(try_unload_level)), unload_retry_delay)
	else
		addtimer(CALLBACK(src, PROC_REF(try_unload_level)), unload_backoff_delay, TIMER_UNIQUE)

/// Placeholders keep their own cleanup loop (try_unload_level(), armed on undock) and
/// must not also run the planet countdown: the two would race, and attempt_despawn()
/// logs a relocation the parent's unload_level() does but ours - which deletes itself -
/// does not. Note this does NOT cover a placeholder that was stood up and then never
/// docked at; that leak is separate and lives in the ship-to-ship docking failure paths.
/obj/structure/overmap/planet/empty/check_start_despawn()
	return

/// Same contract as the parent's, minus its mapzone requirement: an empty-space
/// encounter that never got as far as allocating one still needs cleaning up.
/// preserve_level is handled by unload_level() itself, which has to stop the retries.
/obj/structure/overmap/planet/empty/can_release_interior()
	return isnull(get_interior_release_blocker())

/obj/structure/overmap/planet/empty/get_interior_release_blocker(ignore_ssd_grace = FALSE)
	// Don't unload if any ships are still docked here
	var/docking_blocker = get_docking_blocker()
	if(docking_blocker)
		return docking_blocker
	if(first_dock_taken || second_dock_taken)
		return "A landing pad is reserved, but no assigned ship was found. Inspect its docking port before retrying."


	// Footprint-scoped: three other encounters may share this z-level, and the z-wide
	// answer would keep this one pinned for as long as ANY of them has a crew on it.
	if(length(mapzone?.get_mind_mobs_in(footprint)))
		return "A disconnected player or their body remains inside. Move them out before unloading."

	return null

/obj/structure/overmap/planet/empty/unload_level()
	if(preserve_level)
		return TRUE // Return TRUE to stop retries - this is intentional

	if(unloading)
		return FALSE

	// Never mid-build: a reused placeholder can be standing its encounter up for a new
	// arrival while the previous visitor's unload retry timer is still live, and
	// qdel'ing ourselves under an in-flight spawn_dynamic_encounter() strands the
	// half-built zone. The retry loop calls again after the load has settled.
	if(loading)
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
		// Per-slot: only our own rectangle goes back to uninitialized space unless we are
		// the last tenant on the level, in which case the whole level (cordon included) is
		// reset so the recycled zone starts clean. The footprint has to still be attached
		// while the sweep runs - it is what names the ground we own.
		var/datum/map_zone/departing_zone = mapzone
		var/datum/map_footprint/departing_footprint = footprint
		departing_zone.clear_to_uninitialized_space(departing_footprint)
		departing_zone.release_slot(departing_footprint)
		mapzone = null
		footprint = null

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
	prepare_planet_definition()
	if(ispath(map_generator))
		map_generator = new map_generator()
	var/list/turfs = list()
	for(var/turf/T in contents)
		turfs += T
	map_generator.generate_terrain(turfs, planet_type, FALSE, TRUE)

/area/overmap_encounter/planetoid/RunTerrainPopulation()
	// A typepath here is an area that never generated terrain: the planet-surface yard a
	// ruin maps around itself, minted by the loader after the planet's own ground was laid.
	// Roundstart instantiates every generator before populating; a dynamic planet populates
	// after its ruins land, and those yards keep the mapper's ground exactly as placed.
	if(map_generator && !ispath(map_generator))
		var/list/turfs = list()
		for(var/turf/T in contents)
			turfs += T
		map_generator.populate_terrain(turfs, src, zone_band)

/**
 * SURFACE AREAS
 *
 * Daylight on a planet surface is one ambient light per area, not a light source on
 * every tile. The biomes used to select /lit floor subtypes, which gave a 128x128
 * planet roughly fourteen thousand /datum/light_source instances to hold in memory and
 * fourteen thousand corner updates to chew through while the terrain generated, all to
 * paint a flat wash of light that never changes.
 *
 * base_lighting_alpha builds one BLEND_ADD overlay on the area itself
 * (see /area/proc/add_base_lighting), and static_lighting = FALSE + ambient_lighting = TRUE
 * say that this overlay is ALL the light the ground gets: these turfs carry no lighting
 * objects and no lighting corners at all.
 *
 * That second half is where the memory goes. Keeping static_lighting TRUE and layering the
 * ambient on top was the earlier, conservative shape of this experiment, and it left every
 * surface turf holding a /datum/lighting_object plus the four corners it pulls into
 * existence - measured at roughly 1600 MB against 600 MB for the same planet count with the
 * surfaces dynamic. Ground that can never change its own light has nothing to spend that on.
 *
 * What it costs: a light source standing on open ground - a flashlight, a flare, a lantern -
 * has no lighting object out there to render on, so it does not visibly brighten the
 * surface. It still works normally the moment its holder steps into a cave, a ruin or a
 * ship, which are the places darkness is actually a mechanic. Ambient bleed
 * (voidcrew/edits/lighting.dm) is what keeps those boundaries from being hard black edges.
 *
 * Turfs that light THEMSELVES are the deliberate exception and keep an object apiece - see
 * /turf/proc/skips_lighting_object(). That is what preserves the fallout zone's green.
 *
 * The colours below are the light_color the biome's /lit turfs used to emit - a
 * saturating lighting corner normalises to the source colour, so what the ground
 * actually produced was that colour at full strength. The alpha is the brightness knob:
 * 255 matches the old fully-lit ground (owner's call after seeing 200's softer daylight
 * in play). Tune it live with VV on the area (set_base_lighting is VV-wired); the bleed
 * edges derive from the same alpha, so they follow it.
 *
 * NEVER set base_lighting_color on one of these to COLOR_STARLIGHT. add_base_lighting()
 * treats that value as "follow the live nebula tint" and registers a
 * COMSIG_STARLIGHT_COLOR_CHANGED handler on SSdcs (code/modules/lighting/lighting_area.dm),
 * which /area/Destroy() historically never unregistered. These area instances are minted
 * and reaped once per planet under map packing, so a signal registration that outlives the
 * area would turn every planet teardown into a hard-delete blocker. /area/Destroy() now
 * calls remove_base_lighting() defensively, but do not rely on that - a fixed colour costs
 * nothing and cannot regress.
 *
 * Cave areas are NOT subtypes of any of these - they hang off /planetoid directly - so
 * they keep the inherited static_lighting TRUE and stay dark. Same for ruin areas, ship
 * areas and the outpost hangar, none of which are planet surfaces.
 */
/area/overmap_encounter/planetoid/lava
	name = "\improper Volcanic Planetoid"
	ambientsounds = MINING
	planet_type = /datum/planet/lava
	// was /turf/open/misc/asteroid/planetary_basalt/lava_land_surface/lit

/area/overmap_encounter/planetoid/ice
	name = "\improper Frozen Planetoid"
	sound_environment = SOUND_ENVIRONMENT_CAVE
	ambientsounds = SPOOKY
	planet_type = /datum/planet/snow
	// snow was lit colourless; only the frozen lakes were cyan, and they are a minority

/area/overmap_encounter/planetoid/beach
	name = "\improper Beach Planetoid"
	sound_environment = SOUND_ENVIRONMENT_FOREST
	ambientsounds = BEACH
	planet_type = /datum/planet/beach
	// was /turf/open/misc/asteroid/sand/beach/lit, the bulk of a beach planet's ground

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
	// the fallout zone keeps its own green ground light on top of this - see
	// /datum/biome/nuclear. Those turfs are the one kind of surface ground that still
	// carries a lighting object, so the green still renders; see skips_lighting_object().

// CAVE AREAS
// No base lighting here on purpose: caves are meant to be dark, and they are a subtype
// of /planetoid rather than of any surface area, so they inherit alpha 0.
/area/overmap_encounter/planetoid/cave
	name = "\improper Mysterious Cave"
	sound_environment = SOUND_ENVIRONMENT_CAVE
	ambientsounds = SPOOKY
	outdoors = FALSE

// We want to run generate terrain with is_cave set to TRUE for cave areas
/area/overmap_encounter/planetoid/cave/RunTerrainGeneration()
	prepare_planet_definition()
	if(ispath(map_generator))
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
