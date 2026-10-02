///
/// Ship-to-ship docking.
///
/// Hulls berthing against hulls: the consensual ship_act() handshake, direct
/// exit-to-exit docking via a shared empty-space encounter, reserve-port fallback
/// and the dock placement geometry that keeps two hulls from overwriting each
/// other.

/obj/structure/overmap/ship
	var/pending_dock = FALSE
	var/pending_dock_timer
	/// The ship we sent a docking request to (if any)
	var/obj/structure/overmap/ship/pending_dock_target

/// Returns TRUE if this ship is involved in ship-to-ship docking (either we docked to them, or they docked to us)
/// Only counts ships that have COMPLETED docking (state == IDLE), not ships still in transit
/obj/structure/overmap/ship/proc/is_in_ship_to_ship_dock()
	// We must be fully docked (IDLE state) to be in a ship-to-ship dock
	if(state != OVERMAP_SHIP_IDLE)
		return FALSE
	// Check if we are docked to another ship directly
	if(istype(docked, /obj/structure/overmap/ship))
		return TRUE
	// Check if any ship is docked to us directly (and has completed docking)
	for(var/obj/structure/overmap/ship/other_ship in SSovermap.simulated_ships)
		if(other_ship == src)
			continue
		if(other_ship.docked == src && other_ship.state == OVERMAP_SHIP_IDLE)
			return TRUE
	// Check if we're docked to the same empty space as another ship (consensual helm dock)
	// Only count other ships that have completed docking
	if(istype(docked, /obj/structure/overmap/planet/empty))
		for(var/obj/structure/overmap/ship/other_ship in SSovermap.simulated_ships)
			if(other_ship == src)
				continue
			if(other_ship.docked == docked && other_ship.state == OVERMAP_SHIP_IDLE)
				return TRUE
	return FALSE

/**
  * Docks to an empty dynamic encounter. Used for intership interaction, structural modifications, and such
  * * user - The user that initiated the action
  */
/obj/structure/overmap/ship/proc/dock_in_empty_space(mob/user)
	// Cannot dock while interdicted
	if(is_interdicted)
		return "Cannot dock while interdicted!"

	var/obj/structure/overmap/planet/empty/E
	E = locate() in get_turf(src)
	if(!E)
		E = new(get_turf(src))
	if(E)
		// Load the level first to ensure docking ports exist
		if(!E.loaded && !E.loading)
			E.load_level()

		// Wait for level to load
		if(E.loading)
			return "Empty space is loading, try again in a moment."

		// Restore any stale dock geometry left over from a previous ship-to-ship
		// or cargo-shuttle pairing before computing our placement
		E.reset_free_reserve_docks()

		// Assign port destinations and immediately dock
		var/obj/docking_port/stationary/dock_to_use = null
		if(E.reserve_dock && !E.first_dock_taken && !E.reserve_dock.get_docked())
			dock_to_use = E.reserve_dock
			E.first_dock_taken = TRUE
			dock_index = 1
		else if(E.reserve_dock_secondary && !E.second_dock_taken && !E.reserve_dock_secondary.get_docked())
			dock_to_use = E.reserve_dock_secondary
			E.second_dock_taken = TRUE
			dock_index = 2
		else
			return "No available docking ports in empty space."

		// Set port destinations for helm UI
		shuttle.port_destinations = dock_to_use

		// Someone is still parked in here - typically an NPC hulk the crew boarded,
		// undocked from, and came straight back to. Once a ship docks it leaves the
		// overmap tile for the placeholder's contents, so it stops being a contact and
		// ship_act()'s exit-to-exit handshake is unreachable on the way back in; this
		// button is all the crew has. Berth them against that ship rather than dropping
		// them at the encounter's default port, a map away from the airlock they were
		// just using.
		var/obj/docking_port/stationary/occupied_dock = E.get_occupied_reserve_dock(dock_to_use)
		if(occupied_dock && position_dock_across_from(E, occupied_dock, dock_to_use, shuttle))
			return dock(E, dock_to_use)

		// Adjust dock to shuttle size and immediately start docking
		E.adjust_dock_to_shuttle(dock_to_use, shuttle)
		return dock(E, dock_to_use)

