// Voidcrew Modular Edit: Restore Natural Decapitation
// Reverts tgstation PR #80703 which replaced natural beheading with cranial fissures
// This allows heads to be dismembered through normal damage again

// Override the head bodypart to allow natural dismemberment
/obj/item/bodypart/head
	can_dismember = TRUE

// Override can_dismember to use the standard parent logic instead of the restrictive checks
// The base proc just checks for BODYPART_UNREMOVABLE and TRAIT_NODISMEMBER
/obj/item/bodypart/head/can_dismember(obj/item/item)
	if(bodypart_flags & BODYPART_UNREMOVABLE || (owner && HAS_TRAIT(owner, TRAIT_NODISMEMBER)))
		return FALSE
	return TRUE

// Disable cranial fissure wounds entirely by making their weight always 0
/datum/wound_pregen_data/cranial_fissure/get_weight(obj/item/bodypart/limb, woundtype, damage, attack_direction, damage_source)
	return 0
