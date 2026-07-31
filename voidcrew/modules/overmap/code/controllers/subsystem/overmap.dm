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

SUBSYSTEM_DEF(overmap)
	name = "Overmap"
	wait = 10 // Fires every 1 second (10 deciseconds)
	init_order = INIT_ORDER_OVERMAP
	flags = NONE
	// LOBBY is in here so the roundstart planets can generate while players are still
	// picking characters - see prebuild_roundstart_planets()
	runlevels = RUNLEVEL_LOBBY | RUNLEVEL_SETUP | RUNLEVEL_GAME
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

	/// Ready players each roundstart hull is expected to carry. The fleet scales off
	/// this once turnout is known - see SSticker.create_characters().
	var/roundstart_crew_per_ship = 6
	/// Hard ceiling on roundstart hulls, however big the turnout is.
	var/roundstart_max_ships = 4
	/// The first roundstart ship spawned. Kept for backward compatibility.
	var/obj/structure/overmap/ship/initial_ship
	/// All ships spawned at round start.
	var/list/obj/structure/overmap/ship/initial_ships = list()
	/// Hull types the roundstart fleet has already rolled, so a second hull is a different class
	var/list/spent_roundstart_hulls = list()
	/// Whether the lobby pre-build pass has been kicked off. One-shot.
	var/roundstart_planets_prebuilt = FALSE
	/// TRUE once every roundstart planet is fully built AND its lighting has settled.
	/// The pre-round countdown holds at zero until this flips - see SSticker's pregame gate.
	var/roundstart_planets_ready = FALSE
	/// When the prebuild pass started, for the ticker gate's failsafe cap.
	var/prebuild_started_at = 0

/datum/controller/subsystem/overmap/Initialize(start_timeofday)
	create_map()
	setup_sun()
	setup_dangers()
	setup_planets()
	setup_space_ruins()
	setup_trader_outposts()
	schedule_vestige_ruins()
	schedule_contested_caches()
	schedule_lich_lair()
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

	// First tick after FULL world init: start generating the roundstart planets in the
	// background. Flag is set before the call so a long build can't be started twice.
	//
	// The init_stage check is load-bearing: the MC opens the lobby and starts firing
	// early-stage subsystems while later init stages are still running, so without it
	// the prebuild generates terrain DURING world init. Any light source queued in that
	// window gets stranded by the overlap between SSlighting.Initialize's direct
	// fire() drain and the MC's regular fires (both non-resumed, each replacing
	// current_sources) - the planet is then permanently unlit (probe rounds 768/769).
	if(!roundstart_planets_prebuilt && Master.init_stage_completed == INITSTAGE_MAX)
		roundstart_planets_prebuilt = TRUE
		INVOKE_ASYNC(src, PROC_REF(prebuild_roundstart_planets))

/**
 * Generates the roundstart planets during the pre-round lobby.
 *
 * Planets build themselves on first visit, which is what keeps an unvisited one free -
 * but for the planets that exist at roundstart there is nothing to save: the crew is
 * going to find them. Doing it now means the ~20s per planet is spent while people are
 * still in the lobby picking characters, instead of stalling the first ship to try
 * landing somewhere.
 *
 * Sequential on purpose. Each build is already CHECK_TICK'd throughout and allocating
 * z-levels serialises anyway, so running them in parallel would just interleave the
 * lag. Anything not finished by the time the round starts still builds on arrival.
 */
/datum/controller/subsystem/overmap/proc/prebuild_roundstart_planets()
	prebuild_started_at = world.time
	var/built = 0
	var/start = REALTIMEOFDAY
	for(var/obj/structure/overmap/planet/marker as anything in GLOB.overmap_planets.Copy())
		if(QDELETED(marker) || marker.mapzone || marker.loading)
			continue
		if(!marker.is_terrain_planet())
			continue
		marker.load_level()
		built++
	if(built)
		log_mapping("SSovermap: Pre-built [built] roundstart planet(s) in [(REALTIMEOFDAY - start) / 10]s")
		// Generation queues a light source per surface turf - six figures of lighting
		// work across the fleet of planets that SSlighting chews through at its own
		// pace. A planet is not "done" until that has settled: without this, the round
		// starts onto pitch-black planets that slowly fade in over the next several
		// minutes while SSlighting eats the whole roundstart tick budget.
		wait_for_lighting_settle()
	roundstart_planets_ready = TRUE
	log_mapping("SSovermap: Roundstart planets ready ([(REALTIMEOFDAY - start) / 10]s total)")

