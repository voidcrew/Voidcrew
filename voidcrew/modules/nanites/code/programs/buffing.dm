//Programs that buff the host in generally passive ways.

/datum/nanite_program/nervous
	name = "Nerve Support"
	desc = "The nanites act as a secondary nervous system, reducing the amount of time the host is stunned."
	use_rate = 1.5
	rogue_types = list(/datum/nanite_program/nerve_decay)

/datum/nanite_program/nervous/enable_passive_effect()
	. = ..()
	if(ishuman(host_mob))
		var/mob/living/carbon/human/H = host_mob
		H.physiology.stun_mod *= 0.5

/datum/nanite_program/nervous/disable_passive_effect()
	. = ..()
	if(ishuman(host_mob))
		var/mob/living/carbon/human/H = host_mob
		//A deleted host nulls its physiology before its nanites tear down, and runtiming here
		//would abandon the rest of /datum/component/nanites/Destroy()
		if(H.physiology)
			H.physiology.stun_mod *= 2

/datum/nanite_program/adrenaline
	name = "Adrenaline Burst"
	desc = "The nanites cause a burst of adrenaline when triggered, waking the host from stuns and temporarily increasing their speed."
	can_trigger = TRUE
	trigger_cost = 25
	trigger_cooldown = 1200
	rogue_types = list(/datum/nanite_program/toxic, /datum/nanite_program/nerve_decay)

/datum/nanite_program/adrenaline/on_trigger()
	to_chat(host_mob, span_notice("You feel a sudden surge of energy!"))
	host_mob.SetAllImmobility(0)
	host_mob.adjustStaminaLoss(-75)
	host_mob.set_resting(FALSE)
	host_mob.reagents.add_reagent(/datum/reagent/medicine/stimulants, 1.5)

/datum/nanite_program/hardening
	name = "Dermal Hardening"
	desc = "The nanites form a mesh under the host's skin."
	use_rate = 1.0
	rogue_types = list(/datum/nanite_program/skin_decay)

#define NANITE_ARMOR_BOOST_ADDED 30
#define NANITE_ARMOR_COST_PER_DAMAGE 1

//TODO on_hit effect that turns skin grey for a moment
/datum/nanite_program/hardening/enable_passive_effect()
	if(passive_enabled || !ishuman(host_mob) || nanite_armor_exhausted())
		return
	. = ..()
	if(ishuman(host_mob))
		var/mob/living/carbon/human/user = host_mob
		user.physiology.armor = user.physiology.armor.generate_new_with_modifiers(list(MELEE = NANITE_ARMOR_BOOST_ADDED, BULLET = NANITE_ARMOR_BOOST_ADDED))
		RegisterSignal(user, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(nanite_resolve_hit_armor))

/datum/nanite_program/hardening/active_effect()
	nanite_armor_exhausted()

/datum/nanite_program/hardening/disable_passive_effect()
	if(!passive_enabled)
		return
	UnregisterSignal(host_mob, COMSIG_MOB_APPLY_DAMAGE)
	. = ..()
	if(ishuman(host_mob))
		var/mob/living/carbon/human/user = host_mob
		//See /datum/nanite_program/nervous/disable_passive_effect
		if(user.physiology)
			user.physiology.armor = user.physiology.armor.generate_new_with_modifiers(list(MELEE = -NANITE_ARMOR_BOOST_ADDED, BULLET = -NANITE_ARMOR_BOOST_ADDED))

/datum/nanite_program/refractive
	name = "Dermal Refractive Surface"
	desc = "The nanites form a reflective membrane above the host's skin."
	use_rate = 1.0
	rogue_types = list(/datum/nanite_program/skin_decay)

