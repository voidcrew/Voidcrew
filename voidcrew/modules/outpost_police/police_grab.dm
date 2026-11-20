/**
 * # Outpost police: grabbing outpost people (owner decision 53)
 *
 * A townsperson, worker, trader or gate guard (never an officer, whose handling is stealth's own) who is grabbed:
 * - pulled along by a player, they grumble (on a cooldown) and pull free as ever (ambient_escape). No crime.
 * - grabbed aggressively or worse (a neck grab, a strangle), they shout for help: a line and a scream officers in
 *   earshot come to look at, no more often than OUTPOST_POLICE_GRAB_SHOUT_COOLDOWN. The grab is the same crime as
 *   hitting them unarmed (OUTPOST_CRIME_ASSAULT_CIVILIAN, or OUTPOST_CRIME_ASSAULT_STAFF for a trader or gate guard),
 *   through register_aggression() like a blow, once per grab: witnessed, told and counted like any other crime.
 *
 * tg sends the grab's tightening to the grabber (setGrabState()), so they listen on whoever holds them while they do.
 * A hostage taken by the neck is charged here once, as the grab; the stealth hostage code charges nothing itself, and a
 * hold-up's robbery is its own crime (recovery_robbery.dm).
 */

/mob/living/carbon/human/npc/ambient_npc/outpost
	/// The grab on them now has been charged already (one charge a grab)
	var/grab_charged = FALSE

/mob/living/carbon/human/npc/ambient_npc/outpost/Initialize(mapload, datum/human_npc_order/order)
	. = ..()
	RegisterSignal(src, COMSIG_LIVING_GET_PULLED, PROC_REF(on_outpost_pulled))
	RegisterSignal(src, COMSIG_ATOM_NO_LONGER_PULLED, PROC_REF(on_outpost_let_go))

/// Whether a grab on them is handled here: alive, no one playing them, and not an officer
/mob/living/carbon/human/npc/ambient_npc/outpost/proc/reacts_to_grabs()
	return stat != DEAD && !mind && !client && !istype(src, /mob/living/carbon/human/npc/ambient_npc/outpost/police)

/// Someone took hold of them: a word for a player's pull, and an ear on the grip
/mob/living/carbon/human/npc/ambient_npc/outpost/proc/on_outpost_pulled(datum/source, mob/living/puller)
	SIGNAL_HANDLER
	grab_charged = FALSE
	if(!isliving(puller) || puller == src || !reacts_to_grabs())
		return
	RegisterSignal(puller, COMSIG_MOVABLE_SET_GRAB_STATE, PROC_REF(on_outpost_grip), override = TRUE)
	if(stat != CONSCIOUS || fading || !(puller.mind || puller.client) || !reaction_ready("pulled", OUTPOST_POLICE_PULL_REMARK_COOLDOWN))
		return
	if(!buckled)
		face_atom(puller)
	speak_context(AMBIENT_LINE_PULLED, puller, force = TRUE)

/// Let go of
/mob/living/carbon/human/npc/ambient_npc/outpost/proc/on_outpost_let_go(datum/source, atom/movable/puller)
	SIGNAL_HANDLER
	grab_charged = FALSE
	if(puller)
		UnregisterSignal(puller, COMSIG_MOVABLE_SET_GRAB_STATE)

/// Whoever holds them changed their grip (sent to the grabber, before grab_state changes)
/mob/living/carbon/human/npc/ambient_npc/outpost/proc/on_outpost_grip(mob/living/grabber, new_state)
	SIGNAL_HANDLER
	if(grabber.pulling != src)
		UnregisterSignal(grabber, COMSIG_MOVABLE_SET_GRAB_STATE)
		return
	if(new_state < GRAB_AGGRESSIVE || !reacts_to_grabs())
		return
	if(stat == CONSCIOUS && !fading && reaction_ready("grabbed", OUTPOST_POLICE_GRAB_SHOUT_COOLDOWN))
		speak_context(AMBIENT_LINE_GRABBED, grabber, force = TRUE)
		stealth_noise(src, STEALTH_NOISE_SCREAM, null, grabber)
	if(grab_charged)
		return
	grab_charged = TRUE
	grab_outpost()?.register_aggression(grabber, grab_crime(), src)

/// The crime a rough grab on them is: hitting them unarmed
/mob/living/carbon/human/npc/ambient_npc/outpost/proc/grab_crime()
	return OUTPOST_CRIME_ASSAULT_CIVILIAN

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/grab_crime()
	return OUTPOST_CRIME_ASSAULT_STAFF

/// The trader outpost they belong to, or null
/mob/living/carbon/human/npc/ambient_npc/outpost/proc/grab_outpost()
	var/datum/ambient_place/outpost/outpost_place = place
	var/obj/structure/overmap/trader_outpost/outpost = istype(outpost_place) ? outpost_place.outpost() : null
	return outpost || get_trader_outpost_for_turf(get_turf(src))

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/grab_outpost()
	return outpost || ..()
