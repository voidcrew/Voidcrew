/*
voidcrew TODO:
	SSovermap originally fired to apply the planet effects but these would be way better off just using signals

Performance Note:
	Ship mass/integrity is now tracked via event-driven delta updates instead of polling.
	See setup_mass_tracking() in ship.dm for details.
*/

#define MAX_OVERMAP_EVENT_CLUSTERS 24
#define MAX_OVERMAP_EVENTS 200
#define MAX_OVERMAP_PLACEMENT_ATTEMPTS 40
#define MAX_OVERMAP_PLANETS_TO_SPAWN 15

SUBSYSTEM_DEF(overmap)
	name = "Overmap"
	wait = 10 // Fires every 1 second (10 deciseconds)
	init_order = INIT_ORDER_OVERMAP
	flags = NONE
	runlevels = RUNLEVEL_SETUP | RUNLEVEL_GAME
	dependencies = list(
		/datum/controller/subsystem/mapping,
	)

	/// Centre of the overmap
	var/turf/overmap_centre
	/// Map of tiles at each radius around the sun
	var/list/turf/radius_tiles = list()
	/// List of all events
	var/list/events = list()

	var/size = OVERMAP_SIZE
	//List of all mapzones
	var/list/map_zones = list()
	///List of all simulated ships
	var/list/simulated_ships = list()
	/// List of NPC ships that need mass recalculated (damaged ships)
	/// Used for performance - NPC ships cache mass and only recalc when damaged
	var/list/dirty_npc_ships = list()
	/// Timer ID of the timer used for telling which stage of an endround "jump" the ships are in
	var/jump_timer
	/// Current state of the jump
	var/jump_mode = BS_JUMP_IDLE
	/// Time taken for bluespace jump to begin after it is requested (in deciseconds)
	var/jump_request_time = 6000
	/// Time taken for a bluespace jump to complete after it initiates (in deciseconds)
	var/jump_completion_time = 1200

	/// Type paths of ship templates to spawn at round start. Change this list to control what ships appear.
	var/list/roundstart_ship_templates = list(
		/datum/map_template/shuttle/voidcrew/scarab,
		/datum/map_template/shuttle/voidcrew/meta,
		/datum/map_template/shuttle/voidcrew/box,
	)
	/// The primary roundstart ship (first in the list). Kept for backward compatibility.
	var/obj/structure/overmap/ship/initial_ship
	/// All ships spawned at round start.
	var/list/obj/structure/overmap/ship/initial_ships = list()

/datum/controller/subsystem/overmap/Initialize(start_timeofday)
	create_map()
	setup_sun()
	setup_dangers()
	setup_planets()
	setup_space_ruins()
	spawn_initial_ship()

	return SS_INIT_SUCCESS

/**
 * Called every tick (1 second) - cleanup only
 * Ship integrity is now tracked via event-driven delta updates (see ship.dm setup_mass_tracking)
 * This polling loop has been removed for ~750x performance improvement
 */
/datum/controller/subsystem/overmap/fire(resumed)
	// Clean up deleted ships from the list
	for(var/obj/structure/overmap/ship/ship as anything in simulated_ships)
		if(QDELETED(ship))
			simulated_ships -= ship

/*
 * Bluespace jump procs
 */

/**
 * ## request_jump
 *
 * Requests a bluespace jump, which, after jump_request_time deciseconds, will initiate a bluespace jump.
 *
 * Arguments:
 * * modifiers - (Optional) Modifies the length of the jump request time (defaults to 1)
 */
/datum/controller/subsystem/overmap/proc/request_jump(modifier = 1)
	jump_mode = BS_JUMP_CALLED
	jump_timer = addtimer(CALLBACK(src, PROC_REF(initiate_jump)), jump_request_time * modifier, TIMER_STOPPABLE)
	priority_announce("Preparing for jump. ETD: [jump_request_time * modifier / 600] minutes.", null, null, "Priority")

/**
 * ##cancel_jump
 *
 * Cancels a currently requested bluespace jump.
 * Can only be done after the jump has been requested, but before the jump has actually begun.
 */
/datum/controller/subsystem/overmap/proc/cancel_jump()
	if(jump_mode != BS_JUMP_CALLED)
		return
	deltimer(jump_timer)
	jump_mode = BS_JUMP_IDLE
	priority_announce("Bluespace jump cancelled.", null, null, "Priority")