/datum/nanite_program/refractive/enable_passive_effect()
	if(passive_enabled || !ishuman(host_mob) || nanite_armor_exhausted())
		return
	. = ..()
	if(ishuman(host_mob))
		var/mob/living/carbon/human/user = host_mob
		user.physiology.armor = user.physiology.armor.generate_new_with_modifiers(list(LASER = NANITE_ARMOR_BOOST_ADDED, ENERGY = NANITE_ARMOR_BOOST_ADDED))
		RegisterSignal(user, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(nanite_resolve_hit_armor))

/datum/nanite_program/refractive/active_effect()
	nanite_armor_exhausted()

/datum/nanite_program/refractive/disable_passive_effect()
	if(!passive_enabled)
		return
	UnregisterSignal(host_mob, COMSIG_MOB_APPLY_DAMAGE)
	. = ..()
	if(ishuman(host_mob))
		var/mob/living/carbon/human/user = host_mob
		//See /datum/nanite_program/nervous/disable_passive_effect
		if(user.physiology)
			user.physiology.armor = user.physiology.armor.generate_new_with_modifiers(list(LASER = -NANITE_ARMOR_BOOST_ADDED, ENERGY = -NANITE_ARMOR_BOOST_ADDED))

/// Both armor programs draw on the same reserve. Recovery still goes through normal upkeep.
/datum/nanite_program/proc/nanite_armor_exhausted()
	if(nanites && nanites.nanite_volume > nanites.safety_threshold)
		return FALSE
	if(nanites)
		for(var/datum/nanite_program/program in nanites.programs)
			if(program.passive_enabled && (istype(program, /datum/nanite_program/hardening) || istype(program, /datum/nanite_program/refractive)))
				program.disable_passive_effect()
	return TRUE

/**
 * Bill only the incremental armor supplied by this program, once apply_damage accepts a hit.
 * The signal has no armor category: projectiles supply theirs, items use melee, and source-less
 * brute/burn hits fall back to melee/laser. Unknown caller modifiers are approximated by treating
 * the reported blocked value as the cap. Forced hits with blocked = 0 and direct limb damage
 * are intentionally unbilled. An underfunded hit keeps its already calculated protection.
 */
/datum/nanite_program/proc/nanite_resolve_hit_armor(mob/living/carbon/human/source, damage, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, attacking_item)
	SIGNAL_HANDLER
	if(!passive_enabled || damage <= 0 || blocked <= 0 || blocked >= 100 || (damagetype != BRUTE && damagetype != BURN))
		return
	if(nanite_armor_exhausted())
		return

	var/armor_flag = damagetype == BRUTE ? MELEE : LASER
	var/penetration = 0
	var/weak_against_armor = FALSE
	if(istype(attacking_item, /obj/projectile))
		var/obj/projectile/projectile = attacking_item
		armor_flag = projectile.armor_flag
		penetration = projectile.armour_penetration
		weak_against_armor = projectile.weak_against_armour
	else if(isitem(attacking_item))
		var/obj/item/weapon = attacking_item
		armor_flag = MELEE
		penetration = weapon.armour_penetration
		weak_against_armor = weapon.weak_against_armour
	if(istype(src, /datum/nanite_program/hardening))
		if(armor_flag != MELEE && armor_flag != BULLET)
			return
	else if(armor_flag != LASER && armor_flag != ENERGY)
		return

	// Rebuild clothing's multiplicative remainder without temporarily changing the host's armor.
	var/list/parts = isbodypart(def_zone) ? list(def_zone) : source.bodyparts
	var/clothing_remainder = 0
	for(var/obj/item/bodypart/part in parts)
		var/part_remainder = 1
		for(var/obj/item/clothing/clothing in source.get_clothing_on_part(part))
			part_remainder *= (100 - min(clothing.get_armor_rating(armor_flag), 100)) / 100
		clothing_remainder += part_remainder
	clothing_remainder /= max(length(parts), 1)
	var/armor_with = source.getarmor(def_zone, armor_flag)
	var/physiology_without = source.physiology.armor.get_rating(armor_flag) - NANITE_ARMOR_BOOST_ADDED
	var/armor_without = 100 - clothing_remainder * (100 - min(physiology_without, 100))
	if(weak_against_armor)
		armor_with *= ARMOR_WEAKENED_MULTIPLIER
		armor_without *= ARMOR_WEAKENED_MULTIPLIER
	if(armor_with > 0)
		armor_with = max(0, PENETRATE_ARMOUR(armor_with, penetration))
	if(armor_without > 0)
		armor_without = max(0, PENETRATE_ARMOUR(armor_without, penetration))
	var/armor_delta = max(0, min(blocked, armor_with) - min(blocked, armor_without))
	var/cost = damage * armor_delta / (100 - blocked) * NANITE_ARMOR_COST_PER_DAMAGE
	if(cost <= 0)
		return

	var/datum/component/nanites/swarm = nanites
	var/available = max(0, swarm.nanite_volume - swarm.safety_threshold)
	if(cost >= available)
		// Disable before withdrawing: a zero-safety swarm deletes itself at zero volume.
		for(var/datum/nanite_program/program in swarm.programs)
			if(program.passive_enabled && (istype(program, /datum/nanite_program/hardening) || istype(program, /datum/nanite_program/refractive)))
				program.disable_passive_effect()
	swarm.adjust_nanites(null, -min(cost, available))

