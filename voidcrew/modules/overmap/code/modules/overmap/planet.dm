/obj/structure/overmap/planet
	name = "weak energy signature"
	desc = "A very weak energy signature."
	icon_state = "strange_event"

	/// Datum containing all of the information about this planet
	var/datum/overmap/planet/planet
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
	///Keep track of whether or not the docks have been reserved by a ship. This is required to prevent issues where two ships will attempt to dock in the same place due to unfortunate timing
	var/first_dock_taken = FALSE
	var/second_dock_taken = FALSE
	var/loaded = FALSE
	var/loading = FALSE
	var/visited = FALSE
	/// Which docking port the ship is occupying
	var/dock_index
	var/datum/weather/weather_type
	/// Key into SSmapping.planets (e.g. "lava 1"), set by SSovermap.setup_planets()
	var/planet_key
	/// Stoppable timer ID for the despawn countdown
	var/despawn_timer_id
	/// TRUE while terrain is being recycled, blocks ship_act() and re-entry
	var/recycling = FALSE

/**
  * Load a level for a ship that's visiting the level.
  * * visiting shuttle - The docking port of the shuttle visiting the level.
  */
/obj/structure/overmap/planet/proc/load_level()
	// If mapzone exists but docks don't (pre-configured planets), create docks
	if(mapzone && !reserve_dock)
		create_docking_ports()
		return
	if(mapzone)
		return
	if(loading)
		return
	loading = TRUE
	var/list/dynamic_encounter_values = SSovermap.spawn_dynamic_encounter(planet, TRUE, ruin_type = template)
	mapzone = dynamic_encounter_values[1]
	reserve_dock = dynamic_encounter_values[2]
	reserve_dock_secondary = dynamic_encounter_values[3]
	loaded = TRUE
	loading = FALSE
	SEND_SIGNAL(src, COMSIG_VOIDCREW_PLANET_LOADED, TRUE)

/**
  * Creates docking ports for an existing mapzone that doesn't have them.
  * Used for pre-configured planets that have z-levels but no docking ports.
  */
/obj/structure/overmap/planet/proc/create_docking_ports()
	if(!mapzone || !length(mapzone.z_levels))
		return
	var/datum/space_level/zlevel = mapzone.z_levels[1]
	if(!zlevel)
		return

	// locates the first dock in the bottom left, accounting for padding and the border
	var/turf/primary_docking_turf = locate(
		zlevel.low_x + RESERVE_DOCK_DEFAULT_PADDING + 1,
		zlevel.low_y + RESERVE_DOCK_DEFAULT_PADDING + 1,
		zlevel.z_value
	)
	// now we need to offset to account for the first dock
	var/turf/secondary_docking_turf = locate(
		primary_docking_turf.x + RESERVE_DOCK_MAX_SIZE_LONG + RESERVE_DOCK_DEFAULT_PADDING,
		primary_docking_turf.y,
		primary_docking_turf.z
	)

	reserve_dock = new /obj/docking_port/stationary(primary_docking_turf)
	reserve_dock.dir = NORTH
	reserve_dock.name = "\improper Uncharted Space"
	reserve_dock.height = RESERVE_DOCK_MAX_SIZE_SHORT
	reserve_dock.width = RESERVE_DOCK_MAX_SIZE_LONG
	reserve_dock.dheight = 0
	reserve_dock.dwidth = 0

	reserve_dock_secondary = new /obj/docking_port/stationary(secondary_docking_turf)
	reserve_dock_secondary.dir = NORTH
	reserve_dock_secondary.name = "\improper Uncharted Space"
	reserve_dock_secondary.height = RESERVE_DOCK_MAX_SIZE_SHORT
	reserve_dock_secondary.width = RESERVE_DOCK_MAX_SIZE_LONG
	reserve_dock_secondary.dheight = 0
	reserve_dock_secondary.dwidth = 0

