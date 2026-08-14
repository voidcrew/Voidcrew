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
 * - It is timed, and therefore repeatable. TG's version runs until the wizard dies or an
 *   admin lifts it, which is why it is a one-shot there; this one lifts itself after two
 *   minutes (end_when) and lifts early if the lich dies first, both through
 *   end_lich_babel() at the bottom of this file. A rite that cleans up after itself is
 *   the repeatable-pressure shape lich_events.dm's cap policy asks for, so this carries a
 *   real cap rather than max_occurrences = 1. What stops two running at once is the
 *   controller's can_spawn_event(), not the cap.
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
	/**
	 * Repeatable pressure, not a one-shot. See the cap policy in lich_events.dm.
	 *
	 * It qualifies now that it self-terminates: two minutes, ends on its own, leaves nothing
	 * behind. Sized below the ship-scoped hazards it shares the top band with (grave_dirt 20,
	 * grave_air 10, corpse_bloom 8) because it is galaxy-wide and, unlike them, has no verb
	 * attached, a crew cannot put a mask on or stand on a table to answer it, they can only
	 * wait. At the plateau it is roughly one of four eligible events every
	 * LICH_RITUAL_INTERVAL, so six firings is well over an hour of a long round.
	 */
	max_occurrences = 6
	event_scope = EVENT_SCOPE_GALAXY
	min_wizard_trigger_potency = 5
	max_wizard_trigger_potency = 7

/**
 * One controller at a time. A second concurrent instance would double-register the latejoin
 * signal and orphan the first, and the survivor's Destroy() would cure everyone early.
 *
 * This is a concurrency gate, not an occurrence cap: max_occurrences counts firings, and the
 * global empties itself when the rite expires, so the next ritual is free to roll this again.
 * It also, deliberately, holds the rite off while an admin's own Tower of Babel is up.
 */
/datum/round_event_control/voidcrew/lich/tongues_of_the_dead/can_spawn_event(players_amt, allow_magic = FALSE)
	. = ..()
	if(!.)
		return FALSE
	return isnull(GLOB.tower_of_babel)

/datum/round_event/voidcrew/lich/tongues_of_the_dead
	announce_when = 1
	/// Two minutes of silence. SSevents ticks every 2 seconds, so 60 ticks.
	end_when = 60

/datum/round_event/voidcrew/lich/tongues_of_the_dead/start()
	if(GLOB.tower_of_babel)
		return
	GLOB.tower_of_babel = new /datum/tower_of_babel/lich

/**
 * Lifts the curse when the timer runs out.
 *
 * end_lich_babel() type-checks the global before destroying it, so if the rite lost the
 * race to an admin's own Babel, or the lich died mid-rite and already cured everyone,
 * this is a no-op rather than a double-cure or a stolen cast.
 */
/datum/round_event/voidcrew/lich/tongues_of_the_dead/end()
	end_lich_babel("Ilthuun's grip on the galaxy's tongues has slipped. The living can understand each other again.")

/datum/round_event/voidcrew/lich/tongues_of_the_dead/announce(fake)
	lich_announce_galaxy(
		"Speech was always a courtesy you extended to each other. I am withdrawing it. \
		Scream if you like; it will not survive the trip across the room. \
		The dead have managed for centuries without it.",
		"Tongues of the Dead",
	)

/**
 * Lifts the curse. Two callers: the event's own end() when its two minutes are up, and the
 * site's victory path (on_lich_slain(), lich_site.dm) if the raid kills him sooner.
 *
 * The timer is the normal exit; the death path is the early one. Both are needed. Rule 2 in
 * lich_events.dm's header says nothing Ilthuun does outlives Ilthuun, and a rite whose only
 * cure was an admin verb was exactly the "no amount of playing well undoes any of it"
 * failure the four deleted rites were deleted for. Whichever fires first wins, and the
 * other becomes a no-op via the type check below.
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
/proc/end_lich_babel(deadchat_line = "Ilthuun's hold on the galaxy's tongues has broken. The living can understand each other again.")
	if(!istype(GLOB.tower_of_babel, /datum/tower_of_babel/lich))
		return
	deadchat_broadcast(
		deadchat_line,
		message_type = DEADCHAT_ANNOUNCEMENT,
	)
	QDEL_NULL(GLOB.tower_of_babel)
