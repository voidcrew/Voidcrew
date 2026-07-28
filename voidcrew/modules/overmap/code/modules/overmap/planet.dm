/obj/structure/overmap/planet
	name = "weak energy signature"
	desc = "A very weak energy signature."
	icon_state = "strange_event"
	sensor_detectable = TRUE
	sensor_category = "Planets"

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

/// The chart colours planets by terrain, and the terrain is the planet datum's business.
/obj/structure/overmap/planet/get_contact_variant()
	return planet ? initial(planet.chart_variant) : null

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
		var/planet_turf = locate(round(world.maxx/2), round(world.maxy/2), z_level.z_value)
		if(!planet_turf)
			return
		user.forceMove(get_turf(planet_turf))
	else
		return

/**
 * Alters the position and orientation of a stationary docking port to ensure that any mobile port small enough can dock within its bounds
 */
/obj/structure/overmap/planet/proc/adjust_dock_to_shuttle(obj/docking_port/stationary/dock_to_adjust, obj/docking_port/mobile/shuttle)
	adjust_reserve_dock_to_shuttle(dock_to_adjust, shuttle)
	if(shuttle.height > dock_to_adjust.height || shuttle.width > dock_to_adjust.width)
		CRASH("Shuttle cannot fit in dock!")

/obj/structure/overmap/planet/get_dock_description()
	return "[display_name || name] (planetfall)"

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

