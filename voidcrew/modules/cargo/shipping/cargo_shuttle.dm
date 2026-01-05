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
	/// Transaction history - list of lists with keys: type, name, amount, value, time
	var/list/transaction_history = list()
	/// Maximum history entries to keep
	var/max_history = 50
	/// Current pending shuttle loan offer (if any)
	var/datum/voidcrew_shuttle_loan/pending_loan
	/// Whether a loan was accepted and items should spawn on arrival
	var/loan_accepted = FALSE

/**
 * Records a transaction in the history
 */
/datum/voidcrew_cargo_shuttle/proc/record_transaction(type, name, amount, value)
	var/list/entry = list(
		"type" = type,
		"name" = name,
		"amount" = amount,
		"value" = value,
		"time" = station_time_timestamp()
	)
	transaction_history.Insert(1, list(entry)) // Insert at beginning (newest first)
	if(length(transaction_history) > max_history)
		transaction_history.len = max_history

/datum/voidcrew_cargo_shuttle/Destroy()
	cleanup_shuttle()
	linked_console = null
	target_ship = null
	QDEL_NULL(pending_loan)
	return ..()

/**
 * Receives a new shuttle loan offer
 * Returns TRUE if offer was received successfully
 */
/datum/voidcrew_cargo_shuttle/proc/receive_loan_offer(datum/voidcrew_shuttle_loan/loan_type)
	if(pending_loan)
		return FALSE // Already have a pending offer
	if(state != CARGO_SHUTTLE_AWAY)
		return FALSE // Shuttle is busy

	pending_loan = new loan_type()
	return TRUE

/**
 * Accepts the current shuttle loan offer
 * Returns TRUE if accepted successfully
 */
/datum/voidcrew_cargo_shuttle/proc/accept_loan()
	if(!pending_loan)
		return FALSE
	if(state != CARGO_SHUTTLE_AWAY)
		return FALSE

	loan_accepted = TRUE

	// Add bonus credits to the linked bank account
	if(linked_console?.bank_account_holder?.synced_bank_account && pending_loan.bonus_credits > 0)
		linked_console.bank_account_holder.synced_bank_account.adjust_money(pending_loan.bonus_credits)
		record_transaction("loan", pending_loan.logging_desc, 1, pending_loan.bonus_credits)

	// Announce acceptance
	if(target_ship)
		target_ship.ship_announce(pending_loan.thanks_msg, pending_loan.sender)

	return TRUE

/**
 * Declines/clears the current shuttle loan offer
 */
/datum/voidcrew_cargo_shuttle/proc/decline_loan()
	QDEL_NULL(pending_loan)
	loan_accepted = FALSE

/**
 * Cleans up all shuttle resources (for error states, not normal departure)
 */
/datum/voidcrew_cargo_shuttle/proc/cleanup_shuttle()
	if(warmup_timer)
		deltimer(warmup_timer)
		warmup_timer = null
	warmup_started = null

	// Release the reserve dock
	if(docked_at && cargo_dock_index)
		if(cargo_dock_index == 1)
			docked_at.first_dock_taken = FALSE
		else if(cargo_dock_index == 2)
			docked_at.second_dock_taken = FALSE
		cargo_dock_index = 0

	// Don't move to transit before destroying - just destroy where it is
	// Moving causes baseturfs accumulation issues
	destroy_shuttle()

	docked_at = null

/**
 * Spawns the cargo shuttle using SSshuttle's transit system
 * Returns TRUE on success
 */
/datum/voidcrew_cargo_shuttle/proc/spawn_shuttle()
	// Always spawn fresh - clean up any existing shuttle first
	if(shuttle_port && !QDELETED(shuttle_port))
		cleanup_shuttle()
	shuttle_port = null // Ensure it's null even if QDELETED

	// Use the existing cargo_box template
	var/datum/map_template/shuttle/cargo/box/template = new()

	if(!template.width || !template.height)
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

	// Load the shuttle template - register = TRUE so shuttle_areas get populated
	template.load(transit_turf, centered = FALSE, register = TRUE)

	// Find the mobile docking port that was loaded
	var/list/affected = template.get_affected_turfs(transit_turf, centered = FALSE)
	for(var/turf/T in affected)
		shuttle_port = locate(/obj/docking_port/mobile) in T
		if(shuttle_port)
			break

	if(!shuttle_port)
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
		log_shuttle("LOAN DEBUG: get_cargo_bay_turfs - shuttle_port is null!")
		return turfs

	var/area_count = 0
	var/turf_count = 0
	for(var/area/shuttle_area as anything in shuttle_port.shuttle_areas)
		area_count++
		for(var/turf/T in shuttle_area)
			turf_count++
			if(istype(T, /turf/open/floor))
				turfs += T

	log_shuttle("LOAN DEBUG: get_cargo_bay_turfs - areas=[area_count], total_turfs=[turf_count], floor_turfs=[length(turfs)]")
	return turfs

