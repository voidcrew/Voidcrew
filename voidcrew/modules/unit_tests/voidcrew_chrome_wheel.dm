/**
 * # Chrome wheel
 *
 * The wheel (voidcrew/modules/cyberware/chrome_wheel.dm) fires the bearer's
 * own chrome buttons, so these tests hold it to that: it collects exactly the
 * buttons installed chrome grants (never a printable tg implant's), lays them
 * out by body region without one region moving another, points at the right
 * slice, and fires the pick through Trigger() with the button's own cooldown,
 * offline and arm-toggle behaviour. No client exists here, so the wheel never
 * draws; opening it must fail quietly instead.
 *
 * NOTE: unit-test files compile before voidcrew/_DEFINES/, so fork defines are
 * written as literals: CHROME_WHEEL_INNER_RADIUS 40, CHROME_WHEEL_OUTER_RADIUS
 * 72, CHROME_WHEEL_ROW_GAP 38, CHROME_WHEEL_DEADZONE 16, and
 * ORGAN_SLOT_CYBERWARE_OS "cyberware_os".
 */

/obj/item/organ/cyberimp/cyberware/test_wheel_pulse
	name = "test wheel chrome"
	zone = BODY_ZONE_CHEST
	slot = "voidcrew_test_chrome_wheel"
	chrome_load = 1
	actions_types = list(/datum/action/cooldown/cyberware/test_wheel)

/obj/item/organ/cyberimp/cyberware/test_wheel_os
	name = "test wheel OS"
	zone = BODY_ZONE_CHEST
	slot = "cyberware_os" // ORGAN_SLOT_CYBERWARE_OS
	chrome_load = 1
	actions_types = list(/datum/action/cooldown/cyberware/test_wheel/os)

/// Counts its firings, and offers two sub-options whose use it records.
/datum/action/cooldown/cyberware/test_wheel
	name = "Test Wheel Pulse"
	cooldown_time = 10 SECONDS
	var/fired = 0
	var/list/options_used = list()

/datum/action/cooldown/cyberware/test_wheel/Activate(atom/target)
	fired++
	StartCooldown()
	return TRUE

/datum/action/cooldown/cyberware/test_wheel/chrome_wheel_options(mob/living/carbon/bearer)
	return list(
		new /datum/chrome_wheel_option("alpha", "Alpha"),
		new /datum/chrome_wheel_option("beta", "Beta"),
	)

/datum/action/cooldown/cyberware/test_wheel/use_chrome_wheel_option(mob/living/carbon/bearer, option_id)
	options_used += option_id
	return TRUE

/datum/action/cooldown/cyberware/test_wheel/os
	name = "Test Wheel Burn"

/datum/action/cooldown/cyberware/test_wheel/os/chrome_wheel_options(mob/living/carbon/bearer)
	return null

/// Collection, region layout, its stability, display names and pointing.
/datum/unit_test/voidcrew_chrome_wheel_layout

