/**
 * # Cyberware framework conformance
 *
 * Live-mob tests for the chrome load system (voidcrew/modules/cyberware/):
 * the netted capacity gate, the install-context gate, the all-or-nothing
 * over-cap brownout, the one-hardware-slot-per-arm invariant, and the
 * Second Wind Bladder's breath interception.
 *
 * NOTE: unit-test files compile before voidcrew/_DEFINES/, so every fork
 * define is written as a literal with a comment naming it —
 * CYBERWARE_BASE_CAPACITY is 20 everywhere below.
 *
 * Insert(special = TRUE) bypasses both gates by design (init/admin), which
 * is also how these tests stage bodies into known-loaded states; the
 * brownout monitor still counts special installs, so staging a body over
 * capacity is itself the brownout fixture.
 */

// Test-only chrome. Slots are invented so nothing collides with live ware.
/obj/item/organ/cyberimp/cyberware/test_full_body
	name = "test bulk chrome"
	zone = BODY_ZONE_CHEST
	slot = "voidcrew_test_chrome_bulk"
	chrome_load = 20 // exactly CYBERWARE_BASE_CAPACITY

/obj/item/organ/cyberimp/cyberware/test_small
	name = "test trinket chrome"
	zone = BODY_ZONE_CHEST
	slot = "voidcrew_test_chrome_small"
	chrome_load = 1

/obj/item/organ/cyberimp/cyberware/test_ladder_low
	name = "test ladder chrome mk1"
	zone = BODY_ZONE_CHEST
	slot = "voidcrew_test_chrome_ladder"
	chrome_load = 18

/obj/item/organ/cyberimp/cyberware/test_ladder_high
	name = "test ladder chrome mk2"
	zone = BODY_ZONE_CHEST
	slot = "voidcrew_test_chrome_ladder"
	chrome_load = 20 // fits ONLY because the mk1 nets out

/obj/item/organ/cyberimp/cyberware/test_heavy
	name = "test heavy chrome"
	zone = BODY_ZONE_CHEST
	slot = "voidcrew_test_chrome_heavy"
	chrome_load = 15

/obj/item/organ/cyberimp/cyberware/test_overflow
	name = "test overflow chrome"
	zone = BODY_ZONE_CHEST
	slot = "voidcrew_test_chrome_overflow"
	chrome_load = 10

/// (a) + (b): the insert gates — context, over-cap refusal with the organ
/// surviving, and same-slot netting letting a ladder upgrade through at cap.
/datum/unit_test/voidcrew_cyberware_capacity

