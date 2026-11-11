/**
 * # Outpost recovery: replacement staff and returning residents
 *
 * Owner: R2 (spec-rehydrate.md 4.1, RESTAFF and REFILL). Replacement traders, checkpoint guards, the sergeant and
 * beat officers arrive together by lift and walk to their posts; each shop opens when its keeper reaches the
 * counter (shop.set_keeper(), R1). Then ambient roles come back one at a time near clean stops.
 *
 * Behaviour at R0: none.
 */

/// The counters and posts that need someone: a list of /datum/outpost_shop (counters) and posts R2 defines.
/datum/outpost_recovery/proc/staff_needed()
	return list()

/// Makes the staff staff_needed() lists at the lift and sends them to their posts
/datum/outpost_recovery/proc/send_staff()
	return