/**
 * ##initiate_jump
 *
 * Initiates a bluespace jump, ending the round after a delay of jump_completion_time deciseconds.
 * This cannot be interrupted by conventional means.
 */
/datum/controller/subsystem/overmap/proc/initiate_jump()
	jump_mode = BS_JUMP_INITIATED
	for(var/obj/docking_port/mobile/voidcrew/mobile_port as anything in SSshuttle.mobile_docking_ports)
		mobile_port.hyperspace_sound(HYPERSPACE_WARMUP, mobile_port.shuttle_areas)
		mobile_port.on_emergency_launch()

	priority_announce("Jump initiated. ETA: [jump_completion_time / 600] minutes.", null, null, "Priority")
	jump_timer = addtimer(VARSET_CALLBACK(src, jump_mode, BS_JUMP_COMPLETED), jump_completion_time)

/datum/controller/subsystem/overmap/proc/create_map()
	// creates the overmap area and sets it up
	var/area/overmap/overmap_area = new
	overmap_area.setup("Overmap")

	// locates the area we want the overmap to be
	var/turf/top_left = locate(OVERMAP_LEFT_SIDE_COORD, OVERMAP_NORTH_SIDE_COORD, OVERMAP_Z_LEVEL)
	var/turf/bottom_right = locate(OVERMAP_RIGHT_SIDE_COORD, OVERMAP_SOUTH_SIDE_COORD, OVERMAP_Z_LEVEL)
	var/list/overmap_turfs = block(top_left, bottom_right)
	for (var/turf/overmap_turf as anything in overmap_turfs)
		if (overmap_turf.x == OVERMAP_LEFT_SIDE_COORD || overmap_turf.x == OVERMAP_RIGHT_SIDE_COORD || overmap_turf.y == OVERMAP_NORTH_SIDE_COORD || overmap_turf.y == OVERMAP_SOUTH_SIDE_COORD)
			overmap_turf.ChangeTurf(/turf/closed/overmap_edge)
		else
			overmap_turf.ChangeTurf(/turf/open/overmap)
		var/area/old_area = get_area(overmap_turf)
		LISTASSERTLEN(old_area.turfs_to_uncontain_by_zlevel, overmap_turf.z, list())
		LISTASSERTLEN(overmap_area.turfs_by_zlevel, overmap_turf.z, list())
		old_area.turfs_to_uncontain_by_zlevel[overmap_turf.z] += overmap_turf
		overmap_area.turfs_by_zlevel[overmap_turf.z] += overmap_turf
		overmap_area.contents += overmap_turf
	overmap_area.reg_in_areas_in_z()
	// not actually the centre but close enough
	overmap_centre = get_turf(locate((OVERMAP_LEFT_SIDE_COORD + ((OVERMAP_SIZE - 1) / 2)) - 1, (OVERMAP_SOUTH_SIDE_COORD + ((OVERMAP_SIZE - 1) / 2)) - 1, OVERMAP_Z_LEVEL))

/datum/controller/subsystem/overmap/proc/setup_sun()
	var/turf/open/overmap/centre_tile = overmap_centre
	if(!istype(centre_tile))
		can_fire = FALSE
		message_admins("Overmap failed to generate the map, this is a critical error.")
		CRASH("Overmap did not generate correctly!")

	var/obj/structure/overmap/star/big/star_to_spawn = pick(/obj/structure/overmap/star/big, /obj/structure/overmap/star/big/binary)
	star_to_spawn = new
	star_to_spawn.forceMove(centre_tile)

	var/list/unsorted_turfs = get_area_turfs(/area/overmap, target_z = OVERMAP_Z_LEVEL)
	var/max_ring = 0
	for (var/turf/turf as anything in unsorted_turfs)
		if (istype(turf, /turf/closed/overmap_edge))
			continue
		// the overmap is a square, so we can just use the x and y values to determine the actual ring
		// 2 2 2 2 2
		// 2 1 1 1 2
		// 2 1 X 1 2
		// 2 1 1 1 2
		// 2 2 2 2 2
		var/ring_x = turf.x - (overmap_centre.x + 1)
		var/ring_y = turf.y - (overmap_centre.y + 1)
		var/ring = max(abs(ring_x), abs(ring_y))
		if (!ring)
			continue
		if (ring > max_ring)
			for (var/i in 1 to ring - max_ring)
				radius_tiles += list(list())
			max_ring = ring
		LAZYADDASSOC(radius_tiles, ring, turf)

