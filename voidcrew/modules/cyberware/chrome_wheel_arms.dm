/**
 * # Arm chrome
 *
 * One ability that deploys or stows all of the bearer's arm hardware at once:
 * the toolkit arms that put something in a hand (Mantis, Shiv and Scorch
 * pairs, Widowline, Rockjaw, Fixer's, Ronin and Holdout, Bunker Buster). Arm
 * chrome with nothing to hand out (Icepick, Skyhook, Graverobber, Angler,
 * Gorilla) is left alone.
 *
 * If anything is out, everything goes back in. Otherwise every arm that can
 * deploys: running chrome, its own button usable, a free hand on its side.
 * A held item is never dropped to make room, so a full hand just keeps its
 * arm stowed, and an EMP'd or browned-out arm stays put. A pair comes out
 * together because both housings deploy in the same press.
 *
 * The bearer's chrome wheel owns the ability (chrome_wheel.dm sync_abilities())
 * and gives it a fixed chip at the top of the right arm's arc. It has no HUD
 * button, like every chrome ability (chrome_hud.dm); the "Deploy arm chrome"
 * key fires it (chrome_wheel_keybindings.dm).
 */
/datum/action/chrome_arms
	name = "Arm chrome"
	button_icon = CHROME_HUD_ICON
	button_icon_state = "arms"
	check_flags = AB_CHECK_CONSCIOUS

/datum/action/chrome_arms/is_chrome_ability()
	return TRUE

/datum/action/chrome_arms/Trigger(mob/clicker, trigger_flags)
	. = ..()
	if(!.)
		return FALSE
	return chrome_arms_toggle(owner)

/// The bearer's installed arm chrome that hands something out, deployed or not.
/proc/get_chrome_arm_housings(mob/living/carbon/bearer)
	RETURN_TYPE(/list)
	. = list()
	for(var/obj/item/organ/cyberimp/arm/toolkit/cyberware/housing in get_installed_cyberware(bearer))
		if(housing.chrome_arm_item())
			. += housing

/**
 * Stows every deployed arm if any is out, or else deploys every arm that can.
 * Returns whether anything moved.
 */
/proc/chrome_arms_toggle(mob/living/carbon/bearer)
	var/list/housings = get_chrome_arm_housings(bearer)
	if(!length(housings))
		bearer?.balloon_alert(bearer, "no arm chrome!")
		return FALSE
	var/list/deployed = list()
	for(var/obj/item/organ/cyberimp/arm/toolkit/cyberware/housing as anything in housings)
		if(housing.chrome_arm_deployed())
			deployed += housing
	if(length(deployed))
		for(var/obj/item/organ/cyberimp/arm/toolkit/cyberware/housing as anything in deployed)
			housing.Retract()
		return TRUE
	if(HAS_TRAIT(bearer, TRAIT_INCAPACITATED))
		bearer.balloon_alert(bearer, "incapacitated!")
		return FALSE
	if(HAS_TRAIT(bearer, TRAIT_HANDS_BLOCKED))
		bearer.balloon_alert(bearer, "hands blocked!")
		return FALSE
	var/out = 0
	var/hands_full = FALSE
	for(var/obj/item/organ/cyberimp/arm/toolkit/cyberware/housing as anything in housings)
		if(housing.chrome_arm_deploy())
			out++
		else if(housing.chrome_arm_can_run() && !housing.chrome_arm_hand_free())
			hands_full = TRUE
	if(!out)
		bearer.balloon_alert(bearer, hands_full ? "hands full!" : "chrome offline!")
	return out > 0

/// The first thing this arm hands out, while it is still stowed in it or out in a hand; null for arm chrome with nothing to hand out.
/obj/item/organ/cyberimp/arm/toolkit/cyberware/proc/chrome_arm_item()
	for(var/datum/weakref/item_ref as anything in items_list)
		var/obj/item/stowed = item_ref.resolve()
		if(stowed)
			return stowed
	return null

/// Whether this arm's item is out of the housing.
/obj/item/organ/cyberimp/arm/toolkit/cyberware/proc/chrome_arm_deployed()
	// The toolkit sets active_item before it knows a hand was free, so "out" is "not in us".
	return active_item && !(active_item in src)

/// Whether the chrome runs and its own deploy button could be pressed.
/obj/item/organ/cyberimp/arm/toolkit/cyberware/proc/chrome_arm_can_run()
	var/datum/component/cyberware/chrome = GetComponent(/datum/component/cyberware)
	if(!owner || !chrome?.is_running())
		return FALSE
	var/datum/action/toggle = locate(/datum/action/item_action/organ_action/toggle) in actions
	return !toggle || toggle.IsAvailable()

/// Whether the hand on this arm's side is empty.
/obj/item/organ/cyberimp/arm/toolkit/cyberware/proc/chrome_arm_hand_free()
	return !!owner?.get_empty_held_index_for_side(zone == BODY_ZONE_R_ARM ? RIGHT_HANDS : LEFT_HANDS)

/// Puts this arm's first item in its hand, if the chrome runs and the hand is empty. Returns whether it came out.
/obj/item/organ/cyberimp/arm/toolkit/cyberware/proc/chrome_arm_deploy()
	if(chrome_arm_deployed() || !chrome_arm_can_run() || !chrome_arm_hand_free())
		return FALSE
	var/obj/item/augment = chrome_arm_item()
	if(!augment || !(augment in src))
		return FALSE
	Extend(augment)
	return chrome_arm_deployed()
