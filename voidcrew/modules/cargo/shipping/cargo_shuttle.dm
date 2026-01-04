/**
 * Cargo Shuttle Area
 */
/area/shuttle/voidcrew_cargo
	name = "Cargo Shuttle"
	icon_state = "shuttle"

/**
 * Cargo Shuttle Docking Port
 */
/obj/docking_port/mobile/voidcrew_cargo
	name = "Cargo Shuttle"
	shuttle_id = "voidcrew_cargo"
	area_type = /area/shuttle/voidcrew_cargo
	port_direction = SOUTH
	preferred_direction = NORTH

/**
 * Cargo Shuttle Map Template
 */
/datum/map_template/shuttle/voidcrew_cargo
	name = "Voidcrew Cargo Shuttle"
	prefix = "_maps/voidcrew/shuttles/"
	suffix = "cargo"
	port_id = "voidcrew_cargo"
	shuttle_id = "voidcrew_cargo"

/datum/map_template/shuttle/voidcrew_cargo/New()
	. = ..()
	mappath = "[prefix]cargo_shuttle.dmm"

/**
 * Cargo Shuttle Controller
 * Manages the state machine and docking of the cargo shuttle
 */
/datum/voidcrew_cargo_shuttle
	/// Current state of the cargo shuttle
	var/state = CARGO_SHUTTLE_AWAY
	/// Reference to the shuttle's mobile docking port
	var/obj/docking_port/mobile/voidcrew_cargo/shuttle_port
	/// The cargo console this shuttle is linked to
	var/obj/machinery/computer/voidcrew_cargo/linked_console
	/// Timer ID for warmup periods
	var/warmup_timer
	/// The empty space we're docked at
	var/obj/structure/overmap/planet/empty/docked_at
	/// Temporary stationary dock we created for docking
	var/obj/docking_port/stationary/temp_dock
	/// The turf reservation for the shuttle
	var/datum/turf_reservation/shuttle_reservation
	/// Time when warmup started (for timer display)
	var/warmup_started

/datum/voidcrew_cargo_shuttle/Destroy()
	if(warmup_timer)
		deltimer(warmup_timer)
	if(shuttle_port)
		shuttle_port.jumpToNullSpace()
		QDEL_NULL(shuttle_port)
	QDEL_NULL(temp_dock)
	QDEL_NULL(shuttle_reservation)
	linked_console?.cargo_shuttle = null
	linked_console = null
	docked_at = null
	return ..()

/**
 * Spawns the cargo shuttle into transit space
 */
/datum/voidcrew_cargo_shuttle/proc/spawn_shuttle()
	if(shuttle_port)
		return TRUE

	var/datum/map_template/shuttle/voidcrew_cargo/template = new()

	// Request a turf block in transit space
	shuttle_reservation = SSmapping.request_turf_block_reservation(
		template.width,
		template.height,
		1,
		reservation_type = /datum/turf_reservation/transit,
	)
	if(!shuttle_reservation)
		qdel(template)
		return FALSE

	var/turf/bottom_left = shuttle_reservation.bottom_left_turfs[1]
	template.load(bottom_left, centered = FALSE, register = FALSE)

	// Find the mobile docking port
	var/list/affected = template.get_affected_turfs(bottom_left, centered = FALSE)
	for(var/turf/T in affected)
		for(var/obj/docking_port/mobile/voidcrew_cargo/port in T)
			shuttle_port = port
			break
		if(shuttle_port)
			break

	if(!shuttle_port)
		qdel(template)
		QDEL_NULL(shuttle_reservation)
		return FALSE

	// Register the shuttle
	shuttle_port.register()
	template.post_load(shuttle_port)
	qdel(template)
	return TRUE

/**
 * Returns the cargo bay turf for spawning items
 */
/datum/voidcrew_cargo_shuttle/proc/get_cargo_bay_turf()
	if(!shuttle_port)
		return null

	// Find the cargo bay landmark in the shuttle's areas
	for(var/obj/effect/landmark/voidcrew_cargo_bay/landmark in GLOB.landmarks_list)
		var/turf/T = get_turf(landmark)
		if(T && shuttle_port.shuttle_areas[get_area(T)])
			return T

	// Fallback: find any open turf in the shuttle area
	for(var/area/shuttle_area as anything in shuttle_port.shuttle_areas)
		for(var/turf/open/floor/T in shuttle_area)
			if(!T.is_blocked_turf())
				return T

	return null

/**
 * Returns all cargo bay turfs for exporting
 */
/datum/voidcrew_cargo_shuttle/proc/get_cargo_bay_turfs()
	var/list/turfs = list()
	if(!shuttle_port)
		return turfs

	for(var/area/shuttle_area as anything in shuttle_port.shuttle_areas)
		for(var/turf/open/floor/T in shuttle_area)
			turfs += T

	return turfs

