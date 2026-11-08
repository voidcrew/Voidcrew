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
 */

/**
 * `hitter` strikes `target` beside it with `weapon` in hand (switched to the active hand), or a fist
 * if `weapon` is null, the way a player clicks with combat mode on. The aim spreads over the body as
 * other human NPCs' does. Returns TRUE if the blow was thrown.
 */
/proc/outpost_prison_npc_hit(mob/living/carbon/human/hitter, atom/target, obj/item/weapon)
	if(QDELETED(hitter) || QDELETED(target) || hitter.stat != CONSCIOUS || world.time < hitter.next_move)
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
