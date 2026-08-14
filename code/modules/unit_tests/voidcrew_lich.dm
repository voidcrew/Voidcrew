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
			TEST_FAIL("[control_type] is not flagged wizardevent. That flag is the only thing keeping the ritual roster out of SSdynamic_events' ambient rolls, without it this curse lands on crews in rounds that have no lich.")
		var/low = initial(control_type.min_wizard_trigger_potency)
		var/high = initial(control_type.max_wizard_trigger_potency)
		if(low > high)
			TEST_FAIL("[control_type] has min_wizard_trigger_potency [low] above max [high], so matches_potency() is false at every potency and it can never fire")
		if(high > max_potency)
			TEST_FAIL("[control_type] tops out at potency [high], above the ramp's ceiling of [max_potency], that slice of its band is unreachable")
		roster += control_type
	// A smoke check that the roster registered at all, not a content target. It sat at >= 10
	// while the roster had exactly 10 concrete controls, which made every deliberate cut a
	// test failure; the band-coverage and top-band checks below are what actually police the
	// ramp. Raise this only if the floor is genuinely meaningful.
	TEST_ASSERT(length(roster) >= 8, "only [length(roster)] lich ritual events registered. The roster is not being built")

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
			TEST_FAIL("no lich ritual event is eligible at potency [potency], get_ritual_roster() comes back empty and that beat of the ramp fires nothing at all")
		if(potency != max_potency)
			continue
		if(repeatable_in_band < 2)
			TEST_FAIL("only [repeatable_in_band] repeatable event(s) sit at potency [max_potency]. The ritual clock plateaus there for the rest of the round, so the top band needs more than one answer that can fire again (see the cap policy in lich_events.dm. The fix is a new repeatable ship-scoped event or a band widened upward, never a raised cap on a one-shot).")

/**
 * # Ilthuun's Babel is lifted by his own timer or his death, and nobody else's
 *
 * Tongues of the Dead does its damage through a global controller that sits in
 * GLOB.tower_of_babel until something destroys it, rather than resolving inside
 * its own start(). Two things destroy it: the event's end() when its two minutes
 * are up, and on_lich_slain() if the raid lands sooner. Both go through
 * end_lich_babel() (rule 2, lich_events.dm: a rite that is over should be over).
 * Three ways that silently rots:
 *
 * - The cure stops emptying GLOB.tower_of_babel. Nothing throws: the galaxy just
 *   stays mute for the rest of the round and only an admin verb fixes it.
 * - The istype() narrows to the wrong type, or is dropped for a truthiness check.
 *   Then the rite expiring, or the lich dying, also wipes an admin's own Tower of
 *   Babel out from under them, which nobody would connect to either.
 * - end_when goes back to 0. The rite reverts to lasting the whole round, and
 *   because its can_spawn_event() refuses to run while GLOB.tower_of_babel is
 *   occupied, its max_occurrences > 1 quietly stops meaning anything: it fires
 *   once and never again, with no cap ever reached and nothing logged.
 *
 * All three are checked against a datum in the global slot or against initial()
 * values, never a live lair, so this test spawns nothing and needs no overmap.
 */
/datum/unit_test/lich_babel_cure

/datum/unit_test/lich_babel_cure/Run()
	var/datum/tower_of_babel/preexisting = GLOB.tower_of_babel
	GLOB.tower_of_babel = null

	// His: the cure path must clear it.
	GLOB.tower_of_babel = new /datum/tower_of_babel/lich
	end_lich_babel()
	TEST_ASSERT(isnull(GLOB.tower_of_babel), "end_lich_babel() left GLOB.tower_of_babel populated. The curse survives the lich, and can_spawn_event() will keep refusing a future instance")

	// Somebody else's: the cure path must not touch it.
	var/datum/tower_of_babel/admin_cast = new /datum/tower_of_babel
	GLOB.tower_of_babel = admin_cast
	end_lich_babel()
	TEST_ASSERT_EQUAL(GLOB.tower_of_babel, admin_cast, "end_lich_babel() destroyed a non-lich Tower of Babel. The global slot is shared with upstream's wizard event and the admin verb, and killing the lich must not undo either")
	QDEL_NULL(GLOB.tower_of_babel)

	GLOB.tower_of_babel = preexisting

	// The cap and the timer are one mechanism, not two settings.
	var/datum/round_event/voidcrew/lich/tongues_of_the_dead/rite = /datum/round_event/voidcrew/lich/tongues_of_the_dead
	var/datum/round_event_control/voidcrew/lich/tongues_of_the_dead/rite_control = /datum/round_event_control/voidcrew/lich/tongues_of_the_dead
	if(initial(rite_control.max_occurrences) > 1)
		TEST_ASSERT(initial(rite.end_when) > 0, "Tongues of the Dead is capped at [initial(rite_control.max_occurrences)] firings but has end_when = 0, so the curse never lifts on its own. Its can_spawn_event() refuses to run while GLOB.tower_of_babel is occupied, so it will fire exactly once and the cap becomes decorative. Either restore end_when or drop max_occurrences to 1.")
