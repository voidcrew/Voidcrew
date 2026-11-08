// Blast gore (hyperviolence, braingut part): a heavy explosion can burst the head of a victim who is
// already down, and can blow open the belly of any victim. Both roll against the victim's bomb armour.

/mob/living/carbon/human/ex_act(severity, target, origin)
	. = ..()
	if(!. || severity != EXPLODE_HEAVY || QDELETED(src))
		return
	var/downed = stat >= HARD_CRIT
	if(downed && prob(HV_HEAD_BURST_EXPLOSION_CHANCE) && !prob(getarmor(get_bodypart(BODY_ZONE_HEAD), BOMB)))
		hv_burst_head()
	var/obj/item/bodypart/chest/chest = get_bodypart(BODY_ZONE_CHEST)
	if(!chest || !chest.hv_chest_can_spill())
		return
	if(!prob(downed ? HV_GUTSPILL_EXPLOSION_CHANCE_DOWNED : HV_GUTSPILL_EXPLOSION_CHANCE))
		return
	if(prob(getarmor(chest, BOMB)))
		return
	chest.hv_spill_guts(null, "explosion")