/**
  * Clears pending dock request and timer
  */
/obj/structure/overmap/ship/proc/clear_pending_dock()
	pending_dock = FALSE
	pending_dock_target = null
	if(pending_dock_timer)
		deltimer(pending_dock_timer)
		pending_dock_timer = null

/**
  * Docks two ships directly exit-to-exit. Creates a shared empty space zone
  * and positions the docking ports so the ships' exits face each other.
  * * other_ship - The other ship to dock with
  * * user - The user who initiated the docking
  * * instant - If TRUE, bypasses the dock warmup (used for force dock)
  * Returns an error string on failure, null on success.
  */
/obj/structure/overmap/ship/proc/dock_ships_directly(obj/structure/overmap/ship/other_ship, mob/user, instant = FALSE)
	if(!other_ship || !shuttle || !other_ship.shuttle)
		return "Invalid ships for docking."

	// dock() refuses interdicted ships AFTER we've claimed the dock flags below -
	// check up front so an abort can't leave the encounter's docks marked taken forever
	if(!instant && (is_interdicted || other_ship.is_interdicted))
		return "Cannot dock while interdicted!"

	// Create or find shared empty space
	var/obj/structure/overmap/planet/empty/E = locate() in get_turf(src)
	if(!E)
		E = new(get_turf(src))

	// Load the level first to ensure docking ports exist
	if(!E.loaded && !E.loading)
		E.load_level()

	// Wait for level to load
	if(E.loading)
		return "Empty space is loading, try again in a moment."

	if(!E.reserve_dock || !E.reserve_dock_secondary)
		return "No docking ports available in empty space."

	// Check dock availability
	if(E.first_dock_taken || E.reserve_dock.get_docked())
		return "Primary docking port already in use."
	if(E.second_dock_taken || E.reserve_dock_secondary.get_docked())
		return "Secondary docking port already in use."

	// Mark both docks as taken
	E.first_dock_taken = TRUE
	E.second_dock_taken = TRUE
	dock_index = 1
	other_ship.dock_index = 2

	// Position docks for exit-to-exit docking. A refusal here means one of the two hulls
	// stands out past its own docking port and would be driven through the other; roll the
	// dock claims back so the caller's fallback to separate reserve berths can take them.
	if(!position_docks_for_direct_docking(E, E.reserve_dock, E.reserve_dock_secondary, shuttle, other_ship.shuttle))
		E.first_dock_taken = FALSE
		E.second_dock_taken = FALSE
		dock_index = 0
		other_ship.dock_index = 0
		return "One of the ships has hull built out past its docking port."

	// Set port destinations for helm UI
	shuttle.port_destinations = E.reserve_dock
	other_ship.shuttle.port_destinations = E.reserve_dock_secondary

	// Dock both ships
	dock(E, E.reserve_dock, instant)
	other_ship.dock(E, E.reserve_dock_secondary, instant)

	return null

/**
  * Fallback docking: Docks two ships to the same empty space's reserve ports separately.
  * Used when direct exit-to-exit docking fails. Ships will be in the same location
  * but their airlocks won't be touching.
  * * other_ship - The other ship to dock with
  * * user - The user who initiated the docking (optional)
  * * instant - If TRUE, bypasses the dock warmup (used for force dock)
  * Returns an error string on failure, null on success.
  */