/**
 * Gets remaining warmup time in seconds
 */
/datum/voidcrew_cargo_shuttle/proc/get_remaining_time()
	if(!warmup_started)
		return 0
	var/elapsed = world.time - warmup_started
	var/warmup_duration = (state == CARGO_SHUTTLE_DEPARTING) ? CARGO_SHUTTLE_DEPARTURE_WARMUP : CARGO_SHUTTLE_WARMUP
	var/remaining = max(0, warmup_duration - elapsed)
	return round(remaining / 10) // Convert to seconds

/**
 * Calls the cargo shuttle to dock next to the player's ship
 */
/datum/voidcrew_cargo_shuttle/proc/call_shuttle(obj/structure/overmap/ship/ship)
	if(state != CARGO_SHUTTLE_AWAY)
		return FALSE

	if(!istype(ship?.docked, /obj/structure/overmap/planet/empty))
		return FALSE

	target_ship = ship
	docked_at = ship.docked

	// Spawn shuttle fresh
	if(!spawn_shuttle())
		return FALSE

	// Start warmup
	state = CARGO_SHUTTLE_ARRIVING
	warmup_started = world.time
	warmup_timer = addtimer(CALLBACK(src, PROC_REF(complete_arrival)), CARGO_SHUTTLE_WARMUP, TIMER_STOPPABLE)
	return TRUE

/**
 * Timer callback - docks the shuttle after warmup using ship-to-ship docking system
 */
/datum/voidcrew_cargo_shuttle/proc/complete_arrival()
	warmup_timer = null
	warmup_started = null

	if(state != CARGO_SHUTTLE_ARRIVING || !docked_at || !target_ship)
		state = CARGO_SHUTTLE_AWAY
		cleanup_shuttle()
		return FALSE

	// Make sure the empty space level is loaded
	if(!docked_at.loaded)
		if(!docked_at.loading)
			docked_at.load_level()
		// Schedule retry
		warmup_started = world.time // Reset for timer display
		warmup_timer = addtimer(CALLBACK(src, PROC_REF(complete_arrival)), 1 SECONDS, TIMER_STOPPABLE)
		return FALSE

	// Find the player's ship shuttle
	var/obj/docking_port/mobile/voidcrew/ship_shuttle = target_ship.shuttle
	if(!ship_shuttle)
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
			state = CARGO_SHUTTLE_AWAY
			linked_console?.say("Error: No available docking ports.")
			cleanup_shuttle()
			return FALSE
		docked_at.first_dock_taken = TRUE
		cargo_dock_index = 1
	else
		state = CARGO_SHUTTLE_AWAY
		linked_console?.say("Error: Ship docking port not found.")
		cleanup_shuttle()
		return FALSE

	// Calculate the correct dir for ship_dock based on ship_shuttle's current geometry
	// We can't call adjust_dock_to_shuttle because it also moves the dock
	// This is necessary because construction console port relocation updates port_direction
	// but doesn't update the stationary dock's dir
	var/shuttle_true_height = ship_shuttle.height
	var/shuttle_true_width = ship_shuttle.width
	if(EWCOMPONENT(ship_shuttle.port_direction))
		shuttle_true_height = ship_shuttle.width
		shuttle_true_width = ship_shuttle.height
	var/ship_facing_dir = angle2dir(dir2angle(shuttle_true_height > shuttle_true_width ? EAST : NORTH) + dir2angle(ship_shuttle.port_direction) + 180)
	ship_dock.dir = ship_facing_dir

	// Set cargo_dock dimensions to match the cargo shuttle
	cargo_dock.width = shuttle_port.width
	cargo_dock.height = shuttle_port.height

	// Position the cargo dock adjacent to the player's ship (without moving the ship)
	position_cargo_dock_next_to_ship(ship_dock, cargo_dock, ship_shuttle, shuttle_port)

	// Only dock the cargo shuttle - don't touch the player's ship
	var/cargo_result = shuttle_port.initiate_docking(cargo_dock, force = TRUE)

	if(cargo_result != DOCKING_SUCCESS)
		state = CARGO_SHUTTLE_AWAY
		linked_console?.say("Error: Shuttle docking failed.")
		cleanup_shuttle()
		return FALSE

	state = CARGO_SHUTTLE_DOCKED
	linked_console?.say("Cargo shuttle has arrived.")

	// Now that docking succeeded, process purchases and spawn items
	if(linked_console)
		linked_console.buy()
		linked_console.print_requisition_form()

	// Play docking sound to all mobs on the ship
	if(target_ship?.shuttle)
		for(var/area/ship_area as anything in target_ship.shuttle.shuttle_areas)
			for(var/mob/M in ship_area)
				M.playsound_local(M, 'voidcrew/sound/cargodock1.ogg', 50, FALSE)
		addtimer(CALLBACK(src, PROC_REF(play_dock_sound_2)), 1 SECONDS)

	// If a loan was accepted, spawn the loan items
	if(loan_accepted && pending_loan)
		var/list/cargo_turfs = get_cargo_bay_turfs()
		log_shuttle("LOAN DEBUG: Spawning loan items. shuttle_port=[shuttle_port ? "valid" : "null"], turfs_found=[length(cargo_turfs)], loan_type=[pending_loan.type]")
		if(!length(cargo_turfs))
			log_shuttle("LOAN DEBUG: No cargo turfs found! shuttle_areas=[shuttle_port?.shuttle_areas ? length(shuttle_port.shuttle_areas) : "null"]")
		pending_loan.spawn_items(src)
		target_ship?.ship_announce(pending_loan.shuttle_transit_text, pending_loan.sender)
		QDEL_NULL(pending_loan)
		loan_accepted = FALSE

	return TRUE

