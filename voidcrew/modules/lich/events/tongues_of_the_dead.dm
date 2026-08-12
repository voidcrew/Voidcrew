/**
 * Ritual: Tongues of the Dead: galaxy-scoped port of TG's Tower of Babel
 * (code/modules/events/wizard/tower_of_babel.dm).
 *
 * Every living tongue in the galaxy forgets how to be understood. The dead have only ever
 * had one language and now everyone is speaking it badly.
 *
 * The TG event is a one-liner that instantiates `/datum/tower_of_babel`. That controller
 * datum is where the station coupling lives: its New() skips anyone failing
 * `is_station_level(curse_turf.z)`, and grants immunity plus omnilingualism to anyone
 * `IS_WIZARD()`. In this fork the z check resolves TRUE for whatever levels currently hold a
 * ship and FALSE for everyone standing in a ruin, on a planet, or aboard a trader outpost,
 * a galaxy-wide event with an arbitrary geographic hole in it.
 *
 * Changed from the original:
 * - A /datum/tower_of_babel/lich subtype replaces New() outright, dropping the z filter and
 *   the wizard-immunity clause. It still registers COMSIG_GLOB_CREWMEMBER_JOINED so
 *   latejoiners are cursed, and it still assigns into GLOB.tower_of_babel, which matters,
 *   because the parent's Destroy() is what cures everybody, and the admin
 *   /client/proc/tower_of_babel_undo() verb reads that same global. Subtyping keeps the undo
 *   path working; a parallel datum would have silently broken it.
 * - The per-victim half, `curse_of_babel()`, is reused verbatim. It has no station coupling,
 *   handles the antimagic check and the silicon exemption, and owns the status effect.
 * - The deadchat line and announcement are reflavored. Nobody is immune, including him.
 *   He simply has nothing left to say that requires a tongue.
 * - It ends when he does. See end_lich_babel() at the bottom of this file.
 */

/**
 * Ilthuun's Babel: same curse, no station filter, no exemptions.
 *
 * New() deliberately does not chain to the parent. The parent's body IS the station-scoped
 * victim sweep this subtype exists to replace. The signal registration it also performs is
 * repeated here so latejoin cursing still works, and Destroy() is left entirely to the
 * parent so the cure path stays in one place.
 */
/datum/tower_of_babel/lich

/datum/tower_of_babel/lich/New()
	RegisterSignal(SSdcs, COMSIG_GLOB_CREWMEMBER_JOINED, PROC_REF(handle_new_player))

	deadchat_broadcast(
		"Ilthuun has torn the tongues out of the galaxy. Nobody left alive can make themselves understood.",
		message_type = DEADCHAT_ANNOUNCEMENT,
	)

	for(var/mob/living/carbon/target in GLOB.player_list)
		if(QDELETED(target) || !target.mind)
			continue
		if(target.stat == DEAD)
			continue
		curse_of_babel(target)

/datum/round_event_control/voidcrew/lich/tongues_of_the_dead
	name = "Ritual: Tongues of the Dead"
	typepath = /datum/round_event/voidcrew/lich/tongues_of_the_dead
	description = "Everyone alive forgets their languages and is given a garbled one instead."
	max_occurrences = 1
	event_scope = EVENT_SCOPE_GALAXY
	min_wizard_trigger_potency = 5
	max_wizard_trigger_potency = 7

/// One controller only; a second would double-register the latejoin signal and orphan the first.
/datum/round_event_control/voidcrew/lich/tongues_of_the_dead/can_spawn_event(players_amt, allow_magic = FALSE)
	. = ..()
	if(!.)
		return FALSE
	return isnull(GLOB.tower_of_babel)

/datum/round_event/voidcrew/lich/tongues_of_the_dead
	announce_when = 1

/datum/round_event/voidcrew/lich/tongues_of_the_dead/start()
	if(GLOB.tower_of_babel)
		return
	GLOB.tower_of_babel = new /datum/tower_of_babel/lich

/datum/round_event/voidcrew/lich/tongues_of_the_dead/announce(fake)
	lich_announce_galaxy(
		"Speech was always a courtesy you extended to each other. I am withdrawing it. \
		Scream if you like; it will not survive the trip across the room. \
		The dead have managed for centuries without it.",
		"Tongues of the Dead",
	)

/**
 * Lifts the curse. Called from the site's victory path (on_lich_slain(), lich_site.dm).
 *
 * This rite is one of the four that outlive their own firing, and rule 2 in
 * lich_events.dm's header says nothing Ilthuun does outlives Ilthuun. Without this the
 * galaxy stays mute for the rest of the round no matter how well the raid went, and the
 * only cure is an admin verb, exactly the "no amount of playing well undoes any of it"
 * failure the four deleted rites were deleted for.
 *
 * The cure is entirely the parent's Destroy(): it unregisters the latejoin signal and
 * walks GLOB.player_list calling cure_curse_of_babel() on every carbon, dead or alive
 * and wherever they are standing. QDEL_NULL is what the admin undo verb does, for the
 * same reason, the global slot has to be emptied as well as the datum destroyed, or
 * can_spawn_event() keeps refusing a future instance.
 *
 * The type check is load-bearing rather than defensive. GLOB.tower_of_babel is a single
 * global slot shared with upstream's wizard event and with /client/proc/tower_of_babel;
 * if an admin cast their own Babel over the top of the rite, theirs is what is sitting
 * in the slot, and killing the lich must not quietly undo an admin's work.
 */
/proc/end_lich_babel()
	if(!istype(GLOB.tower_of_babel, /datum/tower_of_babel/lich))
		return
	deadchat_broadcast(
		"Ilthuun's hold on the galaxy's tongues has broken. The living can understand each other again.",
		message_type = DEADCHAT_ANNOUNCEMENT,
	)
	QDEL_NULL(GLOB.tower_of_babel)
