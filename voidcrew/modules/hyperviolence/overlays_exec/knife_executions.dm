// Hyperviolence: knife executions, the one backstab path (decisions 45 and 46).
//
// A combat-mode click with any sharp-edged knife on an adjacent carbon with a head starts it when:
// - the target is a stealth guard caught off guard (stealth_caught_off_guard()) and the attacker is behind it
//   (check_behind()), whatever zone is aimed at (decision 45);
// - or anyone else is taken from behind, or anyone is helpless (hv_can_be_executed()), with the head or mouth aimed at.
// Never on a body the attacker holds in an aggressive grab or tighter (that is tg's own slow throat slit), never on a
// throat already cut. Only players and boss-rank human NPCs do it (hv_can_execute()), never pacifists.
//
// Both hold still for HV_KNIFE_EXECUTION_WINDUP; moving, losing the blade or turning to face the attacker breaks the
// wind-up cleanly. If it holds, the cut is decision 45's: tg's throat slit maths (hv_finish_knife_execution()). The
// throat blood follows the wound that landed (hv_knife_exec_spray). Nothing extra kills, stuns or roots the victim;
// death comes only from tg's real damage and bleeding. A cut throat is mute (voidcrew/edits/datums/neck_slice_mute.dm).

/obj/item/knife
	/// Brute and burn damage this knife dealt to the victim's head during an execution stab.
	var/hv_knife_execution_head_damage = 0
	/// How far the last execution's throat blood sprays (0-2 tiles), by the worst cut it left on the head.
	var/hv_knife_exec_spray = 0

/obj/item/knife/attack(mob/living/target_mob, mob/living/user, list/modifiers, list/attack_modifiers)
	if(!hv_knife_execution_possible(user, target_mob))
		return ..()
	if(!DOING_INTERACTION(user, HV_KNIFE_EXECUTION_DOAFTER))
		var/list/saved_modifiers = islist(modifiers) ? modifiers.Copy() : null
		var/list/saved_attack_modifiers = islist(attack_modifiers) ? attack_modifiers.Copy() : null
		INVOKE_ASYNC(src, PROC_REF(hv_start_knife_execution), user, target_mob, saved_modifiers, saved_attack_modifiers)
	return TRUE

/// Whether a melee click with this knife by `user` on `target` starts a knife execution (the one backstab path).
/obj/item/knife/proc/hv_knife_execution_possible(mob/living/user, mob/living/target)
	if(!isliving(user) || !iscarbon(target) || user == target)
		return FALSE
	if(!user.combat_mode || HAS_TRAIT(user, TRAIT_PACIFISM) || !user.hv_can_execute())
		return FALSE
	if(force <= 0 || !(get_sharpness() & SHARP_EDGED))
		return FALSE
	var/mob/living/carbon/victim = target
	if(isnull(victim.get_bodypart(BODY_ZONE_HEAD)) || !user.Adjacent(victim))
		return FALSE
	// Held in an aggressive grab or tighter: tg's own slow throat slit (butchering.dm), not this.
	if(user.pulling == victim && user.grab_state >= GRAB_AGGRESSIVE)
		return FALSE
	if(victim.has_status_effect(/datum/status_effect/neck_slice))
		return FALSE
	var/behind = check_behind(user, victim)
	// A stealth guard caught off guard from behind: the throat whatever is aimed at (decision 45). On guard, only helpless.
	if(hv_knife_is_stealth_guard(victim))
		var/mob/living/carbon/human/npc/guard = victim
		if(behind && guard.stealth_caught_off_guard(user))
			return TRUE
		return hv_knife_aims_at_throat(user) && victim.hv_can_be_executed()
	if(!hv_knife_aims_at_throat(user))
		return FALSE
	return behind || victim.hv_can_be_executed()

/// Whether `user` aims at the head or the mouth.
/obj/item/knife/proc/hv_knife_aims_at_throat(mob/living/user)
	return user.zone_selected == BODY_ZONE_HEAD || user.zone_selected == BODY_ZONE_PRECISE_MOUTH

/// Whether `victim` is a stealth guard (its awareness decides a backstab, decision 45).
/obj/item/knife/proc/hv_knife_is_stealth_guard(mob/living/victim)
	var/mob/living/carbon/human/npc/guard = victim
	return istype(guard) && istype(guard.ai_controller, /datum/ai_controller/basic_controller/human_npc/stealth)