/**
 * Gets remaining warmup time in seconds
 */
/datum/voidcrew_cargo_shuttle/proc/get_remaining_time()
	if(!warmup_started)
		return 0
	var/elapsed = world.time - warmup_started
	var/remaining = max(0, CARGO_SHUTTLE_WARMUP - elapsed)
	return round(remaining / 10) // Convert to seconds

/**
 * Calls the cargo shuttle to dock at the player's ship
 */
/datum/voidcrew_cargo_shuttle/proc/call_shuttle(obj/structure/overmap/ship/target_ship)
	if(state != CARGO_SHUTTLE_AWAY)
		return FALSE

	if(!istype(target_ship?.docked, /obj/structure/overmap/planet/empty))
		return FALSE

	docked_at = target_ship.docked

	// Spawn shuttle if not already spawned
	if(!spawn_shuttle())
		return FALSE

	// Start warmup
	state = CARGO_SHUTTLE_ARRIVING
	warmup_started = world.time
	warmup_timer = addtimer(CALLBACK(src, PROC_REF(complete_arrival)), CARGO_SHUTTLE_WARMUP, TIMER_STOPPABLE)
	return TRUE

/**
 * Timer callback - docks the shuttle after warmup
 */
/datum/voidcrew_cargo_shuttle/proc/complete_arrival()
	warmup_timer = null
	warmup_started = null

	if(state != CARGO_SHUTTLE_ARRIVING || !docked_at)
		state = CARGO_SHUTTLE_AWAY
		return FALSE

	// Make sure the empty space level is loaded
	if(!docked_at.loaded)
		if(!docked_at.loading)
			docked_at.load_level()
		// Schedule retry
		warmup_timer = addtimer(CALLBACK(src, PROC_REF(complete_arrival)), 1 SECONDS, TIMER_STOPPABLE)
		return FALSE

	// Find a location in the empty space z-level
	if(!docked_at.mapzone || !length(docked_at.mapzone.z_levels))
		state = CARGO_SHUTTLE_AWAY
		linked_console?.say("Error: Could not access empty space.")
		return FALSE

	var/datum/space_level/zlevel = docked_at.mapzone.z_levels[1]

	// Create a temporary stationary dock
	var/center_x = round(world.maxx / 2) + 20 // Offset from ships
	var/center_y = round(world.maxy / 2)
	var/turf/dock_loc = locate(center_x, center_y, zlevel.z_value)

	if(!dock_loc)
		state = CARGO_SHUTTLE_AWAY
		linked_console?.say("Error: Could not find docking location.")
		return FALSE

	temp_dock = new /obj/docking_port/stationary(dock_loc)
	temp_dock.name = "Cargo Shuttle Dock"
	temp_dock.shuttle_id = "voidcrew_cargo_temp"
	temp_dock.dir = SOUTH

	// Size the dock to fit the shuttle
	temp_dock.width = shuttle_port.width
	temp_dock.height = shuttle_port.height
	temp_dock.dwidth = shuttle_port.dwidth
	temp_dock.dheight = shuttle_port.dheight

	// Request docking
	shuttle_port.request(temp_dock)

	state = CARGO_SHUTTLE_DOCKED
	linked_console?.say("Cargo shuttle has arrived.")
	return TRUE

/**
 * Sends the cargo shuttle away
 */
/datum/voidcrew_cargo_shuttle/proc/send_shuttle()
	if(state != CARGO_SHUTTLE_DOCKED)
		return FALSE

	state = CARGO_SHUTTLE_DEPARTING
	warmup_started = world.time
	warmup_timer = addtimer(CALLBACK(src, PROC_REF(complete_departure)), CARGO_SHUTTLE_WARMUP, TIMER_STOPPABLE)
	return TRUE

/**
 * Timer callback - undocks and exports cargo
 */
/datum/voidcrew_cargo_shuttle/proc/complete_departure()
	warmup_timer = null
	warmup_started = null

	if(state != CARGO_SHUTTLE_DEPARTING)
		return FALSE

	// Export cargo before leaving
	linked_console?.sell()

	// Undock - move shuttle back to transit
	shuttle_port.jumpToNullSpace()

	// Clean up temporary dock
	QDEL_NULL(temp_dock)

	state = CARGO_SHUTTLE_AWAY
	docked_at = null
	linked_console?.say("Cargo shuttle has departed.")
	return TRUE

/**
 * Landmark for cargo bay spawn location
 */
/obj/effect/landmark/voidcrew_cargo_bay
	name = "cargo bay"
	icon_state = "x"