/datum/controller/subsystem/overmap/proc/get_unused_overmap_square(thing_not_to_have = /obj/structure/overmap, tries = MAX_OVERMAP_PLACEMENT_ATTEMPTS, force = FALSE)
	var/turf/turf_to_return
	for (var/_ in 1 to tries)
		turf_to_return = pick(block(locate(OVERMAP_LEFT_SIDE_COORD + 1, OVERMAP_SOUTH_SIDE_COORD + 1, OVERMAP_Z_LEVEL), locate(OVERMAP_RIGHT_SIDE_COORD - 1, OVERMAP_NORTH_SIDE_COORD - 1, OVERMAP_Z_LEVEL))) // todo : see if this is expensive
		if (locate(thing_not_to_have) in turf_to_return)
			continue
		return turf_to_return
	if (!force)
		turf_to_return = null
	return turf_to_return

/**
 * Returns TRUE if the given turf is in the green zone (outer ring)
 * Checks the turf's current_zone if zones are initialized, otherwise calculates from distance
 */
/datum/controller/subsystem/overmap/proc/is_turf_in_green_zone(turf/open/overmap/T)
	if(!T || !overmap_centre)
		return FALSE
	// Use current_zone if zones have been initialized
	if(T.current_zone)
		return T.current_zone.zone_type == ZONE_GREEN
	// Fallback to distance calculation (for spawning before zones init)
	var/max_radius = (OVERMAP_SIZE - 1) / 2
	var/dx = T.x - overmap_centre.x
	var/dy = T.y - overmap_centre.y
	var/distance = sqrt(dx * dx + dy * dy)
	var/normalized = distance / max_radius
	return normalized >= 0.66

/**
 * Gets an unused overmap square specifically in the green zone (outer ring)
 * Ships spawn here to ensure they start in the safe zone
 */
/datum/controller/subsystem/overmap/proc/get_unused_overmap_square_in_green_zone(thing_not_to_have = /obj/structure/overmap, tries = MAX_OVERMAP_PLACEMENT_ATTEMPTS, force = FALSE)
	var/turf/turf_to_return
	for (var/_ in 1 to tries)
		turf_to_return = pick(block(locate(OVERMAP_LEFT_SIDE_COORD + 1, OVERMAP_SOUTH_SIDE_COORD + 1, OVERMAP_Z_LEVEL), locate(OVERMAP_RIGHT_SIDE_COORD - 1, OVERMAP_NORTH_SIDE_COORD - 1, OVERMAP_Z_LEVEL)))
		if (locate(thing_not_to_have) in turf_to_return)
			continue
		if (!is_turf_in_green_zone(turf_to_return))
			continue
		return turf_to_return
	if (!force)
		turf_to_return = null
	return turf_to_return

/datum/controller/subsystem/overmap/proc/get_unused_overmap_square_in_radius(radius, thing_not_to_have = /obj/structure/overmap, tries = MAX_OVERMAP_PLACEMENT_ATTEMPTS, force = FALSE)
	if (!radius)
		radius = rand(2, length(radius_tiles) / 2)

	var/turf/turf_to_return
	for (var/_ in 1 to tries)
		turf_to_return = pick(radius_tiles[radius])
		if (locate(thing_not_to_have) in turf_to_return)
			continue
		return turf_to_return

	if (!force)
		turf_to_return = null
	return turf_to_return


