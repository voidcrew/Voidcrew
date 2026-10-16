// Capacity checks run before upstream can evict, consume or move an installed item.
/obj/item/organ/Insert(mob/living/carbon/receiver, special = FALSE, movement_flags)
	// Chrome has already checked its install context, including forced admin installs.
	if(!special && !GetComponent(/datum/component/cyberware) && !cyberware_insert_check(src, receiver))
		return FALSE
	. = ..()
	if(.)
		cyberware_reevaluate_brownout(receiver)

/obj/item/organ/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	cyberware_reevaluate_brownout(organ_owner)

/obj/item/organ/apply_organ_damage(damage_amount, maximum = maxHealth, required_organ_flag = NONE)
	. = ..()
	var/datum/component/cyberware/chrome = GetComponent(/datum/component/cyberware)
	chrome?.update_failing()

/obj/item/organ/set_organ_damage(damage_amount, required_organ_flag = NONE)
	. = ..()
	var/datum/component/cyberware/chrome = GetComponent(/datum/component/cyberware)
	chrome?.update_failing()

/obj/item/organ/pre_surgical_insertion(mob/living/user, mob/living/carbon/new_owner, target_zone)
	. = ..()
	if(.)
		return cyberware_insert_check(src, new_owner, feedback_to = user)

// Surgery has its own delay, then unequips the organ before calling Insert().
// Recheck here so a late capacity refusal leaves it in the surgeon's hands.
/datum/surgery_step/manipulate_organs/success(mob/living/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery, default_display_results = FALSE)
	if(current_type == "insert" && (QDELETED(target_organ) || !cyberware_insert_check(target_organ, target, feedback_to = user)))
		return SURGERY_STEP_FAIL
	return ..()

/obj/item/implant/implant(mob/living/target, mob/user, silent = FALSE, force = FALSE)
	if(!force && iscarbon(target))
		var/list/replaced = list()
		// Upstream combines duplicate implants instead of adding a second object.
		if(!allow_multiple)
			for(var/obj/item/implant/incumbent in target.implants)
				if(istype(incumbent, type))
					replaced += incumbent
					break
		if(!installed_capacity_check(target, list(src), replaced, silent))
			return FALSE
	. = ..()
	if(.)
		cyberware_reevaluate_brownout(target)

/obj/item/implant/removed(mob/living/source, silent = FALSE, special = 0)
	. = ..()
	cyberware_reevaluate_brownout(source)

/// Limbs are free, but the organs carried inside them are not.
/obj/item/bodypart/proc/installed_capacity_can_attach(mob/living/carbon/receiver)
	var/list/additions = list(src)
	var/list/removals = list()
	var/obj/item/bodypart/incumbent_limb = receiver.get_bodypart(body_zone)
	if(incumbent_limb != src)
		removals += incumbent_limb
	for(var/obj/item/organ/organ in src)
		additions |= organ
		removals |= organ.cyberware_get_incumbents(receiver)
	return installed_capacity_check(receiver, additions, removals)

/obj/item/bodypart/replace_limb(mob/living/carbon/limb_owner, special)
	if(istype(limb_owner) && !installed_capacity_can_attach(limb_owner))
		return FALSE
	return ..()

/obj/item/bodypart/try_attach_limb(mob/living/carbon/new_limb_owner, special, lazy)
	if(!lazy && !installed_capacity_can_attach(new_limb_owner))
		return FALSE
	. = ..()
	if(.)
		cyberware_reevaluate_brownout(new_limb_owner)

// Reject before status_effect/on_creation assigns owner: a rejected enhancement
// must not run bioware_lost() for a benefit it never granted.
/datum/status_effect/bioware/on_creation(mob/living/new_owner, ...)
	if(!installed_capacity_check(new_owner, list(src)))
		qdel(src)
		return FALSE
	. = ..()
	if(.)
		cyberware_reevaluate_brownout(new_owner)

/datum/status_effect/bioware/on_remove()
	. = ..()
	cyberware_reevaluate_brownout(owner)
