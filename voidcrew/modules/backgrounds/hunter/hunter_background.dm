/// Backgrounds: owned by P3.

/**
 * The bounty hunter: a crew on a Marshal-class hull, with the warrant console, a brig and a goal of
 * paid captures. Every paid capture the hull makes counts (criminal records, warrants, pirate-ship
 * keys), for everyone on its roster who started as a hunter.
 */
/datum/background/bounty_hunter
	parent_type = /datum/background/hull_start
	key = BACKGROUND_BOUNTY_HUNTER
	name = "Bounty Hunter"
	hull_type = /datum/map_template/shuttle/voidcrew/marshal

/datum/background/bounty_hunter/on_started(datum/mind/mind, datum/background_state/state)
	state.goal_target = BACKGROUND_HUNTER_GOAL
	// An admin-spawned hull never went through on_hull_spawned(): listen to the hull the hunter stands on
	var/obj/structure/overmap/ship/hull = get_ship_from_atom(mind?.current)
	if(hull?.background_key() == key)
		watch_hull(hull)

/datum/background/bounty_hunter/on_hull_spawned(obj/structure/overmap/ship/hull)
	watch_hull(hull)

/// Counts this hull's paid captures toward its hunters' goal. Safe to call again on the same hull.
/datum/background/bounty_hunter/proc/watch_hull(obj/structure/overmap/ship/hull)
	if(QDELETED(hull))
		return
	// The hull's Destroy() drops the registration. Override: the spawn and every hunter's start both call this.
	RegisterSignal(hull, COMSIG_BACKGROUND_BOUNTY_PAID, PROC_REF(on_bounty_paid), override = TRUE)

/// A paid capture at the hull's pad: each hunter on its roster brings in one more
/datum/background/bounty_hunter/proc/on_bounty_paid(obj/structure/overmap/ship/source, kind)
	SIGNAL_HANDLER
	for(var/datum/mind/member in source.ship_team?.members)
		var/datum/background_state/state = member.background_state
		if(!state || state.ended || state.key != key)
			continue
		state.add_progress(1)
		if(state.outcome == BACKGROUND_OUTCOME_ONGOING && state.progress >= state.goal_target)
			state.complete(done_line())

/datum/background/bounty_hunter/goal_line(datum/background_state/state)
	var/goal = state.goal_target || BACKGROUND_HUNTER_GOAL
	return "Bring in [lowertext(hunter_count_word(goal))] bounties. [hunter_count_word(min(state.progress, goal))] done so far."

/datum/background/bounty_hunter/outcome_line(datum/background_state/state)
	if(state.outcome == BACKGROUND_OUTCOME_DONE)
		return done_line()
	return "Brought in [state.progress] of [state.goal_target || BACKGROUND_HUNTER_GOAL]."

/datum/background/bounty_hunter/judge(datum/background_state/state)
	if(state.outcome == BACKGROUND_OUTCOME_ONGOING && state.goal_target && state.progress >= state.goal_target)
		state.complete(done_line())

/// The round-end line for a finished goal
/datum/background/bounty_hunter/proc/done_line()
	return "Brought in their bounties."

/// "None", "One", "Two"... for the memory line; digits past ten
/proc/hunter_count_word(count)
	var/static/list/words = list("None", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten")
	if(count >= 0 && count < length(words))
		return words[count + 1]
	return "[count]"

// ===== EVER-CREW [ECO-2] =====
// The collusion guard for warrants: ckeys of everyone ever on a hull's roster this round, and of every
// convict or pirate who stood on the hull while free. P2's warrant claim and P4's siphon goal read it;
// the background watch in hunter_recognition.dm fills it.

/obj/structure/overmap/ship
	/// ckeys of everyone who has been aboard this hull while free. P3 fills it; P2 and P4 read it.
	var/list/background_ever_crew

/// Puts a player's ckey on this hull's ever-crew list
/proc/background_note_ever_crew(obj/structure/overmap/ship/ship, player_key)
	var/player_ckey = ckey(player_key)
	if(QDELETED(ship) || !player_ckey)
		return
	LAZYOR(ship.background_ever_crew, player_ckey)

/// Whether a body is free: conscious, uncuffed and not stunned. Lying on a bed or a chair still counts as free.
/proc/background_is_free(mob/living/body)
	if(!isliving(body) || body.stat != CONSCIOUS)
		return FALSE
	return !HAS_TRAIT(body, TRAIT_RESTRAINED) && !HAS_TRAIT(body, TRAIT_INCAPACITATED)