/datum/controller/subsystem/overmap/proc/setup_dangers()
	var/list/orbits = list()
	for (var/i in 2 to LAZYLEN(radius_tiles))
		orbits += "[i]"

	// Phase 1: Spawn guaranteed event types first to ensure map diversity
	var/list/guaranteed_events = GLOB.overmap_event_guaranteed_list.Copy()
	for (var/event_type in guaranteed_events)
		if (MAX_OVERMAP_EVENTS <= LAZYLEN(events))
			break
		if (LAZYLEN(orbits) == 0 || !orbits)
			break
		var/selected_orbit = text2num(pick(orbits))

		var/turf/turf_for_event = get_unused_overmap_square_in_radius(selected_orbit)
		if (!turf_for_event || !istype(turf_for_event))
			orbits -= "[selected_orbit]"
			continue
		var/obj/structure/overmap/event/event_to_spawn = new event_type(turf_for_event)
		for (var/turf/turf_to_spawn as anything in radius_tiles[selected_orbit])
			if (locate(/obj/structure/overmap) in turf_to_spawn)
				continue
			if (!prob(event_to_spawn.spread_chance))
				continue
			new event_type(turf_to_spawn)

	// Phase 2: Fill remaining clusters with weighted random picks
	var/clusters_spawned = length(GLOB.overmap_event_guaranteed_list)
	for (var/_ in clusters_spawned to MAX_OVERMAP_EVENT_CLUSTERS)
		if (MAX_OVERMAP_EVENTS <= LAZYLEN(events))
			return
		if (LAZYLEN(orbits) == 0 || !orbits)
			break // can't fit anymore in
		var/selected_orbit = text2num(pick(orbits))

		var/turf/turf_for_event = get_unused_overmap_square_in_radius(selected_orbit)
		if (!turf_for_event || !istype(turf_for_event))
			orbits -= "[selected_orbit]" // this one is full
			continue
		var/event_type = pick_weight(GLOB.overmap_event_pick_list)
		var/obj/structure/overmap/event/event_to_spawn = new event_type(turf_for_event)
		for (var/turf/turf_to_spawn as anything in radius_tiles[selected_orbit])
			if (locate(/obj/structure/overmap) in turf_to_spawn)
				continue
			if (!prob(event_to_spawn.spread_chance))
				continue
			new event_type(turf_to_spawn)

/datum/controller/subsystem/overmap/proc/setup_planets()
	// Init planets
	var/list/planets = SSmapping.planets
	if(!planets)
		return

	var/list/orbits = list()
	for (var/i in 2 to LAZYLEN(radius_tiles))
		orbits += "[i]"

	for (var/planet in planets)
		if (LAZYLEN(orbits) == 0 || !orbits)
			break // can't fit anymore in
		var/selected_orbit = text2num(pick(orbits))

		var/turf/turf_for_planet = get_unused_overmap_square_in_radius(selected_orbit)
		if (!turf_for_planet || !istype(turf_for_planet))
			orbits -= "[selected_orbit]" // this one is full
			continue
		var/datum/overmap/planet/planet_type = planets[planet]["type"]
		var/obj/structure/overmap/planet/planet_to_spawn = new
		planet_to_spawn.planet = planet_type
		planet_to_spawn.forceMove(turf_for_planet)

		// Transfer all of the data from the planet datum onto the planet object
		var/datum/overmap/planet/planet_info = new planet_to_spawn.planet
		planet_to_spawn.name = planet_info.name
		planet_to_spawn.desc = planet_info.desc
		planet_to_spawn.icon_state = planet_info.icon_state
		planet_to_spawn.color = planet_info.color
		qdel(planet_info)

		var/datum/map_zone/mapzone = find_free_mapzone()
		var/datum/space_level/zlevel
		var/encounter_name = "Dynamic Overmap Encounter"
		if(isnull(mapzone))
			mapzone = create_map_zone(encounter_name)
			zlevel = SSmapping.get_level(planets[planet]["z"])
			mapzone.add_space_level(zlevel)
		else
			if(mapzone.z_levels[1])
				zlevel = mapzone.z_levels[1]
			else
				zlevel = SSmapping.get_level(planets[planet]["z"])
				mapzone.add_space_level(zlevel)

		mapzone.taken = TRUE
		planet_to_spawn.mapzone = mapzone
		planet_to_spawn.loaded = TRUE

	// Midgame planets
	// var/list/datum/overmap/planet/midgame_planets = list()
	// for(var/datum/overmap/planet/planet_type as anything in subtypesof(/datum/overmap/planet))
	// 	if(initial(planet_type.spawn_rate) > 0)
	// 		midgame_planets += planet_type


	// var/list/midgame_orbits = list()
	// for (var/i in 2 to LAZYLEN(radius_tiles))
	// 	midgame_orbits += "[i]"

	// for (var/_ in 1 to MAX_OVERMAP_PLANETS_TO_SPAWN)
	// 	if (LAZYLEN(midgame_orbits) == 0 || !midgame_orbits)
	// 		break // can't fit anymore in
	// 	var/selected_orbit = text2num(pick(midgame_orbits))

	// 	var/turf/turf_for_planet = get_unused_overmap_square_in_radius(selected_orbit)
	// 	if (!turf_for_planet || !istype(turf_for_planet))
	// 		midgame_orbits -= "[selected_orbit]" // this one is full
	// 		continue

	// 	var/datum/overmap/planet/planet_type = pick(midgame_planets)
	// 	var/obj/structure/overmap/planet/planet_to_spawn = new
	// 	planet_to_spawn.planet = planet_type
	// 	planet_to_spawn.forceMove(turf_for_planet)

	// 	// Transfer all of the data from the planet datum onto the planet object
	// 	var/datum/overmap/planet/planet_info = new planet_to_spawn.planet
	// 	planet_to_spawn.name = planet_info.name
	// 	planet_to_spawn.desc = planet_info.desc
	// 	planet_to_spawn.icon_state = planet_info.icon_state
	// 	planet_to_spawn.color = planet_info.color
	// 	qdel(planet_info)

