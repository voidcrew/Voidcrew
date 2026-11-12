/**
 * # Outpost floors: liveliness
 *
 * Owner: P8 (spec 12). Tenants, moving day, fitters, the lift chime, the buzzer and the note under the door.
 * Everything here is an ambient outpost NPC inside the outpost's existing caps (A47). Strings: strings/floor_life.json.
 *
 * Stubs below are P0's.
 */

/// A crew has just taken this floor: the tenant moves out and a note waits under the door. Stub: nothing.
/datum/outpost_floor/proc/on_let(mob/buyer)
	return

/// A room has just been placed on this floor: fitters come up, once. Stub: nothing.
/datum/outpost_floor/proc/on_room_placed(datum/outpost_upgrade/room)
	return

/// The car is on its way up: the lift chimes on the floor. Stub: nothing.
/datum/outpost_floor/proc/on_lift_arriving()
	return
