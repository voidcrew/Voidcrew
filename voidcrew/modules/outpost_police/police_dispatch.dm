/**
 * # Outpost police: dispatch
 *
 * Owner: P4. Sectors, the police lifts, ordering units and topping the scene up in waves. Spec 5.2-5.4.
 */

/// The highest stars among the suspects at the outpost
/datum/outpost_police/proc/alert_level()
	return 0

/// Which sector `where` is in: POLICE_SECTOR_*, or the /datum/outpost_berth of a hangar
/datum/outpost_police/proc/sector_of(turf/where)
	return POLICE_SECTOR_CONCOURSE

/// A lift point serving `sector`, out of `avoid_sight_of`'s sight if possible; null if none
/datum/outpost_police/proc/lift_point(sector, atom/avoid_sight_of)
	return null

/// `officer` rides the lift to `sector`, with whoever they pull. Sleeps the ride. TRUE on arrival.
/datum/outpost_police/proc/ride(mob/living/officer, sector)
	return FALSE

/// Queues one unit of `unit_kind` (POLICE_UNIT_*) for `sector`. Returns the spawn order, or null.
/datum/outpost_police/proc/order_unit(unit_kind, sector)
	return null

/// Once a second (police_core.dm tick()): responders, waves, caps, stand-downs, bodies, cases to open
/datum/outpost_police/proc/tick_dispatch()
	return
