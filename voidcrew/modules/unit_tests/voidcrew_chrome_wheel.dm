/**
 * # Chrome wheel
 *
 * The wheel (voidcrew/modules/cyberware/chrome_wheel.dm) fires the bearer's
 * own chrome abilities, so these tests hold it to that: it collects exactly the
 * abilities installed chrome grants (never a printable tg implant's), sockets
 * them on the ring by body part without one socket moving another, points at
 * the right chip by bearing, and fires the pick through Trigger() with the
 * ability's own cooldown, offline and arm-toggle behaviour. No client exists
 * here, so the wheel never goes on a screen; opening it must fail quietly, and
 * building its pieces must still work. Chrome abilities have no HUD button of
 * their own; one Chrome button stands in for them (chrome_hud.dm), and Arm
 * chrome deploys every arm at once (chrome_wheel_arms.dm).
 *
 * NOTE: unit-test files compile before voidcrew/_DEFINES/, so fork defines are
 * written as literals: CHROME_WHEEL_RADIUS 100, CHROME_WHEEL_STEP 14.5,
 * CHROME_WHEEL_ROW_GAP 26, CHROME_WHEEL_CENTRE_Y 2, CHROME_WHEEL_DEADZONE 34,
 * CHROME_WHEEL_SOCKET_OS "os", CHROME_WHEEL_SOCKET_RIGHT_ARM "r_arm",
 * ORGAN_SLOT_CYBERWARE_OS "cyberware_os" and ORGAN_SLOT_CYBERWARE_HANDS
 * "cyberware_hands".
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

/obj/item/organ/cyberimp/cyberware/test_wheel_hand
	name = "test wheel grips"
	zone = BODY_ZONE_R_ARM
	slot = "cyberware_hands" // ORGAN_SLOT_CYBERWARE_HANDS
	chrome_load = 1
	actions_types = list(/datum/action/cooldown/cyberware/test_wheel/hand)

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

/datum/action/cooldown/cyberware/test_wheel/hand
	name = "Test Wheel Grip"

/datum/action/cooldown/cyberware/test_wheel/hand/chrome_wheel_options(mob/living/carbon/bearer)
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

	var/datum/component/chrome_wheel/wheel = lab_rat.GetComponent(/datum/component/chrome_wheel)
	var/datum/action/arms = wheel?.arm_action
	TEST_ASSERT_NOTNULL(arms, "Arm hardware went in and the body got no Arm chrome")

	var/list/abilities = get_chrome_wheel_actions(lab_rat)
	TEST_ASSERT_EQUAL(length(abilities), 5, "The wheel should hold the four abilities installed chrome grants, and Arm chrome")
	TEST_ASSERT((pulse in abilities) && (burn in abilities) && (blade in abilities) && (lunge in abilities), "An installed chrome ability is missing from the wheel")
	TEST_ASSERT(arms in abilities, "Arm chrome is not on the wheel")
	TEST_ASSERT(!(toolset_toggle in abilities), "A printable tg implant's button made it onto the chrome wheel")
	TEST_ASSERT_EQUAL(get_os_chrome_action(lab_rat), burn, "Use OS chrome does not find the OS-slot ware's ability")

	// Sockets run round the ring 14.5 degrees apart at radius 100, from a
	// centre 2 px above the view's. The OS starts its arc right of the head.
	var/list/positions = chrome_wheel_layout(abilities)
	TEST_ASSERT_EQUAL(point_text(positions[burn]), "73,70", "The OS ability is not first on its arc, up and right of the body")
	TEST_ASSERT_EQUAL(point_text(positions[pulse]), "88,50", "Other chest chrome should follow the OS one step round its arc")
	TEST_ASSERT_EQUAL(point_text(positions[blade]), "-99,14", "Left arm chrome is not on the left of the ring")
	TEST_ASSERT_EQUAL(point_text(positions[lunge]), "-99,-11", "A left arm's second ability should sit one step further round its arc")
	// Arm chrome holds the top of the right arm's arc, by the torso, whatever the right arm carries.
	TEST_ASSERT_EQUAL(point_text(positions[arms]), "99,14", "Arm chrome is not at the top of the right arm's arc")

	// Socket independence: new right-arm chrome takes the right side and moves
	// nothing on the left, and a missing OS leaves its place empty.
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/right_mantis = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis)
	TEST_ASSERT(right_mantis.Insert(lab_rat, special = TRUE), "Right Mantis staging insert was refused")
	var/datum/action/right_blade = locate(/datum/action/item_action/organ_action/toggle) in right_mantis.actions
	os_ware.Remove(lab_rat, special = TRUE)
	abilities = get_chrome_wheel_actions(lab_rat)
	positions = chrome_wheel_layout(abilities)
	TEST_ASSERT_EQUAL(point_text(positions[right_blade]), "99,-11", "Right arm chrome should start on the right of the ring, below Arm chrome")
	TEST_ASSERT_EQUAL(point_text(positions[arms]), "99,14", "Right arm chrome moved Arm chrome")
	TEST_ASSERT_EQUAL(point_text(positions[blade]), "-99,14", "Adding right-arm chrome moved the left arm's chip")
	TEST_ASSERT_EQUAL(point_text(positions[pulse]), "88,50", "Removing the OS moved other chest chrome into its place")

	// Hand chrome follows its arm's own chrome round the arm's arc.
	var/obj/item/organ/cyberimp/cyberware/test_wheel_hand/grips = allocate(/obj/item/organ/cyberimp/cyberware/test_wheel_hand)
	TEST_ASSERT(grips.Insert(lab_rat, special = TRUE), "Test hand chrome staging insert was refused")
	var/datum/action/grip = locate(/datum/action/cooldown/cyberware/test_wheel/hand) in grips.actions
	TEST_ASSERT_NOTNULL(grip, "The test hand chrome is missing its button")
	abilities = get_chrome_wheel_actions(lab_rat)
	var/list/placements = chrome_wheel_placements(abilities)
	var/list/grip_place = placements[grip]
	TEST_ASSERT_EQUAL(grip_place?["socket"], "r_arm", "Hand chrome is not in its arm's socket")
	TEST_ASSERT_EQUAL(grip_place?["index"], 4, "Hand chrome should come after Arm chrome and both of the right Mantis housing's chips")
	TEST_ASSERT(grip_place?["hand"], "Hand chrome was not marked as hand chrome")
	positions = chrome_wheel_layout(abilities)
	TEST_ASSERT_EQUAL(point_text(positions[right_blade]), "99,-11", "Hand chrome pushed its arm's own chrome along")

	// A full arc starts a row further out at the same bearing.
	TEST_ASSERT_EQUAL(point_text(chrome_wheel_position("os", 3)), "92,88", "The OS arc's third chip did not start a second row outside the first")

	// Chips are called by what they do, not by their button's full name.
	var/list/names = chrome_wheel_names(abilities)
	TEST_ASSERT_EQUAL(names[blade], "Mantis Blade", "A Mantis housing's deploy chip should read as the blade, without its housing or side")
	TEST_ASSERT_EQUAL(names[lunge], "Mantis Lunge", "An ability with its own name was renamed")
	TEST_ASSERT_EQUAL(chrome_wheel_ware_name(lunge), "Mantis Blade housing (left)", "The readout should name the chrome an ability lives in")
	TEST_ASSERT_EQUAL(names[arms], "Arm chrome", "Arm chrome's chip is misnamed")

	// Pointing. Points: 1 pulse (88,50), 2 blade (-99,14), 3 lunge (-99,-11),
	// 4 right blade (99,-11), 5 grip (80,-57).
	var/list/points = list(positions[pulse], positions[blade], positions[lunge], positions[right_blade], positions[grip])
	TEST_ASSERT_EQUAL(chrome_wheel_pick(5, 5, points), 0, "The middle of the body pointed at a chip")
	TEST_ASSERT_EQUAL(chrome_wheel_pick(20, 20, points), 0, "A point inside the body pointed at a chip")
	TEST_ASSERT_EQUAL(chrome_wheel_pick(87, 51, points), 1, "The mouse on a chip did not point at it")
	TEST_ASSERT_EQUAL(chrome_wheel_pick(-300, 4, points), 2, "A flick far out to the left did not point at the left arm's nearest chip by bearing")
	TEST_ASSERT_EQUAL(chrome_wheel_pick(-40, -6, points), 3, "A short move between the body and the ring did not point at the chip on its bearing")
	TEST_ASSERT_EQUAL(chrome_wheel_pick(0, -300, points), 0, "A flick into the empty legs arc pointed at something")
	// A second-row chip answers the mouse right on it, never a bearing.
	var/list/rows = list(list(73, 70), list(92, 88))
	TEST_ASSERT_EQUAL(chrome_wheel_pick(184, 176, rows, list(TRUE, FALSE)), 1, "A flick out along a socket's bearing picked its second row over its first")
	TEST_ASSERT_EQUAL(chrome_wheel_pick(93, 87, rows, list(TRUE, FALSE)), 2, "The mouse on a second-row chip did not point at it")

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

	// Its pieces build without a screen to go on: one chip per ability, and
	// pointing, picking and teardown work on them.
	wheel.build_wheel(get_chrome_wheel_actions(lab_rat))
	TEST_ASSERT_EQUAL(length(wheel.chips), 5, "The built wheel should have one chip per chrome ability, Arm chrome included")
	var/atom/movable/screen/chrome_wheel/chip/first_chip = wheel.chips[1]
	wheel.set_highlight(first_chip)
	TEST_ASSERT_EQUAL(first_chip.size, 26, "The chip pointed at did not grow")
	wheel.select_chip(first_chip, quiet = TRUE)
	TEST_ASSERT_EQUAL(wheel.get_selected_ability(), first_chip.ability_ref.resolve(), "Picking a chip did not pick its ability")
	TEST_ASSERT_EQUAL(length(first_chip.brackets), 4, "The picked chip did not get its lock brackets")
	wheel.close_wheel()
	TEST_ASSERT_NULL(wheel.chips, "Closing the wheel left its chips behind")

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

/**
 * Chrome abilities get no HUD button of their own and still fire from the
 * wheel; one Chrome button stands in for them while the body has chrome, shows
 * the pick, and fires a chip clicked on a wheel it opened. A printable tg
 * implant keeps its own button.
 */