/obj/structure/overmap/planet/attack_ghost(mob/user)
	if(reserve_dock)
		user.forceMove(get_turf(reserve_dock))
		return TRUE
	else if(mapzone)
		var/datum/space_level/z_level = mapzone.z_levels[1]
		if(!z_level)
			return
		var/center_x = !isnull(z_level.low_x) ? round((z_level.low_x + z_level.high_x) / 2) : round(world.maxx / 2)
		var/center_y = !isnull(z_level.low_y) ? round((z_level.low_y + z_level.high_y) / 2) : round(world.maxy / 2)
		var/planet_turf = locate(center_x, center_y, z_level.z_value)
		if(!planet_turf)
			return
		user.forceMove(get_turf(planet_turf))
	else
		return

/**
 * Alters the position and orientation of a stationary docking port to ensure that any mobile port small enough can dock within its bounds
 */
/obj/structure/overmap/planet/proc/adjust_dock_to_shuttle(obj/docking_port/stationary/dock_to_adjust, obj/docking_port/mobile/shuttle)
	// the shuttle's dimensions where "true height" measures distance from the shuttle's fore to its aft
	var/shuttle_true_height = shuttle.height
	var/shuttle_true_width = shuttle.width
	// if the port's location is perpendicular to the shuttle's fore, the "true height" is the port's "width" and vice-versa
	if(EWCOMPONENT(shuttle.port_direction))
		shuttle_true_height = shuttle.width
		shuttle_true_width = shuttle.height
	// the dir the stationary port should be facing (note that it points inwards)
	var/final_facing_dir = angle2dir(dir2angle(shuttle_true_height > shuttle_true_width ? EAST : NORTH)+dir2angle(shuttle.port_direction)+180)
	var/list/old_corners = dock_to_adjust.return_coords() // coords for "bottom left" / "top right" of dock's covered area, rotated by dock's current dir
	var/list/new_dock_location // TBD coords of the new location
	if(final_facing_dir == dock_to_adjust.dir)
		new_dock_location = list(old_corners[1], old_corners[2]) // don't move the corner
	else if(final_facing_dir == angle2dir(dir2angle(dock_to_adjust.dir)+180))
		new_dock_location = list(old_corners[3], old_corners[4]) // flip corner to the opposite
	else
		var/combined_dirs = final_facing_dir | dock_to_adjust.dir
		if(combined_dirs == (NORTH|EAST) || combined_dirs == (SOUTH|WEST))
			new_dock_location = list(old_corners[1], old_corners[4]) // move the corner vertically
		else
			new_dock_location = list(old_corners[3], old_corners[2]) // move the corner horizontally
		// we need to flip the height and width
		var/dock_height_store = dock_to_adjust.height
		dock_to_adjust.height = dock_to_adjust.width
		dock_to_adjust.width = dock_height_store

	dock_to_adjust.dir = final_facing_dir
	if(shuttle.height > dock_to_adjust.height || shuttle.width > dock_to_adjust.width)
		CRASH("Shuttle cannot fit in dock!")

	// offset for the dock within its area
	var/new_dheight = round((dock_to_adjust.height-shuttle.height)/2) + shuttle.dheight
	var/new_dwidth = round((dock_to_adjust.width-shuttle.width)/2) + shuttle.dwidth

	// use the relative-to-dir offset above to find the absolute position offset for the dock
	switch(final_facing_dir)
		if(NORTH)
			new_dock_location[1] += new_dwidth
			new_dock_location[2] += new_dheight
		if(SOUTH)
			new_dock_location[1] -= new_dwidth
			new_dock_location[2] -= new_dheight
		if(EAST)
			new_dock_location[1] += new_dheight
			new_dock_location[2] -= new_dwidth
		if(WEST)
			new_dock_location[1] -= new_dheight
			new_dock_location[2] += new_dwidth

	dock_to_adjust.forceMove(locate(new_dock_location[1], new_dock_location[2], dock_to_adjust.z))
	dock_to_adjust.dheight = new_dheight
	dock_to_adjust.dwidth = new_dwidth