/obj/structure/overmap/ship/proc/dock_ships_to_reserve_ports(obj/structure/overmap/ship/other_ship, mob/user, instant = FALSE)
	if(!other_ship || !shuttle || !other_ship.shuttle)
		return "Invalid ships for docking."

	// dock() refuses interdicted ships AFTER we've claimed the dock flags below -
	// check up front so an abort can't leave the encounter's docks marked taken forever
	if(!instant && (is_interdicted || other_ship.is_interdicted))
		return "Cannot dock while interdicted!"

	// Create or find shared empty space
	var/obj/structure/overmap/planet/empty/E = locate() in get_turf(src)
	if(!E)
		E = new(get_turf(src))

	// Load the level first to ensure docking ports exist
	if(!E.loaded && !E.loading)
		E.load_level()

	// Wait for level to load
	if(E.loading)
		return "Empty space is loading, try again in a moment."

	if(!E.reserve_dock || !E.reserve_dock_secondary)
		return "No docking ports available in empty space."

	// Restore any stale dock geometry left over from a previous ship-to-ship
	// or cargo-shuttle pairing before computing placement
	E.reset_free_reserve_docks()

	// Check if at least one dock is available for each ship
	var/obj/docking_port/stationary/dock_for_us
	var/obj/docking_port/stationary/dock_for_them

	if(!E.first_dock_taken && !E.reserve_dock.get_docked())
		dock_for_us = E.reserve_dock
		E.first_dock_taken = TRUE
		dock_index = 1
	else if(!E.second_dock_taken && !E.reserve_dock_secondary.get_docked())
		dock_for_us = E.reserve_dock_secondary
		E.second_dock_taken = TRUE
		dock_index = 2

	if(!dock_for_us)
		return "No available docking ports for our ship."

	// Find dock for the other ship
	if(!E.first_dock_taken && !E.reserve_dock.get_docked())
		dock_for_them = E.reserve_dock
		E.first_dock_taken = TRUE
		other_ship.dock_index = 1
	else if(!E.second_dock_taken && !E.reserve_dock_secondary.get_docked())
		dock_for_them = E.reserve_dock_secondary
		E.second_dock_taken = TRUE
		other_ship.dock_index = 2

	if(!dock_for_them)
		// Rollback our dock allocation
		if(dock_index == 1)
			E.first_dock_taken = FALSE
		else
			E.second_dock_taken = FALSE
		dock_index = 0
		return "No available docking ports for target ship."

	// Adjust docks to fit each shuttle
	E.adjust_dock_to_shuttle(dock_for_us, shuttle)
	E.adjust_dock_to_shuttle(dock_for_them, other_ship.shuttle)

	// Set port destinations for helm UI
	shuttle.port_destinations = dock_for_us
	other_ship.shuttle.port_destinations = dock_for_them

	// Dock both ships
	dock(E, dock_for_us, instant)
	other_ship.dock(E, dock_for_them, instant)

	return null

/**
  * TRUE if `shuttle` can take an exit-to-exit berth without ramming its neighbour.
  *
  * Null shuttles pass: an empty anchor dock is not an obstruction. `context` is logged, not
  * shown to players - the crew-facing explanation belongs on the console that can fix it.
  */
/proc/ship_port_clear_to_berth(obj/docking_port/mobile/shuttle, context)
	if(!shuttle)
		return TRUE
	var/list/overhang = hull_port_overhang(shuttle, null)
	if(overhang[1] <= 0)
		return TRUE
	log_shuttle("[shuttle] refused an exit-to-exit berth ([context]): [overhang[1]] tiles of hull \
		stand out past its docking port. Move the port onto the outermost hull door.")
	return FALSE

/**
  * Positions two stationary docks so that two shuttles will dock exit-to-exit (airlocks touching).
  * * empty_planet - The empty space planet (for calling adjust_dock_to_shuttle)
  * * dock_a - First stationary dock (for shuttle_a)
  * * dock_b - Second stationary dock (for shuttle_b)
  * * shuttle_a - First shuttle's mobile dock
  * * shuttle_b - Second shuttle's mobile dock
  */