#undef NANITE_ARMOR_COST_PER_DAMAGE
#undef NANITE_ARMOR_BOOST_ADDED

/datum/nanite_program/coagulating
	name = "Rapid Coagulation"
	desc = "The nanites induce rapid coagulation when the host is wounded, dramatically reducing bleeding rate."
	use_rate = 0.10
	rogue_types = list(/datum/nanite_program/suffocating)

/datum/nanite_program/coagulating/enable_passive_effect()
	. = ..()
	if(ishuman(host_mob))
		var/mob/living/carbon/human/H = host_mob
		H.physiology.bleed_mod *= 0.1

/datum/nanite_program/coagulating/disable_passive_effect()
	. = ..()
	if(ishuman(host_mob))
		var/mob/living/carbon/human/H = host_mob
		//See /datum/nanite_program/nervous/disable_passive_effect
		if(H.physiology)
			H.physiology.bleed_mod *= 10

/datum/nanite_program/conductive
	name = "Electric Conduction"
	desc = "The nanites act as a grounding rod for electric shocks, protecting the host. Shocks can still damage the nanites themselves."
	use_rate = 0.20
	program_flags = NANITE_SHOCK_IMMUNE
	rogue_types = list(/datum/nanite_program/nerve_decay)

/datum/nanite_program/conductive/enable_passive_effect()
	. = ..()
	ADD_TRAIT(host_mob, TRAIT_SHOCKIMMUNE, TRAIT_NANITES)

/datum/nanite_program/conductive/disable_passive_effect()
	. = ..()
	REMOVE_TRAIT(host_mob, TRAIT_SHOCKIMMUNE, TRAIT_NANITES)

/datum/nanite_program/mindshield
	name = "Mental Barrier"
	desc = "The nanites form a protective membrane around the host's brain, shielding them from abnormal influences while they're active."
	use_rate = 0.40
	rogue_types = list(/datum/nanite_program/brain_decay, /datum/nanite_program/brain_misfire)

/datum/nanite_program/mindshield/enable_passive_effect()
	. = ..()
	if(!host_mob.mind.has_antag_datum(/datum/antagonist/rev, TRUE)) //won't work if on a rev, to avoid having implanted revs.
		ADD_TRAIT(host_mob, TRAIT_MINDSHIELD, TRAIT_NANITES)
		host_mob.sec_hud_set_implants()

/datum/nanite_program/mindshield/disable_passive_effect()
	. = ..()
	REMOVE_TRAIT(host_mob, TRAIT_MINDSHIELD, TRAIT_NANITES)
	host_mob.sec_hud_set_implants()