/obj/structure/overmap/planet/ship_act(mob/user, obj/structure/overmap/ship/acting, obj/structure/overmap/ship/optional_partner)
	if(concerned)
		to_chat(user, "<span class='notice'>Too much traffic, try again later!</span>")
		return
	concerned = TRUE

	var/prev_state = acting.state
	acting.state = OVERMAP_SHIP_ACTING //This is so the controls are locked while loading the level to give both a sense of confirmation and to prevent people from moving the ship
	balloon_alert(user, "starting docking process..")
	. = load_level(acting.shuttle)
	if(.)
		acting.state = prev_state
		concerned = FALSE
	else
		var/is_survey = FALSE
		var/dock_to_use = null
		// Port destinations are set by our survey console
		if (acting.shuttle.port_destinations)
			dock_to_use = acting.shuttle.port_destinations
			is_survey = TRUE
		else
			if(!reserve_dock.get_docked() && !first_dock_taken)
				dock_to_use = reserve_dock //This assigns what port the shuttle will eventually try to dock into, but it does not immediately update the port's docked status
				first_dock_taken = TRUE
				acting.dock_index = 1
			else if(!reserve_dock_secondary.get_docked() && !second_dock_taken)
				dock_to_use = reserve_dock_secondary
				second_dock_taken = TRUE
				acting.dock_index = 2
		if(!dock_to_use)
			acting.state = prev_state
			concerned = FALSE
			to_chat(user, "<span class='notice'>All potential docking locations occupied.</span>")
			return

		if(!is_survey)
			adjust_dock_to_shuttle(dock_to_use, acting.shuttle)
		to_chat(user, "<span class='notice'>[acting.dock(src, dock_to_use)]</span>") //If a value is returned from load_level(), say that, otherwise, commence docking
	concerned = FALSE
	// For request docking
	if (optional_partner)
		ship_act(user, optional_partner)

/**
  * Unloads the reserve, deletes the linked docking port, and moves to a random location if there's no client-having, alive mobs.
  */
/obj/structure/overmap/planet/proc/unload_level()
	if(preserve_level || concerned || !mapzone)
		return

	if(first_dock_taken || second_dock_taken)
		return

	// Check if any ships are still docked inside (catches race conditions with async unload)
	for(var/obj/structure/overmap/ship/docked_ship in contents)
		return

	if(length(mapzone.get_mind_mobs()))
		return //Dont fuck over stranded people? tbh this shouldn't be called on this condition, instead of bandaiding it inside

	concerned = TRUE //Prevent someone to act with this while it reloads

	remove_docks()
	remove_mapzone() //Take a lot of time
/*
	if(SSovermap.generator_type == OVERMAP_GENERATOR_SOLAR)
		forceMove(SSovermap.get_unused_overmap_square_in_radius())
	else
		forceMove(SSovermap.get_unused_overmap_square())
	choose_level_type()
*/
	forceMove(SSovermap.get_unused_overmap_square())
	concerned = FALSE //Now it can be raided again


/obj/structure/overmap/planet/proc/remove_mapzone()
	if(mapzone)
		mapzone.clear_reservation()
		mapzone.taken = FALSE
		mapzone = null

/obj/structure/overmap/planet/proc/remove_docks()
	if(reserve_dock)
		qdel(reserve_dock, TRUE)
		reserve_dock = null
	if(reserve_dock_secondary)
		qdel(reserve_dock_secondary, TRUE)
		reserve_dock_secondary = null

// ---- Planet Lifecycle (recycle when empty) ----

/// When a ship docks, register for its undock signal and cancel any pending despawn timer.
/obj/structure/overmap/planet/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	. = ..()
	if(!istype(arrived, /obj/structure/overmap/ship))
		return
	RegisterSignal(arrived, COMSIG_VOIDCREW_SHIP_UNDOCKED, PROC_REF(on_ship_undocked))
	cancel_despawn_timer()

/// Signal handler -- called when a ship that was docked here finishes undocking
/obj/structure/overmap/planet/proc/on_ship_undocked(obj/structure/overmap/ship/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_VOIDCREW_SHIP_UNDOCKED)
	// 3-second delay to let the shuttle fully move out
	addtimer(CALLBACK(src, PROC_REF(check_start_despawn)), 3 SECONDS)