/// Sleeps until SSlighting's pipeline has fully drained (two consecutive empty checks,
/// since sources feed corners feed objects between fires). Capped so a wedged queue
/// can't hold the round hostage.
/datum/controller/subsystem/overmap/proc/wait_for_lighting_settle(cap = 5 MINUTES)
	var/started = world.time
	var/consecutive_empty = 0
	while(world.time < started + cap)
		if(!length(SSlighting.sources_queue) && !length(SSlighting.corners_queue) && !length(SSlighting.objects_queue))
			consecutive_empty++
			if(consecutive_empty >= 2)
				return TRUE
		else
			consecutive_empty = 0
		sleep(1 SECONDS)
	log_mapping("SSovermap: lighting settle wait hit its [cap / 600] minute cap (sources=[length(SSlighting.sources_queue)] corners=[length(SSlighting.corners_queue)] objects=[length(SSlighting.objects_queue)])")
	return FALSE

/**
 * Whether the pre-round countdown should keep holding for planet generation.
 * Failsafe: if the prebuild has been running for an unreasonable amount of time,
 * something is wedged - let the round start rather than hold the lobby forever.
 */
/datum/controller/subsystem/overmap/proc/roundstart_planets_pending()
	if(roundstart_planets_ready)
		return FALSE
	// A dead overmap will never run the prebuild - don't deadlock the lobby over it
	if(!initialized || !can_fire)
		return FALSE
	// SSovermap hasn't had its first lobby fire yet - the prebuild is still coming
	if(!roundstart_planets_prebuilt)
		return TRUE
	if(prebuild_started_at && world.time - prebuild_started_at > 10 MINUTES)
		log_mapping("SSovermap: planet prebuild failsafe tripped - starting the round without it")
		message_admins("Roundstart planet generation exceeded 10 minutes; the round is starting without waiting for it.")
		roundstart_planets_ready = TRUE
		return FALSE
	return TRUE

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

	// Instantiate the PICKED type - a bare `new` here builds the declared type instead
	// and the binary system could never roll
	var/star_to_spawn_type = pick(/obj/structure/overmap/star/big, /obj/structure/overmap/star/big/binary)
	var/obj/structure/overmap/star/big/star_to_spawn = new star_to_spawn_type
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

	// Tracks landable meteor storm / asteroid field events spawned below (main +
	// spread copies), so we can top up to MIN_OVERMAP_ASTEROID_FIELDS afterward.
	// This is the mining-content guarantee that used to target space ruin asteroid
	// signals (MIN_OVERMAP_ASTEROID_SIGNALS) before that category was retired.
	var/meteor_count = 0

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
		if (istype(event_to_spawn, /obj/structure/overmap/event/meteor))
			meteor_count++
		for (var/turf/turf_to_spawn as anything in radius_tiles[selected_orbit])
			if (locate(/obj/structure/overmap) in turf_to_spawn)
				continue
			if (!prob(event_to_spawn.spread_chance))
				continue
			var/obj/structure/overmap/event/spread_event = new event_type(turf_to_spawn)
			if (istype(spread_event, /obj/structure/overmap/event/meteor))
				meteor_count++

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
		if (istype(event_to_spawn, /obj/structure/overmap/event/meteor))
			meteor_count++
		for (var/turf/turf_to_spawn as anything in radius_tiles[selected_orbit])
			if (locate(/obj/structure/overmap) in turf_to_spawn)
				continue
			if (!prob(event_to_spawn.spread_chance))
				continue
			var/obj/structure/overmap/event/spread_event = new event_type(turf_to_spawn)
			if (istype(spread_event, /obj/structure/overmap/event/meteor))
				meteor_count++

	// Guarantee a minimum number of landable asteroid field events per round, so space
	// mining is a dependable resource loop rather than a lucky roll of the weighted picker
	while (meteor_count < MIN_OVERMAP_ASTEROID_FIELDS)
		var/turf/turf_for_field = get_unused_overmap_square()
		if (!turf_for_field)
			break
		new /obj/structure/overmap/event/meteor(turf_for_field)
		meteor_count++
		log_mapping("SSovermap: Spawned guaranteed asteroid field event")

