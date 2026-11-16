/**
 * # Prison NPC bodies
 *
 * Prisoners, guards and Kessler staff are real human bodies (voidcrew/modules/human_npcs/): they go
 * down, bleed, stamcrit, get cuffed, die and come back through tg's own code. This file holds what the
 * prison's own AI needs to use those bodies the way a person does:
 * - outpost_prison_npc_hit(): a blow is a click with combat mode on, through the body's hands (a fist,
 *   a held shiv, a stun baton), so tg's damage, armour, wounds, knockdowns and logs apply.
 * - Saved faces: a guard on the payroll is the same person each time the record sends them back
 *   (outpost_prison_save_look(), outpost_prison_apply_look()).
 * - Bruising to a health: outpost_prison_bruise() and outpost_prison_set_health(), for a transfer's
 *   roughing up and the admin tools.
 */

/// Brute in which a limb is bruised by outpost_prison_bruise(): a multiple of it on a limb (0.75 or 0.5 of
/// the body's health) comes to whole tenths of health
#define OUTPOST_PRISON_BRUISE_STEP 0.4

/**
 * `hitter` strikes `target` beside it with `weapon` in hand (switched to the active hand), or a fist
 * if `weapon` is null, the way a player clicks with combat mode on. The aim spreads over the body as
 * other human NPCs' does. Returns TRUE if the blow was thrown: not if they can't swing yet, nor a second
 * time in the same tick, which ClickOn() would ignore as it does a player's second click.
 */
/proc/outpost_prison_npc_hit(mob/living/carbon/human/hitter, atom/target, obj/item/weapon)
	if(QDELETED(hitter) || QDELETED(target) || hitter.stat != CONSCIOUS || world.time < hitter.next_move || world.time <= hitter.next_click)
		return FALSE
	if(!hitter.Adjacent(target))
		return FALSE
	if(weapon)
		if(!human_npc_ready_item(hitter, weapon))
			return FALSE
	else if(!human_npc_ready_empty_hand(hitter))
		return FALSE
	hitter.face_atom(target)
	hitter.zone_selected = human_npc_pick_aim_zone()
	var/old_combat_mode = hitter.combat_mode
	hitter.set_combat_mode(TRUE, silent = TRUE)
	hitter.ClickOn(target)
	hitter.set_combat_mode(old_combat_mode, silent = TRUE)
	return TRUE

/// What makes a face: the bits of a random person a guard record keeps, so the same guard comes back
/proc/outpost_prison_save_look(mob/living/carbon/human/person)
	if(QDELETED(person))
		return null
	return list(
		"gender" = person.gender,
		"skin_tone" = person.skin_tone,
		"hairstyle" = person.hairstyle,
		"hair_color" = person.hair_color,
		"facial_hairstyle" = person.facial_hairstyle,
		"facial_hair_color" = person.facial_hair_color,
		"eye_color" = person.eye_color_left,
		"real_name" = person.real_name,
	)

/// Puts a face saved by outpost_prison_save_look() on `person`
/proc/outpost_prison_apply_look(mob/living/carbon/human/person, list/look)
	if(QDELETED(person) || !length(look))
		return
	person.gender = look["gender"] == FEMALE ? FEMALE : MALE
	person.physique = person.gender
	if(look["skin_tone"])
		person.skin_tone = look["skin_tone"]
	person.set_hairstyle(look["hairstyle"] || "Bald", update = FALSE)
	if(look["hair_color"])
		person.set_haircolor(look["hair_color"], update = FALSE)
	person.set_facial_hairstyle(look["facial_hairstyle"] || "Shaved", update = FALSE)
	if(look["facial_hair_color"])
		person.set_facial_haircolor(look["facial_hair_color"], update = FALSE)
	if(look["eye_color"])
		person.set_eye_color(look["eye_color"])
	person.update_body(is_creating = TRUE)

/**
 * Bruises `body` until it has lost `health_loss` health: brute spread over its limbs, no wounds and no
 * attacker, as a rough transfer leaves someone, with the chest taking what is left. Arms and legs count
 * for less of a body's health than its head and chest (body_damage_coeff), so each limb's share is
 * measured in health and bruised in steps of OUTPOST_PRISON_BRUISE_STEP brute, which come to whole
 * tenths of health; the chest, which counts in full, then makes the loss exact. Returns the health it
 * ended at.
 */
/proc/outpost_prison_bruise(mob/living/carbon/body, health_loss)
	if(QDELETED(body) || health_loss <= 0)
		return body?.health
	var/target_health = body.health - health_loss
	var/obj/item/bodypart/chest = body.get_bodypart(BODY_ZONE_CHEST)
	var/list/parts = body.get_damageable_bodyparts()
	if(length(parts))
		var/share = health_loss / length(parts)
		for(var/obj/item/bodypart/part as anything in parts)
			if(part == chest || part.body_damage_coeff <= 0)
				continue
			var/room = FLOOR(part.max_damage - part.get_damage(), OUTPOST_PRISON_BRUISE_STEP)
			var/brute = min(round(share / part.body_damage_coeff, OUTPOST_PRISON_BRUISE_STEP), room)
			if(brute > 0)
				part.receive_damage(brute = brute, forced = TRUE, wound_bonus = CANT_WOUND, updating_health = FALSE)
		body.updatehealth()
	for(var/i in 1 to 5)
		var/short = round(body.health - target_health, DAMAGE_PRECISION)
		if(short <= 0 || !chest)
			break
		chest.receive_damage(brute = short, forced = TRUE, wound_bonus = CANT_WOUND)
	body.update_damage_overlays()
	return body.health

/**
 * Sets `body`'s health to `target_health` with brute alone: heals the brute it has, then bruises it
 * down (outpost_prison_bruise()). Burns, toxins and lost air stay as they are, so a body with those
 * can't be brought all the way up. For the admin tools. Returns the health it ended at.
 */
/proc/outpost_prison_set_health(mob/living/carbon/body, target_health)
	if(QDELETED(body))
		return null
	if(body.getBruteLoss() > 0)
		body.heal_overall_damage(brute = body.getBruteLoss(), forced = TRUE)
	return outpost_prison_bruise(body, body.health - target_health)

#undef OUTPOST_PRISON_BRUISE_STEP