/datum/unit_test/voidcrew_chrome_hud

/datum/unit_test/voidcrew_chrome_hud/Run()
	var/mob/living/carbon/human/lab_rat = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/arm/toolkit/toolset/printable = allocate(/obj/item/organ/cyberimp/arm/toolkit/toolset)
	TEST_ASSERT(printable.Insert(lab_rat, special = TRUE), "Toolset implant staging insert was refused")
	var/datum/action/toolset_toggle = locate(/datum/action/item_action/organ_action/toggle) in printable.actions
	TEST_ASSERT(toolset_toggle in lab_rat.actions, "Test fixture: the printable implant's button is not on the body")
	TEST_ASSERT_NULL(lab_rat.GetComponent(/datum/component/chrome_wheel), "A body with no chrome grew a chrome wheel")

	var/obj/item/organ/cyberimp/cyberware/test_wheel_pulse/pulse_ware = allocate(/obj/item/organ/cyberimp/cyberware/test_wheel_pulse)
	TEST_ASSERT(pulse_ware.Insert(lab_rat, special = TRUE), "Test chrome staging insert was refused")
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left/mantis = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left)
	TEST_ASSERT(mantis.Insert(lab_rat, special = TRUE), "Mantis staging insert was refused")
	var/datum/action/cooldown/cyberware/test_wheel/pulse = locate(/datum/action/cooldown/cyberware/test_wheel) in pulse_ware.actions
	var/datum/action/blade = locate(/datum/action/item_action/organ_action/toggle) in mantis.actions
	var/datum/action/lunge = locate(/datum/action/cooldown/cyberware/mantis_lunge) in mantis.actions

	// Granted, but no button: never in the body's actions, which the HUD builds buttons from.
	for(var/datum/action/ability as anything in list(pulse, blade, lunge))
		TEST_ASSERT_EQUAL(ability.owner, lab_rat, "[ability.name] was not granted to its bearer")
		TEST_ASSERT(!(ability in lab_rat.actions), "[ability.name] joined the body's actions and would get a HUD button")
	TEST_ASSERT(toolset_toggle in lab_rat.actions, "A printable tg implant lost its button")

	// The Chrome button came with the first chrome ability.
	var/datum/component/chrome_wheel/wheel = lab_rat.GetComponent(/datum/component/chrome_wheel)
	TEST_ASSERT_NOTNULL(wheel, "Chrome went in and no chrome wheel was made")
	var/datum/action/chrome_button/chrome_button = wheel.hud_button
	TEST_ASSERT_NOTNULL(chrome_button, "Chrome went in and no Chrome button was made")
	TEST_ASSERT(chrome_button in lab_rat.actions, "The Chrome button is not on the body")
	var/datum/action/chrome_arms/arms = wheel.arm_action
	TEST_ASSERT(arms && !(arms in lab_rat.actions), "Arm chrome is missing, or has a button of its own")

	// The HUD builds buttons from the body's actions; a chrome ability never asks for one.
	TEST_ASSERT(pulse.is_chrome_ability() && blade.is_chrome_ability() && arms.is_chrome_ability(), "Chrome abilities are not recognised as chrome")
	TEST_ASSERT(!toolset_toggle.is_chrome_ability(), "A printable tg implant's button was taken for chrome")
	TEST_ASSERT(!chrome_button.is_chrome_ability(), "The Chrome button hid itself")

	// Chips still wear the ability's own button look without a button on any screen.
	var/mutable_appearance/blade_look = chrome_wheel_ability_look(blade)
	TEST_ASSERT(length(blade_look.overlays), "A chip lost its item overlay without the ability's button")
	var/mutable_appearance/pulse_look = chrome_wheel_ability_look(pulse)
	TEST_ASSERT_EQUAL(pulse_look.icon_state, pulse.button_icon_state, "A chip lost its ability's icon without the ability's button")

	// No pick: the Chrome button shows the wheel. A pick: its look in the frame.
	var/list/look = chrome_button_look(chrome_button)
	TEST_ASSERT_EQUAL(look["icon_state"], "chrome", "The Chrome button with no pick does not show the chrome icon")
	TEST_ASSERT_EQUAL(look["laid"], 0, "The Chrome button with no pick shows a pick")
	wheel.select(pulse)
	look = chrome_button_look(chrome_button)
	TEST_ASSERT_EQUAL(look["laid"], 2, "The Chrome button does not show the pick in its frame")
	TEST_ASSERT(!look["icon"], "The Chrome button shows the chrome icon under its pick")

	// The pick fires from the wheel through its own Trigger(), and the button shows its cooldown.
	lab_rat.next_click = 0
	TEST_ASSERT(wheel.use_selected(), "Use chrome refused a ready pick")
	TEST_ASSERT_EQUAL(pulse.fired, 1, "A chrome ability with no button did not fire from the wheel")
	look = chrome_button_look(chrome_button)
	TEST_ASSERT(length(look["maptext"]), "The Chrome button does not count down its pick's cooldown")
	TEST_ASSERT_EQUAL(look["color"], rgb(128, 0, 0), "The Chrome button is not red while its pick cools down")
	pulse.ResetCooldown()
	look = chrome_button_look(chrome_button)
	TEST_ASSERT(!length(look["maptext"]), "The Chrome button kept counting down after the cooldown ended")

	// Offline: red, like the pick's own button would be.
	var/datum/component/cyberware/pulse_chrome = pulse_ware.GetComponent(/datum/component/cyberware)
	pulse_chrome.start_emp_reboot(EMP_HEAVY)
	look = chrome_button_look(chrome_button)
	TEST_ASSERT_EQUAL(look["color"], rgb(128, 0, 0), "The Chrome button is not red while its pick is offline")
	pulse_chrome.tune_up()
	look = chrome_button_look(chrome_button)
	TEST_ASSERT_NOTEQUAL(look["color"], rgb(128, 0, 0), "The Chrome button stayed red after its pick came back")

	// A click on the button reaches the wheel. Opening it needs a client, so here it stays shut.
	TEST_ASSERT(chrome_button.Trigger(lab_rat), "The Chrome button refused its own bearer")
	TEST_ASSERT(!wheel.is_open(), "The wheel opened with no client to draw on")

	// A wheel the Chrome button opened fires the chip clicked as well as picking it.
	pulse.ResetCooldown()
	wheel.build_wheel(get_chrome_wheel_actions(lab_rat))
	wheel.fire_on_pick = TRUE
	var/atom/movable/screen/chrome_wheel/chip/pulse_chip
	for(var/atom/movable/screen/chrome_wheel/chip/chip as anything in wheel.chips)
		if(chip.ability_ref?.resolve() == pulse)
			pulse_chip = chip
	TEST_ASSERT_NOTNULL(pulse_chip, "The built wheel has no chip for the test ability")
	lab_rat.next_click = 0
	wheel.choose(pulse_chip)
	TEST_ASSERT_EQUAL(pulse.fired, 2, "A chip clicked on a wheel the Chrome button opened was not fired")
	TEST_ASSERT(!wheel.fire_on_pick, "Closing the wheel left it firing picks")

	// The last chrome out takes the Chrome button with it; the printable implant keeps its own.
	pulse_ware.Remove(lab_rat, special = TRUE)
	TEST_ASSERT_NOTNULL(wheel.hud_button, "The Chrome button went while chrome was still in")
	mantis.Remove(lab_rat, special = TRUE)
	TEST_ASSERT_NULL(wheel.hud_button, "The Chrome button outlived the body's last chrome")
	TEST_ASSERT_NULL(wheel.arm_action, "Arm chrome outlived the body's last arm hardware")
	TEST_ASSERT(!(chrome_button in lab_rat.actions), "The Chrome button stayed on the body")
	TEST_ASSERT(toolset_toggle in lab_rat.actions, "The printable implant lost its button along with the chrome")

