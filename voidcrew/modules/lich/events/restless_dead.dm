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
	set_observer_default_invisibility(0, span_warning("A cold green pressure settles over you. Something enormous has just noticed that you are still here."))

/datum/round_event/voidcrew/lich/restless_dead/announce(fake)
	lich_announce_galaxy(
		"I have opened a small door. Nothing came through it; nothing needed to. \
		Your dead have always been standing exactly where you left them, and now you can \
		see them. Look at their faces. You will be joining them soon enough.",
		"A Small Courtesy",
	)
