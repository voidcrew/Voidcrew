/// Backgrounds: owned by P4.

/datum/background/pirate
	parent_type = /datum/background/hull_start
	key = BACKGROUND_PIRATE
	name = "Pirate"
	hull_type = /datum/map_template/shuttle/voidcrew/corsair
	/// The loop that hands the pirate flag to every hull a pirate commands (pirate_flags.dm)
	var/flag_timer

/// Yellow or red, away from player hulls. Never green: the hull could not get back out to its trade.
/datum/background/pirate/pick_spawn_turf()
	var/turf/spot = SSnpc_ships?.get_spawn_turf(list(ZONE_RED, ZONE_YELLOW))
	if(spot)
		return spot
	for(var/attempt in 1 to 20)
		var/turf/candidate = SSovermap.get_unused_overmap_square()
		if(candidate && !SSovermap.is_turf_in_green_zone(candidate))
			return candidate
	return null

/datum/background/pirate/on_hull_spawned(obj/structure/overmap/ship/hull)
	pirate_flag_hull(hull)
	ensure_flag_timer()

/datum/background/pirate/on_started(datum/mind/mind, datum/background_state/state)
	if(!state)
		return
	state.crime = "Piracy"
	state.crime_tier = 2
	state.goal = "siphon"
	state.goal_target = BACKGROUND_PIRATE_GOAL
	if(mind)
		background_mint_warrant(mind, BACKGROUND_PIRATE)
	ensure_flag_timer()
	state.refresh_memory()

/datum/background/pirate/goal_line(datum/background_state/state)
	return "Take [pirate_credits_text(BACKGROUND_PIRATE_GOAL)] cr off other ships. [pirate_credits_text(state?.progress)] cr taken so far."

/datum/background/pirate/outcome_line(datum/background_state/state)
	if(state?.outcome == BACKGROUND_OUTCOME_DONE)
		return "Took their [pirate_credits_text(BACKGROUND_PIRATE_GOAL)]."
	return "Took [pirate_credits_text(state?.progress)] cr of [pirate_credits_text(BACKGROUND_PIRATE_GOAL)]."

/datum/background/pirate/judge(datum/background_state/state)
	if(!state || state.outcome != BACKGROUND_OUTCOME_ONGOING)
		return
	if(state.progress >= BACKGROUND_PIRATE_GOAL)
		state.complete(outcome_line(state))
	else
		state.fail(outcome_line(state))

/// A whole number of credits with thousands separators: 25000 -> "25,000"
/proc/pirate_credits_text(amount)
	amount = round(amount || 0)
	var/digits = num2text(abs(amount), 20)
	var/grouped = ""
	while(length(digits) > 3)
		grouped = ",[copytext(digits, length(digits) - 2)][grouped]"
		digits = copytext(digits, 1, length(digits) - 2)
	return "[amount < 0 ? "-" : ""][digits][grouped]"
