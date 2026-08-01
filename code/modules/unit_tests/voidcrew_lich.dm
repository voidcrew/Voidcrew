/**
 * # Lich ritual roster conformance
 *
 * The Verdigris' ritual clock (voidcrew/modules/lich/lich_site.dm) filters
 * SSevents.control down to /datum/round_event_control/voidcrew/lich, applies
 * the potency window inclusively, and fires one every LICH_RITUAL_INTERVAL as
 * potency ramps 0 -> LICH_MAX_POTENCY. Two properties of that roster are
 * argued for at length in lich_events.dm's header and enforced by nothing:
 *
 * - **Every band on the ramp must have something in it.** A band with no
 *   eligible event fires nothing. There is no relaxed fallback pass, so a
 *   gap is a beat of silence that nobody sees.
 * - **The top band must keep more than one repeatable option, forever.** The
 *   clock plateaus at max potency and stays there for the rest of the round;
 *   one-shots are spent within minutes and then the lich stops applying
 *   pressure entirely.
 *
 * Also checked: the `wizardevent` flag, which is the only thing keeping these
 * out of the ambient SSdynamic_events roster. Drop it on one event and a lich
 * curse starts landing on crews in rounds with no lich in the galaxy.
 */

/datum/unit_test/lich_ritual_roster_coverage

/datum/unit_test/lich_ritual_roster_coverage/Run()
	// 7 = LICH_MAX_POTENCY (voidcrew/_DEFINES/lich.dm). Unit-test files compile
	// before voidcrew/_DEFINES, so the fork defines are not available here.
	var/max_potency = 7

	var/list/roster = list()
	for(var/datum/round_event_control/voidcrew/lich/control_type as anything in subtypesof(/datum/round_event_control/voidcrew/lich))
		var/event_type = initial(control_type.typepath)
		if(!event_type)
			continue // abstract base; SSevents drops controls with no typepath
		if(!ispath(event_type, /datum/round_event/voidcrew/lich))
			TEST_FAIL("[control_type] has typepath [event_type], which is not a /datum/round_event/voidcrew/lich subtype")
			continue
		if(!initial(control_type.wizardevent))
			TEST_FAIL("[control_type] is not flagged wizardevent. That flag is the only thing keeping the ritual roster out of SSdynamic_events' ambient rolls — without it this curse lands on crews in rounds that have no lich.")
		var/low = initial(control_type.min_wizard_trigger_potency)
		var/high = initial(control_type.max_wizard_trigger_potency)
		if(low > high)
			TEST_FAIL("[control_type] has min_wizard_trigger_potency [low] above max [high], so matches_potency() is false at every potency and it can never fire")
		if(high > max_potency)
			TEST_FAIL("[control_type] tops out at potency [high], above the ramp's ceiling of [max_potency] — that slice of its band is unreachable")
		roster += control_type
	TEST_ASSERT(length(roster) >= 10, "only [length(roster)] lich ritual events are registered — expected the full roster")

	for(var/potency in 1 to max_potency)
		var/in_band = 0
		var/repeatable_in_band = 0
		for(var/datum/round_event_control/voidcrew/lich/control_type as anything in roster)
			if(initial(control_type.min_wizard_trigger_potency) > potency)
				continue
			if(initial(control_type.max_wizard_trigger_potency) < potency)
				continue
			in_band++
			if(initial(control_type.max_occurrences) > 1)
				repeatable_in_band++
		if(!in_band)
			TEST_FAIL("no lich ritual event is eligible at potency [potency] — get_ritual_roster() comes back empty and that beat of the ramp fires nothing at all")
		if(potency != max_potency)
			continue
		if(repeatable_in_band < 2)
			TEST_FAIL("only [repeatable_in_band] repeatable event(s) sit at potency [max_potency]. The ritual clock plateaus there for the rest of the round, so the top band needs more than one answer that can fire again (see the cap policy in lich_events.dm — the fix is a new repeatable ship-scoped event or a band widened upward, never a raised cap on a one-shot).")