/obj/structure/overmap/ship/proc/position_docks_for_direct_docking(obj/structure/overmap/planet/empty/empty_planet, obj/docking_port/stationary/dock_a, obj/docking_port/stationary/dock_b, obj/docking_port/mobile/shuttle_a, obj/docking_port/mobile/shuttle_b)
	// For ship-to-ship docking, we need both shuttles to fit in the same area
	// First, move dock_a to the center of the z-level with plenty of clearance
	var/datum/map_zone/mapzone = empty_planet.mapzone
	if(!mapzone || !length(mapzone.z_levels))
		log_shuttle("WARNING: No mapzone for ship-to-ship docking")
		return
	var/datum/space_level/zlevel = mapzone.z_levels[1]

	// Neither hull may stand out past its own docking port, or it lands inside the other ship.
	// Checked before anything is moved so a refusal leaves both docks where the caller found
	// them and it can fall back to separate reserve berths.
	if(!ship_port_clear_to_berth(shuttle_a, "exit-to-exit with [shuttle_b]"))
		return FALSE
	if(!ship_port_clear_to_berth(shuttle_b, "exit-to-exit with [shuttle_a]"))
		return FALSE

	// Centre of the ENCOUNTER'S OWN FOOTPRINT, not of the z-level. The old world.maxx/2
	// pick predates bounds tracking entirely; on a packed level it lands squarely in the
	// gutter between slots - indestructible cordon, so both hulls would be sealed in - or
	// on a neighbouring encounter's ground. Two maximum-size hulls berthed exit-to-exit
	// span ~112 turfs, which fits inside a MAP_SLOT_SIDE (123) square.
	var/datum/map_footprint/footprint = empty_planet.footprint
	var/turf/center_turf = footprint?.get_center_turf()
	if(!center_turf)
		center_turf = locate(round((zlevel.low_x + zlevel.high_x) / 2), round((zlevel.low_y + zlevel.high_y) / 2), zlevel.z_value)
	if(!center_turf)
		log_shuttle("WARNING: No centre turf for ship-to-ship docking on z[zlevel.z_value]")
		return FALSE

	// Position dock_a at center, let adjust_dock_to_shuttle handle orientation
	dock_a.forceMove(center_turf)
	empty_planet.adjust_dock_to_shuttle(dock_a, shuttle_a)

	// Put dock_b right across from it so the two shuttles end up exit-to-exit
	return position_dock_across_from(empty_planet, dock_a, dock_b, shuttle_b)

/**
  * Places a free stationary dock exit-to-exit against another dock, so a shuttle sent
  * to it ends up with its airlock touching whatever is parked on the anchor.
  *
  * anchor_dock.dir points INTO the ship parked there, so that ship's exit - and the
  * berth we want - is one tile away in REVERSE_DIR. Facing the placed dock the same
  * way puts the two shuttle bodies back to back with their exits meeting in between.
  *
  * Used both when pairing two ships up front and when a ship arrives into an
  * encounter someone else is already sitting in.
  *
  * * empty_planet - The encounter, for its z-level bounds. Optional; skips the fit check.
  * * anchor_dock - The dock to berth against. Never moved: something is parked on it.
  * * dock_to_place - The free dock to reposition.
  * * shuttle_to_place - The mobile port that will dock at dock_to_place.
  *
  * Returns TRUE if the dock was placed, FALSE (leaving it untouched) if the berth
  * would fall outside the encounter.
  */
