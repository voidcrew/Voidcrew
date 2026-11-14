// Hyperviolence: knife executions.
//
// Modelled on gun executions in executions.dm. A combat-mode click with an edged knife aimed at the
// head or mouth of an adjacent carbon with a head starts a knife execution when the attacker is
// either behind the target (check_behind()) or the target is helpless (hv_can_be_executed()). Only
// players and boss-rank human NPCs execute (hv_can_execute()), never pacifists.
//
// Both hold still for HV_KNIFE_EXECUTION_WINDUP; moving, losing the blade, switching zones or turning
// to face the attacker breaks the wind-up cleanly. If it holds, the knife stabs the head at
// HV_EXECUTION_POINT_BLANK_MULT force and opens whatever slash wound tg's own wound maths allows
// through the head's melee and wound armour (worn helmets and physiology armour, such as dermal
// cyberware) and sealed helmets: unarmoured throats take a critical slash and tg's neck_slice bleed,
// light helmets or subdermal plating downgrade the wound (and the directional blood it throws), and
// heavy armour stops the cut outright. Nothing extra kills, stuns or roots the victim; death comes
// only from tg's real damage and bleeding.

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

/// Whether a melee click with this knife by `user` on `target` starts a knife execution.
/obj/item/knife/proc/hv_knife_execution_possible(mob/living/user, mob/living/target)
	if(!isliving(user) || !iscarbon(target) || user == target)
		return FALSE
	if(!user.combat_mode || HAS_TRAIT(user, TRAIT_PACIFISM) || !user.hv_can_execute())
		return FALSE
	if(user.zone_selected != BODY_ZONE_HEAD && user.zone_selected != BODY_ZONE_PRECISE_MOUTH)
		return FALSE
	if(force <= 0 || !(get_sharpness() & SHARP_EDGED))
		return FALSE
	var/mob/living/carbon/victim = target
	if(isnull(victim.get_bodypart(BODY_ZONE_HEAD)) || !user.Adjacent(victim))
		return FALSE
	return check_behind(user, victim) || victim.hv_can_be_executed()

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
	if(user.zone_selected != BODY_ZONE_HEAD && user.zone_selected != BODY_ZONE_PRECISE_MOUTH)
		return FALSE
	if(isnull(victim.get_bodypart(BODY_ZONE_HEAD)) || !user.Adjacent(victim))
		return FALSE
	return victim.hv_can_be_executed() || check_behind(user, victim)

