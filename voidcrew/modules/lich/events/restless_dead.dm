/**
 * Ritual: Restless Dead: galaxy-scoped port of TG's G-G-G-Ghosts! (code/modules/events/wizard/ghost.dm).
 *
 * The original is two lines: set every observer's default invisibility to 0 so the dead
 * are visible to the living, and tell them they feel obvious. That mechanic has no station
 * coupling at all (set_observer_default_invisibility() walks GLOB.player_list) so the
 * port is a straight copy into the lich's own control tree with the flavor rewritten.
 *
 * Changed from the original:
 * - Galaxy-scoped rather than station-scoped, because observers are not on anyone's z-level
 *   in particular and the effect was always global in practice.
 * - Gains an announcement. TG's version fires silently; the lich's first ritual should be
 *   the one that tells the galaxy something is wrong, and it costs nothing but a line.
 * - TG's sibling event in the same file (Possessing Ghosts, which grants fun_verbs) is NOT
 *   ported. It is an admin-flavored toy that hands live players poltergeist powers with no
 *   counterplay, and it is not on the contract's ramp.
 * - His death undoes it. TG's version is permanent for the round; here the veil restores
 *   itself through end_restless_dead() (bottom of this file), called from the site's victory
 *   path, the same reach-back Tongues of the Dead gets. The visible dead are his working,
 *   and rule 2 in lich_events.dm's header says nothing he does outlives him.
 */
/datum/round_event_control/voidcrew/lich/restless_dead
	name = "Ritual: Restless Dead"
	typepath = /datum/round_event/voidcrew/lich/restless_dead
	description = "The dead become visible to the living, everywhere at once."
	max_occurrences = 1
	event_scope = EVENT_SCOPE_GALAXY
	min_wizard_trigger_potency = 0
	max_wizard_trigger_potency = 2

/// Pointless to run twice, and pointless if the veil is already down for some other reason.
/datum/round_event_control/voidcrew/lich/restless_dead/can_spawn_event(players_amt, allow_magic = FALSE)
	. = ..()
	if(!.)
		return FALSE
	return GLOB.observer_default_invisibility != 0

/datum/round_event/voidcrew/lich/restless_dead
	announce_when = 1

/datum/round_event/voidcrew/lich/restless_dead/start()
	GLOB.lich_restless_dead_active = TRUE
	set_observer_default_invisibility(0, span_warning("A cold green pressure settles over you. Something enormous has just noticed that you are still here."))

/datum/round_event/voidcrew/lich/restless_dead/announce(fake)
	lich_announce_galaxy(
		"I have opened a small door. Nothing came through it; nothing needed to. \
		Your dead have always been standing exactly where you left them, and now you can \
		see them. Look at their faces. You will be joining them soon enough.",
		"A Small Courtesy",
	)

/// TRUE while the veil is down because of THIS rite. end_restless_dead() keys on it so
/// killing the lich can only undo his own casting: if an admin made observers visible on
/// their own (this rite never fired), his death must not quietly revert their work.
GLOBAL_VAR_INIT(lich_restless_dead_active, FALSE)

/**
 * Restores the veil. One caller: the site's victory path (on_lich_slain(), lich_site.dm).
 *
 * Unlike Tongues of the Dead this rite has no timer, so his death is its only cure; that
 * is what keeps a one-shot with no end() on the right side of rule 2 in lich_events.dm's
 * header. The flag check makes it a no-op when the rite never fired, and the value check
 * makes it yield if something else (roundend, an admin verb) has already moved observer
 * invisibility off 0 since, whatever they set stands.
 *
 * Restoring the GLOBAL matters as much as the sweep inside the helper: freshly made
 * observers read GLOB.observer_default_invisibility in New(), so without it every ghost
 * created after his death would spawn visible.
 */
/proc/end_restless_dead()
	if(!GLOB.lich_restless_dead_active)
		return
	GLOB.lich_restless_dead_active = FALSE
	if(GLOB.observer_default_invisibility != 0)
		return
	set_observer_default_invisibility(INVISIBILITY_OBSERVER, span_notice("The green pressure lifts. The living can no longer see you."))
