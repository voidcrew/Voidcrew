// Voidcrew extensions to code/modules/antagonists/abductor/equipment/glands/heal.dm.

/obj/item/organ/heart/gland/heal/on_mob_remove(mob/living/carbon/gland_owner, special, movement_flags)
	healing_generation++
	return ..()

/// Removal invalidates pending work even if this gland returns to the same body.
/obj/item/organ/heart/gland/heal/proc/can_finish_healing(mob/living/carbon/recipient, generation)
	return !QDELETED(src) && !QDELETED(recipient) && owner == recipient && active && generation == healing_generation && ownerCheck()
// VOIDCREW ADD END

/obj/item/organ/heart/gland/heal
	var/healing_generation = 0