/// Lands the knife execution: stabs the head at point-blank force, opens tg's armour-attenuated head slash wound, and slices exposed throats.
/obj/item/knife/proc/hv_finish_knife_execution(mob/living/user, mob/living/carbon/victim, list/modifiers, list/attack_modifiers)
	if(!hv_knife_execution_holds(user, victim))
		return FALSE
	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	if(isnull(head))
		return FALSE

	hv_knife_exec_spray = 0
	hv_knife_execution_head_damage = 0

	var/sealed_helmet = !isnull(victim.is_mouth_covered(ITEM_SLOT_HEAD))
	var/blocked = min(victim.run_armor_check(
		def_zone = head,
		attack_flag = MELEE,
		armour_penetration = armour_penetration,
		silent = TRUE,
		weak_against_armour = weak_against_armour,
	), ARMOR_MAX_BLOCK)
	var/wound_severity = hv_knife_execution_wound_severity(victim, head, blocked, sealed_helmet)
	var/spray_dir = get_dir(user, victim) || victim.dir || SOUTH

	var/list/stab_modifiers = islist(attack_modifiers) ? attack_modifiers.Copy() : list()
	MODIFY_ATTACK_FORCE_MULTIPLIER(stab_modifiers, HV_EXECUTION_POINT_BLANK_MULT)
	var/stab_force = CALCULATE_FORCE(src, stab_modifiers)

	user.do_attack_animation(victim)
	user.changeNext_move(CLICK_CD_MELEE)
	if(!LAZYACCESS(stab_modifiers, SILENCE_HITSOUND))
		playsound(victim, hitsound || 'sound/effects/butcher.ogg', get_clamped_volume(), TRUE, extrarange = stealthy_audio ? SILENCED_SOUND_EXTRARANGE : -1, falloff_distance = 0)
	victim.lastattacker = user.real_name
	victim.lastattackerckey = user.ckey

	RegisterSignal(victim, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(hv_knife_execution_hit))
	var/damage_done = victim.apply_damage(
		damage = stab_force,
		damagetype = damtype,
		def_zone = head,
		blocked = blocked,
		wound_bonus = CANT_WOUND,
		attack_direction = spray_dir,
		attacking_item = src,
	)
	if(!QDELETED(victim))
		UnregisterSignal(victim, COMSIG_MOB_APPLY_DAMAGE)

	if(!QDELETED(victim))
		head = victim.get_bodypart(BODY_ZONE_HEAD)
		if(head)
			if(damage_done > 0 && head.can_bleed())
				add_mob_blood(victim)
			if(wound_severity >= WOUND_SEVERITY_MODERATE)
				var/datum/wound/wound_path = get_corresponding_wound_type(list(WOUND_SLASH), head, wound_severity, wound_severity, WOUND_PICK_HIGHEST_SEVERITY)
				if(wound_path)
					hv_crit_apply_wound(head, wound_path, spray_dir, src)
			var/worst = 0
			for(var/datum/wound/cut as anything in head.wounds)
				if((istype(cut, /datum/wound/slash) || istype(cut, /datum/wound/pierce)) && cut.severity > worst)
					worst = cut.severity
			if(worst >= WOUND_SEVERITY_CRITICAL)
				hv_knife_exec_spray = 2
			else if(worst >= WOUND_SEVERITY_MODERATE)
				hv_knife_exec_spray = 1

			if(wound_severity >= WOUND_SEVERITY_CRITICAL && worst >= WOUND_SEVERITY_CRITICAL)
				victim.apply_status_effect(/datum/status_effect/neck_slice)
				victim.hv_add_hit_line("[user] cuts [victim]'s throat!", HV_LINE_HUGE, "[user] cuts your throat!", COMBAT_MESSAGE_RANGE)
			else if(wound_severity == WOUND_SEVERITY_SEVERE)
				victim.hv_add_hit_line("[user] slashes [victim]'s neck!", HV_LINE_BOLD, "[user] slashes your neck!", COMBAT_MESSAGE_RANGE)
			else
				var/blocked_by = (sealed_helmet || victim.get_item_by_slot(ITEM_SLOT_HEAD)) ? "helmet" : "collar"
				victim.hv_add_hit_line("[src] skids off [victim]'s [blocked_by].", HV_LINE_BOLD, "[src] skids off your [blocked_by].", COMBAT_MESSAGE_RANGE)

		if(!QDELETED(src) && !QDELETED(user))
			SEND_SIGNAL(src, COMSIG_ITEM_AFTERATTACK, victim, user, modifiers, stab_modifiers)
			SEND_SIGNAL(victim, COMSIG_ATOM_AFTER_ATTACKEDBY, src, user, modifiers, stab_modifiers)
			afterattack(victim, user, modifiers, stab_modifiers)
		hv_execution_witnesses(user, victim)
	if(!QDELETED(src) && !QDELETED(user))
		add_fingerprint(user)
	log_combat(user, victim, "knife-executed", src, "([round(hv_knife_execution_head_damage, 0.1)] damage to the head, slash severity [wound_severity])")
	return TRUE

/// Works out the slash wound severity tg's own wound maths allows for a placed cut on `head` after `blocked` melee armour.
/obj/item/knife/proc/hv_knife_execution_wound_severity(mob/living/carbon/victim, obj/item/bodypart/head, blocked, sealed_helmet = FALSE)
	if(HAS_TRAIT(victim, TRAIT_NEVER_WOUNDED) || HAS_TRAIT(victim, TRAIT_GODMODE))
		return 0
	var/wounding_dmg = WOUND_MAX_CONSIDERED_DAMAGE * (100 - clamp(blocked, 0, 100)) * 0.01
	if(HAS_TRAIT(victim, TRAIT_HARDLY_WOUNDED) && !HAS_TRAIT(victim, TRAIT_EASILY_WOUNDED))
		wounding_dmg *= 0.85
	if(HAS_TRAIT(victim, TRAIT_EASYBLEED) && victim.can_bleed())
		wounding_dmg *= 1.5
	if(wounding_dmg < WOUND_MINIMUM_DAMAGE)
		return 0
	var/best_roll = round(wounding_dmg ** WOUND_DAMAGE_EXPONENT)
	var/roll = head.check_woundings_mods(WOUND_SLASH, best_roll, wounding_dmg, wound_bonus, exposed_wound_bonus, FALSE)
	var/list/series_mods = head.check_series_wounding_mods()
	roll += series_mods[WOUND_SERIES_FLESH_SLASH_BLEED] || 0
	var/critical_min = head.get_wound_threshold_of_wound_type(WOUND_SLASH, WOUND_SEVERITY_CRITICAL, INFINITY, src)
	if(!sealed_helmet && roll >= critical_min)
		return WOUND_SEVERITY_CRITICAL
	var/severe_min = head.get_wound_threshold_of_wound_type(WOUND_SLASH, WOUND_SEVERITY_SEVERE, INFINITY, src)
	if(!sealed_helmet && roll >= severe_min)
		return WOUND_SEVERITY_SEVERE
	var/moderate_min = head.get_wound_threshold_of_wound_type(WOUND_SLASH, WOUND_SEVERITY_MODERATE, INFINITY, src)
	if(roll >= moderate_min)
		return WOUND_SEVERITY_MODERATE
	return 0

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
