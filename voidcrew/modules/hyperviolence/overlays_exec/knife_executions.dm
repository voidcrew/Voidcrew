// Hyperviolence: knife executions.
//
// Modelled on gun executions in executions.dm. A combat-mode click with an edged knife aimed at the
// head or mouth of an adjacent carbon with a head starts a knife execution when the attacker is
// either behind the target (check_behind()) or the target is helpless (hv_can_be_executed()). Only
// players and boss-rank human NPCs execute (hv_can_execute()), never pacifists.
//
// Both hold still for HV_KNIFE_EXECUTION_WINDUP; moving, losing the blade, switching zones or turning
// to face the attacker breaks the wind-up cleanly. If it holds, the knife stabs the head through its
// real attack() path at HV_EXECUTION_POINT_BLANK_MULT force and opens a slash wound on the head whose
// severity is tempered by the head's combined melee cover (worn armour plus physiology armour, such
// as dermal cyberware, minus the blade's armour penetration) and sealed helmets: unarmoured throats
// take a critical slash and tg's neck_slice bleed, light cover downgrades to a severe slash without
// neck_slice, and heavy cover or a sealed helmet leaves only a moderate slash. Nothing extra kills,
// stuns or roots the victim; death comes only from tg's real damage and bleeding.

/obj/item/knife
	/// Set while the execution's own head stab runs through attack(), so our override passes to parent.
	var/hv_knife_executing = FALSE
	/// Brute and burn damage this knife dealt to the victim's head during an execution stab.
	var/hv_knife_execution_head_damage = 0

/obj/item/knife/attack(mob/living/target_mob, mob/living/user, list/modifiers, list/attack_modifiers)
	if(hv_knife_executing || !hv_knife_execution_possible(user, target_mob))
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
			span_danger("[user] grabs [victim] from behind and presses [src] to [victim.p_their()] throat!"),
			span_danger("You grab [victim] from behind and press [src] to [victim.p_their()] throat!"),
			ignored_mobs = victim,
		)
		to_chat(victim, span_userdanger((unseen ? "Someone grabs you from behind and presses cold steel to your throat!" : "[user] grabs you from behind and presses [src] to your throat!")))
	else
		user.visible_message(
			span_danger("[user] grabs [victim]'s head and presses [src] to [victim.p_their()] throat!"),
			span_danger("You grab [victim]'s head and press [src] to [victim.p_their()] throat!"),
			ignored_mobs = victim,
		)
		to_chat(victim, span_userdanger((unseen ? "Someone grabs your head and presses cold steel to your throat!" : "[user] grabs your head and presses [src] to your throat!")))
	var/held = do_after(
		user,
		HV_KNIFE_EXECUTION_WINDUP,
		victim,
		extra_checks = CALLBACK(src, PROC_REF(hv_knife_execution_holds), user, victim),
		interaction_key = HV_KNIFE_EXECUTION_DOAFTER,
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

/**
 * Lands the knife execution: stabs the head through the real attack() path with the point-blank
 * multiplier, then opens a head slash wound scaled by the head's combined melee cover and sealed
 * headgear, adding neck_slice only when the throat is unarmoured and exposed. Returns TRUE on completion.
 */
/obj/item/knife/proc/hv_finish_knife_execution(mob/living/user, mob/living/carbon/victim, list/modifiers, list/attack_modifiers)
	if(!hv_knife_execution_holds(user, victim))
		return FALSE
	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	if(isnull(head))
		return FALSE

	var/sealed_helmet = !isnull(victim.is_mouth_covered(ITEM_SLOT_HEAD))
	var/cover = hv_crit_cover_rating(victim, head, MELEE, armour_penetration)
	var/wound_severity = WOUND_SEVERITY_CRITICAL
	var/slice_neck = TRUE
	if(sealed_helmet || cover >= HV_KNIFE_EXECUTION_HIGH_COVER)
		wound_severity = WOUND_SEVERITY_MODERATE
		slice_neck = FALSE
	else if(cover >= HV_KNIFE_EXECUTION_LOW_COVER)
		wound_severity = WOUND_SEVERITY_SEVERE
		slice_neck = FALSE

	var/list/stab_modifiers = islist(attack_modifiers) ? attack_modifiers.Copy() : list()
	MODIFY_ATTACK_FORCE_MULTIPLIER(stab_modifiers, HV_EXECUTION_POINT_BLANK_MULT)

	// Bypass the knife's butchering component for this synchronous hit so an aggressive grab or a
	// corpse with butcher results takes the real stab instead of starting startNeckSlice / startButcher.
	var/datum/component/butchering/butchering = GetComponent(/datum/component/butchering)
	if(butchering)
		butchering.UnregisterSignal(src, COMSIG_ITEM_ATTACK)

	var/previous_zone = user.zone_selected
	user.zone_selected = BODY_ZONE_HEAD
	hv_knife_execution_head_damage = 0
	RegisterSignal(victim, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(hv_knife_execution_hit))
	hv_knife_executing = TRUE
	attack(victim, user, modifiers, stab_modifiers)
	hv_knife_executing = FALSE
	if(!QDELETED(user))
		user.zone_selected = previous_zone
	if(!QDELETED(victim))
		UnregisterSignal(victim, COMSIG_MOB_APPLY_DAMAGE)
	if(!QDELETED(src) && !QDELETED(butchering))
		butchering.RegisterSignal(src, COMSIG_ITEM_ATTACK, TYPE_PROC_REF(/datum/component/butchering, onItemAttack))

	if(!QDELETED(victim))
		head = victim.get_bodypart(BODY_ZONE_HEAD)
		if(head)
			victim.cause_wound_of_type_and_severity(WOUND_SLASH, head, wound_severity, wound_source = src)
			if(slice_neck)
				var/has_critical_slash = FALSE
				for(var/datum/wound/wound as anything in head.wounds)
					if(wound.severity >= WOUND_SEVERITY_CRITICAL)
						has_critical_slash = TRUE
						break
				if(has_critical_slash)
					victim.apply_status_effect(/datum/status_effect/neck_slice)
				victim.hv_add_hit_line("[user] draws [src] across [victim]'s throat!", HV_LINE_HUGE, null, COMBAT_MESSAGE_RANGE)
				to_chat(victim, span_userdanger("Cold steel opens your throat!"))
			else if(wound_severity == WOUND_SEVERITY_SEVERE)
				victim.hv_add_hit_line("[src] cuts deep into [victim]'s neck, turned short of the artery!", HV_LINE_BOLD, null, COMBAT_MESSAGE_RANGE)
			else
				victim.hv_add_hit_line("[victim]'s protection turns the worst of [src] from [victim.p_their()] throat!", HV_LINE_BOLD, null, COMBAT_MESSAGE_RANGE)

	log_combat(user, victim, "knife-executed", src, "([round(hv_knife_execution_head_damage, 0.1)] damage to the head, slash severity [wound_severity])")
	if(!QDELETED(victim))
		hv_execution_witnesses(user, victim)
	return TRUE

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
