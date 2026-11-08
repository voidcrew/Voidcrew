// Hyperviolence: putting an NPC's fight onto the human corpse it leaves (see npc_wounds.dm).
//
// In order:
// 1. The damage it took, by body zone, scaled from the NPC's health to the corpse's, goes on the
//    matching bodyparts with no wound roll, so the fight itself never rolls a random dismemberment.
//    Damage nothing noted (fire, vacuum, bleeding out) is spread over the body, as tg always did.
// 2. The killing blow is struck again on its bodypart at its real force, through tg's own wound roll
//    (a chest cut can spill the guts, gut_spill.dm). A heavy enough blow then gets tg's dismember
//    roll (try_dismember(): the blow's damage plus how battered the limb is), so a katana kill can
//    take the head or a limb off, as it can on a player, and a crushing or piercing one can burst the
//    head instead (brain_burst.dm). A huge crushing or piercing blow to the head always bursts it.
// 3. An execution ends the same way it would on a person: the head burst, or a heavy skull wound.
// 4. Crits the NPC took (crit_basic.dm) become the matching wound and missing organ.
// 5. The clothes over the places that were hit get the corpse's blood, and the hands too if it was
//    badly hurt, with a pool under it.
// The lines those steps add name the NPC people saw die, not the corpse's own random name, and go out
// as one message before the deathgasp.

/**
 * Puts `dead`'s fight onto this corpse. `dead` is the NPC that just died, still in the world.
 * Returns TRUE if any of its tally was used.
 */
/mob/living/carbon/human/proc/hv_take_npc_wounds(mob/living/dead)
	var/datum/hv_npc_wounds/wounds = dead.hv_npc_wounds
	var/npc_health = max(dead.maxHealth, 1)
	var/scale = maxHealth / npc_health
	// Basic mobs keep every kind of damage as brute.
	var/taken = dead.getBruteLoss() + dead.getFireLoss()
	var/tracked = wounds?.total() || 0
	// Healing makes the tally run over what it really lost; fit the tally to what it lost.
	var/fit = (tracked > taken && tracked > 0) ? taken / tracked : 1
	var/untracked = max(taken - tracked, 0)
	var/killing_blow = wounds?.has_killing_blow()
	var/executed = wounds?.was_executed()

	var/real_name_shown = name
	name = dead.name
	if(wounds)
		hv_take_npc_tally(wounds, fit * scale, killing_blow)
	if(untracked > 0)
		take_overall_damage(brute = untracked * scale, updating_health = FALSE, forced = TRUE)
	if(killing_blow)
		hv_replay_killing_blow(wounds, executed)
	if(executed)
		hv_replay_execution(wounds)
	hv_take_npc_crits(dead)
	if(wounds)
		hv_bloody_npc_clothes(wounds, npc_health)
	updatehealth()
	update_damage_overlays()
	// Say it now, so the deathgasp comes after.
	hv_flush_hit()
	// A lost head changes what the body is called; otherwise it is its own name again.
	name = real_name_shown
	update_visible_name()
	return !!wounds

/// Step 1: the tally on the bodyparts it landed on, times `multiplier`, without the killing blow.
/mob/living/carbon/human/proc/hv_take_npc_tally(datum/hv_npc_wounds/wounds, multiplier, killing_blow)
	var/list/zones = wounds.brute_by_zone | wounds.burn_by_zone
	for(var/zone in zones)
		var/brute = wounds.brute_by_zone[zone] || 0
		var/burn = wounds.burn_by_zone[zone] || 0
		if(killing_blow && zone == wounds.last_zone)
			if(wounds.last_type == BRUTE)
				brute = max(brute - wounds.last_damage, 0)
			else
				burn = max(burn - wounds.last_damage, 0)
		brute *= multiplier
		burn *= multiplier
		if(brute <= 0 && burn <= 0)
			continue
		var/obj/item/bodypart/part = get_bodypart(zone) || get_bodypart(BODY_ZONE_CHEST)
		part?.receive_damage(brute, burn, updating_health = FALSE, forced = TRUE, wound_bonus = CANT_WOUND)

	// A skull is only opened by one heavy hit. The tally went on in one go, so settle it by the heaviest hit it noted.
	var/obj/item/bodypart/head/head = get_bodypart(BODY_ZONE_HEAD)
	if(!head)
		return
	if(wounds.max_head_hit >= HV_SKULL_OPEN_HIT)
		head.hv_open_skull()
	else if(head.hv_skull_open)
		head.hv_skull_open = FALSE
		head.hv_update_skull_wound()