/datum/unit_test/voidcrew_cyberware_capacity/Run()
	var/mob/living/carbon/human/lab_rat = allocate(/mob/living/carbon/human/consistent)

	// Context gate: no surgery, no Cradle, no special — the insert refuses
	// even though the body is empty of chrome.
	var/obj/item/organ/cyberimp/cyberware/test_small/no_context = allocate(/obj/item/organ/cyberimp/cyberware/test_small)
	TEST_ASSERT(!no_context.Insert(lab_rat), "Cyberware Insert() succeeded without an install context — the autosurgeon gate is open")
	TEST_ASSERT(!no_context.owner, "A context-refused insert still ended up owned")
	TEST_ASSERT(!QDELETED(no_context), "A context-refused insert deleted the organ")

	// With a context granted, the same insert goes through.
	var/datum/component/cyberware/no_context_chrome = no_context.GetComponent(/datum/component/cyberware)
	no_context_chrome.grant_install_context(lab_rat)
	TEST_ASSERT(no_context.Insert(lab_rat), "Cyberware Insert() refused despite a granted install context and free capacity")
	TEST_ASSERT_EQUAL(no_context.owner, lab_rat, "Context-approved insert didn't take")
	no_context.Remove(lab_rat, special = TRUE)
	no_context.forceMove(run_loc_floor_bottom_left)

	// (a) Fill the body to exactly capacity (20), then try one more point.
	var/obj/item/organ/cyberimp/cyberware/test_full_body/bulk = allocate(/obj/item/organ/cyberimp/cyberware/test_full_body)
	TEST_ASSERT(bulk.Insert(lab_rat, special = TRUE), "special = TRUE staging insert was refused")
	TEST_ASSERT_EQUAL(get_chrome_load(lab_rat), 20, "Chrome load didn't sum to the staged 20")

	var/obj/item/organ/cyberimp/cyberware/test_small/overflow = allocate(/obj/item/organ/cyberimp/cyberware/test_small)
	var/datum/component/cyberware/overflow_chrome = overflow.GetComponent(/datum/component/cyberware)
	overflow_chrome.grant_install_context(lab_rat)
	TEST_ASSERT(!overflow.Insert(lab_rat), "Insert over capacity was allowed")
	TEST_ASSERT(!overflow.owner, "An over-cap-refused insert still ended up owned")
	TEST_ASSERT(!QDELETED(overflow), "An over-cap-refused insert deleted the organ — autosurgeons would eat it")
	TEST_ASSERT_EQUAL(get_chrome_load(lab_rat), 20, "A refused insert changed the body's chrome load")

	// (b) Same-slot netting: swap the bulk ware for the ladder pair. An
	// 18-load incumbent nets out, so a 20-load upgrade fits a 20-cap body.
	bulk.Remove(lab_rat, special = TRUE)
	bulk.forceMove(run_loc_floor_bottom_left)
	var/obj/item/organ/cyberimp/cyberware/test_ladder_low/rung_one = allocate(/obj/item/organ/cyberimp/cyberware/test_ladder_low)
	TEST_ASSERT(rung_one.Insert(lab_rat, special = TRUE), "Ladder rung one staging insert was refused")

	var/obj/item/organ/cyberimp/cyberware/test_ladder_high/rung_two = allocate(/obj/item/organ/cyberimp/cyberware/test_ladder_high)
	var/datum/component/cyberware/rung_two_chrome = rung_two.GetComponent(/datum/component/cyberware)
	TEST_ASSERT(cyberware_insert_check(rung_two, lab_rat, silent = TRUE), "The netted capacity check refused a same-slot upgrade that should fit")
	rung_two_chrome.grant_install_context(lab_rat)
	TEST_ASSERT(rung_two.Insert(lab_rat), "Same-slot ladder upgrade at capacity was refused — netting is broken")
	TEST_ASSERT_EQUAL(rung_two.owner, lab_rat, "Ladder upgrade didn't take")
	TEST_ASSERT(!rung_one.owner, "The evicted incumbent is somehow still installed")
	TEST_ASSERT_EQUAL(get_chrome_load(lab_rat), 20, "Post-upgrade load isn't the new rung's 20")
	TEST_ASSERT(!(rung_two.organ_flags & ORGAN_FAILING), "At-capacity (not over) chrome browned out")

/// (c) Over-cap brownout: force a body over capacity with special inserts
/// (the same state removing a Governor mid-build produces), watch ALL chrome
/// flip to ORGAN_FAILING, then recover the moment load drops back under.
/datum/unit_test/voidcrew_cyberware_brownout

/datum/unit_test/voidcrew_cyberware_brownout/Run()
	var/mob/living/carbon/human/lab_rat = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/test_heavy/heavy = allocate(/obj/item/organ/cyberimp/cyberware/test_heavy)
	var/obj/item/organ/cyberimp/cyberware/test_overflow/overflow = allocate(/obj/item/organ/cyberimp/cyberware/test_overflow)

	TEST_ASSERT(heavy.Insert(lab_rat, special = TRUE), "Heavy staging insert was refused")
	TEST_ASSERT(!(heavy.organ_flags & ORGAN_FAILING), "Chrome under capacity is failing")

	// 15 + 10 = 25 > 20 (CYBERWARE_BASE_CAPACITY): everything browns out.
	TEST_ASSERT(overflow.Insert(lab_rat, special = TRUE), "Overflow staging insert was refused — special must bypass the gate")
	TEST_ASSERT(get_chrome_load(lab_rat) > get_chrome_capacity(lab_rat), "Test body isn't actually over capacity")
	TEST_ASSERT(heavy.organ_flags & ORGAN_FAILING, "Over capacity, but the first ware didn't brown out")
	TEST_ASSERT(overflow.organ_flags & ORGAN_FAILING, "Over capacity, but the second ware didn't brown out — brownout must hit ALL chrome")

	// Removal is never blocked and IS the fix.
	overflow.Remove(lab_rat)
	overflow.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(!(heavy.organ_flags & ORGAN_FAILING), "Load dropped back under capacity but the remaining ware is still browned out")
	TEST_ASSERT(!(overflow.organ_flags & ORGAN_FAILING), "Removed ware kept its brownout outside the body")