/**
 * Places the round's planets on the overmap.
 *
 * Two supply models feed this. Anything SSmapping preloaded (the *_planet_count knobs
 * in _mapping.dm) already owns a generated z-level pair at boot and only needs a marker
 * wired to it. Every other planet type spawns as a DYNAMIC marker: an overmap contact
 * with no interior at all - no map zone, no z-level, no docks - whose surface is
 * generated the first time a ship docks or a survey shuttle maps it
 * (planet/load_level() -> spawn_dynamic_encounter()).
 *
 * An unvisited dynamic planet costs nothing but its overmap tile, which is why the
 * preloaded counts are all zero: each of those is a full 255x255 z-pair sitting in
 * memory whether or not anyone ever goes there.
 */
/datum/controller/subsystem/overmap/proc/setup_planets()
	// Init planets
	var/list/planets = SSmapping.planets
	if(!planets)
		return

	var/list/orbits = list()
	for (var/i in 2 to LAZYLEN(radius_tiles))
		orbits += "[i]"

	for (var/planet in planets)
		var/turf/turf_for_planet
		// Roundstart planets pre-rolled a zone band before their terrain generated
		// (SSmapping.next_planet_zone_band()) — place them inside that band so the
		// zone-scaled mobs/weather they were built with match their overmap tile
		var/wanted_band = planets[planet]["zone_band"]
		if(wanted_band)
			turf_for_planet = get_unused_overmap_square_in_zone_band(wanted_band, tries = 80) // red band is ~9% of tiles, needs generous sampling
			if(!turf_for_planet)
				log_mapping("SSovermap: Failed to place planet '[planet]' in its assigned zone band [wanted_band], falling back to any orbit")
		if(!turf_for_planet) // fallback: legacy random-orbit placement
			if (LAZYLEN(orbits) == 0 || !orbits)
				break // can't fit anymore in
			var/selected_orbit = text2num(pick(orbits))
			turf_for_planet = get_unused_overmap_square_in_radius(selected_orbit)
			if (!turf_for_planet || !istype(turf_for_planet))
				orbits -= "[selected_orbit]" // this one is full
				continue
		var/datum/overmap/planet/planet_type = planets[planet]["type"]
		var/obj/structure/overmap/planet/planet_to_spawn = new
		planet_to_spawn.planet = planet_type
		// Roundstart planets are static: their z-pair was generated once during SSmapping
		// init and can never be rebuilt, so no unload path may ever clear it
		planet_to_spawn.preserve_level = TRUE
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

	// Dynamic planets: one marker per planet type SSmapping did not preload. They are
	// full overmap contacts - named, charted, scannable - with no interior at all until
	// someone visits. Bands come from the same shuffled pool the preloaded planets draw
	// from, so the first three cover green, yellow and red instead of every planet
	// piling into the safe outer ring.
	var/list/preloaded_types = list()
	for(var/planet_key in planets)
		preloaded_types |= planets[planet_key]["type"]

	var/list/dynamic_planet_markers = list(
		/obj/structure/overmap/planet/lava,
		/obj/structure/overmap/planet/ice,
		/obj/structure/overmap/planet/jungle,
		/obj/structure/overmap/planet/beach,
		/obj/structure/overmap/planet/wasteland,
	)
	for(var/obj/structure/overmap/planet/marker_type as anything in dynamic_planet_markers.Copy())
		if(initial(marker_type.planet) in preloaded_types)
			dynamic_planet_markers -= marker_type

	for(var/obj/structure/overmap/planet/marker_type as anything in dynamic_planet_markers)
		var/wanted_band = SSmapping.next_planet_zone_band()
		var/turf/turf_for_planet = get_unused_overmap_square_in_zone_band(wanted_band, tries = 80) // red band is ~9% of tiles, needs generous sampling
		if(!turf_for_planet)
			log_mapping("SSovermap: Failed to place dynamic planet [marker_type] in zone band [wanted_band], falling back to any free square")
			turf_for_planet = get_unused_overmap_square()
		if(!turf_for_planet)
			log_mapping("SSovermap: Failed to place dynamic planet [marker_type] - no free overmap square")
			continue
		var/obj/structure/overmap/planet/planet_to_spawn = new marker_type(turf_for_planet)
		// Remembered rather than re-derived, so the planet keeps its difficulty when it
		// relocates after being abandoned
		planet_to_spawn.zone_band = wanted_band

		// SSovermap initializes before SSatoms, so the marker's Initialize() - which is
		// what normally copies the planet datum's identity onto it - has not run yet and
		// will not until SSatoms drains its queue. Copy the identity across now so the
		// contact is never briefly a nameless "weak energy signature".
		var/datum/overmap/planet/planet_info = new planet_to_spawn.planet
		planet_to_spawn.name = planet_info.name
		planet_to_spawn.desc = planet_info.desc
		planet_to_spawn.icon_state = planet_info.icon_state
		planet_to_spawn.color = planet_info.color
		qdel(planet_info)

		log_mapping("SSovermap: Spawned dynamic planet '[planet_to_spawn.name]' (unloaded) in zone band [wanted_band] at ([turf_for_planet.x], [turf_for_planet.y])")

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

	// Asteroid mining no longer has a guarantee here - space ruin signals retired the
	// "asteroid" category entirely. The equivalent guarantee (MIN_OVERMAP_ASTEROID_FIELDS)
	// now targets landable meteor storm field events instead; see setup_dangers().
	log_mapping("SSovermap: Finished spawning [length(used_ruins)] space ruins")