/// Step 2: the killing blow again, at its real force. Executions settle the head themselves (step 3).
/mob/living/carbon/human/proc/hv_replay_killing_blow(datum/hv_npc_wounds/wounds, executed)
	var/obj/item/bodypart/part = get_bodypart(wounds.last_zone) || get_bodypart(BODY_ZONE_CHEST)
	if(!part)
		return
	var/blow = wounds.last_damage
	var/brute_blow = wounds.last_type == BRUTE
	// Not forced: a forced hit never spills guts. The corpse has no armour to soak it.
	part.receive_damage(
		brute = brute_blow ? blow : 0,
		burn = brute_blow ? 0 : blow,
		updating_health = FALSE,
		wound_bonus = wounds.last_wound_bonus,
		exposed_wound_bonus = wounds.last_exposed_bonus,
		sharpness = wounds.last_sharpness,
		attack_direction = wounds.last_dir,
	)
	if(executed || !brute_blow || wounds.last_wound_bonus == CANT_WOUND)
		return
	if(QDELETED(part) || part.owner != src)
		return // the wound roll already took it
	var/wounding_type = hv_crit_wounding_type(wounds.last_sharpness)
	if(part.body_zone == BODY_ZONE_HEAD && wounding_type != WOUND_SLASH && blow >= HV_CORPSE_HEAD_BURST_DAMAGE)
		hv_burst_head_apart(wounds.last_dir)
		return
	if(blow < (wounding_type == WOUND_SLASH ? HV_CORPSE_EDGED_SEVER_DAMAGE : HV_CORPSE_HEAVY_SEVER_DAMAGE))
		return
	if(part.body_zone == BODY_ZONE_CHEST && part.get_wound_type(/datum/wound/slash/flesh/critical/disembowel))
		return // the cut already spilled the guts
	hv_roll_corpse_dismember(part, wounding_type, blow, wounds.last_wound_bonus, wounds.last_exposed_bonus, wounds.last_dir)

/// tg's dismember roll for one blow on a corpse's limb. A separate proc so tests can force it.
/mob/living/carbon/human/proc/hv_roll_corpse_dismember(obj/item/bodypart/part, wounding_type, blow, wound_bonus, exposed_wound_bonus, blow_dir)
	var/obj/item/bodypart/head/head = part
	if(istype(head))
		head.hv_blow_dir = blow_dir // so a burst throws the brain the way the blow went
	. = part.try_dismember(wounding_type, blow, wound_bonus, exposed_wound_bonus)
	if(istype(head) && !QDELETED(head))
		head.hv_blow_dir = null

/// Step 3: the end of an execution, as hv_take_execution() would have it on a person.
/mob/living/carbon/human/proc/hv_replay_execution(datum/hv_npc_wounds/wounds)
	var/obj/item/bodypart/head/head = get_bodypart(BODY_ZONE_HEAD)
	if(!head)
		return
	// Said here unless the NPC's own line already did (it didn't if the bullet killed it outright).
	var/announce = !wounds.execution_said
	if(wounds.execution_blow >= HV_EXECUTION_BURST_DAMAGE && hv_burst_head_apart(wounds.execution_dir, announce))
		return
	if(head.brute_dam < HV_SKULL_HEAVY_BRUTE)
		head.receive_damage(HV_SKULL_HEAVY_BRUTE - head.brute_dam, updating_health = FALSE, forced = TRUE, wound_bonus = CANT_WOUND)
	if(head.hv_open_skull() && announce)
		hv_add_hit_line("The shot blows out the back of [src]'s skull.", HV_LINE_HUGE, null, DEFAULT_MESSAGE_RANGE)

