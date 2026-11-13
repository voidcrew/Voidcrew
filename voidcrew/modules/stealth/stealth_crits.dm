/**
 * # Stealth guards: crits on a guard caught unaware, and the head shot (step 3a, owner decisions 9, 16, 19)
 *
 * Nothing here deals damage of its own. A blow on a stealth guard that never saw it coming adds to hyperviolence's
 * aimed crit roll (crit_roll.dm, hv_crit_situation_bonus()), so it only matters on an aimed hit that could crit
 * anyway, it goes in before wound armour scales the roll, and every crit's own armour block still holds.
 *
 * - Who: a guard with the stealth controller, conscious, not held or cuffed, with no player in the body. Never a
 *   player (decision 19), never any other NPC.
 * - When: by its state as the blow began (stealth_state_at_blow()). Unaware of everyone gets the full bonus; only
 *   suspicious, a smaller one; searching or alert, none. Searching gets none so that peek, shoot, hide and wait out
 *   the search can't farm it.
 * - Head: aimed at the head, eyes or mouth, the bonus goes up again.
 * - Backstab: the matte combat knife (stealth_knife.dm) adds STEALTH_BACKSTAB_BONUS from behind (tg's check_behind()),
 *   whatever the guard's state.
 *
 * hyperviolence had no head crit a bullet could cause, so a pistol shot to an unaware guard's head could do nothing a
 * shot to an alert one couldn't. The head shot crit below is that crit, and only a stealth hit rolls it: everyone
 * else's head shots (players on players included) are exactly as before. Numbers: data/stealth/STATUS.md, "Step 3a".
 */

/// The roll bonus for this blow (STEALTH_CRIT_* and STEALTH_BACKSTAB_BONUS), or 0. No side effects.
/mob/living/carbon/human/npc/proc/stealth_crit_bonus(mob/living/attacker, atom/source, obj/item/bodypart/limb)
	if(isnull(attacker) || attacker == src || client || stat != CONSCIOUS)
		return 0
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = ai_controller
	if(!istype(stealth_ai) || stealth_ai.stealth_captive())
		return 0
	. = 0
	switch(stealth_state_at_blow())
		if(STEALTH_UNAWARE)
			. = STEALTH_CRIT_UNAWARE_BONUS
		if(STEALTH_SUSPICIOUS)
			. = STEALTH_CRIT_SUSPICIOUS_BONUS
	if(. && limb?.body_zone == BODY_ZONE_HEAD)
		. += STEALTH_CRIT_HEAD_BONUS
	if(istype(source, /obj/item/knife/combat/matte) && check_behind(attacker, src))
		. += STEALTH_BACKSTAB_BONUS

/mob/living/carbon/human/npc/hv_crit_situation_bonus(mob/living/attacker, atom/source, obj/item/bodypart/limb)
	. = ..()
	var/bonus = stealth_crit_bonus(attacker, source, limb)
	if(!bonus)
		return .
	log_combat(attacker, src, "struck a [stealth_state_at_blow()] stealth guard", source, "(crit roll +[bonus], [limb?.body_zone])")
	return . + bonus

// ---------------------------------------------------------------------------------------------
// Shot through the head: a bullet aimed at the head of a guard who didn't see it coming. A good enough helmet stops it.

/datum/hv_crit/head_shot
	name = "shot through the head"
	limb_zone = BODY_ZONE_HEAD
	aim_zones = list(BODY_ZONE_HEAD, BODY_ZONE_PRECISE_EYES, BODY_ZONE_PRECISE_MOUTH)
	wounding_types = list(WOUND_PIERCE)
	min_damage = STEALTH_HEAD_SHOT_MIN_DAMAGE
	threshold = STEALTH_HEAD_SHOT_THRESHOLD
	allow_projectiles = TRUE
	wound_type = /datum/wound/pierce/bleed/critical/hv_head_shot
	line_severity = HV_LINE_HUGE
	line_range = DEFAULT_MESSAGE_RANGE
	hit_sound = 'sound/effects/wounds/pierce3.ogg'
	shake = 6

/datum/hv_crit/head_shot/matches(hit_zone, aimed_zone, wounding_type, from_projectile)
	return from_projectile && ..()

/datum/hv_crit/head_shot/blocked_on_carbon(mob/living/carbon/victim, obj/item/bodypart/limb, atom/source)
	if(!ishumannpc(victim) || !isprojectile(source))
		return TRUE
	var/mob/living/carbon/human/npc/guard = victim
	var/obj/projectile/shot = source
	if(!isliving(shot.firer) || guard.stealth_crit_bonus(shot.firer, source, limb) <= 0)
		return TRUE
	return hv_crit_cover_rating(victim, limb, hv_crit_attack_flag(source), hv_crit_armour_pen(source)) >= STEALTH_HEAD_SHOT_HELMET_ARMOUR

/datum/hv_crit/head_shot/apply_carbon(mob/living/carbon/victim, obj/item/bodypart/limb, damage, attack_direction, atom/source, mob/living/attacker)
	if(!hv_crit_apply_wound(limb, wound_type, attack_direction, source))
		return FALSE
	victim.hv_blood_spray(attack_direction, 2)
	announce(victim, attack_direction)
	return TRUE

/datum/hv_crit/head_shot/hit_line(mob/living/victim)
	return "[victim] is shot through the head!"

/datum/hv_crit/head_shot/self_line(mob/living/victim)
	return "Something punches through your skull!"

/**
 * tg's ruptured cavity on the head, with a knock to the brain: brain damage, a knockdown, confusion and blurred eyes.
 * Treated like any critical puncture (gauze, sutures, cautery, surgery); the brain damage heals like any other.
 */
/datum/wound/pierce/bleed/critical/hv_head_shot
	name = "Penetrating Head Wound"
	undiagnosed_name = "Head Wound"
	desc = "Patient has been shot through the skull. The wound is bleeding heavily and the brain is injured."
	simple_desc = "A bullet has gone through the skull."
	examine_desc = "has a bloody hole punched through it"
	occur_text = "is punched through"

/datum/wound/pierce/bleed/critical/hv_head_shot/wound_injury(datum/wound/old_wound = null, attack_direction = null)
	. = ..()
	if(!victim)
		return
	victim.adjustOrganLoss(ORGAN_SLOT_BRAIN, STEALTH_HEAD_SHOT_BRAIN_DAMAGE)
	if(victim.stat == DEAD)
		return
	victim.Knockdown(STEALTH_HEAD_SHOT_KNOCKDOWN)
	victim.set_confusion_if_lower(15 SECONDS)
	victim.adjust_eye_blur(10 SECONDS)

/datum/wound_pregen_data/flesh_pierce/hv_head_shot
	abstract = FALSE
	wound_path_to_generate = /datum/wound/pierce/bleed/critical/hv_head_shot
	required_wounding_types = list(WOUND_PIERCE)
	wound_series = WOUND_SERIES_HV_HEAD_SHOT
	required_limb_biostate = (BIO_FLESH|BIO_BLOODED)
	ignore_cannot_bleed = FALSE
	viable_zones = list(BODY_ZONE_HEAD)
	can_be_randomly_generated = FALSE
	threshold_minimum = 100
