/// Backgrounds: owned by P4.

// The green cordon (MP-5): a pirate hull is turned back at the edge of green, on the step that
// would cross (start_zone_transition(), reached from tick_move() and manual burns). No patrol,
// no waiver. Hulls already inside green are left alone; they cannot dock at Halcyon.

/obj/structure/overmap/ship
	/// Between two cordon warnings to this hull
	COOLDOWN_DECLARE(background_cordon_cooldown)

/// TRUE when this crossing into target_zone is refused
/obj/structure/overmap/ship/proc/background_zone_refusal(datum/overmap_zone/target_zone)
	if(target_zone?.zone_type != ZONE_GREEN)
		return FALSE
	if(background_pirate_flag_check(src))
		background_turn_back()
		return TRUE
	// MP-6: a flagged rider that force-docked onto us is cast off and we go through;
	// one we took aboard willingly keeps us out
	var/carrying_flagged = FALSE
	for(var/obj/structure/overmap/ship/rider in contents)
		if(!rider.pirate_crew)
			continue
		if(COOLDOWN_FINISHED(src, interdiction_undock_lockout))
			carrying_flagged = TRUE
			continue
		rider.undock()
		rider.ship_notify("Docking clamps released at the cordon.", "SECTOR PATROL", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
		ship_notify("Docking clamps released at the cordon.", "SECTOR PATROL", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
	if(!carrying_flagged)
		return FALSE
	background_turn_back()
	return TRUE

/// Stops the hull at the cordon and says so, at most once a cooldown
/obj/structure/overmap/ship/proc/background_turn_back()
	// A course into green would only steer back into the line on its next poll
	if(autopilot_engaged)
		disengage_autopilot(null, FALSE)
	full_stop()
	if(!COOLDOWN_FINISHED(src, background_cordon_cooldown))
		return
	COOLDOWN_START(src, background_cordon_cooldown, BACKGROUND_ZONE_REFUSAL_COOLDOWN)
	ship_notify("Sector patrol cordon. Transponder flagged. Turn back.", "SECTOR PATROL", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert2.ogg', 25)
