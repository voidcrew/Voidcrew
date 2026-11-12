/**
 * # Outpost floors: round metrics
 *
 * Owner: P9 (spec 10). One helper every package calls. Events: floor_bought, floor_given_up, floor_claimed,
 * floor_warrant, floor_breach, floor_lift_forced, floor_setting, floor_visit, floor_npc_sale, floor_fitting,
 * floor_supply_order, floor_hand.
 * Trap: record_metric() takes named arguments, and no positional string may equal one of its parameter names.
 *
 * Stub below is P0's.
 */

/// Records `event` for `floor`. Stub: nothing.
/proc/record_floor_metric(event, datum/outpost_floor/floor, mob/actor, amount = 0)
	return
