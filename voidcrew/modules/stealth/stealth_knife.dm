/**
 * # The matte combat knife (step 3a, owner decisions 5, 12 and 45)
 *
 * tg's combat knife with a blackened blade. Its one difference: stabbed into a stealth guard from behind (tg's
 * check_behind(), the heretic blade's backstab test) while the guard is unaware or only suspicious, it goes for the
 * throat whatever zone is aimed at, and the stab is tg's own throat slit (butchering.dm, startNeckSlice()) without the
 * grab and the wait: the knife's force to the head, a critical slash on the head and tg's neck_slice. A cut throat
 * can't speak, shout or use a radio (voidcrew/edits/datums/neck_slice_mute.dm). Head armour counts as tg counts it: the
 * damage goes through its melee armour, and the cut only opens the throat if tg's wound maths lets a critical slash
 * through (slit_gets_through()); otherwise it is an ordinary stab to the head. tg's grab slit works as before.
 * On anyone else, players included, it is a plain combat knife. No new animation.
 *
 * Players get it as scav den loot (step 4). It has no buy, print or craft route.
 */
/obj/item/knife/combat/matte
	name = "matte combat knife"
	desc = "A combat knife with a blackened blade that doesn't catch the light."
	color = "#6E6E7D"

/obj/item/knife/combat/matte/attack(mob/living/target_mob, mob/living/user, list/modifiers, list/attack_modifiers)
	if(!backstab_slits(target_mob, user))
		return ..()
	var/mob/living/carbon/human/npc/guard = target_mob
	var/obj/item/bodypart/throat = guard.get_bodypart(BODY_ZONE_HEAD)
	user.do_attack_animation(guard)
	user.changeNext_move(CLICK_CD_MELEE)
	playsound(guard, 'sound/effects/butcher.ogg', 50, TRUE, -1)
	var/blocked = guard.run_armor_check(throat, MELEE, armour_penetration = armour_penetration, silent = TRUE)
	if(!slit_gets_through(guard, throat))
		// A well protected throat: an ordinary stab to the head through its armour, with tg's own wound roll.
		guard.visible_message(span_danger("[user] stabs at [guard]'s throat, but the blade turns!"), span_userdanger("[user] stabs at your throat!"))
		log_combat(user, guard, "stabbed at the throat of", src, "(stab from behind, protected throat)")
		guard.apply_damage(force, BRUTE, throat, blocked, wound_bonus = wound_bonus, exposed_wound_bonus = exposed_wound_bonus, sharpness = get_sharpness(), attack_direction = get_dir(user, guard), attacking_item = src)
	else
		// tg's throat slit (butchering.dm, startNeckSlice()), from its do_after on, its damage through armour.
		guard.visible_message(span_danger("[user] slits [guard]'s throat!"), span_userdanger("[user] slits your throat..."))
		log_combat(user, guard, "wounded via throat slitting", src, "(stab from behind)")
		guard.apply_damage(force, BRUTE, throat, blocked, wound_bonus = CANT_WOUND)
		if(guard.cause_wound_of_type_and_severity(WOUND_SLASH, throat, WOUND_SEVERITY_CRITICAL))
			guard.apply_status_effect(/datum/status_effect/neck_slice)
	// The guard felt that: the same signal a normal blow sends (tg's relay_attackers), after the cut.
	SEND_SIGNAL(guard, COMSIG_ATOM_AFTER_ATTACKEDBY, src, user, modifiers, attack_modifiers)
	add_fingerprint(user)
	return TRUE

/**
 * Whether the slit gets through what protects this throat, by tg's own wound maths: a placed cut is the best roll tg's
 * wound roll allows (WOUND_MAX_CONSIDERED_DAMAGE to the power WOUND_DAMAGE_EXPONENT), plus this knife's wound bonus,
 * through check_woundings_mods() (worn wound armour on the head, physiology wound armour such as dermal cyberware, the
 * head's own resistance and its existing wounds). It gets through if that reaches tg's critical slash threshold.
 */
/obj/item/knife/combat/matte/proc/slit_gets_through(mob/living/carbon/human/victim, obj/item/bodypart/throat)
	var/datum/wound_pregen_data/critical = GLOB.all_wound_pregen_data[/datum/wound/slash/flesh/critical]
	var/best_roll = round(WOUND_MAX_CONSIDERED_DAMAGE ** WOUND_DAMAGE_EXPONENT)
	var/roll = throat.check_woundings_mods(WOUND_SLASH, best_roll, force, wound_bonus, exposed_wound_bonus, FALSE)
	return roll >= critical.threshold_minimum

/**
 * Whether stabbing `target` now is a throat slit from behind: a stealth guard caught off guard
 * (stealth_caught_off_guard()) with the stabber behind it, a combat-mode stab, its throat not already cut, and not
 * from tg's own grab slit (an aggressive grab aimed at the head goes tg's way).
 */
/obj/item/knife/combat/matte/proc/backstab_slits(mob/living/target, mob/living/user)
	if(!ishumannpc(target) || !istype(user) || !user.combat_mode || !force || !get_sharpness())
		return FALSE
	if(HAS_TRAIT(user, TRAIT_PACIFISM) || !target.get_bodypart(BODY_ZONE_HEAD))
		return FALSE
	if(user.pulling == target && user.grab_state >= GRAB_AGGRESSIVE)
		return FALSE
	if(target.has_status_effect(/datum/status_effect/neck_slice))
		return FALSE
	var/mob/living/carbon/human/npc/guard = target
	return check_behind(user, guard) && guard.stealth_caught_off_guard(user)