/**
 * Sends the cargo shuttle away
 */
/datum/voidcrew_cargo_shuttle/proc/send_shuttle()
	if(state != CARGO_SHUTTLE_DOCKED)
		return FALSE

	// Check for living mobs on the shuttle
	if(has_living_mobs())
		return FALSE

	state = CARGO_SHUTTLE_DEPARTING
	warmup_started = world.time
	warmup_timer = addtimer(CALLBACK(src, PROC_REF(complete_departure)), CARGO_SHUTTLE_DEPARTURE_WARMUP, TIMER_STOPPABLE)
	return TRUE

/**
 * Checks if there are any living mobs on the cargo shuttle
 */
/datum/voidcrew_cargo_shuttle/proc/has_living_mobs()
	if(!shuttle_port)
		return FALSE

	for(var/area/shuttle_area as anything in shuttle_port.shuttle_areas)
		for(var/turf/T in shuttle_area)
			for(var/mob/living/L in T)
				if(L.stat != DEAD)
					return TRUE
	return FALSE

/**
 * Timer callback - processes cargo and cleans up shuttle
 */
/datum/voidcrew_cargo_shuttle/proc/complete_departure()
	warmup_timer = null
	warmup_started = null

	if(state != CARGO_SHUTTLE_DEPARTING)
		return FALSE

	// Release the reserve dock first
	if(docked_at && cargo_dock_index)
		if(cargo_dock_index == 1)
			docked_at.first_dock_taken = FALSE
		else if(cargo_dock_index == 2)
			docked_at.second_dock_taken = FALSE
		cargo_dock_index = 0

	// Export cargo while shuttle is still docked (sell() uses shuttle_areas, doesn't need transit)
	linked_console?.sell()

	// Now fully destroy the shuttle (don't move to transit first - causes baseturfs issues)
	destroy_shuttle()

	state = CARGO_SHUTTLE_AWAY
	target_ship = null
	docked_at = null
	linked_console?.say("Cargo shuttle has departed.")
	return TRUE

/**
 * Completely destroys the shuttle - deletes all turfs and objects
 */