/obj/structure/overmap/ship/proc/position_dock_across_from(obj/structure/overmap/planet/empty/empty_planet, obj/docking_port/stationary/anchor_dock, obj/docking_port/stationary/dock_to_place, obj/docking_port/mobile/shuttle_to_place)
	if(!anchor_dock || !dock_to_place || !shuttle_to_place)
		return FALSE

	// Exit-to-exit only leaves one tile between the two hulls, so neither ship may have
	// plating standing out past its own docking port - that plating lands inside the other
	// ship and overwrites it (hull_port_overhang() in hull_survey.dm has the full reasoning).
	// canDock() cannot see this, because the dwidth/dheight we set below are derived from the
	// mobile port's own, so its bounds test compares a number with itself.
	if(!ship_port_clear_to_berth(shuttle_to_place, "berthing beside [anchor_dock]"))
		return FALSE
	if(!ship_port_clear_to_berth(anchor_dock.get_docked(), "parked on [anchor_dock]"))
		return FALSE

	var/new_dir = REVERSE_DIR(anchor_dock.dir)
	var/new_x = anchor_dock.x
	var/new_y = anchor_dock.y
	switch(new_dir)
		if(NORTH)
			new_y = anchor_dock.y + 1
		if(SOUTH)
			new_y = anchor_dock.y - 1
		if(EAST)
			new_x = anchor_dock.x + 1
		if(WEST)
			new_x = anchor_dock.x - 1

	var/turf/new_loc = locate(new_x, new_y, anchor_dock.z)
	if(!new_loc)
		log_shuttle("WARNING: Could not position [dock_to_place] at ([new_x], [new_y], [anchor_dock.z]) for ship-to-ship docking")
		return FALSE

	// Square footprint: the dock gets rotated to face the anchor rather than sized along
	// a fixed axis, so its long side has to clear the shuttle whichever way it lands
	var/new_size = max(shuttle_to_place.width, shuttle_to_place.height)

	// return_coords() reads the port's own footprint, so these have to be in place before
	// we can ask where the berth would actually land. Snapshot them: a berth that turns
	// out not to fit leaves the dock exactly as we found it for the caller's fallback.
	var/old_width = dock_to_place.width
	var/old_height = dock_to_place.height
	var/old_dwidth = dock_to_place.dwidth
	var/old_dheight = dock_to_place.dheight

	dock_to_place.width = new_size
	dock_to_place.height = new_size
	dock_to_place.dwidth = round((new_size - shuttle_to_place.width) / 2) + shuttle_to_place.dwidth
	dock_to_place.dheight = round((new_size - shuttle_to_place.height) / 2) + shuttle_to_place.dheight

	var/datum/space_level/zlevel
	if(empty_planet?.mapzone && length(empty_planet.mapzone.z_levels))
		zlevel = empty_planet.mapzone.z_levels[1]
	// The ENCOUNTER's rectangle, not the level's. Flat encounters pack four to a z-level, and
	// the level's rect widens to the whole z as soon as a second one lands - which turns this
	// fit test from "does the berth stay on our ground" into "is it anywhere on the map", and
	// lets a berth be laid into the cordon gutter or straight onto a neighbour's encounter.
	var/datum/map_footprint/site = empty_planet?.footprint
	var/site_low_x = isnull(site?.low_x) ? zlevel?.low_x : site.low_x
	var/site_low_y = isnull(site?.low_x) ? zlevel?.low_y : site.low_y
	var/site_high_x = isnull(site?.low_x) ? zlevel?.high_x : site.high_x
	var/site_high_y = isnull(site?.low_x) ? zlevel?.high_y : site.high_y
	if(zlevel && !isnull(site_low_x))
		var/list/corners = dock_to_place.return_coords(new_x, new_y, new_dir)
		if(min(corners[1], corners[3]) < site_low_x || max(corners[1], corners[3]) > site_high_x \
			|| min(corners[2], corners[4]) < site_low_y || max(corners[2], corners[4]) > site_high_y)
			dock_to_place.width = old_width
			dock_to_place.height = old_height
			dock_to_place.dwidth = old_dwidth
			dock_to_place.dheight = old_dheight
			log_shuttle("WARNING: berth for [shuttle_to_place] beside [anchor_dock] falls outside the encounter, using the default port instead")
			return FALSE

	dock_to_place.dir = new_dir
	dock_to_place.forceMove(new_loc)
	return TRUE

/**
  * Ship-to-ship interaction. Creates shared empty space and docks both ships together.
  * * user - The user that initiated the action
  * * acting_ship - The ship that initiated the interaction
  */