/**
 * Returns the zone band (ZONE_RED/YELLOW/GREEN) a turf falls in, computed from
 * distance to the sun. Mirrors SSovermap_zones.calculate_zone_for_turf(), which
 * can't be used here because SSovermap_zones initializes after SSovermap.
 * Zones are static concentric rings, so the distance math is the ground truth.
 */
/datum/controller/subsystem/overmap/proc/get_zone_band_for_turf(turf/T)
	if(!T || !overmap_centre)
		return ZONE_GREEN
	var/max_radius = (OVERMAP_SIZE - 1) / 2
	var/dx = T.x - overmap_centre.x
	var/dy = T.y - overmap_centre.y
	var/normalized = sqrt(dx * dx + dy * dy) / max_radius
	if(normalized < ZONE_INNER_RING_RATIO)
		return ZONE_RED
	if(normalized < ZONE_MIDDLE_RING_RATIO)
		return ZONE_YELLOW
	return ZONE_GREEN

/**
 * Places one trader outpost per zone band (black market deep, outfitter mid,
 * general store in the safe outer ring). Outposts are permanent and never move.
 */
/datum/controller/subsystem/overmap/proc/setup_trader_outposts()
	var/list/wanted = list(
		"[ZONE_RED]" = /obj/structure/overmap/trader_outpost/black_market,
		"[ZONE_YELLOW]" = /obj/structure/overmap/trader_outpost/outfitter,
		"[ZONE_GREEN]" = /obj/structure/overmap/trader_outpost/general,
	)

	for(var/_ in 1 to MAX_OUTPOST_PLACEMENT_ATTEMPTS)
		if(!length(wanted))
			break
		var/turf/candidate = get_unused_overmap_square()
		if(!candidate)
			continue
		var/band = "[get_zone_band_for_turf(candidate)]"
		var/outpost_type = wanted[band]
		if(!outpost_type)
			continue
		var/obj/structure/overmap/trader_outpost/outpost = new outpost_type(candidate)
		outpost.load_level() // pre-load interior at init instead of on first dock
		wanted -= band
		log_mapping("SSovermap: Spawned trader outpost '[outpost.name]' in zone band [band] at ([candidate.x], [candidate.y])")

	for(var/band in wanted)
		log_mapping("SSovermap: WARNING - failed to place a trader outpost in zone band [band]")

/**
 * Spawns the ship the round is anchored on.
 *
 * Only one hull spawns here. Fleet size follows turnout, and nobody has readied up
 * yet at SSovermap init - the rest of the fleet is spawned by scale_roundstart_fleet()
 * once SSticker knows how many players it has. This one still has to exist now, since
 * it carries the observer_start landmark pre-round ghosts spawn on.
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
	if(!spawn_roundstart_hull())
		CRASH("Failed to spawn any roundstart ships.")
#endif

/**
 * Rolls and spawns one roundstart hull: a random modular hull, a random theme on it,
 * and a random module in every one of its upgrade slots.
 *
 * Costs are ignored throughout - nobody is paying for these. Hull classes are drawn
 * without replacement while the pool lasts, so a three-ship round is three different
 * classes rather than three Scarabs.
 *
 * Returns the spawned ship, or null on failure.
 */