// TODO - MULTI-Z VLEVELS
/datum/controller/subsystem/overmap/proc/calculate_turf_above(turf/T)
	return

// TODO - MULTI-Z VLEVELS
/datum/controller/subsystem/overmap/proc/calculate_turf_below(turf/T)
	return

/**
 * Sets up space ruins on the overmap as mysterious signals
 * Randomly selects from available space ruin templates and places them in various orbits
 */
/datum/controller/subsystem/overmap/proc/setup_space_ruins()
	// Get available space ruin templates
	var/list/available_ruins = SSmapping.space_ruins_templates
	if(!available_ruins || !length(available_ruins))
		log_mapping("SSovermap: No space ruins available to spawn")
		return

	// Build list of orbits to use
	var/list/orbits = list()
	for(var/i in 2 to LAZYLEN(radius_tiles))
		orbits += "[i]"

	// Determine how many ruins to spawn
	var/ruins_to_spawn = rand(MIN_OVERMAP_SPACE_RUINS, MAX_OVERMAP_SPACE_RUINS)

	// Convert template list to a pickable list
	var/list/ruin_pool = list()
	for(var/ruin_id in available_ruins)
		var/datum/map_template/ruin/space/ruin = available_ruins[ruin_id]
		if(istype(ruin) && !ruin.unpickable)
			ruin_pool += ruin

	if(!length(ruin_pool))
		log_mapping("SSovermap: No pickable space ruins in pool")
		return

	var/list/used_ruins = list() // Track which ruins we've already spawned (for allow_duplicates check)

	for(var/i in 1 to ruins_to_spawn)
		if(!length(orbits))
			break // No more space in orbits

		// Pick a random orbit
		var/selected_orbit = text2num(pick(orbits))

		// Find an unused tile in this orbit
		var/turf/turf_for_ruin = get_unused_overmap_square_in_radius(selected_orbit)
		if(!turf_for_ruin || !istype(turf_for_ruin))
			orbits -= "[selected_orbit]" // This orbit is full
			continue

		// Pick a ruin template (respecting allow_duplicates)
		var/datum/map_template/ruin/space/selected_ruin
		var/list/pickable_ruins = ruin_pool.Copy()

		// Remove already-used ruins that don't allow duplicates
		for(var/datum/map_template/ruin/space/ruin in pickable_ruins)
			if(!ruin.allow_duplicates && (ruin in used_ruins))
				pickable_ruins -= ruin

		if(!length(pickable_ruins))
			break // No more ruins to pick from

		// Use weighted selection based on placement_weight if available
		var/list/weighted_ruins = list()
		for(var/datum/map_template/ruin/space/ruin in pickable_ruins)
			weighted_ruins[ruin] = ruin.placement_weight || 1
		selected_ruin = pick_weight(weighted_ruins)

		if(!selected_ruin)
			continue

		// Create the space ruin overmap object and set its template
		var/obj/structure/overmap/space_ruin/new_ruin = new(turf_for_ruin)
		new_ruin.set_ruin_template(selected_ruin)

		// Track that we've used this ruin
		used_ruins += selected_ruin

		log_mapping("SSovermap: Spawned space ruin '[selected_ruin.name]' at orbit [selected_orbit]")

	log_mapping("SSovermap: Finished spawning [length(used_ruins)] space ruins")

