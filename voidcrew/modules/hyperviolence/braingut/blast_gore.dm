// Blast gore (hyperviolence, braingut part): a heavy explosion can burst the head of a victim who is
// already down. It rolls against the victim's bomb armour. A blast that splits a chest open does so
// through tg's own chest spill, which brings the intestines out with the other organs (gut_spill.dm).

/mob/living/carbon/human/ex_act(severity, target, origin)
	. = ..()
	if(!. || severity != EXPLODE_HEAVY || QDELETED(src))
		return
	if(stat < HARD_CRIT || !prob(HV_HEAD_BURST_EXPLOSION_CHANCE) || prob(getarmor(get_bodypart(BODY_ZONE_HEAD), BOMB)))
		return
	hv_burst_head()