/datum/unit_test/voidcrew_chrome_wheel_layout/Run()
	var/mob/living/carbon/human/lab_rat = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/test_wheel_pulse/pulse_ware = allocate(/obj/item/organ/cyberimp/cyberware/test_wheel_pulse)
	TEST_ASSERT(pulse_ware.Insert(lab_rat, special = TRUE), "Test chrome staging insert was refused")
	var/obj/item/organ/cyberimp/cyberware/test_wheel_os/os_ware = allocate(/obj/item/organ/cyberimp/cyberware/test_wheel_os)
	TEST_ASSERT(os_ware.Insert(lab_rat, special = TRUE), "Test OS staging insert was refused")
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left/left_mantis = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left)
	TEST_ASSERT(left_mantis.Insert(lab_rat, special = TRUE), "Left Mantis staging insert was refused")
	var/obj/item/organ/cyberimp/arm/toolkit/toolset/printable = allocate(/obj/item/organ/cyberimp/arm/toolkit/toolset)
	TEST_ASSERT(printable.Insert(lab_rat, special = TRUE), "Toolset implant staging insert was refused")

	var/datum/action/pulse = locate(/datum/action/cooldown/cyberware/test_wheel) in pulse_ware.actions
	var/datum/action/burn = locate(/datum/action/cooldown/cyberware/test_wheel/os) in os_ware.actions
	var/datum/action/blade = locate(/datum/action/item_action/organ_action/toggle) in left_mantis.actions
	var/datum/action/lunge = locate(/datum/action/cooldown/cyberware/mantis_lunge) in left_mantis.actions
	var/datum/action/toolset_toggle = locate(/datum/action/item_action/organ_action/toggle) in printable.actions
	TEST_ASSERT(pulse && burn && blade && lunge && toolset_toggle, "A staged organ is missing its button")

	var/list/abilities = get_chrome_wheel_actions(lab_rat)
	TEST_ASSERT_EQUAL(length(abilities), 4, "The wheel should hold exactly the four buttons installed chrome grants")
	TEST_ASSERT((pulse in abilities) && (burn in abilities) && (blade in abilities) && (lunge in abilities), "An installed chrome button is missing from the wheel")
	TEST_ASSERT(!(toolset_toggle in abilities), "A printable tg implant's button made it onto the chrome wheel")
	TEST_ASSERT_EQUAL(get_os_chrome_action(lab_rat), burn, "Use OS chrome does not find the OS-slot ware's ability")

	var/list/positions = chrome_wheel_layout(abilities)
	TEST_ASSERT_EQUAL(point_text(positions[burn]), "0,40", "The OS ability is not at the top of the torso ring")
	TEST_ASSERT_EQUAL(point_text(positions[pulse]), "35,20", "Other torso chrome should start beside the OS, 60 degrees round the torso ring")
	TEST_ASSERT_EQUAL(point_text(positions[blade]), "-72,0", "Left arm chrome is not on the left of the wheel")
	TEST_ASSERT_EQUAL(point_text(positions[lunge]), "-62,-36", "A left arm's second ability should hang 30 degrees below the first")

	// Region independence: new right-arm chrome takes the right side and moves
	// nothing on the left, and a missing OS leaves its place empty.
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/right_mantis = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis)
	TEST_ASSERT(right_mantis.Insert(lab_rat, special = TRUE), "Right Mantis staging insert was refused")
	var/datum/action/right_blade = locate(/datum/action/item_action/organ_action/toggle) in right_mantis.actions
	os_ware.Remove(lab_rat, special = TRUE)
	abilities = get_chrome_wheel_actions(lab_rat)
	positions = chrome_wheel_layout(abilities)
	TEST_ASSERT_EQUAL(point_text(positions[right_blade]), "72,0", "Right arm chrome is not on the right of the wheel")
	TEST_ASSERT_EQUAL(point_text(positions[blade]), "-72,0", "Adding right-arm chrome moved the left arm's slice")
	TEST_ASSERT_EQUAL(point_text(positions[pulse]), "35,20", "Removing the OS moved other torso chrome into its place")

	// Two housings give two Mantis Lunges; the side tells them apart.
	var/list/names = chrome_wheel_names(abilities)
	TEST_ASSERT_EQUAL(names[lunge], "Mantis Lunge (left arm)", "Matching ability names are not told apart by body side")

	// Pointing. Points: 1 pulse (35,20), 2 blade (-72,0), 3 lunge (-62,-36), 4 right blade (72,0).
	var/list/points = list(positions[pulse], positions[blade], positions[lunge], positions[right_blade])
	TEST_ASSERT_EQUAL(chrome_wheel_pick(5, 5, points), 0, "The dead zone in the middle pointed at a slice")
	TEST_ASSERT_EQUAL(chrome_wheel_pick(33, 22, points), 1, "The mouse on a slice did not point at it")
	TEST_ASSERT_EQUAL(chrome_wheel_pick(-300, 4, points), 2, "A flick far out to the left did not point at the left arm")
	TEST_ASSERT_EQUAL(chrome_wheel_pick(0, -300, points), 0, "A flick into the empty legs region pointed at something")

	var/list/ring = chrome_wheel_sub_positions(0, 72, 3, 72)
	TEST_ASSERT_EQUAL(point_text(ring[1]), "0,110", "The first sub-option should sit straight out from its parent, a row outside the wheel")
	var/list/second = ring[2]
	var/list/third = ring[3]
	TEST_ASSERT(second[1] > 0 && third[1] < 0, "Sub-options should spread to both sides of the first")

	TEST_ASSERT_EQUAL(chrome_wheel_raw_key("ShiftV"), "V", "A Shift bind's key was not found")
	TEST_ASSERT_EQUAL(chrome_wheel_raw_key("CtrlShiftV"), "V", "A two-modifier bind's key was not found")
	TEST_ASSERT_EQUAL(chrome_wheel_raw_key("Space"), "Space", "A plain key was mangled")
	TEST_ASSERT_EQUAL(chrome_wheel_raw_key("Alt"), "Alt", "A bare modifier bind lost its key")

/datum/unit_test/voidcrew_chrome_wheel_layout/proc/point_text(list/point)
	return length(point) == 2 ? "[point[1]],[point[2]]" : "none"

/// Selection and firing: the pick goes through the button's own Trigger().
/datum/unit_test/voidcrew_chrome_wheel_fire