/**
 * Spawns all ships defined in roundstart_ship_templates.
 * The first successfully spawned ship becomes initial_ship (backward compat).
 * All spawned ships are tracked in initial_ships.
 */
/datum/controller/subsystem/overmap/proc/spawn_initial_ship()
#ifdef UNIT_TESTS
	var/list/remaining_templates = subtypesof(/datum/map_template/shuttle/voidcrew)
	for(var/templates in remaining_templates)
		var/obj/structure/overmap/ship/loaded_ship = SSshuttle.create_ship(templates)
		if(!initial_ship && loaded_ship)
			initial_ship = loaded_ship
		if(loaded_ship)
			initial_ships += loaded_ship
			RegisterSignal(loaded_ship, COMSIG_QDELETING, PROC_REF(handle_initial_ship_deletion))
		else
			log_mapping("[src] failed to load ship [templates].")
#else
	if(!length(roundstart_ship_templates))
		CRASH("No roundstart ship templates configured.")

	for(var/ship_type in roundstart_ship_templates)
		var/obj/structure/overmap/ship/spawned = SSshuttle.create_ship(ship_type)
		if(!spawned)
			stack_trace("Failed to spawn roundstart ship: [ship_type]")
			continue
		initial_ships += spawned
		RegisterSignal(spawned, COMSIG_QDELETING, PROC_REF(handle_initial_ship_deletion))

	if(!length(initial_ships))
		CRASH("Failed to spawn any roundstart ships.")

	initial_ship = initial_ships[1]
#endif

/datum/controller/subsystem/overmap/proc/handle_initial_ship_deletion(datum/source)
	SIGNAL_HANDLER

	initial_ships -= source
	if(source == initial_ship)
		initial_ship = length(initial_ships) ? initial_ships[1] : null
	message_admins("A roundstart ship was deleted. [length(initial_ships)] roundstart ship(s) remaining.")



	/**
  * Reserves a square dynamic encounter area, and spawns a ruin in it if one is supplied.
  * * on_planet - If the encounter should be on a generated planet. Required, as it will be otherwise inaccessible.
  * * target - The ruin to spawn, if any
  * * ruin_type - The ruin to spawn. Don't pass this argument if you want it to randomly select based on planet type.
  */

  /**
 * ##get_ruin_list
 *
 * Returns the SSmapping list of ruins, according to the given desired ruin type
 *
 * Arguments:
 * * ruin_type - a string, depicting the desired ruin type
 */
/datum/controller/subsystem/overmap/proc/get_ruin_list(ruin_type)
	switch(ruin_type) // temporary because SSmapping needs a refactor to make this any better
		if (ZTRAIT_LAVA_RUINS)
			return SSmapping.lava_ruins_templates
		if (ZTRAIT_ICE_RUINS)
			return SSmapping.ice_ruins_templates
		if (ZTRAIT_JUNGLE_RUINS)
			return SSmapping.jungle_ruins_templates
		if (ZTRAIT_REEBE_RUINS)
			return SSmapping.yellow_ruins_templates
		if (ZTRAIT_SPACE_RUINS)
			return SSmapping.space_ruins_templates
		if (ZTRAIT_BEACH_RUINS)
			return SSmapping.beach_ruins_templates
		if (ZTRAIT_WASTELAND_RUINS)
			return SSmapping.wasteland_ruins_templates

