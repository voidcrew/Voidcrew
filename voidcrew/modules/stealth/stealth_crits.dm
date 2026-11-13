/**
 * # Stealth guards: crits on a guard caught off guard, and the head shot (step 3a, owner decisions 9, 16, 19, 45)
 *
 * A blow on a stealth guard that never saw it coming adds to hyperviolence's aimed crit roll (crit_roll.dm,
 * hv_crit_situation_bonus()), so it only matters on an aimed hit that could crit anyway, it goes in before wound
 * armour scales the roll, and every crit's own armour block still holds.
 *
 * - Who: a guard with the stealth controller, conscious, not held or cuffed, with no player in the body. Never a
 *   player (decision 19), never any other NPC.
 * - When: by its state as the blow began (stealth_state_at_blow()). Unaware of everyone gets the full bonus; only
 *   suspicious, a smaller one; searching or alert, none. Searching gets none so that peek, shoot, hide and wait out
 *   the search can't farm it.
 * - Head: aimed at the head, eyes or mouth, the bonus goes up again.
 * - The matte knife from behind cuts the throat instead (stealth_knife.dm).
 *
 * The head shot (decision 45) is not a roll. A bullet aimed at the head of a guard caught off guard does what the
 * round can do against how well his head is protected (stealth_head_shot()), all through tg's own systems:
 * - a strong round: the head bursts (hyperviolence's hv_burst_head_apart(), a real decapitation);
 * - a weak round through the skull: a critical puncture with a heavy bleed, real brain damage and tg's
 *   Unconscious() long enough that the bleed takes him (blood loss, then oxygen loss, then crit and death);
 * - stopped short of the skull: the hit as normal, and tg's Unconscious() for STEALTH_HEAD_SHOT_HELMET_TIME;
 * - stopped: the hit as normal.
 * Protection (helmets, and physiology armour such as dermal cyberware, by tg's own armour numbers) steps it down.
 * Players on players, and everyone else's head shots, are exactly as before. Numbers: data/stealth/STATUS.md.
 */

/// TRUE if this guard was caught off guard by `attacker`'s blow: unaware or only suspicious as it began, conscious,
/// not held or cuffed, no player in the body. No side effects.
/mob/living/carbon/human/npc/proc/stealth_caught_off_guard(mob/living/attacker)
	if(isnull(attacker) || attacker == src || client || stat != CONSCIOUS)
		return FALSE
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = ai_controller
	if(!istype(stealth_ai) || stealth_ai.stealth_captive())
		return FALSE
	var/state = stealth_state_at_blow()
	return state == STEALTH_UNAWARE || state == STEALTH_SUSPICIOUS

/// The roll bonus for this blow (STEALTH_CRIT_*), or 0. No side effects.
/mob/living/carbon/human/npc/proc/stealth_crit_bonus(mob/living/attacker, atom/source, obj/item/bodypart/limb)
	if(!stealth_caught_off_guard(attacker))
		return 0
	. = stealth_state_at_blow() == STEALTH_UNAWARE ? STEALTH_CRIT_UNAWARE_BONUS : STEALTH_CRIT_SUSPICIOUS_BONUS
	if(limb?.body_zone == BODY_ZONE_HEAD)
		. += STEALTH_CRIT_HEAD_BONUS

/mob/living/carbon/human/npc/hv_crit_situation_bonus(mob/living/attacker, atom/source, obj/item/bodypart/limb)
	. = ..()
	var/bonus = stealth_crit_bonus(attacker, source, limb)
	if(!bonus)
		return .
	log_combat(attacker, src, "struck a [stealth_state_at_blow()] stealth guard", source, "(crit roll +[bonus], [limb?.body_zone])")
	return . + bonus

// ---------------------------------------------------------------------------------------------
// The head shot (decision 45)

/obj/projectile
	/// The caliber of the casing this was fired from (stealth head shots), or null.
	var/vc_caliber

/obj/item/ammo_casing/ready_proj(atom/target, mob/living/user, quiet, zone_override = "", atom/fired_from)
	. = ..()
	if(loaded_projectile)
		loaded_projectile.vc_caliber = caliber

/// Whether a round of this caliber is a rifle or shotgun round, which hits a skull harder than its damage says.
/proc/stealth_heavy_caliber(caliber)
	switch(caliber)
		if(CALIBER_A223, CALIBER_A7MM, CALIBER_STRILKA310, CALIBER_50BMG, CALIBER_SHOTGUN)
			return TRUE
	return FALSE

