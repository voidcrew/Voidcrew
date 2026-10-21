/**
 * # Cyberware framework conformance
 *
 * Live-mob tests for the chrome load system (voidcrew/modules/cyberware/):
 * the netted capacity gate, the install-context gate, the all-or-nothing
 * over-cap brownout, the one-hardware-slot-per-arm invariant, the Second Wind
 * Bladder's breath interception, chrome surviving a body-destroying death, the
 * EMP counter (a pulse reaching installed chrome, offline chrome dropping its
 * passives, and the Voltaic cyberheart's one-pulse absorb), and the Chrome
 * Cradle console. Its rack grouping, load projection and body preview, all of
 * which the interface reads straight out of ui_data() and none of which errors
 * when it goes wrong.
 *
 * NOTE: unit-test files compile before voidcrew/_DEFINES/, so every fork
 * define is written as a literal with a comment naming it,
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

// A later insertion gate refusing after the Cradle's projected check passed.
/obj/item/organ/cyberimp/cyberware/test_ladder_high/refused/Insert(mob/living/carbon/receiver, special = FALSE, movement_flags)
	if(!special)
		return FALSE
	return ..()

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

// Arm-zone chrome, for the severed-limb half of the salvage test. It has to
// claim the real arm hardware slot or test (d) below fails it like any other
// piece of arm chrome.
/obj/item/organ/cyberimp/cyberware/test_arm
	name = "test arm chrome"
	zone = BODY_ZONE_L_ARM
	slot = ORGAN_SLOT_LEFT_ARM_AUG
	chrome_load = 1

/// (a) + (b): the insert gates. Context, over-cap refusal with the organ
/// surviving, and same-slot netting letting a ladder upgrade through at cap.
/datum/unit_test/voidcrew_cyberware_capacity

/datum/unit_test/voidcrew_cyberware_capacity/Run()
	var/mob/living/carbon/human/lab_rat = allocate(/mob/living/carbon/human/consistent)

	// Context gate: no surgery, no Cradle, no special, the insert refuses
	// even though the body is empty of chrome.
	var/obj/item/organ/cyberimp/cyberware/test_small/no_context = allocate(/obj/item/organ/cyberimp/cyberware/test_small)
	TEST_ASSERT(!no_context.Insert(lab_rat), "Cyberware Insert() succeeded without an install context. The autosurgeon gate is open")
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
	TEST_ASSERT(!QDELETED(overflow), "An over-cap-refused insert deleted the organ. Autosurgeons would eat it")
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
	TEST_ASSERT(rung_two.Insert(lab_rat), "Same-slot ladder upgrade at capacity was refused, netting is broken")
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
	TEST_ASSERT(overflow.Insert(lab_rat, special = TRUE), "Overflow staging insert was refused. Special must bypass the gate")
	TEST_ASSERT(get_chrome_load(lab_rat) > get_chrome_capacity(lab_rat), "Test body isn't actually over capacity")
	TEST_ASSERT(heavy.organ_flags & ORGAN_FAILING, "Over capacity, but the first ware didn't brown out")
	TEST_ASSERT(overflow.organ_flags & ORGAN_FAILING, "Over capacity, but the second ware didn't brown out. Brownout must hit ALL chrome")

	// Removal is never blocked and IS the fix.
	overflow.Remove(lab_rat)
	overflow.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(!(heavy.organ_flags & ORGAN_FAILING), "Load dropped back under capacity but the remaining ware is still browned out")
	TEST_ASSERT(!(overflow.organ_flags & ORGAN_FAILING), "Removed ware kept its brownout outside the body")

/// (d) One-hardware-per-arm: every piece of arm-zone chrome must claim that
/// arm's ONE hardware slot (tg's ARM_AUG), so knuckles, myomer lattices,
/// blades and launchers can never stack on the same arm, a new install
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
				TEST_ASSERT_EQUAL(initial(ware.slot), ORGAN_SLOT_RIGHT_ARM_AUG, "[organ_path] is right-arm chrome off the arm hardware slot. It would stack with blades/launchers on the same arm")
			if(BODY_ZONE_L_ARM)
				TEST_ASSERT_EQUAL(initial(ware.slot), ORGAN_SLOT_LEFT_ARM_AUG, "[organ_path] is left-arm chrome off the arm hardware slot. It would stack with blades/launchers on the same arm")

/// (f) Chrome read: the optics' scan resolves installed hardware by name at
/// itemized resolution, rates parlor chrome by tier and everything else
/// UNRATED, counts either way, and NEVER resolves anything flagged
/// ORGAN_HIDDEN: the Cargo Cavity's whole selling point.
/// Resolution literals are 1 = CYBERWARE_SCAN_SILHOUETTE, 2 = _ITEMIZED.
/datum/unit_test/voidcrew_cyberware_scan

/datum/unit_test/voidcrew_cyberware_scan/Run()
	var/mob/living/carbon/human/lab_rat = allocate(/mob/living/carbon/human/consistent)

	// A body of nothing but meat reads as one.
	var/blank = jointext(cyberware_scan_readout(lab_rat, 2), "\n")
	TEST_ASSERT(findtext(blank, "NO HARDWARE SIGNATURE"), "An unaugmented body didn't read as unaugmented: [blank]")

	var/obj/item/organ/eyes/robotic/cyberware/nightshade/optics = allocate(/obj/item/organ/eyes/robotic/cyberware/nightshade)
	TEST_ASSERT(optics.Insert(lab_rat, special = TRUE), "Nightshade staging insert was refused")
	var/obj/item/organ/cyberimp/cyberware/cargo_cavity/stash = allocate(/obj/item/organ/cyberimp/cyberware/cargo_cavity)
	TEST_ASSERT(stash.Insert(lab_rat, special = TRUE), "Cargo Cavity staging insert was refused")
	TEST_ASSERT(stash.organ_flags & ORGAN_HIDDEN, "The Cargo Cavity stopped being ORGAN_HIDDEN. The scan exemption is keyed to that flag")
	// A printable tg augment: robotic, but no chrome component to rate.
	var/obj/item/organ/cyberimp/chest/reviver/printable = allocate(/obj/item/organ/cyberimp/chest/reviver)
	TEST_ASSERT(printable.Insert(lab_rat, special = TRUE), "Reviver implant staging insert was refused")

	// Hidden hardware is invisible to the bus, installed or not.
	var/list/scannable = cyberware_scannable_hardware(lab_rat)
	TEST_ASSERT(optics in scannable, "Installed unhidden chrome didn't show up as scannable")
	TEST_ASSERT(printable in scannable, "A non-cyberware robotic organ didn't show up as scannable")
	TEST_ASSERT(!(stash in scannable), "ORGAN_HIDDEN chrome showed up as scannable. The Cargo Cavity is meant to be off every scanner")

	// Itemized resolution names what it found, rates chrome by tier, leaves
	// printable augments unrated, and skips what it can't see.
	var/itemized = jointext(cyberware_scan_readout(lab_rat, 2), "\n")
	TEST_ASSERT(findtext(itemized, uppertext(optics.name)), "An itemized chrome read didn't name the installed optics: [itemized]")
	TEST_ASSERT(findtext(itemized, "T1"), "An itemized chrome read didn't rate the tier 1 optics: [itemized]")
	TEST_ASSERT(findtext(itemized, "UNRATED"), "An itemized chrome read rated a printable augment as parlor chrome: [itemized]")
	TEST_ASSERT(!findtext(itemized, uppertext(stash.name)), "An itemized chrome read named the ORGAN_HIDDEN Cargo Cavity: [itemized]")
	TEST_ASSERT(findtext(itemized, "SIGNATURES 2"), "An itemized chrome read miscounted the visible signatures: [itemized]")

	// Silhouette resolution still counts and loads, but names nothing.
	var/silhouette = jointext(cyberware_scan_readout(lab_rat, 1), "\n")
	TEST_ASSERT(!findtext(silhouette, uppertext(optics.name)), "A silhouette chrome read named a ware it shouldn't resolve: [silhouette]")
	TEST_ASSERT(findtext(silhouette, "SIGNATURES 2"), "A silhouette chrome read didn't report the signature count: [silhouette]")
	TEST_ASSERT_EQUAL(initial(optics.chrome_scan_resolution), 1, "The street-tier Nightshade isn't set to silhouette resolution")

/// (e) Second Wind Bladder: blocks suffocation while reserve lasts, runs
/// dry, and refills in breathable air.
///
/// Two things about the fixture, both learned the hard way. The vacuum is a
/// real space turf at the far corner of the test zone, NOT nullspace: the
/// failed-breath path emotes, and an emote with no location runtimes inside
/// audible_message(). And breathe() is called positionally, because
/// /mob/living/carbon/human/breathe() declares no parameters of its own and
/// forwards through ..(), naming the carbon proc's arguments on a
/// human-typed var is a "bad arg name" runtime, not a call.
/datum/unit_test/voidcrew_cyberware_second_wind

/datum/unit_test/voidcrew_cyberware_second_wind/Run()
	var/mob/living/carbon/human/lab_rat = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/second_wind/bladder = allocate(/obj/item/organ/cyberimp/cyberware/second_wind)
	TEST_ASSERT(bladder.Insert(lab_rat, special = TRUE), "Second Wind staging insert was refused")

	var/full_reserve = bladder.reserve
	TEST_ASSERT(full_reserve > 0, "Second Wind spawned with an empty reserve")

	var/floor_type = run_loc_floor_top_right.type
	var/turf/vacuum = run_loc_floor_top_right.ChangeTurf(/turf/open/space)
	lab_rat.forceMove(vacuum)
	lab_rat.breathe(2, 1)
	TEST_ASSERT(!lab_rat.failed_last_breath, "Second Wind didn't block a breath in vacuum, the bearer suffocated with a full reserve")
	TEST_ASSERT_EQUAL(lab_rat.getOxyLoss(), 0, "Second Wind blocked the breath but the bearer still took oxygen damage")
	TEST_ASSERT(bladder.reserve < full_reserve, "A blocked breath spent no reserve")
	TEST_ASSERT(bladder.engaged, "Second Wind fed a breath without registering as engaged")

	var/after_one_breath = bladder.reserve
	lab_rat.breathe(2, 1)
	TEST_ASSERT(bladder.reserve < after_one_breath, "A second blocked breath spent no reserve")

	// Run the reserve dry: the next breath must fail for real.
	bladder.reserve = 0
	lab_rat.breathe(2, 1)
	TEST_ASSERT(lab_rat.failed_last_breath || lab_rat.getOxyLoss() > 0, "Reserve empty in vacuum, but the bearer still isn't suffocating")

	// Back in the test room's air the reserve climbs again.
	lab_rat.forceMove(run_loc_floor_bottom_left)
	lab_rat.breathe(2, 1)
	TEST_ASSERT(bladder.reserve > 0, "A breath of good air refilled no reserve")
	TEST_ASSERT(!bladder.engaged, "Second Wind stayed engaged in breathable air")
	vacuum.ChangeTurf(floor_type)

/// (g) The Chrome Cradle console: every reachable piece files into exactly one
/// rack group, and the highlight projects its own swap before anything commits.
/// The interface reads all of this straight out of ui_data(), so a silent
/// change of shape here is a console that renders empty with no error.
///
/// The body-preview mannequin this used to cover was cut on 2026-08-05, taking
/// /atom/movable/screen/map_view/chrome_preview, chrome_cradle.preview and
/// refresh_preview() with it. The assertions went with them; nothing else here
/// depends on that feature.
/datum/unit_test/voidcrew_cradle_console

/datum/unit_test/voidcrew_cradle_console/Run()
	var/obj/machinery/chrome_cradle/rig = allocate(/obj/machinery/chrome_cradle)
	var/mob/living/carbon/human/lab_rat = allocate(/mob/living/carbon/human/consistent)

	// An empty slab still answers, and still draws the whole body diagram.
	var/list/idle_data = rig.ui_data(lab_rat)
	TEST_ASSERT_EQUAL(length(idle_data["groups"]), length(GLOB.cyberware_ui_groups), "The rack didn't render one row per body system")

	rig.buckle_mob(lab_rat, force = TRUE)
	TEST_ASSERT_EQUAL(rig.occupant, lab_rat, "The cradle didn't take the buckled patient as its occupant")

	// One piece seated, one piece in hand: both have to reach the rack, in
	// their own groups, tagged with where they are.
	var/obj/item/organ/cyberimp/cyberware/dermal_mesh/worn = allocate(/obj/item/organ/cyberimp/cyberware/dermal_mesh)
	TEST_ASSERT(worn.Insert(lab_rat, special = TRUE), "Dermal Mesh staging insert was refused")
	var/obj/item/organ/cyberimp/cyberware/shock_coils/held = allocate(/obj/item/organ/cyberimp/cyberware/shock_coils)
	lab_rat.put_in_hands(held)
	TEST_ASSERT_EQUAL(held.loc, lab_rat, "The carried ware didn't end up on the patient")

	var/list/reachable = rig.get_reachable_ware(lab_rat)
	TEST_ASSERT_EQUAL(reachable[worn], "installed", "Installed chrome wasn't reported as installed")
	TEST_ASSERT_EQUAL(reachable[held], "carried", "Chrome in the patient's hands wasn't reported as carried")

	var/list/data = rig.ui_data(lab_rat)
	var/list/seen = list()
	for(var/list/group as anything in data["groups"])
		for(var/list/card as anything in group["ware"])
			TEST_ASSERT(!seen[card["ref"]], "[card["name"]] appears in more than one rack group")
			seen[card["ref"]] = group["id"]
			TEST_ASSERT(!isnull(card["icon"]), "[card["name"]] reached the rack with no card art key")
	TEST_ASSERT_EQUAL(length(seen), 2, "The rack didn't carry exactly the two pieces the console can reach")
	TEST_ASSERT(seen[REF(worn)] != seen[REF(held)], "Skin plating and leg pistons filed under the same body system")

	// Highlighting the carried piece projects the swap without touching the body.
	var/before_load = get_chrome_load(lab_rat)
	rig.selected_ware = held
	var/list/projection = rig.build_projection(lab_rat, "carried")
	TEST_ASSERT_EQUAL(projection["load"], before_load + 1, "The projection didn't add the highlighted piece's load")
	TEST_ASSERT_EQUAL(get_chrome_load(lab_rat), before_load, "Highlighting a piece changed the body's real load")
	TEST_ASSERT(!held.owner, "Highlighting a piece installed it")

	// Getting up clears the highlight, so nothing of one patient survives onto
	// the next.
	rig.unbuckle_mob(lab_rat, force = TRUE)
	TEST_ASSERT(isnull(rig.selected_ware), "Leaving the slab left a highlight behind")

/// (h) Splice's price index: the cradle quotes parlor prices next to the load
/// cost, and cased pairs have to resolve to their halves or a Mantis Blade
/// card comes up priceless.
/datum/unit_test/voidcrew_cradle_prices

/datum/unit_test/voidcrew_cradle_prices/Run()
	build_cyberware_price_index()

	var/list/direct = GLOB.cyberware_price_index[/obj/item/organ/cyberimp/cyberware/dermal_mesh]
	TEST_ASSERT(!isnull(direct), "A ware sold one-to-a-SKU got no price entry")
	TEST_ASSERT(direct["credits"] > 0, "Dermal Mesh indexed with no credit price")
	TEST_ASSERT(!direct["paired"], "A single-item SKU was indexed as a cased pair")

	// Both halves of a cased pair quote the case's price, flagged as a pair.
	for(var/half in list(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis, /obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left))
		var/list/paired = GLOB.cyberware_price_index[half]
		TEST_ASSERT(!isnull(paired), "[half] got no price entry, the pair case never resolved to its contents")
		TEST_ASSERT(paired["vouchers"] > 0, "[half] indexed with no voucher price")
		TEST_ASSERT(paired["paired"], "[half] came out of a pair case without the paired flag")

/// Recheck the complete final installation after the delay, before touching incumbents.
/datum/unit_test/voidcrew_cradle_installed_capacity

/datum/unit_test/voidcrew_cradle_installed_capacity/Run()
	var/obj/machinery/chrome_cradle/rig = allocate(/obj/machinery/chrome_cradle)
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	rig.buckle_mob(patient, force = TRUE)
	var/obj/item/organ/cyberimp/cyberware/test_ladder_low/incumbent = allocate(/obj/item/organ/cyberimp/cyberware/test_ladder_low)
	var/obj/item/organ/cyberimp/cyberware/test_small/extra = allocate(/obj/item/organ/cyberimp/cyberware/test_small)
	var/obj/item/organ/cyberimp/cyberware/test_ladder_high/upgrade = allocate(/obj/item/organ/cyberimp/cyberware/test_ladder_high)
	TEST_ASSERT(incumbent.Insert(patient, TRUE), "Cradle incumbent fixture failed")
	TEST_ASSERT(extra.Insert(patient, TRUE), "Cradle extra-load fixture failed")
	patient.put_in_hands(upgrade)
	rig.begin_install(upgrade)
	TEST_ASSERT(!rig.busy, "Cradle began an over-budget sequence")
	TEST_ASSERT_EQUAL(upgrade.loc, patient, "Initial refusal moved the incoming ware")
	TEST_ASSERT_EQUAL(incumbent.owner, patient, "Initial refusal evicted the incumbent")
	extra.Remove(patient, TRUE)
	rig.begin_install(upgrade)
	TEST_ASSERT(rig.busy && rig.busy_ware == upgrade, "Fitting upgrade didn't begin its sequence")
	TEST_ASSERT_EQUAL(incumbent.owner, patient, "Beginning the sequence evicted the incumbent")
	// An implanter can add load while the patient is sedated.
	var/obj/item/implant/voidcrew_capacity_test/implant = allocate(/obj/item/implant/voidcrew_capacity_test)
	TEST_ASSERT(implant.implant(patient), "Mid-sequence implantation fixture failed")
	rig.finish_install()
	TEST_ASSERT_EQUAL(incumbent.owner, patient, "Post-delay capacity refusal evicted the incumbent")
	TEST_ASSERT(!QDELETED(incumbent) && !QDELETED(upgrade), "Post-delay refusal consumed an organ")
	TEST_ASSERT(!upgrade.owner && upgrade.loc == rig && (upgrade in rig.tray), "Rejected incoming ware wasn't preserved in the tray")
	TEST_ASSERT_EQUAL(get_chrome_load(patient), 19, "Rejected sequence changed installed load")
	TEST_ASSERT(!rig.busy && !patient.IsUnconscious(), "Rejected sequence didn't clear the cycle and sedation")
	implant.removed(patient)
	// Even a refusal by a later Insert() gate must restore the old piece.
	var/obj/item/organ/cyberimp/cyberware/test_ladder_high/refused/late_refusal = allocate(/obj/item/organ/cyberimp/cyberware/test_ladder_high/refused)
	late_refusal.forceMove(rig)
	rig.begin_install(late_refusal)
	TEST_ASSERT(rig.busy, "Late-refusal fixture failed its projected check")
	rig.finish_install()
	TEST_ASSERT_EQUAL(incumbent.owner, patient, "Insertion refusal didn't restore the incumbent")
	TEST_ASSERT(!(incumbent in rig.tray), "Restored incumbent remained in the parts tray")
	TEST_ASSERT(!late_refusal.owner && late_refusal.loc == rig && (late_refusal in rig.tray), "Insertion refusal lost the incoming ware")
	TEST_ASSERT_EQUAL(get_chrome_load(patient), 18, "Rollback changed the original installed load")
	// Retry after shedding load: net the old piece out rather than summing both.
	rig.begin_install(upgrade)
	rig.finish_install()
	TEST_ASSERT_EQUAL(upgrade.owner, patient, "Fitting Cradle replacement was refused")
	TEST_ASSERT(!incumbent.owner && incumbent.loc == rig && (incumbent in rig.tray), "Successful replacement didn't rack its incumbent")
	TEST_ASSERT_EQUAL(get_chrome_load(patient), 20, "Cradle replacement didn't net the incumbent")
	upgrade.Remove(patient, TRUE)
	TEST_ASSERT(incumbent.Insert(patient, TRUE), "Governor-loss incumbent fixture failed")
	var/obj/item/organ/cyberimp/cyberware/governor_delete/governor = allocate(/obj/item/organ/cyberimp/cyberware/governor_delete)
	governor.Insert(patient, TRUE)
	implant.implant(patient)
	upgrade.forceMove(rig)
	rig.begin_install(upgrade)
	TEST_ASSERT(rig.busy, "Governor-backed replacement didn't begin")
	governor.Remove(patient, TRUE)
	rig.finish_install()
	TEST_ASSERT_EQUAL(incumbent.owner, patient, "Losing a Governor during the delay evicted the incumbent")
	TEST_ASSERT_EQUAL(get_chrome_capacity(patient), 20, "Cradle retained the removed Governor's bonus")
	TEST_ASSERT(!upgrade.owner && (upgrade in rig.tray), "Governor-loss refusal lost the incoming ware")
	// A Governor-for-Governor swap must fit the exact 35 boundary.
	implant.removed(patient)
	incumbent.Remove(patient, TRUE)
	governor.Insert(patient, TRUE)
	upgrade.Insert(patient, TRUE)
	var/obj/item/organ/cyberimp/cyberware/test_heavy/heavy = allocate(/obj/item/organ/cyberimp/cyberware/test_heavy)
	heavy.Insert(patient, TRUE)
	var/obj/item/organ/cyberimp/cyberware/governor_delete/new_governor = allocate(/obj/item/organ/cyberimp/cyberware/governor_delete)
	new_governor.forceMove(rig)
	rig.begin_install(new_governor)
	TEST_ASSERT(rig.busy, "Governor replacement at 35 failed its projected check")
	rig.finish_install()
	TEST_ASSERT_EQUAL(new_governor.owner, patient, "Cradle rejected a netted Governor replacement at 35")
	TEST_ASSERT(!governor.owner && (governor in rig.tray), "Successful Governor replacement didn't rack the old Governor")
	TEST_ASSERT_EQUAL(get_chrome_capacity(patient), 35, "Governor replacement changed capacity")
	TEST_ASSERT_EQUAL(get_chrome_load(patient), 35, "Governor replacement changed installed load")

/datum/unit_test/voidcrew_cradle_generic_projection

/datum/unit_test/voidcrew_cradle_generic_projection/Run()
	var/obj/machinery/chrome_cradle/rig = allocate(/obj/machinery/chrome_cradle)
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/test_nineteen/bulk = allocate(/obj/item/organ/cyberimp/cyberware/test_nineteen)
	var/obj/item/organ/eyes/robotic/incumbent = allocate(/obj/item/organ/eyes/robotic)
	var/obj/item/organ/eyes/robotic/cyberware/nightshade/optics = allocate(/obj/item/organ/eyes/robotic/cyberware/nightshade)
	bulk.Insert(patient, TRUE)
	incumbent.Insert(patient, TRUE)
	rig.selected_ware = optics
	var/list/projection = rig.build_projection(patient, "carried")
	TEST_ASSERT_EQUAL(projection["load"], 20, "Cradle projection didn't net out generic robotic eyes")
	TEST_ASSERT_EQUAL(get_chrome_load(patient), 20, "Building a Cradle projection changed the body")

/// (i) Gecko Grips: the clamp is a refusal of the involuntary drop itself, so
/// what it does and does not refuse is the whole ware. Everything below is a
/// real drop attempt rather than a state check, because the failure this
/// replaced looked entirely correct in state and did nothing in play.
/datum/unit_test/voidcrew_cyberware_gecko

/datum/unit_test/voidcrew_cyberware_gecko/Run()
	var/mob/living/carbon/human/lab_rat = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/gecko/pads = allocate(/obj/item/organ/cyberimp/cyberware/gecko)
	TEST_ASSERT(pads.Insert(lab_rat, special = TRUE), "Gecko Grip staging insert was refused")

	// Tables read as flat ground for as long as the pads are in.
	TEST_ASSERT(lab_rat.pass_flags & PASSTABLE, "Gecko Grips didn't make their bearer able to cross tables")

	var/obj/item/bar = allocate(/obj/item/crowbar)
	lab_rat.put_in_hands(bar)
	TEST_ASSERT(lab_rat.is_holding(bar), "Test fixture never got the crowbar into a hand")

	// Nothing wrong with them: an ordinary drop is an ordinary drop.
	TEST_ASSERT(lab_rat.dropItemToGround(bar), "The grips blocked a voluntary drop by an upright bearer")
	lab_rat.put_in_hands(bar)

	// Stunned: this is the one the ware is sold on.
	lab_rat.Stun(5 SECONDS)
	TEST_ASSERT(HAS_TRAIT(lab_rat, TRAIT_HANDS_BLOCKED), "Test fixture: the stun didn't block hands, so nothing was being tested")
	TEST_ASSERT(lab_rat.is_holding(bar), "A stun stripped the crowbar out of gecko-gripped hands")
	TEST_ASSERT(!lab_rat.dropItemToGround(bar), "A downed bearer's grip let go of the crowbar")
	// Forced removal always wins: admin work and gibbing must not be blocked.
	TEST_ASSERT(lab_rat.dropItemToGround(bar, force = TRUE), "A FORCED unequip was blocked by the grips")

	// Cuffs beat chrome: hands blocked by restraints ALONE still open. The
	// stun has to come off first. The clamp reads every source of
	// TRAIT_HANDS_BLOCKED, so a lingering stun would make this pass or fail
	// for the wrong reason.
	lab_rat.SetStun(0)
	TEST_ASSERT(!HAS_TRAIT(lab_rat, TRAIT_HANDS_BLOCKED), "Test fixture: the stun didn't lift, so the restraint case would be testing the stun")
	lab_rat.put_in_hands(bar)
	ADD_TRAIT(lab_rat, TRAIT_HANDS_BLOCKED, TRAIT_RESTRAINED)
	TEST_ASSERT(!pads.hands_blocked_by_trauma(), "Restraints read as trauma. The grips would beat handcuffs")
	TEST_ASSERT(lab_rat.dropItemToGround(bar), "The grips held on against restraints")
	REMOVE_TRAIT(lab_rat, TRAIT_HANDS_BLOCKED, TRAIT_RESTRAINED)

	// A corpse stays lootable.
	lab_rat.put_in_hands(bar)
	lab_rat.set_stat(DEAD)
	TEST_ASSERT(!pads.hands_blocked_by_trauma(), "A dead bearer's grips still counted as clamped")
	TEST_ASSERT(lab_rat.dropItemToGround(bar), "A corpse's grips wouldn't give up the crowbar")

	// Out of the body, the passive goes with it.
	pads.Remove(lab_rat, special = TRUE)
	pads.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(!(lab_rat.pass_flags & PASSTABLE), "Extracting the grips left their table-vaulting behind")

/// (j) Chromatic Dermis: the ink hangs a real filter, re-keys off the parlor's
/// stock list (and only off that list), and is reachable through the shared
/// pulse bus every other piece of chrome calls it on. Slot literal is
/// ORGAN_SLOT_CYBERWARE_INK.
/datum/unit_test/voidcrew_cyberware_ink

/datum/unit_test/voidcrew_cyberware_ink/Run()
	var/mob/living/carbon/human/lab_rat = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/chromatic_dermis/ink = allocate(/obj/item/organ/cyberimp/cyberware/chromatic_dermis)
	TEST_ASSERT(ink.Insert(lab_rat, special = TRUE), "Chromatic Dermis staging insert was refused")
	TEST_ASSERT(!isnull(lab_rat.get_filter(ink.filter_name)), "The ink hung no outline filter on its bearer")

	// The bus every other ware pulses through has to find it by slot.
	TEST_ASSERT_EQUAL(lab_rat.get_organ_slot("cyberware_ink"), ink, "The ink suite isn't in the slot cyberware_ink_pulse() looks up")

	// Re-keying: stock pigments and stock patterns, applied on the spot.
	TEST_ASSERT(ink.set_ink(lab_rat, "Splice Magenta", "hex weave"), "set_ink refused a stock swatch and pattern")
	TEST_ASSERT_EQUAL(ink.tattoo_color, GLOB.cyberware_ink_palette["Splice Magenta"], "The swatch didn't take")
	TEST_ASSERT_EQUAL(ink.tattoo_pattern, "hex weave", "The pattern didn't take")
	TEST_ASSERT(!isnull(lab_rat.get_filter(ink.filter_name)), "A pattern change tore the filter down without rebuilding it")

	// Anything not on Splice's shelf is refused rather than written through.
	TEST_ASSERT(!ink.set_ink(lab_rat, "Not A Pigment", "not a pattern"), "set_ink accepted a colour and pattern the parlor doesn't stock")
	TEST_ASSERT_EQUAL(ink.tattoo_pattern, "hex weave", "A refused re-key still changed the pattern")

	// And nobody but the bearer gets to re-key their skin.
	var/mob/living/carbon/human/bystander = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(!ink.set_ink(bystander, "Ion Blue", null), "Someone else's ink answered a stranger")

/// (k) The ink bus: chrome that does something visible has to SAY so through
/// cyberware_ink_pulse(), or the Chromatic Dermis goes back to being a piece of
/// jewellery that ignores the rest of the body.
///
/// A pulse is a client-side filter animation with nothing to read back, so the
/// dermis counts its own pulses and remembers the last strength; that counter is
/// what this hangs off. Every case below drives the REAL activation path rather
/// than calling pulse(), an unwired call site is exactly the failure this
/// exists to catch, and it looks perfect from the ink's side.
///
/// Strength literals: 1 = CYBERWARE_INK_SOFT, 2 = _HARD, 3 = _FLARE.
/datum/unit_test/voidcrew_cyberware_ink_bus

/datum/unit_test/voidcrew_cyberware_ink_bus/Run()
	var/mob/living/carbon/human/lab_rat = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/chromatic_dermis/ink = allocate(/obj/item/organ/cyberimp/cyberware/chromatic_dermis)
	TEST_ASSERT(ink.Insert(lab_rat, special = TRUE), "Chromatic Dermis staging insert was refused")
	TEST_ASSERT_EQUAL(ink.pulse_count, 0, "The ink pulsed before anything on the body had activated")

	// The bus itself: an arbitrary caller reaches the ink by slot, at the
	// strength it asked for. This is the one line every other ware calls.
	cyberware_ink_pulse(lab_rat, 3)
	TEST_ASSERT_EQUAL(ink.pulse_count, 1, "cyberware_ink_pulse() didn't reach the installed ink")
	TEST_ASSERT_EQUAL(ink.last_pulse_strength, 3, "The bus dropped the strength it was called with")

	// (1) The shared cooldown-action bridge, every chrome ability button.
	// PreActivate() is the funnel a real click reaches through
	// InterceptClickOn(); Trigger() on a click_to_activate ability only arms
	// the cursor and needs a client, so it is deliberately not what we call.
	var/obj/item/organ/eyes/robotic/cyberware/nightshade/optics = allocate(/obj/item/organ/eyes/robotic/cyberware/nightshade)
	TEST_ASSERT(optics.Insert(lab_rat, special = TRUE), "Nightshade staging insert was refused")
	var/datum/action/cooldown/cyberware/chrome_read/read = locate(/datum/action/cooldown/cyberware/chrome_read) in lab_rat.actions
	TEST_ASSERT(!isnull(read), "The optics never granted their chrome read action to the body")
	TEST_ASSERT(!lab_rat.is_blind(), "Test fixture: the staged optics left the body blind, so the read could never run")

	var/before = ink.pulse_count
	TEST_ASSERT(read.PreActivate(lab_rat), "The chrome read didn't run against its own bearer")
	TEST_ASSERT(ink.pulse_count > before, "A chrome ability fired and the ink never answered. The cooldown-action bridge is unwired")
	TEST_ASSERT_EQUAL(ink.last_pulse_strength, 2, "A chrome ability pulsed the ink at the wrong strength")

	// (2) Deployable arm hardware. Rockjaw stands in for the whole toolkit-arm
	// family (Fixer's Fingers, blades, launchers), they all share the base's
	// Extend/Retract override, so one wired arm is all of them.
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw/fist = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw)
	TEST_ASSERT(fist.Insert(lab_rat, special = TRUE), "Rockjaw staging insert was refused")
	var/obj/item/drill = locate(/obj/item/pickaxe/drill/cyberware) in fist
	TEST_ASSERT(!isnull(drill), "Test fixture: the Rockjaw minted no drill to deploy")

	before = ink.pulse_count
	fist.Extend(drill)
	TEST_ASSERT(lab_rat.is_holding(drill), "Test fixture: the drill never made it into a hand, so nothing was deployed")
	TEST_ASSERT(ink.pulse_count > before, "Arm hardware deployed and the ink never answered")
	TEST_ASSERT_EQUAL(ink.last_pulse_strength, 2, "A deployed arm pulsed the ink at the wrong strength")

	before = ink.pulse_count
	TEST_ASSERT(fist.Retract(), "Test fixture: the drill wouldn't stow again")
	TEST_ASSERT(ink.pulse_count > before, "Arm hardware stowed and the ink never answered")
	TEST_ASSERT_EQUAL(ink.last_pulse_strength, 1, "A stowed arm pulsed the ink at the wrong strength")

	// (3) Organ action buttons that aren't abilities at all, the Cargo
	// Cavity's ui_action_click, which no signal covers.
	var/obj/item/organ/cyberimp/cyberware/cargo_cavity/cavity = allocate(/obj/item/organ/cyberimp/cyberware/cargo_cavity)
	TEST_ASSERT(cavity.Insert(lab_rat, special = TRUE), "Cargo Cavity staging insert was refused")
	var/obj/item/contraband = allocate(/obj/item/screwdriver)
	lab_rat.put_in_active_hand(contraband)
	TEST_ASSERT(lab_rat.is_holding(contraband), "Test fixture: nothing in hand to stash")

	before = ink.pulse_count
	cavity.ui_action_click()
	TEST_ASSERT_EQUAL(cavity.stashed, contraband, "Test fixture: the cavity didn't swallow the screwdriver")
	TEST_ASSERT(ink.pulse_count > before, "The Cargo Cavity swallowed something and the ink never answered")

	before = ink.pulse_count
	cavity.ui_action_click()
	TEST_ASSERT(isnull(cavity.stashed), "Test fixture: the cavity didn't hand the screwdriver back")
	TEST_ASSERT(ink.pulse_count > before, "The Cargo Cavity ejected something and the ink never answered")

	// Every ware calls the bus unconditionally, so it has to be a no-op on a
	// body with no ink in it rather than a runtime in the middle of a punch.
	var/mob/living/carbon/human/meat = allocate(/mob/living/carbon/human/consistent)
	cyberware_ink_pulse(meat, 2)

	// Ink that has browned out or been EMP-scrambled stays dark, however loud
	// the rest of the body gets.
	ink.organ_flags |= ORGAN_FAILING
	before = ink.pulse_count
	cyberware_ink_pulse(lab_rat, 3)
	TEST_ASSERT_EQUAL(ink.pulse_count, before, "Offline ink still lit up")
	ink.organ_flags &= ~ORGAN_FAILING

/// (l) Surgical reach: every piece of chrome has to sit in a body zone that
/// some organ-manipulation surgery can actually open, or the only way to wear
/// it is a Chrome Cradle at a ripperdoc parlor.
///
/// This is not hypothetical. All three pieces of leg chrome shipped in
/// BODY_ZONE_L_LEG, and no upstream surgery has ever listed a leg in its
/// possible_locs - the insert step was unreachable and nothing anywhere said
/// so. Add a ware in a zone no surgeon can cut into and this fails instead.
/datum/unit_test/voidcrew_cyberware_surgical_reach

/datum/unit_test/voidcrew_cyberware_surgical_reach/Run()
	// The zones an INTERNAL organ-manipulation surgery can open. The external
	// "Feature manipulation" surgeries are excluded on purpose: their step only
	// accepts ORGAN_EXTERNAL organs, and no chrome is one, so counting them
	// would make an unreachable zone look covered.
	var/list/reachable = list()
	for(var/datum/surgery/organ_manipulation/procedure in GLOB.surgeries_list)
		var/takes_internal = FALSE
		for(var/step_path in procedure.steps)
			if(ispath(step_path, /datum/surgery_step/manipulate_organs/internal) || ispath(step_path, /datum/surgery_step/manipulate_organs/any))
				takes_internal = TRUE
				break
		if(!takes_internal)
			continue
		for(var/zone in procedure.possible_locs)
			reachable[zone] = TRUE

	TEST_ASSERT(reachable[BODY_ZONE_L_LEG] && reachable[BODY_ZONE_R_LEG], "No organ-manipulation surgery opens a leg. Every piece of leg chrome is Chrome Cradle-only again")

	var/list/all_ware = typesof(/obj/item/organ/cyberimp/cyberware) + typesof(/obj/item/organ/eyes/robotic/cyberware) + typesof(/obj/item/organ/cyberimp/arm/toolkit/cyberware)
	for(var/obj/item/organ/ware as anything in all_ware)
		var/zone = initial(ware.zone)
		TEST_ASSERT(reachable[zone], "[ware] lives in [zone], which no organ-manipulation surgery can open. It can never be installed by surgery")

/// (m) Chrome salvage: a body coming apart leaves its hardware on the floor.
/// Upstream, gibbing without DROP_ORGANS (which is most gib calls), dusting,
/// and destroying a severed limb all delete organs outright, which quietly
/// erased the most expensive thing a player owns and left whoever earned the
/// kill nothing to pick up. Meat organs must still follow tg's drop flags,
/// so each half of this checks both sides.
/datum/unit_test/voidcrew_cyberware_salvage

/datum/unit_test/voidcrew_cyberware_salvage/Run()
	// Gibbing with no drop flags at all, the case that deleted everything.
	var/mob/living/carbon/human/gib_rat = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/test_small/gib_ware = allocate(/obj/item/organ/cyberimp/cyberware/test_small)
	TEST_ASSERT(gib_ware.Insert(gib_rat, special = TRUE), "Test fixture: staging insert into the gib subject was refused")
	var/obj/item/organ/gib_meat = gib_rat.get_organ_slot(ORGAN_SLOT_LIVER)
	TEST_ASSERT(gib_meat, "Test fixture: the gib subject has no liver to compare chrome against")

	gib_rat.gib()
	TEST_ASSERT(!QDELETED(gib_ware), "Gibbing deleted the chrome")
	TEST_ASSERT(isnull(gib_ware.owner), "Gibbed chrome is still owned by the corpse")
	TEST_ASSERT(isturf(gib_ware.loc), "Gibbed chrome ended up in [gib_ware.loc || "nullspace"] instead of on the floor")
	TEST_ASSERT(QDELETED(gib_meat), "A flagless gib kept a meat organ. Tg's drop rules changed, not just chrome's")

	// Dusting: the body is queued for deletion, organs and all.
	var/mob/living/carbon/human/ash_rat = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/test_heavy/ash_ware = allocate(/obj/item/organ/cyberimp/cyberware/test_heavy)
	TEST_ASSERT(ash_ware.Insert(ash_rat, special = TRUE), "Test fixture: staging insert into the dust subject was refused")

	ash_rat.dust()
	TEST_ASSERT(!QDELETED(ash_ware), "Dusting deleted the chrome")
	TEST_ASSERT(isnull(ash_ware.owner), "Dusted chrome is still owned by the corpse")
	TEST_ASSERT(isturf(ash_ware.loc), "Dusted chrome ended up in [ash_ware.loc || "nullspace"] instead of on the floor")

	// A severed limb with chrome in it. drop_limb() takes the organ off the
	// mob but leaves it inside the limb, and the limb's Destroy() is what
	// used to eat it.
	var/mob/living/carbon/human/limb_rat = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/test_arm/limb_ware = allocate(/obj/item/organ/cyberimp/cyberware/test_arm)
	TEST_ASSERT(limb_ware.Insert(limb_rat, special = TRUE), "Test fixture: staging insert into the dismemberment subject was refused")
	var/obj/item/bodypart/severed = limb_rat.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT(severed, "Test fixture: the dismemberment subject has no left arm")
	TEST_ASSERT_EQUAL(limb_ware.bodypart_owner, severed, "Test fixture: the arm chrome didn't seat in the left arm")

	severed.drop_limb()
	TEST_ASSERT_EQUAL(limb_ware.bodypart_owner, severed, "A dropped limb shed its chrome instead of carrying it off")
	qdel(severed)
	TEST_ASSERT(!QDELETED(limb_ware), "Destroying a severed limb deleted the chrome inside it")
	TEST_ASSERT(isnull(limb_ware.bodypart_owner), "Chrome from a destroyed limb still points at the limb")
	TEST_ASSERT(isturf(limb_ware.loc), "Chrome from a destroyed limb ended up in [limb_ware.loc || "nullspace"] instead of on the floor")

/// (h) EMP is THE designed counter to a chromed-out body, and it has to
/// actually arrive and actually cost the wearer something. Three claims, all
/// of which shipped broken at some point:
///
/// 1. A pulse on the bearer reaches installed chrome (mob -> limb -> organ)
///    and knocks it offline.
/// 2. Offline chrome stops paying its always-on passives. Dermal Mesh stands
///    in for every ware that mixes something into the bearer's physiology.
/// 3. The Voltaic cyberheart soaks exactly ONE pulse. It used to hang a
///    permanent EMP_PROTECT_CONTENTS element on the whole mob, which deleted
///    the counter outright for anyone carrying one.
///
/// Nothing here is permanent: the tune-up hands the passives straight back,
/// which is the ripperdoc/Cradle repair path.
/datum/unit_test/voidcrew_cyberware_emp

/datum/unit_test/voidcrew_cyberware_emp/Run()
	var/mob/living/carbon/human/lab_rat = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/dermal_mesh/mesh = allocate(/obj/item/organ/cyberimp/cyberware/dermal_mesh)
	var/bare = lab_rat.physiology.armor.get_rating(MELEE)

	TEST_ASSERT(mesh.Insert(lab_rat, special = TRUE), "Test fixture: Dermal Mesh staging insert was refused")
	var/plated = lab_rat.physiology.armor.get_rating(MELEE)
	TEST_ASSERT(plated > bare, "Installed Dermal Mesh never mixed its plating into the bearer's physiology")

	lab_rat.emp_act(EMP_HEAVY)
	TEST_ASSERT(mesh.organ_flags & ORGAN_FAILING, "An EMP on the bearer never reached installed chrome")
	TEST_ASSERT_EQUAL(lab_rat.physiology.armor.get_rating(MELEE), bare, "EMP-scrambled chrome kept armoring its bearer. Offline ware must stop paying its passives")

	// The repair path, and proof the counter is a moment and not a brick.
	var/datum/component/cyberware/chrome = mesh.GetComponent(/datum/component/cyberware)
	TEST_ASSERT_NOTNULL(chrome, "Test fixture: Dermal Mesh carries no cyberware component")
	chrome.tune_up()
	TEST_ASSERT(!(mesh.organ_flags & ORGAN_FAILING), "A tune-up didn't bring the EMP'd ware back online")
	TEST_ASSERT_EQUAL(lab_rat.physiology.armor.get_rating(MELEE), plated, "Repaired chrome didn't hand its plating back")

	// Protection and notification must have distinct signals. The first pulse
	// is absorbed; the next one arrives before the one-minute recharge.
	TEST_ASSERT(COMSIG_ATOM_PRE_EMP_ACT != COMSIG_ATOM_EMP_ACT, "EMP protection collides with EMP notification")
	var/obj/item/organ/heart/cybernetic/anomalock/prebuilt/shield = allocate(/obj/item/organ/heart/cybernetic/anomalock/prebuilt)
	TEST_ASSERT_EQUAL(shield.emp_absorb_cooldown_time, 1 MINUTES, "Voltaic recharge changed")
	TEST_ASSERT(shield.Insert(lab_rat, special = TRUE), "Test fixture: Voltaic cyberheart staging insert was refused")

	lab_rat.emp_act(EMP_HEAVY)
	TEST_ASSERT(!(mesh.organ_flags & ORGAN_FAILING), "The Voltaic cyberheart didn't absorb the first pulse")
	TEST_ASSERT_EQUAL(COOLDOWN_TIMELEFT(shield, emp_absorb_cooldown), 1 MINUTES, "Absorption didn't start the one-minute recharge")

	lab_rat.emp_act(EMP_HEAVY)
	TEST_ASSERT(mesh.organ_flags & ORGAN_FAILING, "The Voltaic cyberheart ate a second pulse on drained capacitors. It must only ever cover one")
	chrome.tune_up()
	// Advance only the charge clock, without sleeping through a minute of world processing.
	shield.emp_absorb_cooldown = world.time
	lab_rat.emp_act(EMP_HEAVY)
	TEST_ASSERT(chrome.is_running(), "A recharged Voltaic heart failed to absorb another pulse")

	// Pulling the core first: a cored heart tesla-zaps the room on removal,
	// and teardown removes it.
	QDEL_NULL(shield.core)

/// Non-chrome fixtures use production installation hooks and costs.
/obj/item/organ/cyberimp/cyberware/test_nineteen
	zone = BODY_ZONE_CHEST
	slot = "voidcrew_test_chrome_bulk"
	chrome_load = 19

/obj/item/implant/voidcrew_capacity_test
	allow_multiple = TRUE

/datum/unit_test/voidcrew_installed_capacity_mixed

/datum/unit_test/voidcrew_installed_capacity_mixed/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT_EQUAL(get_chrome_load(patient), 0, "Organic anatomy costs capacity")
	var/obj/item/organ/cyberimp/cyberware/test_heavy/chrome = allocate(/obj/item/organ/cyberimp/cyberware/test_heavy)
	var/obj/item/organ/cyberimp/brain/anti_drop/implant_organ = allocate(/obj/item/organ/cyberimp/brain/anti_drop)
	var/obj/item/organ/heart/cybernetic/heart = allocate(/obj/item/organ/heart/cybernetic)
	var/obj/item/implant/voidcrew_capacity_test/implant = allocate(/obj/item/implant/voidcrew_capacity_test)
	TEST_ASSERT(chrome.Insert(patient, TRUE), "Chrome fixture failed")
	TEST_ASSERT(implant_organ.Insert(patient), "TG cyber implant failed")
	TEST_ASSERT(heart.Insert(patient), "Robotic heart failed")
	TEST_ASSERT(implant.implant(patient), "Implant fixture failed")
	var/datum/status_effect/bioware/nerves/grounded/bioware = patient.apply_status_effect(/datum/status_effect/bioware/nerves/grounded)
	TEST_ASSERT(bioware, "Bioware fixture failed")
	var/datum/component/nanites/nanites = patient.AddComponent(/datum/component/nanites)
	var/datum/nanite_program/protocol/kickstart/protocol = allocate(/datum/nanite_program/protocol/kickstart)
	protocol.activated = FALSE
	TEST_ASSERT_EQUAL(nanites.add_program(null, protocol), 1, "Protocol fixture failed") // COMPONENT_PROGRAM_INSTALLED
	TEST_ASSERT_EQUAL(get_chrome_load(patient), 20, "Mixed installed sources weren't counted exactly once")
	TEST_ASSERT(!(chrome.organ_flags & ORGAN_FAILING), "The exact 20 boundary browned out")
	var/obj/item/bodypart/arm/left/robot/arm = allocate(/obj/item/bodypart/arm/left/robot)
	TEST_ASSERT(arm.replace_limb(patient, TRUE), "Free prosthetic failed at capacity")
	TEST_ASSERT_EQUAL(get_chrome_load(patient), 20, "Prosthetic limb costs capacity")
	// Generic replacements net the incumbent before upstream can delete it.
	var/obj/item/organ/heart/cybernetic/replacement = allocate(/obj/item/organ/heart/cybernetic)
	TEST_ASSERT(replacement.Insert(patient, FALSE, DELETE_IF_REPLACED), "Netted robotic-organ replacement failed at 20")
	TEST_ASSERT(QDELETED(heart), "Successful replacement didn't follow DELETE_IF_REPLACED")
	TEST_ASSERT_EQUAL(get_chrome_load(patient), 20, "Robotic-organ replacement double-counted")
	var/obj/item/implant/voidcrew_capacity_test/refused = allocate(/obj/item/implant/voidcrew_capacity_test)
	var/atom/old_location = refused.loc
	TEST_ASSERT(!refused.implant(patient), "Over-budget implant was accepted")
	TEST_ASSERT(!QDELETED(refused) && !refused.imp_in && refused.loc == old_location, "Rejected implantation consumed or moved the item")
	var/stun_mod = patient.physiology.stun_mod
	TEST_ASSERT(!patient.apply_status_effect(/datum/status_effect/bioware/ligaments/reinforced), "Over-budget bioware was accepted")
	TEST_ASSERT_EQUAL(patient.physiology.stun_mod, stun_mod, "Rejected bioware changed physiology")
	qdel(protocol)
	TEST_ASSERT_EQUAL(get_chrome_load(patient), 19, "Program deletion didn't release capacity")
	TEST_ASSERT(refused.implant(patient), "Released capacity didn't allow implantation")
	implant.removed(patient)
	TEST_ASSERT_EQUAL(get_chrome_load(patient), 19, "Implant removal didn't release capacity")

/datum/unit_test/voidcrew_installed_capacity_rejections

/datum/unit_test/voidcrew_installed_capacity_rejections/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/test_full_body/bulk = allocate(/obj/item/organ/cyberimp/cyberware/test_full_body)
	bulk.Insert(patient, TRUE)
	var/obj/item/organ/heart/incumbent = patient.get_organ_slot(ORGAN_SLOT_HEART)
	var/obj/item/organ/heart/cybernetic/refused = allocate(/obj/item/organ/heart/cybernetic)
	var/atom/old_location = refused.loc
	TEST_ASSERT(!refused.Insert(patient, FALSE, DELETE_IF_REPLACED), "Robotic heart was installed over capacity")
	TEST_ASSERT_EQUAL(patient.get_organ_slot(ORGAN_SLOT_HEART), incumbent, "Rejected replacement removed the incumbent")
	TEST_ASSERT(!QDELETED(incumbent) && !QDELETED(refused), "Rejected replacement deleted an organ")
	TEST_ASSERT_EQUAL(refused.loc, old_location, "Rejected replacement moved the new organ")
	TEST_ASSERT(!patient.apply_status_effect(/datum/status_effect/bioware/nerves/spliced), "Bioware was applied over capacity")
	TEST_ASSERT_EQUAL(patient.physiology.stun_mod, 1, "Refused bioware ran its removal effect without applying")
	// An attached limb can carry installed organs, even though the limb itself is free.
	var/obj/item/bodypart/arm/left/robot/arm = allocate(/obj/item/bodypart/arm/left/robot)
	var/obj/item/organ/cyberimp/cyberware/test_arm/packed = allocate(/obj/item/organ/cyberimp/cyberware/test_arm)
	packed.bodypart_insert(arm)
	var/obj/item/bodypart/original_arm = patient.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT(!arm.replace_limb(patient, TRUE), "A loaded prosthetic bypassed capacity")
	TEST_ASSERT_EQUAL(patient.get_bodypart(BODY_ZONE_L_ARM), original_arm, "Rejected prosthetic replacement detached the original limb")
	TEST_ASSERT_EQUAL(packed.loc, arm, "Rejected prosthetic lost its organ")
	TEST_ASSERT(!QDELETED(arm) && !QDELETED(packed), "Rejected prosthetic replacement consumed items")
	// Net a generic robotic eye out when replacing it with chrome optics.
	bulk.Remove(patient, TRUE)
	var/obj/item/organ/cyberimp/cyberware/test_nineteen/nineteen = allocate(/obj/item/organ/cyberimp/cyberware/test_nineteen)
	nineteen.Insert(patient, TRUE)
	var/obj/item/organ/eyes/robotic/robotic_eyes = allocate(/obj/item/organ/eyes/robotic)
	TEST_ASSERT(robotic_eyes.Insert(patient), "Generic eye fixture failed")
	var/obj/item/organ/eyes/robotic/cyberware/nightshade/optics = allocate(/obj/item/organ/eyes/robotic/cyberware/nightshade)
	var/datum/component/cyberware/optics_chrome = optics.GetComponent(/datum/component/cyberware)
	optics_chrome.grant_install_context(patient)
	TEST_ASSERT(optics.Insert(patient), "Chrome replacement didn't net out generic robotic eyes")
	TEST_ASSERT_EQUAL(get_chrome_load(patient), 20, "Chrome optics counted as both chrome and robotic anatomy")

/// Capacity can change between surgery's preop check and its insertion step.
/datum/unit_test/voidcrew_surgery_capacity_recheck

/datum/unit_test/voidcrew_surgery_capacity_recheck/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/surgeon = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/test_nineteen/bulk = allocate(/obj/item/organ/cyberimp/cyberware/test_nineteen)
	var/obj/item/organ/cyberimp/cyberware/test_small/extra = allocate(/obj/item/organ/cyberimp/cyberware/test_small)
	bulk.Insert(patient, TRUE)
	var/obj/item/organ/cyberimp/brain/anti_drop/implant = allocate(/obj/item/organ/cyberimp/brain/anti_drop)
	surgeon.put_in_hands(implant)
	TEST_ASSERT(implant.pre_surgical_insertion(surgeon, patient, BODY_ZONE_HEAD), "Surgical capacity fixture didn't initially fit")
	extra.Insert(patient, TRUE)
	var/datum/surgery_step/manipulate_organs/step = allocate(/datum/surgery_step/manipulate_organs)
	step.current_type = "insert"
	step.target_organ = implant
	TEST_ASSERT_EQUAL(step.success(surgeon, patient, BODY_ZONE_HEAD, implant, null), SURGERY_STEP_FAIL, "Surgery didn't recheck capacity after its delay")
	TEST_ASSERT(surgeon.is_holding(implant), "Late surgical refusal unequipped the new organ")
	TEST_ASSERT(!QDELETED(implant) && !implant.owner, "Late surgical refusal consumed or installed the organ")

/datum/unit_test/voidcrew_governor_capacity

/datum/unit_test/voidcrew_governor_capacity/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/governor_delete/governor = allocate(/obj/item/organ/cyberimp/cyberware/governor_delete)
	TEST_ASSERT_EQUAL(governor.zone, BODY_ZONE_CHEST, "Governor isn't chest hardware")
	for(var/os_type in list(/obj/item/organ/cyberimp/cyberware/cascade, /obj/item/organ/cyberimp/cyberware/redline))
		var/obj/item/organ/os = os_type
		TEST_ASSERT_EQUAL(governor.slot, initial(os.slot), "Governor doesn't share the OS slot with [os_type]")
	TEST_ASSERT(governor.Insert(patient, TRUE), "Governor fixture failed")
	TEST_ASSERT_EQUAL(get_chrome_capacity(patient), 35, "Governor must yield 35 capacity")
	var/obj/item/organ/cyberimp/cyberware/test_full_body/bulk = allocate(/obj/item/organ/cyberimp/cyberware/test_full_body)
	var/obj/item/organ/cyberimp/cyberware/test_heavy/heavy = allocate(/obj/item/organ/cyberimp/cyberware/test_heavy)
	bulk.Insert(patient, TRUE)
	heavy.Insert(patient, TRUE)
	TEST_ASSERT_EQUAL(get_chrome_load(patient), 35, "35 boundary fixture is wrong")
	var/datum/component/cyberware/heavy_chrome = heavy.GetComponent(/datum/component/cyberware)
	TEST_ASSERT(heavy_chrome.is_running(), "35/35 browned out")
	var/obj/item/organ/cyberimp/cyberware/test_small/extra = allocate(/obj/item/organ/cyberimp/cyberware/test_small)
	TEST_ASSERT(!cyberware_insert_check(extra, patient, TRUE), "36/35 passed the capacity gate")
	var/obj/item/organ/cyberimp/cyberware/governor_delete/replacement = allocate(/obj/item/organ/cyberimp/cyberware/governor_delete)
	var/datum/component/cyberware/replacement_chrome = replacement.GetComponent(/datum/component/cyberware)
	replacement_chrome.grant_install_context(patient)
	TEST_ASSERT(replacement.Insert(patient), "Governor replacement double-counted its bonus")
	var/obj/item/organ/cyberimp/cyberware/cascade/cascade = allocate(/obj/item/organ/cyberimp/cyberware/cascade)
	TEST_ASSERT(!cyberware_insert_check(cascade, patient, TRUE), "OS replacement kept the evicted Governor's capacity")
	TEST_ASSERT_EQUAL(replacement.owner, patient, "Rejected OS replacement evicted the Governor")
	replacement.Remove(patient, TRUE)
	TEST_ASSERT_EQUAL(get_chrome_capacity(patient), 20, "Governor removal retained its bonus")
	TEST_ASSERT(!heavy_chrome.is_running(), "Capacity loss didn't brown out chrome")
	heavy.Remove(patient, TRUE)
	var/datum/component/cyberware/bulk_chrome = bulk.GetComponent(/datum/component/cyberware)
	TEST_ASSERT(bulk_chrome.is_running(), "Removal didn't recover chrome at 20")
	bulk.Remove(patient, TRUE)
	TEST_ASSERT(cascade.Insert(patient, TRUE), "OS fixture failed")
	TEST_ASSERT(governor.Insert(patient, TRUE), "Governor couldn't replace an OS")
	TEST_ASSERT(!cascade.owner && governor.owner == patient, "Chest OS hardware stacked")

/// Every approved exception is checked independently of the table under test.
/datum/unit_test/voidcrew_nanite_capacity_costs

/datum/unit_test/voidcrew_nanite_capacity_costs/Run()
	var/list/cost_groups = list(
		list(/datum/nanite_program/regenerative_advanced, /datum/nanite_program/defib),
		list(/datum/nanite_program/regenerative, /datum/nanite_program/repairing, /datum/nanite_program/hardening, /datum/nanite_program/refractive, /datum/nanite_program/nervous, /datum/nanite_program/adrenaline),
		list(/datum/nanite_program/purging, /datum/nanite_program/purging_advanced, /datum/nanite_program/brain_heal_advanced, /datum/nanite_program/coagulating, /datum/nanite_program/access, /datum/nanite_program/viral, /datum/nanite_program/emp, /datum/nanite_program/spreading),
		list(/datum/nanite_program/brain_heal, /datum/nanite_program/blood_restoring, /datum/nanite_program/temperature, /datum/nanite_program/conductive, /datum/nanite_program/mindshield, /datum/nanite_program/self_scan, /datum/nanite_program/stealth, /datum/nanite_program/metabolic_synthesis, /datum/nanite_program/mitosis, /datum/nanite_program/nanite_sting),
		list(/datum/nanite_program/relay, /datum/nanite_program/dermal_button, /datum/nanite_program/sensor/repeat, /datum/nanite_program/sensor/relay_repeat, /datum/nanite_program/reduced_diagnostics, /datum/nanite_program/monitoring, /datum/nanite_program/poison, /datum/nanite_program/glitch, /datum/nanite_program/paralyzing),
	)
	var/list/costs = list(6, 3, 2, 1, 0)
	for(var/index in 1 to length(cost_groups))
		for(var/program_type in cost_groups[index])
			var/datum/nanite_program/program = allocate(program_type)
			TEST_ASSERT_EQUAL(program.capacity_cost(), costs[index], "Wrong capacity for [program_type]")
			program.activated = FALSE
			program.force_disabled = TRUE
			TEST_ASSERT_EQUAL(program.capacity_cost(), costs[index], "Disabling [program_type] made it free")
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/component/nanites/nanites = patient.AddComponent(/datum/component/nanites)
	for(var/program_type in subtypesof(/datum/nanite_program/protocol))
		var/datum/nanite_program/protocol/program = allocate(program_type)
		program.activated = FALSE
		program.force_disabled = TRUE
		TEST_ASSERT_EQUAL(nanites.add_program(null, program), 1, "Protocol installation failed")
	TEST_ASSERT_EQUAL(get_chrome_load(patient), length(subtypesof(/datum/nanite_program/protocol)), "Inactive/exclusive protocols were free")
	var/datum/nanite_program/defib/old_program = allocate(/datum/nanite_program/defib)
	old_program.activated = FALSE
	TEST_ASSERT_EQUAL(nanites.add_program(null, old_program), 1, "Disabled program installation failed")
	var/old_load = get_chrome_load(patient)
	var/datum/nanite_program/defib/new_program = allocate(/datum/nanite_program/defib)
	TEST_ASSERT_EQUAL(nanites.add_program(null, new_program), 1, "Netted nanite replacement failed")
	TEST_ASSERT(QDELETED(old_program), "Replaced program survived")
	TEST_ASSERT_EQUAL(get_chrome_load(patient), old_load, "Nanite replacement doubled its cost")
	var/obj/item/organ/cyberimp/cyberware/test_full_body/bulk = allocate(/obj/item/organ/cyberimp/cyberware/test_full_body)
	bulk.Insert(patient, TRUE)
	var/datum/nanite_program/defib/refused = allocate(/datum/nanite_program/defib)
	refused.activation_code = 42
	TEST_ASSERT_EQUAL(nanites.add_program(null, refused), 2, "Over-budget replacement was accepted")
	TEST_ASSERT(!QDELETED(new_program) && new_program in nanites.programs, "Rejected replacement deleted its incumbent")
	TEST_ASSERT(!QDELETED(refused) && !refused.nanites, "Rejected replacement consumed the new program")
	// A different paid program cannot consume an over-budget body's remaining programming.
	var/datum/nanite_program/hardening/rejected = allocate(/datum/nanite_program/hardening)
	TEST_ASSERT_EQUAL(nanites.add_program(null, rejected), 2, "Over-budget nanite installation succeeded") // COMPONENT_PROGRAM_NOT_INSTALLED
	TEST_ASSERT(!QDELETED(rejected) && !rejected.nanites, "Rejected nanite program was consumed")
	TEST_ASSERT(new_program in nanites.programs, "Rejected nanite install removed existing programming")

/datum/unit_test/voidcrew_nanite_capacity_sync

/datum/unit_test/voidcrew_nanite_capacity_sync/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/test_heavy/heavy = allocate(/obj/item/organ/cyberimp/cyberware/test_heavy)
	heavy.Insert(patient, TRUE)
	var/datum/component/nanites/nanites = patient.AddComponent(/datum/component/nanites)
	var/datum/nanite_program/hardening/incumbent = allocate(/datum/nanite_program/hardening)
	var/datum/nanite_program/brain_heal/shared = allocate(/datum/nanite_program/brain_heal)
	nanites.add_program(null, incumbent)
	nanites.add_program(null, shared)
	shared.activation_code = 12
	shared.activated = FALSE
	var/obj/machinery/computer/nanite_cloud_controller/controller = allocate(/obj/machinery/computer/nanite_cloud_controller)
	var/datum/nanite_cloud_backup/backup = allocate(/datum/nanite_cloud_backup, controller)
	var/datum/component/nanites/cloud = backup.AddComponent(/datum/component/nanites)
	backup.nanites = cloud
	var/datum/nanite_program/brain_heal/cloud_shared = allocate(/datum/nanite_program/brain_heal)
	cloud_shared.activation_code = 34
	var/datum/nanite_program/nervous/cloud_new = allocate(/datum/nanite_program/nervous)
	cloud.add_program(null, cloud_new)
	cloud.add_program(null, cloud_shared)
	var/list/excess = list()
	for(var/program_type in list(/datum/nanite_program/defib, /datum/nanite_program/regenerative_advanced, /datum/nanite_program/repairing, /datum/nanite_program/hardening))
		var/datum/nanite_program/program = allocate(program_type)
		TEST_ASSERT_EQUAL(cloud.add_program(null, program), 1, "Hostless backup was capacity-limited")
		excess += program
	TEST_ASSERT(cloud.programs_fit_capacity(cloud.programs), "Hostless cloud has a body capacity")
	TEST_ASSERT_EQUAL(nanites.sync_programming(cloud, TRUE, TRUE), 4, "Over-budget cloud sync did not report refusal") // NANITE_SYNC_REFUSED
	TEST_ASSERT(incumbent in nanites.programs, "Rejected cloud sync deleted an incumbent")
	TEST_ASSERT_EQUAL(shared.activation_code, 12, "Rejected cloud sync copied settings")
	TEST_ASSERT(!shared.activated, "Rejected cloud sync copied activation")
	TEST_ASSERT_EQUAL(length(nanites.programs), 2, "Rejected cloud sync partially installed programs")
	for(var/datum/nanite_program/program in excess)
		qdel(program)
	TEST_ASSERT(nanites.sync_programming(cloud), "Fitting cloud sync didn't commit")
	TEST_ASSERT(QDELETED(incumbent), "Committed cloud sync didn't remove old programming")
	TEST_ASSERT_EQUAL(shared.activation_code, 34, "Committed cloud sync didn't copy settings")
	TEST_ASSERT_EQUAL(get_chrome_load(patient), 19, "Cloud sync didn't net its complete replacement set")
	var/datum/component/cyberware/chrome = heavy.GetComponent(/datum/component/cyberware)
	chrome.set_browned_out(TRUE)
	// Identical programming still has to settle capacity; reordering the cloud is immaterial.
	cloud.programs.Swap(1, 2)
	TEST_ASSERT_EQUAL(nanites.sync_programming(cloud), 0, "Identical resync reported a programming change")
	TEST_ASSERT(chrome.is_running(), "Unchanged resync didn't recalculate brownout")
	// A partial sync must count the programs it retains, too.
	var/datum/nanite_program/hardening/additional = allocate(/datum/nanite_program/hardening)
	cloud.add_program(null, additional)
	TEST_ASSERT_EQUAL(nanites.sync_programming(cloud, FALSE), 4, "Partial cloud sync ignored retained program load") // NANITE_SYNC_REFUSED
	TEST_ASSERT_EQUAL(length(nanites.programs), 2, "Rejected partial sync changed programming")

/datum/unit_test/voidcrew_nanite_capacity_recovery

/datum/unit_test/voidcrew_nanite_capacity_recovery/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/governor_delete/governor = allocate(/obj/item/organ/cyberimp/cyberware/governor_delete)
	var/obj/item/organ/cyberimp/cyberware/test_heavy/heavy = allocate(/obj/item/organ/cyberimp/cyberware/test_heavy)
	var/obj/item/organ/heart/cybernetic/heart = allocate(/obj/item/organ/heart/cybernetic)
	governor.Insert(patient, TRUE)
	heavy.Insert(patient, TRUE)
	heart.Insert(patient)
	var/datum/component/nanites/nanites = patient.AddComponent(/datum/component/nanites)
	var/datum/nanite_program/hardening/armor = allocate(/datum/nanite_program/hardening)
	var/datum/nanite_program/adrenaline/burst = allocate(/datum/nanite_program/adrenaline)
	nanites.add_program(null, armor)
	nanites.add_program(null, burst)
	var/bare_armor = patient.physiology.armor.get_rating(MELEE)
	armor.on_process()
	TEST_ASSERT(armor.passive_enabled, "Beneficial passive didn't start")
	governor.Remove(patient, TRUE)
	TEST_ASSERT(!armor.passive_enabled, "Capacity loss retained beneficial nanite armor")
	TEST_ASSERT_EQUAL(patient.physiology.armor.get_rating(MELEE), bare_armor, "Paused nanites retained armor")
	TEST_ASSERT(!(heart.organ_flags & ORGAN_FAILING), "Capacity loss shut down a vital TG organ")
	var/volume = nanites.nanite_volume
	armor.on_process()
	burst.trigger()
	TEST_ASSERT_EQUAL(nanites.nanite_volume, volume, "Over-budget beneficial nanites consumed fuel")
	TEST_ASSERT_EQUAL(burst.next_trigger, 0, "A paused beneficial trigger spent its cooldown")
	TEST_ASSERT(!patient.reagents.has_reagent(/datum/reagent/medicine/stimulants), "Paused Adrenaline Burst fired")
	for(var/program_type in list(/datum/nanite_program/glitch, /datum/nanite_program/poison, /datum/nanite_program/paralyzing, /datum/nanite_program/sensor/repeat, /datum/nanite_program/monitoring))
		var/datum/nanite_program/hostile = allocate(program_type)
		var/load = get_chrome_load(patient)
		TEST_ASSERT_EQUAL(nanites.add_program(null, hostile), 1, "Zero-cost payload was refused over capacity")
		TEST_ASSERT_EQUAL(get_chrome_load(patient), load, "Zero-cost payload sabotaged capacity")
		TEST_ASSERT(!hostile.capacity_blocked(), "Capacity paused a hostile/free program")
	qdel(burst)
	TEST_ASSERT_EQUAL(get_chrome_load(patient), 19, "Deletion didn't release beneficial program load")
	var/datum/component/cyberware/chrome = heavy.GetComponent(/datum/component/cyberware)
	TEST_ASSERT(chrome.is_running(), "Deleting a program didn't recover chrome")
	armor.on_process()
	TEST_ASSERT(armor.passive_enabled, "Beneficial nanites didn't resume after recovery")
	qdel(nanites)
	TEST_ASSERT_EQUAL(get_chrome_load(patient), 16, "Deleting nanites retained installed program costs")
	TEST_ASSERT_EQUAL(patient.physiology.armor.get_rating(MELEE), bare_armor, "Deleting recovered nanites retained their armor")

/datum/unit_test/voidcrew_cyberware_running_gates

/datum/unit_test/voidcrew_cyberware_running_gates/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/eyes/robotic/cyberware/nightshade/eyes = allocate(/obj/item/organ/eyes/robotic/cyberware/nightshade)
	eyes.Insert(patient, TRUE)
	var/datum/component/cyberware/eye_chrome = eyes.GetComponent(/datum/component/cyberware)
	var/datum/action/cooldown/cyberware/chrome_read/read = locate() in eyes.actions
	TEST_ASSERT(read, "Chrome read action fixture missing")
	TEST_ASSERT(read.IsAvailable(), "Installed healthy optics action unavailable")
	eyes.set_organ_damage(eyes.maxHealth)
	eye_chrome.start_emp_reboot()
	eyes.set_organ_damage(0)
	TEST_ASSERT(eye_chrome.emp_down, "Organ repair cleared EMP downtime")
	TEST_ASSERT(!eye_chrome.is_running() && !read.IsAvailable(), "Healing eyes reopened buttons before reboot")
	// The running predicate must remain authoritative even if another caller clears the shared bit.
	eyes.organ_flags &= ~ORGAN_FAILING
	TEST_ASSERT(!read.IsAvailable(), "Clearing the shared failing flag bypassed EMP downtime")
	eye_chrome.tune_up()
	TEST_ASSERT(read.IsAvailable(), "Finished reboot didn't restore the action")
	read.StartCooldown(1 MINUTES)
	var/ready_at = read.next_use_time
	eyes.Remove(patient, TRUE)
	TEST_ASSERT(!eye_chrome.is_running() && !read.IsAvailable(), "Removed optics still running")
	eyes.Insert(patient, TRUE)
	TEST_ASSERT_EQUAL(read.next_use_time, ready_at, "Removing/reinstalling reset an ability cooldown")
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/arm = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis)
	arm.Insert(patient, TRUE)
	var/datum/component/cyberware/arm_chrome = arm.GetComponent(/datum/component/cyberware)
	var/obj/item/blade = arm.contents[1]
	arm.Extend(blade)
	TEST_ASSERT(arm.active_item == blade && blade.loc == patient, "Arm deployment fixture failed")
	arm_chrome.start_emp_reboot()
	TEST_ASSERT(!arm.active_item && blade.loc == arm, "EMP left chrome arm hardware deployed")
	arm.organ_flags &= ~ORGAN_FAILING
	arm.Extend(blade)
	TEST_ASSERT(blade.loc == arm, "Arm deployed during EMP reboot after shared flag was cleared")
	arm_chrome.tune_up()
	arm.Extend(blade)
	arm.set_organ_damage(arm.maxHealth)
	TEST_ASSERT(!arm.active_item && blade.loc == arm, "Damage failure left chrome arm hardware deployed")
	arm_chrome.tune_up()
	arm.Extend(blade)
	var/obj/item/organ/cyberimp/cyberware/test_full_body/bulk = allocate(/obj/item/organ/cyberimp/cyberware/test_full_body)
	bulk.Insert(patient, TRUE)
	TEST_ASSERT(!arm.active_item && blade.loc == arm, "Brownout left chrome arm hardware deployed")
	bulk.Remove(patient, TRUE)
	arm.Extend(blade)
	TEST_ASSERT_EQUAL(arm.active_item, blade, "Capacity recovery didn't restore arm deployment")
	arm.Remove(patient, TRUE)
	TEST_ASSERT(!arm.active_item && blade.loc == arm, "Removal left arm hardware deployed")

/datum/unit_test/voidcrew_cyberware_lazarus_windup

/datum/unit_test/voidcrew_cyberware_lazarus_windup/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/lazarus/node = allocate(/obj/item/organ/cyberimp/cyberware/lazarus)
	node.Insert(patient, TRUE)
	var/datum/component/cyberware/chrome = node.GetComponent(/datum/component/cyberware)
	patient.stat = SOFT_CRIT
	node.on_stat_change(patient, SOFT_CRIT, CONSCIOUS)
	var/first_generation = node.jolt_generation
	TEST_ASSERT(node.jolting, "Lazarus didn't wind up")
	TEST_ASSERT(COOLDOWN_FINISHED(node, jolt_cooldown), "Windup consumed Lazarus charge")
	chrome.start_emp_reboot()
	TEST_ASSERT(!node.jolting, "EMP didn't cancel Lazarus windup")
	chrome.tune_up()
	node.jolt(first_generation, WEAKREF(patient))
	TEST_ASSERT(COOLDOWN_FINISHED(node, jolt_cooldown), "Cancelled EMP windup consumed charge")
	node.on_stat_change(patient, SOFT_CRIT, CONSCIOUS)
	var/removed_generation = node.jolt_generation
	node.Remove(patient, TRUE)
	node.Insert(patient, TRUE)
	node.on_stat_change(patient, SOFT_CRIT, CONSCIOUS)
	var/current_generation = node.jolt_generation
	node.jolt(removed_generation, WEAKREF(patient))
	TEST_ASSERT(node.jolting, "A stale Lazarus callback cancelled the new windup")
	TEST_ASSERT(COOLDOWN_FINISHED(node, jolt_cooldown), "Removal/reinstall allowed a stale callback to discharge")
	patient.stat = DEAD
	node.jolt(current_generation, WEAKREF(patient))
	TEST_ASSERT(COOLDOWN_FINISHED(node, jolt_cooldown), "Dead patient consumed Lazarus charge")
	patient.stat = SOFT_CRIT
	node.on_stat_change(patient, SOFT_CRIT, CONSCIOUS)
	patient.stat = CONSCIOUS
	node.jolt(node.jolt_generation, WEAKREF(patient))
	TEST_ASSERT(COOLDOWN_FINISHED(node, jolt_cooldown), "Recovered patient consumed Lazarus charge")
	patient.stat = SOFT_CRIT
	node.on_stat_change(patient, SOFT_CRIT, CONSCIOUS)
	node.jolt(node.jolt_generation, WEAKREF(patient))
	TEST_ASSERT_EQUAL(COOLDOWN_TIMELEFT(node, jolt_cooldown), 6 MINUTES, "Successful discharge didn't start the six-minute cooldown")
	var/ready_at = node.jolt_cooldown
	node.Remove(patient, TRUE)
	node.Insert(patient, TRUE)
	TEST_ASSERT_EQUAL(node.jolt_cooldown, ready_at, "Removal/reinstall reset Lazarus cooldown")
