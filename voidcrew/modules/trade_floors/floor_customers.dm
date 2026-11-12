/**
 * # Outpost floors: NPC customers and patrons
 *
 * Owner: P11 (spec 3b.6, 12; L23, L36). Customers come up to an Open floor whose shop is open while one of its
 * people or hands is there, buy one cheap thing at a sale point and leave. One who buys food or a drink sits down and
 * really consumes it. Every NPC sale on a floor draws on the one budget here (A64, A76): OUTPOST_FLOOR_NPC_ITEM_MAX an
 * item, OUTPOST_FLOOR_NPC_BUDGET per OUTPOST_FLOOR_NPC_BUDGET_WINDOW, kept as a "ready at" time so that no toggle,
 * re-placed shop or extra till raises it. The sale itself is P12's (npc_buy()). Strings: strings/floor_customers.json.
 *
 * Stubs below are P0's.
 */

/// Credits NPC custom may still spend on this floor now. Stub: 0.
/datum/outpost_floor/proc/npc_budget_left()
	return 0

/// Takes `amount` from the budget. FALSE, and nothing taken, when it is not all there. Stub: FALSE.
/datum/outpost_floor/proc/npc_budget_spend(amount)
	return FALSE
