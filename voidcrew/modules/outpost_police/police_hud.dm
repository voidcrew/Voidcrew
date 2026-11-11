/**
 * # Outpost police: the wanted alert
 *
 * Owner: P8. Stars as a HUD alert icon (owner decision 10), no chat text. Spec 12.
 */

/atom/movable/screen/alert/outpost_wanted
	name = "Wanted"

/// Throws or clears `who`'s wanted alert
/datum/outpost_police/proc/update_hud(datum/mind/who)
	return