/datum/unit_test/voidcrew_chrome_wheel_fire/Run()
	var/mob/living/carbon/human/lab_rat = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT_NULL(get_chrome_wheel(lab_rat), "A body with no chrome grew a chrome wheel")
	var/obj/item/organ/cyberimp/cyberware/test_wheel_pulse/pulse_ware = allocate(/obj/item/organ/cyberimp/cyberware/test_wheel_pulse)
	TEST_ASSERT(pulse_ware.Insert(lab_rat, special = TRUE), "Test chrome staging insert was refused")
	var/obj/item/organ/cyberimp/cyberware/test_wheel_os/os_ware = allocate(/obj/item/organ/cyberimp/cyberware/test_wheel_os)
	TEST_ASSERT(os_ware.Insert(lab_rat, special = TRUE), "Test OS staging insert was refused")
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left/mantis = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left)
	TEST_ASSERT(mantis.Insert(lab_rat, special = TRUE), "Mantis staging insert was refused")

	var/datum/action/cooldown/cyberware/test_wheel/pulse = locate(/datum/action/cooldown/cyberware/test_wheel) in pulse_ware.actions
	var/datum/action/cooldown/cyberware/test_wheel/burn = locate(/datum/action/cooldown/cyberware/test_wheel/os) in os_ware.actions
	var/datum/action/blade = locate(/datum/action/item_action/organ_action/toggle) in mantis.actions
	var/datum/action/lunge = locate(/datum/action/cooldown/cyberware/mantis_lunge) in mantis.actions

	var/datum/component/chrome_wheel/wheel = get_chrome_wheel(lab_rat)
	TEST_ASSERT_NOTNULL(wheel, "A chromed body got no wheel")

	// No client: the wheel key has nothing to draw on and must do nothing.
	wheel.wheel_key_down()
	TEST_ASSERT(!wheel.is_open(), "The wheel opened with no client to draw on")
	wheel.wheel_key_up()

	wheel.select(pulse)
	TEST_ASSERT(wheel.use_selected(), "Use chrome refused a ready pick")
	TEST_ASSERT_EQUAL(pulse.fired, 1, "Use chrome did not fire the picked ability")

	// The cooldown is the button's own.
	lab_rat.next_click = 0
	wheel.use_selected()
	TEST_ASSERT_EQUAL(pulse.fired, 1, "The wheel fired an ability through its cooldown")

	// Offline chrome stays dark through the wheel, and keeps its pick.
	pulse.ResetCooldown()
	var/datum/component/cyberware/chrome = pulse_ware.GetComponent(/datum/component/cyberware)
	chrome.start_emp_reboot(EMP_HEAVY)
	lab_rat.next_click = 0
	wheel.use_selected()
	TEST_ASSERT_EQUAL(pulse.fired, 1, "EMP-scrambled chrome fired from the wheel")
	TEST_ASSERT_EQUAL(wheel.get_selected_ability(), pulse, "Going offline dropped the pick. It should only go dark")
	chrome.tune_up()
	lab_rat.next_click = 0
	wheel.use_selected()
	TEST_ASSERT_EQUAL(pulse.fired, 2, "Chrome back online did not fire from the wheel")

	// Use OS chrome fires the OS and leaves the pick alone.
	lab_rat.next_click = 0
	TEST_ASSERT(wheel.use_os(), "Use OS chrome refused")
	TEST_ASSERT_EQUAL(burn.fired, 1, "Use OS chrome did not fire the OS ability")
	TEST_ASSERT_EQUAL(pulse.fired, 2, "Use OS chrome fired the picked ability")
	TEST_ASSERT_EQUAL(wheel.get_selected_ability(), pulse, "Use OS chrome changed the pick")

	// Arm hardware toggles like its button: out, then back in.
	wheel.select(blade)
	lab_rat.next_click = 0
	wheel.use_selected()
	TEST_ASSERT(mantis.active_item && !(mantis.active_item in mantis), "Using the picked Mantis housing did not deploy the blade")
	lab_rat.next_click = 0
	wheel.use_selected()
	TEST_ASSERT(!mantis.active_item || (mantis.active_item in mantis), "Using the picked Mantis housing again did not retract the blade")

	// A picked sub-option fires through the ability's option hook instead of Trigger().
	pulse.ResetCooldown()
	wheel.select(pulse, "beta")
	lab_rat.next_click = 0
	wheel.use_selected()
	TEST_ASSERT("beta" in pulse.options_used, "A picked sub-option was not handed to its ability")
	TEST_ASSERT_EQUAL(pulse.fired, 2, "Using a sub-option also fired the ability itself")

	// A pick the ability no longer offers is dropped, not fired.
	wheel.select(pulse, "gamma")
	lab_rat.next_click = 0
	TEST_ASSERT(!wheel.use_selected(), "A sub-option the ability no longer offers was fired")
	TEST_ASSERT_NULL(wheel.get_selected_ability(), "A sub-option the ability no longer offers stayed picked")

	// Chrome pulled between the pick and the use: nothing fires and the pick goes.
	wheel.select(lunge)
	mantis.Remove(lab_rat, special = TRUE)
	lab_rat.next_click = 0
	TEST_ASSERT(!wheel.use_selected(), "An ability fired after its chrome was removed")
	TEST_ASSERT_NULL(wheel.get_selected_ability(), "Removed chrome stayed picked")
	TEST_ASSERT(!wheel.is_open(), "With no client, a missing pick opened the wheel")
