/**
 * # The garrotte (stealth step 3b, owner decision 12)
 *
 * Two grips and a length of wire, held in both hands. A combat-mode click on someone it can take (stealth_takedown.dm)
 * drops the wire over their head and strangles them until they're dead or the garroter lets go. On anyone it can't
 * take it does nothing: it has no force.
 *
 * Players get it as scav den loot (step 4). It has no buy, print or craft route, like the matte knife.
 */
/obj/item/garrotte
	name = "garrotte"
	desc = "Two wooden grips and a length of wire between them."
	icon = 'voidcrew/modules/stealth/icons/garrotte.dmi'
	icon_state = "garrotte"
	w_class = WEIGHT_CLASS_SMALL
	force = 0
	throwforce = 0
	attack_verb_continuous = list("whips")
	attack_verb_simple = list("whip")
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT, /datum/material/wood = SMALL_MATERIAL_AMOUNT)

/obj/item/garrotte/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/two_handed, require_twohands = TRUE)

/obj/item/garrotte/attack(mob/living/target_mob, mob/living/user, list/modifiers, list/attack_modifiers)
	if(!ishuman(target_mob) || !user.combat_mode)
		return ..()
	var/refusal = stealth_takedown_refusal(user, target_mob, STEALTH_TAKEDOWN_GARROTTE, src)
	switch(refusal)
		if(null)
			var/datum/stealth_takedown/hold = new(user, target_mob, STEALTH_TAKEDOWN_GARROTTE, src)
			INVOKE_ASYNC(hold, TYPE_PROC_REF(/datum/stealth_takedown, start))
			return TRUE
		if("front")
			user.balloon_alert(user, "can't get it over [target_mob.p_their()] head!")
			return TRUE
		if("cover")
			user.balloon_alert(user, "the wire won't bite!")
			return TRUE
	return TRUE
