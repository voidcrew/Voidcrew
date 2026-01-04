/**
 * Voidcrew Cargo Shuttle System
 * Spawns a cargo shuttle that docks next to the player's ship using ship-to-ship docking
 * Shuttle is ephemeral - created fresh each time, deleted after departure
 */

/**
 * Cargo Shuttle Controller
 * Manages the state machine and docking of the cargo shuttle
 */
/datum/voidcrew_cargo_shuttle
	/// Current state of the cargo shuttle
	var/state = CARGO_SHUTTLE_AWAY
	/// Reference to the shuttle's mobile docking port
	var/obj/docking_port/mobile/shuttle_port
	/// The cargo console this shuttle is linked to (for callbacks)
	var/obj/machinery/computer/voidcrew_cargo/linked_console
	/// Timer ID for warmup periods
	var/warmup_timer
	/// The empty space we're docking to
	var/obj/structure/overmap/planet/empty/docked_at
	/// Transit dock reservation
	var/obj/docking_port/stationary/transit/transit_dock
	/// Time when warmup started (for timer display)
	var/warmup_started
	/// Reference to the player's ship we're docking with
	var/obj/structure/overmap/ship/target_ship
	/// Which reserve dock we're using (1 or 2)
	var/cargo_dock_index = 0

/datum/voidcrew_cargo_shuttle/Destroy()
	cleanup_shuttle()
	linked_console = null
	target_ship = null
	return ..()

/**
 * Cleans up all shuttle resources
 */
/datum/voidcrew_cargo_shuttle/proc/cleanup_shuttle()
	log_shuttle("VOIDCREW CARGO: cleanup_shuttle() called")

	if(warmup_timer)
		deltimer(warmup_timer)
		warmup_timer = null
	warmup_started = null

	// Release the reserve dock
	if(docked_at && cargo_dock_index)
		log_shuttle("VOIDCREW CARGO: Releasing dock [cargo_dock_index]")
		if(cargo_dock_index == 1)
			docked_at.first_dock_taken = FALSE
		else if(cargo_dock_index == 2)
			docked_at.second_dock_taken = FALSE
		cargo_dock_index = 0

	// Delete the shuttle port
	if(shuttle_port && !QDELETED(shuttle_port))
		log_shuttle("VOIDCREW CARGO: Cleaning up shuttle_port [shuttle_port]")

		// Clear any SSshuttle references BEFORE deleting
		if(SSshuttle.supply == shuttle_port)
			SSshuttle.supply = null

		// Move back to transit dock first - this keeps the shuttle in the transit reservation
		// When we delete the transit dock, the reservation cleanup handles the turfs
		if(transit_dock && !QDELETED(transit_dock))
			log_shuttle("VOIDCREW CARGO: Moving shuttle back to transit")
			shuttle_port.initiate_docking(transit_dock, force = TRUE)

		// Now delete the shuttle port (this calls unregister())
		qdel(shuttle_port)
	shuttle_port = null

	// Clean up transit dock - this releases the turf reservation which cleans up the turfs
	if(transit_dock && !QDELETED(transit_dock))
		log_shuttle("VOIDCREW CARGO: Deleting transit dock")
		qdel(transit_dock)
	transit_dock = null

	docked_at = null
	log_shuttle("VOIDCREW CARGO: cleanup_shuttle() complete")

/**
 * Spawns the cargo shuttle using SSshuttle's transit system
 * Returns TRUE on success
 */