/datum/controller/subsystem/overmap/proc/spawn_dynamic_encounter(datum/overmap/planet/planet_type, ruin = TRUE, ignore_cooldown = FALSE, datum/map_template/ruin/ruin_type)
	log_shuttle("SSOVERMAP: SPAWNING DYNAMIC ENCOUNTER STARTED")
	var/list/ruin_list
	var/datum/map_generator/mapgen
	var/area/target_area
	var/datum/weather/weather_controller_type
	var/weather_trait
	var/datum/planet/planet_template
	if(!isnull(planet_type))
		planet_type = new planet_type
		ruin_list = get_ruin_list(planet_type.ruin_type)
		if(!isnull(planet_type.mapgen))
			mapgen = new planet_type.mapgen
		target_area = planet_type.target_area
		weather_controller_type = planet_type.weather_controller_type
		weather_trait = planet_type.weather_trait
		if(!(isnull(planet_type.planet_template)))
			planet_template = new planet_type.planet_template
		qdel(planet_type)

	if(ruin && ruin_list && !ruin_type)
		ruin_type = ruin_list[pick(ruin_list)]
		if(ispath(ruin_type))
			ruin_type = new ruin_type

	var/encounter_name = "Dynamic Overmap Encounter"
	var/datum/map_zone/mapzone = find_free_mapzone()
	var/datum/space_level/zlevel
	// ZTRAIT_LINKAGE = UNAFFECTED disables space transitions so construction is allowed
	var/list/zlevel_traits = list(ZTRAIT_MINING = TRUE, ZTRAIT_LINKAGE = UNAFFECTED)
	if(weather_trait)
		zlevel_traits[weather_trait] = TRUE

	if(isnull(mapzone))
		mapzone = create_map_zone(encounter_name)
		zlevel = SSmapping.add_new_zlevel(encounter_name, zlevel_traits)
		mapzone.add_space_level(zlevel)
	else
		if(mapzone.z_levels[1])
			zlevel = mapzone.z_levels[1]
			// Add weather trait to existing z-level if needed
			if(weather_trait)
				SSmapping.z_trait_levels[weather_trait] += list(zlevel.z_value)
		else
			zlevel = SSmapping.add_new_zlevel(encounter_name, zlevel_traits)
			mapzone.add_space_level(zlevel)

	mapzone.taken = TRUE

	var/area/filled_area = zlevel.fill_in(area_override = target_area)

	if(ruin_type)
		var/turf/ruin_turf = locate(rand(
			zlevel.low_x+6,
			zlevel.high_x-ruin_type.width-6),
			zlevel.high_y-ruin_type.height-6,
			zlevel.z_value
			)
		ruin_type.load(ruin_turf)

	if (!isnull(mapgen) && (istype(mapgen, /datum/map_generator/planet_generator)) && !isnull(planet_template))
		mapgen.generate_terrain(zlevel.get_block(), planet_template, FALSE, FALSE)
	else
		if (!isnull(mapgen))
			mapgen.generate_terrain(zlevel.get_block(), planet_template)

	if(filled_area)
		filled_area.reg_in_areas_in_z()

	if(weather_controller_type)
		new weather_controller_type(mapzone)

	// locates the first dock in the bottom left, accounting for padding and the border
	var/turf/primary_docking_turf = locate(
		zlevel.low_x+RESERVE_DOCK_DEFAULT_PADDING+1,
		zlevel.low_y+RESERVE_DOCK_DEFAULT_PADDING+1,
		zlevel.z_value
		)
	// now we need to offset to account for the first dock
	var/turf/secondary_docking_turf = locate(
		primary_docking_turf.x+RESERVE_DOCK_MAX_SIZE_LONG+RESERVE_DOCK_DEFAULT_PADDING,
		primary_docking_turf.y,
		primary_docking_turf.z
		)

	//This check exists because docking ports don't like to be deleted.
	var/obj/docking_port/stationary/primary_dock = new(primary_docking_turf)
	primary_dock.dir = NORTH
	primary_dock.name = "\improper Uncharted Space"
	primary_dock.height = RESERVE_DOCK_MAX_SIZE_SHORT
	primary_dock.width = RESERVE_DOCK_MAX_SIZE_LONG
	primary_dock.dheight = 0
	primary_dock.dwidth = 0

	var/obj/docking_port/stationary/secondary_dock = new(secondary_docking_turf)
	secondary_dock.dir = NORTH
	secondary_dock.name = "\improper Uncharted Space"
	secondary_dock.height = RESERVE_DOCK_MAX_SIZE_SHORT
	secondary_dock.width = RESERVE_DOCK_MAX_SIZE_LONG
	secondary_dock.dheight = 0
	secondary_dock.dwidth = 0

	return list(mapzone, primary_dock, secondary_dock)


/datum/controller/subsystem/overmap/proc/create_map_zone(new_name)
	return new /datum/map_zone(new_name)

/datum/controller/subsystem/overmap/proc/find_free_mapzone()
	. = null
	for(var/datum/map_zone/mapzone as anything in map_zones)
		if(!mapzone.taken)
			return(mapzone)