/// Whether `shot` came from a gun with a suppressor. tg's pellet cloud fires every pellet "quiet", so the gun is asked first.
/proc/stealth_shot_suppressed(obj/projectile/shot)
	if(isgun(shot.fired_from))
		var/obj/item/gun/gun = shot.fired_from
		return !!gun.suppressed
	return !!shot.suppressed

/mob/living/carbon/human/npc
	/// world.time of the head shot being resolved: every pellet of one shot lands in the same tick
	var/stealth_head_shot_at = -1
	/// Whether the shot being resolved caught it off guard (decided on its first pellet)
	var/stealth_head_shot_open = FALSE
	/// Power of the shot being resolved so far, before the caliber bonus and the suppressor
	var/stealth_head_shot_power = 0
	/// The worst outcome (STEALTH_HEAD_SHOT_*) the shot being resolved has done so far
	var/stealth_head_shot_done = STEALTH_HEAD_SHOT_NONE

/mob/living/carbon/human/npc/hv_crit_check_hit(damage, def_zone, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, atom/source)
	if(stealth_head_shot(damage, def_zone, wound_bonus, attack_direction, source))
		return
	return ..()

/**
 * A round that has just hit this guard's head, after tg dealt its damage. If it was aimed there and caught the guard off
 * guard, grades it and does what it earns. Returns TRUE if the hit was a stealth head shot (the aimed crit roll is then
 * skipped), FALSE to leave it to the ordinary crit roll.
 */
/mob/living/carbon/human/npc/proc/stealth_head_shot(damage, def_zone, wound_bonus, attack_direction, atom/source)
	if(!isprojectile(source) || !isbodypart(def_zone))
		return FALSE
	var/obj/item/bodypart/limb = def_zone
	if(limb.owner != src || limb.body_zone != BODY_ZONE_HEAD)
		return FALSE
	var/obj/projectile/shot = source
	if(shot.damage_type != BRUTE || shot.stamina > shot.damage)
		return FALSE
	var/mob/living/carbon/shooter = hv_crit_get_aimer(shot)
	if(isnull(shooter) || shooter == src || check_zone(shooter.zone_selected) != BODY_ZONE_HEAD)
		return FALSE
	if(stealth_head_shot_at != world.time)
		stealth_head_shot_at = world.time
		stealth_head_shot_power = 0
		stealth_head_shot_done = STEALTH_HEAD_SHOT_NONE
		stealth_head_shot_open = stealth_caught_off_guard(shooter)
	if(!stealth_head_shot_open)
		return FALSE
	var/grade = stealth_head_shot_grade(limb, shot, damage, wound_bonus)
	// Bursting a head is an execution: only those hyperviolence lets execute (players and boss NPCs).
	if(grade == STEALTH_HEAD_SHOT_BURST && !shooter.hv_can_execute())
		grade = STEALTH_HEAD_SHOT_DOWN
	if(grade > stealth_head_shot_done)
		stealth_head_shot_apply(grade, limb, shot, shooter, attack_direction || get_dir(shooter, src))
	return stealth_head_shot_done != STEALTH_HEAD_SHOT_NONE

/**
 * What this round does to this head (STEALTH_HEAD_SHOT_*), counting every pellet of the shot that has landed so far.
 * The round's power (its own numbers, before armour) gives burst, down or nothing; then each protection step
 * (stealth_head_protection()) moves that one down the ladder: burst, down, knocked out, nothing.
 */
/mob/living/carbon/human/npc/proc/stealth_head_shot_grade(obj/item/bodypart/limb, obj/projectile/shot, damage, wound_bonus)
	stealth_head_shot_power += shot.damage + max(0, shot.wound_bonus) / 2
	var/power = stealth_head_shot_power
	if(stealth_heavy_caliber(shot.vc_caliber))
		power += STEALTH_HEAD_SHOT_HEAVY_CALIBER
	if(stealth_shot_suppressed(shot))
		power *= STEALTH_HEAD_SHOT_SUPPRESSED_MULT
	var/grade = STEALTH_HEAD_SHOT_NONE
	if(power >= STEALTH_HEAD_SHOT_BURST_POWER)
		grade = STEALTH_HEAD_SHOT_BURST
	else if(power >= STEALTH_HEAD_SHOT_MIN_POWER)
		grade = STEALTH_HEAD_SHOT_DOWN
	if(grade == STEALTH_HEAD_SHOT_NONE)
		return grade
	var/protection = stealth_head_protection(limb, shot)
	var/steps = 0
	if(protection >= STEALTH_HEAD_SHOT_STEP_THREE)
		steps = 3
	else if(protection >= STEALTH_HEAD_SHOT_STEP_TWO)
		steps = 2
	else if(protection >= STEALTH_HEAD_SHOT_STEP_ONE)
		steps = 1
	return max(STEALTH_HEAD_SHOT_NONE, grade - steps)