/datum/voidcrew_cargo_shuttle/proc/spawn_shuttle()
	// Always spawn fresh - clean up any existing shuttle first
	if(shuttle_port && !QDELETED(shuttle_port))
		log_shuttle("VOIDCREW CARGO: spawn_shuttle() cleaning up existing shuttle")
		cleanup_shuttle()
	shuttle_port = null // Ensure it's null even if QDELETED

	// Use the existing cargo_box template
	var/datum/map_template/shuttle/cargo/box/template = new()

	log_shuttle("VOIDCREW CARGO: Using template [template.name], mappath=[template.mappath]")
	log_shuttle("VOIDCREW CARGO: Template dimensions: [template.width]x[template.height]")

	if(!template.width || !template.height)
		log_shuttle("VOIDCREW CARGO: Template dimensions are 0!")
		qdel(template)
		return FALSE

	// Request transit dock from SSshuttle (proper way to get space reservation)
	transit_dock = new()
	transit_dock.reserved_area = SSmapping.request_turf_block_reservation(
		template.width + SHUTTLE_TRANSIT_BORDER * 2,
		template.height + SHUTTLE_TRANSIT_BORDER * 2,
		1,
		reservation_type = /datum/turf_reservation/transit,
	)

	if(!transit_dock.reserved_area)
		log_shuttle("VOIDCREW CARGO: Failed to reserve transit turf block")
		QDEL_NULL(transit_dock)
		qdel(template)
		return FALSE

	// Set up transit dock dimensions
	transit_dock.width = template.width
	transit_dock.height = template.height

	var/turf/transit_turf = transit_dock.reserved_area.bottom_left_turfs[1]
	// Offset by border to center shuttle in reservation
	transit_turf = locate(transit_turf.x + SHUTTLE_TRANSIT_BORDER, transit_turf.y + SHUTTLE_TRANSIT_BORDER, transit_turf.z)
	transit_dock.forceMove(transit_turf)

	log_shuttle("VOIDCREW CARGO: Loading shuttle at [transit_turf]")

	// Load the shuttle template - register = TRUE so shuttle_areas get populated
	template.load(transit_turf, centered = FALSE, register = TRUE)

	// Find the mobile docking port that was loaded
	var/list/affected = template.get_affected_turfs(transit_turf, centered = FALSE)
	for(var/turf/T in affected)
		shuttle_port = locate(/obj/docking_port/mobile) in T
		if(shuttle_port)
			break

	if(!shuttle_port)
		log_shuttle("VOIDCREW CARGO: Docking port not found in loaded template!")
		QDEL_NULL(transit_dock)
		qdel(template)
		return FALSE

	// Don't let this become SSshuttle.supply
	if(SSshuttle.supply == shuttle_port)
		SSshuttle.supply = null

	// Make shuttle_id unique
	shuttle_port.shuttle_id = "voidcrew_cargo_[REF(src)]"
	shuttle_port.name = "Voidcrew Cargo Shuttle"

	// Set up transit
	shuttle_port.assigned_transit = transit_dock
	transit_dock.owner = shuttle_port

	template.post_load(shuttle_port)
	qdel(template)

	log_shuttle("VOIDCREW CARGO: Shuttle spawned, port=[shuttle_port], shuttle_areas=[length(shuttle_port.shuttle_areas)]")
	return TRUE

/**
 * Returns the cargo bay turf for spawning items
 */
/datum/voidcrew_cargo_shuttle/proc/get_cargo_bay_turf()
	if(!shuttle_port)
		return null

	// Find any open turf in the shuttle area
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
 * Calls the cargo shuttle to dock next to the player's ship
 */
/datum/voidcrew_cargo_shuttle/proc/call_shuttle(obj/structure/overmap/ship/ship)
	if(state != CARGO_SHUTTLE_AWAY)
		log_shuttle("VOIDCREW CARGO: call_shuttle failed - state is [state], not AWAY")
		return FALSE

	if(!istype(ship?.docked, /obj/structure/overmap/planet/empty))
		log_shuttle("VOIDCREW CARGO: call_shuttle failed - ship not docked at empty space")
		return FALSE

	target_ship = ship
	docked_at = ship.docked

	// Spawn shuttle fresh
	if(!spawn_shuttle())
		log_shuttle("VOIDCREW CARGO: call_shuttle failed - spawn_shuttle returned FALSE")
		return FALSE

	// Start warmup
	state = CARGO_SHUTTLE_ARRIVING
	warmup_started = world.time
	warmup_timer = addtimer(CALLBACK(src, PROC_REF(complete_arrival)), CARGO_SHUTTLE_WARMUP, TIMER_STOPPABLE)
	log_shuttle("VOIDCREW CARGO: Shuttle called, timer set for [CARGO_SHUTTLE_WARMUP/10]s")
	return TRUE

/**
 * Timer callback - docks the shuttle after warmup using ship-to-ship docking system
 */