/obj/structure/overmap/ship/ship_act(mob/user, obj/structure/overmap/ship/acting_ship)
	if(!acting_ship || acting_ship == src)
		return

	// Both ships must be still to interact
	if(!acting_ship.is_still() || !is_still())
		to_chat(user, "<span class='warning'>Both ships must be stationary to dock together!</span>")
		return

	// Both ships must be flying (not already docked)
	if(acting_ship.state != OVERMAP_SHIP_FLYING || state != OVERMAP_SHIP_FLYING)
		to_chat(user, "<span class='warning'>Both ships must be undocked to perform ship-to-ship docking!</span>")
		return

	// If the acting ship has an interdictor locked onto the target, force dock instead
	for(var/obj/machinery/ship_combat/interdictor/interdictor in acting_ship.linked_interdictors)
		if(interdictor.interdiction_active && interdictor.interdicted_ship_ref?.resolve() == src)
			interdictor.force_dock_target(user)
			return

	// If target ship is a disabled NPC ship, allow direct docking without mutual request.
	// An abandoned hull docks the same way and for the same reason: the handshake below
	// needs a helm with someone at it, an abandoned hull has no crew left to answer, and
	// the claim console inside (claim_abandoned_ship()) is only reachable by boarding it.
	// Without this the whole SHIP_DERELICT_DESPAWN_TIME claim window was unreachable by
	// any ordinary means - only an interdictor lock could put a boarding party aboard.
	var/obj/structure/overmap/ship/npc/npc_target = src
	var/target_disabled = istype(npc_target) && npc_target.is_disabled
	if(target_disabled || abandoned)
		// Clear any pending dock requests
		clear_pending_dock()
		acting_ship.clear_pending_dock()

		// The derelict cannot answer, so tell the boarders what is happening instead.
		// Not for the disabled-NPC case, which has always been silent here.
		if(!target_disabled)
			acting_ship.ship_notify("[name] is not responding - registered as an abandoned derelict. Docking directly.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

		// Dock directly - no mutual request needed for disabled ships
		var/result = dock_ships_directly(acting_ship, user)
		if(result)
			// Direct docking failed, fall back to reserve port docking
			var/fallback_result = dock_ships_to_reserve_ports(acting_ship, user)
			if(fallback_result)
				to_chat(user, "<span class='warning'>Docking failed: [fallback_result]</span>")
		return

	// Check if acting_ship is clicking on a ship it already requested to dock with
	// If so, cancel the request
	if(acting_ship.pending_dock && acting_ship.pending_dock_target == src)
		acting_ship.clear_pending_dock()
		acting_ship.ship_notify("Docking request to [name] has been cancelled.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify2.ogg', 50)
		ship_notify("[acting_ship.name] has cancelled their docking request.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify2.ogg', 50)
		return

	// Check if the target (src) already sent a request to acting_ship
	// If src.pending_dock is TRUE and target is acting_ship, complete the handshake
	if(pending_dock && pending_dock_target == acting_ship)
		ship_notify("Initiating docking procedures with [acting_ship.name]...", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		acting_ship.ship_notify("Initiating docking procedures with [name]...", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

		// Clear pending status and timers for both ships
		clear_pending_dock()
		acting_ship.clear_pending_dock()

		// Dock both ships directly exit-to-exit
		var/result = dock_ships_directly(acting_ship, user)
		if(result)
			// Direct docking failed, fall back to reserve port docking
			ship_notify("Direct docking failed, using reserve ports instead.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify2.ogg', 50)
			acting_ship.ship_notify("Direct docking failed, using reserve ports instead.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify2.ogg', 50)
			var/fallback_result = dock_ships_to_reserve_ports(acting_ship, user)
			if(fallback_result)
				to_chat(user, "<span class='warning'>Docking failed: [fallback_result]</span>")
				ship_notify("Docking failed: [fallback_result]", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
				acting_ship.ship_notify("Docking failed: [fallback_result]", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
	else
		// If acting_ship already has a pending request to a DIFFERENT ship, cancel it first
		if(acting_ship.pending_dock && acting_ship.pending_dock_target != src)
			var/obj/structure/overmap/ship/old_target = acting_ship.pending_dock_target
			acting_ship.clear_pending_dock()
			acting_ship.ship_notify("Docking request to [old_target?.name] has been cancelled.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify2.ogg', 50)
			if(old_target)
				old_target.ship_notify("[acting_ship.name] has cancelled their docking request.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify2.ogg', 50)

		// New request - acting_ship wants to dock with src (target)
		log_admin("[key_name(user)] requested ship-to-ship docking from [acting_ship.name] to [name]")
		// Announce to the acting ship (the one making the request)
		acting_ship.ship_notify("Your ship has requested to dock with [name]. They must also request docking to proceed.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		// Announce to the target ship (src) that they have an incoming request
		ship_notify("[acting_ship.name] has requested to dock with your ship. Use your helm console to accept.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		// Set pending on acting_ship - this marks that acting_ship is waiting for src to respond
		acting_ship.pending_dock = TRUE
		acting_ship.pending_dock_target = src

		// Set a 30 second timer to clear the pending dock request on acting_ship
		acting_ship.pending_dock_timer = addtimer(CALLBACK(acting_ship, PROC_REF(clear_pending_dock)), 30 SECONDS, TIMER_STOPPABLE)
		acting_ship.ship_notify("Docking request will expire in 30 seconds.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify2.ogg', 50)
