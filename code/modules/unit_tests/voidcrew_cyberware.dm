/**
 * # Cyberware framework conformance
 *
 * Live-mob tests for the chrome load system (voidcrew/modules/cyberware/):
 * the netted capacity gate, the install-context gate, the all-or-nothing
 * over-cap brownout, the one-hardware-slot-per-arm invariant, the Second Wind
 * Bladder's breath interception, chrome surviving a body-destroying death, the
 * EMP counter (a pulse reaching installed chrome, offline chrome dropping its
 * passives, and the Voltaic cyberheart's one-pulse absorb), and the Chrome
 * Cradle console - its rack grouping and load projection, both of which the
 * interface reads straight out of ui_data() and neither of which errors when it
 * goes wrong.
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
	TEST_ASSERT(!lab_rat.failed_last_breath, "Second Wind didn't block a breath in vacuum — the bearer suffocated with a full reserve")
	TEST_ASSERT_EQUAL(lab_rat.get_oxy_loss(), 0, "Second Wind blocked the breath but the bearer still took oxygen damage")
	TEST_ASSERT(bladder.reserve < full_reserve, "A blocked breath spent no reserve")
	TEST_ASSERT(bladder.engaged, "Second Wind fed a breath without registering as engaged")

	var/after_one_breath = bladder.reserve
	lab_rat.breathe(2, 1)
	TEST_ASSERT(bladder.reserve < after_one_breath, "A second blocked breath spent no reserve")

	// Run the reserve dry: the next breath must fail for real.
	bladder.reserve = 0
	lab_rat.breathe(2, 1)
	TEST_ASSERT(lab_rat.failed_last_breath || lab_rat.get_oxy_loss() > 0, "Reserve empty in vacuum, but the bearer still isn't suffocating")

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
	//
	// The body-preview mannequin this block used to also assert on was cut from
	// the feature on 2026-08-05; refresh_preview(), the `preview` var, the
	// /atom/movable/screen/map_view/chrome_preview type and the "preview_view"
	// ui_data key all went with it. The load projection below is what survived,
	// and it is the part that actually guards the install maths.
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
	// The 2026 upstream surgery rework replaced the /datum/surgery possible_locs whitelist -
	// which is what made a leg unreachable in the first place - with one operation that is
	// generic over whichever limb is being cut into and answers per organ through zone_check().
	// So the question this test asks is the same, but it is asked of the operation directly:
	// would organ manipulation accept this ware on the limb the ware lives in?
	var/datum/surgery_operation/limb/organ_manipulation/procedure = 		GLOB.operations.operations_by_typepath[/datum/surgery_operation/limb/organ_manipulation/internal]
	TEST_ASSERT(procedure, "no internal organ-manipulation operation is registered, so nothing here proves anything")

	for(var/zone in list(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
		var/obj/item/organ/leg_ware = allocate(/obj/item/organ/cyberimp/cyberware/piledriver)
		leg_ware.zone = zone
		TEST_ASSERT(procedure.zone_check(leg_ware, deprecise_zone(zone), zone), 			"Organ manipulation refuses [zone]. Every piece of leg chrome is Chrome Cradle-only again")

	var/list/all_ware = typesof(/obj/item/organ/cyberimp/cyberware) + typesof(/obj/item/organ/eyes/robotic/cyberware) + typesof(/obj/item/organ/cyberimp/arm/toolkit/cyberware)
	for(var/obj/item/organ/ware_type as anything in all_ware)
		if(initial(ware_type.abstract_type) == ware_type)
			continue
		var/obj/item/organ/ware = allocate(ware_type)
		var/zone = ware.zone
		TEST_ASSERT(procedure.zone_check(ware, deprecise_zone(zone), zone), 			"[ware_type] lives in [zone], which organ manipulation will not open. It can never be installed by surgery")

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

	// One pulse, then the capacitors have to vent. Both pulses below land in
	// the same tick, so the shortened recharge can't finish between them; it
	// is shortened only so the recharge timer doesn't outlive the test.
	var/obj/item/organ/heart/cybernetic/anomalock/prebuilt/shield = allocate(/obj/item/organ/heart/cybernetic/anomalock/prebuilt)
	shield.emp_absorb_cooldown_time = 1
	TEST_ASSERT(shield.Insert(lab_rat, special = TRUE), "Test fixture: Voltaic cyberheart staging insert was refused")

	lab_rat.emp_act(EMP_HEAVY)
	TEST_ASSERT(!(mesh.organ_flags & ORGAN_FAILING), "The Voltaic cyberheart didn't absorb the first pulse")

	lab_rat.emp_act(EMP_HEAVY)
	TEST_ASSERT(mesh.organ_flags & ORGAN_FAILING, "The Voltaic cyberheart ate a second pulse on drained capacitors. It must only ever cover one")

	// Pulling the core first: a cored heart tesla-zaps the room on removal,
	// and teardown removes it.
	QDEL_NULL(shield.core)

