/**
 * # Outpost floors: the floor datum
 *
 * Owner: P1 (build plan, "P1 Floor core"). The shared vars and the geometry procs are in _floor_types.dm (P0, frozen).
 * P0 wrote New(), Destroy() and default_accent() so the seams could be tested; P1 extends them.
 */

/datum/outpost_floor/New(obj/structure/overmap/trader_outpost/new_outpost, new_number)
	..()
	outpost = new_outpost
	number = new_number
	accent = default_accent()

/**
 * P1: before the refs go, put whoever is on the floor in the lobby and free the ground (A10), and make sure a floor
 * that dies under warrant leaves nothing behind in the police (A51).
 */
/datum/outpost_floor/Destroy()
	GLOB.outpost_floors_on_ground -= src
	if(outpost?.floors)
		var/slot = outpost.floors.Find(src)
		if(slot)
			outpost.floors[slot] = null
	if(host)
		if(host.floor == src)
			host.floor = null
		QDEL_NULL(host)
	if(panel?.floor == src)
		panel.floor = null
	panel = null
	alcove_turfs.Cut()
	goods_turfs.Cut()
	guests.Cut()
	barred.Cut()
	hands.Cut()
	QDEL_NULL(reservation)
	bounds = null
	landing_bounds = null
	outpost = null
	return ..()

/// The colour a floor starts with: neighbours differ
/datum/outpost_floor/proc/default_accent()
	var/list/ids = OUTPOST_FLOOR_ACCENTS
	return ids[((max(number, 1) - 1) % length(ids)) + 1]

/// The colour to draw this floor's accent in
/datum/outpost_floor/proc/accent_colour()
	var/list/ids = OUTPOST_FLOOR_ACCENTS
	return ids[accent] || ids[OUTPOST_FLOOR_ACCENT_AMBER]

/// Whether `person` is one of the floor's own people: the owner, a resident, or on a crew the owner is on. Not a guest, not a hand.
/// Stub: FALSE. P1: `host.is_outpost_member(person)`, and nobody while the floor has no owner.
/datum/outpost_floor/proc/is_member(mob/person)
	return FALSE

/// The name shown under the floor's: the owner's ship, or the owner where there is none. Stub: "".
/datum/outpost_floor/proc/crew_name()
	return ""
