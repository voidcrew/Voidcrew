/**
 * Moderation timeline: physical boarding/departure, actual zone crossings, and
 * location context for attack logs. These are observations, not PvP rulings:
 * log_combat also records harmless interactions, so it cannot establish hostility.
 */

/proc/overmap_zone_log_name(zone_type)
	switch(zone_type)
		if(ZONE_GREEN)
			return "GREEN ([ZONE_NAME_GREEN])"
		if(ZONE_YELLOW)
			return "YELLOW ([ZONE_NAME_YELLOW])"
		if(ZONE_RED)
			return "RED ([ZONE_NAME_RED])"
	return "UNKNOWN"

/// Resolve the physical hull, including upper decks and ships docked to carriers.
/proc/zone_log_ship_for_atom(atom/source)
	var/turf/location = get_turf(source)
	var/area/shuttle/voidcrew/location_area = get_area(location)
	var/obj/structure/overmap/ship/ship
	if(istype(location_area))
		ship = location_area.shuttle_port?.current_ship
	if(!ship)
		ship = get_voidcrew_ship_for_turf(location)
	if(!ship)
		return null
	// A carrier temporarily owns its riders' areas as well. Prefer the rider's hull.
	var/found_rider = TRUE
	while(found_rider)
		found_rider = FALSE
		for(var/obj/structure/overmap/ship/rider in ship.contents)
			if(!(location_area in rider.shuttle?.shuttle_areas))
				continue
			ship = rider
			found_rider = TRUE
			break
	return ship

/obj/structure/overmap/ship/proc/zone_log_identity()
	return "[name] (ship [REF(src)], shuttle [shuttle?.shuttle_id || "none"])"

/// Always reads the actual tile, including a carrier's tile during a countdown.
/proc/overmap_zone_log_context(atom/source)
	var/obj/structure/overmap/ship/ship = zone_log_ship_for_atom(source)
	if(ship)
		var/zone_type = SSovermap_zones?.get_zone_type(get_turf(ship))
		return "ship=[ship.zone_log_identity()]; zone=[overmap_zone_log_name(zone_type)]"
	var/zone_type = SSovermap_zones?.get_zone_type_anywhere(get_turf(source))
	return "off ship; zone=[overmap_zone_log_name(zone_type)]"

/// Called by the token's Moved(), after a real move, never by the countdown.
/obj/structure/overmap/ship/proc/log_zone_crossing(old_zone_type, new_zone_type)
	if(old_zone_type == new_zone_type || !SSovermap_zones?.zones_active)
		return
	var/crossing = "[overmap_zone_log_name(old_zone_type)] -> [overmap_zone_log_name(new_zone_type)]"
	var/list/aboard = list()
	// Physical occupants, not the ship team: includes visitors, bodies and containers.
	for(var/mob/living/occupant as anything in GLOB.mob_living_list)
		var/datum/component/ship_zone_logging/tracker = occupant.GetComponent(/datum/component/ship_zone_logging)
		if(!tracker || zone_log_ship_for_atom(occupant) != src)
			continue
		aboard += key_name_and_tag(occupant)
		occupant.log_message("\[ZONE\] remained aboard [zone_log_identity()] during [crossing]; [tracker.boarding_context]", LOG_ATTACK, color = "blue", log_globally = FALSE)
	var/message = "\[ZONE\] [zone_log_identity()] crossed [crossing] at [loc_name(src)]; players aboard: [length(aboard) ? jointext(aboard, "; ") : "none"]"
	log_game(message)
	log_attack(message)
	// A docked token does not get Moved() when its carrier moves.
	for(var/obj/structure/overmap/ship/rider in contents)
		rider.log_zone_crossing(old_zone_type, new_zone_type)

/// Attached when a player controls a living body, and retained across disconnects.
/datum/component/ship_zone_logging
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// Weak reference so a logged visit cannot keep a destroyed ship alive.
	var/datum/weakref/ship_ref
	/// Saved identity survives a rename or deletion between boarding and departure.
	var/ship_identity
	/// The most recent entry observation, retained through room/zone changes and logins.
	var/boarding_context

/datum/component/ship_zone_logging/Initialize()
	if(!isliving(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/ship_zone_logging/RegisterWithParent()
	var/mob/living/occupant = parent
	occupant.become_area_sensitive(type)
	RegisterSignal(occupant, COMSIG_ENTER_AREA, PROC_REF(on_area_entered))
	RegisterSignal(occupant, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	update_ship(initial_observation = TRUE)

/datum/component/ship_zone_logging/UnregisterFromParent()
	var/mob/living/occupant = parent
	occupant.lose_area_sensitivity(type)
	UnregisterSignal(occupant, list(COMSIG_ENTER_AREA, COMSIG_MOVABLE_MOVED))

/datum/component/ship_zone_logging/proc/on_area_entered(datum/source)
	SIGNAL_HANDLER
	// Area sensitivity follows players inside lockers, mechs and other containers.
	update_ship()

/datum/component/ship_zone_logging/proc/on_moved(datum/source, atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	SIGNAL_HANDLER
	if(!momentum_change)
		// Shuttle relocation uses abstract_move before the port has moved. Wait for
		// its coordinates to settle rather than recording a false departure/reboard.
		addtimer(CALLBACK(src, PROC_REF(update_ship)), 0, TIMER_UNIQUE)
		return
	update_ship()

/datum/component/ship_zone_logging/proc/update_ship(initial_observation = FALSE)
	var/mob/living/occupant = parent
	if(QDELETED(occupant))
		return
	var/obj/structure/overmap/ship/old_ship = ship_ref?.resolve()
	if(old_ship?.shuttle?.move_in_flight())
		addtimer(CALLBACK(src, PROC_REF(update_ship)), 1 SECONDS, TIMER_UNIQUE)
		return
	var/obj/structure/overmap/ship/current_ship = zone_log_ship_for_atom(occupant)
	if(current_ship == old_ship && (!ship_identity || current_ship))
		return
	if(ship_identity)
		var/old_zone = SSovermap_zones?.get_zone_type(get_turf(old_ship))
		var/message = "\[SHIP\] departed [ship_identity] in [overmap_zone_log_name(old_zone)]; [boarding_context]; destination: [overmap_zone_log_context(occupant)]"
		occupant.log_message(message, LOG_GAME)
		occupant.log_message(message, LOG_ATTACK, color = "blue")
	ship_ref = current_ship ? WEAKREF(current_ship) : null
	ship_identity = current_ship?.zone_log_identity()
	boarding_context = null
	if(!current_ship)
		return
	var/entry_verb = initial_observation ? "first observed aboard" : "boarded"
	boarding_context = "[entry_verb] at [time_stamp(format = "YYYY-MM-DD hh:mm:ss")] in [overmap_zone_log_name(SSovermap_zones?.get_zone_type(get_turf(current_ship)))]"
	var/message = "\[SHIP\] [entry_verb] [ship_identity]; [boarding_context]"
	occupant.log_message(message, LOG_GAME)
	occupant.log_message(message, LOG_ATTACK, color = "blue")