/datum/voidcrew_cargo_shuttle/proc/complete_arrival()
	warmup_timer = null
	warmup_started = null

	log_shuttle("VOIDCREW CARGO: complete_arrival() called")

	if(state != CARGO_SHUTTLE_ARRIVING || !docked_at || !target_ship)
		log_shuttle("VOIDCREW CARGO: complete_arrival() aborted - invalid state")
		state = CARGO_SHUTTLE_AWAY
		cleanup_shuttle()
		return FALSE

	// Make sure the empty space level is loaded
	if(!docked_at.loaded)
		log_shuttle("VOIDCREW CARGO: Empty space not loaded, loading...")
		if(!docked_at.loading)
			docked_at.load_level()
		// Schedule retry
		warmup_started = world.time // Reset for timer display
		warmup_timer = addtimer(CALLBACK(src, PROC_REF(complete_arrival)), 1 SECONDS, TIMER_STOPPABLE)
		return FALSE

	// Find the player's ship shuttle
	var/obj/docking_port/mobile/voidcrew/ship_shuttle = target_ship.shuttle
	if(!ship_shuttle)
		log_shuttle("VOIDCREW CARGO: Could not find player ship's shuttle")
		state = CARGO_SHUTTLE_AWAY
		linked_console?.say("Error: Could not locate ship.")
		cleanup_shuttle()
		return FALSE

	// Find which reserve dock the player ship is using, and get the other one
	var/obj/docking_port/stationary/ship_dock
	var/obj/docking_port/stationary/cargo_dock

	if(docked_at.first_dock_taken && docked_at.reserve_dock?.get_docked() == ship_shuttle)
		ship_dock = docked_at.reserve_dock
		cargo_dock = docked_at.reserve_dock_secondary
		if(docked_at.second_dock_taken)
			log_shuttle("VOIDCREW CARGO: Both docks taken!")
			state = CARGO_SHUTTLE_AWAY
			linked_console?.say("Error: No available docking ports.")
			cleanup_shuttle()
			return FALSE
		docked_at.second_dock_taken = TRUE
		cargo_dock_index = 2
	else if(docked_at.second_dock_taken && docked_at.reserve_dock_secondary?.get_docked() == ship_shuttle)
		ship_dock = docked_at.reserve_dock_secondary
		cargo_dock = docked_at.reserve_dock
		if(docked_at.first_dock_taken)
			log_shuttle("VOIDCREW CARGO: Both docks taken!")
			state = CARGO_SHUTTLE_AWAY
			linked_console?.say("Error: No available docking ports.")
			cleanup_shuttle()
			return FALSE
		docked_at.first_dock_taken = TRUE
		cargo_dock_index = 1
	else
		log_shuttle("VOIDCREW CARGO: Could not find player ship's dock")
		state = CARGO_SHUTTLE_AWAY
		linked_console?.say("Error: Ship docking port not found.")
		cleanup_shuttle()
		return FALSE

	log_shuttle("VOIDCREW CARGO: Ship using dock [ship_dock], cargo will use dock [cargo_dock]")

	// Use the same positioning system as ship-to-ship docking
	// This positions both docks adjacent to each other at the center of the z-level
	target_ship.position_docks_for_direct_docking(docked_at, ship_dock, cargo_dock, ship_shuttle, shuttle_port)

	log_shuttle("VOIDCREW CARGO: Docks positioned, ship_dock at ([ship_dock.x], [ship_dock.y]), cargo_dock at ([cargo_dock.x], [cargo_dock.y])")

	// Redock the player ship to its repositioned dock
	log_shuttle("VOIDCREW CARGO: Redocking player ship...")
	var/ship_result = ship_shuttle.initiate_docking(ship_dock, force = TRUE)
	log_shuttle("VOIDCREW CARGO: Ship redock result: [ship_result]")

	// Dock cargo shuttle
	log_shuttle("VOIDCREW CARGO: Docking cargo shuttle...")
	var/cargo_result = shuttle_port.initiate_docking(cargo_dock, force = TRUE)
	log_shuttle("VOIDCREW CARGO: Cargo dock result: [cargo_result]")

	if(cargo_result != DOCKING_SUCCESS)
		log_shuttle("VOIDCREW CARGO: Cargo docking FAILED")
		state = CARGO_SHUTTLE_AWAY
		linked_console?.say("Error: Shuttle docking failed.")
		cleanup_shuttle()
		return FALSE

	state = CARGO_SHUTTLE_DOCKED
	linked_console?.say("Cargo shuttle has arrived.")
	log_shuttle("VOIDCREW CARGO: Shuttle docked successfully")
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
	log_shuttle("VOIDCREW CARGO: Shuttle departing, timer set")
	return TRUE

/**
 * Timer callback - exports cargo and cleans up shuttle
 */
/datum/voidcrew_cargo_shuttle/proc/complete_departure()
	warmup_timer = null
	warmup_started = null

	log_shuttle("VOIDCREW CARGO: complete_departure() called")

	if(state != CARGO_SHUTTLE_DEPARTING)
		return FALSE

	// Export cargo before leaving
	linked_console?.sell()

	// Clean up everything - shuttle is ephemeral
	cleanup_shuttle()

	state = CARGO_SHUTTLE_AWAY
	target_ship = null
	linked_console?.say("Cargo shuttle has departed.")
	log_shuttle("VOIDCREW CARGO: Shuttle departed and cleaned up")
	return TRUE