/// Checks if conditions are met to start the despawn countdown
/obj/structure/overmap/planet/proc/check_start_despawn()
	if(!planet_key || recycling || preserve_level)
		return
	if(first_dock_taken || second_dock_taken)
		return
	for(var/obj/structure/overmap/ship/docked_ship in contents)
		return
	if(length(mapzone?.get_mind_mobs()))
		return
	start_despawn_timer()

/obj/structure/overmap/planet/proc/start_despawn_timer()
	if(despawn_timer_id)
		return // already running
	despawn_timer_id = addtimer(CALLBACK(src, PROC_REF(attempt_despawn)), PLANET_DESPAWN_TIMER, TIMER_STOPPABLE)
	log_game("PLANET LIFECYCLE: Despawn timer started for [planet_key]")

/obj/structure/overmap/planet/proc/cancel_despawn_timer()
	if(!despawn_timer_id)
		return
	deltimer(despawn_timer_id)
	despawn_timer_id = null
	log_game("PLANET LIFECYCLE: Despawn timer cancelled for [planet_key]")

/// Called when the despawn timer fires. Re-verifies conditions, then recycles.
/obj/structure/overmap/planet/proc/attempt_despawn()
	despawn_timer_id = null
	if(recycling || preserve_level)
		return
	if(first_dock_taken || second_dock_taken)
		return
	for(var/obj/structure/overmap/ship/docked_ship in contents)
		return
	if(length(mapzone?.get_mind_mobs()))
		return
	SSovermap.queue_planet_recycle(src)

/// Main orchestrator: wipes and regenerates the planet terrain on existing z-levels.
/obj/structure/overmap/planet/proc/recycle_planet()
	recycling = TRUE
	concerned = TRUE
	log_game("PLANET LIFECYCLE: Recycling [planet_key]")

	var/list/planet_data = SSmapping.planets[planet_key]
	if(!planet_data)
		log_game("PLANET LIFECYCLE: ERROR - No planet data for [planet_key], aborting recycle")
		recycling = FALSE
		concerned = FALSE
		SSovermap.recycle_complete()
		return

	var/surface_z = planet_data["z"]
	var/cave_z = planet_data["cave_z"]
	var/planet_type_path = planet_data["type"]

	// 1. Move to new overmap position immediately so icon disappears from old spot
	forceMove(SSovermap.get_unused_overmap_square())

	// 2. Remove docking ports
	remove_docks()

	// 3. Clean up weather -- end active weather events on these z-levels
	cleanup_weather(surface_z)

	// 4. Despawn planet mobs
	var/datum/planet_mob_tracker/tracker = SSplanet_mobs.tracked_planets[planet_key]
	if(tracker)
		SSplanet_mobs.despawn_planet_mobs(tracker)

	// 5. Wipe both z-levels
	mapzone.clear_reservation()

	// 6. Regenerate terrain
	regenerate_planet(surface_z, cave_z, planet_type_path)

	// 7. Reset state
	loaded = TRUE
	visited = FALSE
	first_dock_taken = FALSE
	second_dock_taken = FALSE
	recycling = FALSE
	concerned = FALSE

	log_game("PLANET LIFECYCLE: [planet_key] recycled successfully at [x],[y]")
	SSovermap.recycle_complete()

/// Ends active weather events on the given z-level and removes it from eligibility
/obj/structure/overmap/planet/proc/cleanup_weather(surface_z)
	// End any active weather events affecting this z-level
	// Copy list since end() removes from processing mid-iteration
	for(var/datum/weather/W as anything in SSweather.processing.Copy())
		if(surface_z in W.impacted_z_levels)
			W.end()
	// Remove from eligible z-levels and cancel pending weather timers
	var/z_key = "[surface_z]"
	SSweather.eligible_zlevels -= z_key
	if(SSweather.next_hit_by_zlevel[z_key])
		deltimer(SSweather.next_hit_by_zlevel[z_key])
		SSweather.next_hit_by_zlevel[z_key] = null

