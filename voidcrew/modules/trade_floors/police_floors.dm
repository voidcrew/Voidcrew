/**
 * # Outpost floors: the police
 *
 * Owner: P5 (spec 6). Lives here and not in voidcrew/modules/outpost_police so that it may override anything trade
 * or the police declare. The police tick calls tick_floors() after tick_warrants(); has_work() asks
 * floors_have_work(); dispatch, perception, the morgue crew and the door hook fall through to the procs below.
 * `warrant_in_force` and `public_ground` on a floor are written here and nowhere else.
 *
 * Stubs below are P0's and answer as if there were no floors.
 */

/// Once a second: warrants on floors start and end, and each floor's `public_ground` is kept (spec 6.3, 6.4, L38). Stub: nothing.
/datum/outpost_police/proc/tick_floors()
	return

/// Whether a floor gives the police something to do. Stub: FALSE.
/datum/outpost_police/proc/floors_have_work()
	return FALSE

/// The sector `where` is in when it is on one of this outpost's floors (the /datum/outpost_floor), else null. Stub: null.
/datum/outpost_police/proc/floor_sector_of(turf/where)
	return null

/// The lift tiles of a floor sector. Stub: an empty list.
/datum/outpost_police/proc/floor_lift_tiles(sector)
	return list()

/// Whether `where` is a lift tile of one of this outpost's floors. Stub: FALSE.
/datum/outpost_police/proc/floor_is_lift_tile(turf/where)
	return FALSE

/// A crime at the lift (OUTPOST_CRIME_LIFT_TAMPER, OUTPOST_CRIME_ABDUCTION), through the one witness seam (A17). Stub: nothing.
/datum/outpost_police/proc/floor_lift_report(mob/offender, crime, turf/where, mob/victim)
	return

/// Someone hit a floor's fitting. Vandalism on public ground, by anyone but the floor's people (L39). Stub: nothing.
/datum/outpost_police/proc/floor_fitting_hit(mob/offender, atom/fitting, obj/item/tool)
	return

/// The lift panels of floors that are public ground or under warrant: witnesses, like the lobby's. Stub: an empty list.
/datum/outpost_police/proc/floor_cameras()
	return list()

/// Whether the morgue crew may take `body`, which lies on a floor at `where` (spec 6.3). The caller has already
/// made the checks that hold anywhere (dead, loose, not held, not done). Stub: FALSE.
/datum/outpost_recovery/proc/floor_body_free(mob/living/body, turf/where)
	return FALSE

/// Whether `door` must open for `user` whatever its setting: outpost police NPCs on a floor under warrant (A42). Stub: FALSE.
/proc/police_floor_door_override(obj/machinery/door/door, mob/user)
	return FALSE

/// Everyone on the floor, alive or dead, who is not one of its own people. Stub: an empty list.
/datum/outpost_floor/proc/visitors_upstairs()
	return list()