/datum/voidcrew_cargo_shuttle/proc/destroy_shuttle()
	// Clean up transit dock and its reservation FIRST
	if(transit_dock && !QDELETED(transit_dock))
		// Release the turf reservation if it exists
		if(transit_dock.reserved_area)
			qdel(transit_dock.reserved_area)
			transit_dock.reserved_area = null
		qdel(transit_dock)
	transit_dock = null

	if(!shuttle_port || QDELETED(shuttle_port))
		shuttle_port = null
		return

	// Clear SSshuttle references
	if(SSshuttle.supply == shuttle_port)
		SSshuttle.supply = null

	// Unlink from transit dock
	shuttle_port.assigned_transit = null

	// Get all turfs in shuttle areas before we delete the port
	var/list/shuttle_turfs = list()
	for(var/area/shuttle_area as anything in shuttle_port.shuttle_areas)
		for(var/turf/T in shuttle_area)
			shuttle_turfs += T

	// Delete all movable objects on shuttle turfs (except the docking port itself)
	for(var/turf/T as anything in shuttle_turfs)
		for(var/atom/movable/AM in T)
			if(AM == shuttle_port)
				continue
			if(isliving(AM))
				continue // Don't delete mobs
			qdel(AM)

	// Convert all shuttle turfs to space and move them out of shuttle area
	var/area/space/space_area = locate(/area/space) in GLOB.areas
	if(!space_area)
		space_area = new /area/space
	for(var/turf/T as anything in shuttle_turfs)
		T.ChangeTurf(/turf/open/space, flags = CHANGETURF_DEFER_CHANGE)
		space_area.contents += T

	// Delete the shuttle port (force = TRUE to actually delete it)
	qdel(shuttle_port, force = TRUE)
	shuttle_port = null

/**
 * Positions the cargo dock adjacent to the player's ship dock
 * This finds where the ship already is and places the cargo dock next to it,
 * without moving the player's ship at all.
 *
 * * ship_dock - The stationary dock the player's ship is using
 * * cargo_dock - The stationary dock for the cargo shuttle
 * * ship_shuttle - The player's ship mobile dock (for reference)
 * * cargo_shuttle - The cargo shuttle mobile dock
 */
/**
 * Plays the second docking sound after a delay
 */
/datum/voidcrew_cargo_shuttle/proc/play_dock_sound_2()
	if(!target_ship?.shuttle)
		return
	for(var/area/ship_area as anything in target_ship.shuttle.shuttle_areas)
		for(var/mob/M in ship_area)
			M.playsound_local(M, 'voidcrew/sound/cargodock2.ogg', 50, FALSE)

/datum/voidcrew_cargo_shuttle/proc/position_cargo_dock_next_to_ship(obj/docking_port/stationary/ship_dock, obj/docking_port/stationary/cargo_dock, obj/docking_port/mobile/ship_shuttle, obj/docking_port/mobile/cargo_shuttle_port)
	// For exit-to-exit docking (airlocks facing each other):
	// - ship_dock.dir points INTO the ship
	// - cargo_dock.dir must point INTO the cargo shuttle (OPPOSITE direction)
	// This way both shuttle bodies extend AWAY from the docking point

	// Cargo dock faces opposite to ship dock (exit-to-exit)
	cargo_dock.dir = REVERSE_DIR(ship_dock.dir)

	// Set up cargo dock offsets to match the cargo shuttle
	cargo_dock.dwidth = cargo_shuttle_port.dwidth
	cargo_dock.dheight = cargo_shuttle_port.dheight

	// The docks should be placed 1 tile apart in the direction the ship faces out
	// ship_dock.dir points INTO ship, so REVERSE_DIR is where ship's exit is
	var/offset_dir = REVERSE_DIR(ship_dock.dir)

	var/cargo_dock_x = ship_dock.x
	var/cargo_dock_y = ship_dock.y

	switch(offset_dir)
		if(NORTH)
			cargo_dock_y = ship_dock.y + 1
		if(SOUTH)
			cargo_dock_y = ship_dock.y - 1
		if(EAST)
			cargo_dock_x = ship_dock.x + 1
		if(WEST)
			cargo_dock_x = ship_dock.x - 1

	var/turf/new_loc = locate(cargo_dock_x, cargo_dock_y, ship_dock.z)
	if(new_loc)
		cargo_dock.forceMove(new_loc)