/// Step 4: the NPC's crits (crit_basic.dm) as the wounds and missing organs a person gets from them.
/mob/living/carbon/human/proc/hv_take_npc_crits(mob/living/dead)
	var/obj/item/bodypart/head/head = get_bodypart(BODY_ZONE_HEAD)
	if(head)
		if(dead.has_status_effect(/datum/status_effect/hv_crit_basic/eye))
			var/obj/item/organ/eyes/eyes = get_organ_slot(ORGAN_SLOT_EYES)
			if(eyes && !(eyes.organ_flags & ORGAN_UNREMOVABLE) && hv_crit_apply_wound(head, /datum/wound/pierce/bleed/severe/eye/hv_gouged))
				eyes.apply_scar(LEFT_EYE_SCAR) // the socket wound names the left eye
		if(dead.has_status_effect(/datum/status_effect/hv_crit_basic/tongue))
			var/obj/item/organ/tongue/tongue = get_organ_slot(ORGAN_SLOT_TONGUE)
			if(tongue && !(tongue.organ_flags & ORGAN_UNREMOVABLE) && hv_crit_apply_wound(head, /datum/wound/slash/flesh/moderate/hv_tongue))
				tongue.Remove(src)
				qdel(tongue)
		if(dead.has_status_effect(/datum/status_effect/hv_crit_basic/jaw))
			hv_crit_apply_wound(head, /datum/wound/blunt/bone/severe/hv_jaw)
		if(dead.has_status_effect(/datum/status_effect/hv_crit_basic/skull))
			hv_crit_apply_wound(head, /datum/wound/blunt/bone/critical/hv_skull)
			head.hv_open_skull()
		if(dead.has_status_effect(/datum/status_effect/hv_crit_basic/bleed/throat))
			hv_crit_apply_wound(head, /datum/wound/slash/flesh/critical/hv_carotid)
	var/obj/item/bodypart/chest = get_bodypart(BODY_ZONE_CHEST)
	if(chest && dead.has_status_effect(/datum/status_effect/hv_crit_basic/bleed/aorta))
		hv_crit_apply_wound(chest, /datum/wound/pierce/bleed/critical/hv_aorta)

/// Step 5: blood on the clothes over every place that took a beating, and on the hands and floor if it took a lot.
/mob/living/carbon/human/proc/hv_bloody_npc_clothes(datum/hv_npc_wounds/wounds, npc_health)
	if(!can_bleed())
		return
	var/list/blood_dna = get_blood_dna_list()
	if(!length(blood_dna))
		return
	var/slots = NONE
	var/beaten = 0
	for(var/zone in wounds.brute_by_zone)
		var/share = wounds.brute_by_zone[zone] / npc_health
		beaten += share
		if(share >= HV_CORPSE_BLOOD_ZONE_SHARE)
			slots |= hv_zone_clothing_slots(zone)
	if(beaten >= HV_CORPSE_BLOOD_HANDS_SHARE)
		slots |= ITEM_SLOT_GLOVES
		add_splatter_floor(get_turf(src))
	if(slots)
		add_blood_DNA_to_items(blood_dna, slots)

/// The clothing slots over a body zone.
/proc/hv_zone_clothing_slots(zone)
	switch(zone)
		if(BODY_ZONE_HEAD)
			return ITEM_SLOT_HEAD | ITEM_SLOT_MASK | ITEM_SLOT_NECK | ITEM_SLOT_EYES
		if(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM)
			return ITEM_SLOT_ICLOTHING | ITEM_SLOT_OCLOTHING | ITEM_SLOT_GLOVES
	return ITEM_SLOT_ICLOTHING | ITEM_SLOT_OCLOTHING
