// Tutorial checklist hook: a finished chrome execution (Cyberware item).
// The three cyberware finishers are separate engine types: the Gorilla Arms moves (/datum/hv_finisher/chrome),
// the Mantis Blades scissor and the Widowline garrote. Boss finishers and gun executions don't count.
// Hooked on the shared stop() so each line is covered; returns the parent's value unchanged.

/// The finishers that count as a cyberware execution.
GLOBAL_LIST_INIT(tutorial_chrome_finisher_types, typecacheof(list(
	/datum/hv_finisher/chrome,
	/datum/hv_finisher/garrote,
	/datum/hv_finisher/mantis_scissor,
)))

/datum/hv_finisher/stop(reason)
	// Captured first: the end callback can delete the finisher inside the parent.
	var/was_running = running
	var/mob/living/doer = user
	var/killed = completed
	. = ..()
	if(!was_running || !(killed || reason == HV_FINISHER_DONE))
		return
	if(!doer?.ckey || !GLOB.tutorial_chrome_finisher_types[type])
		return
	tutorial_credit(doer, TUTORIAL_STEP_CHROME_EXECUTE)

// ---- chrome-surgery: helpers for the Cyberware item's pointers and live lines ----

/// Whether a bought item path is chrome for the Buy chrome step: implants, cyberware eyes and the
/// cased sets. Not the empty autosurgeon: it can't fit chrome.
/proc/tutorial_is_chrome_path(path)
	return ispath(path, /obj/item/organ/cyberimp) || ispath(path, /obj/item/organ/eyes/robotic/cyberware) \
		|| ispath(path, /obj/item/cyberware_pair_case) || ispath(path, /obj/item/storage/case/cyberware)

/// Whether a trader's shelf holds any chrome. Cached per shop type: shelves are fixed lists.
/proc/tutorial_shop_sells_chrome(datum/outpost_shop/shop)
	if(!shop)
		return FALSE
	var/static/list/sells_by_type = list()
	if(isnull(sells_by_type[shop.type]))
		var/sells = FALSE
		for(var/datum/shop_sku/sku_type as anything in shop.sku_types)
			if(ispath(sku_type, /datum/shop_sku) && tutorial_is_chrome_path(initial(sku_type.item_path)))
				sells = TRUE
				break
		sells_by_type[shop.type] = sells
	return sells_by_type[shop.type]

/// The first loose piece of chrome [user] carries (hands, pockets, bags, cases), or null.
/proc/tutorial_carried_chrome(mob/living/carbon/user)
	if(!iscarbon(user))
		return null
	for(var/obj/item/organ/ware in user.get_all_contents())
		if(ware.owner || !ware.GetComponent(/datum/component/cyberware))
			continue
		return ware
	return null

/**
 * What finisher [user]'s fitted chrome gives them, for the Do an execution step.
 * Returns list(line, can_finish): a short how-to line or null, and TRUE when they own a working one.
 */
/proc/tutorial_chrome_finisher_state(mob/living/carbon/user)
	if(!iscarbon(user))
		return list(null, FALSE)
	if(gorilla_synced(user))
		return list("Gorilla Arms: hands empty, aim at the head, an arm or the chest.", TRUE)
	if(brawler_synced(user))
		return list("Brawler Myomers: hands empty, aim at an arm.", TRUE)
	var/wire = FALSE
	var/scissor_housings = 0
	var/shiv_housings = 0
	var/gorilla_arms = 0
	for(var/obj/item/organ/organ in user.organs)
		if(organ.owner != user)
			continue
		if(istype(organ, /obj/item/organ/cyberimp/arm/toolkit/cyberware/monowire))
			wire = TRUE
		else if(istype(organ, /obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis))
			var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing = organ
			var/scissors = FALSE
			for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade_type as anything in housing.items_to_create)
				if(ispath(blade_type, /obj/item/melee/energy/blade/hardlight/cyberware_mantis) && (initial(blade_type.gore_moves) & MANTIS_MOVE_SCISSOR))
					scissors = TRUE
			if(scissors)
				scissor_housings++
			else
				shiv_housings++
		else if(istype(organ, /obj/item/organ/cyberimp/cyberware/gorilla_arms))
			gorilla_arms++
	if(scissor_housings >= 2)
		return list("Mantis Blades: both blades out, aim at the head.", TRUE)
	if(wire)
		return list("Widowline: wire out, aim at the head.", TRUE)
	if(scissor_housings || gorilla_arms)
		return list("Only one arm of the pair is working.", FALSE)
	if(shiv_housings)
		return list("Shiv Blades can't finish anyone.", FALSE)
	return list("Nothing fitted can finish someone yet.", FALSE)
