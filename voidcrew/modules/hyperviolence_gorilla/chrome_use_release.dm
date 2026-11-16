/**
 * # Use chrome, let go
 *
 * A hook for charged chrome on the chrome wheel (cyberware/chrome_wheel*.dm): when the Use chrome key comes
 * back up, the picked ability hears it through chrome_use_released(). The Gorilla haymaker throws its
 * charge there. Kept in its own file so other charged chrome can share it.
 */

/**
 * The bearer let go of the Use chrome key with this ability picked. A charged ability can throw what
 * it built up. Returns TRUE if it did something. Every other ability ignores it.
 */
/datum/action/proc/chrome_use_released(mob/living/carbon/bearer)
	return FALSE

/datum/keybinding/living/chrome/use/up(client/user, turf/target)
	. = ..()
	if(.)
		return
	var/mob/living/carbon/bearer = user.mob
	if(!iscarbon(bearer))
		return
	var/datum/component/chrome_wheel/wheel = bearer.GetComponent(/datum/component/chrome_wheel)
	var/datum/action/picked = wheel?.get_selected_ability()
	picked?.chrome_use_released(bearer)
