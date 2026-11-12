/**
 * # Outpost floors: the lift and who may come up
 *
 * Owner: P2 (spec 5). The lift itself is trade/outpost_elevator.dm; its floor seams call the
 * /obj/structure/overmap base procs in trade/outpost_hangar.dm (may_enter_floor(), extra_floor_rows(),
 * lift_leaves_behind(), on_lift_ride(), on_lift_emagged(), lift_refusal_text()), which answer as before floors.
 * P2 overrides them on /obj/structure/overmap/trader_outpost here, and get_floor_alcove() for ids 101 and up.
 * The panel's `floor`, `forced_until` and `force_ready_at` vars are declared in the lift file.
 *
 * Stubs below are P0's.
 */

/// Sets who the lift takes up (OUTPOST_FLOOR_ENTRY_*). Stub: sets the var. P2: who may, the metric, the lift's rows.
/datum/outpost_floor/proc/set_entry(new_entry, mob/user)
	if(!(new_entry in list(OUTPOST_FLOOR_ENTRY_CREW, OUTPOST_FLOOR_ENTRY_INVITED, OUTPOST_FLOOR_ENTRY_OPEN)))
		return FALSE
	entry_policy = new_entry
	return TRUE

/// Whether `person` may send the car up to this floor alone, by its setting, lists, hands, a pass or a forced panel.
/// Stub: FALSE.
/datum/outpost_floor/proc/may_visit(mob/person)
	return FALSE

/// Whether `person` is on the guest list, themselves or by a crew they are on. Stub: FALSE.
/datum/outpost_floor/proc/is_guest(mob/person)
	return FALSE

/// Whether `person` is barred, themselves or by a crew they are on. Stub: FALSE.
/datum/outpost_floor/proc/is_barred(mob/person)
	return FALSE

/// Whether `person` is one of the floor's hired hands. Stub: FALSE.
/datum/outpost_floor/proc/is_hand(mob/person)
	return FALSE

/// Lets one person send the car up for `duration`. Nothing in this build calls it; it is there for outpost jobs. Stub: nothing.
/datum/outpost_floor/proc/grant_pass(datum/mind/holder, duration)
	return
