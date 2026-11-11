/**
 * # Outpost police: warrants, heat and stars
 *
 * Owner: P1 (wanted core). Every crime at a trader outpost reaches report_crime(); this file turns it into
 * heat on the offender's warrant (GLOB.outpost_crimes), fades it, fines it, bars and embargoes for it.
 * Spec sections 2, 4, 6.2, 9 (the embargo half) and 15.
 *
 * P0 left stubs with the frozen signatures (build plan section 2). report_crime() runs inside signal
 * handlers (the PvP watcher, outpost property, the armed sweep): it and everything it calls must never sleep.
 */

/**
 * `offender` did `crime` (OUTPOST_CRIME_*) to `victim` (or to nobody in particular) with `source` (the item
 * used, or null). Returns the offender's stars here after it, 0 for a counted crime still under one star, or
 * null when it did not count (no mind, no witness, folded into the last one). A counted `source` joins the
 * warrant's evidence. Never sleeps.
 */
/datum/outpost_police/proc/report_crime(mob/living/offender, crime, atom/victim, obj/item/source)
	SHOULD_NOT_SLEEP(TRUE)
	if(!offender?.mind)
		return null
	log_game("OUTPOST POLICE: [key_name(offender)] committed [crime][victim ? " against [victim]" : ""][source ? " with [source] ([source.type])" : ""] at [outpost] ([AREACOORD(offender)]).")
	return null

/// Stars `who` has here, 0 to 5
/datum/outpost_police/proc/get_stars(datum/mind/who)
	return 0

/// `who`'s warrant here, or null
/datum/outpost_police/proc/get_warrant(datum/mind/who)
	return null

/// How hard officers may go at `target`: POLICE_FORCE_* (NONE for no mind, in custody or dead)
/datum/outpost_police/proc/force_level(mob/living/target)
	return POLICE_FORCE_NONE

/**
 * Whether `user` is refused service here (shops, the permit desk, the checkpoint): stars, a bar, or crew of
 * an embargoed ship. P0 stub: the embargo half only.
 */
/datum/outpost_police/proc/is_barred(mob/user)
	if(!user?.mind || !outpost)
		return FALSE
	var/datum/voidcrew_crew_record/crew = user.mind.get_reputation_crew()
	for(var/datum/team/voidcrew/team in crew?.teams)
		if(team.ship && outpost.is_ship_embargoed(team.ship))
			return TRUE
	return FALSE

/// An officer (or the checkpoint's scan) sees `who` at `where` now
/datum/outpost_police/proc/note_seen(datum/mind/who, turf/where)
	return

/**
 * The fine for `warrant`'s stars and the zone, from its remembered crew's ship accounts pooled, richest first,
 * all or nothing (abuse M6, M7). TRUE with the money gone, or FALSE with nothing taken. Never sleeps.
 */
/datum/outpost_police/proc/charge_fine(datum/outpost_warrant/warrant)
	return FALSE

/// `who`'s heat goes to 0 (`served`: they did their time); their prior stays
/datum/outpost_police/proc/close_warrant(datum/mind/who, served)
	return

/// Clears every warrant, prior and bar of `crew` here and lifts its embargo
/datum/outpost_police/proc/pardon_crew(datum/voidcrew_crew_record/crew)
	return

/// Warrants of one star or more whose holder is at this outpost
/datum/outpost_police/proc/suspects_at_outpost()
	return list()

/// An officer was hit (relay_attackers): ASSAULT_OFFICER or RESIST (abuse M3). From the officer's body (P2).
/datum/outpost_police/proc/officer_struck(mob/living/officer, atom/attacker, attack_flags)
	return

/// Someone tried to cuff an officer: ASSAULT_OFFICER (abuse M3). From the officer's body (P2).
/datum/outpost_police/proc/officer_cuff_attempt(mob/living/officer, mob/living/user)
	return

/// Once a second (police_core.dm tick()): sightings, fading, priors, bars, accomplices, pending reports
/datum/outpost_police/proc/tick_warrants()
	return