/// Rebuilds the planet terrain on existing z-levels
/obj/structure/overmap/planet/proc/regenerate_planet(surface_z, cave_z, planet_type_path)
	// Instantiate planet datum to read config
	var/datum/overmap/planet/planet_info = new planet_type_path
	var/psize = planet_info.planet_size
	var/cave_area_type = planet_info.cave_area
	var/surface_area_type = planet_info.surface_area
	var/ruin_trait = planet_info.ruin_type
	var/weather_trait = planet_info.weather_trait
	var/weather_controller_type = planet_info.weather_controller_type

	// Get space_level datums
	var/datum/space_level/cave_level = SSmapping.get_level(cave_z)
	var/datum/space_level/surface_level = SSmapping.get_level(surface_z)

	// Rebuild cave z-level
	cave_level.set_bounds(psize, psize)
	var/area/cave_area = cave_level.fill_in(area_override = cave_area_type)
	cave_level.place_cordon()

	// Rebuild surface z-level
	surface_level.set_bounds(psize, psize)
	var/area/surface_area = surface_level.fill_in(area_override = surface_area_type)
	surface_level.place_cordon()

	// Run terrain generation (Perlin noise + cellular automata)
	if(cave_area)
		cave_area.RunTerrainGeneration()
	if(surface_area)
		surface_area.RunTerrainGeneration()

	// Reset mob tracking before population registers new turfs
	SSplanet_mobs.rebuild_planet_spawn_turfs(planet_key)

	// Run terrain population (flora, features, registers mob spawn turfs)
	if(cave_area)
		cave_area.RunTerrainPopulation()
	if(surface_area)
		surface_area.RunTerrainPopulation()

	// Seed ruins
	reseed_planet_ruins(ruin_trait, surface_area_type)

	// Regenerate rivers (lava and ice planets)
	regenerate_rivers(surface_z, cave_z, ruin_trait, surface_area_type, cave_area_type)

	// Recreate docking ports
	create_docking_ports()

	// Rebuild weather eligibility and start a new weather controller
	rebuild_weather(surface_level, weather_trait, weather_controller_type)

	qdel(planet_info)

/// Seeds ruins on the regenerated planet, mirroring setup_ruins() logic
/obj/structure/overmap/planet/proc/reseed_planet_ruins(ruin_trait, area/surface_area_type)
	if(!ruin_trait)
		return
	var/list/ruin_templates = SSmapping.themed_ruins[ruin_trait]
	if(!ruin_templates)
		return
	var/list/planet_data = SSmapping.planets[planet_key]
	var/surface_z = planet_data["z"]
	seedRuins(list(surface_z), CONFIG_GET(number/lavaland_budget), list(surface_area_type), ruin_templates, clear_below = TRUE, mineral_budget = 15, mineral_budget_update = OREGEN_PRESET_LAVALAND)

/// Regenerates rivers for lava and ice planets
/obj/structure/overmap/planet/proc/regenerate_rivers(surface_z, cave_z, ruin_trait, area/surface_area_type, area/cave_area_type)
	if(ruin_trait == ZTRAIT_LAVA_RUINS)
		var/datum/space_level/level = SSmapping.get_level(surface_z)
		spawn_planet_rivers(surface_z, 4, /turf/open/lava/smooth/lava_land_surface/planetary, list(surface_area_type, cave_area_type), level.low_x, level.low_y, level.high_x, level.high_y)
	else if(ruin_trait == ZTRAIT_ICE_RUINS)
		var/datum/space_level/level = SSmapping.get_level(surface_z)
		spawn_planet_rivers(surface_z, 4, /turf/open/lava/plasma/planetary, list(surface_area_type, cave_area_type), level.low_x, level.low_y, level.high_x, level.high_y)

/// Rebuilds weather eligibility and creates a new weather controller
/obj/structure/overmap/planet/proc/rebuild_weather(datum/space_level/surface_level, weather_trait, weather_controller_type)
	if(!weather_trait)
		return
	// Re-add to eligible z-levels
	SSweather.update_z_level(surface_level)
	// Create new weather controller
	if(weather_controller_type)
		var/list/weather_z_levels = list()
		for(var/datum/space_level/level as anything in mapzone.z_levels)
			weather_z_levels += level.z_value
		new weather_controller_type(weather_z_levels)