/// (d) One-hardware-per-arm: every piece of arm-zone chrome must claim that
/// arm's ONE hardware slot (tg's ARM_AUG), so knuckles, myomer lattices,
/// blades and launchers can never stack on the same arm — a new install
/// evicts the incumbent instead. Gecko Grip is the deliberate exception:
/// palm-surface pads, not arm chassis, on its own slot.
/datum/unit_test/voidcrew_cyberware_arm_slots

/datum/unit_test/voidcrew_cyberware_arm_slots/Run()
	var/list/exempt = list(/obj/item/organ/cyberimp/cyberware/gecko)
	var/list/arm_ware = typesof(/obj/item/organ/cyberimp/cyberware) + typesof(/obj/item/organ/cyberimp/arm/toolkit/cyberware)
	for(var/organ_path in arm_ware)
		if(organ_path in exempt)
			continue
		var/obj/item/organ/ware = organ_path
		switch(initial(ware.zone))
			if(BODY_ZONE_R_ARM)
				TEST_ASSERT_EQUAL(initial(ware.slot), ORGAN_SLOT_RIGHT_ARM_AUG, "[organ_path] is right-arm chrome off the arm hardware slot — it would stack with blades/launchers on the same arm")
			if(BODY_ZONE_L_ARM)
				TEST_ASSERT_EQUAL(initial(ware.slot), ORGAN_SLOT_LEFT_ARM_AUG, "[organ_path] is left-arm chrome off the arm hardware slot — it would stack with blades/launchers on the same arm")

/// (e) Second Wind Bladder: blocks suffocation while reserve lasts, runs
/// dry, and refills in breathable air. Nullspace stands in for hard vacuum —
/// breathe() sees no environment either way.
/datum/unit_test/voidcrew_cyberware_second_wind

/datum/unit_test/voidcrew_cyberware_second_wind/Run()
	var/mob/living/carbon/human/lab_rat = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/second_wind/bladder = allocate(/obj/item/organ/cyberimp/cyberware/second_wind)
	TEST_ASSERT(bladder.Insert(lab_rat, special = TRUE), "Second Wind staging insert was refused")

	var/full_reserve = bladder.reserve
	TEST_ASSERT(full_reserve > 0, "Second Wind spawned with an empty reserve")

	lab_rat.moveToNullspace()
	lab_rat.breathe(seconds_per_tick = 2, times_fired = 1)
	TEST_ASSERT(!lab_rat.failed_last_breath, "Second Wind didn't block a breath in vacuum — the bearer suffocated with a full reserve")
	TEST_ASSERT_EQUAL(lab_rat.getOxyLoss(), 0, "Second Wind blocked the breath but the bearer still took oxygen damage")
	TEST_ASSERT(bladder.reserve < full_reserve, "A blocked breath spent no reserve")
	TEST_ASSERT(bladder.engaged, "Second Wind fed a breath without registering as engaged")

	var/after_one_breath = bladder.reserve
	lab_rat.breathe(seconds_per_tick = 2, times_fired = 1)
	TEST_ASSERT(bladder.reserve < after_one_breath, "A second blocked breath spent no reserve")

	// Run the reserve dry: the next breath must fail for real.
	bladder.reserve = 0
	lab_rat.breathe(seconds_per_tick = 2, times_fired = 1)
	TEST_ASSERT(lab_rat.failed_last_breath || lab_rat.getOxyLoss() > 0, "Reserve empty in vacuum, but the bearer still isn't suffocating")

	// Back in the test room's air the reserve climbs again.
	lab_rat.forceMove(run_loc_floor_bottom_left)
	lab_rat.breathe(seconds_per_tick = 2, times_fired = 1)
	TEST_ASSERT(bladder.reserve > 0, "A breath of good air refilled no reserve")
	TEST_ASSERT(!bladder.engaged, "Second Wind stayed engaged in breathable air")
