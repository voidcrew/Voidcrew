/**
 * # Fire extinguishers are not bulky
 *
 * Upstream ships the standard red extinguisher at WEIGHT_CLASS_BULKY, so it can
 * only be carried in a hand, a suit slot or a back slot. On a ship where every
 * compartment is a potential fire and the crew is small enough that nobody is a
 * dedicated firefighter, that means the extinguisher gets left in its cabinet.
 * Dropping it to WEIGHT_CLASS_NORMAL lets it ride in a backpack.
 *
 * The catch is upstream's wind-up head bash (attack_secondary), which gates
 * itself on `w_class < WEIGHT_CLASS_BULKY`, lowering the weight class silently
 * deletes the attack. The override below keeps the bash and re-gates it on an
 * explicit `can_wallop` var instead, so the two are no longer coupled and a
 * future weight change can't quietly remove a combat feature again.
 *
 * `can_wallop` is set to preserve exactly who could bash before this file: the
 * full-size extinguisher and the firefighter backpack nozzle, but not the
 * pocket, crafted or foam models.
 */
/obj/item/extinguisher
	w_class = WEIGHT_CLASS_NORMAL
	/// Whether this extinguisher is heavy enough to wind up a head bash with.
	var/can_wallop = TRUE

/obj/item/extinguisher/mini
	can_wallop = FALSE

/obj/item/extinguisher/mini/nozzle
	can_wallop = TRUE

/obj/item/extinguisher/crafted
	can_wallop = FALSE

/obj/item/extinguisher/advanced
	can_wallop = FALSE

/**
 * A copy of upstream's attack_secondary (code/game/objects/items/extinguisher.dm)
 * with the weight-class gate swapped for `can_wallop`. Everything else is
 * verbatim, if upstream retunes the bash, re-sync this body.
 */
/obj/item/extinguisher/attack_secondary(mob/living/victim, mob/living/user, params)
	if(!can_wallop)
		return SECONDARY_ATTACK_CALL_NORMAL

	if(issilicon(user))
		return SECONDARY_ATTACK_CALL_NORMAL

	if(!iscarbon(victim))
		return SECONDARY_ATTACK_CALL_NORMAL

	var/mob/living/carbon/wallopee = victim
	var/obj/item/bodypart/head/head_to_bash = wallopee.get_bodypart(BODY_ZONE_HEAD)

	if(!head_to_bash)
		return SECONDARY_ATTACK_CALL_NORMAL

	var/head_name = head_to_bash.name

	if(fire_extinguisher_reagent_sloshing_sound && reagents.total_volume > 0)
		playsound(src, fire_extinguisher_reagent_sloshing_sound, LIQUID_SLOSHING_SOUND_VOLUME, vary = TRUE, ignore_walls = FALSE)

	log_combat(user, wallopee, "prepared to use a bash attack with a [src] against [wallopee]")

	wallopee.visible_message(span_danger("[user] begins to raise [src] above [wallopee]'s [head_name]."), span_userdanger("[user] begins to raise [src], aiming to cave in your [head_name]!"))

	if(!do_after(user,  2 SECONDS, target = wallopee))
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

	wallopee.visible_message(span_danger("[user] brings [src] heavily down on [wallopee]'s [head_name]."), span_userdanger("[user] brings [src] heavily down on your [head_name]!"))

	var/min_wound = head_to_bash.get_wound_threshold_of_wound_type(WOUND_BLUNT, WOUND_SEVERITY_SEVERE, return_value_if_no_wound = 30, wound_source = src)
	var/max_wound = head_to_bash.get_wound_threshold_of_wound_type(WOUND_BLUNT, WOUND_SEVERITY_CRITICAL, return_value_if_no_wound = 50, wound_source = src)

	wallopee.apply_damage(src.force * 3, src.damtype, head_to_bash, wound_bonus = rand(min_wound, max_wound + 10), attacking_item = src)
	wallopee.emote("scream")
	log_combat(user, wallopee, "used a bash attack with a [src] against [wallopee]")
	user.do_attack_animation(wallopee, used_item = src)

	if(fire_extinguisher_reagent_sloshing_sound && reagents.total_volume > 0)
		playsound(src, fire_extinguisher_reagent_sloshing_sound, LIQUID_SLOSHING_SOUND_VOLUME, vary = TRUE, ignore_walls = FALSE)

	playsound(source = src, soundin = src.hitsound, vol = src.get_clamped_volume(), vary = TRUE)

	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN
