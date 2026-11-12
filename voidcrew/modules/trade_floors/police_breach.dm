/**
 * # Outpost floors: breaching
 *
 * Owner: P6 (spec 6.5). During a warrant on a floor every door admits an officer (police_floors.dm) and anything else
 * in the way is breached: a real, telegraphed explosion. A blast works on every floor because a floor is never
 * blast-protected trader ground (trade/outpost_security.dm, is_trader_outpost_protected()).
 * The subtree is already in the officers' planning list, before the force subtree (stealth_police/police_stealth.dm).
 *
 * Stubs below are P0's.
 */

/// The first blocked tile on the cheapest way from `start` to `goal` over this floor, or null when there is none. Stub: null.
/datum/outpost_floor/proc/breach_target(turf/start, turf/goal)
	return null

/// `officer` sets a charge on `target`. Stub: FALSE.
/datum/outpost_police/proc/plant_breach(mob/living/officer, turf/target)
	return FALSE

/// The charge an officer sets: a fixture, never an item. Never saved on a ship.
/obj/structure/outpost_breach_charge
	name = "breaching charge"
	anchored = TRUE

/// Plans a breach when an officer has had no way to a suspect on a floor under warrant. Stub: plans nothing.
/datum/ai_planning_subtree/outpost_police_breach