/datum/controller/subsystem/overmap/proc/spawn_roundstart_hull()
	var/list/pool = get_roundstart_hull_templates()
	if(!length(pool))
		CRASH("No modular hulls are eligible to spawn at round start.")

	var/list/unused = pool - spent_roundstart_hulls
	var/datum/map_template/shuttle/voidcrew/hull = pick(length(unused) ? unused : pool)

	var/datum/ship_theme/theme = roll_random_ship_theme(hull.type)
	var/list/selections = roll_random_upgrade_selections(hull, theme)

	// Pass the type path, not the catalog instance: create_ship rewrites suffix and
	// mappath on whatever template object it's handed
	var/obj/structure/overmap/ship/spawned = SSshuttle.create_ship(hull.type, selections, theme)
	if(!spawned)
		stack_trace("Failed to spawn roundstart ship: [hull.type]")
		return null

	spent_roundstart_hulls += hull
	initial_ships += spawned
	if(!initial_ship)
		initial_ship = spawned
	RegisterSignal(spawned, COMSIG_QDELETING, PROC_REF(handle_initial_ship_deletion))

	var/list/rolled = list()
	for(var/slot_key in selections)
		var/datum/ship_upgrade_module/module = selections[slot_key]
		rolled += "[slot_key]=[module.id]"
	log_mapping("SSovermap: roundstart hull [hull.name] spawned as '[spawned.name]' \
		(theme: [theme?.id || "none"], modules: [length(rolled) ? rolled.Join(", ") : "defaults"])")

	return spawned

/**
 * Grows the roundstart fleet to match how many players actually readied up.
 *
 * Called from SSticker.create_characters() before anyone is assigned a job, so the
 * hulls exist by the time crews are dealt out. Never shrinks the fleet.
 *
 * Returns the number of hulls in the fleet.
 */
/datum/controller/subsystem/overmap/proc/scale_roundstart_fleet(ready_count)
	var/wanted = clamp(CEILING(ready_count / roundstart_crew_per_ship, 1), 1, roundstart_max_ships)
	while(length(initial_ships) < wanted)
		if(!spawn_roundstart_hull())
			break
	log_mapping("SSovermap: roundstart fleet scaled to [length(initial_ships)] hull(s) for [ready_count] ready player(s) (wanted [wanted]).")
	return length(initial_ships)

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

/datum/controller/subsystem/overmap/proc/spawn_dynamic_encounter(datum/overmap/planet/planet_type, ruin = TRUE, ignore_cooldown = FALSE, datum/map_template/ruin/ruin_type, zone_band)
	log_shuttle("SSOVERMAP: SPAWNING DYNAMIC ENCOUNTER STARTED")
	var/list/ruin_list
	var/datum/map_generator/mapgen
	var/area/target_area
	var/weather_trait
	var/datum/planet/planet_template
	if(!isnull(planet_type))
		planet_type = new planet_type
		ruin_list = get_ruin_list(planet_type.ruin_type)
		if(!isnull(planet_type.mapgen))
			mapgen = new planet_type.mapgen
		target_area = planet_type.target_area
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
		else
			zlevel = SSmapping.add_new_zlevel(encounter_name, zlevel_traits)
			mapzone.add_space_level(zlevel)

	// Dynamic levels appear after SSweather.Initialize and map zones are recycled.
	// Replace any prior encounter's trait, active storm, and cooldown before registering
	// the new planet's weather.
	SSweather.set_z_level_weather_trait(zlevel, weather_trait)

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
		// Terrain generation only lays turfs down and tags each one with the biome it
		// came from - every scrap of flora, fauna and ground feature comes from the
		// population pass, which historically only SSmapping's roundstart init ever
		// ran. Without this a dynamically generated planet is bare landscape. The turf
		// list is rebuilt because generation replaced every turf on the level.
		mapgen.populate_terrain(zlevel.get_block(), filled_area, zone_band)
	else
		if (!isnull(mapgen))
			mapgen.generate_terrain(zlevel.get_block(), planet_template)

	if(filled_area)
		filled_area.reg_in_areas_in_z()

	// Anything mapgen/ruins didn't touch is still uninitialized /turf/open/space/basic,
	// which players can't interact with (no throwing, no construction). For space
	// encounters, empty space and player outposts that's the ENTIRE level.
	zlevel.initialize_space_turfs()

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

