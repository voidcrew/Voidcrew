/obj/structure/overmap/ship
	/// Flagged as a pirate hull: kept out of green, refused at green and yellow outposts and by freight lines
	var/pirate_crew = FALSE
	/// The flag came from a pirate commanding this hull, not from the hull itself: it lapses when no pirate commands it
	var/pirate_flag_followed = FALSE

/// Whether a pirate_crew hull rides in this carrier's contents
/proc/background_rider_flagged(obj/structure/overmap/ship/carrier)
	if(!carrier)
		return FALSE
	for(var/obj/structure/overmap/ship/rider in carrier.contents)
		if(rider.pirate_crew)
			return TRUE
	return FALSE

/**
 * Flags a hull as a pirate hull and counts what it takes toward its pirates' goal (pirate_goals.dm).
 * Safe to call again on a flagged hull. NPC hulls are never flagged. `followed` marks a flag that
 * only lasts while a pirate commands the hull; a hull flagged at spawn keeps its flag.
 */
/datum/background/pirate/proc/pirate_flag_hull(obj/structure/overmap/ship/hull, followed = FALSE)
	if(QDELETED(hull) || istype(hull, /obj/structure/overmap/ship/npc))
		return
	if(!hull.pirate_crew)
		hull.pirate_flag_followed = followed
	hull.pirate_crew = TRUE
	RegisterSignal(hull, COMSIG_BACKGROUND_CREDITS_TAKEN, PROC_REF(on_credits_taken), override = TRUE)

/// Starts the flag-follow loop unless it is already running
/datum/background/pirate/proc/ensure_flag_timer()
	if(flag_timer)
		return
	flag_timer = addtimer(CALLBACK(src, PROC_REF(flag_follow_tick)), BACKGROUND_PIRATE_FLAG_INTERVAL, TIMER_LOOP | TIMER_STOPPABLE | TIMER_DELETE_ME)

/**
 * The flag follows the pirate: every hull a playing pirate captains, holds an
 * explicit claim on or commands as acting captain is flagged. Signing on as ordinary crew
 * flags nothing. A hull that only carried the flag for its pirate commander loses it once no
 * pirate commands it, so a pirate passing through as acting captain cannot brand a crew for
 * the round. The loop stops itself while nobody plays a pirate.
 */
/datum/background/pirate/proc/flag_follow_tick()
	for(var/obj/structure/overmap/ship/hull as anything in SSovermap.simulated_ships)
		if(QDELETED(hull) || !hull.pirate_flag_followed || !hull.pirate_crew)
			continue
		if(!commanded_by_pirate(hull))
			hull.pirate_crew = FALSE
			hull.pirate_flag_followed = FALSE
	var/list/minds = background_active_minds(BACKGROUND_PIRATE)
	if(!length(minds))
		if(flag_timer)
			deltimer(flag_timer)
			flag_timer = null
		return
	for(var/datum/mind/mind in minds)
		flag_commanded_hulls(mind)

/// Flags every player hull this mind commands
/datum/background/pirate/proc/flag_commanded_hulls(datum/mind/mind)
	for(var/datum/team/voidcrew/team in mind?.ship_teams)
		var/obj/structure/overmap/ship/hull = team.ship
		if(QDELETED(hull) || istype(hull, /obj/structure/overmap/ship/npc))
			continue
		if(!hull.is_ship_captain_mind(mind))
			continue
		pirate_flag_hull(hull, followed = TRUE)

/// Whether a playing pirate commands this hull right now
/datum/background/pirate/proc/commanded_by_pirate(obj/structure/overmap/ship/hull)
	for(var/datum/mind/member in hull?.ship_team?.members)
		var/datum/background_state/state = member.background_state
		if(!state || state.ended || state.key != BACKGROUND_PIRATE)
			continue
		if(hull.is_ship_captain_mind(member))
			return TRUE
	return FALSE

/**
 * Flags a hull at once if a pirate commands it, so a hull claimed a moment ago is turned away at
 * a berth or the cordon without waiting for the next tick. TRUE when the hull is flagged.
 */
/proc/background_pirate_flag_check(obj/structure/overmap/ship/hull)
	if(!hull || istype(hull, /obj/structure/overmap/ship/npc))
		return FALSE
	if(hull.pirate_crew)
		return TRUE
	var/datum/background/pirate/pirates = background_by_key(BACKGROUND_PIRATE)
	if(!pirates?.commanded_by_pirate(hull))
		return FALSE
	pirates.pirate_flag_hull(hull, followed = TRUE)
	return TRUE
