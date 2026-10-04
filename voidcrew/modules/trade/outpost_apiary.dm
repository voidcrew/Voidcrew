/**
 * Outpost apiaries: bees that live in an apiary an outpost was built with never sting anyone.
 * Stock bees go for anybody near the hive without a beekeeper suit, which in a trader outpost's
 * garden means every shopper walking past. Keyed on the bee's home rather than on
 * TRAIT_OUTPOST_RESIDENT, so the bees the apiary breeds later to replace squashed ones stay
 * calm too. Apiaries players bring or build are not outpost property and keep stock bees.
 */

/// Whether this bee's home is an apiary that came with an outpost.
/mob/living/basic/bee/proc/is_outpost_bee()
	return !isnull(beehome) && HAS_TRAIT(beehome, TRAIT_OUTPOST_PROPERTY)

/datum/targeting_strategy/basic/bee/can_attack(mob/living/owner, atom/target, vision_range)
	var/mob/living/basic/bee/bee = owner
	if(istype(bee) && bee.is_outpost_bee())
		return FALSE
	return ..()
