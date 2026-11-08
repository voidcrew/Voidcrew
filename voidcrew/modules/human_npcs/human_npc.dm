// Human combat NPCs: a real /mob/living/carbon/human body driven by an ai_controller.
//
// SPIKE PROTOTYPE (branch hv/human-npc-spike). Nothing spawns these in normal play yet.
//
// Because the body is a real human, tg's wounds, dismemberment, soft and hard crit, crawling,
// bleeding out and the hyperviolence executions and crits all apply to it while it is alive,
// with no corpse swap at death. The AI (human_npc_ai.dm) fights through the held item: a gun is
// fired through ClickOn, so the gun's own fire path, projectiles and casings are used.
//
// Life() trimming. A human's Life() runs every SSmobs tick (2 s) for every human in the world,
// with or without a client or a player nearby. NPCs keep everything that matters for a fight
// (blood, wounds, organs, breathing, body temperature) and drop the rest:
// - no mood datum (setup_mood), so nothing processes on SSmood;
// - TRAIT_NOHUNGER, so a long-lived NPC never starves over a 6 hour round;
// - dormancy: Life() does nothing while no player is on the NPC's z-level (the same test tg uses
//   to switch the AI off) and always once the NPC is dead. A dormant NPC is frozen in time; a
//   dead one never decays or rots. This has to be a guard on Life() itself: COMSIG_LIVING_LIFE's
//   cancel flag only stops /mob/living/Life(), and carbon and human Life() run organs, wounds,
//   limbs, body temperature, heart and liver around that call whatever it returns.

/mob/living/carbon/human/npc
	name = "Pirate"
	faction = list(FACTION_PIRATE)
	ai_controller = /datum/ai_controller/basic_controller/human_npc
	/// Outfit worn at spawn.
	var/datum/outfit/npc_outfit = /datum/outfit/piratecorpse
	/// Weapon put in the right hand at spawn, or null for fists.
	var/obj/item/npc_weapon
	/// Apply the NPC Life() trims (no mood, no hunger, dormancy). Off only for measurement.
	var/npc_trim_life = TRUE
	/// Cancel Life() while dead.
	var/npc_dormant_when_dead = TRUE

/mob/living/carbon/human/npc/Initialize(mapload)
	. = ..()
	if(npc_trim_life)
		ADD_TRAIT(src, TRAIT_NOHUNGER, INNATE_TRAIT)
	if(npc_outfit)
		equipOutfit(npc_outfit)
	if(npc_weapon)
		var/obj/item/weapon = new npc_weapon(src)
		if(put_in_r_hand(weapon))
			npc_prepare_weapon(weapon)
		else
			qdel(weapon)

/mob/living/carbon/human/npc/setup_mood()
	if(npc_trim_life)
		return
	return ..()

/// Switches on whatever the NPC holds so it is ready to fight (energy swords and similar).
/mob/living/carbon/human/npc/proc/npc_prepare_weapon(obj/item/weapon)
	if(istype(weapon, /obj/item/melee/energy))
		var/obj/item/melee/energy/esword = weapon
		if(!HAS_TRAIT(esword, TRAIT_TRANSFORM_ACTIVE))
			esword.attack_self(src)

/mob/living/carbon/human/npc/Life(seconds_per_tick = SSMOBS_DT, times_fired)
	if(npc_trim_life && npc_dormant())
		return FALSE
	return ..()

/// TRUE while this NPC's Life() should not run.
/mob/living/carbon/human/npc/proc/npc_dormant()
	if(stat == DEAD)
		return npc_dormant_when_dead
	return !npc_players_on_level()

/// Whether any living player shares this NPC's z-level. Same test as get_expected_ai_status().
/mob/living/carbon/human/npc/proc/npc_players_on_level()
	var/turf/our_turf = get_turf(src)
	if(isnull(our_turf))
		return FALSE
	return length(SSmobs.clients_by_zlevel[our_turf.z]) > 0

/mob/living/carbon/human/npc/ranged
	name = "Pirate Gunner"
	npc_outfit = /datum/outfit/piratecorpse/ranged
	npc_weapon = /obj/item/gun/energy/laser

/mob/living/carbon/human/npc/melee
	name = "Pirate Swashbuckler"
	npc_outfit = /datum/outfit/piratecorpse/melee
	npc_weapon = /obj/item/melee/energy/sword/pirate

/**
 * Refills a gun an NPC carries, standing in for the spare cells and magazines it doesn't model.
 * Returns TRUE if the gun can shoot afterwards.
 */
/obj/item/gun/proc/npc_refill()
	return can_shoot()

/obj/item/gun/energy/npc_refill()
	if(QDELETED(cell))
		return FALSE
	cell.give(cell.maxcharge)
	recharge_newshot(TRUE)
	update_appearance()
	return can_shoot()

/obj/item/gun/ballistic/npc_refill()
	if(magazine)
		magazine.top_off()
	if(!chambered)
		chamber_round()
	update_appearance()
	return can_shoot()