/// Grabs the victim, presses the blade to their throat and, if both hold still, cuts.
/obj/item/knife/proc/hv_start_knife_execution(mob/living/user, mob/living/carbon/victim, list/modifiers, list/attack_modifiers)
	if(DOING_INTERACTION(user, HV_KNIFE_EXECUTION_DOAFTER) || !hv_knife_execution_possible(user, victim))
		return FALSE
	var/from_behind = check_behind(user, victim)
	var/unseen = from_behind || victim.is_blind() || !(user in viewers(7, victim))
	if(from_behind)
		user.visible_message(
			span_danger("[user] grabs [victim] from behind and presses [src] to [victim.p_their()] throat."),
			span_danger("You grab [victim] from behind and press [src] to [victim.p_their()] throat."),
			ignored_mobs = victim,
		)
		to_chat(victim, span_userdanger((unseen ? "Someone grabs you from behind and presses a blade to your throat!" : "[user] grabs you from behind and presses [src] to your throat!")))
	else
		user.visible_message(
			span_danger("[user] grabs [victim]'s head and presses [src] to [victim.p_their()] throat."),
			span_danger("You grab [victim]'s head and press [src] to [victim.p_their()] throat."),
			ignored_mobs = victim,
		)
		to_chat(victim, span_userdanger((unseen ? "Someone grabs your head and presses a blade to your throat!" : "[user] grabs your head and presses [src] to your throat!")))
	var/held = do_after(
		user,
		HV_KNIFE_EXECUTION_WINDUP,
		victim,
		extra_checks = CALLBACK(src, PROC_REF(hv_knife_execution_holds), user, victim),
		interaction_key = HV_KNIFE_EXECUTION_DOAFTER,
		hidden = TRUE, // no cog over his head: the grab itself is what people see
	)
	if(!held || QDELETED(src) || QDELETED(user) || QDELETED(victim))
		return FALSE
	return hv_finish_knife_execution(user, victim, modifiers, attack_modifiers)

/// do_after check: the attacker still holds a sharp knife to an adjacent victim who hasn't turned to face them.
/obj/item/knife/proc/hv_knife_execution_holds(mob/living/user, mob/living/carbon/victim)
	if(!user.is_holding(src) || !user.combat_mode || HAS_TRAIT(user, TRAIT_PACIFISM))
		return FALSE
	if(force <= 0 || !(get_sharpness() & SHARP_EDGED))
		return FALSE
	if(isnull(victim.get_bodypart(BODY_ZONE_HEAD)) || !user.Adjacent(victim))
		return FALSE
	if(user.pulling == victim && user.grab_state >= GRAB_AGGRESSIVE)
		return FALSE
	// A stealth guard taken from behind goes for the throat whatever is aimed at; anyone else needs the head or mouth.
	if(!hv_knife_is_stealth_guard(victim) && !hv_knife_aims_at_throat(user))
		return FALSE
	return victim.hv_can_be_executed() || check_behind(user, victim)

/**
 * Lands the knife execution: tg's throat slit (butchering.dm, startNeckSlice()) from its do_after on, as decision 45 built
 * it. The knife's force goes to the head through its melee armour; if tg's wound maths lets a critical cut through what
 * protects the head (slit_gets_through()), a critical slash and tg's neck_slice (mute, neck_slice_mute.dm). Otherwise
 * the blade turns: an ordinary stab to the head with tg's own wound roll, and he can still shout.
 */
