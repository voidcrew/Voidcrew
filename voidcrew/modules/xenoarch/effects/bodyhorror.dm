// Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/effects/bodyhorror.dm.
// Voidcrew: half as likely in green; one victim per burst; not harvestable; logged.

/datum/artifact_effect/bodyhorror
	label_name = "Twists flesh"
	log_name = "Body horror"
	tier = ARTIFACT_TIER_EXTREME
	harvestable = FALSE
	harmful = TRUE
	green_weight = 0.5
	possible_kinds = list(ARTIFACT_ENERGY_ORGANIC)
	allowed_release_methods = list(ARTIFACT_RELEASE_PULSE)

/datum/artifact_effect/bodyhorror/setup()
	range = min(range, 4)

/datum/artifact_effect/bodyhorror/do_effect_pulse(power)
	var/list/victims = list()
	for(var/mob/living/carbon/target in living_in_range())
		if(target.stat == DEAD || HAS_TRAIT(target, TRAIT_NODISMEMBER) || artifact_exposure(target) <= 0.5)
			continue
		victims += target
	while(length(victims))
		if(mutate_limb(pick_n_take(victims)))
			return

/// Swaps one arm or leg (or a missing one) for a living flesh limb. Returns TRUE if it did.
/datum/artifact_effect/bodyhorror/proc/mutate_limb(mob/living/carbon/target)
	var/list/zones = target.get_missing_limbs()
	for(var/obj/item/bodypart/part as anything in target.bodyparts)
		if(part.body_zone == BODY_ZONE_HEAD || part.body_zone == BODY_ZONE_CHEST)
			continue
		if(HAS_TRAIT(part, TRAIT_IGNORED_BY_LIVING_FLESH) || (part.bodypart_flags & BODYPART_UNREMOVABLE))
			continue
		zones += part.body_zone
	if(!length(zones))
		return FALSE
	var/zone = pick(zones)
	var/part_type
	switch(zone)
		if(BODY_ZONE_L_ARM)
			part_type = /obj/item/bodypart/arm/left/flesh
		if(BODY_ZONE_R_ARM)
			part_type = /obj/item/bodypart/arm/right/flesh
		if(BODY_ZONE_L_LEG)
			part_type = /obj/item/bodypart/leg/left/flesh
		if(BODY_ZONE_R_LEG)
			part_type = /obj/item/bodypart/leg/right/flesh
	if(!part_type)
		return FALSE
	var/obj/item/bodypart/old_part = target.get_bodypart(zone)
	if(old_part)
		old_part.dismember()
	else
		target.emote("scream")
	target.visible_message(
		span_danger("[target]'s limb swells and splits, and something red and living pushes out of it!"),
		span_userdanger("Your limb swells and splits, and something red and living pushes out of it!"),
		blind_message = span_hear("You hear tearing flesh and cracking bone."),
	)
	// The same steps the living flesh mob uses to take a limb (ruin_defender/flesh.dm).
	var/obj/item/bodypart/new_part = new part_type()
	var/mob/living/basic/living_limb_flesh/parasite = new
	parasite.forceMove(new_part)
	new_part.replace_limb(target, TRUE)
	parasite.register_to_limb(new_part)
	log_harm(target)
	return TRUE
