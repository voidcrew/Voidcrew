/**
 * Ritual: Mockery of Heroes: galaxy-scoped port of TG's RPG Titles
 * (code/modules/events/wizard/rpgtitles.dm).
 *
 * He has decided the galaxy is a story about adventurers. He is not paying it a compliment.
 *
 * This is the one event on the ramp whose underlying machinery is already
 * station-independent, so the port is mostly a matter of scope declaration and voice.
 * /datum/rpgtitle_controller works off GLOB.alive_player_list and touches no z-level, area
 * or station global. Reimplementing the fantasy-component wiring here would create a second
 * copy to drift out of sync for no benefit, so the upstream controller is reused.
 *
 * Changed from the original:
 * - A can_spawn_event() guard against the controller already existing. TG does not check,
 *   so a second firing would install a second controller with a second set of global signal
 *   registrations. TG gets away with it via max_occurrences = 1; belt and braces here
 *   because the lich's ritual clock is a different caller.
 * - A small /datum/rpgtitle_controller/lich subtype guards two unchecked null dereferences
 *   in the upstream signal handlers (see below). The behaviour is otherwise the parent's.
 * - A galaxy announcement in Ilthuun's voice. The original fires silently.
 *
 * Its sibling, TG's RPG Loot (rpgloot.dm), was ported here as "Mockery of Treasure" and has
 * been REMOVED. It renamed and re-rolled the stats of every item in the galaxy, permanently
 * and irreversibly, including the stock inside NPC trader outposts, the single stickiest
 * thing the lich did to anybody. Rites do not touch the crew's property; see the roster
 * policy in lich_events.dm. Titles survives the cut because it is a label under a mob, it
 * costs nobody an item, and it dies with the round.
 */

/**
 * Guards the two unchecked derefs in the upstream controller's signal handlers.
 *
 * `/datum/rpgtitle_controller/on_crewmember_join()` calls `SSjob.get_job(rank)` and then
 * immediately reads `job.rpg_title` for any non-animal mob, and `on_mob_login()` reads
 * `living_login.mind.assigned_role.title` without checking `mind`. On a station every human
 * in the round has an assigned role; in this fork a ghost-possessed body, an event riser or
 * an admin-spawned human may not, and either path would runtime. Both are cheap to guard
 * and the parent's title-generation logic is left completely alone.
 */
/datum/rpgtitle_controller/lich

/datum/rpgtitle_controller/lich/on_crewmember_join(datum/source, mob/living/new_crewmember, rank)
	SIGNAL_HANDLER
	if(QDELETED(new_crewmember))
		return
	if(!isanimal_or_basicmob(new_crewmember) && !SSjob.get_job(rank))
		return // Upstream would deref a null job datum here.
	return ..()

/datum/rpgtitle_controller/lich/on_mob_login(datum/source, mob/new_login)
	SIGNAL_HANDLER
	if(!isliving(new_login))
		return
	var/mob/living/living_login = new_login
	if(isnull(living_login.mind?.assigned_role))
		return // Upstream would deref a null mind here.
	return ..()

/datum/round_event_control/voidcrew/lich/mockery_of_heroes
	name = "Ritual: Mockery of Heroes"
	typepath = /datum/round_event/voidcrew/lich/mockery_of_heroes
	description = "Everyone alive gains a levelled RPG title hovering beneath them."
	max_occurrences = 1
	event_scope = EVENT_SCOPE_GALAXY
	min_wizard_trigger_potency = 4
	max_wizard_trigger_potency = 7

/// One controller only; a second would double-register the join signals.
/datum/round_event_control/voidcrew/lich/mockery_of_heroes/can_spawn_event(players_amt, allow_magic = FALSE)
	. = ..()
	if(!.)
		return FALSE
	return isnull(GLOB.rpgtitle_controller)

/datum/round_event/voidcrew/lich/mockery_of_heroes
	announce_when = 1

/datum/round_event/voidcrew/lich/mockery_of_heroes/start()
	if(GLOB.rpgtitle_controller)
		return
	GLOB.rpgtitle_controller = new /datum/rpgtitle_controller/lich

/datum/round_event/voidcrew/lich/mockery_of_heroes/announce(fake)
	lich_announce_galaxy(
		"You have been telling yourselves you are heroes. I have written it down for you, \
		with the numbers, so that everyone can see exactly how much of a hero you are. \
		Mine is blank.",
		"Mockery of Heroes",
	)