/obj/item/knife/proc/hv_finish_knife_execution(mob/living/user, mob/living/carbon/victim, list/modifiers, list/attack_modifiers)
	if(!hv_knife_execution_holds(user, victim))
		return FALSE
	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	if(isnull(head))
		return FALSE
	hv_knife_exec_spray = 0
	hv_knife_execution_head_damage = 0
	RegisterSignal(victim, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(hv_knife_execution_hit))
	user.do_attack_animation(victim)
	user.changeNext_move(CLICK_CD_MELEE)
	playsound(victim, 'sound/effects/butcher.ogg', 50, TRUE, -1)
	var/blocked = victim.run_armor_check(head, MELEE, armour_penetration = armour_penetration, silent = TRUE)
	var/slit = slit_gets_through(victim, head)
	if(slit)
		log_combat(user, victim, "wounded via throat slitting", src, "(knife execution)")
		victim.apply_damage(force, BRUTE, head, blocked, wound_bonus = CANT_WOUND, attack_direction = get_dir(user, victim), attacking_item = src)
		if(victim.cause_wound_of_type_and_severity(WOUND_SLASH, head, WOUND_SEVERITY_CRITICAL, wound_source = src))
			victim.apply_status_effect(/datum/status_effect/neck_slice)
	else
		log_combat(user, victim, "stabbed at the throat of", src, "(knife execution, protected throat)")
		victim.apply_damage(force, BRUTE, head, blocked, wound_bonus = wound_bonus, exposed_wound_bonus = exposed_wound_bonus, sharpness = get_sharpness(), attack_direction = get_dir(user, victim), attacking_item = src)
	if(!QDELETED(victim))
		UnregisterSignal(victim, COMSIG_MOB_APPLY_DAMAGE)
		head = victim.get_bodypart(BODY_ZONE_HEAD)
		// The blood follows the wound that landed: a cut throat sprays, a lesser cut runs, no wound no spray.
		var/worst = 0
		for(var/datum/wound/cut as anything in head?.wounds)
			if((istype(cut, /datum/wound/slash) || istype(cut, /datum/wound/pierce)) && cut.severity > worst)
				worst = cut.severity
		if(worst >= WOUND_SEVERITY_CRITICAL)
			hv_knife_exec_spray = 2
		else if(worst >= WOUND_SEVERITY_MODERATE)
			hv_knife_exec_spray = 1
		if(victim.has_status_effect(/datum/status_effect/neck_slice))
			victim.hv_add_hit_line("[user] cuts [victim]'s throat!", HV_LINE_HUGE, "[user] cuts your throat!", COMBAT_MESSAGE_RANGE)
		else
			victim.hv_add_hit_line("[user] stabs at [victim]'s throat, but the blade turns!", HV_LINE_BOLD, "[user] stabs at your throat!", COMBAT_MESSAGE_RANGE)
		// The victim felt that: the same signal a normal blow sends (tg's relay_attackers), after the cut.
		SEND_SIGNAL(victim, COMSIG_ATOM_AFTER_ATTACKEDBY, src, user, modifiers, attack_modifiers)
		hv_execution_witnesses(user, victim)
	add_fingerprint(user)
	log_combat(user, victim, "knife-executed", src, "([round(hv_knife_execution_head_damage, 0.1)] damage to the head, throat [slit ? "cut" : "protected"])")
	return TRUE

/**
 * Whether the slit gets through what protects this throat, by tg's own wound maths (decision 45): a placed cut is the
 * best roll tg's wound roll allows (WOUND_MAX_CONSIDERED_DAMAGE to the power WOUND_DAMAGE_EXPONENT), plus this knife's
 * wound bonus, through check_woundings_mods() (worn wound armour on the head, physiology wound armour such as dermal
 * cyberware, the head's own resistance and its existing wounds). It gets through if that reaches tg's critical slash
 * threshold.
 */
/obj/item/knife/proc/slit_gets_through(mob/living/carbon/victim, obj/item/bodypart/throat)
	var/datum/wound_pregen_data/critical = GLOB.all_wound_pregen_data[/datum/wound/slash/flesh/critical]
	var/best_roll = round(WOUND_MAX_CONSIDERED_DAMAGE ** WOUND_DAMAGE_EXPONENT)
	var/roll = throat.check_woundings_mods(WOUND_SLASH, best_roll, force, wound_bonus, exposed_wound_bonus, FALSE)
	return roll >= critical.threshold_minimum

/// Sums brute and burn damage this knife deals to the victim's head during an execution stab.
/obj/item/knife/proc/hv_knife_execution_hit(mob/living/source, damage, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, atom/attacking_item)
	SIGNAL_HANDLER
	if(attacking_item != src || (damagetype != BRUTE && damagetype != BURN))
		return
	var/zone
	if(isbodypart(def_zone))
		var/obj/item/bodypart/limb = def_zone
		zone = limb.body_zone
	else
		zone = check_zone(def_zone)
	if(zone == BODY_ZONE_HEAD)
		hv_knife_execution_head_damage += damage
