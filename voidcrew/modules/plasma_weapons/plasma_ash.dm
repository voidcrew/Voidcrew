// Package: P1 bolt. Ash dismemberment: the COMSIG_MOB_AFTER_APPLY_DAMAGE handler that burns away an
// arm or leg through tg's own burn dismemberment.

/// Registered on a carbon this bolt hits; runs once, after the bolt's damage lands. An arm or leg left
/// within ash_margin of its max damage burns away through tg's WOUND_BURN loss (no spray, ash decal).
/// Heads and chests are never ashed here.
/obj/projectile/energy/plasma_bolt/proc/plasma_check_ash(mob/living/carbon/source, damage_dealt, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, attacking_item)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_MOB_AFTER_APPLY_DAMAGE)
	if(attacking_item != src || !iscarbon(source))
		return
	var/obj/item/bodypart/limb = isbodypart(def_zone) ? def_zone : source.get_bodypart(check_zone(def_zone))
	if(!limb || limb.owner != source || !(limb.body_zone in GLOB.limb_zones))
		return
	if(!limb.can_dismember() || (limb.bodypart_flags & BODYPART_UNREMOVABLE))
		return
	if(limb.get_damage() < limb.max_damage - ash_margin)
		return
	var/datum/wound/loss/ash = new
	ash.apply_dismember(limb, WOUND_BURN, FALSE, attack_direction)
