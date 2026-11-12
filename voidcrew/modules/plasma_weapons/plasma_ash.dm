// Package: P1 bolt. Melted limbs: the COMSIG_MOB_AFTER_APPLY_DAMAGE handler that burns away an arm or leg
// through tg's own burn dismemberment.

/// Registered on a carbon this bolt hits; runs once, after the bolt's damage lands. First sears the bleeding
/// cuts on the hit limb, any zone. Then the arm or leg melts
/// through tg's WOUND_BURN loss (no spray, ash decal) when it was already hurt before this bolt
/// (PLASMA_ASH_PRIOR_DAMAGE) and is now within ash_margin of its max damage, or, for a rifle bolt, when
/// it already carried a plasma burn-through with slag still in it. No bolt melts an unhurt limb in one hit.
/// Heads and chests never melt.
/obj/projectile/energy/plasma_bolt/proc/plasma_check_ash(mob/living/carbon/source, damage_dealt, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, attacking_item)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_MOB_AFTER_APPLY_DAMAGE)
	if(attacking_item != src || !iscarbon(source))
		return
	var/obj/item/bodypart/limb = isbodypart(def_zone) ? def_zone : source.get_bodypart(check_zone(def_zone))
	if(!limb || limb.owner != source || limb.body_zone != ash_zone)
		return
	plasma_sear_cuts(limb)
	if(!(limb.body_zone in GLOB.limb_zones))
		return
	if(!limb.can_dismember() || (limb.bodypart_flags & BODYPART_UNREMOVABLE))
		return
	var/burned_through = ash_critical_burns && ash_prior_critical
	var/worn_through = ash_prior_damage >= PLASMA_ASH_PRIOR_DAMAGE && limb.get_damage() >= limb.max_damage - ash_margin
	if(!burned_through && !worn_through)
		return
	plasma_melt_limb(limb, attack_direction) // tg's WOUND_BURN loss, plus the melt picture (plasma_melt.dm)
