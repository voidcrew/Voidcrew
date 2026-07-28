/**
 * Ritual: Mockery of Heroes / Mockery of Treasure — galaxy-scoped ports of TG's RPG Titles
 * and RPG Loot (code/modules/events/wizard/rpgtitles.dm, rpgloot.dm).
 *
 * He has decided the galaxy is a story about adventurers. He is not paying it a compliment.
 *
 * These two are the only events on the ramp whose underlying machinery is already
 * station-independent, so they are the only two where the port is mostly a matter of scope
 * declaration and voice. /datum/rpgtitle_controller works off GLOB.alive_player_list and
 * /datum/rpgloot_controller iterates world items; neither touches a z-level, an area, or a
 * station global. Reimplementing the fantasy-component wiring here would create a second
 * copy to drift out of sync for no benefit, so both upstream controllers are reused.
 *
 * Changed from the originals:
 * - Both gain a can_spawn_event() guard against their controller already existing. TG does
 *   not check, so a second firing would install a second controller with a second set of
 *   global signal registrations. TG gets away with it via max_occurrences = 1; belt and
 *   braces here because the lich's ritual clock is a different caller.
 * - Titles uses a small /datum/rpgtitle_controller/lich subtype that guards two unchecked
 *   null dereferences in the upstream signal handlers (see below). The behaviour is
 *   otherwise the parent's.
 * - Both gain galaxy announcements in Ilthuun's voice. The originals fire silently.
 *
 * Not fixed, and worth knowing: RPG Loot renames and re-rolls every item in the world,
 * including the stock inside NPC trader outposts. That is inherent to what the event is —
 * it is declared EVENT_SCOPE_GALAXY precisely because it cannot be confined to a hull — and
 * it is cosmetic-plus-stat-jitter rather than damage, so it does not violate the
 * outposts-are-never-harmed rule. It is still the widest-reaching thing on this roster.
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

/datum/round_event_control/voidcrew/lich/mockery_of_treasure
	name = "Ritual: Mockery of Treasure"
	typepath = /datum/round_event/voidcrew/lich/mockery_of_treasure
	description = "Every object in the galaxy acquires a fantastical name and a quality roll."
	max_occurrences = 1
	event_scope = EVENT_SCOPE_GALAXY
	min_wizard_trigger_potency = 4
	max_wizard_trigger_potency = 7

/// One controller only; a second would double-register COMSIG_GLOB_ATOM_AFTER_POST_INIT.
/datum/round_event_control/voidcrew/lich/mockery_of_treasure/can_spawn_event(players_amt, allow_magic = FALSE)
	. = ..()
	if(!.)
		return FALSE
	return isnull(GLOB.rpgloot_controller)

/datum/round_event/voidcrew/lich/mockery_of_treasure
	announce_when = 1

/datum/round_event/voidcrew/lich/mockery_of_treasure/start()
	if(GLOB.rpgloot_controller)
		return
	GLOB.rpgloot_controller = new /datum/rpgloot_controller

/datum/round_event/voidcrew/lich/mockery_of_treasure/announce(fake)
	lich_announce_galaxy(
		"Grave goods. All of it. Every hammer, every mug, every gun you are so proud of has \
		only ever been waiting for a grave. I have given each piece the name it will be \
		catalogued under. Do try to get a good one.",
		"Mockery of Treasure",
	)
