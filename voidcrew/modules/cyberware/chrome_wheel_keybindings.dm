/**
 * The chrome wheel's binds (chrome_wheel.dm). Defaults sit on V, the one free
 * letter by the movement keys: hold V for the wheel, Shift+V fires the pick
 * (beside tg's Shift+E/Q/B variants), Ctrl+V fires the OS and Alt+V deploys or
 * stows all arm chrome (chrome_wheel_arms.dm). Alt alone is tg's "Block
 * movement", held only for the moment the combo is down. All of them rebind in
 * the keybind settings like any other.
 */
/datum/keybinding/living/chrome

/datum/keybinding/living/chrome/can_use(client/user)
	return iscarbon(user.mob)

/// The bearer's wheel, or null with a "no chrome" balloon for a body without any.
/datum/keybinding/living/chrome/proc/get_wheel(client/user)
	var/mob/living/carbon/bearer = user.mob
	if(bearer.stat == DEAD)
		return null
	var/datum/component/chrome_wheel/wheel = get_chrome_wheel(bearer)
	if(!wheel)
		bearer.balloon_alert(bearer, "no chrome!")
	return wheel

/datum/keybinding/living/chrome/wheel
	hotkey_keys = list("V")
	name = CHROME_WHEEL_KEYBIND
	full_name = "Chrome wheel"
	description = "Hold to pick a chrome ability."
	keybind_signal = COMSIG_KB_LIVING_CHROME_WHEEL_DOWN

/datum/keybinding/living/chrome/wheel/down(client/user, turf/target)
	. = ..()
	if(.)
		return
	get_wheel(user)?.wheel_key_down()
	return TRUE

/datum/keybinding/living/chrome/wheel/up(client/user, turf/target)
	. = ..()
	if(.)
		return
	var/datum/component/chrome_wheel/wheel = user.mob.GetComponent(/datum/component/chrome_wheel)
	wheel?.wheel_key_up()

/datum/keybinding/living/chrome/use
	hotkey_keys = list("ShiftV")
	name = "use_chrome"
	full_name = "Use chrome"
	description = "Use the chrome ability picked on the wheel."
	keybind_signal = COMSIG_KB_LIVING_USE_CHROME_DOWN

/datum/keybinding/living/chrome/use/down(client/user, turf/target)
	. = ..()
	if(.)
		return
	get_wheel(user)?.use_selected()
	return TRUE

/datum/keybinding/living/chrome/use_os
	hotkey_keys = list("CtrlV")
	name = "use_os_chrome"
	full_name = "Use OS chrome"
	description = "Use your operating system chrome."
	keybind_signal = COMSIG_KB_LIVING_USE_OS_CHROME_DOWN

/datum/keybinding/living/chrome/use_os/down(client/user, turf/target)
	. = ..()
	if(.)
		return
	get_wheel(user)?.use_os()
	return TRUE

/datum/keybinding/living/chrome/deploy_arms
	hotkey_keys = list("AltV")
	name = "deploy_arm_chrome"
	full_name = "Deploy arm chrome"
	description = "Deploy or stow all your arm chrome."
	keybind_signal = COMSIG_KB_LIVING_DEPLOY_ARM_CHROME_DOWN

/datum/keybinding/living/chrome/deploy_arms/down(client/user, turf/target)
	. = ..()
	if(.)
		return
	get_wheel(user)?.use_arms()
	return TRUE
