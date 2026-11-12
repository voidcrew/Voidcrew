/**
 * # Outpost floors: the console (tenancy, settings, identity, hands)
 *
 * Owner: P3 (spec 3b.3, 3b.4, 5, 7). The management console is player_outposts/outpost_management_ui.dm; on any host
 * it merges floor_ui_data() into its data and hands actions it does not know to floor_ui_act(). The base procs on
 * /obj/structure/overmap/dynamic/player_outpost (player_outpost.dm) answer as before floors; P3 overrides
 * can_take_over(), claim_denial(), announce_abandoned(), floor_ui_data() and floor_ui_act() on the host here.
 *
 * Stubs below are P0's.
 */

/// Names the floor: `reject_bad_text()`, OUTPOST_FLOOR_NAME_MAX, the rename cooldown, no announcement. Stub: FALSE.
/datum/outpost_floor/proc/set_name(new_name, mob/user)
	return FALSE

/// Sets the floor's line for the board: `reject_bad_text()`, OUTPOST_FLOOR_LINE_MAX. Stub: FALSE.
/datum/outpost_floor/proc/set_line(new_line, mob/user)
	return FALSE

/// Sets the accent. Anything but one of the eight ids is refused (A90). P0 wrote the check; P3 adds who may.
/datum/outpost_floor/proc/set_accent(new_accent, mob/user)
	var/list/ids = OUTPOST_FLOOR_ACCENTS
	if(!istext(new_accent) || !ids[new_accent])
		return FALSE
	accent = new_accent
	return TRUE

/// Offers `target` work on this floor. They must say yes (A80). Stub: FALSE.
/datum/outpost_floor/proc/offer_hire(mob/living/target, mob/user)
	return FALSE

/// Lets a hand go. Stub: FALSE.
/datum/outpost_floor/proc/let_go(datum/mind/hand, mob/user)
	return FALSE