/// What a Chrome button drawn now looks like: built off any screen, read, and thrown away.
/datum/unit_test/voidcrew_chrome_hud/proc/chrome_button_look(datum/action/chrome_button/chrome_button)
	var/atom/movable/screen/movable/action_button/button = chrome_button.create_button()
	. = list(
		"icon" = button.icon,
		"icon_state" = button.icon_state,
		"laid" = length(button.chrome_overlays),
		"maptext" = button.maptext,
		"color" = button.color,
	)
	qdel(button)

/**
 * Arm chrome: both Mantis blades come out together and every arm goes back in
 * if any is out; an EMP'd arm and an arm whose hand is full stay put; Deploy
 * arm chrome sits on a key no other default bind uses.
 */
/datum/unit_test/voidcrew_chrome_arms

/datum/unit_test/voidcrew_chrome_arms/Run()
	var/mob/living/carbon/human/lab_rat = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/arm/toolkit/toolset/printable = allocate(/obj/item/organ/cyberimp/arm/toolkit/toolset)
	TEST_ASSERT(printable.Insert(lab_rat, special = TRUE), "Toolset implant staging insert was refused")
	TEST_ASSERT_NULL(lab_rat.GetComponent(/datum/component/chrome_wheel), "A printable tg arm implant made a chrome wheel")

	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left/left_blade = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left)
	TEST_ASSERT(left_blade.Insert(lab_rat, special = TRUE), "Left Mantis staging insert was refused")
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/right_blade = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis)
	TEST_ASSERT(right_blade.Insert(lab_rat, special = TRUE), "Right Mantis staging insert was refused")
	var/datum/component/chrome_wheel/wheel = lab_rat.GetComponent(/datum/component/chrome_wheel)
	TEST_ASSERT_NOTNULL(wheel?.arm_action, "Two Mantis housings went in and the body got no Arm chrome")
	var/list/housings = get_chrome_arm_housings(lab_rat)
	TEST_ASSERT_EQUAL(length(housings), 2, "Arm chrome should count both housings")
	TEST_ASSERT(!(printable in housings), "Arm chrome counted a printable tg implant")

	// Out together.
	lab_rat.next_click = 0
	TEST_ASSERT(wheel.use_arms(), "Deploy arm chrome refused")
	TEST_ASSERT(left_blade.blade_extended() && right_blade.blade_extended(), "Arm chrome did not deploy both Mantis blades together")
	TEST_ASSERT(chrome_wheel_ability_active(wheel.arm_action, lab_rat), "The wheel does not show Arm chrome as out")

	// Any out: all in.
	right_blade.Retract()
	TEST_ASSERT(left_blade.blade_extended() && !right_blade.blade_extended(), "Test fixture: stowing one blade by hand failed")
	lab_rat.next_click = 0
	wheel.use_arms()
	TEST_ASSERT(!left_blade.blade_extended() && !right_blade.blade_extended(), "Arm chrome with one blade out did not stow everything")

	// An EMP'd arm stays in; the other still comes out.
	var/datum/component/cyberware/right_chrome = right_blade.GetComponent(/datum/component/cyberware)
	right_chrome.start_emp_reboot(EMP_HEAVY)
	lab_rat.next_click = 0
	wheel.use_arms()
	TEST_ASSERT(left_blade.blade_extended(), "An EMP'd arm kept the working one from deploying")
	TEST_ASSERT(!right_blade.blade_extended(), "Arm chrome deployed an EMP'd arm")
	lab_rat.next_click = 0
	wheel.use_arms()
	TEST_ASSERT(!left_blade.blade_extended(), "Arm chrome did not stow the deployed arm")
	right_chrome.tune_up()

	// A full hand keeps its item, and that arm stays in.
	var/obj/item/held = allocate(/obj/item/screwdriver)
	TEST_ASSERT(lab_rat.put_in_l_hand(held), "Test fixture: the left hand would not take a screwdriver")
	lab_rat.next_click = 0
	wheel.use_arms()
	TEST_ASSERT(right_blade.blade_extended(), "A full left hand kept the right blade in")
	TEST_ASSERT(!left_blade.blade_extended(), "Arm chrome deployed into a full hand")
	TEST_ASSERT(lab_rat.is_holding(held), "Arm chrome dropped what the hand held")
	lab_rat.next_click = 0
	wheel.use_arms()
	TEST_ASSERT(!right_blade.blade_extended(), "Arm chrome did not stow the right blade")

	// Each housing keeps its own chip for single-arm use.
	var/datum/action/left_toggle = locate(/datum/action/item_action/organ_action/toggle) in left_blade.actions
	TEST_ASSERT(left_toggle in get_chrome_wheel_actions(lab_rat), "A housing's own deploy chip left the wheel")

	// Arm hardware out: Arm chrome goes with the last of it.
	left_blade.Remove(lab_rat, special = TRUE)
	TEST_ASSERT_NOTNULL(wheel.arm_action, "Arm chrome went with arm hardware still in")
	right_blade.Remove(lab_rat, special = TRUE)
	TEST_ASSERT_NULL(wheel.arm_action, "Arm chrome stayed with no arm hardware")

	// Deploy arm chrome: a default key no other bind sits on.
	var/datum/keybinding/deploy_bind = GLOB.keybindings_by_name["deploy_arm_chrome"]
	TEST_ASSERT_NOTNULL(deploy_bind, "There is no Deploy arm chrome keybind")
	for(var/default_key in deploy_bind.hotkey_keys)
		for(var/bind_name in GLOB.keybindings_by_name)
			var/datum/keybinding/other = GLOB.keybindings_by_name[bind_name]
			if(other != deploy_bind && (default_key in other.hotkey_keys))
				TEST_FAIL("Deploy arm chrome's default key [default_key] is also [other.full_name]'s")