/**
 * How well this head is protected against this round, with tg's own numbers: the armour tg's damage code uses against it
 * (run_armor_check(): covering clothes and physiology armour, where protective cyberware lives, stacked as
 * check_armor() stacks them, less the round's penetration), plus the wound armour tg's wound roll uses
 * (check_woundings_mods(): covering clothes and physiology), bar the head's own resistance everyone has.
 */
/mob/living/carbon/human/npc/proc/stealth_head_protection(obj/item/bodypart/limb, obj/projectile/shot)
	. = run_armor_check(limb, shot.armor_flag, armour_penetration = shot.armour_penetration, silent = TRUE, weak_against_armour = shot.weak_against_armour)
	for(var/obj/item/clothing/worn as anything in get_clothing_on_part(limb))
		. += worn.get_armor_rating(WOUND)
	. += physiology?.armor.get_rating(WOUND) || 0

/// Does what a graded head shot earns, through tg's own systems.
/mob/living/carbon/human/npc/proc/stealth_head_shot_apply(grade, obj/item/bodypart/limb, obj/projectile/shot, mob/living/shooter, shot_dir)
	switch(grade)
		if(STEALTH_HEAD_SHOT_BURST)
			if(hv_burst_head_apart(shot_dir))
				stealth_head_shot_done = grade
				log_combat(shooter, src, "burst the head of an unsuspecting stealth guard", shot)
				return
			// A head that can't come off: a round through the skull instead.
			grade = STEALTH_HEAD_SHOT_DOWN
		if(STEALTH_HEAD_SHOT_HELMET)
			stealth_head_shot_done = grade
			Unconscious(STEALTH_HEAD_SHOT_HELMET_TIME)
			if(head)
				hv_add_hit_line("The shot cracks off [src]'s [head.name]!", HV_LINE_BOLD, "Something cracks off your [head.name]!")
			else
				hv_add_hit_line("The shot glances off [src]'s skull!", HV_LINE_BOLD, "Something cracks against your skull!")
			playsound(src, SFX_RICOCHET, 60, TRUE)
			log_combat(shooter, src, "knocked out an unsuspecting stealth guard through head protection", shot)
			return
	if(grade != STEALTH_HEAD_SHOT_DOWN || stealth_head_shot_done >= grade)
		return
	if(!hv_crit_apply_wound(limb, /datum/wound/pierce/bleed/critical/hv_head_shot, shot_dir, shot))
		return
	stealth_head_shot_done = grade
	hv_blood_spray(shot_dir, 2)
	hv_add_hit_line("[src] is shot through the head!", HV_LINE_HUGE, "Something punches through your skull!", DEFAULT_MESSAGE_RANGE)
	playsound(src, 'sound/effects/wounds/pierce3.ogg', 80, TRUE, falloff_exponent = SOUND_FALLOFF_EXPONENT + 2, ignore_walls = FALSE, falloff_distance = 0)
	// He drops and twitches as he goes under (hyperviolence's own twitches).
	hv_vis_twitches(4, 8)
	log_combat(shooter, src, "shot an unsuspecting stealth guard through the head", shot)

/**
 * A round through the skull: tg's ruptured cavity on the head with a heavier bleed, real brain damage and tg's
 * unconsciousness. Treated like any critical puncture (gauze, sutures, cautery, surgery); the brain damage heals like any
 * other. Only a stealth head shot gives it (can_be_randomly_generated is off).
 */
/datum/wound/pierce/bleed/critical/hv_head_shot
	name = "Penetrating Head Wound"
	undiagnosed_name = "Head Wound"
	desc = "Patient has been shot through the skull. The wound is bleeding heavily and the brain is injured."
	simple_desc = "A bullet has gone through the skull."
	examine_desc = "has a bloody hole punched through it"
	occur_text = "is punched through"
	initial_flow = STEALTH_HEAD_SHOT_FLOW
	clot_rate = 0

/datum/wound/pierce/bleed/critical/hv_head_shot/wound_injury(datum/wound/old_wound = null, attack_direction = null)
	. = ..()
	if(!victim)
		return
	victim.adjustOrganLoss(ORGAN_SLOT_BRAIN, STEALTH_HEAD_SHOT_BRAIN_DAMAGE)
	if(victim.stat == DEAD)
		return
	victim.Unconscious(STEALTH_HEAD_SHOT_DOWN_TIME)

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
